{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    inputs.pi-flake.homeManagerModules.default
  ];

  programs.pi-coding-agent = {
    enable = true;
    package = inputs.pi-flake.packages.${pkgs.stdenv.hostPlatform.system}.default;
    models = {
      providers = {
        ollama = {
          baseUrl = "http://172.16.32.133:11435/v1";
          api = "openai-completions";
          apiKey = "ollama";
          models = [
            { id = "qwen2.5-coder:1.5b"; }
            { id = "qwen2.5-coder:3b"; }
            { id = "qwen2.5-coder:7b"; }
            { id = "qwen2.5-coder:7b-instruct-q8_0"; }
            { id = "devstral:24b"; }
            { id = "qwen3-coder:30b"; }
            { id = "qwen2.5-coder:32b"; }
          ];
        };
      };
    };
  };

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
