{ config, lib, pkgs, ... }:

let
  zcodeVersion = "3.14.0";
  zcodeRev = "872ad960de7ec172591f7e1952f7849229f94521";
  zcodeSrc = pkgs.fetchFromGitHub {
    owner = "zai-org";
    repo = "ZCode";
    rev = zcodeRev;
    hash = "sha256-H2lGuzdUM01mJ9VNpZ2w4DAdrv2lw2dsZL9marGvIN4=";
  };

  zcodePnpmDeps = pkgs.fetchPnpmDeps {
    pname = "zcode-cli";
    version = zcodeVersion;
    src = zcodeSrc;
    pnpm = pkgs.pnpm_10;
    pnpmWorkspaces = [ "." "@zcode/cli..." ];
    fetcherVersion = 4;
    hash = "sha256-ympMfiw9zfKLLpf/y8Xy97xS+iLvKduxDljjuak5QJY=";
  };

  zcode = pkgs.stdenv.mkDerivation {
    pname = "zcode";
    version = zcodeVersion;
    src = zcodeSrc;

    nativeBuildInputs = [
      pkgs.nodejs_24
      pkgs.pnpm_10
      pkgs.pnpmConfigHook
    ];

    pnpmDeps = zcodePnpmDeps;
    pnpmWorkspaces = [ "." "@zcode/cli..." ];

    preBuild = ''
      pnpm config set manage-package-manager-versions false
      # pnpm workspace .bin links are outside pnpmConfigHook's root patchShebangs glob.
      # Patch their real targets so Nix's sandbox does not depend on /usr/bin/env.
      while IFS= read -r -d "" link; do
        target=$(readlink -f "$link")
        if [ -f "$target" ]; then
          patchShebangs "$target"
        fi
      done < <(find . -path '*/node_modules/.bin/*' -type l -print0)
      pnpm --filter @zcode/dynamic-workflow build
      test -f apps/zcode-cli/packages/dynamic-workflow/dist/index.d.ts
      export ZCODE_ENV=production
      pnpm --workspace-concurrency=1 --filter @zcode/cli... build
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/libexec"
      mkdir -p "$out/libexec/zcode/dist" "$out/libexec/zcode/node_modules/@zcode/tui"
      cp -a apps/zcode-cli/packages/cli/dist/. "$out/libexec/zcode/dist/"
      cp -a apps/zcode-cli/packages/cli/package.json "$out/libexec/zcode/"
      cp -a apps/zcode-cli/packages/tui/dist "$out/libexec/zcode/node_modules/@zcode/tui/"
      cp -a apps/zcode-cli/packages/tui/package.json "$out/libexec/zcode/node_modules/@zcode/tui/"

      # The CLI bundle intentionally leaves only a small runtime closure external:
      # TUI/native rendering, Playwright, and koffi. Copy that closure from the
      # already offline-installed pnpm tree, without running package lifecycle code.
      node --input-type=module <<'NODE'
import fs from "node:fs";
import path from "node:path";

const sourceRoot = path.resolve("node_modules");
const targetRoot = path.resolve(process.env.out, "libexec/zcode/node_modules");
const roots = [
  "@mbears/opentui-core",
  "@mbears/opentui-react",
  "react",
  "react-devtools-core",
  "shiki",
  "web-tree-sitter",
  "ws",
  "playwright-core",
  "koffi",
];
const seen = new Set();

function packagePath(name, start) {
  for (let current = start; ; current = path.dirname(current)) {
    const candidate = path.join(current, "node_modules", name);
    if (fs.existsSync(path.join(candidate, "package.json"))) return fs.realpathSync(candidate);
    const parent = path.dirname(current);
    if (parent === current) break;
  }
  throw new Error(`runtime dependency not found: ''${name} from ''${start}`);
}

function copyPackage(name, start = process.cwd()) {
  const source = packagePath(name, start);
  const key = `''${name}\0''${source}`;
  if (seen.has(key)) return;
  seen.add(key);
  const manifest = JSON.parse(fs.readFileSync(path.join(source, "package.json"), "utf8"));
  const target = path.join(targetRoot, name);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.cpSync(source, target, {
    recursive: true,
    dereference: true,
    filter: (entry) => {
      const relative = path.relative(source, entry);
      return relative === "" || !relative.split(path.sep).includes("node_modules");
    },
  });
  const dependencies = {
    ...(manifest.dependencies ?? {}),
    ...(manifest.optionalDependencies ?? {}),
  };
  for (const dependency of Object.keys(dependencies)) copyPackage(dependency, source);
}

for (const root of roots) copyPackage(root, sourceRoot);
NODE

      mkdir -p "$out/bin"
      cat > "$out/bin/zcode" <<EOF
#!${pkgs.runtimeShell}
exec ${pkgs.nodejs_24}/bin/node "$out/libexec/zcode/dist/zcode.cjs" "\$@"
EOF
      chmod 0555 "$out/bin/zcode"

      runHook postInstall
    '';

    meta = {
      description = "ZCode AI coding agent CLI";
      homepage = "https://github.com/zai-org/ZCode";
      license = lib.licenses.asl20;
      mainProgram = "zcode";
      platforms = lib.platforms.linux;
    };
  };
in
{
  home.packages = [ zcode ];

  # ZCode CLI automatically loads ~/.zcode/AGENTS.md as the user-level context.
  home.file = {
    ".zcode/AGENTS.md".source = ../agent-context.md;
  };
}
