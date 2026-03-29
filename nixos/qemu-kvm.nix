{ config, pkgs, lib,  ... }:

let
  stableTarball =
    fetchTarball
      https://nixos.org/channels/nixos-25.11/nixexprs.tar.xz;
  stablePkgs = import stableTarball {
    config = config.nixpkgs.config;
  };
in
{
  boot.binfmt.emulatedSystems = [
    "aarch64-linux"
    "riscv64-linux"
  ];

  users.users.baizhu945 = {
    extraGroups = [
      "libvirtd"
      "kvm"
      "disk"
    ];
  };

  environment.systemPackages = with pkgs; [
    qemu
    virt-manager
    OVMFFull
    dmidecode
  ];

  programs.virt-manager.enable = true;
  services.qemuGuest.enable = true;
  services.spice-vdagentd.enable = true;

  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      vhostUserPackages = with pkgs; [ virtiofsd ];
      package = pkgs.qemu;
      swtpm.enable = true;
      runAsRoot = true;
      verbatimConfig = ''
        cgroup_device_acl = [
          "/dev/null", "/dev/full", "/dev/zero", "/dev/random", "/dev/urandom",
          "/dev/ptmx", "/dev/kvm", "/dev/rtc", "/dev/hpet",
          "/dev/sdb", "/dev/sdb1", "/dev/sda", "/dev/sda1"
        ]
      '';
    };
    onBoot = "start";
  };

  systemd.services.virtnetworkd = {
    enable = true;
    path = with pkgs; [
      dnsmasq     # 报错的核心：负责 DHCP 和 DNS
      iptables    # 负责 NAT 转发和防火墙规则
      nftables    # 新版 libvirt 可能会用到的后端
      iproute2    # 负责管理桥接网卡 (ip link/addr)
      bridge-utils # 备用的桥接工具 (brctl)
      dmidecode   # libvirt 检测硬件信息有时需要
    ];
    wantedBy = [ "multi-user.target" ]; # 强制开机启动
  };
  systemd.sockets.virtnetworkd = {
    enable = true;
    wantedBy = [ "sockets.target" ];
  };

  systemd.services.virtqemud = {
    path = with pkgs; [
      bridge-utils
      dmidecode
      qemu
      qemu-utils
      acl
      kmod
      iproute2
      runtimeShell
    ]; # 根据需要添加
    wantedBy = [ "multi-user.target" ]; # 强制开机启动
  };
  systemd.sockets.virtqemud = {
    enable = true;
    wantedBy = [ "sockets.target" ];
  };

  systemd.services.virtnodedevd = {
    path = with pkgs; [
      pciutils
      usbutils
      coreutils
      mdevctl
      util-linux
      kmod
      systemd
      acl
      dbus
    ];
    serviceConfig = {
      BindReadOnlyPaths = [ 
        "/run/udev:/run/udev"
        "/run/dbus:/run/dbus" 
      ];
    };
    wantedBy = [ "multi-user.target" ];
  };
  systemd.sockets.virtnodedevd = {
    enable = true;
    wantedBy = [ "sockets.target" ];
  };

  systemd.services.virtstoraged = {
    path = with pkgs; [ 
      qemu-utils  # 核心：提供 qemu-img 用于创建和转换 qcow2 镜像
      coreutils   # 提供基础文件操作支持
      util-linux  # 提供挂载和设备查询支持
      acl
    ];
    wantedBy = [ "multi-user.target" ];
  };
  systemd.sockets.virtstoraged = {
    enable = true;
    wantedBy = [ "sockets.target" ];
  };

  systemd.services.virtsecretd.wantedBy = [ "multi-user.target" ];
  systemd.sockets.virtsecretd = {
    enable = true;
    wantedBy = [ "sockets.target" ];
  };

  # 修复 virt-secret-init-encryption.service 的硬编码 shell 路径
  systemd.services.virt-secret-init-encryption = {
    description = "Initialize Libvirt Secret Encryption Key";
    after = [ "local-fs.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      # 使用 Nix store 中的 bash 路径替换 /usr/bin/sh
      ExecStart = "${pkgs.bash}/bin/sh -c 'umask 0077 && (dd if=/dev/random status=none bs=32 count=1 | ${pkgs.systemd}/bin/systemd-creds encrypt --name=secrets-encryption-key - /var/lib/libvirt/secrets/secrets-encryption-key)'";
      RemainAfterExit = true;
    };
  };

  environment.etc."libvirt/qemu.conf".text = ''
    # NixOS 模块原本写入 /var/lib/libvirt/qemu.conf 的内容
    # 但 virtqemud 只读 /etc/libvirt/qemu.conf，所以我们手动把它放到正确位置
    namespaces = []  
    # UEFI 固件路径
    nvram = [
      "/run/libvirt/nix-ovmf/edk2-x86_64-code.fd:/run/libvirt/nix-ovmf/edk2-i386-vars.fd",
      "/run/libvirt/nix-ovmf/edk2-x86_64-secure-code.fd:/run/libvirt/nix-ovmf/edk2-i386-vars.fd"
    ]

    user = "root"
    group = "root"
    emulator = "/run/libvirt/nix-emulators/qemu-system-x86_64"
  '';

  environment.variables.PATH = "/run/current-system/sw/bin";

  systemd.tmpfiles.rules = [
    "L+ /var/lib/qemu/firmware - - - - ${pkgs.qemu}/share/qemu/firmware"
  ];

  hardware.ksm.enable = true;
  hardware.ksm.sleep = 500;

  system.activationScripts.libvirtFixFirmwarePaths = {
    deps = [ "var" ];
    text = ''
      # 在 activationScripts 里必须用完整的 store 路径引用所有外部工具
      # 因为激活环境的 PATH 是空的，不包含任何常规命令
      SED="${pkgs.gnused}/bin/sed"

      if [ -d /var/lib/libvirt/qemu ]; then
        for xmlfile in /var/lib/libvirt/qemu/*.xml; do
          [ -f "$xmlfile" ] || continue

          # 替换 <loader> 标签内容里的 secure-code 路径
          "$SED" -i \
            's|/nix/store/[^<]*edk2-x86_64-secure-code\.fd|/run/libvirt/nix-ovmf/edk2-x86_64-secure-code.fd|g' \
            "$xmlfile"

          # 替换 <loader> 标签内容里的普通 code 路径（放在 secure-code 之后避免误匹配）
          "$SED" -i \
            's|/nix/store/[^<]*edk2-x86_64-code\.fd|/run/libvirt/nix-ovmf/edk2-x86_64-code.fd|g' \
            "$xmlfile"

          # 只替换 <nvram> 的 template 属性值，保留标签内容里的 _VARS.fd 路径不变
          "$SED" -i \
            's|template="/nix/store/[^"]*edk2-i386-vars\.fd"|template="/run/libvirt/nix-ovmf/edk2-i386-vars.fd"|g' \
            "$xmlfile"
        done
      fi

      if [ -d /var/lib/libvirt/qemu ]; then
        # 修复主 VM XML
        for xml in /var/lib/libvirt/qemu/*.xml; do
          [ -f "$xml" ] || continue
  
          $SED -i \
            's|/nix/store/.*/bin/qemu-system-x86_64|/run/libvirt/nix-emulators/qemu-system-x86_64|g' \
            "$xml"
        done
  
        # 修复 snapshot XML（你现在其实已经部分正确，但建议统一）
        for xml in /var/lib/libvirt/qemu/snapshot/*/*.xml; do
          [ -f "$xml" ] || continue
  
          $SED -i \
            's|/nix/store/.*/bin/qemu-system-x86_64|/run/libvirt/nix-emulators/qemu-system-x86_64|g' \
            "$xml"
        done
      fi

      rm -rf /var/cache/libvirt/qemu/*
    '';
  };
}
