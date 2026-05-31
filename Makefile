CLI           := devcontainer
WORKSPACE     ?= $(or $(PWD),$(CURDIR))
DOTFILES_REPO := https://github.com/xortim/dotfiles
CONFIG_FLAG   := --config $(CURDIR)/.devcontainer/devcontainer.local.json

# External invocation — run from any directory to use that dir as the workspace:
#   cd ~/workspace/myproject && make -C ~/workspace/devcontainer shell
#   make -C ~/workspace/devcontainer shell WORKSPACE=~/workspace/myproject
#
# WORKSPACE defaults to $PWD (the caller's directory). Targets that need to
# locate an existing container (down, down-local, migrate-claude) require the
# same WORKSPACE value that was passed to the original shell / build invocation.

UP_FLAGS := \
	--workspace-folder $(WORKSPACE) \
	--dotfiles-repository $(DOTFILES_REPO)

LOCAL_FLAGS := $(UP_FLAGS) $(CONFIG_FLAG)

.PHONY: build build-no-cache build-local build-local-no-cache \
        up up-local shell shell-local down down-local migrate-claude

########
##@ Usage

build: ## Rebuild devcontainer (removes existing container)
	$(CLI) up $(UP_FLAGS) --remove-existing-container

build-no-cache: ## Rebuild devcontainer without Docker layer cache
	$(CLI) up $(UP_FLAGS) --remove-existing-container --build-no-cache

build-local: ## Rebuild devcontainer with host ~/.claude bind-mounted
	@test -d $(HOME)/.claude || { \
	  echo "ERROR: $(HOME)/.claude does not exist."; \
	  echo "Run 'mkdir -p $(HOME)/.claude' to start fresh, or 'make migrate-claude' first."; \
	  exit 1; \
	}
	$(CLI) up $(LOCAL_FLAGS) --remove-existing-container

build-local-no-cache: ## Rebuild devcontainer with host ~/.claude, no Docker layer cache
	@test -d $(HOME)/.claude || { \
	  echo "ERROR: $(HOME)/.claude does not exist."; \
	  echo "Run 'mkdir -p $(HOME)/.claude' to start fresh, or 'make migrate-claude' first."; \
	  exit 1; \
	}
	$(CLI) up $(LOCAL_FLAGS) --remove-existing-container --build-no-cache

up: ## Start devcontainer
	$(CLI) up $(UP_FLAGS)

up-local: ## Start devcontainer with host ~/.claude bind-mounted
	@test -d $(HOME)/.claude || { \
	  echo "ERROR: $(HOME)/.claude does not exist."; \
	  echo "Run 'mkdir -p $(HOME)/.claude' to start fresh, or 'make migrate-claude' first."; \
	  exit 1; \
	}
	$(CLI) up $(LOCAL_FLAGS)

shell: up ## Open a zsh shell in the devcontainer
	$(CLI) exec --workspace-folder $(WORKSPACE) -- /bin/zsh

shell-local: up-local ## Open a zsh shell with host ~/.claude bind-mounted
	$(CLI) exec --workspace-folder $(WORKSPACE) -- /bin/zsh

down: ## Stop the devcontainer
	$(CLI) down --workspace-folder $(WORKSPACE)

down-local: ## Stop the host-~/.claude devcontainer
	$(CLI) down --workspace-folder $(WORKSPACE) $(CONFIG_FLAG)

migrate-claude: ## Copy ~/.claude from the devcontainer Docker volume to host ~/.claude
	@REAL_WORKSPACE=$$(cd -- "$(WORKSPACE)" 2>/dev/null && pwd -P || echo "$(WORKSPACE)"); \
	CONTAINER=""; VOLUME=""; \
	for C in $$(docker ps -a \
	  --filter "label=devcontainer.local_folder=$$REAL_WORKSPACE" \
	  --format "{{.ID}}"); do \
	  V=$$(docker inspect "$$C" \
	    --format '{{range .Mounts}}{{if and (eq .Destination "/home/vscode/.claude") (eq .Type "volume")}}{{.Name}}{{end}}{{end}}'); \
	  if [ -n "$$V" ]; then \
	    CONTAINER="$$C"; VOLUME="$$V"; break; \
	  fi; \
	done; \
	if [ -z "$$CONTAINER" ]; then \
	  echo "ERROR: No volume-backed devcontainer found for $$REAL_WORKSPACE. Start it once with the default targets first."; \
	  exit 1; \
	fi; \
	HOST_UID=$$(id -u); HOST_GID=$$(id -g); \
	echo "Copying from Docker volume $$VOLUME to $(HOME)/.claude ..."; \
	mkdir -p $(HOME)/.claude; \
	docker run --rm \
	  -v "$$VOLUME:/src" \
	  -v "$(HOME)/.claude:/dst" \
	  alpine sh -c "cp -a /src/. /dst/ && chown -R $$HOST_UID:$$HOST_GID /dst/"; \
	echo "Done. You can now use 'make shell-local'."


###########################################################################
## Self-Documenting Makefile Help and logging                            ##
## https://github.com/terraform-docs/terraform-docs/blob/master/Makefile ##
## https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html    ##
###########################################################################

########
##@ Help

.PHONY: help
help:   ## Display this help
	@awk \
		-v "col=\033[36m" -v "nocol=\033[0m" \
		' \
			BEGIN { \
				FS = ":.*##" ; \
				printf "Usage:\n  make %s<target>%s\n", col, nocol \
			} \
			/^[a-zA-Z_-]+:.*?##/ { \
				printf "  %s%-25s%s %s\n", col, $$1, nocol, $$2 \
			} \
			/^##@/ { \
				printf "\n%s%s%s\n", nocol, substr($$0, 5), nocol \
			} \
		' $(MAKEFILE_LIST)

log-%:
	@grep -h -E '^$*:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk \
			'BEGIN { \
				FS = ":.*?## " \
			}; \
			{ \
				printf "\033[36m==> %s\033[0m\n", $$2 \
			}'
