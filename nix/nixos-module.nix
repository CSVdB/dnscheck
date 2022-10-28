{ dnscheck }:
{ lib, pkgs, config, ... }:
with lib;

{
  options.services.dnscheck = {
    enable = mkEnableOption "DNS Checker";
    checks = mkOption {
      default = [ ];
      type = types.listOf (
        types.submodule {
          options = {
            type = mkOption {
              type = types.str;
              example = "a";
              description = "The type of record to check";
            };
            domain = mkOption {
              type = types.str;
              example = "cs-syd.eu";
              description = "The domain to query";
            };
            values = mkOption {
              type = types.listOf types.str;
              example = [ "52.211.121.166" ];
              default = [ ];
              description = "The value to expect in the dns response";
            };
          };
        }
      );
    };
    verbatimConfig = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Verbatim configuration, only used when 'checks' is []";
    };
    onCalendar = mkOption {
      type = types.str;
      default = "hourly";
      description = "The OnCalendar part of the systemd timer";
    };
    notifyCommand = mkOption {
      type = types.str;
      default = "false";
      description = "The command to pass the output to in case of a failure";
    };
  };
  config.systemd =
    let
      cfg = config.services.dnscheck;
      dnscheckName = "dnscheck";
      dnscheckTimer = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = cfg.onCalendar;
          Persistent = true;
        };
      };
      configFile =
        if cfg.checks == [ ] && !builtins.isNull cfg.verbatimConfig
        then pkgs.writeText "dnscheck-config-file" cfg.verbatimConfig
        else
          (pkgs.formats.yaml { }).generate "dnscheck-config.yaml" {
            checks = cfg.checks;
          };
      dnscheckService = {
        description = "DNS Checker";
        path = [ dnscheck ];
        script = ''
          set +e # We need error codes to work this way.

          tmpfile=~/.dnscheck
          ${dnscheck}/bin/dnscheck ${configFile} 2>&1 > "$tmpfile"
          if [[ "$?" != "0" ]]
          then
            cat "$tmpfile" | ${cfg.notifyCommand}
          fi
          rm -f "$tmpfile"
        '';
      };
    in
    mkIf cfg.enable {
      timers = { "${dnscheckName}" = dnscheckTimer; };
      services = { "${dnscheckName}" = dnscheckService; };
    };
}
