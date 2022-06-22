{ self, ... }:
{
  perSystem = { config, self', inputs', pkgs, ... }: {
    packages = {
      neard = pkgs.callPackage ./neard/stable.nix { };
      neard-unstable = pkgs.callPackage ./neard/unstable.nix { };
      neard-bin = pkgs.callPackage ./neard/bin.nix { };

      kuutamod = pkgs.callPackage ./kuutamod.nix { };

      nix-update = pkgs.callPackage ./nix-update.nix { };

      default = self'.packages.neard;
    };
  };
}