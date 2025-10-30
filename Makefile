# Fast shortcuts for gdtoolkit
SRC := topdown

.PHONY: lint format format-check parse cc hooks

lint:
	gdlint $(SRC)

format:
	gdformat $(SRC)

format-check:
	gdformat --check $(SRC)

parse:
	gdparse $(SRC)

cc:
	gdradon cc $(SRC)

hooks:
	pre-commit install
