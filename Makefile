# Makefile
SHELL := /bin/bash
.DEFAULT_GOAL := help

RUN_SCRIPT := $(CURDIR)/.runtime/run.sh

DOCKER_VARS_FILE ?= $(CURDIR)/docker.vars
include $(DOCKER_VARS_FILE)
export $(shell cat "$(DOCKER_VARS_FILE)" | cut -d= -f1)
RUNTIME_FUNCTIONS := . $(CURDIR)/.runtime/functions.sh &&

TAG ?= latest
UID ?= $(shell id -u)
GID ?= $(shell id -g)
NO_CACHE ?=
DOCKER_BUILD_FLAGS := $(if $(NO_CACHE),--no-cache,)
IMAGE_NAME ?= $(if $(DOCKER_IMAGE),$(DOCKER_IMAGE),wine-base)
CONTAINER_NAME ?= $(if $(DOCKER_CONTAINER),$(DOCKER_CONTAINER),wine-base-container)
USER_NAME ?= $(if $(DOCKER_USER),$(DOCKER_USER),wine)

# App Windows
APP ?=
EXE ?=
APP_EXE ?=
# INSTALL_ARGS empty → auto: .exe=/S, .msi=/quiet (see bin/resolve-install-args)
INSTALL_ARGS ?=
INSTALL_TIMEOUT ?= 1800
INSTALL_BIN ?= $(HOME)/.local/bin
# app-from-prefix: 1 = rsync .wine-local/wine-prefix → apps/<APP>/wine-prefix/ before build
SYNC_PREFIX ?= 1
export PATH := $(INSTALL_BIN):$(PATH)

# Require APP= and an existing apps/<APP>/app.vars
define REQUIRE_APP
@test -n "$(APP)" || { echo -e "\033[31mERROR:\033[0m define APP="; exit 1; }
@case "$(APP)" in */*|*..*) \
	echo -e "\033[31mERROR:\033[0m invalid APP name: $(APP)"; exit 1;; esac
@test -f "apps/$(APP)/app.vars" || { \
	echo -e "\033[31mERROR:\033[0m app '$(APP)' not found at apps/$(APP)/"; \
	echo "  make app-init APP=$(APP)   or   make show-apps"; \
	exit 1; \
}
endef

# Require APP= only (app-init / app may create the app directory)
define REQUIRE_APP_NAME
@test -n "$(APP)" || { echo -e "\033[31mERROR:\033[0m define APP="; exit 1; }
@case "$(APP)" in */*|*..*) \
	echo -e "\033[31mERROR:\033[0m invalid APP name: $(APP)"; exit 1;; esac
endef

all: image

.PHONY: app-init
app-init: ## Create apps/$(APP)/ from template
	$(REQUIRE_APP_NAME)
	@./bin/scaffold-app "$(APP)" "$(APP_EXE)"

.PHONY: app
app: image ## Build app: make app APP=example [EXE=./setup.exe] [INSTALL_ARGS=] [INSTALL_TIMEOUT=1800]
	$(REQUIRE_APP_NAME)
	@./bin/scaffold-app "$(APP)" "$(APP_EXE)" 2>/dev/null || true
	@if [ -n "$(EXE)" ]; then \
		test -f "$(EXE)" || { echo -e "\033[31mERROR:\033[0m installer not found: $(EXE)"; exit 1; }; \
		mkdir -p "apps/$(APP)/installers"; \
		cp -f "$(EXE)" "apps/$(APP)/installers/$$(basename "$(EXE)")"; \
		echo "Installer: apps/$(APP)/installers/$$(basename "$(EXE)")"; \
	fi
	@if [ -n "$(APP_EXE)" ]; then \
		grep -q '^APP_EXE=' "apps/$(APP)/app.vars" \
			&& sed -i "s|^APP_EXE=.*|APP_EXE='$(APP_EXE)'|" "apps/$(APP)/app.vars" \
			|| echo "APP_EXE='$(APP_EXE)'" >> "apps/$(APP)/app.vars"; \
	fi
	@grep -q '^USER_NAME=' "apps/$(APP)/app.vars" \
		|| echo "USER_NAME=$(USER_NAME)" >> "apps/$(APP)/app.vars"; \
	sed -i "s/^USER_NAME=.*/USER_NAME=$(USER_NAME)/" "apps/$(APP)/app.vars"
	@INSTALLER=""; \
	INSTALLER_LIST="$$(find "apps/$(APP)/installers" -maxdepth 1 -type f ! -name '.gitkeep' | sort)"; \
	if [ -z "$$INSTALLER_LIST" ]; then \
		echo -e "\033[31mERROR:\033[0m no installer. Use EXE=./file or put files in apps/$(APP)/installers/"; \
		exit 1; \
	fi; \
	echo "Installers:"; \
	echo "$$INSTALLER_LIST" | while IFS= read -r _f; do \
		echo "  apps/$(APP)/installers/$$(basename "$$_f")"; \
	done; \
	if [ -n "$(INSTALL_ARGS)" ]; then \
		RESOLVED_ARGS="$(INSTALL_ARGS)"; \
		echo "INSTALL_ARGS (manual): $$RESOLVED_ARGS"; \
	else \
		RESOLVED_ARGS=""; \
		_first=1; \
		while IFS= read -r _f; do \
			_base="$$(basename "$$_f")"; \
			_arg="$$(./bin/resolve-install-args "$$_base")"; \
			[ $$_first -eq 1 ] || RESOLVED_ARGS="$$RESOLVED_ARGS|"; \
			RESOLVED_ARGS="$$RESOLVED_ARGS$$_arg"; \
			_first=0; \
			case "$$_base" in \
				*.msi|*.MSI) echo "INSTALL_ARGS (auto .msi $$_base): $$_arg" ;; \
				*.exe|*.EXE) echo "INSTALL_ARGS (auto .exe $$_base): $$_arg" ;; \
				*) echo -e "\033[33mWARNING:\033[0m unknown extension $$_base, no auto args" ;; \
			esac; \
		done <<< "$$INSTALLER_LIST"; \
	fi; \
	INSTALLER="$$(basename "$$(echo "$$INSTALLER_LIST" | head -1)")"; \
	grep -q '^INSTALL_ARGS=' "apps/$(APP)/app.vars" 2>/dev/null \
		&& sed -i "s|^INSTALL_ARGS=.*|INSTALL_ARGS=$$RESOLVED_ARGS|" "apps/$(APP)/app.vars" \
		|| echo "INSTALL_ARGS=$$RESOLVED_ARGS" >> "apps/$(APP)/app.vars"; \
	if [ -f "apps/$(APP)/Dockerfile" ]; then \
		DOCKERFILE="apps/$(APP)/Dockerfile"; \
		echo "Custom Dockerfile: $$DOCKERFILE"; \
		APP_IMAGE=$$(grep '^APP_IMAGE=' "apps/$(APP)/app.vars" | cut -d= -f2); \
		docker build -t "$$APP_IMAGE" \
			--build-arg BASE_IMAGE=$(IMAGE_NAME) \
			--build-arg USER_NAME=$(USER_NAME) \
			--build-arg INSTALLER="$$INSTALLER" \
			--build-arg "INSTALL_ARGS=$$RESOLVED_ARGS" \
			-f "$$DOCKERFILE" "apps/$(APP)"; \
	else \
		echo "Generic Dockerfile (apps/Dockerfile), installers=$$(echo "$$INSTALLER_LIST" | wc -l)"; \
		APP_IMAGE=$$(grep '^APP_IMAGE=' "apps/$(APP)/app.vars" | cut -d= -f2); \
		docker build -t "$$APP_IMAGE" \
			--build-arg BASE_IMAGE=$(IMAGE_NAME) \
			--build-arg APP=$(APP) \
			--build-arg USER_NAME=$(USER_NAME) \
			--build-arg "INSTALL_ARGS=$$RESOLVED_ARGS" \
			--build-arg INSTALL_TIMEOUT=$(INSTALL_TIMEOUT) \
			-f apps/Dockerfile .; \
	fi

.PHONY: app-from-prefix
app-from-prefix: image ## Build app from dev prefix: make app-from-prefix APP=example [SYNC_PREFIX=1]
	$(REQUIRE_APP)
	@_wine_local="$(WINE_LOCAL_DIR)"; \
	[[ "$$_wine_local" != /* ]] && _wine_local="$(CURDIR)/$$_wine_local"; \
	PREFIX_SRC="$${PREFIX_SRC:-$$_wine_local/wine-prefix}"; \
	APP_PREFIX="apps/$(APP)/wine-prefix"; \
	if [ "$(SYNC_PREFIX)" != "0" ]; then \
		test -d "$$PREFIX_SRC/drive_c" || { \
			echo -e "\033[31mERROR:\033[0m dev prefix not found: $$PREFIX_SRC"; \
			echo "  Install in dev container (make container, make attach), then retry."; \
			exit 1; \
		}; \
		mkdir -p "$$APP_PREFIX"; \
		echo "Sync: $$PREFIX_SRC/ → $$APP_PREFIX/"; \
		rsync -a --delete "$$PREFIX_SRC/" "$$APP_PREFIX/"; \
	else \
		echo "SYNC_PREFIX=0 — using existing $$APP_PREFIX/"; \
	fi; \
	test -f "$$APP_PREFIX/drive_c/windows/syswow64/kernel32.dll" || { \
		echo -e "\033[31mERROR:\033[0m invalid prefix at $$APP_PREFIX"; \
		echo "  Expected drive_c/…/kernel32.dll. Use SYNC_PREFIX=1 (default) or fix the copy."; \
		exit 1; \
	}; \
	APP_IMAGE=$$(grep '^APP_IMAGE=' "apps/$(APP)/app.vars" | cut -d= -f2); \
	if [ -f "apps/$(APP)/Dockerfile.prefix" ]; then \
		DOCKERFILE="apps/$(APP)/Dockerfile.prefix"; \
	else \
		DOCKERFILE="apps/Dockerfile.prefix"; \
	fi; \
	echo "Building $$APP_IMAGE ($$DOCKERFILE, context=apps/$(APP))"; \
	docker build $(DOCKER_BUILD_FLAGS) -t "$$APP_IMAGE" \
		--build-arg BASE_IMAGE=$(IMAGE_NAME) \
		--build-arg USER_NAME=$(USER_NAME) \
		-f "$$DOCKERFILE" "apps/$(APP)"

.PHONY: app-from-prefix-setup
app-from-prefix-setup: app-from-prefix install-cmd ## Prefix image + command in PATH
	@echo "Mode B (image): set APP_IMAGE + WINE_DATA_DIR=@image in apps/$(APP)/app.vars"
	@echo "Mode A (local):  APP_IMAGE=wine-base WINE_DATA_DIR=@app"
	@echo "Execute: $(INSTALL_BIN)/$(APP)"

.PHONY: install-cmd
install-cmd: ## Install command in PATH [APP=name] [INSTALL_BIN=~/.local/bin]
	$(REQUIRE_APP)
	@./bin/install-cmd "$(APP)" "$(INSTALL_BIN)"

.PHONY: install-desktop
install-desktop: ## Install menu launcher (.desktop) [APP=name]
	$(REQUIRE_APP)
	@./bin/install-desktop "$(APP)"

.PHONY: install
install: install-cmd install-desktop ## PATH command + menu icon: make install APP=example

.PHONY: demo
demo: image ## Demo without installer: wine-app-example (notepad)
	@docker build -t wine-app-example \
		--build-arg BASE_IMAGE=$(IMAGE_NAME) \
		-f apps/example/Dockerfile apps/example
	@echo "Next: make install-cmd APP=example && example"

.PHONY: app-setup
app-setup: app install-cmd ## Build + command in PATH: make app-setup APP=myapp EXE=./setup.exe
	@echo "Execute: $(INSTALL_BIN)/$(APP)"

.PHONY: show-apps
show-apps: ## List apps defined in apps/
	@find apps -mindepth 1 -maxdepth 1 -type d ! -name '_*' -printf '%f\n' 2>/dev/null | sort

.PHONY: image
image: ## Build base image [$(IMAGE_NAME)] (user=wine; NO_CACHE=1 no cache)
	@docker build $(DOCKER_BUILD_FLAGS) -t $(IMAGE_NAME) \
		--build-arg USERNAME=$(USER_NAME) \
		--build-arg UID=$(UID) \
		--build-arg GID=$(GID) \
		.

.PHONY: image-full
image-full: ## Build full image [$(IMAGE_NAME)] — i386 + winetricks (NO_CACHE=1)
	@docker build $(DOCKER_BUILD_FLAGS) -t $(IMAGE_NAME) \
		--build-arg USERNAME=$(USER_NAME) \
		--build-arg UID=$(UID) \
		--build-arg GID=$(GID) \
		-f Dockerfile.full \
		.

.PHONY: container
container: ## Create and start container [$(CONTAINER_NAME)]
	@$(RUN_SCRIPT)

.PHONY: attach
attach: ## Shell in container: make attach [APP=name] (APP → app container; else dev)
	@_container="$(CONTAINER_NAME)"; \
	_user="$(USER_NAME)"; \
	_workdir="/home/$(USER_NAME)"; \
	if [ -n "$(APP)" ]; then \
		_av="$(CURDIR)/apps/$(APP)/app.vars"; \
		[ -f "$$_av" ] || { echo -e "\033[31mERROR:\033[0m apps/$(APP)/app.vars not found"; exit 1; }; \
		source "$$_av"; \
		_container="$${CONTAINER_NAME:-wine-app-$(APP)-container}"; \
		_user="$${USER_NAME:-wine}"; \
		_workdir="/home/$$_user"; \
	fi; \
	docker ps -q -f "name=^$$_container$$" | grep -q . || { \
		echo -e "\033[31mERROR:\033[0m container '$$_container' is not running."; \
		if [ -n "$(APP)" ]; then echo "  Start the app: ./bin/wine-launch $(APP)"; \
		else echo "  Run: make container"; fi; \
		exit 1; \
	}; \
	docker exec -it --workdir "$$_workdir" --user "$$_user" "$$_container" bash -lc 'exec bash'

.PHONY: winecfg
winecfg: ## Open winecfg in container (requires graphical support X11)
	@$(RUNTIME_FUNCTIONS) container_require_x11 "$(CONTAINER_NAME)"
	@docker exec -it \
		-e DISPLAY=$(DISPLAY) \
		--user $(USER_NAME) \
		$(CONTAINER_NAME) \
		winecfg

.PHONY: winetricks
winetricks: ## Execute winetricks (requires image-full or manual installation)
	@$(RUNTIME_FUNCTIONS) container_require_x11 "$(CONTAINER_NAME)"
	@docker exec -it \
		--user $(USER_NAME) \
		$(CONTAINER_NAME) \
		winetricks $(ARGS)

.PHONY: start
start: ## Start container [$(CONTAINER_NAME)]
	@docker start $(CONTAINER_NAME)

.PHONY: stop
stop: ## Stop container [$(CONTAINER_NAME)]
	@docker stop $(CONTAINER_NAME)

.PHONY: tag
tag: ## Tag image for registry
	docker tag $(IMAGE_NAME) $(REGISTRY)/$(PROJECT)/$(IMAGE_NAME):$(TAG)

.PHONY: push
push: ## Push image to registry
	@IMAGE_ID=$$(docker images -q $(REGISTRY)/$(PROJECT)/$(IMAGE_NAME):$(TAG)); \
	if [ -z "$$IMAGE_ID" ]; then \
		echo "\033[31mERROR:\033[0m Image $(REGISTRY)/$(PROJECT)/$(IMAGE_NAME):$(TAG) does not exist."; \
		exit 1; \
	fi; \
	docker push $(REGISTRY)/$(PROJECT)/$(IMAGE_NAME):$(TAG)

.PHONY: show-logs
show-logs: ## Show container logs
	@docker logs $(CONTAINER_NAME)

.PHONY: clean
clean: ## Remove container and base image
	docker stop $(CONTAINER_NAME) 2>/dev/null || true
	docker rm $(CONTAINER_NAME) 2>/dev/null || true
	docker rmi $(IMAGE_NAME) 2>/dev/null || true

.PHONY: clean-app
clean-app: ## Remove app image [APP=name]
	$(REQUIRE_APP)
	@APP_IMAGE=$$(grep '^APP_IMAGE=' "apps/$(APP)/app.vars" | cut -d= -f2); \
	docker rmi "$$APP_IMAGE" 2>/dev/null || true

.PHONY: clean-wine
clean-wine: ## Remove wine prefix and data for base
	@rm -r .wine-local

.PHONY: help
help: ## Show this menu
	@echo "Guide: README.md in this folder"
	@echo ""
	@echo "Available commands:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z0-9_-]+:.*?## / {gsub("\\\\n",sprintf("\n%22c",""), $$2);printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
