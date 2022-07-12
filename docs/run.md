# Run Kuutamod failover setup

## Running in localnet

This is the easiest way to test kuutamod that requires the least amount of
resources, since it does not require to download big amounts of chain data. In
this setup we will setup a local near network and than let kuutamod connect to
it. It is intended to work on a single machine with no port open to the
internet.

### Requirements

You will need the following executables in your `$PATH`.

- [consul](https://www.consul.io/): This provides a distributed lock for
  kuutamod for lifeness detection and avoiding two neard validator running at
  the same time.
- [neard](https://github.com/near/nearcore/releases/latest): Kuutamod will run this binary.
- [hivemind](https://github.com/DarthSim/hivemind): This optionally needed to
  run our [Procfile](../Procfile). You could also run the commands found in this
  file manually.
- [Python](https://www.python.org/) for some of the setup scripts.


If you have the nix package manager (as described [here](./build.md)), you can
get all dependencies by running `nix develop` from the source directory of
kuutamod.

```
$ git clone
$ nix develop
```

After install the dependencies or running `nix develop`, run the hivemind command:

```
hivemind
```

This will run consul and setup localnet and starts two neard instances for this
network.  It should be noted that it only runs a single consul server. In a
production setup, one should running a
[cluster](https://www.consul.io/docs/install/bootstrapping) as otherwise this
consul server becomes a single point of failure.
The scripts also setup keys and configuration for two kuutamod instances. The
localnet configuration is stored in `.data/near/localnet`.

If you have build kuutamod from source with `cargo build`, it's binary is in `target/debug` or
`target/release`, depending whether you have a debug or release build.

Next start kuutamod in a new terminal window seperate in addition to hivemind.

```
./target/debug/kuutamod --neard-home .data/near/localnet/kuutamod0/ --voter-node-key .data/near/localnet/kuutamod0/voter_node_key.json --validator-node-key .data/near/localnet/node3/node_key.json --validator-key .data/near/localnet/node3/validator_key.json
```

You can verify that it becomes a validator by running with the `curl` command.

```
curl http://localhost:2233/metrics
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

This will fetch data from kuutamod's prometheus monitoring endpoint.

The line `kuutamod_state{type="Validating"} 1` here indicates that `kuutamod` has setup
neard as a validator as you can also see from the neard home directory:

```
$ ls -la .data/near/localnet/kuutamod0/
.rw-r--r-- 2,3k joerg 12 Jul 14:12 config.json
drwxr-xr-x    - joerg 12 Jul 14:12 data/
.rw-r--r-- 6,7k joerg 12 Jul 13:47 genesis.json
lrwxrwxrwx   73 joerg 12 Jul 14:12 node_key.json -> /home/joerg/work/kuutamo/kuutamod/.data/near/localnet/node3/node_key.json
lrwxrwxrwx   78 joerg 12 Jul 14:12 validator_key.json -> /home/joerg/work/kuutamo/kuutamod/.data/near/localnet/node3/validator_key.json
.rw-------  214 joerg 12 Jul 13:47 voter_node_key.json
```

The validator key has been symlinked in and the node key has been replaced by node key specified in `--validator-node-key`.


After that you can also start a second `kuutamod` instance like this:

```
./target/debug/kuutamod --exporter-address 127.0.0.1:2234 --validator-network-addr 0.0.0.0:24569 --voter-network-addr 0.0.0.0:24570 --neard-home .data/near/localnet/kuutamod1/ --voter-node-key .data/near/localnet/kuutamod1/voter_node_key.json --validator-node-key .data/near/localnet/node3/node_key.json --validator-key .data/near/localnet/node3/validator_key.json
```

Notice that we choose different network ports for some interface to not collide
with the first kuutamod instance. Furthmore we pick a seperate neard directory,
while using the same keys for `--voter-node-key` and `--validator-node-key`. In
a real setup kuutamod would run on dedicate machines or VMs so that port
collisions should be not an issue.
The second kuutamod has its metrics endpoint on `http://localhost:2234/metrics`.
Using `curl` again, we can see that it went it to voting state, since there is
already one running kuutamod instance registered.

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

If we now stop the first `kuutamod` instance with pressing `ctrl-c`...

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

This currently requires restarting `neard`, so it will load the `validator node key`.

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