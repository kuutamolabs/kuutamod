{ pkgs }:

let
  generic = pkgs.callPackage ./generic.nix { };
in
generic {
  version = "1.27.0";
  sha256 = "sha256-B9HqUa0mBSvsCPzxPt4NqpV99rV4lmQ9Q/z9lxob9oM=";
  cargoSha256 = "sha256-yZ3gMegub2/1z34fv+lAz8kx098/fd+sbOFHS4q433A=";
}
