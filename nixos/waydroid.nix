{ config, pkgs, lib,  ... }:

{
  boot.kernelModules = [ "ip_tables" "iptable_filter" "iptable_nat" "tun" "bridge" ];
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

  networking.nftables.enable = true; # 开启新版防火墙后端

  virtualisation.waydroid.enable = true;

  environment.systemPackages =  [ 
    pkgs.waydroid-helper 
    pkgs.android-tools 
    pkgs.iptables
    pkgs.dnsmasq
  ];

  systemd = {
    packages = [ pkgs.waydroid-helper ];
    services.waydroid-mount.wantedBy = [ "multi-user.target" ];
  };

  services.geoclue2.enable = true;

  systemd.tmpfiles.settings."10-waydroid" = {
    "/var/lib/waydroid/waydroid_base.prop" = {
      "f+" = {
        mode = "0644";
        user = "root";
        group = "root";
        argument = ''
          ro.hardware.gralloc=default
          ro.hardware.egl=swiftshader
          sys.use_memfd=true
        '';
      };
    };
  };
}
