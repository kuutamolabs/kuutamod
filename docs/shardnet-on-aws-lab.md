# Lab: Single node kuutamo near validator up on shardnet using AWS.

This lab assumes you have created an account on shardnet. [Challange 1](https://github.com/near/stakewars-iii/blob/main/challenges/001.md)

- Get [NixOS EC2 AMI](https://nixos.org/download.html#nixos-amazon)
  In this demo I used London (eu-west-2): `ami-08f3c1eb533a42ac1` 
- Setup VM
  AWS > EC2 > AMIs > `ami-08f3c1eb533a42ac1` > Launch instance from AMI > For this demo I used: c5a.xlarge, 500GIB gp3 > Launch instance
- SSH to instance

#### Edit `configuration.nix` so it is as below: `nano /etc/nixos/configuration.nix`
```nix
{ modulesPath, ... }: {
  imports = [ "${modulesPath}/virtualisation/amazon-image.nix" ./kuutamod.nix];
  ec2.hvm = true;

  nix.extraOptions = ''
  experimental-features = nix-command flakes
  '';  
}
```

#### Add `flake.nix` file as below: `nano /etc/nixos/flake.nix`
```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable-small";
    kuutamod.url = "github:kuutamolabs/kuutamod";
  };
  outputs = { self, nixpkgs, kuutamod }: {
    nixosConfigurations.validator = nixpkgs.lib.nixosSystem {
      # Our neard package is currently only tested on x86_64-linux.
      system = "x86_64-linux";
      modules = [
        ./configuration.nix

        kuutamod.nixosModules.neard-shardnet
        kuutamod.nixosModules.kuutamod
      ];
    };
  };
}

```
#### Add `kuutamod.nix` file as below: `nano /etc/nixos/kuutamod.nix`
```nix
{
  # consul is here because you can add more kuutamod nodes later and create an Active/Passive HA cluster.
  services.consul.interface.bind = "ens5";
  services.consul.extraConfig.bootstrap_expect = 1;

  kuutamo.kuutamod.validatorKeyFile = "/var/lib/secrets/validator_key.json";
  kuutamo.kuutamod.validatorNodeKeyFile = "/var/lib/secrets/node_key.json";
}
```

#### Rebuild and switch to new configuration
```console
$ nixos-rebuild switch --flake /etc/nixos#validator
```

#### Create keys

1. Follow [instructions to create wallet and install near-cli](https://github.com/near/stakewars-iii/blob/main/challenges/001.md) 
2. Follow instructions to [generate keys](https://github.com/near/stakewars-iii/blob/main/challenges/002.md#activating-the-node-as-validator)
3. Copy key to validator

#### Install keys
 
```console
$ sudo install -o neard -g neard -D -m400 /var/lib/neard/voter_node_key.json /var/lib/secrets/node_key.json
$ sudo install -o neard -g neard -D -m400 /you.shardnet.near.json /var/lib/secrets/validator_key.json
```
You can view logs in the systemd journal
```console
$ journalctl -u kuutamod.service -f
Jul 17 21:43:50 river kuutamod[44389]: 2022-07-17T21:43:50.898176Z  INFO stats: # 1102053 7zgkxdDiKBoqud9DuSC47cwZ94e63BwGj1NNKs93JcLs Validator | 100 validators 29 peers ⬇ 345 kB/s ⬆ 485 kB/s 0.80 bps 0 gas/s CPU: 0%, Mem: 1.77 GB
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
kuutamod_uptime 3447978
```

Once neard is synced with the network, you should see a kuutamod listed as an active validator using `kuutamoctl`:
```console
$ kuutamoctl active-validator
Name: river
```
where `Name` is the kuutamo node id.

---
#### Next Steps

- You can now mount your staking pool [Challenge 3](https://github.com/near/stakewars-iii/blob/main/challenges/003.md)
- You can add more nodes to create an active/passive ha cluster. See [kuutamo GitHub README.md](https://github.com/kuutamolabs/kuutamod/blob/main/README.md) for more information. 

---
kuutamolabs  
[GitHub](https://github.com/kuutamolabs/kuutamod) | [Matrix](https://matrix.to/#/#kuutamo-chat:kuutamo.chat)
