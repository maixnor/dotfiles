{ config, pkgs, lib, inputs, ... }:

let
  allModelNames = [
    "qwen2.5-coder:1.5b" "qwen2.5-coder:1.5b-fast" "qwen2.5-coder:1.5b-long"
    "qwen2.5-coder:3b" "qwen2.5-coder:3b-fast" "qwen2.5-coder:3b-long"
    "qwen2.5-coder:7b" "qwen2.5-coder:7b-fast" "qwen2.5-coder:7b-long"
    "qwen2.5-coder:7b-instruct-q8_0"
    "devstral:24b" "devstral:24b-fast" "devstral:24b-long"
    "qwen3-coder:30b" "qwen3-coder:30b-fast" "qwen3-coder:30b-long"
    "qwen2.5-coder:32b" "qwen2.5-coder:32b-fast" "qwen2.5-coder:32b-long"
    "qwen3.6-heretic:40b" "qwen3.6-heretic:40b-fast" "qwen3.6-heretic:40b-long"
    "llama3.2-moe-heretic:10b"
    "deepseek-coder-v2:lite"
  ];

  piModels = map (m: { id = m; }) allModelNames;
  opencodeModels = lib.listToAttrs (map (m: { name = m; value = { name = m; }; }) allModelNames);
in
{
  imports = [
    inputs.pi-flake.homeManagerModules.default
  ];

  programs.pi-coding-agent = {
    enable = true;
    package = inputs.pi-flake.packages.${pkgs.stdenv.hostPlatform.system}.default;
    agentFiles.models.value = {
      providers = {
        ollama = {
          baseUrl = "http://172.16.32.133:11434/v1";
          api = "openai-completions";
          apiKey = "sk-eadaa0312689422ba59ae69ba540a78c";
          models = piModels;
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
        models = opencodeModels;
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
