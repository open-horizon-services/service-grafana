# AGENTS.md

This file provides guidance to agents when working with code in this repository.

## Project Overview

This repository contains an **Open Horizon service configuration** for deploying Grafana, an open-source analytics and monitoring platform. The project is designed to run Grafana as a containerized edge service on Open Horizon-managed edge nodes.

**Key Technologies:**
- **Open Horizon**: Edge computing platform for autonomous management of containerized workloads
- **Grafana OSS**: Third-party Docker image (`grafana/grafana-oss`) for data visualization
- **Docker**: Container runtime with persistent volume storage
- **Make**: Build automation and service lifecycle management

**Architecture:**
- Deploys pre-built Grafana Docker images (not custom-built)
- Multi-architecture support: amd64, arm64, arm/v7
- Policy-based deployment using Open Horizon's service, deployment, and node policies
- Persistent data storage via Docker volumes (`grafana-storage`)
- Web UI accessible on port 3000

## Building and Running

### Prerequisites
- Open Horizon Management Hub access (or IBM Edge Application Manager)
- Open Horizon agent (`anax`) installed and registered on edge node
- Docker installed
- `hzn` CLI tool available
- Optional: `jq`, `curl`, `git`, `make`

### Local Testing (Manual)
```bash
# Initialize Docker volume and run Grafana locally
make                    # Equivalent to: make init run browse

# Stop local instance
make stop

# Clean up (removes container and volume)
make clean
```

### Publishing to Open Horizon Hub
```bash
# Publish service definition, policies, and register node
make publish

# This executes:
# 1. make publish-service          - Publishes service definition to hub
# 2. make publish-service-policy   - Publishes service policy
# 3. make publish-deployment-policy - Publishes deployment policy
# 4. make agent-run                - Registers node with hub
```

### Unregistering and Cleanup
```bash
# Unregister node and remove all policies/services
make distclean

# Just unregister the node
make agent-stop
```

### Key Makefile Targets
- `make check` - Display environment variables and service definition
- `make deploy-check` - Verify policy compatibility before deployment
- `make log` - View Open Horizon event logs and service logs
- `make test` - Test if Grafana web UI is responding
- `make attach` - Connect to running container shell
- `make browse` - Open Grafana UI in browser (http://localhost:3000)

## Configuration

### Environment Variables
All configuration is done via environment variables (can be set in shell or `.env` file):

**Docker Configuration:**
- `DOCKER_IMAGE_BASE` - Base image name (default: `grafana/grafana-oss`)
- `DOCKER_IMAGE_VERSION` - Image tag (default: `latest`)
- `DOCKER_VOLUME_NAME` - Persistent volume name (default: `grafana-storage`)

**Open Horizon Configuration:**
- `HZN_ORG_ID` - Organization ID in Open Horizon hub (default: `examples`)
- `SERVICE_NAME` - Service identifier (default: `service-grafana`)
- `SERVICE_VERSION` - Service version (default: `0.0.1`)
- `ARCH` - Target architecture (default: `amd64`)

**Application Configuration:**
- `MY_TIME_ZONE` - Timezone for Grafana (default: `America/New_York`)

### Policy Files

**service.definition.json**
- Defines the service metadata, Docker image, port mappings, and volume binds
- Uses environment variable substitution (`$VAR_NAME`)
- Exposes port 3000 for web UI
- Configurable user input: `MY_TIME_ZONE`

**deployment.policy.json**
- Defines deployment constraints and properties
- Constraints: `purpose == automation` and `openhorizon.allowPrivileged == true`
- Supports all architectures (`arch: "*"`)

**service.policy.json** and **node.policy.json**
- Define service and node-level policies for agreement formation

## Development Conventions

### No Custom Build Process
This project does **not** build custom Docker images. It deploys the official `grafana/grafana-oss` image from Docker Hub. The `make build` and `make push` targets are no-ops with informational messages.

### Policy-Based Deployment
Open Horizon uses a policy-based approach where:
1. **Service Policy** - Defines service requirements
2. **Deployment Policy** - Defines where/how service should be deployed
3. **Node Policy** - Defines node capabilities and properties
4. Agreements are formed when policies match

### Debugging Workflow
1. Use `make check` to verify environment variables
2. Use `make deploy-check` to validate policy compatibility
3. Use `make log` to view event and service logs
4. Use `make attach` to inspect running container
5. Use `make test` to verify web UI availability

### Privileged Mode
The container runs in unprivileged mode by default. If privileged access is needed, manually add `--privileged` flag to the `docker run` command in the Makefile under the `run` target.

### Default Credentials
- Username: `admin`
- Password: `admin` (Grafana will prompt to change on first login)

## Project Maintainers
- Joe Pearson (@joewxboy) - joe.pearson@us.ibm.com
- Joerg Wende (@jwende) - jwende@gmx.de

## Additional Resources
- [Grafana Documentation](https://grafana.com/docs/grafana/latest/)
- [Open Horizon Documentation](https://open-horizon.github.io/)
- [Open Horizon Examples](https://github.com/open-horizon/examples)
