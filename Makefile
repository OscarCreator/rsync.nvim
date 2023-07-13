export RSYNC_ROOT=$(PWD)

TEST_DIR := $(RSYNC_ROOT)/tests/rsync/
MINIMAL_PATH := $(RSYNC_ROOT)/scripts/minimal.vim
MINIMAL_INIT_PATH := $(RSYNC_ROOT)/tests/minimal_init.lua

UNAME_S := $(shell uname -s)

.PHONY: build
build:
	cargo build --release
	@rm -rf $(PWD)/lua/librsync_nvim.so $(PWD)/lua/deps/
    ifeq ($(UNAME_S),Linux)
		cp $(PWD)/target/release/librsync_nvim.so $(PWD)/lua/rsync_nvim.so
    endif
    ifeq ($(UNAME_S),Darwin)
		cp $(PWD)/target/release/librsync_nvim.dylib $(PWD)/lua/rsync_nvim.so
    endif
	@mkdir -p $(PWD)/lua/deps/
	cp $(PWD)/target/release/deps/*.rlib $(PWD)/lua/deps/

.PHONY: lint
lint: stylua luacheck cargocheck

.PHONY: luacheck
luacheck:
	luacheck lua/rsync

.PHONY: stylua
stylua:
	stylua --color always --check lua/ tests/

.PHONY: cargocheck
cargocheck:
	cargo fmt --check
	cargo clippy

.PHONY: test
test:
	nvim --headless --noplugin -u $(MINIMAL_PATH) -c "PlenaryBustedDirectory $(TEST_DIR) {minimal_init = '$(MINIMAL_INIT_PATH)'}"

.PHONY: testcov
testcov:
	TEST_COV=1 $(MAKE) --no-print-directory test
	@luacov-console lua/rsync/
	@luacov-console -s
	@luacov -r lcov || luacov

ifeq ($(NOCLEAN), )
	@$(MAKE) --no-print-directory test-clean
endif

.PHONY: testcov-html
testcov-html: 
	NOCLEAN=1 $(MAKE) --no-print-directory testcov
	luacov -r html
	xdg-open luacov-html/index.html

.PHONY: test-clean
test-clean:
	@rm -rf luacov*

.PHONY: clean
clean: test-clean
	@rm -rf lua/deps
	@rm lua/rsync_nvim.so
