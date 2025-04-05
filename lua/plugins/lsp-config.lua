return {
    {
        "williamboman/mason.nvim",
        config = function()
            require("mason").setup()
        end,
    },
    {
        "williamboman/mason-lspconfig.nvim",
        config = function()
            require("mason-lspconfig").setup({
                ensure_installed = { "lua_ls", "pyright", "ruff" },
            })
        end,
    },
    {
        "neovim/nvim-lspconfig",
        dependencies = { 'saghen/blink.cmp' },
        config = function()
            local original_capabilities = vim.lsp.protocol.make_client_capabilities()
            local capabilities = require('blink.cmp').get_lsp_capabilities(original_capabilities)
            local lspconfig = require('lspconfig')

            lspconfig.lua_ls.setup({
                on_attach = function(client, bufnr)
                    vim.api.nvim_buf_set_option(bufnr, "omnifunc", "v:lua.vim.lsp.omnifunc")
                end,
                capabilities = capabilities,
            })

            lspconfig.pyright.setup({
                on_attach = function(client, bufnr)
                    vim.lsp.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(
                        vim.lsp.diagnostic.on_publish_diagnostics, {
                            virtual_text = true,
                            signs = true,
                            update_in_insert = true,
                        }
                    )
                end,
                on_init = function(client)
                    local root_dir = client.config.root_dir
                    if root_dir then
                        local venv_path = root_dir .. "/.venv"
                        if vim.fn.isdirectory(venv_path) == 1 then
                            client.config.settings.python.pythonPath = venv_path .. "/bin/python"
                        end
                    end
                end,
                capabilities = capabilities,
                filetype = { "python" },
                settings = {
                    pyright = {
                        disableOrganizeImports = true,
                    },
                    python = {
                        analysis = {
                            ignore = { "*" },
                        },
                    },
                },
            })

            lspconfig.ruff.setup({
                on_attach = function(client, bufnr)
                    vim.keymap.set("n", "<leader>rf", function()
                        vim.lsp.buf.format({ async = true })
                    end, { buffer = bufnr, desc = "Format with Ruff" })
                end,
                capabilities = capabilities,
                init_options = {
                    settings = {
                        organizeImports = false,
                        showSyntaxErrors = true,
                        lint = {
                            preview = true,
                            extendSelect = { "F", "E", "I", "C", "SIM", "B", "W" },
                        }
                    }
                }
            })

            vim.api.nvim_create_autocmd("LspAttach", {
                group = vim.api.nvim_create_augroup("lsp_attach_disable_ruff_hover", { clear = true }),
                callback = function(args)
                    local client = vim.lsp.get_client_by_id(args.data.client_id)
                    if client == nil then
                        return
                    end
                    if client.name == "ruff" then
                        client.server_capabilities.hoverProvider = false
                    end
                end,
                desc = "LSP: Disable hover capability from Ruff",
            })

            vim.api.nvim_create_autocmd("BufWritePre", {
                pattern = "*.py",
                callback = function()
                    local clients = vim.lsp.get_active_clients({ bufnr = vim.api.nvim_get_current_buf() })
                    local ruff_client = nil
                    for _, client in pairs(clients) do
                        if client.name == "ruff" then
                            ruff_client = client
                            break
                        end
                    end

                    if ruff_client then
                        vim.lsp.buf.code_action({
                            context = { only = { "source.fixAll" } },
                            apply = true,
                            action_handler = function(action)
                                if action.command then
                                    action.command.arguments = { "--extend-select", "I" }
                                end
                                vim.lsp.buf.execute_command(action.command)
                            end,
                        })
                    else
                        vim.notify("Ruff LSP not available ...", vim.log.levels.WARN)
                    end
                end,
                desc = "Run Ruff autofix and format on save for Python files",
            })

            vim.api.nvim_create_autocmd("BufWritePre", {
                callback = function()
                    vim.lsp.buf.format({
                        async = false,
                        filter = function(client)
                            return client.supports_method("textDocument/formatting")
                        end,
                    })
                end,
                desc = "Auto-format on save with specific LSP clients",
            })
        end
    },
    {
        "mfussenegger/nvim-lint",
        dependencies = { "nvim-lua/plenary.nvim" },
        config = function()
            local lint = require("lint")
            lint.linters_by_ft = {
                python = { "mypy" },
            }
            lint.config_by_ft = {
                python = {
                    mypy = {
                        "--strict",
                        "--show-error-codes",
                    },
                },
            }

            vim.api.nvim_create_autocmd("BufWritePost", {
                group = vim.api.nvim_create_augroup("lint_on_save", { clear = true }),
                pattern = { "*.py" },
                callback = function()
                    lint.try_lint()
                end,
            })
        end,
    },
}
