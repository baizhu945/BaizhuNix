{ config, pkgs, lib, ... }:

let
  craft = import ./common.nix { inherit pkgs lib; };

  # PhotoCraft UI language (BCP 47). Override via home.sessionVariables if needed.
  photocraftLocale =
    let
      lang =
        config.home.sessionVariables.LANG
          or config.home.sessionVariables.LC_MESSAGES
          or "";
      lower = lib.toLower lang;
      fromLang =
        if lib.hasInfix "zh_tw" lower || lib.hasInfix "zh-hant" lower || lib.hasInfix "zh_hk" lower
        then "zh-hant"
        else if lib.hasInfix "zh" lower then "zh-hans"
        else if lib.hasInfix "ja" lower then "ja"
        else if lib.hasInfix "ko" lower then "ko"
        else null;
    in
    if fromLang != null then fromLang else "zh-hans";

  photocraft = pkgs.rustPlatform.buildRustPackage rec {
    pname = "photocraft";
    version = "0.3.0";
    rev = "ec7302f4b3d1f1c530ac39e744ccb17301d4ccda";
    appId = "ai.storyteller.photocraft";

    src = pkgs.fetchFromGitHub {
      owner = "storytold";
      repo = "photocraft";
      inherit rev;
      hash = "sha256-WdYYA2b5jzf9rqSe8X6J2FoTplq8JTz20EN61QiL0wA=";
    };

    cargoHash = "sha256-iRn6y8CxCEkJEiiYzjAgMqAnWck1+68Hhokk4HzF3sI=";

    buildFeatures = [ "heif" ];

    cargoBuildFlags = [
      "-p"
      "photocraft"
      "-p"
      "photocraft-cli"
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

    postFixup =
      craft.wrapCraftGuiBins {
        bins = [
          "photocraft"
          "photocraft-cli"
        ];
        extraEnv = [
          {
            name = "PHOTOCRAFT_LOCALE";
            value = photocraftLocale;
          }
        ];
      };

    meta = with lib; {
      description = "Open-source native image editor (clean-room Photoshop-class workflow)";
      homepage = "https://github.com/storytold/photocraft";
      license = licenses.mit;
      maintainers = [ ];
    };
  };
in
{
  home.sessionVariables.PHOTOCRAFT_LOCALE = lib.mkDefault photocraftLocale;

  home.packages = [
    photocraft
    pkgs.noto-fonts-cjk-sans
    pkgs.wqy_zenhei
  ];
}
