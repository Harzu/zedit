.SHELL: bash
.ONESHELL:

.PHONY: build
build:
	@rm -rf ./zig-cache
	@zig build

.PHONY: run
run: build
	./zig-out/bin/zedit

.PHONY: run_with_file
run_with_file: build
	./zig-out/bin/zedit ./src/terminal.zig

.PHONY: run_with_file
run_with_empty_file: build
	./zig-out/bin/zedit ./test.txt
