{ config, pkgs, lib, ... }:

{
  home.packages = with pkgs; [
    unstable.antigravity-cli
    claude-code
    opencode
  ];

  home.file.".config/opencode/opencode.json".source = config.lib.file.mkOutOfStoreSymlink "/run/agenix/opencode.json";

  home.activation.createOpencodeDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD mkdir -p $VERBOSE_ARG "${config.home.homeDirectory}/.config/opencode"
  '';

  home.file.".config/antigravity-cli/settings.json".text = builtins.toJSON ({
    toolPermission = "request-review";
    verbosity = "high";
    renderingMode = "auto";
    colorScheme = "terminal";
    editor = "vim";
    enableTerminalSandbox = true;
    statusLine = {
      enabled = true;
    };
    trustedWorkspaces = [
      "${config.home.homeDirectory}/repo/dotfiles"
    ];
    telemetry = {
      enabled = false;
    };
  });
}
