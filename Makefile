CLI            := devcontainer
WORKSPACE      := $(CURDIR)
DOTFILES_REPO  := https://github.com/xortim/dotfiles

NO_CACHE ?= 0
ifeq ($(NO_CACHE),1)
NO_CACHE_FLAG := --build-no-cache
endif

UP_FLAGS := \
	--workspace-folder $(WORKSPACE) \
	--dotfiles-repository $(DOTFILES_REPO)

.PHONY: build up shell down

########
##@ Usage

build: ## Build the devcontainer, set NO_CACHE to 1 to run with --build-no-cache
	$(CLI) up $(UP_FLAGS) --remove-existing-container $(NO_CACHE_FLAG)

up: ## Bring up the devcontinaer
	$(CLI) up $(UP_FLAGS)

shell: up # Launch zsh inside the devcontainer
	$(CLI) exec --workspace-folder $(WORKSPACE) -- /bin/zsh

down: ## Shutdown the devcontainer
	$(CLI) down --workspace-folder $(WORKSPACE)


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
				printf "  %s%-15s%s %s\n", col, $$1, nocol, $$2 \
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

