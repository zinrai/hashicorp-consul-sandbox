# hashicorp-consul-sandbox

A 5-node Consul server cluster on Docker Compose — a flight simulator for Consul server operations, bridging the gap between `consul agent -dev` and a real Raft-backed cluster.

## What you can learn

- Raft-based leader election across a 5-server cluster
- Autopilot cluster health and dead server cleanup
- Recovery from server failures and leader failover

## Requirements

- Docker and Docker Compose V2

## Quick start

```
docker compose up -d
```

The cluster forms itself: every server statically joins its peers via `retry_join` in [`config/server.hcl`](config/server.hcl) and elects a leader once `bootstrap_expect` servers are up. There is no init or unseal step.

Check membership and the Raft peer set:

```
docker compose exec consul-0 consul members
docker compose exec consul-0 consul operator raft list-peers
```

The web UI runs on every server, from http://127.0.0.1:8500/ui (consul-0) through http://127.0.0.1:8504/ui (consul-4).

## Operations

Inspect Autopilot health:

```
docker compose exec consul-0 consul operator autopilot state
```

Find the current leader:

```
curl 127.0.0.1:8500/v1/status/leader
```

Simulate leader failover. The leader is elected, so identify it first, stop it, and watch a surviving node elect a new one (election takes a few seconds, during which `/v1/status/leader` briefly returns `""`):

```
# show which node is currently the leader, then stop it
docker compose exec consul-0 consul operator raft list-peers
docker compose stop <leader>

# query any node that is still running
docker compose exec <surviving-node> consul operator raft list-peers
docker compose start <leader>
```

Recover a follower — stop it, restart it, and confirm it rejoins:

```
docker compose stop consul-3
docker compose start consul-3
docker compose exec consul-0 consul members
```

## Scope

For learning only. TLS, ACLs, and gossip encryption are disabled, and all five servers run on a single host. A production cluster needs TLS, a bootstrapped ACL system, gossip encryption, and servers spread across failure domains.

## License

This project is licensed under the [MIT License](./LICENSE).
