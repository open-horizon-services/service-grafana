# local-container-runtime Specification

## Purpose

Define how the Makefile chooses the container CLI for local runs, cleanup and image inspection, so the project works on hosts that have Docker, Podman, or either one, without requiring Docker.

## Requirements

### Requirement: Container CLI selection
The Makefile SHALL use one overridable container CLI variable for every local container operation. When the variable is not set, it SHALL default to `docker` if that command is available, otherwise `podman` if available.

#### Scenario: Only Podman installed
- **WHEN** `docker` is not on `PATH`, `podman` is, and the variable is not set
- **THEN** the local targets run with `podman`

#### Scenario: Only Docker installed
- **WHEN** `podman` is not on `PATH`, `docker` is, and the variable is not set
- **THEN** the local targets run with `docker`

#### Scenario: Both installed
- **WHEN** both commands are on `PATH` and the variable is not set
- **THEN** `docker` is used

#### Scenario: Explicit override
- **WHEN** the user sets the variable to `podman` while `docker` is also installed
- **THEN** the local targets run with `podman`

### Requirement: No hard-coded Docker command
No Makefile target SHALL invoke `docker` directly. Targets that run containers, manage volumes, remove images, attach to a container or inspect image manifests SHALL use the selected container CLI.

#### Scenario: Search for direct calls
- **WHEN** the Makefile recipes are searched for a direct `docker` command
- **THEN** none is found outside the default-detection logic

### Requirement: Clear failure when no runtime exists
When neither `docker` nor `podman` is available and the user has not set the variable, targets that need a container CLI SHALL stop with a message that names both options and the override variable. Targets that do not need a container CLI SHALL still work.

#### Scenario: No runtime
- **WHEN** neither command is installed and the user runs `make run`
- **THEN** the command exits non-zero with a message that explains how to install one or set the variable

#### Scenario: Hub-only targets
- **WHEN** neither command is installed and the user runs `make check`
- **THEN** `make check` completes and shows that no container CLI was detected

### Requirement: Local run works on Podman
The local run SHALL start the pinned Grafana image with either runtime, using an image reference that does not depend on Docker Hub being a default registry, and serve the web UI on port 3000.

#### Scenario: Short image name with Podman
- **WHEN** `make run` is used with `podman` and the default image
- **THEN** the image pulls from Docker Hub without an interactive registry prompt, and `make test` returns the Grafana response

### Requirement: Documented runtime support
The README SHALL state that Docker and Podman are supported for local use, how to select one, and that publishing and the Horizon agent have their own container runtime requirements.

#### Scenario: README content
- **WHEN** a user reads the README
- **THEN** it explains the container CLI variable and its default order of detection
