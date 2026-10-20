# Design

## Context

See proposal.md for motivation. Current state, from the repository:

- The Makefile exports `ARCH ?= amd64`. `horizon/service.definition.json` uses `"arch": "$ARCH"` and the label `$SERVICE_NAME for $ARCH`. The Exchange service ID is `$HZN_ORG_ID/$SERVICE_NAME_$SERVICE_VERSION_$ARCH`.
- `publish-service`, `publish-service-policy`, `remove-service`, `remove-service-policy` and `deploy-check` each run `hzn` once, with whatever `ARCH` is in the environment.
- `$VAR` placeholders in `horizon/*.json` are substituted by `hzn` or `envsubst` from the environment, so a per-architecture value is passed by setting `ARCH` for a single `hzn` invocation.
- The deployment policy already uses `"arch": "*"` and an ID without architecture, so one policy serves every architecture.
- Defaults for the image and version are duplicated in the Makefile and `horizon/hzn.json`.
- Literals are repeated across files: port `3000` appears in `run` (`-p 3000:3000`), `test`, `browse` (twice) and in `service.definition.json` (`"HostPort": "3000:3000/tcp"`). The data path `/var/lib/grafana` appears in `run` and the service definition. The restart policy `unless-stopped` and the host IP `0.0.0.0` are literals too. The default time zone `America/New_York` appears in the Makefile variable, the `check` text, `service.definition.json` and `userinput.json`.
- The Makefile calls `docker` directly in `stop`, `init`, `run`, `attach` and `clean`. The variable names `DOCKER_IMAGE_BASE`, `DOCKER_IMAGE_VERSION` and `DOCKER_VOLUME_NAME` are also used by the JSON files and stay as they are, since they name image and volume values and not the CLI.
- `distclean` already depends on `remove-service` and `remove-service-policy`, so it covers all architectures once those do.

## Goals / Non-Goals

**Goals:**
- One `make` invocation publishes, checks or removes the service for every supported architecture.
- A single-architecture run is still possible by overriding the architecture list.
- Image and version defaults are in sync everywhere they appear.
- No Makefile target requires Docker. Docker and Podman both work for local use.
- No recipe or JSON template contains a literal value that has a variable (port, data path, URL, restart policy, host IP, time zone, image, version, architectures). Defaults are defined once.

**Non-Goals:**
- Building or pushing images. The image stays third party.
- Changing any default value for port, volume, time zone, bind address or privileges. These become variables with the same defaults as today. The existing `0.0.0.0` binding stays the default and is flagged in D9.
- Restructuring files for `hzn dev verify` (issue 8).
- Auto-detecting the host architecture.
- Supporting `linux/arm/v6`.

## Decisions

### D1. Loop over architectures inside the existing targets
Add `export ARCHS ?= amd64 arm64 arm` and change the five arch-specific targets to run a shell `for` loop that sets `ARCH` for each `hzn` call, for example `for a in $(ARCHS); do ARCH=$$a hzn ...; done`. The aggregate behavior is then the default for `make publish`, `make distclean` and `make deploy-check`, with no new entry points.

Alternatives considered:
- *New aggregate targets (`publish-service-all`)*: leaves `publish` and `distclean` single-arch unless they are rewired, which would not meet the acceptance criteria.
- *Per-architecture target names (`publish-service-arm64`)*: more targets and more `.PHONY` and README entries for no extra capability.
- *`$(foreach)` generating recipe lines*: stops at the first failing line and hides which architecture failed.

The name `ARCHS` is used because `ARCH` remains the per-iteration value consumed by the JSON files.

### D2. Failure semantics differ for publish and remove
- Publish and deploy-check loops record a failure, continue, print the failing architecture and exit non-zero at the end. All results are visible in a single run.
- Remove loops continue past errors, such as an architecture that was never published, so `distclean` can finish cleanup. They report which architecture failed and still exit zero for "not found". Genuine errors (for example authentication) still surface in the `hzn` output.

Alternative: `set -e` fail-fast. Rejected because a partial publish or partial cleanup leaves the Exchange in a mixed state that is harder to reason about.

### D3. Keep `ARCH` for single-architecture use and for the JSON files
`ARCH` stays exported with its current default so `make check` and `service.definition.json` rendering work unchanged. Users who want one architecture set `ARCHS=arm64`. `make check` prints both `ARCHS` and the rendered definition. To make the rendered definition meaningful, `check` renders once per entry in `ARCHS`.

### D4. Image: `grafana/grafana`, pinned tag, digest optional
Set `DOCKER_IMAGE_BASE ?= grafana/grafana` and `DOCKER_IMAGE_VERSION ?= 13.2.4` in the Makefile and `horizon/hzn.json`. Re-check the newest release and the platform list at implementation time with any manifest inspection tool that is installed (see D8), for example `skopeo inspect --raw docker://docker.io/grafana/grafana:<tag>`, `podman manifest inspect docker.io/grafana/grafana:<tag>`, or `docker buildx imagetools inspect grafana/grafana:<tag>`.

Digest pinning (`13.2.4@sha256:...`) is documented in the README as an optional override of `DOCKER_IMAGE_VERSION`, not the default. Defaults stay readable and a patch bump remains one-line, while users with strict immutability needs can opt in. The manifest-list digest, not a per-platform digest, must be used so all architectures resolve.

### D5. Version bump to 0.1.0
Set `SERVICE_VERSION ?= 0.1.0` in the Makefile and `horizon/hzn.json`. A minor bump signals a changed default image and multi-arch publishing. Because the deployment policy ID includes the version, the new policy is a separate Exchange object and the old `0.0.1` objects can be removed with `SERVICE_VERSION=0.0.1 make distclean`. This is documented in the README migration note.

### D6. `-P` pull behavior when publishing non-host architectures
`hzn exchange service publish -O -P` pulls the image locally to record its digest. For an `arm` or `arm64` publish from an `amd64` host the pull must still resolve to the manifest-list digest, which is the same for every architecture. During implementation, verify the digest recorded for each architecture and, if `-P` records a host-platform digest, drop `-P` for non-host architectures or pass the manifest-list digest through `DOCKER_IMAGE_VERSION`. This is part of the verification tasks, not an open scope question.

### D7. Documentation
Add the platform table (`linux/amd64` → `amd64`, `linux/arm64` → `arm64`, `linux/arm/v7` → `arm`) to the README and Makefile header, plus publish-all, publish-one, and migration commands. Replace the stale "x86 or Raspberry Pi (arm64)" edge node text with the three architectures. Update the target descriptions.

### D8. Selectable container CLI instead of hard-coded `docker`
Add `export CONTAINER_CLI ?= $(shell command -v docker >/dev/null 2>&1 && echo docker || (command -v podman >/dev/null 2>&1 && echo podman))` near the other variables, and replace every direct `docker` call in `stop`, `init`, `run`, `attach` and `clean` with `$(CONTAINER_CLI)`. `docker` is preferred when both exist, to keep current behavior for existing users. `CONTAINER_CLI=podman make run` forces Podman.

Targets that need a runtime call a small guard (`@test -n "$(CONTAINER_CLI)" || { echo "..."; exit 1; }`) that names `docker`, `podman` and the override variable. `check` and the `hzn` targets do not use the guard, and `check` prints `CONTAINER_CLI` or "none detected".

The commands in use, `run`, `rm -f`, `volume create`, `volume rm`, `rmi -f`, `exec -it` and `ps -aqf`, exist in both CLIs with the same flags, so no per-runtime branching is needed. For `run`, qualify the image as `docker.io/$(DOCKER_IMAGE_BASE):$(DOCKER_IMAGE_VERSION)` so Podman does not depend on `unqualified-search-registries`. The `service.definition.json` image stays unqualified, because the Horizon agent resolves it and Docker Hub is its default.

The variable names `DOCKER_IMAGE_*` and `DOCKER_VOLUME_NAME` are kept. Renaming them would touch `hzn.json`, the JSON templates and every user's environment for no behavior gain.

Alternatives considered:
- *Require Docker and document Podman's `podman-docker` shim*: depends on a host package and hides the choice. Rejected.
- *Hard switch to Podman*: breaks existing Docker users. Rejected.
- *Separate `Makefile.podman`*: duplicates the file and the defaults, which already drift easily. Rejected.

For image inspection (tasks 1.1 and 6.1), the design lists several equivalent tools (`skopeo`, `podman manifest inspect`, `docker buildx imagetools inspect`). Any one that is installed is acceptable, and the task records which was used. No Makefile target depends on them.


### D9. Variables for every repeated literal
Add these variables to the Makefile variable block, each `export ... ?=` with today's value as the default:

| Variable | Default | Replaces |
|---|---|---|
| `GRAFANA_HOST_PORT` | `3000` | host side of `-p` in `run`, URL in `test` and `browse`, `HostPort` in the service definition |
| `GRAFANA_CONTAINER_PORT` | `3000` | container side of `-p` and of `HostPort`, and the value of `GF_SERVER_HTTP_PORT` passed to Grafana |
| `GRAFANA_HOST_IP` | `0.0.0.0` | `HostIP` in the service definition |
| `GRAFANA_DATA_PATH` | `/var/lib/grafana` | volume mount target in `run` and the service definition |
| `GRAFANA_URL` | `http://127.0.0.1:$(GRAFANA_HOST_PORT)` | the URL literals in `test` and `browse` |
| `CONTAINER_RESTART_POLICY` | `unless-stopped` | `--restart=` in `run` |

`GRAFANA_HOST_IP` keeps `0.0.0.0` as the default so behavior does not change, but making it a variable lets an operator bind to `127.0.0.1` without editing files. The default is not changed in this work, because it is outside issue 12. The existing conflict with the security rule to bind to `127.0.0.1` is noted in `AGENTS.md`, and a follow-up change should switch the default.

The JSON side uses `"HostIP": "$GRAFANA_HOST_IP"`, `"HostPort": "$GRAFANA_HOST_PORT:$GRAFANA_CONTAINER_PORT/tcp"`, `"$DOCKER_VOLUME_NAME:$GRAFANA_DATA_PATH"` and an `"environment": ["GF_SERVER_HTTP_PORT=$GRAFANA_CONTAINER_PORT", "GF_PATHS_DATA=$GRAFANA_DATA_PATH"]` entry in the service's deployment section. `hzn` substitutes `$VAR` from the environment, with `MetadataVars` in `horizon/hzn.json` as the fallback when `hzn` runs without `make`. Therefore each new variable is added to `MetadataVars` with the same default. Make exports its variables, so overrides reach `hzn`.

The local `run` passes the same two settings with `-e GF_SERVER_HTTP_PORT=$(GRAFANA_CONTAINER_PORT) -e GF_PATHS_DATA=$(GRAFANA_DATA_PATH)`. With these, the port Grafana listens on and the container side of the port mapping come from one variable and cannot diverge, and the same holds for the data directory and the volume mount target. The defaults equal the image's own (`3000` and `/var/lib/grafana`), so default behavior is unchanged.

The time zone default is also a literal in the `check` text, `service.definition.json` and `userinput.json`. Use `$MY_TIME_ZONE` in the JSON files and print only the actual value in `check`.

`check` stops printing default literals (for example `default: 0.0.1  actual: ...`) because those strings drift. It prints the variable name and its actual value, and the rendered service definition shows the final result.

Alternatives considered:
- *One `GRAFANA_PORT` for both sides*: simpler, but prevents remapping (host 8080 to container 3000), which is the usual reason to change the port.
- *Keep `3000` in JSON and only variable-ize the Makefile*: leaves `make run` and the Horizon deployment disagreeing as soon as a user overrides the port. Rejected.
- *Generate the JSON from a template with `envsubst` in Make*: `hzn` already does the substitution, so a second pass adds no value.

Grafana reads its listen port from `GF_SERVER_HTTP_PORT` and its data directory from `GF_PATHS_DATA`. Passing both from the variables means overriding `GRAFANA_CONTAINER_PORT` or `GRAFANA_DATA_PATH` is enough, in `make run` and in the Horizon deployment. Users do not set the `GF_*` variables by hand. If a user also supplies their own `GF_SERVER_HTTP_PORT` or `GF_PATHS_DATA` another way, the explicit value is theirs to keep consistent, and the README does not recommend it.


## Risks / Trade-offs

- [`-P` records a host-platform digest, so other architectures fail to start] → Verify per D6 on an arm64 or arm node (or by inspecting the manifest list with any tool in D8) before declaring done.
- [`hzn exchange service publish -P` may itself require a local Docker daemon] → Check what `hzn` needs on a Podman-only host during task 6.1. If it needs Docker, document that publishing needs a Docker-compatible socket (for example the Podman socket with `DOCKER_HOST`) or drop `-P` and supply the digest. This is a verification item and not a change to this repository's targets.
- [Podman rootless or short-name resolution differs from Docker] → Use fully qualified image names for the local run (D8) and keep the volume and port options common to both CLIs.
- [Pinned tag goes stale as Grafana ships patch releases] → Document how to bump (`DOCKER_IMAGE_VERSION`, `hzn.json`, `SERVICE_VERSION`). Trading automatic updates for reproducibility is the intent of the issue.
- [Defaults drift between Makefile and `hzn.json`] → Update both in the same task and verify with `make check` plus a grep. No new third copy is introduced.
- [`grafana/grafana` image differs from `-oss` in user, paths or defaults] → The issue states they host the same OSS images. Smoke-test the container on the default port and the existing volume path on amd64 and arm64, and once with a non-default container port to confirm `GF_SERVER_HTTP_PORT` takes effect.
- [A data path other than the image default is not writable by the Grafana user] → The mount target changes but the volume ownership is the image's. Keep the default for normal use and note that a custom `GRAFANA_DATA_PATH` must be writable by the container user.
- [Users with `0.0.1` deployed do not move automatically] → Marked **BREAKING** in the proposal. The new version is published alongside, and the old one is removed explicitly.
- [Shell loops in Make are harder to read] → Keep each loop a few lines, with the architecture printed in each header.
- [`arm` nodes are ARMv7 only] → Documented. No `linux/arm/v6` image exists.
- [Hardware for `arm64` and `arm` acceptance tests may be unavailable] → `make deploy-check` and manifest inspection can be run anywhere, but the container start check needs real nodes. Record any untested architecture in the task notes.
