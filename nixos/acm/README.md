# /etc/nixos/acm -- ACM-equivalent display colour management

This directory contains the declarative Nix configuration for the Linux ACM
equivalent (see `~/Code/acm-re/linux/README.md` for the full documentation).

* `package.nix` -- reproducible derivation for `acm-ctl` (colour engine +
  KMS/Wayland appliers; `doCheck = true` runs the 73-check test suite during the
  build, including byte-for-byte comparison with Microsoft's `dwmcore.dll`
  colour tables).
* `module.nix`  -- the NixOS module (`services.acm.*`): installs the package,
  generates `/etc/acm/displays.conf`, grants DRM access, optional system daemon
  and optional `vkms` loading for `acm-ctl selftest`.

Enable it in `configuration.nix`:

```nix
imports = [ ./acm/module.nix ];
services.acm = {
  enable = true;
  user = "<yourusername>";
  displays = {
    "eDP-1"    = { mode = "auto"; };
    "HDMI-A-1" = { mode = "auto"; };
  };
};
```

The session daemon (which applies the transform under a Wayland compositor via
`wlr-gamma-control`) is configured per-user in
`~/.config/home-manager/acm.nix`; it writes `~/.config/acm/displays.conf` and the
`acm.service` systemd **user** unit.

## Turning ACM on and off

```bash
acm-ctl status              # is it on? which applier? is the hardware really programmed? (exit 0 = on)
acm-ctl off                 # stop the daemon + clear the hardware ramp (exit 0 = cleared)
acm-ctl on                  # start the daemon + verify (exit 0 = verified)
acm-ctl status --json       # machine-readable

# temporary, without the wrapper commands:
systemctl --user stop acm   # off  (the compositor restores its default ramp)
systemctl --user start acm  # on

# permanent: edit the Nix configuration instead
#   ~/.config/home-manager/home.nix :  home.acm.enable = false;
#   /etc/nixos/configuration.nix    :  services.acm.enable = false;
```

Do **not** use `systemctl --user disable acm` or `mask acm` -- the unit file is
managed by home-manager and those commands break/are rejected; use the Nix
options or `acm-ctl off`.

## Rebuilding / re-deploying

```bash
# system side (package, /etc/acm/displays.conf, DRM access)
sudo nixos-rebuild switch

# user side (session daemon + user config)
home-manager switch -b ~/hm-backup

# check the transform is live in the display hardware
acm-ctl verify --config ~/.config/acm/displays.conf
```

## Verifying the full pipeline (needs DRM master)

While a compositor owns the displays only the gamma applier can run.  To verify
the complete `DEGAMMA_LUT + CTM + GAMMA_LUT` path, pause the session briefly on
another VT (which releases DRM master) and run the self test; it always switches
back:

```bash
sudo chvt 3
sudo acm-ctl selftest --card /dev/dri/card0   # i915 has no display attached
sudo chvt 2
```

Expected output: `degamma/gamma max deviation 0.000008 OK`, `ctm 0.000000 OK`,
`selftest: PASS`.
