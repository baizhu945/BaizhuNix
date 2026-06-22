{ config, pkgs, lib,  ... }:

{
  services.mpd = {
    enable = true;
    settings = {
      music_directory = "/mnt/T7_Shield/Music_Lossless";
      audio_output = [
        {
          type = "alsa";
          name = "DX5 II";
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
    pcm.dsd_force {
        type hw
        card II
        device 0
    }

    ctl.dsd_force {
        type hw
        card II
    }
  '';

  services.pipewire.extraConfig = {
    pipewire = {
      "10-rates.conf" = {
        "context.properties" ={
          "default.clock.allowed-rates" = [ 44100 48000 88200 96000 176400 192000 352800 384000 705600 768000 ];
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

  environment.systemPackages = [ pkgs.cantata ];
}
