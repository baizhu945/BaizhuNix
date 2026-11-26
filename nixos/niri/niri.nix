{pkgs, config, lib, ...}:

{
  programs.niri = {
    enable = true;
    useNautilus = false;
    package =
      let
        # memory-fixes 分支中包含打包定义和 NVIDIA read-fence 补丁的提交。
        revision = "ebbb9ff71c44f06e36458cab04c64ef266cc858a";
        src = builtins.fetchTarball {
          url = "https://codeload.github.com/<yourusername>/niri-manual/tar.gz/${revision}";
          sha256 = "sha256-LmSq6tU3i9cJ9ITmifjwnoGYrn5IwuCS8J91zFFVXsk=";
        };
      in
      import ( src + "/nix/package.nix") {
        inherit pkgs src revision;
        withNvidiaReadFenceWorkaround = true;
      };
  };
}
