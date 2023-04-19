lint: stylua luacheck

luacheck:
	luacheck lua/rsync

stylua:
	stylua --color always --check lua/
