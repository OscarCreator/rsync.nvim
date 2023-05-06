local helpers = require("tests.rsync_helper")
local rsync = require("rsync")

--- create temp folder and files which are good to have

describe("rsync", function()
    describe("files copied", function()
        before_each(function()
            helpers.create_workspace()
        end)

        after_each(function()
            helpers.cleanup_workspace()
        end)

        it("on save", function()
            helpers.mkdir(".nvim")
            helpers.write_file(".nvim/rsync.toml", "remote_path = \"" .. helpers.dest .. "\"")
            helpers.write_file("test.c", "eueueu")

            assert.matches("scratch/source/test.c", vim.api.nvim_command_output("f"))
            -- this triggers autocommand
            vim.cmd.w()

            local config = rsync.config()
            vim.fn.jobwait({config["sync_status"]["job_id"]})
            helpers.assert_file("test.c")
        end)
    end)
end)
