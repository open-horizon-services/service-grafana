# Proposal

## Why

The service publishes one architecture per run (`ARCH ?= amd64`), so Raspberry Pi (`arm64`) and 32-bit ARM (`arm`) nodes need a manual re-run with `ARCH` overridden. It also references the floating tag `grafana/grafana-oss:latest`. Since Grafana 12.4.0 the `grafana/grafana-oss` repository is no longer updated, so `latest` is stale (13.0.2) while `grafana/grafana` carries the current release (13.2.4). Tracked in [GitHub issue 12](https://github.com/open-horizon-services/service-grafana/issues/12).

## What Changes

- Switch the default image from `grafana/grafana-oss` to `grafana/grafana`.
- Pin `DOCKER_IMAGE_VERSION` to `13.2.4` (re-check the newest release at implementation time) instead of `latest`.
- Add a Makefile variable listing supported architectures (`amd64 arm64 arm`), the platforms in the `grafana/grafana` manifest list.
- Make `publish-service`, `publish-service-policy`, `remove-service`, `remove-service-policy` and `deploy-check` act on every listed architecture. `distclean` then removes all of them.
- Replace literal values in the Makefile recipes (port `3000` in `run`, `test` and `browse`, the data path `/var/lib/grafana`, the local URL) with overridable variables, and use the same variables in `horizon/service.definition.json`. The container port and data path are also passed to Grafana as `GF_SERVER_HTTP_PORT` and `GF_PATHS_DATA`, so overriding them changes what Grafana uses and not only the mapping. New or changed targets (architecture loops, container CLI) take all their values from variables too.
- Stop assuming Docker is installed. The local container targets (`run`, `stop`, `init`, `clean`, `attach`) and any image inspection use a selectable container CLI that is auto-detected as `docker` or `podman`.
- Bump `SERVICE_VERSION` from `0.0.1` so new definitions do not collide with published ones. The deployment policy ID (`policy-$SERVICE_NAME_$SERVICE_VERSION`) changes with it.
- Update `README.md` and the Makefile header comments with a supported-architecture table, the pinned version, and how to publish each architecture.
- **BREAKING**: Nodes and policies that reference version `0.0.1` are not updated. Operators must publish and deploy the new version. The default image repository and tag also change.

## Capabilities

### New Capabilities
- `multiarch-service-publishing`: Publishing, deploy-checking and removing the Exchange service definitions, service policies and deployment policy for every supported architecture from a single Makefile invocation.
- `grafana-image-selection`: Which Grafana container image and version the local run and the Horizon service definition use. It covers repository, pinned release tag, and the consistency of defaults across files.
- `local-container-runtime`: Which container CLI (`docker` or `podman`) the Makefile's local run, cleanup and image-inspection targets use, and how it is chosen and overridden.
- `configurable-service-settings`: Which Makefile variables hold the service's port, data path and local URL, so recipes and the Horizon service definition share one overridable value instead of repeated literals.

### Modified Capabilities

None. `openspec/specs/` is empty.

## Impact

- [`Makefile`](../../../Makefile): image defaults, new architecture list variable, per-architecture loops for the publish, remove and deploy-check targets, a container CLI variable replacing hard-coded `docker` calls, `check` output, header comments.
- [`horizon/hzn.json`](../../../horizon/hzn.json): `DOCKER_IMAGE_BASE`, `DOCKER_IMAGE_VERSION`, `SERVICE_VERSION` defaults, plus the new port and data-path variables.
- [`horizon/service.definition.json`](../../../horizon/service.definition.json): resolves to the new image and version through `$DOCKER_IMAGE_BASE:$DOCKER_IMAGE_VERSION`. Its `arch` field stays `$ARCH` and is varied per publish.
- [`README.md`](../../../README.md): architecture table, pinned version, publishing instructions, Raspberry Pi node text.
- [`horizon/deployment.policy.json`](../../../horizon/deployment.policy.json) already uses `"arch": "*"` and needs no change.
- Depends on the `hzn` CLI and the Docker Hub registry, not on the Docker CLI. The change touches no application code. Issue #8 (restructure for `hzn dev verify`) may move files, so coordinate the two.
- The Horizon agent's own container-runtime requirements, and what `hzn exchange service publish -P` needs to pull images, are outside this repository. The design records how they are verified.
- Not supported: `linux/arm/v6` (Raspberry Pi Zero and 1), since Grafana publishes no image for it.
