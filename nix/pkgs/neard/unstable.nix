{ pkgs }:

let
  generic = pkgs.callPackage ./generic.nix { };
in
generic {
  version = "1.28.0-rc.3";
  sha256 = "sha256-AB9vOgSPzJXdMYuQ4BHOwahzW2tWOf4BvoctP9N8d0o=";
  cargoSha256 = "sha256-uhKsQFvVE7h65zzLHDeXVEHzIiTk3V1qvcrJSILj34Y=";
}
