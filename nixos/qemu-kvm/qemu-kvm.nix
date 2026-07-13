{ config, pkgs, lib,  ... }:

{
  boot.extraModprobeConfig = ''
    options kvm_intel nested=1
    options kvm_intel yield_func_stats=0
  '';

  users.users.<yourusername> = {
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
    virglrenderer
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
        nvram = [
          "/run/libvirt/nix-ovmf/edk2-x86_64-code.fd:/run/libvirt/nix-ovmf/edk2-i386-vars.fd",
          "/run/libvirt/nix-ovmf/edk2-x86_64-secure-code.fd:/run/libvirt/nix-ovmf/edk2-i386-vars.fd"
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

  systemd.tmpfiles.rules = [
    "L+ /var/lib/qemu/firmware - - - - ${pkgs.qemu}/share/qemu/firmware"
  ];

  hardware.ksm.enable = true;
  hardware.ksm.sleep = 500;

  systemd.services.libvirt-fix-firmware-paths = {
    description = "Fix libvirt VM firmware paths to use stable NixOS symlinks";
    after = [ "network.target" "local-fs.target" ];
    before = [ "virtqemud.service" ];
    wantedBy = [ "multi-user.target" ];
  
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "root";
    };

    path = with pkgs; [ gnused gnugrep coreutils ];
    script = builtins.readFile ./fix-firmware-path.sh;
  };
}
