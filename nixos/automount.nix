{ config, pkgs, lib, ... }:

{
  fileSystems."/mnt/Windows/EFI" = {
    device = "/dev/disk/by-uuid/AEDB-5D56";
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
      ExecStart = "${pkgs.ntfs3g}/bin/ntfsfix /dev/disk/by-uuid/7CFAFFF4FAFFA892";
    };
  };
  systemd.mounts = [{
    what = "/dev/disk/by-uuid/7CFAFFF4FAFFA892";
    where = "/mnt/Windows/C";
    type = "ntfs3";
    options = "rw,uid=1000,gid=1000,umask=0022,nofail,force";
    wantedBy = [];
    requires = [ "ntfsfix-win10-c.service" ];
    after = [ "ntfsfix-win10-c.service" ];
  }];

  fileSystems."/mnt/Windows/RECOVER" = {
    device = "/dev/disk/by-uuid/8A324B9F324B8F5F";
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
    device = "/dev/disk/by-uuid/00D8E718D8E70AAC";
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
    ACTION=="add", SUBSYSTEM=="block", ENV{ID_FS_UUID}=="8A324B9F324B8F5F", \
    TAG+="systemd", ENV{SYSTEMD_WANTS}+="mnt-Windows-RECOVER.mount"

    ACTION=="add", SUBSYSTEM=="block", ENV{ID_FS_UUID}=="AEDB-5D56", \
    TAG+="systemd", ENV{SYSTEMD_WANTS}+="mnt-Windows-EFI.mount"

    ACTION=="add", SUBSYSTEM=="block", ENV{ID_FS_UUID}=="7CFAFFF4FAFFA892", \
    TAG+="systemd", ENV{SYSTEMD_WANTS}+="mnt-Windows-C.mount"

    ACTION=="add", SUBSYSTEM=="block", ENV{ID_FS_UUID}=="00D8E718D8E70AAC", \
    TAG+="systemd", ENV{SYSTEMD_WANTS}+="mnt-Windows-D.mount"

    ACTION=="add", SUBSYSTEM=="block", ENV{ID_FS_UUID}=="601F-0929", \
    TAG+="systemd", ENV{SYSTEMD_WANTS}+="mnt-T7_Shield.mount"
  '';
}
