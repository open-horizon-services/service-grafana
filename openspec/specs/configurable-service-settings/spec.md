# configurable-service-settings Specification

## Purpose

Define which settings of the Grafana service are held in overridable variables, so a single value drives the local run, the test and browse targets, and the Horizon service definition, with no repeated literals.

## Requirements

### Requirement: Configurable port
The Makefile SHALL define the host port and the container port as overridable variables with defaults of `3000`. The local run, `test`, `browse` and the Horizon service definition SHALL take the port from these variables and SHALL NOT contain a literal port number.

#### Scenario: Default port
- **WHEN** no port variable is overridden
- **THEN** the container is reachable at port 3000 and `make test` and `make browse` use port 3000

#### Scenario: Override host port
- **WHEN** the user sets the host port variable to `8080` and runs `make run test`
- **THEN** the container publishes host port 8080 and `make test` requests port 8080

#### Scenario: Service definition follows the variable
- **WHEN** the service definition is rendered with the host port variable set to `8080`
- **THEN** its published port mapping uses `8080` and contains no literal `3000`

### Requirement: Grafana listens on the configured container port
The local run and the Horizon service definition SHALL pass the container port variable to Grafana as `GF_SERVER_HTTP_PORT`, so the port Grafana listens on always equals the container side of the port mapping.

#### Scenario: Container port override, local run
- **WHEN** the user sets the container port variable to `8081` and host port to `8080` and runs `make run test`
- **THEN** the run command contains `-p 8080:8081` and `GF_SERVER_HTTP_PORT=8081`, and `make test` receives the Grafana response on host port 8080

#### Scenario: Container port override, Horizon deployment
- **WHEN** the service definition is rendered with the container port variable set to `8081`
- **THEN** its port mapping ends in `:8081/tcp` and its environment contains `GF_SERVER_HTTP_PORT=8081`

#### Scenario: Defaults unchanged
- **WHEN** no port variable is overridden
- **THEN** `GF_SERVER_HTTP_PORT` is `3000`, matching the image default

### Requirement: Configurable data path
The container data path SHALL be an overridable variable defaulting to `/var/lib/grafana`. The local run and the service definition SHALL both use it for the volume mount target and SHALL pass it to Grafana as `GF_PATHS_DATA`, so Grafana stores its data on the mounted volume.

#### Scenario: Same path in both places
- **WHEN** the data path variable is overridden
- **THEN** the local run and the rendered service definition mount the volume at the new path and set `GF_PATHS_DATA` to the same path

### Requirement: Configurable local URL
The URL used by `test` and `browse` SHALL be built from a single variable that includes the host port variable, so changing the port changes the URL without editing any recipe.

#### Scenario: One URL definition
- **WHEN** the Makefile recipes for `test` and `browse` are inspected
- **THEN** both reference the URL variable and neither contains a literal host, port or scheme

### Requirement: No duplicated default literals in recipes
Default values SHALL be defined once in the Makefile variable block. The `check` output SHALL print the actual value of each variable and SHALL NOT repeat default literals in its text.

#### Scenario: Check output follows overrides
- **WHEN** the user runs `make check` with an overridden value
- **THEN** the output shows the overridden value and no stale default text for that variable

### Requirement: New and changed targets use variables
The architecture list, container CLI, image repository, image tag, service name, service version and organization SHALL be referenced through variables in every recipe, with no literal copies of those values.

#### Scenario: Search recipes for literals
- **WHEN** the Makefile recipes are searched for the default values `grafana/grafana`, `amd64`, `arm64`, `0.1.0` and `service-grafana`
- **THEN** matches appear only in the variable definitions and comments

### Requirement: Matching defaults for JSON-side variables
The port, data path, image and version variables that the service definition uses SHALL also be listed with the same defaults in `horizon/hzn.json`, so running `hzn` without `make` renders the same definition.

#### Scenario: hzn.json in sync
- **WHEN** the defaults in the Makefile and `horizon/hzn.json` are compared
- **THEN** the port, data path, image, tag and service version values are identical
