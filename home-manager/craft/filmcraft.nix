{ config, pkgs, lib, ... }:

let
  craft = import ./common.nix { inherit pkgs lib; };

  filmcraft = pkgs.rustPlatform.buildRustPackage rec {
    pname = "filmcraft";
    version = "0.4.0";
    rev = "5231852443363f001c3f6b396dd9b1e6461ae2be";
    appId = "ai.storyteller.filmcraft";

    src = pkgs.fetchFromGitHub {
      owner = "storytold";
      repo = "filmcraft";
      inherit rev;
      hash = "sha256-qM8o8rSiiGBif0UePQpn6aAEzqbjIMx3ZRoE3wA1yFI=";
    };

    cargoHash = "sha256-uzDeo+94RAK/flnYgTic167BeYfk2zqwwf/ODbwnok0=";

    cargoBuildFlags = [
      "-p"
      "filmcraft"
      "-p"
      "filmcraft-cli"
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
        "filmcraft"
        "filmcraft-cli"
      ];
    };

    meta = with lib; {
      description = "Open-source native video editor (clean-room Premiere-class workflow)";
      homepage = "https://github.com/storytold/filmcraft";
      license = with licenses; [
        mit
        asl20
      ];
      maintainers = [ ];
    };
  };
in
{
  home.packages = [ filmcraft ];
}
