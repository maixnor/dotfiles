{ config, pkgs, lib, ... }:

{
  age.secrets.odoo_db_password.file = ../secrets/odoo_db_password.age;

  systemd.services.odoo-env-setup = {
    description = "Generate Odoo environment files";
    wantedBy = [ "multi-user.target" ];
    before = [ "podman-odoo-db.service" "podman-odoo.service" ];
    requiredBy = [ "podman-odoo-db.service" "podman-odoo.service" ];
    script = ''
      DB_PASS=$(cat ${config.age.secrets.odoo_db_password.path})
      
      cat > /var/lib/odoo-secrets.env <<EOF
USER=odoo
PASSWORD=''${DB_PASS}
EOF

      cat > /var/lib/odoo-db-secrets.env <<EOF
POSTGRES_USER=odoo
POSTGRES_PASSWORD=''${DB_PASS}
POSTGRES_DB=postgres
EOF

      chmod 600 /var/lib/odoo-secrets.env /var/lib/odoo-db-secrets.env
    '';
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
  };

  virtualisation.oci-containers.containers = {
    odoo-db = {
      image = "postgres:15";
      environmentFiles = [ "/var/lib/odoo-db-secrets.env" ];
      volumes = [
        "odoo-db-data:/var/lib/postgresql/data"
      ];
      extraOptions = [ "--network=host" ];
    };

    odoo = {
      image = "odoo:17.0";
      environmentFiles = [ "/var/lib/odoo-secrets.env" ];
      environment = {
        HOST = "127.0.0.1";
      };
      volumes = [
        "odoo-web-data:/var/lib/odoo"
      ];
      ports = [
        "8069:8069"
        "8072:8072" # Realtime communication/longpolling
      ];
      dependsOn = [ "odoo-db" ];
      extraOptions = [ "--network=host" ];
    };
  };

  networking.firewall.allowedTCPPorts = [ 8069 8072 ];
}
