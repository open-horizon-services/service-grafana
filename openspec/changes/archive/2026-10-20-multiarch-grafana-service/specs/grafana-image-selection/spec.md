## Purpose

Define which Grafana container image and release the local test run and the Open Horizon service definition use, so deployments are reproducible and track the maintained image repository.

## ADDED Requirements

### Requirement: Maintained image repository
The default Grafana image repository SHALL be `grafana/grafana`, not `grafana/grafana-oss`.

#### Scenario: Default repository
- **WHEN** the user runs `make check` with no overrides
- **THEN** `DOCKER_IMAGE_BASE` shows `grafana/grafana`

### Requirement: Pinned Grafana release
The default image tag SHALL be a specific Grafana release (`13.2.4`, or the newest release when the change is implemented). It SHALL NOT be `latest` or any other floating tag.

#### Scenario: Default tag is a version
- **WHEN** the user runs `make check` with no overrides
- **THEN** `DOCKER_IMAGE_VERSION` shows a full `MAJOR.MINOR.PATCH` version and not `latest`

#### Scenario: Service definition image
- **WHEN** the service definition is rendered with default settings
- **THEN** the deployment image is `grafana/grafana:<pinned version>`

#### Scenario: Override the tag
- **WHEN** the user sets `DOCKER_IMAGE_VERSION` to another valid tag
- **THEN** both the local run and the rendered service definition use that tag

### Requirement: Multi-architecture image
The selected image tag SHALL provide a manifest list with `linux/amd64`, `linux/arm64` and `linux/arm/v7` platforms, so all published architectures reference the same image name and tag.

#### Scenario: Platforms present
- **WHEN** the pinned tag is inspected with a manifest tool
- **THEN** the list contains `linux/amd64`, `linux/arm64` and `linux/arm/v7`

#### Scenario: Same image for every architecture
- **WHEN** service definitions are rendered for `amd64`, `arm64` and `arm`
- **THEN** only the `arch` value and label differ between them

### Requirement: Defaults stay consistent across files
The image repository, image tag and service version defaults SHALL be identical in the Makefile and `horizon/hzn.json`. The Makefile `check` output SHALL show the same values.

#### Scenario: Consistent defaults
- **WHEN** the defaults in the Makefile and `horizon/hzn.json` are compared
- **THEN** `DOCKER_IMAGE_BASE`, `DOCKER_IMAGE_VERSION` and `SERVICE_VERSION` match

### Requirement: Service runs on supported architectures
A node of any published architecture that forms an agreement SHALL start the container and serve the Grafana web UI on port 3000.

#### Scenario: amd64 node
- **WHEN** an `amd64` node forms an agreement for the service
- **THEN** `make test` returns the Grafana response on port 3000

#### Scenario: arm64 node
- **WHEN** an `arm64` node forms an agreement for the service
- **THEN** `make test` returns the Grafana response on port 3000
