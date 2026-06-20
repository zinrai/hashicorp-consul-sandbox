# hashicorp-consul-sandbox

A production-shaped Consul cluster on Docker Compose: **5 servers**, **6 clients**
(5 plain plus 1 UI), and a small service catalog. It is the substrate for rehearsing
a Consul **server rolling upgrade** and verifying it left KV, services, and the
catalog intact.

It bridges `consul agent -dev` and a real cluster: a five-server Raft quorum, client
agents that register services with health checks (so the catalog has something real
to keep or lose), and a single UI endpoint.

## Topology

| Role | Nodes | Address | Host HTTP |
|------|-------|---------|-----------|
| server | consul-server-0..4 | 172.28.0.10-.14 | 127.0.0.1:8500-8504 |
| client | consul-client-0..4 | 172.28.0.20-.24 | 127.0.0.1:8505-8509 |
| UI client | consul-client-ui | 172.28.0.25 | 127.0.0.1:8510 |
| backend | web-0..2, cache-0, api-0 | 172.28.0.30-.34 | (none) |

- The five servers form one Raft quorum (`bootstrap_expect = 5`).
- The five plain clients register services with HTTP health checks against a small
  `http-echo` backend: **web** has three instances (consul-client-0..2), **cache** one
  (consul-client-3), **api** one (consul-client-4). Stopping a backend drives its check
  critical, so the graded `healthy` count (web 3 to 2 benign, cache/api 1 to 0 outage)
  is exactly what consul-state-diff judges.
- The **UI** runs on one agent only: consul-client-ui (http://127.0.0.1:8510/ui),
  which carries no service and exists purely for observation.
- Scale the `consul-client-*` / backend blocks if you want more instances.

## Quick start

```
docker compose up -d
docker compose exec consul-server-0 consul members
docker compose exec consul-server-0 consul operator raft list-peers
docker compose exec consul-server-0 consul catalog services
```

The cluster forms itself: every agent statically joins the servers via `retry_join`
([`config/server`](config/server), [`config/client`](config/client),
[`config/ui`](config/ui)) and the servers elect a leader once `bootstrap_expect` are
up. There is no init or unseal step.

## What it is for: rehearsing a server upgrade

The cluster is the stage; the upgrade toolchain lives in separate repos:

- [consul-server-runbook](https://github.com/zinrai/consul-server-runbook): generates
  the leader-last replacement plan and the per-step verification commands.
- [consul-state-verify](https://github.com/zinrai/consul-state-verify)
  (consul-state-dump / consul-state-diff): dumps the server-authoritative state
  before and after a step and judges that it survived.
- [consul-server-tail](https://github.com/zinrai/consul-server-tail): watches
  membership and health live during the window.

KV is not pre-seeded; [consul-fixture-seed / consul-fixture-churn](https://github.com/zinrai)
populate and perturb it for a rehearsal.

### The rolling upgrade (servers, leader last)

All servers share `CONSUL_SERVER_IMAGE`. A quick in-place smoke test bumps one node
at a time, followers first and the leader last, reusing the data-dir (same node-id):

```
docker compose exec consul-server-0 consul operator raft list-peers   # find the leader
CONSUL_SERVER_IMAGE=hashicorp/consul:1.22 docker compose up -d consul-server-1
# wait for the cluster to re-stabilise, repeat per follower, leader last
```

The cluster stays a clean five voters throughout, which is the invariant the upgrade
must preserve.

The production operation (shut each old server down, bring up a freshly provisioned
new-version server at the same IP, with `force-leave -prune` of the old node) is not
hand-written: [consul-server-runbook](https://github.com/zinrai/consul-server-runbook)
generates it from this cluster. Its example template is the full upgrade runbook for
this sandbox, with consul-server-tail, consul-client-tail, and consul-state-verify
wired in. Follow the generated `runbook.md` (it runs `consul-client-tail` against a
`clients.json` you provide; write one from
[consul-client-tail](https://github.com/zinrai/consul-client-tail)'s example for the
clients above). The reasoning behind the procedure is in
[docs/server-rolling-upgrade.md](docs/server-rolling-upgrade.md).

### The skew window: did the upgrade break the clients?

Clients share one image (`CONSUL_CLIENT_IMAGE`), so you can hold them on the old
version while the servers move to the new one, the supported
servers-first / clients-last skew. While the servers are new and the clients are
still old, confirm each client's local access path still serves its apps. This is a
**liveness probe (exit code), not a state dump**:

```
# old client -> new servers: forward read path and local check state
docker compose exec consul-client-1 consul catalog services
docker compose exec consul-client-1 wget -qO- 127.0.0.1:8500/v1/agent/checks

# service discovery from the host (DNS is published on consul-client-1)
dig +short @127.0.0.1 -p 8600 web.service.consul
```

Membership-level "did a client fall out of the pool" is consul-server-tail's job, and
a client's services going critical shows up server-side in consul-state-diff's outage
rule. The snippet above covers only the residual that is irreducibly client-local: the
local read path and the agent's own check execution. Then bump the clients:

```
CONSUL_CLIENT_IMAGE=hashicorp/consul:1.22 docker compose up -d \
  consul-client-0 consul-client-1 consul-client-2 consul-client-3 \
  consul-client-4 consul-client-ui
```

## Operations

```
# leader failover: stop the leader, watch a survivor elect a new one
docker compose exec consul-server-0 consul operator raft list-peers
docker compose stop <leader>
docker compose exec <survivor> consul operator raft list-peers
docker compose start <leader>

# service health: kill a backend and watch the healthy count drop
docker compose stop web-1
docker compose exec consul-server-0 consul catalog nodes -service=web
docker compose start web-1

# autopilot health
docker compose exec consul-server-0 consul operator autopilot state
```

## Scope

Learning and rehearsal only. TLS, ACLs, and gossip encryption are disabled, and all
nodes run on a single host. A production cluster needs TLS, a bootstrapped ACL system,
gossip encryption, and servers spread across failure domains.

## License

This project is licensed under the [MIT License](./LICENSE).
