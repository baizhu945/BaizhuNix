{ config, pkgs, lib,  ... }:

{
  fileSystems."/mnt/T7_Shield" = {
    device = "/dev/disk/by-uuid/601F-0929";
    fsType = "exfat";
    options = [
      "rw"
      "nofail"
      "users"
      "uid=1000"
      "gid=1000"
      "umask=0022"
    ];
  };

  services.mpd = {
    enable = true;
    settings = {
      music_directory = "/mnt/T7_Shield/Music_Lossless";
      audio_output = [
        {
          type = "alsa";
          name = "xDuoo Native DSD";
          device = "dsd_force";
          auto_resample = "no";
          auto_channels = "no";
          auto_format = "no";
          mixer_type = "disabled";
        }
      ];
    };
    startWhenNeeded = true;
  };

  environment.etc."asound.conf".text = ''
    # xDuoo DAC的直接硬件访问配置
    pcm.dsd_force {
        type hw
        card Audio
        device 0
    }

    ctl.dsd_force {
        type hw
        card Audio
    }
  '';

  services.pipewire.extraConfig = {
    pipewire = {
      "10-rates.conf" = {
        "context.properties" ={
          "default.clock.allowed-rates" = [ 44100 48000 88200 96000 176000 352000 384000 ];
        };
      };
    };

    client = {
      "resample.conf" = {
        "stream.properties" = {
          "resample.quality" = 14;
        };
      };
    };
  };
}
