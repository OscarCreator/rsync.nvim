local project = require("rsync.project")

describe("project", function()
    after_each(function()
        -- Needed to have reliable coverage
        if os.getenv("TEST_COV") then
            require("luacov.runner").save_stats()
        end
    end)
    describe("no rsync.toml", function()
        it("get_config_table", function()
            assert.equals(project.get_config_table(), nil)
        end)

        it("run", function()
            local val = false
            project:run(function()
                val = true
            end)
            assert.equals(false, val, "run function was ran even if rsync.toml wasn't found")
        end)
    end)
end)
