return function(capabilities)
    -- clangd serves both C and C++ files.
    vim.lsp.config('clangd', {
        capabilities = capabilities,
    })
    vim.lsp.enable('clangd')
end
