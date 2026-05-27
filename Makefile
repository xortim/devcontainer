CLI            := devcontainer
WORKSPACE      := $(CURDIR)
DOTFILES_REPO  := $(HOME)/dotfiles
DOTFILES_CMD   := bash install.sh

NO_CACHE ?= 0
ifeq ($(NO_CACHE),1)
NO_CACHE_FLAG := --build-no-cache
endif

UP_FLAGS := \
	--workspace-folder $(WORKSPACE) \
	--dotfiles-repository $(DOTFILES_REPO) \
	--dotfiles-install-command "$(DOTFILES_CMD)"

.PHONY: build up shell down

build:
	$(CLI) up $(UP_FLAGS) --remove-existing-container $(NO_CACHE_FLAG)

up:
	$(CLI) up $(UP_FLAGS)

shell: up
	$(CLI) exec --workspace-folder $(WORKSPACE) -- /bin/zsh

down:
	$(CLI) down --workspace-folder $(WORKSPACE)
