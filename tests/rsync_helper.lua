--- file with helper functions for testing
local H = {}

local rsync = require("rsync")

H.scratch = os.getenv("RSYNC_ROOT") .. "/scratch"
H.source = H.scratch .. "/source"
H.dest = H.scratch .. "/dest"

function H.write_file(name, content)
    local path = H.source .. "/" .. name
    local ok, _ = pcall(vim.fn.writefile, content, path)
    assert.equals(true, ok)
    vim.cmd.e(path)
end

function H.write_remote_file(name, content)
    local path = H.dest .. "/" .. name
    local ok, _ = pcall(vim.fn.writefile, content, path)
    assert.equals(true, ok)
end

function H.delete_file(name)
    vim.fn.delete(name)
end

function H.mkdir(name)
    vim.fn.mkdir(H.source .. "/" .. name)
end

function H.mkdir_remote(name)
    vim.fn.mkdir(H.dest .. "/" .. name)
end

function H.assert_file(name)
    vim.fn.system("diff " .. H.source .. "/" .. name .. " " .. H.dest .. "/" .. name)
    -- check that files do not differ
    assert.equals(0, vim.v.shell_error)
end

function H.assert_files(files)
    for _, value in pairs(files) do
        H.assert_file(value)
    end
end

function H.assert_file_not_copied(name)
    vim.fn.system("! test -f " .. H.dest .. "/" .. name)
    assert.equals(0, vim.v.shell_error)
end

function H.assert_on_remote_only(name)
    vim.fn.system("test -f " .. H.dest .. "/" .. name)
    assert.equals(0, vim.v.shell_error)
    vim.fn.system("! test -f " .. H.source .. "/" .. name)
    assert.equals(0, vim.v.shell_error)
end

function H.assert_file_delete(name)
    vim.fn.system("! test -f " .. H.dest .. "/" .. name)
    assert.equals(0, vim.v.shell_error)
    vim.fn.system("! test -f " .. H.source .. "/" .. name)
    assert.equals(0, vim.v.shell_error)
end

function H.create_workspace()
    assert.equals(vim.fn.mkdir(H.scratch), 1)
    assert.equals(vim.fn.mkdir(H.source), 1)
    vim.cmd.cd(H.source)
end

function H.cleanup_workspace()
    vim.fn.system("rm -rf " .. H.scratch)
    _RsyncProjectConfigs = {}
end

-- TODO add different for file/project wait
function H.wait_sync()
    local config = rsync.config()
    vim.fn.jobwait({ config.status.project.job_id})
end

function H.wait_sync_file()
    local config = rsync.config()
    vim.fn.jobwait({ config.status.file.job_id})
end

return H
