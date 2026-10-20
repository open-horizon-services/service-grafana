## Purpose

Define how the Grafana Open Horizon service is published, validated and removed for every container architecture that Grafana ships, so one Makefile invocation covers all supported edge nodes.

## ADDED Requirements

### Requirement: Supported architecture list
The Makefile SHALL expose a single overridable variable that lists the Open Horizon architectures to publish, with a default of `amd64 arm64 arm`.

#### Scenario: Default list
- **WHEN** the variable is not overridden
- **THEN** it contains exactly `amd64`, `arm64` and `arm`

#### Scenario: Override the list
- **WHEN** the user sets the variable to `arm64` on the command line or in the environment
- **THEN** every multi-architecture target acts only on `arm64`

#### Scenario: Visible in check output
- **WHEN** the user runs `make check`
- **THEN** the output shows the architecture list and its actual value

### Requirement: Publish service for all architectures
Publishing the service SHALL create one Exchange service definition per listed architecture. Each definition SHALL have the ID `$HZN_ORG_ID/$SERVICE_NAME_$SERVICE_VERSION_<arch>`, and all definitions SHALL reference the same image repository and tag.

#### Scenario: Publish with defaults
- **WHEN** the user runs `make publish-service` with default settings
- **THEN** service definitions exist in the Exchange for `amd64`, `arm64` and `arm` at the configured version

#### Scenario: Publish failure for one architecture
- **WHEN** publishing fails for one architecture
- **THEN** the command exits non-zero and identifies the failing architecture

### Requirement: Publish service policy for all architectures
Publishing the service policy SHALL attach the service policy to the service definition of every listed architecture.

#### Scenario: Policies attached
- **WHEN** the user runs `make publish-service-policy` after publishing the services
- **THEN** each of the three architecture-specific service definitions has the service policy attached

### Requirement: Remove service and service policy for all architectures
Removing the service and service policy SHALL delete the Exchange entries for every listed architecture at the configured version. Removal SHALL NOT stop at the first architecture that is missing or fails.

#### Scenario: Remove all service definitions
- **WHEN** the user runs `make remove-service`
- **THEN** no service definition for any listed architecture at the configured version remains in the Exchange

#### Scenario: Remove all service policies
- **WHEN** the user runs `make remove-service-policy`
- **THEN** no listed architecture at the configured version retains a service policy

#### Scenario: One architecture was never published
- **WHEN** one listed architecture has no published definition and the user runs a removal target
- **THEN** the remaining architectures are still removed

### Requirement: Full cleanup covers all architectures
`make distclean` SHALL remove the service definitions and service policies for every listed architecture, along with the deployment policy and the local container, image and volume.

#### Scenario: Distclean after multi-arch publish
- **WHEN** the user runs `make distclean` after a multi-architecture publish
- **THEN** no service definition for any listed architecture at the configured version remains in the Exchange

### Requirement: Deploy check for all architectures
`make deploy-check` SHALL run the policy compatibility check once for each listed architecture and SHALL report which architecture each result belongs to.

#### Scenario: All architectures compatible
- **WHEN** the policies are valid for every listed architecture
- **THEN** `make deploy-check` exits zero and prints a result for each architecture

#### Scenario: One architecture incompatible
- **WHEN** the check fails for one architecture
- **THEN** `make deploy-check` exits non-zero and the output identifies the failing architecture

### Requirement: Single deployment policy across architectures
The service SHALL be deployed through one deployment policy that matches any architecture, so agreements form on `amd64`, `arm64` and `arm` nodes without per-architecture policies.

#### Scenario: Policy matches any architecture
- **WHEN** the deployment policy is published
- **THEN** its service architecture is `*` and its ID contains the service name and version but no architecture

### Requirement: New version does not collide with published definitions
The default service version SHALL be higher than the previously published `0.0.1`, so publishing the new definitions does not overwrite or conflict with existing Exchange entries.

#### Scenario: Default version
- **WHEN** the user runs `make check` with no overrides
- **THEN** the service version shown is greater than `0.0.1` and is the same in the Makefile, `horizon/hzn.json` and the service definition default

### Requirement: Documentation of supported architectures
The README and the Makefile header comments SHALL list the supported architectures, state that `arm` means ARMv7 (`linux/arm/v7`), state that Raspberry Pi Zero and 1 (`linux/arm/v6`) are unsupported, and explain how to publish all or one architecture.

#### Scenario: README content
- **WHEN** a user reads the README
- **THEN** it contains a table that maps Docker platforms to Open Horizon architectures, the pinned Grafana version, and the commands to publish all architectures or a single one
