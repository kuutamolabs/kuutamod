# kuutamod

kuutamod is a distributed supervisor for neard that implements failover for
[NEAR validators](https://near.org/validators/). NEAR is an application
platform built on top of the NEAR protocol blockchain. Validator nodes, run by
the community, provide computational resources to the NEAR network and collect
monetary rewards at regular intervals, based on the volume of work (blocks and chunks
produced). Validators who do not complete the work assigned to them receive
fewer rewards and may be excluded from the group of validators who are allowed
to validate for some time.

Kuutamod therefore allows multiple NEAR validators to operate in an
active-passive setup. The active validator node is started with the validator
keys, while the other nodes are synchronised with the blockchain. In the event
of a failure, i.e. a neard crash, network split or hardware failure, a passive
instance can be promoted to an active validator by restarting it with the
validator keys. To avoid having two active validators running at the same time,
kuutamod uses [consul](https://www.consul.io/) by acquiring a distributed lock.

In production, Systemd or another supervisor must be used as this will terminate 
neard in the case kuutamod crashes.

## Status: beta

kuutamod is continously tested and also used in production for validators.
However `kuutamod`'s interface is still under active development and might
change significantly.

## Docs

- Tutorials:
  - [Build and install from source](docs/build.md)
  - [Run kuutamod failover setup](docs/run.md)
  <!-- TODO - [Monitoring](docs/monitoring.md) -->
- References:
  - [Configuration](docs/configuration.md)
- [Architecture](docs/architecture.md)
  - [Failover algorithm](docs/failover-algorithm.md)

---
kuutamolabs  
[GitHub](https://github.com/kuutamolabs/kuutamod) | [Matrix](https://matrix.to/#/#kuutamo-chat:kuutamo.chat)
