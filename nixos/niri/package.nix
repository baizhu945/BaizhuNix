{
  pkgs ? import <nixpkgs> { },
  src ? pkgs.lib.cleanSource ../.,
  revision ? "worktree",
  withNvidiaReadFenceWorkaround ? true,
}:

pkgs.niri.overrideAttrs (finalAttrs: old: {
  version = "26.04-unstable-2026-11-14";
  inherit src;

  cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
    name = "niri-memory-fixes";
    inherit src;
    hash = "sha256-rLVTigIUf8rxn25bVdjVyOqPPjBq8KpKINoXQ/gFYxI=";
  };

  # cargoSetupPostUnpackHook gives us a writable dependency copy. Git-sourced
  # crates have an empty files checksum map; Cargo.lock remains unchanged.
  postPatch = (old.postPatch or "") + pkgs.lib.optionalString withNvidiaReadFenceWorkaround ''
    echo "Applying local NVIDIA unshared-context read-fence mitigation"
    patch --batch --forward --fuzz=0 \
      --directory="$cargoDepsCopy/source-git-0/smithay-0.7.0" --strip=1 \
      < ${src}/nix/smithay-nvidia-read-fences.patch
  '';

  env = (old.env or { }) // {
    NIRI_BUILD_COMMIT = revision;
    NIRI_BUILD_VERSION_STRING = "${finalAttrs.version} (<yourusername>/${builtins.substring 0 12 revision})";
  };
})
