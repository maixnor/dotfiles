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
          baseUrl = "http://172.16.32.133:8080/api/v1";
          api = "openai-completions";
          apiKey = "sk-eadaa0312689422ba59ae69ba540a78c";
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

  home.file.".config/opencode/opencode.json".text = builtins.toJSON ({
    "$schema" = "https://opencode.ai/config.json";
    provider = {
      ollama = {
        npm = "ollama-ai-provider-v2";
        name = "Ollama";
        options = {
          baseURL = "http://172.16.32.133:11434/api";
          apiKey = "sk-this-is-just-a-dummy";
        };
        models = {
          "qwen2.5-coder:1.5b" = { name = "Qwen2.5 Coder (1.5B)"; };
          "qwen2.5-coder:3b" = { name = "Qwen2.5 Coder (3B)"; };
          "qwen2.5-coder:7b" = { name = "Qwen2.5 Coder (7B)"; };
          "qwen2.5-coder:7b-instruct-q8_0" = { name = "Qwen2.5 Coder (7B Q8)"; };
          "devstral:24b" = { name = "Devstral (24B)"; };
          "qwen3-coder:30b" = { name = "Qwen3 Coder (30B)"; };
          "qwen2.5-coder:32b" = { name = "Qwen2.5 Coder (32B)"; };
        };
      };
    };
  });

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

  home.sessionVariables = {
    ANTHROPIC_BASE_URL = "http://172.16.32.133:11434";
    ANTHROPIC_API_KEY = "sk-this-is-just-a-dummy";
  };
}
