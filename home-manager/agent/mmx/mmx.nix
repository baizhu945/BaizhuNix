{ config, pkgs, lib, ... }:

let
  version = "1.0.22";
  rev = "a3beefa4fa11400fdb0b4cf28b1fb7b022dba8da";

  src = pkgs.fetchFromGitHub {
    owner = "MiniMax-AI";
    repo = "cli";
    inherit rev;
    hash = "sha256-ZhF64E+UzangVvF4v5JV60UpRueUh1I/B5jysChwHNs=";
  };

  # The upstream project uses Bun and ships bun.lock, while its stale
  # package-lock.json does not match package.json. Vendor the exact Bun
  # dependency tree in a fixed-output derivation, then build the CLI with the
  # same pinned source tree.
  nodeModules = pkgs.stdenvNoCC.mkDerivation {
    pname = "mmx-cli-node-modules";
    inherit version src;

    nativeBuildInputs = [
      pkgs.bun
      pkgs.writableTmpDirAsHomeHook
    ];

    dontConfigure = true;

    buildPhase = ''
      runHook preBuild

      export BUN_INSTALL_CACHE_DIR=$(mktemp -d)
      bun install \
        --cpu="*" \
        --os="*" \
        --frozen-lockfile \
        --ignore-scripts \
        --no-progress

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out
      find . -type d -name node_modules -exec cp -R --parents {} $out \;

      runHook postInstall
    '';

    # Store paths and build-time environment must not enter this FOD.
    dontFixup = true;
    outputHash = "sha256-pVtR5Xz9HMQcYL9yMrTf2CA41VNYu2pSJq14Aif+lWg=";
    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
  };

  mmx = pkgs.stdenvNoCC.mkDerivation {
    pname = "mmx-cli";
    inherit version src;

    nativeBuildInputs = [
      pkgs.bun
      pkgs.makeWrapper
    ];

    configurePhase = ''
      runHook preConfigure

      cp -R ${nodeModules}/. .

      runHook postConfigure
    '';

    buildPhase = ''
      runHook preBuild

      VERSION=${version} bun run build

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/bin $out/lib/mmx-cli $out/share/mmx-cli
      cp -R dist node_modules package.json $out/lib/mmx-cli/
      cp -R skill $out/share/mmx-cli/
      cp README.md README_CN.md $out/share/mmx-cli/

      makeWrapper ${lib.getExe pkgs.nodejs} $out/bin/mmx \
        --add-flags "$out/lib/mmx-cli/dist/mmx.mjs"

      runHook postInstall
    '';

    doInstallCheck = true;
    installCheckPhase = ''
      runHook preInstallCheck

      $out/bin/mmx --version
      $out/bin/mmx config export-schema --command "text chat" >/dev/null

      runHook postInstallCheck
    '';

    meta = {
      description = "Official MiniMax AI Platform CLI";
      homepage = "https://github.com/MiniMax-AI/cli";
      license = lib.licenses.mit;
      mainProgram = "mmx";
      platforms = lib.platforms.unix;
      sourceProvenance = with lib.sourceTypes; [ fromSource ];
    };
  };

  # Keep the same skill set as pi-coding-agent, but pin every Git source to a
  # commit so the mmx integration is reproducible as well.
  anbeimeSkillsRepo = builtins.fetchGit {
    url = "https://github.com/anbeime/skill.git";
    rev = "752499feb9e7832dadb76039c67ab40afdc49be8";
  };

  anthropicsSkillsRepo = builtins.fetchGit {
    url = "https://github.com/anthropics/skills.git";
    rev = "3b3fad96af16a10759d930941b4520ba0c40edae";
  };

  agentSkillsRepo = builtins.fetchGit {
    url = "https://github.com/addyosmani/agent-skills.git";
    rev = "5a5ea45e806f82273549fd85e60adb95d55f510d";
  };

  commonSkills = {
    "cc-connect-cron" = ../skills/cc-connect-cron;
    "cc-connect-send" = ../skills/cc-connect-send;
    "chrome-automation" = ../skills/chrome-automation;

    "docx" = "${anthropicsSkillsRepo}/skills/docx";
    "pptx" = "${anthropicsSkillsRepo}/skills/pptx";
    "xlsx" = "${anthropicsSkillsRepo}/skills/xlsx";
    "pdf" = "${anthropicsSkillsRepo}/skills/pdf";
    "canvas-design" = "${anthropicsSkillsRepo}/skills/canvas-design";

    "media-processor" = "${anbeimeSkillsRepo}/skills/media-processor/media-processor";
    "idea-refine" = "${agentSkillsRepo}/skills/idea-refine";
    "mmx-cli" = "${mmx}/share/mmx-cli/skill";
  };

  universalSkillFiles = lib.mapAttrs' (
    name: source:
    lib.nameValuePair ".agents/skills/${name}" {
      inherit source;
      recursive = true;
    }
  ) commonSkills;
in
{
  home.packages = [ mmx ];

  home.file = universalSkillFiles // {
    # Universal agent context and skills directory used by the skills CLI.
    ".agents/AGENTS.md".source = ../agent-context.md;
  };
}
