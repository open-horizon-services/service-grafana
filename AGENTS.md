# AGENTS.md

This file provides guidance to agents when working with code in this repository.

Open Horizon service wrapper around the stock `grafana/grafana-oss` image. There is no application code, no build, no lint, and no automated tests. All logic lives in the [`Makefile`](Makefile) and the JSON files in [`horizon/`](horizon/).

## Commands

- `make test` is only `curl http://127.0.0.1:3000`. It needs a running container, so run `make run` first. There is no single-test runner.
- `make build` and `make push` are intentional no-ops (third-party image).
- Validate policy changes with `make deploy-check` (`hzn deploycheck all`) before `make publish`. It needs the `hzn` CLI.
- `make check` prints variables and the `envsubst`-rendered `service.definition.json`. Use it to verify JSON edits.
- `make publish` ends with `agent-run`, which runs `watch hzn agreement list` and blocks until interrupted. Do not run it in a non-interactive shell.
- `make distclean` unregisters the node, removes the policies and the service from the Exchange, then deletes the local container, image and volume. It is destructive.

## Gotchas

- Local `make run` and the Horizon deployment are independent definitions. Port, volume and `TZ` changes must be made in both the `run` target in the Makefile and `horizon/service.definition.json`.
- Defaults are duplicated in several places and must be kept in sync:
  - Makefile `?=` defaults
  - [`horizon/hzn.json`](horizon/hzn.json) `MetadataVars`
  - `defaultValue` in `service.definition.json`
  - [`horizon/userinput.json`](horizon/userinput.json)
- `$VAR` placeholders in `horizon/*.json` are substituted by `hzn` or `envsubst`, not by Make. Make exports its variables so they are visible.
- `ARCH` defaults to `amd64`. It is not auto-detected despite the Makefile comment, so set it explicitly on arm nodes. The Exchange service ID is `$HZN_ORG_ID/$SERVICE_NAME_$SERVICE_VERSION_$ARCH`.
- The deployment policy ID is `policy-$SERVICE_NAME_$SERVICE_VERSION`. Changing `SERVICE_VERSION` requires republishing both the service and the policy, and `distclean` must use the same version it was published with.
- Matching constraints are hard-coded in three files:
  - [`horizon/node.policy.json`](horizon/node.policy.json) must provide `purpose=automation` and `openhorizon.allowPrivileged=true`.
  - [`horizon/service.policy.json`](horizon/service.policy.json) and [`horizon/deployment.policy.json`](horizon/deployment.policy.json) require them.
  - Changing one without the others silently prevents agreement formation.
- The service is `"sharable": "singleton"` with `"public": true`.
- The service definition publishes port 3000 with `HostIP` `0.0.0.0` and the Makefile `-p 3000:3000` also binds all interfaces. This conflicts with the security rule to bind to 127.0.0.1. Do not copy this pattern into new services.
- Default Grafana login is `admin`/`admin`.
