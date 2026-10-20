# Multi-arch container instance of the open-source grafana project intended for Open Horizon Linux edge nodes
#
# Supported platforms (the grafana/grafana image manifest list) and the Open Horizon ARCH value for each:
#   linux/amd64  -> amd64
#   linux/arm64  -> arm64
#   linux/arm/v7 -> arm      (linux/arm/v6, e.g. Raspberry Pi Zero and 1, has no image)
#
# ARCHS lists the architectures the publish, remove and deploy-check targets act on (default: all three).
#   Publish every architecture:   make publish-service publish-service-policy publish-deployment-policy
#   Publish one architecture:     ARCHS=arm64 make publish-service publish-service-policy
#   ARCH is the value for a single architecture, used when rendering horizon/service.definition.json.
#
# CONTAINER_CLI is the command used by the local container targets (run, stop, init, attach, clean).
#   It is auto-detected as docker, else podman. Force one with: CONTAINER_CLI=podman make run
#   The publish targets need the hzn CLI. hzn publish -P pulls the image via Docker to record its digest (not tested without Docker).
export DOCKER_IMAGE_BASE ?= grafana/grafana
export DOCKER_IMAGE_NAME ?= grafana
export DOCKER_IMAGE_VERSION ?= 13.2.4
export DOCKER_VOLUME_NAME ?= grafana-storage

# DockerHub ID of the third party providing the image (usually yours if building and pushing) 
export DOCKER_HUB_ID ?= grafana

# The Open Horizon organization ID namespace where you will be publishing the service definition file
export HZN_ORG_ID ?= examples

# Variables that can be overridden by your environment variables
export MY_TIME_ZONE ?= America/New_York

# Grafana settings shared by the local run and horizon/service.definition.json
export GRAFANA_HOST_PORT ?= 3000
export GRAFANA_CONTAINER_PORT ?= 3000
export GRAFANA_HOST_IP ?= 0.0.0.0
export GRAFANA_DATA_PATH ?= /var/lib/grafana
export GRAFANA_URL ?= http://127.0.0.1:$(GRAFANA_HOST_PORT)
export CONTAINER_RESTART_POLICY ?= unless-stopped

# Open Horizon settings for publishing metadata about the service
export DEPLOYMENT_POLICY_NAME ?= deployment-policy-grafana
export NODE_POLICY_NAME ?= node-policy-grafana
export SERVICE_NAME ?= service-grafana
export SERVICE_VERSION ?= 0.1.0

# Architecture used to render a single service definition (assumes hzn CLI installed)
export ARCH ?= amd64

# Architectures that publish, remove and deploy-check act on
export ARCHS ?= amd64 arm64 arm

# Container command for the local targets: docker if installed, else podman, else empty
export CONTAINER_CLI ?= $(shell command -v docker >/dev/null 2>&1 && echo docker || (command -v podman >/dev/null 2>&1 && echo podman))

# Fully qualified so podman does not depend on its unqualified-search-registries setting
LOCAL_IMAGE = docker.io/$(DOCKER_IMAGE_BASE):$(DOCKER_IMAGE_VERSION)

# Detect Operating System running Make
OS := $(shell uname -s)

default: init run browse

check:
	@echo "====================="
	@echo "ENVIRONMENT VARIABLES"
	@echo "====================="
	@printf '%-26s %s\n' DOCKER_IMAGE_BASE "$(DOCKER_IMAGE_BASE)"
	@printf '%-26s %s\n' DOCKER_IMAGE_NAME "$(DOCKER_IMAGE_NAME)"
	@printf '%-26s %s\n' DOCKER_IMAGE_VERSION "$(DOCKER_IMAGE_VERSION)"
	@printf '%-26s %s\n' DOCKER_VOLUME_NAME "$(DOCKER_VOLUME_NAME)"
	@printf '%-26s %s\n' DOCKER_HUB_ID "$(DOCKER_HUB_ID)"
	@printf '%-26s %s\n' HZN_ORG_ID "$(HZN_ORG_ID)"
	@printf '%-26s %s\n' MY_TIME_ZONE "$(MY_TIME_ZONE)"
	@printf '%-26s %s\n' GRAFANA_HOST_PORT "$(GRAFANA_HOST_PORT)"
	@printf '%-26s %s\n' GRAFANA_CONTAINER_PORT "$(GRAFANA_CONTAINER_PORT)"
	@printf '%-26s %s\n' GRAFANA_HOST_IP "$(GRAFANA_HOST_IP)"
	@printf '%-26s %s\n' GRAFANA_DATA_PATH "$(GRAFANA_DATA_PATH)"
	@printf '%-26s %s\n' GRAFANA_URL "$(GRAFANA_URL)"
	@printf '%-26s %s\n' CONTAINER_RESTART_POLICY "$(CONTAINER_RESTART_POLICY)"
	@printf '%-26s %s\n' DEPLOYMENT_POLICY_NAME "$(DEPLOYMENT_POLICY_NAME)"
	@printf '%-26s %s\n' NODE_POLICY_NAME "$(NODE_POLICY_NAME)"
	@printf '%-26s %s\n' SERVICE_NAME "$(SERVICE_NAME)"
	@printf '%-26s %s\n' SERVICE_VERSION "$(SERVICE_VERSION)"
	@printf '%-26s %s\n' ARCH "$(ARCH)"
	@printf '%-26s %s\n' ARCHS "$(ARCHS)"
	@printf '%-26s %s\n' CONTAINER_CLI "$(if $(CONTAINER_CLI),$(CONTAINER_CLI),none detected)"
	@echo ""
	@echo "=================="
	@echo "SERVICE DEFINITION"
	@echo "=================="
	@for a in $(ARCHS); do \
		echo "--- $$a ---"; \
		ARCH=$$a envsubst < horizon/service.definition.json; \
		echo ""; \
	done

# Stops the targets that need a local container runtime when none is installed
require-container-cli:
	@test -n "$(CONTAINER_CLI)" || { \
		echo "No container runtime found. Install docker or podman, or set CONTAINER_CLI (for example CONTAINER_CLI=podman)." >&2; \
		exit 1; \
	}

stop: require-container-cli
	@$(CONTAINER_CLI) rm -f $(DOCKER_IMAGE_NAME) >/dev/null 2>&1 || :

init: require-container-cli
	@$(CONTAINER_CLI) volume create $(DOCKER_VOLUME_NAME)

run: stop
	@$(CONTAINER_CLI) run -d \
		--name $(DOCKER_IMAGE_NAME) \
		--restart=$(CONTAINER_RESTART_POLICY) \
		-e TZ=$(MY_TIME_ZONE) \
		-e GF_SERVER_HTTP_PORT=$(GRAFANA_CONTAINER_PORT) \
		-e GF_PATHS_DATA=$(GRAFANA_DATA_PATH) \
		-v $(DOCKER_VOLUME_NAME):$(GRAFANA_DATA_PATH) \
		-p $(GRAFANA_HOST_PORT):$(GRAFANA_CONTAINER_PORT) \
		$(LOCAL_IMAGE)

dev: run attach

attach: require-container-cli
	@$(CONTAINER_CLI) exec -it \
		`$(CONTAINER_CLI) ps -aqf "name=$(DOCKER_IMAGE_NAME)"` \
		/bin/bash		

test:
	@curl -sS $(GRAFANA_URL)

browse:
ifeq ($(OS),Darwin)
	@open $(GRAFANA_URL)
else
	@xdg-open $(GRAFANA_URL)
endif

clean: stop
	@$(CONTAINER_CLI) rmi -f $(LOCAL_IMAGE) >/dev/null 2>&1 || :
	@$(CONTAINER_CLI) volume rm $(DOCKER_VOLUME_NAME)

distclean: agent-stop remove-deployment-policy remove-service-policy remove-service clean

build:
	@echo "There is no Docker image build process since this container is provided by a third-party from official sources."

push:
	@echo "There is no Docker image push process since this container is provided by a third-party from official sources."

publish: publish-service publish-service-policy publish-deployment-policy agent-run browse

# Pull, not push, Docker image since provided by third party
# Each target below runs once per architecture in ARCHS, continues after a failure and fails at the end if any architecture failed
publish-service:
	@echo "=================="
	@echo "PUBLISHING SERVICE"
	@echo "=================="
	@rc=0; \
	for a in $(ARCHS); do \
		echo "--- $$a ---"; \
		ARCH=$$a hzn exchange service publish -O -P --json-file=horizon/service.definition.json || { echo "FAILED to publish service for $$a" >&2; rc=1; }; \
	done; \
	echo ""; \
	exit $$rc

# Keeps going when an architecture is missing so distclean can finish cleaning up
remove-service:
	@echo "=================="
	@echo "REMOVING SERVICE"
	@echo "=================="
	@for a in $(ARCHS); do \
		echo "--- $$a ---"; \
		hzn exchange service remove -f $(HZN_ORG_ID)/$(SERVICE_NAME)_$(SERVICE_VERSION)_$$a || echo "Not removed for $$a, continuing" >&2; \
	done; \
	echo ""

publish-service-policy:
	@echo "========================="
	@echo "PUBLISHING SERVICE POLICY"
	@echo "========================="
	@rc=0; \
	for a in $(ARCHS); do \
		echo "--- $$a ---"; \
		hzn exchange service addpolicy -f horizon/service.policy.json $(HZN_ORG_ID)/$(SERVICE_NAME)_$(SERVICE_VERSION)_$$a || { echo "FAILED to publish service policy for $$a" >&2; rc=1; }; \
	done; \
	echo ""; \
	exit $$rc

remove-service-policy:
	@echo "======================="
	@echo "REMOVING SERVICE POLICY"
	@echo "======================="
	@for a in $(ARCHS); do \
		echo "--- $$a ---"; \
		hzn exchange service removepolicy -f $(HZN_ORG_ID)/$(SERVICE_NAME)_$(SERVICE_VERSION)_$$a || echo "Not removed for $$a, continuing" >&2; \
	done; \
	echo ""

publish-deployment-policy:
	@echo "============================"
	@echo "PUBLISHING DEPLOYMENT POLICY"
	@echo "============================"
	@hzn exchange deployment addpolicy -f horizon/deployment.policy.json $(HZN_ORG_ID)/policy-$(SERVICE_NAME)_$(SERVICE_VERSION)
	@echo ""

remove-deployment-policy:
	@echo "=========================="
	@echo "REMOVING DEPLOYMENT POLICY"
	@echo "=========================="
	@hzn exchange deployment removepolicy -f $(HZN_ORG_ID)/policy-$(SERVICE_NAME)_$(SERVICE_VERSION)
	@echo ""

agent-run:
	@echo "================"
	@echo "REGISTERING NODE"
	@echo "================"
	@hzn register --policy=horizon/node.policy.json
	@watch hzn agreement list

agent-stop:
	@echo "==================="
	@echo "UN-REGISTERING NODE"
	@echo "==================="
	@hzn unregister -f
	@echo ""

deploy-check:
	@rc=0; \
	for a in $(ARCHS); do \
		echo "--- $$a ---"; \
		ARCH=$$a hzn deploycheck all -t device -B horizon/deployment.policy.json --service=horizon/service.definition.json --service-pol=horizon/service.policy.json --node-pol=horizon/node.policy.json || { echo "FAILED deploy check for $$a" >&2; rc=1; }; \
	done; \
	exit $$rc

log:
	@echo "========="
	@echo "EVENT LOG"
	@echo "========="
	@hzn eventlog list
	@echo ""
	@echo "==========="
	@echo "SERVICE LOG"
	@echo "==========="
	@hzn service log -f $(SERVICE_NAME)

.PHONY: default stop init run dev test clean build push attach browse publish publish-service publish-service-policy publish-deployment-policy agent-run distclean deploy-check check log remove-deployment-policy remove-service-policy remove-service require-container-cli
