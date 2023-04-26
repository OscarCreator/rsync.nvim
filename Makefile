lint: stylua luacheck cargocheck

luacheck:
	luacheck lua/rsync

stylua:
	stylua --color always --check lua/

cargocheck:
	cargo fmt --check
	cargo clippy

build:
	cargo build --release
	@rm -rf ./lua/librsync_nvim.so ./lua/deps/
	cp ./target/release/librsync_nvim.so ./lua/rsync_nvim.so
	@mkdir -p ./lua/deps/
	cp ./target/release/deps/*.rlib ./lua/deps/
