{ config, pkgs, lib, ... }:

let
  craft = import ./common.nix { inherit pkgs lib; };

  cadcraft = pkgs.rustPlatform.buildRustPackage rec {
    pname = "cadcraft";
    version = "0.3.0";
    rev = "59631c8d4f9ffe6c08c5c2065ea17504e53bf821";
    appId = "ai.storyteller.cadcraft";

    src = pkgs.fetchFromGitHub {
      owner = "storytold";
      repo = "cadcraft";
      inherit rev;
      hash = "sha256-VFw6np9BSOdBQrKlIiNnQ0kKKNfGnYMctbceBpmE778=";
    };

    cargoHash = "sha256-R0nr3XMPU8nL9qV05bHDqW0YGa3pk3mu4kXIF31pm2U=";

    cargoBuildFlags = [
      "-p"
      "cadcraft"
      "-p"
      "cadcraft-cli"
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
        "cadcraft"
        "cadcraft-cli"
      ];
    };

    meta = with lib; {
      description = "Open-source native CAD editor (clean-room AutoCAD-class workflow)";
      homepage = "https://github.com/storytold/cadcraft";
      license = with licenses; [
        mit
        asl20
      ];
      maintainers = [ ];
    };
  };
in
{
  home.packages = [ cadcraft ];
}
