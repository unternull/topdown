# Fast shortcuts for gdtoolkit
SRC := topdown
SRC_DIRS := $(SRC)/scripts $(SRC)/scenes $(SRC)/test
GODOT ?= godot

.PHONY: lint format format-check parse cc hooks import test

lint:
	gdlint $(SRC_DIRS)

format:
	gdformat $(SRC_DIRS)

format-check:
	gdformat --check $(SRC_DIRS)

parse:
	gdparse $(SRC_DIRS)

cc:
	gdradon cc $(SRC_DIRS)

hooks:
	pre-commit install

import:
	$(GODOT) --headless --path $(SRC) --import

test: import
	$(GODOT) --headless --path $(SRC) --script res://addons/gut/gut_cmdln.gd -gdir=res://test -gexit
