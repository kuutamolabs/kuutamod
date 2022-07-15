# Run a Kuutamod failover setup

This tutorial is splitted into two parts. First we show how to run kuutamod
locally in [localnet](https://docs.near.org/docs/concepts/networks#localnet).
This allows you to understand how kuutamod works and play around with
failover kuutamod and neard.

The second part shows how to deploy validator ha setup for
[testnet](https://docs.near.org/docs/concepts/networks#testnet) using
[NixOS](https://nixos.org/).

If you want to get an high-level overview of how kuutamod works, you can also
read the [Architecture](./architecture.md) page.

## Running in localnet

This is the easiest way to test kuutamod, which requires the least amount of
resources as it does not require downloading large amounts of chain data. We
will set up a local NEAR network and allow kuutamod to connect to it. This
tutorial is intended to work on a single computer without the need for an open
port to the internet.

### Requirements

You need the following executables in your `$PATH`.

- [consul](https://www.consul.io/): This provides a distributed lock for
  kuutamod to detect liveness and prevent two validators from running at the
  same time.

- [neard](https://github.com/near/nearcore/releases/latest): Kuutamod will run this binary.

- [hivemind](https://github.com/DarthSim/hivemind): This is optionally required
  to run execute our [Procfile](../Procfile). You can also manually execute the
  commands contained in this file.

- [Python](https://www.python.org/) for some of the setup scripts.

If you have installed the nix package manager (as described [here](./build.md)),
you can get all dependencies by running `nix develop` from the source directory
of kuutamod:

```console
$ git clone
$ nix develop
```

After installing the dependencies or running `nix develop`, run the command hivemind:

```console
$ hivemind
```

Hivemind starts consul, sets up the localnet configuration and starts two neard
instances for this network. It should be noted that only one consul server is
running. In a production setup, one should run a
[cluster](https://www.consul.io/docs/install/bootstrapping), otherwise this
consul server becomes a single point of failure. The scripts also set up keys
and configuration for two kuutamod instances. The localnet configuration for all
nodes is stored in `.data/near/localnet`.

If you built kuutamod from source using `cargo build`, the binary is in
`target/debug` or `target/release`, depending on whether you have a debug or
release build.

Next, start kuutamod in a new terminal window in addition to hivemind:

```console
$ ./target/debug/kuutamod --neard-home .data/near/localnet/kuutamod0/ \
  --voter-node-key .data/near/localnet/kuutamod0/voter_node_key.json \
  --validator-node-key .data/near/localnet/node3/node_key.json \
  --validator-key .data/near/localnet/node3/validator_key.json \
  --near-boot-nodes $(jq -r .public_key < .data/near/localnet/node0/node_key.json)@127.0.0.1:33301
```

You can check if it becomes a validator by running the command `curl`.

```console
$ curl http://localhost:2233/metrics
# HELP kuutamod_neard_restarts How often neard has been restarted
# TYPE kuutamod_neard_restarts counter
kuutamod_neard_restarts 1
# HELP kuutamod_state In what state our supervisor statemachine is
# TYPE kuutamod_state gauge
kuutamod_state{type="Registering"} 0
kuutamod_state{type="Shutdown"} 0
kuutamod_state{type="Startup"} 0
kuutamod_state{type="Syncing"} 0
kuutamod_state{type="Validating"} 1
kuutamod_state{type="Voting"} 0
# HELP kuutamod_uptime Time in milliseconds how long daemon is running
# TYPE kuutamod_uptime gauge
kuutamod_uptime 81917
```

This retrieves data from the [prometheus](https://prometheus.io/) monitoring endpoint of kuutamod.

The line `kuutamod_state{type="Validating"} 1` indicates that `kuutamod` has set
up neard as a validator, as you can also see from the neard home directory:

```console
$ ls -la .data/near/localnet/kuutamod0/
.rw-r--r-- 2,3k joerg 12 Jul 14:12 config.json
drwxr-xr-x    - joerg 12 Jul 14:12 data/
.rw-r--r-- 6,7k joerg 12 Jul 13:47 genesis.json
lrwxrwxrwx   73 joerg 12 Jul 14:12 node_key.json -> /home/joerg/work/kuutamo/kuutamod/.data/near/localnet/node3/node_key.json
lrwxrwxrwx   78 joerg 12 Jul 14:12 validator_key.json -> /home/joerg/work/kuutamo/kuutamod/.data/near/localnet/node3/validator_key.json
.rw-------  214 joerg 12 Jul 13:47 voter_node_key.json
```

The validator key has been symlinked and the node key has been replaced with the
node key specified in `-validator-node-key`.

After that you can also start a second `kuutamod` instance as follows:

```console
$ ./target/debug/kuutamod \
  --exporter-address 127.0.0.1:2234 \
  --validator-network-addr 0.0.0.0:24569 \
  --voter-network-addr 0.0.0.0:24570 \
  --neard-home .data/near/localnet/kuutamod1/ \
  --voter-node-key .data/near/localnet/kuutamod1/voter_node_key.json \
  --validator-node-key .data/near/localnet/node3/node_key.json \
  --validator-key .data/near/localnet/node3/validator_key.json \
  --near-boot-nodes $(jq -r .public_key < .data/near/localnet/node0/node_key.json)@127.0.0.1:33301
```

Note that we choose different network ports to not collide with the first
kuutamod instance on the same machine. Also, we choose a separate directory
while using the same keys for `--voter-node-key` and `--validator-node-key`.
The second kuutamod has its metrics endpoint at `http://localhost:2234/metrics`.
Again, with `curl`, we can see that it has entered the Voting state, as there is
already another kuutamod instance registered:

```
$ curl http://localhost:2234/metrics
# HELP kuutamod_state In what state our supervisor statemachine is
# TYPE kuutamod_state gauge
kuutamod_state{type="Registering"} 0
kuutamod_state{type="Shutdown"} 0
kuutamod_state{type="Startup"} 0
kuutamod_state{type="Syncing"} 0
kuutamod_state{type="Validating"} 0
kuutamod_state{type="Voting"} 1
# HELP kuutamod_uptime Time in milliseconds how long daemon is running
# TYPE kuutamod_uptime gauge
kuutamod_uptime 10412
```

If we look at its neard home directory we can also see that no validator key is
present and the node key specified by `--voter-node-key` is symlinked:

```
$ ls -la .data/near/localnet/kuutamod1
.rw-r--r-- 2,3k joerg 12 Jul 14:20 config.json
drwxr-xr-x    - joerg 12 Jul 14:20 data/
.rw-r--r-- 6,7k joerg 12 Jul 13:47 genesis.json
lrwxrwxrwx   83 joerg 12 Jul 14:20 node_key.json -> /home/joerg/work/kuutamo/kuutamod/.data/near/localnet/kuutamod1/voter_node_key.json
.rw-------  214 joerg 12 Jul 13:47 voter_node_key.json
```

If we now stop the first `kuutamod` instance by pressing `ctrl-c`...

```
2022-07-12T14:38:22.810412Z  WARN neard: SIGINT, stopping... this may take a few minutes.
level=info pid=2119211 message="SIGINT received" target="kuutamod::exit_signal_handler" node_id=node
level=info pid=2119211 message="state changed: Voting -> Shutdown" target="kuutamod::supervisor" node_id=node
level=warn pid=2119211 message="Termination timeout reached. Send SIGKILL to neard!" target="kuutamod::proc" node_id=node
```

... we can see that the second instance takes over:

```
2022-07-12T14:52:02.827213Z  INFO stats: #       0 CyjBSLQPeET76Z2tZP2otY8gDFsxANBgobf57o9Mzi8e 4 validators 0 peers ⬇ 0 B/s ⬆ 0 B/s 0.00 bps 0 gas/s CPU: 0%, Mem: 34.0 MB
level=info pid=2158051 message="state changed: Voting -> Validating" target="kuutamod::supervisor" node_id=node
2022-07-12T14:52:04.271448Z  WARN neard: SIGTERM, stopping... this may take a few minutes.
2022-07-12T14:52:09.281715Z  INFO neard: Waiting for RocksDB to gracefully shutdown
2022-07-12T14:52:09.281725Z  INFO db: Waiting for the 1 remaining RocksDB instances to gracefully shutdown
2022-07-12T14:52:09.281746Z  INFO db: Dropped a RocksDB instance. num_instances=0
2022-07-12T14:52:09.281772Z  INFO db: All RocksDB instances performed a graceful shutdown
level=warn pid=2158051 message="Cannot reach neard status api: Failed to get status" target="kuutamod::supervisor" node_id=node
2022-07-12T14:52:09.295345Z  INFO neard: version="1.27.0" build="nix:1.27.0" latest_protocol=54
2022-07-12T14:52:09.295956Z  INFO near: Opening store database at ".data/near/localnet/kuutamod1/data"
2022-07-12T14:52:09.312159Z  INFO db: Created a new RocksDB instance. num_instances=1
2022-07-12T14:52:09.312801Z  INFO db: Dropped a RocksDB instance. num_instances=0
2022-07-12T14:52:09.401450Z  INFO db: Created a new RocksDB instance. num_instances=1
2022-07-12T14:52:09.440197Z  INFO near_network::peer_manager::peer_manager_actor: Bandwidth stats total_bandwidth_used_by_all_peers=0 total_msg_received_count=0 max_max_record_num_messages_in_progress=0
2022-07-12T14:52:09.454305Z  INFO stats: #       0 CyjBSLQPeET76Z2tZP2otY8gDFsxANBgobf57o9Mzi8e Validator | 4 validators 0 peers ⬇ 0 B/s ⬆ 0 B/s NaN bps 0 gas/s
2022-07-12T14:52:19.457739Z  INFO stats: #       0 CyjBSLQPeET76Z2tZP2otY8gDFsxANBgobf57o9Mzi8e Validator | 4 validators 0 peers ⬇ 0 B/s ⬆ 0 B/s 0.00 bps 0 gas/s CPU: 1%, Mem: 34.7 MB
```

This currently requires a restart of `neard` so that it loads the `validator node key`.

```
$ curl http://localhost:2234/metrics
# HELP kuutamod_neard_restarts How often neard has been restarted
# TYPE kuutamod_neard_restarts counter
kuutamod_neard_restarts 1
# HELP kuutamod_state In what state our supervisor statemachine is
# TYPE kuutamod_state gauge
kuutamod_state{type="Registering"} 0
kuutamod_state{type="Shutdown"} 0
kuutamod_state{type="Startup"} 0
kuutamod_state{type="Syncing"} 0
kuutamod_state{type="Validating"} 1
kuutamod_state{type="Voting"} 0
# HELP kuutamod_uptime Time in milliseconds how long daemon is running
# TYPE kuutamod_uptime gauge
kuutamod_uptime 43610
```

```
$ ls -la .data/near/localnet/kuutamod1
.rw-r--r-- 2,3k joerg 12 Jul 14:54 config.json
drwxr-xr-x    - joerg 12 Jul 14:54 data/
.rw-r--r-- 6,7k joerg 12 Jul 14:54 genesis.json
lrwxrwxrwx   73 joerg 12 Jul 14:54 node_key.json -> /home/joerg/work/kuutamo/kuutamod/.data/near/localnet/node3/node_key.json
lrwxrwxrwx   78 joerg 12 Jul 14:54 validator_key.json -> /home/joerg/work/kuutamo/kuutamod/.data/near/localnet/node3/validator_key.json
.rw-------  214 joerg 12 Jul 14:54 voter_node_key.json
```

## Running in testnet

### Single node kuutamod

This part of the tutorial assumes that you have installed a computer on which.
[NixOS](https://nixos.org/manual/nixos/stable/#sec-installation).
This is not yet a failover setup, as we will only use a single machine for simplicity.
How to convert this setup into a cluster setup is described in the next section.
To use the NixOS modules we provide in this repository, you also need to enable Flakes in NixOS.
To do this, add these lines to your `configuration.nix`...

```nix
{
  nix.extraOptions = ''
    experimental-features = nix-command flakes
  '';
}
```

and create a `flake.nix` as described [here](https://nixos.wiki/wiki/Flakes#Using_nix_flakes_with_NixOS).

In your `flake.nix` you have to add the `kuutamod` flake as source and import
the nixos modules from it into your configuration.nix.

```nix
{
  inputs = {
    # This is probably already there.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable-small";

    # This is the line you need to add.
    kuutamod.url = "github:kuutamolabs/kuutamod";
  };
  outputs = { self, nixpkgs, kuutamod }: {
    # Replace 'my-validator' with your hostname here.
    nixosConfigurations.my-validator = nixpkgs.lib.nixosSystem {
      # Our neard package is currently only tested on x86_64-linux.
      system = "x86_64-linux";
      modules = [
        ./configuration.nix

        # These are the modules provided by our flake
        kuutamod.nixosModules.neard-testnet
        # or if you want to join other networks, use one of these as needed.
        # kuutamod.nixosModules.neard-shardnet
        # kuutamod.nixosModules.neard-mainnet
        kuutamod.nixosModules.kuutamod
      ];
    };
  };
}
```

---

To bootstrap neard quickly, you can use an s3 backup of the chain database.
These are available for mainnet, testnet and stakenet:

The module can download this automatically, but for mainnet and testnet you need to specify a timestamp to do so:

**Testnet**

```
$ nix-shell -p awscli --command 'aws s3 --no-sign-request cp s3://near-protocol-public/backups/testnet/rpc/latest -'
2022-07-13T11:00:40Z
```

In this case, the full s3 backup URL (to be used in the config below) is  
`s3://near-protocol-public/backups/testnet/rpc/2022-07-13T11:00:40Z`.

**Mainnet**

For `mainnet` replace the word `testnet` in the urls above.

**Stakenet**

For `stakenet` at the time of writing backups are not versioned, so for the time being, if deploying on `shardnet` remove this option,
for now we have hardcoded the `shardnet` node to pull from this backup. As shardnet evolves and alignes this will be updated.   

---


Create a new file called `kuutamod.nix` next to your `configuration.nix`.
If your NixOS configuration is managed via a git repository, do not forget to run `git add kuutamod.nix`.

For testnet, add the following configuration to the `kuutamod.nix` file:

```nix
{
  # Consul wants to bind to a network interface. You can get your interface as follows:
  # $ ip route get 8.8.8.8
  # 8.8.8.8 via 131.159.102.254 dev enp24s0f0 src 131.159.102.16 uid 1000
  #   cache
  # This becomes relevant when you scale up to multiple machines.
  services.consul.interface.bind = "enp24s0f0";
  services.consul.extraConfig.bootstrap_expect = 1;

  # This is the URL we calculated above:
  kuutamo.neard.s3.dataBackupDirectory = "s3://near-protocol-public/backups/testnet/rpc/2022-07-13T11:00:40Z";

  # We create these keys after the first 'nixos-rebuild switch'
  # As these files are critical, we also recommend tools like https://github.com/Mic92/sops-nix or https://github.com/ryantm/agenix
  # to securely encrypt and manage these files. For both sops-nix and agenix, set the owner to 'neard' so that the service can read it.
  kuutamo.kuutamod.validatorKeyFile = "/var/lib/secrets/validator_key.json";
  kuutamo.kuutamod.validatorNodeKeyFile = "/var/lib/secrets/node_key.json";
}
```

Import this file in your `configuration.nix`:

```nix
{
  imports = [ ./kuutamod.nix ];
}
```

Before we can move on generating validator keys, we need first create the neard user. Therefore run `nixos-rebuild switch`.

```
nixos-rebuild switch
```

The first switch will take longer since it blocks on downloading the s3 data backup (around 300GB).
You can follow the progress by running: `sudo journalctl -u kuutamod -f`.

The next step is to generate and install validator key and validator node key. Note that
with kuutamod we will have one validator and node key for the active validator,
while each validator also has its own non-valdiator node key, when its not the active
validator. Furthermore when the current machine is not a validator it will listen to seperate port.
This is important for failover since we want to not confuse the neard instances that might
still have old routing table entries for specific nodes.

To generate these keys. Run the following command but replace
`myawsome.pool.f863973.m0`, with your own account id of choice:

```
# we use intentionally the `localnet` here to not having to download genesis files
$ nix run github:kuutamolabs/kuutamod#neard -- --home /tmp/tmp-near-keys init --chain-id localnet --account-id myawsome.pool.f863973.m0
warning: Using saved setting for 'extra-substituters = https://cache.garnix.io' from ~/.local/share/nix/trusted-settings.json.
warning: Using saved setting for 'extra-trusted-public-keys = cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g=' from ~/.local/share/nix/trusted-settings.json.
2022-07-13T10:37:43.778395Z  INFO neard: version="1.27.0" build="nix:1.27.0" latest_protocol=54
2022-07-13T10:37:43.778551Z  INFO near: Using key ed25519:7Bt35Z83VJjvhWY23rTF9ep5uiDwne1nv1HXPtc3ZMcg for myawsome.pool.f863973.m0
2022-07-13T10:37:43.778626Z  INFO near: Using key ed25519:BN88UKdWdz1rweHXETKQH3UYu8yxR5P8pn3ssqNAe2kW for node
2022-07-13T10:37:43.778804Z  INFO near: Generated node key, validator key, genesis file in /tmp/tmp-near-keys
```

Once the keys are generated, you can install them like this:

```console
$ sudo install -o neard -g neard -D -m400 /tmp/tmp-near-keys/validator_key.json /var/lib/secrets/validator_key.json
$ sudo install -o neard -g neard -D -m400 /tmp/tmp-near-keys/node_key.json /var/lib/secrets/node_key.json
```

If the s3 backup sync was quicker than you generating the key, you might need to
run `systemctl restart kuutamod` so that it picks up the key. If everything
went well, you should be able to reach kuutamod's prometheus exporter url:

```
$ curl http://localhost:2233/metrics
# HELP kuutamod_state In what state our supervisor statemachine is
# TYPE kuutamod_state gauge
kuutamod_state{type="Registering"} 0
kuutamod_state{type="Shutdown"} 0
kuutamod_state{type="Startup"} 0
kuutamod_state{type="Syncing"} 1
kuutamod_state{type="Validating"} 0
kuutamod_state{type="Voting"} 0
# HELP kuutamod_uptime Time in milliseconds how long daemon is running
# TYPE kuutamod_uptime gauge
kuutamod_uptime 1273658
```

Once neard is synced with the network, you should see a kuutamod listed as an active validator using `kuutamoctl`:

```
$ kuutamoctl active-validator
Name: river
```

where `name` is the kuutamo node id.

### Multi-Node kuutamo cluster

Once your single-node kuutamod setup works, you can scale out to multiple nodes by changing your `kuutamod.nix`
like this:

```
{

  # Same as above, this needs to be an interface should be used to connect to your other machines
  services.consul.interface.bind = "enp24s0f0";

  # this now needs to be increased to the number of consul nodes your are adding
  services.consul.extraConfig.bootstrap_expect = 3;

  # We allow these ports for our consul server. Here we assume a trusted network. If this is not the case, read about
  # setting up encryption and authentication for consul: https://www.consul.io/docs/security/encryption
  networking.firewall = {
    allowedTCPPorts = [
      8301 # lan serf
      8302 # wan serf
      8600 # dns
      8500 # http api
      8300 # RPC address
    ];
    allowedUDPPorts = [
      8301 # lan serf
      8302 # wan serf
      8600 # dns
    ];
  };

  # add here the ip addresses or domain names of other hosts, that you want to add to the cluster
  services.consul.extraConfig.retry_join = [
    "node0.mydomain.tld"
    "node1.mydomain.tld"
    "node3.mydomain.tld"
  ];

  # Everything below stays the same.

  # This is the URL we calculated above:
  kuutamo.neard.s3.dataBackupDirectory = "s3://near-protocol-public/backups/testnet/rpc/2022-07-13T11:00:40Z";

  # If you set this to null, neard will download the Genesis file on first startup.
  kuutamo.neard.genesisFile = null;
  kuutamo.neard.chainId = "testnet";
  # This is the file we just have downloaded from: https://s3-us-west-1.amazonaws.com/build.nearprotocol.com/nearcore-deploy/testnet/config.json
  kuutamo.neard.configFile = ./config.json;

  # We create these keys after the first 'nixos-rebuild switch'
  # As these files are critical, we also recommend tools like https://github.com/Mic92/sops-nix or https://github.com/ryantm/agenix
  # to securely encrypt and manage these files. For both sops-nix and agenix, set the owner to 'neard' so that the service can read it.
  kuutamo.kuutamod.validatorKeyFile = "/var/lib/secrets/validator_key.json";
  kuutamo.kuutamod.validatorNodeKeyFile = "/var/lib/secrets/node_key.json";
}
```

Do not forget to also copy `/var/lib/secrets/validator_key.json` and `/var/lib/secrets/node_key.json` from your first machine to the other nodes.
After running `nixos-rebuild switch` on each of them.
Check that your consul cluster is working:

If you access `http://localhost:8500/v1/status/peers` from any of the hosts, it should contain all node ips of your consul cluster:

```
curl http://localhost:8500/v1/status/peers
["131.0.0.1:8300","131.0.0.2:8300","131.0.0.3:8300"]
```

Furthermore `http://localhost:8500/v1/status/leader` should contain the consul cluster leader:

```
curl http://localhost:8500/v1/status/leader
"131.159.102.16:8300"
```

Just like in the `localnet` example, you can query
`http://localhost:2233/metrics` on each host or use `kuutamoctl` to see which
host is currently the designated validator.

## Further reading

- [Configuration](./configuration.md): All configuration options in kuutamod
- [Failover algorithm](./failover-algorithm.md) describes the runtime behavior of kuutamod in depth
