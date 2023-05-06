--- file with helper functions for testing
local H = {}

H.scratch = os.getenv("RSYNC_ROOT").."/scratch/"
H.source = H.scratch .. "source"
H.dest = H.scratch .. "dest"

function H.write_file(name, content)
    local path = H.source.."/"..name
    vim.fn.writefile({content}, path)
    vim.cmd.e(path)
end

function H.mkdir(name)
    vim.fn.mkdir(H.source.."/"..name)
end

function H.assert_file(name)
    vim.fn.system("diff " .. H.source.."/".. name .. " " .. H.dest.."/".. name)
    -- check that files do not differ
    assert.equals(vim.v.shell_error, 0)
end

function H.create_workspace()
    vim.fn.mkdir(H.scratch)
    vim.fn.mkdir(H.source)
    vim.cmd.cd(H.source)
end

function H.cleanup_workspace()
    vim.fn.system("rm -rf " .. H.scratch)
end

return H
