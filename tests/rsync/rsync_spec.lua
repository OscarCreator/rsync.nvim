local helpers = require("tests.rsync_helper")

describe("rsync", function()
    before_each(function()
        helpers.create_workspace()
        helpers.mkdir(".nvim")
    end)

    after_each(function()
        helpers.cleanup_workspace()
        -- Needed to have reliable coverage
        if os.getenv("TEST_COV") then
            require("luacov.runner").save_stats()
        end
    end)

    describe("au", function()
        it("RsyncLog", function()
            vim.cmd.RsyncLog()
            local file_name = vim.fn.expand("%:t")
            assert.equals(file_name, "rsync.log")
        end)

        it("RsyncConfig", function()
            local status, err = pcall(vim.cmd.RsyncConfig)
            assert.equals(status, true)
            assert.equals(err, "")
        end)

        it("RsyncProjectConfig", function()
            helpers.write_file(".nvim/rsync.toml", { 'remote_path = "' .. helpers.dest .. '/"' })
            helpers.write_file("test.c", { "eueueu" })
            helpers.assert_file_not_copied("test.c")

            local status, err = pcall(vim.cmd.RsyncProjectConfig)
            assert.equals(status, true)
            assert.equals(err, "")
        end)
    end)

    describe("missing rsync.toml", function()
        it("status returns empty string", function()
            helpers.write_file("test.c", { "eueueu" })
            local status, err = pcall(vim.cmd.w)
            assert.equals(status, false)
            assert(string.match(err, "Could not find rsync.toml"), "Did not print out missing rsync.toml")
            assert.equals(require("rsync").status(), "")
        end)
    end)

    describe("setup config", function()
        it("fugitive_sync", function()
            require("rsync").setup({ fugitive_sync = true })
        end)
    end)

    describe("files", function()
        local function setup(code)
            helpers.write_file(".nvim/rsync.toml", { 'remote_path = "' .. helpers.dest .. '/"' })
            helpers.write_file("test.c", { "eueueu" })
            helpers.assert_file_not_copied("test.c")

            code()
        end
        describe("not copied", function()
            require("rsync").setup({ sync_on_save = false })
            it("on save", function()
                setup(function()
                    -- this triggers autocommand
                    vim.cmd.w()
                    assert.equals(require("rsync").status(), "Up to date")
                    helpers.wait_sync()
                    assert.equals(require("rsync").status(), "Up to date")
                    helpers.assert_file_not_copied("test.c")
                end)
            end)

            -- restore default
            require("rsync").setup({ sync_on_save = true })
        end)

        describe("copied", function()
            it("on save", function()
                setup(function()
                    -- this triggers autocommand
                    vim.cmd.w()
                    assert.equals(require("rsync").status(), "Syncing up files")
                    helpers.wait_sync()
                    assert.equals(require("rsync").status(), "Up to date")
                    helpers.assert_file("test.c")
                end)
            end)

            it("reschedule save", function()
                setup(function()
                    -- this triggers autocommand
                    vim.cmd.w()
                    vim.cmd.w()
                    vim.cmd.w()
                    vim.cmd.w()
                    assert.equals(require("rsync").status(), "Syncing up files")
                    helpers.wait_sync()
                    assert.equals(require("rsync").status(), "Up to date")
                    helpers.assert_file("test.c")
                end)
            end)

            it("RsyncDown is aborted", function()
                setup(function()
                    -- this triggers autocommand
                    vim.cmd.w()
                    local status, err = pcall(vim.cmd.RsyncDown)
                    assert.equals(status, false)
                    assert.equals(err, "Vim:Could not sync down, due to sync up still running")
                    assert.equals(require("rsync").status(), "Syncing up files")
                    helpers.wait_sync()
                    assert.equals(require("rsync").status(), "Up to date")
                    helpers.assert_file("test.c")
                end)
            end)

            it("on RsyncUp", function()
                setup(function()
                    vim.cmd.RsyncUp()
                    helpers.wait_sync()
                    helpers.assert_file("test.c")
                end)
            end)

            it("RsyncDownFile is aborted", function()
                setup(function()
                    vim.cmd.RsyncUpFile()
                    local status, err = pcall(vim.cmd.RsyncDownFile)
                    assert.equals(status, false)
                    assert.equals(err, "Vim:File still syncing up")

                    helpers.wait_sync_file()
                    helpers.assert_file("test.c")
                end)
            end)

            it("RsyncUpFile is aborted", function()
                setup(function()
                    vim.cmd.RsyncUpFile()
                    local status, err = pcall(vim.cmd.RsyncUpFile)
                    assert.equals(status, false)
                    assert.equals(err, "Vim:File still syncing up")

                    helpers.wait_sync_file()
                    helpers.assert_file("test.c")
                end)
            end)

            it("on RsyncUpFile inside folder", function()
                setup(function()
                    vim.cmd.w()
                    helpers.wait_sync()
                    helpers.assert_file("test.c")

                    helpers.mkdir("sub")
                    helpers.write_file("sub/second_test.tt", { "labbal" })
                    -- this is needed due to rsync will not create remote directories
                    -- if they do not exist
                    helpers.mkdir_remote("sub")

                    vim.cmd.RsyncUpFile()
                    helpers.wait_sync_file()
                    helpers.assert_file("sub/second_test.tt")
                end)
            end)

            it("on RsyncUpFile inside not exsisting remote folder", function()
                setup(function()
                    helpers.mkdir("sub")
                    helpers.write_file("sub/second_test.tt", { "labbal" })

                    vim.cmd.RsyncUpFile()
                    helpers.wait_sync_file()
                    helpers.assert_file("sub/second_test.tt")
                    helpers.assert_file_not_copied("test.c")
                end)
            end)
        end)
    end)

    describe("files re-ignored", function()
        local filters = {
            {"*.txt", "!should_ignore.txt", "!log.txt"},
            {"*.txt", "!should_ignore.txt", "!build/log.txt"},
            {"!build/log.txt", "*.txt", "!should_ignore.txt"},
            {"!should_ignore.txt", "!build/*", "*.txt"},
            {"should_ignore.txt", "!*.txt"},
            {"!*.txt", "should_ignore.txt"},
            {"!should*", "*.txt", "!build"},
        }

        local function setup(filter, code)
            helpers.write_file(".nvim/rsync.toml", { 'remote_path = "' .. helpers.dest .. '/"' })
            helpers.write_file(".gitignore", filter)
            helpers.write_file("should_ignore.txt", { "this file\nshould not be synced" })
            helpers.write_file("test.c", { "eueueu" })
            helpers.mkdir("build")
            helpers.write_file("build/log.txt", { "logging data" })

            helpers.assert_file_not_copied("test.c")
            helpers.assert_file_not_copied("should_ignore.txt")
            helpers.assert_file_not_copied("build/log.txt")

            code()

            helpers.assert_file("test.c")
            helpers.assert_file("should_ignore.txt")
            helpers.assert_file("build/log.txt")
        end
        for k, filter in pairs(filters) do
            it("on save key:" .. k, function()
                setup(filter, function()
                    -- this triggers autocommand
                    vim.cmd.w()
                    helpers.wait_sync()
                end)
            end)

            it("on RsyncUp key:" .. k, function()
                setup(filter, function()
                    vim.cmd.RsyncUp()
                    helpers.wait_sync()
                end)
            end)
        end
    end)

    describe("files ignored", function()
        local function setup_with_gitignore(code)
            helpers.write_file(".nvim/rsync.toml", { 'remote_path = "' .. helpers.dest .. '/"' })
            helpers.write_file(".gitignore", { "should_ignore.txt" })
            helpers.write_file("should_ignore.txt", { "this file\nshould not be synced" })
            helpers.write_file("test.c", { "eueueu" })

            helpers.assert_file_not_copied("test.c")
            helpers.assert_file_not_copied("should_ignore.txt")

            code()

            helpers.assert_file("test.c")
            helpers.assert_file_not_copied("should_ignore.txt")
        end

        it("on save", function()
            setup_with_gitignore(function()
                -- this triggers autocommand
                vim.cmd.w()
                helpers.wait_sync()
            end)
        end)

        it("on RsyncUp", function()
            setup_with_gitignore(function()
                vim.cmd.RsyncUp()
                helpers.wait_sync()
            end)
        end)

        it("on RsyncUpFile", function()
            setup_with_gitignore(function()
                helpers.write_file("second_test.tt", { "labbal" })
                vim.cmd.e("test.c")
                vim.cmd.RsyncUpFile()
                helpers.wait_sync_file()
                helpers.assert_file_not_copied("second_test.tt")
            end)
        end)
    end)

    local function setup_with_remote_includes(config)
        helpers.write_file(".nvim/rsync.toml", config)

        helpers.write_file(".gitignore", { "remote_file*" })
        helpers.write_file("test.c", { "eueueu" })
        helpers.assert_file_not_copied("test.c")

        vim.cmd.w()
        helpers.wait_sync()

        helpers.assert_file("test.c")
    end

    describe("files deleted", function()
        it("on remote", function()
            setup_with_remote_includes({
                'remote_path = "' .. helpers.dest .. '/"',
                'remote_includes = ["remote_file.h"]',
            })
            -- add files to remote (not part of .gitignore))
            helpers.write_file("to_be_deleted.md", { "does not matter", "really." })
            helpers.write_remote_file("remote_file.h", { "this file should be able to sync down" })
            helpers.assert_on_remote_only("remote_file.h")
            helpers.write_remote_file("remote_file_2.t", { "some nonsense" })
            helpers.assert_on_remote_only("remote_file_2.t")

            vim.cmd.w()
            helpers.wait_sync()

            -- delete the file locally
            helpers.delete_file("to_be_deleted.md")

            -- switch file
            vim.cmd.e("test.c")
            -- sync up
            vim.cmd.w()
            helpers.wait_sync()

            -- sync down does not remove file
            helpers.assert_file_delete("to_be_deleted.md")
            helpers.assert_on_remote_only("remote_file_2.t")
            helpers.assert_on_remote_only("remote_file.h")
            helpers.assert_file("test.c")

            -- down sync still works
            vim.cmd.RsyncDown()
            assert.equals(require("rsync").status(), "Syncing down files")
            helpers.wait_sync()

            --
            helpers.assert_file_delete("to_be_deleted.md")
            helpers.assert_files({ "remote_file.h", "test.c" })
            helpers.assert_on_remote_only("remote_file_2.t")
        end)
    end)

    describe("remote includes", function()
        it("synced with RsyncDownFile", function()
            setup_with_remote_includes({
                'remote_path = "' .. helpers.dest .. '/"',
                'remote_includes = ["remote_file.h"]',
            })
            helpers.write_remote_file("remote_file.h", { "this file should be able to sync down" })
            helpers.assert_on_remote_only("remote_file.h")

            -- sync down file
            vim.cmd.RsyncDown()
            helpers.wait_sync()

            -- edit remote file
            local remote_text = { "some other content", "which is replaced" }
            helpers.write_remote_file("remote_file.h", remote_text)

            vim.cmd.e("remote_file.h")
            local buf = vim.api.nvim_get_current_buf()
            vim.cmd.RsyncDownFile()
            -- Rsync Up/Down File is aborted
            local status, err = pcall(vim.cmd.RsyncUpFile)
            assert.equals(status, false)
            assert.equals(err, "Vim:File still syncing down")
            local status, err = pcall(vim.cmd.RsyncDownFile)
            assert.equals(status, false)
            assert.equals(err, "Vim:File still syncing down")

            -- open another file just to check that buffer
            -- is update even if it not is the current.
            vim.cmd.e("test.c")
            -- this should update buffer after sync is done
            helpers.wait_sync_file()

            local lines = vim.api.nvim_buf_get_lines(buf, 0, 2, false)
            assert(vim.deep_equal(lines, remote_text), "found:" .. vim.inspect(lines))
        end)

        it("synced with RsyncDown", function()
            setup_with_remote_includes({
                'remote_path = "' .. helpers.dest .. '/"',
                'remote_includes = ["remote_file.h"]',
            })
            helpers.write_remote_file("remote_file.h", { "this file should be able to sync down" })
            helpers.assert_on_remote_only("remote_file.h")

            vim.cmd.RsyncDown()
            helpers.wait_sync()

            helpers.assert_files({ "test.c", "remote_file.h" })
        end)

        it("RsyncUp is aborted", function()
            setup_with_remote_includes({
                'remote_path = "' .. helpers.dest .. '/"',
                'remote_includes = ["remote_file.h"]',
            })
            helpers.write_remote_file("remote_file.h", { "this file should be able to sync down" })
            helpers.assert_on_remote_only("remote_file.h")

            vim.cmd.RsyncDown()
            local status, err = pcall(vim.cmd.RsyncUp)
            assert.equals(status, false)
            assert.equals(err, "Vim:Could not sync up, due to sync down still running")

            helpers.wait_sync()

            helpers.assert_files({ "test.c", "remote_file.h" })
        end)

        it("synced with RsyncDown multiple files", function()
            setup_with_remote_includes({
                'remote_path = "' .. helpers.dest .. '/"',
                'remote_includes = ["remote_file.h", "remote_file_2"]',
            })
            helpers.write_remote_file("remote_file.h", { "this file should be able to sync down" })
            helpers.assert_on_remote_only("remote_file.h")
            helpers.write_remote_file("remote_file_2", { "second file", "with a bunch of text" })
            helpers.assert_on_remote_only("remote_file_2")

            vim.cmd.RsyncDown()
            helpers.wait_sync()

            helpers.assert_files({ "test.c", "remote_file.h", "remote_file_2" })
        end)
    end)
end)
