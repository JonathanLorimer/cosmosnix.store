{ inputs, config, lib, ... }:
{
  imports = [
    inputs.attic.nixosModules.atticd
  ];

  services.atticd = {
    enable = true;

    credentialsFile = config.age.secrets.atticServerToken.path;

    settings = {
      listen = "[::]:8080";

      chunking = {
        nar-size-threshold = 0;
        min-size = 0;
        avg-size = 0;
        max-size = 0;
      };

      compression.type = "none";

      storage = {
        type = "s3";
        region = "us-east-1";
        endpoint = ""; ## TODO: replace with actual s3 endpoint
        bucket = "attic";
      };

      garbage-collection = {
        interval = "2 weeks";
        default-retention-period = "3 months";
      };
    };
  };

  users = {
    users.atticd = {
      isSystemUser = true;
      group = "atticd";
      home = "/var/lib/atticd";
      createHome = true;
    };
    groups.atticd = {};
  };

  services.caddy = {
    enable = true;
    virtualHosts."example.org".extraConfig = ''
      reverse_proxy http://localhost:8080
    '';
  };
}
