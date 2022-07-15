{ config, lib, pkgs, ... }:
let
  cfg = config.kuutamo.neard;
in
{
  options.kuutamo.neard = {
    enable = lib.mkOption {
      type = lib.types.bool;
      description = "Whether to enable Neard";
      default = true;
    };

    enableSolanaKernelTuning = lib.mkOption {
      type = lib.types.bool;
      description = ''
        Enable kernel optimizations from the solana validator project.
        https://docs.solana.com/de/running-validator/validator-start#system-tuning
        We found those to be effective to avoid bottlenecks and missing blocks
        on near validators as well.
      '';
      default = false;
    };
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ../../pkgs/neard/stable.nix { };
      defaultText = lib.literalExpression "pkgs.neard";
      description = "The neard package to use in our service";
    };
    generateNodeKey = lib.mkOption {
      type = lib.types.bool;
      description = "Whether to generate Node key on boot";
      default = true;
    };

    s3 = {
      dataBackupDirectory = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "s3://near-protocol-public/backups/testnet/rpc/2022-07-12T23:00:50Z";
        description = ''
          S3 backup bucket directory to load initial near database data from
        '';
      };
      dataBackupTarball = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "s3://build.openshards.io/stakewars/shardnet/data.tar.gz";
        description = ''
          S3 backup tarball to load initial near database data from
        '';
      };
      signRequests = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Does not sign requests when downloading from the s3 bucket.
          This needs to be false when using the official near s3 backup bucket.
          Set this to true if you have your own private bucket that needs authentication.
        '';
      };
    };

    configFile = lib.mkOption {
      type = lib.types.path;
      description = "Configuration for the node in json format";
    };

    genesisFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      description = ''
        A file with all the data the network started with at genesis. This contains initial accounts, contracts, access keys, and other records which represents the initial state of the blockchain.
        If not provided, neard will try to download the genesis file.
      '';
    };
    chainId = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        NEAR chain to connect to
      '';
    };
  };

  config = {
    users.users.neard = {
      group = "neard";
      isSystemUser = true;
    };
    users.groups.neard = { };

    boot.kernel.sysctl = lib.mkIf (cfg.enableSolanaKernelTuning) {
      # Increase socket buffer sizes
      "net.core.rmem_default" = "134217728";
      "net.core.rmem_max" = "134217728";
      "net.core.wmem_default" = "134217728";
      "net.core.wmem_max" = "134217728";

      # Increase memory mapped files limit
      "vm.max_map_count" = "1000000";
      # Increase number of allowed open file descriptors
      "fs.nr_open" = "1000000";
    };

    systemd.services.neard = {
      enable = config.kuutamo.neard.enable;
      wantedBy = [ "multi-user.target" ];
      path = [
        pkgs.awscli2
        cfg.package
        pkgs.util-linux
      ] ++ lib.optional (cfg.s3.dataBackupTarball != null) pkgs.libarchive;

      serviceConfig = {
        StateDirectory = "neard";
        TimeoutStartSec = "120min"; # downloading chain data can take some time...
        # this script is run as root
        ExecStartPre = [
          "+${pkgs.writeShellScript "neard-setup" ''
          set -eux -o pipefail
          # Boostrap chain data for new nodes

          install -d -o neard -g neard /var/lib/neard

          if [[ ! -f /var/lib/neard/.finished ]]; then
            ${lib.optionalString (cfg.generateNodeKey) ''
              runuser -u neard -g neard -- ${cfg.package}/bin/neard --home /var/lib/neard init \
                ${lib.optionalString (cfg.chainId != null) "--chain-id=${cfg.chainId}"} \
                ${lib.optionalString (cfg.chainId != null && cfg.genesisFile == null) "--download-genesis"}
            ''}
            ${lib.optionalString (cfg.s3.dataBackupDirectory != null) ''
              runuser -u neard -g neard -- aws s3 sync ${lib.optionalString (!cfg.s3.signRequests) "--no-sign-request"} --delete ${cfg.s3.dataBackupDirectory} /var/lib/neard/data
            ''}
            ${lib.optionalString (cfg.s3.dataBackupTarball != null) ''
              runuser -u neard -g neard -- aws s3 --no-sign-request cp ${cfg.s3.dataBackupTarball} /var/lib/neard/data.tar.gz
              runuser -u neard -g neard -- bsdtar -C /var/lib/neard -xzf /var/lib/neard/data.tar.gz
              rm -rf /var/lib/neard/data.tar.gz
            ''}
            touch /var/lib/neard/.finished
          fi

          # Update configuration
          install -D -m755 -o neard -g neard ${cfg.configFile} /var/lib/neard/config.json
          ${lib.optionalString (cfg.genesisFile != null) ''
            ln -sf ${cfg.genesisFile} /var/lib/neard/genesis.json
          ''}
        ''}"
        ];
        ExecStart = "${cfg.package}/bin/neard --home /var/lib/neard run";
        Restart = "always";

        User = "neard";
        Group = "neard";

        # New file permissions
        UMask = "0027"; # 0640 / 0750

        # Hardening measures
        # Sandboxing (sorted by occurrence in https://www.freedesktop.org/software/systemd/man/systemd.exec.html)

        ProtectSystem = "full";
        Type = "simple";
        ProtectHome = true;
        ProtectHostname = true;
        ProtectClock = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectKernelLogs = true;
        ProtectControlGroups = true;

        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        PrivateMounts = true;
        # We do we have to disable this? Seems to be related to the wasm runtime
        # neard[1711]: thread '<unnamed>' panicked at 'unable to make memory readonly and executable: SystemCall(Os { code: 1, kind: PermissionDenied, message: "Operation not permitted" })', /build/neard-1.25.0-vendor.tar.gz/wasmer-engine-universal-near/src/code_memory.rs:153:10
        #MemoryDenyWriteExecute = true;
        RemoveIPC = true;

        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" ];
        RestrictRealtime = true;
        RestrictSUIDSGID = true;

        LockPersonality = true;

        # Proc filesystem
        ProcSubset = "pid";
        ProtectProc = "invisible";

        RestrictNamespaces = true;

        SystemCallArchitectures = "native";
        # blacklist some syscalls
        SystemCallFilter = [ "~@cpu-emulation @debug @keyring @mount @obsolete @privileged @setuid @ipc" ];
      } // lib.optionalAttrs (cfg.enableSolanaKernelTuning) {
        LimitNOFILE = "1000000";
      };
    };
  };
}
