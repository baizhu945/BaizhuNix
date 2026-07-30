{ config, pkgs, lib, ... }:

{
  fileSystems."/mnt/Windows/EFI" = {
    device = "/dev/disk/by-uuid/241F-8E2D";
    fsType = "vfat";
    options = [
      "rw"
      "nofail"
      "users"
      "uid=1000"
      "gid=1000"
      "umask=0022"
      "noauto"
    ];
  };

  systemd.services."ntfsfix-win10-c" = {
    description = "Clear NTFS dirty state on Windows C partition before mounting";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.ntfs3g}/bin/ntfsfix /dev/disk/by-uuid/545C43E35C43BF0C";
    };
  };
  systemd.mounts = [{
    what = "/dev/disk/by-uuid/545C43E35C43BF0C";
    where = "/mnt/Windows/C";
    type = "ntfs3";
    options = "rw,uid=1000,gid=1000,umask=0022,nofail,force";
    wantedBy = [];
    requires = [ "ntfsfix-win10-c.service" ];
    after = [ "ntfsfix-win10-c.service" ];
  }];

  fileSystems."/mnt/Windows/RECOVER_C" = {
    device = "/dev/disk/by-uuid/88DEE415DEE3F978";
    fsType = "ntfs3";
    options = [
      "rw"
      "nofail"
      "users"
      "uid=1000"
      "gid=1000"
      "umask=0022"
      "noauto"
    ];
  };

  fileSystems."/mnt/Windows/D" = {
    device = "/dev/disk/by-uuid/24C073F9C073CF92";
    fsType = "ntfs3";
    options = [
      "rw"
      "nofail"
      "users"
      "uid=1000"
      "gid=1000"
      "umask=0022"
      "noauto"
    ];
  };

  fileSystems."/mnt/Windows/RECOVER_D" = {
    device = "/dev/disk/by-uuid/000EA90D0EA8FCB2";
    fsType = "ntfs3";
    options = [
      "rw"
      "nofail"
      "users"
      "uid=1000"
      "gid=1000"
      "umask=0022"
      "noauto"
    ];
  };

  fileSystems."/mnt/T7_Shield" = {
    device = "/dev/disk/by-uuid/601F-0929";
    fsType = "exfat";
    noCheck = true;
    options = [
      "rw"
      "nofail"
      "users"
      "uid=1000"
      "gid=1000"
      "umask=0022"
      "noauto"
    ];
  };

  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="block", ENV{ID_FS_UUID}=="000EA90D0EA8FCB2", \
    TAG+="systemd", ENV{SYSTEMD_WANTS}+="mnt-Windows-RECOVER_D.mount"

    ACTION=="add", SUBSYSTEM=="block", ENV{ID_FS_UUID}=="88DEE415DEE3F978", \
    TAG+="systemd", ENV{SYSTEMD_WANTS}+="mnt-Windows-RECOVER_C.mount"

    ACTION=="add", SUBSYSTEM=="block", ENV{ID_FS_UUID}=="241F-8E2D", \
    TAG+="systemd", ENV{SYSTEMD_WANTS}+="mnt-Windows-EFI.mount"

    ACTION=="add", SUBSYSTEM=="block", ENV{ID_FS_UUID}=="545C43E35C43BF0C", \
    TAG+="systemd", ENV{SYSTEMD_WANTS}+="mnt-Windows-C.mount"

    ACTION=="add", SUBSYSTEM=="block", ENV{ID_FS_UUID}=="24C073F9C073CF92", \
    TAG+="systemd", ENV{SYSTEMD_WANTS}+="mnt-Windows-D.mount"

    ACTION=="add", SUBSYSTEM=="block", ENV{ID_FS_UUID}=="601F-0929", \
    TAG+="systemd", ENV{SYSTEMD_WANTS}+="mnt-T7_Shield.mount"
  '';
}
