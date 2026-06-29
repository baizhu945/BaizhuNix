{ config, pkgs, lib, ... }:

let
  # linux-g14 打包仓库（只含 patch 文件和 config）
  linux-g14-repo = pkgs.fetchurl {
    url = "https://gitlab.com/asus-linux/linux-g14/-/archive/7.0/linux-g14-7.0.tar.gz";
    hash = "sha256-z+QzCzRTGfGZkoP2jrhfZxmQ21aB0VbAkpKLOtpOie4=";
  };

  # 解压为 derivation，使各 patch 文件可被引用
  linux-g14-files = pkgs.runCommand "linux-g14-files" {} ''
    mkdir -p $out
    tar -xzf ${linux-g14-repo} -C $out --strip-components=1
  '';

  # 按 PKGBUILD source 数组顺序排列（跳过注释掉的 patch）
  g14KernelPatches = [
    # {
      # name = "more-uarches-6.15";
      # patch = "${linux-g14-files}/sys-kernel_arch-sources-g14_files-0004-more-uarches-for-kernel-6.15.patch";
    # }
    {
      name = "asus-armoury-FA507UV";
      patch = "${linux-g14-files}/0003-platform-x86-asus-armoury-add-support-for-FA507UV.patch";
    }
    {
      name = "asus-armoury-FA608UM";
      patch = "${linux-g14-files}/0003-platform-x86-asus-armoury-add-support-for-FA608UM.patch";
    }
    {
      name = "asus-armoury-G615LR";
      patch = "${linux-g14-files}/0003-platform-x86-asus-armoury-add-support-for-G615LR.patch";
    }
    {
      name = "asus-armoury-G835LW";
      patch = "${linux-g14-files}/0003-platform-x86-asus-armoury-add-support-for-G835LW.patch";
    }
    {
      name = "asus-armoury-GA403WR";
      patch = "${linux-g14-files}/0003-platform-x86-asus-armoury-add-support-for-GA403WR.patch";
    }
    {
      name = "asus-armoury-ppt-fixes";
      patch = "${linux-g14-files}/0003-0-4-platform-x86-asus-armoury-ppt-fixes-and-new-models.patch";
    }
    {
      name = "acpi-proc-idle";
      patch = "${linux-g14-files}/0001-acpi-proc-idle-skip-dummy-wait.patch";
    }
    {
      name = "asus-wmi-screenpad";
      patch = "${linux-g14-files}/PATCH-asus-wmi-fixup-screenpad-brightness.patch";
    }
    {
      name = "acpi-s2idle-wakeup";
      patch = "${linux-g14-files}/0070-acpi-x86-s2idle-Add-ability-to-configure-wakeup-by-A.patch";
    }
    {
      name = "amdgpu-hw-decode-workaround";
      patch = "${linux-g14-files}/0040-workaround_hardware_decoding_amdgpu.patch";
    }
    {
      name = "steam-deck-hdr";
      patch = "${linux-g14-files}/0084-enable-steam-deck-hdr.patch";
    }
    {
      name = "asus-nb-wmi-tablet-mode";
      patch = "${linux-g14-files}/sys-kernel_arch-sources-g14_files-0047-asus-nb-wmi-Add-tablet_mode_sw-lid-flip.patch";
    }
    {
      name = "asus-nb-wmi-tablet-int";
      patch = "${linux-g14-files}/sys-kernel_arch-sources-g14_files-0048-asus-nb-wmi-fix-tablet_mode_sw_int.patch";
    }
    {
      name = "ga403wr-audio";
      patch = "${linux-g14-files}/ga403wr-fix-audio.patch";
    }
    {
      name = "asus-wmi-battery";
      patch = "${linux-g14-files}/0001-platform-asus-wmi-do-not-enforce-battery.patch";
    }
    {
      name = "g614fp";
      patch = "${linux-g14-files}/0002-g614fp.patch";
    }
    {
      name = "lamparray";
      patch = "${linux-g14-files}/v4-0001-lamparray.patch";
    }
    {
      name = "asus-armoury-FX608JMR";
      patch = "${linux-g14-files}/0001-platform-x86-asus-armoury-add-support-for-FX608JMR.patch";
    }
  ];

  linux_g14_pkg = { fetchFromGitHub, buildLinux, ... } @ args:
    buildLinux (args // rec {
      version = "7.0.2";
      modDirVersion = "7.0.2-arch1";

      # 真正的内核源码：Arch Linux 的 linux 仓库 tag v7.0.2-arch1
      src = fetchFromGitHub {
        owner = "archlinux";
        repo = "linux";
        rev = "v7.0.2-arch1";
        # 首次构建时先填空字符串，从报错的 "got:" 行取 hash
        hash = "sha256-eiwrD0Im2e+WEJCIhJaXcHnNXUrRl6zSEFrwzbnNBTY=";
      };

      kernelPatches = g14KernelPatches;

      # PKGBUILD 里通过 scripts/config 设置了大量 config，
      # 用 structuredExtraConfig 对应最关键的选项
      structuredExtraConfig = with lib.kernel; {
        # AMD/ASUS 相关
        PINCTRL_AMD         = yes;
        X86_AMD_PSTATE      = yes;
        AMD_PMC             = module;
        # ASUS_WMI_BIOS       = yes;
        # HID_ASUS_ALLY       = module;
        # ASUS_ARMOURY        = yes;
        ASUS_WMI_DEPRECATED_ATTRS = yes;
        DRM_AMD_COLOR_STEAMDECK   = yes;

        # 调度
        SCHED_CLASS_EXT     = yes;

        # LRU
        LRU_GEN             = yes;
        LRU_GEN_ENABLED     = yes;
        LRU_GEN_STATS       = no;

        # 模块压缩
        # MODULE_COMPRESS_NONE = no;
        # MODULE_COMPRESS_ZSTD = yes;

        # NTSYNC
        NTSYNC              = yes;

        # EFI
        EFI_HANDOVER_PROTOCOL = yes;
        EFI_STUB            = yes;

        # 禁用 nouveau（NVIDIA 用 nvidia-open）
        # DRM_NOUVEAU         = no;

        # 禁用虚拟化驱动（PKGBUILD 的选择，
        # 但如果你用 virt-manager/QEMU 请删掉这段！）
        # HYPERVISOR_GUEST    = no;
        # VIRT_DRIVERS        = no;

        # 禁用 SELinux
        SECURITY_SELINUX    = no;

        # 禁用 TPM RNG（防止 ROG 笔记本卡顿）
        HW_RANDOM_TPM       = no;
      };

      extraMeta.branch = "7.0";
    } // (args.argsOverride or {}));

  linux_g14 = pkgs.callPackage linux_g14_pkg {};

in
{
  boot.kernelPackages =
    pkgs.lib.recurseIntoAttrs (pkgs.linuxPackagesFor linux_g14);
}
