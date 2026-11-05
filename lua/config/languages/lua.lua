-- Lua Language Server
return function(capabilities)
    vim.lsp.config("lua_ls", {
        capabilities = capabilities,
        cmd = { "lua-language-server" },
        filetypes = { "lua" },
        root_markers = {
            { ".luarc.json", ".luarc.jsonc" },
            ".git",
        },

        settings = {
            Lua = {
                runtime = {
                    version = "LuaJIT",
                },
                diagnostics = {
                    globals = { "vim" },
                },
                workspace = {
                    checkThirdParty = false,
                    library = {
                        vim.env.VIMRUNTIME,
                    },
                },
            },
        },
    })

    vim.lsp.enable("lua_ls")
end
