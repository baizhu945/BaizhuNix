{ config, pkgs, lib, ... }:

let
  craft = import ./common.nix { inherit pkgs lib; };

  wordcraft = pkgs.rustPlatform.buildRustPackage rec {
    pname = "wordcraft";
    version = "0.3.0";
    rev = "7584b9b2930ffddfe7db96b6eba977262e55135c";
    appId = "ai.storyteller.wordcraft";

    src = pkgs.fetchFromGitHub {
      owner = "storytold";
      repo = "wordcraft";
      inherit rev;
      hash = "sha256-uhePuWSXq6uybLviJg4H2Qlb5mlV4OPwryT2vqq+9zU=";
    };

    cargoHash = "sha256-gQvzoEhvC4C1ZpQmr6E4zjRJlVqm54/N2kYe38GaAzs=";

    cargoBuildFlags = [
      "-p"
      "wordcraft"
      "-p"
      "wordcraft-cli"
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
        "wordcraft"
        "wordcraft-cli"
      ];
    };

    meta = with lib; {
      description = "Open-source native word processor (clean-room Word-class workflow)";
      homepage = "https://github.com/storytold/wordcraft";
      license = with licenses; [
        mit
        asl20
      ];
      maintainers = [ ];
    };
  };
in
{
  home.packages = [ wordcraft ];
}
