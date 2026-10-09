{ config, pkgs, lib, ... }:

let
  craft = import ./common.nix { inherit pkgs lib; };

  soundcraft = pkgs.rustPlatform.buildRustPackage rec {
    pname = "soundcraft";
    version = "0.3.0";
    rev = "c51e5d5ec52f11c6264b72e26661fa712feb5345";
    appId = "ai.storyteller.soundcraft";

    src = pkgs.fetchFromGitHub {
      owner = "storytold";
      repo = "soundcraft";
      inherit rev;
      hash = "sha256-VdTwPoLrLq3XxevWWo06WF16f/6/+x9cQ/kS3swkreE=";
    };

    cargoHash = "sha256-3ujhZk0bkdDuRPX6z6fTliHzjuaVGrdcXCyMu7906Uk=";

    cargoBuildFlags = [
      "-p"
      "soundcraft"
      "-p"
      "soundcraft-cli"
    ];

    env.CRAFT_FONTS_DIR = craft.craftFonts;

    nativeBuildInputs = craft.craftNativeBuildInputs;
    buildInputs = craft.craftLinuxDeps;

    doCheck = false;

    postPatch = craft.patchCjkFontPaths;

    postInstall = ''
      install -Dm644 packaging/linux/${appId}.desktop \
        $out/share/applications/${appId}.desktop
      install -Dm644 packaging/linux/${appId}.mime.xml \
        $out/share/mime/packages/${appId}.xml
      cp -R assets/app-icon/hicolor $out/share/icons/
    '';

    postFixup = craft.wrapCraftGuiBins {
      bins = [
        "soundcraft"
        "soundcraft-cli"
      ];
    };

    meta = with lib; {
      description = "Open-source native digital audio workstation (clean-room Audition-class workflow)";
      homepage = "https://github.com/storytold/soundcraft";
      license = with licenses; [
        mit
        asl20
      ];
      maintainers = [ ];
    };
  };
in
{
  home.packages = [ soundcraft ];
}
