.SHELL: bash
.ONESHELL:

.PHONY: help
help: ## List all available targets with help
	@grep -E '^[0-9a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

.PHONY: build
build: ## Build binary file
	@rm -rf ./zig-cache
	@zig build

.PHONY: run
run: build ## Run without file
	./zig-out/bin/zedit

.PHONY: run_with_file
run_with_file: build ## Run big file
	./zig-out/bin/zedit ./src/terminal.zig

.PHONY: run_with_file
run_with_empty_file: build ## Run empty file
	./zig-out/bin/zedit ./test.txt
