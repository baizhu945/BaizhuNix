# NekoMoteAssets v0.6.2. Returns the repository root; use "${root}/assets".
# Upstream declares CC BY-NC-SA 4.0 for the assets, not the player's license.
{ fetchzip }:
fetchzip {
  name = "source"; # Match nix-prefetch-url --unpack --name source.
  url = "https://codeload.github.com/Chocola-X/NekoMoteAssets/tar.gz/faa78f61e00df31077016a45289a529ffb6a8c50";
  extension = "tar.gz";
  hash = "sha256-1jWjIsEmyu6OXqkiChgt/mBYCD5n3yFPvX+eYQpBpkY=";
}
