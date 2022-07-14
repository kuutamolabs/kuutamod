# Build

Kuutamod comes as a single binary and with the optional programme `kuutamoctl`
to check the status of Kuutamod at runtime.

## Build with nix

We develop kuutamod primarily with nix and our development environment is based on it:

1. Install [nix](https://nix.dev/tutorials/install-nix)
2. Enable [flake support](https://xeiaso.net/blog/nix-flakes-1-2022-02-21) in nix:

```console
mkdir -p ~/.config/nix
echo 'experimental-features = nix-command flakes' >> ~/.config/nix/nix.conf
```

3. Build and run kuutamod:

```
nix run github:kuutamolabs/kuutamod -- --version
kuutamod 0.1.0
```

It is also possible to open a shell with development dependencies like this:

```
git clone https://github.com/kuutamolabs/kuutamod/
cd kuutamod
nix develop .#
```

The resulting shell allows to build kuutamod from nix as follows:

```
nix-shell> cargo build
./target/debug/kuutamod --version
kuutamod 0.1.0
```

## Build without nix

Currently we are testing `kuutamod` only on Linux.

1. Download kuutamod i.e. with [git](https://git-scm.com/downloads)

```
git clone https://github.com/kuutamolabs/kuutamod/
```

2. For building, `rustc` and `cargo` are needed depending on the
   [Linux distribution](https://www.rust-lang.org/learn/get-started).
   Due to dependencies on neard libraries, you will need a relatively recent version of
   of rust. If in doubt, install rustup to get the latest rust version:
   `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`

3. Build kuutamod with `cargo`:

```
cd kuutamod
cargo build --release
./target/release/kuutamod --version
kuutamod 0.1.0
```
