.SHELL: bash
.ONESHELL:

.PHONY: run
run:
	@rm -rf ./zig-cache
	@zig build
	./zig-out/bin/zedit
