{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.jupyter-nlp;
  
  # Python environment with all required packages
  pythonEnv = pkgs.python3.withPackages (ps: with ps; [
    jupyter
    jupyterlab
    notebook
    pyspark
    findspark
    datasets
    nltk
    langid
    requests
    numpy
    pandas
    scikit-learn
    ipykernel
    pip
    pydantic
    typing-extensions
    packaging
    atproto
  ]);

in

{
  options.services.jupyter-nlp = {
    enable = mkEnableOption "Jupyter NLP server for hate speech analysis";

    port = mkOption {
      type = types.port;
      default = 8888;
      description = "Port for Jupyter server";
    };

    host = mkOption {
      type = types.str;
      default = "0.0.0.0";
      description = "Host address to bind to";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/jupyter-nlp";
      description = "Directory for Jupyter notebooks and data";
    };

    user = mkOption {
      type = types.str;
      default = "jupyter";
      description = "User to run Jupyter as";
    };

    group = mkOption {
      type = types.str;
      default = "jupyter";
      description = "Group to run Jupyter as";
    };

    passwordHash = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "sha1:abcd1234:efgh5678";
      description = "Password hash for Jupyter access. Generate with: python -c \"from notebook.auth import passwd; print(passwd())\"";
    };
  };

  config = mkIf cfg.enable {
    # Create user and group
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.dataDir;
      createHome = true;
      description = "Jupyter NLP service user";
    };

    users.groups.${cfg.group} = {};

    # Install required packages
    environment.systemPackages = with pkgs; [
      pythonEnv
      spark
      openjdk11
    ];

    # Set environment variables
    environment.variables = {
      JAVA_HOME = "${pkgs.openjdk11}/lib/openjdk";
      SPARK_HOME = "${pkgs.spark}";
      PYSPARK_PYTHON = "${pythonEnv}/bin/python";
      PYSPARK_DRIVER_PYTHON = "${pythonEnv}/bin/python";
    };

    # Jupyter service
    systemd.services.jupyter-nlp = {
      description = "Jupyter NLP Server";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.dataDir;
        ExecStartPre = [
          # Create data directory structure
          "${pkgs.coreutils}/bin/mkdir -p ${cfg.dataDir}/notebooks"
          "${pkgs.coreutils}/bin/mkdir -p ${cfg.dataDir}/.jupyter"
          # Fix permissions
          "${pkgs.coreutils}/bin/chown -R ${cfg.user}:${cfg.group} ${cfg.dataDir}"
          # Download NLTK data
          #"${pkgs.su}/bin/su -s ${pkgs.bash}/bin/bash ${cfg.user} -c 'cd ${cfg.dataDir} && ${pythonEnv}/bin/python -c \"import nltk; nltk.download(\\\"averaged_perceptron_tagger\\\", download_dir=\\\"${cfg.dataDir}/nltk_data\\\"); nltk.download(\\\"averaged_perceptron_tagger_eng\\\", download_dir=\\\"${cfg.dataDir}/nltk_data\\\"); nltk.download(\\\"stopwords\\\", download_dir=\\\"${cfg.dataDir}/nltk_data\\\"); nltk.download(\\\"wordnet\\\", download_dir=\\\"${cfg.dataDir}/nltk_data\\\"); nltk.download(\\\"punkt\\\", download_dir=\\\"${cfg.dataDir}/nltk_data\\\")\"'"
        ];
        ExecStart = "${pythonEnv}/bin/jupyter lab --ip=${cfg.host} --port=${toString cfg.port} --no-browser --allow-root --notebook-dir=${cfg.dataDir}/notebooks" + 
          (if cfg.passwordHash != null then " --ServerApp.password='${cfg.passwordHash}'" else " --ServerApp.token=''");
        Restart = "always";
        RestartSec = 10;

        # Security settings
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ cfg.dataDir ];
      };

      environment = {
        JAVA_HOME = "${pkgs.openjdk11}/lib/openjdk";
        SPARK_HOME = "${pkgs.spark}";
        PYSPARK_PYTHON = "${pythonEnv}/bin/python";
        PYSPARK_DRIVER_PYTHON = "${pythonEnv}/bin/python";
        NLTK_DATA = "${cfg.dataDir}/nltk_data";
      };
    };

    # Firewall configuration
    networking.firewall.allowedTCPPorts = [ cfg.port ];

    # Log rotation
    services.logrotate.settings.jupyter-nlp = {
      files = "/var/log/jupyter-nlp.log";
      frequency = "weekly";
      rotate = 4;
      compress = true;
      delaycompress = true;
      missingok = true;
      notifempty = true;
    };
  };
}

