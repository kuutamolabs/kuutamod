{ makeTest' }:
makeTest' {
  name = "single-node-kuutamod";
  nodes.server = { lib, ... }: {
    imports = [
      ../neard/mainnet
      ../kuutamod
    ];

    services.consul.interface.bind = "eth0";
    # our consul wants an ipv6 address
    networking.interfaces.eth0 = {
      ipv6.addresses = [
        {
          address = "2001:1470:fffd:2097::";
          prefixLength = 64;
        }
      ];
    };
    services.consul.extraConfig.bootstrap_expect = 1;

    kuutamo.kuutamod.validatorKeyFile = ./validator_key.json;
    kuutamo.kuutamod.validatorNodeKeyFile = ./node_key.json;
  };

  testScript = ''
    start_all()
    server.wait_for_unit("kuutamod.service")
    server.wait_for_unit("consul.service")
    # wait until consul is up
    server.wait_until_succeeds("curl --silent 127.0.0.1:8500/v1/status/leader")

    # kuutamod prometheus endpoint
    server.wait_until_succeeds("curl --silent http://127.0.0.1:2233/metrics | grep -q 'kuutamod_state{type=\"Syncing\"} 1'")
    # neard prometheus endpoint
    server.succeed("curl --silent http://127.0.0.1:3030/metrics")

    # check that node_key is set up, but not validator key
    server.succeed("[[ ! -f /var/lib/neard/validator_key.json ]]")
    server.succeed("[[ -f /var/lib/neard/node_key.json ]]")
  '';
}
