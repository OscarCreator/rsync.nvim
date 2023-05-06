export RSYNC_ROOT=$(PWD)

TEST_DIR := $(RSYNC_ROOT)/tests/rsync/
MINIMAL_PATH := $(RSYNC_ROOT)/scripts/minimal.vim
MINIMAL_INIT_PATH := $(RSYNC_ROOT)/tests/minimal_init.lua


.PHONY: build
build:
	cargo build --release
	@rm -rf ./lua/librsync_nvim.so ./lua/deps/
	cp ./target/release/librsync_nvim.so ./lua/rsync_nvim.so
	@mkdir -p ./lua/deps/
	cp ./target/release/deps/*.rlib ./lua/deps/

.PHONY: lint
lint: stylua luacheck cargocheck

.PHONY: luacheck
luacheck:
	luacheck lua/rsync

.PHONY: stylua
stylua:
	stylua --color always --check lua/

.PHONY: cargocheck
cargocheck:
	cargo fmt --check
	cargo clippy

.PHONY: test
test:
	nvim --headless --noplugin -u $(MINIMAL_PATH) -c "PlenaryBustedDirectory $(TEST_DIR) {minimal_init = '$(MINIMAL_INIT_PATH)'}"
