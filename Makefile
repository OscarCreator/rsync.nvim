export RSYNC_ROOT=$(PWD)
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
	nvim --headless -v --noplugin -u scripts/minimal.vim -c "PlenaryBustedDirectory tests/rsync/ {minimal_init = 'tests/minimal_init.lua'}"
