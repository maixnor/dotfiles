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
  ]);
  
  # Preproc.py file content
  preprocPy = pkgs.writeText "preproc.py" ''
    """
    Preprocessing functions for NLP tasks
    """
    
    import re
    import nltk
    from nltk.corpus import stopwords
    from nltk.stem import WordNetLemmatizer
    import langid
    
    # Initialize NLTK components
    lemmatizer = WordNetLemmatizer()
    
    def check_lang(text):
        """Detect language of the text"""
        try:
            lang, confidence = langid.classify(text)
            return lang
        except:
            return "unknown"
    
    def remove_stops(text):
        """Remove stopwords from text"""
        try:
            stop_words = set(stopwords.words('english'))
            words = text.split()
            filtered_words = [word for word in words if word.lower() not in stop_words]
            return ' '.join(filtered_words)
        except:
            return text
    
    def clean_text(text):
        """Clean text by removing special characters, URLs, etc."""
        if not text:
            return ""
        
        # Remove URLs
        text = re.sub(r'http\S+|www\S+|https\S+', \'\', text, flags=re.MULTILINE)
        
        # Remove user mentions and hashtags
        text = re.sub(r'@\w+|#\w+', '', text)
        
        # Remove special characters and digits
        text = re.sub(r'[^a-zA-Z\s]', '', text)
        
        # Remove extra whitespace
        text = re.sub(r'\s+', ' ', text).strip()
        
        return text.lower()
    
    def pos_tag_text(text):
        """Apply POS tagging to text"""
        try:
            tokens = nltk.word_tokenize(text)
            pos_tags = nltk.pos_tag(tokens)
            return ' '.join([f"{word}_{tag}" for word, tag in pos_tags])
        except:
            return text
    
    def lemmatize_text(text):
        """Lemmatize text"""
        try:
            words = text.split()
            lemmatized = [lemmatizer.lemmatize(word) for word in words]
            return ' '.join(lemmatized)
        except:
            return text
    
    def is_blank(text):
        """Check if text is blank or empty"""
        return not text or text.strip() == ""
    
    def preprocess_full(text):
        """Full preprocessing pipeline"""
        if is_blank(text):
            return ""
        
        # Clean text
        cleaned = clean_text(text)
        
        # Remove stopwords
        no_stops = remove_stops(cleaned)
        
        # Lemmatize
        lemmatized = lemmatize_text(no_stops)
        
        return lemmatized
  '';

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
          # Copy preproc.py to data directory
          "${pkgs.coreutils}/bin/cp ${preprocPy} ${cfg.dataDir}/notebooks/preproc.py"
          # Fix permissions
          "${pkgs.coreutils}/bin/chown -R ${cfg.user}:${cfg.group} ${cfg.dataDir}"
          # Download NLTK data
          "${pkgs.su}/bin/su -s ${pkgs.bash}/bin/bash ${cfg.user} -c 'cd ${cfg.dataDir} && ${pythonEnv}/bin/python -c \"import nltk; nltk.download(\\\"averaged_perceptron_tagger\\\", download_dir=\\\"${cfg.dataDir}/nltk_data\\\"); nltk.download(\\\"averaged_perceptron_tagger_eng\\\", download_dir=\\\"${cfg.dataDir}/nltk_data\\\"); nltk.download(\\\"stopwords\\\", download_dir=\\\"${cfg.dataDir}/nltk_data\\\"); nltk.download(\\\"wordnet\\\", download_dir=\\\"${cfg.dataDir}/nltk_data\\\"); nltk.download(\\\"punkt\\\", download_dir=\\\"${cfg.dataDir}/nltk_data\\\")\"'"
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

