# service-grafana


This is an Open Horizon configuration to deploy a vanilla instance of the open-source [Grafana](https://grafana.com/docs/grafana/latest/setup-grafana/installation/docker/) software.  The Grafana UI is designed to run in a web browser, so you will need to navigate to <http://localhost:3000/> to use the software once it has been deployed.

## Service Structure

This service follows the standard Open Horizon service structure created by `hzn dev service new`. All service definition files are organized in the `horizon/` directory:

```
service-grafana/
├── horizon/
│   ├── dependencies/             # Service dependencies (if any)
│   ├── deployment.policy.json    # Deployment policy (for publishing to Exchange)
│   ├── hzn.json                  # HZN CLI configuration with metadata variables
│   ├── node.policy.json          # Example node policy
│   ├── service.definition.json   # Core service definition
│   ├── service.policy.json       # Service policy for policy-based deployment
│   └── userinput.json            # User input variable values
├── Makefile                      # Build and deployment automation
└── README.md                     # This file
```

## Supported architectures

The service uses the official [`grafana/grafana`](https://hub.docker.com/r/grafana/grafana) image, pinned to version `13.2.4` (`DOCKER_IMAGE_VERSION`). `make publish-service` publishes one service definition per architecture:

| Image platform | Open Horizon `ARCH` | Typical hardware |
|---|---|---|
| `linux/amd64` | `amd64` | x86-64 Linux and macOS computers |
| `linux/arm64` | `arm64` | Raspberry Pi 3, 4 and 5 with a 64-bit OS, Apple silicon |
| `linux/arm/v7` | `arm` | Raspberry Pi with a 32-bit OS |

`linux/arm/v6` (Raspberry Pi Zero and Raspberry Pi 1) has no image and is not supported.

The deployment policy matches any architecture (`"arch": "*"`), so one policy serves every published definition and each node receives the definition for its own architecture.

To pin the image to an exact build, set `DOCKER_IMAGE_VERSION` to the tag plus the digest of the multi-architecture manifest list, for example `DOCKER_IMAGE_VERSION=13.2.4@sha256:<manifest-list-digest>`. Use the manifest list digest and not a single platform digest, or the other architectures will not start.

## Prerequisites

**Management Hub:** [Install the Open Horizon Management Hub](https://open-horizon.github.io/quick-start) or have access to an existing hub in order to publish this service and register your edge node.  You may also choose to use a downstream commercial distribution based on Open Horizon, such as IBM's Edge Application Manager.  If you'd like to use the Open Horizon community hub, you may [apply for a temporary account](https://wiki.lfedge.org/display/LE/Open+Horizon+Management+Hub+Developer+Instance) and have credentials sent to you.

**Edge Node:** You will need a computer running Linux or macOS on `amd64` (x86-64), a 64-bit `arm64` computer, or a 32-bit ARMv7 (`arm`) computer such as a Raspberry Pi running Raspberry Pi OS or Ubuntu, to install and use Grafana deployed by Open Horizon.  You will need to install the Open Horizon agent software, anax, on the edge node and register it with a hub.

**Container runtime:** The local test targets (`init`, `run`, `stop`, `attach`, `clean`) work with either Docker or Podman.  The Makefile uses `docker` if it is installed, otherwise `podman`.  To choose one, set `CONTAINER_CLI`, for example `CONTAINER_CLI=podman make run`.  If neither is installed, those targets stop with a message.  Publishing the service needs the `hzn` CLI.  `hzn exchange service publish -P` pulls the image through the local Docker client and records the digest of the multi-architecture manifest list.  Publishing was tested only on a host with Docker; whether it works on a Podman-only host has not been tested.

**Optional utilities to install:**  With `brew` on macOS (you may need to install _that_ as well), `apt-get` on Ubuntu or Raspberry Pi OS, `yum` on Fedora, install `gcc`, `make`, `git`, `jq`, `curl`, `net-tools`.  Not all of those may exist on all platforms, and some may already be installed.  But reflexively installing those has proven helpful in having the right tools available when you need them.

## Installation

Clone the `service-grafana` GitHub repo from a terminal prompt on the edge node and enter the folder where the artifacts were copied.

  NOTE: This assumes that `git` has been installed on the edge node.

  ``` shell
  git clone https://github.com/jwende/service-grafana.git
  cd service-grafana
  ```

Run `make clean` to confirm that the "make" utility is installed and working.

Confirm that you have the Open Horizon agent installed by using the CLI to check the version:

  ``` shell
  hzn version
  ```

  It should return values for both the CLI and the Agent (actual version numbers may vary from those shown):

  ``` text
  Horizon CLI version: 2.30.0-1491
  Horizon Agent version: 2.30.0-1491 
  ```

  If it returns "Command not found", then the Open Horizon agent is not installed.

  If it returns a version for the CLI but not the agent, then the agent is installed but not running.  You may run it with `systemctl horizon start` on Linux or `horizon-container start` on macOS.

Check that the agent is in an unconfigured state, and that it can communicate with a hub.  If you have the `jq` utility installed, run `hzn  list | jq '.configstate.state'` and check that the value returned is "unconfigured".  If not, running `make agent-stop` or `hzn unregister -f` will put the agent in an unconfigured state.  Run `hzn  list | jq '.configuration'` and check that the JSON returned shows values for the "exchange_version" property, as well as the "exchange_api" and "mms_api" properties showing URLs.  If those do not, then the agent is not configured to communicate with a hub.  If you do not have `jq` installed, run `hzn  list` and eyeball the sections mentioned above.

NOTE: If "exchange_version" is showing an empty value, you will not be able to publish and run the service.  The only fix found to this condition thus far is to re-install the agent using these instructions:

``` shell
hzn unregister -f # to ensure that the  is unregistered
systemctl horizon stop # for Linux, or "horizon-container stop" on macOS
export HZN_ORG_ID=myorg   # or whatever you customized it to
export HZN_EXCHANGE_USER_AUTH=admin:<admin-pw>   # use the pw deploy-mgmt-hub.sh displayed
export HZN_FSS_CSSURL=http://<mgmt-hub-ip>:9443/
curl -sSL https://github.com/open-horizon/anax/releases/latest/download/agent-install.sh | bash -s -- -i anax: -k css: -c css: -p IBM/pattern-ibm.helloworld -w '*' -T 120
```

## Usage

To manually run Grafana locally as a test, enter `make`.  This will open a browser window, but it may do so before Grafan is completely ready.  If you get a blank web page, wait about 10 seconds or so and reload the page.  Running `make attach` will connect you to a prompt running inside the container, and you can end that session by entering `exit`.  When you are done, run `make stop` in the terminal to end the test.
The initial user is 'admin' with password 'admin'.

To create [the service definition](https://github.com/open-horizon/examples/blob/master/edge/services/helloworld/CreateService.md#build-publish-your-hw), publish it to the hub, and then form an agreement to download and run Grafana, enter `make publish`.  This publishes the service and service policy for every architecture in `ARCHS` (`amd64 arm64 arm` by default).  When installation is complete and an agreement has been formed, exit the watch command with Control-C.  You may then open a browser pointing to Grafana by entering `make browse` or visiting [http://localhost:3000/](http://localhost:3000/) in a web browser.

To publish only some architectures, set `ARCHS`:

``` shell
ARCHS=arm64 make publish-service publish-service-policy
make publish-deployment-policy
```

Each publish and remove step runs for every architecture, reports any that failed, and exits with an error at the end if one did.

### Settings

These variables can be overridden in the environment or on the `make` command line, for example `make run GRAFANA_HOST_PORT=8080`.  The same values are used by `make run` and by `horizon/service.definition.json`.  `horizon/hzn.json` holds the same defaults for when `hzn` runs without `make`.

| Variable | Default | Purpose |
|---|---|---|
| `GRAFANA_HOST_PORT` | `3000` | Port published on the host |
| `GRAFANA_CONTAINER_PORT` | `3000` | Port Grafana listens on in the container |
| `GRAFANA_HOST_IP` | `0.0.0.0` | Host address the port is bound to.  Set `127.0.0.1` to keep Grafana off the network |
| `GRAFANA_DATA_PATH` | `/var/lib/grafana` | Where the data volume is mounted |
| `GRAFANA_URL` | `http://127.0.0.1:$GRAFANA_HOST_PORT` | URL used by `make test` and `make browse` |
| `CONTAINER_RESTART_POLICY` | `unless-stopped` | Restart policy for the local container |
| `MY_TIME_ZONE` | `America/New_York` | Time zone |
| `ARCHS` | `amd64 arm64 arm` | Architectures to publish, remove and check |
| `CONTAINER_CLI` | detected | `docker` or `podman` for the local targets |

`GRAFANA_CONTAINER_PORT` and `GRAFANA_DATA_PATH` are passed to Grafana automatically (as `GF_SERVER_HTTP_PORT` and `GF_PATHS_DATA`), so you do not need to set any `GF_*` variable yourself.  A custom `GRAFANA_DATA_PATH` must be writable by the container user.

### Upgrading from version 0.0.1

Version `0.1.0` changes the image from `grafana/grafana-oss:latest` to the pinned `grafana/grafana` and publishes all architectures.  Because the deployment policy ID includes the version, `0.1.0` is a separate set of Exchange objects.  Nodes with `0.0.1` keep running it until you remove it:

``` shell
SERVICE_VERSION=0.0.1 ARCHS=amd64 make remove-deployment-policy remove-service-policy remove-service
make publish-service publish-service-policy publish-deployment-policy
```

Set `ARCHS` to the architectures you published for `0.0.1`.  Do not run `SERVICE_VERSION=0.0.1 make distclean` unless you also want to unregister this node and delete the local container, image and volume.

## Advanced details

### Debugging

The Makefile includes several targets to assist you in inspecting what is happening to see if they match your expectations.  They include:

`make log` to see both the event logs and the service logs.

`make check` to see the values in your environment variables.  It will also show the service definition file with those values filled in, once for each architecture in `ARCHS`.

`make deploy-check` to see if the properties and constraints that you've configured match each other to potentially form an agreement.  It runs once for each architecture in `ARCHS`.

`make test` to see if the web server is responding.

`make attach` to connect to the running container and open a shell inside it.

> **Note** The Grafana container by default runs in un-privileged mode, but it may require privileged conditions in certain cases. In that case you can manually add "--privileged" flag in the Makefile under the `run` target.

### All Makefile targets

* `default` - init run browse
* `init` - optionally create the container volume
* `run` - manually run the container locally as a test
* `browse` - open the UI in a web browser
* `check` - view current settings
* `stop` - halt a locally-run container
* `dev` - manually run it locally and connect to a terminal in the container
* `attach` - connect to a terminal in the container
* `test` - request the web UI from the terminal to confirm that it is running and available
* `clean` - remove the container image and volume
* `distclean` - clean (see above) AND unregister the node and remove the service files for every architecture in `ARCHS` from the hub
* `build` - N/A
* `push` - N/A
* `publish-service` - Publish the service definition file for each architecture in `ARCHS` to the hub in your organization
* `remove-service` - Remove the service definition file for each architecture in `ARCHS` from the hub in your organization
* `publish-service-policy` - Publish the [service policy](https://github.com/open-horizon/examples/blob/master/edge/services/helloworld/PolicyRegister.md#service-policy) file for each architecture in `ARCHS` to the hub in your org
* `remove-service-policy` - Remove the service policy file for each architecture in `ARCHS` from the hub in your org
* `publish-deployment-policy` - Publish a [deployment policy](https://github.com/open-horizon/examples/blob/master/edge/services/helloworld/PolicyRegister.md#deployment-policy) for the service to the hub in your org
* `remove-deployment-policy` - Remove a deployment policy for the service from the hub in your org
* `agent-run` - register your agent's [node policy](https://github.com/open-horizon/examples/blob/master/edge/services/helloworld/PolicyRegister.md#node-policy) with the hub
* `publish` - Publish the service def, service policy, deployment policy, and then register your agent
* `agent-stop` - unregister your agent with the hub, halting all agreements and stopping containers
* `deploy-check` - confirm that a registered agent is compatible with the service and deployment, for each architecture in `ARCHS`
* `log` - check the agent event logs
