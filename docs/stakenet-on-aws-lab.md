# Lab: Single node kuutamo near validator up on shardnet using AWS.

- Get [NixOS EC2 AMI](https://nixos.org/download.html#nixos-amazon)
  In this demo I used London (eu-west-2): `ami-08f3c1eb533a42ac1` 
- Setup VM
  AWS > EC2 > AMIs > `ami-08f3c1eb533a42ac1` > Launch instance from AMI > c5a.xlarge (I guess c5ad no available in London), 500GIB gp3 > Launch instance
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

#### Build and switch
```console
$ nixos-rebuild switch --flake /etc/nixos#validator`
```
- Note: Compiling took about an hour on this machine.

#### Create keys
```console
$ nix run github:kuutamolabs/kuutamod#neard -- --home /tmp/tmp-near-keys init --chain-id shardnet--account-id validator.shardnet.near
```

---
kuutamolabs  
[GitHub](https://github.com/kuutamolabs/kuutamod) [Matrix](https://matrix.to/#/#kuutamo-chat:kuutamo.chat)
