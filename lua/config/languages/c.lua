return function()
    -- Preserve automatic formatting for C files only.
    vim.api.nvim_create_autocmd('BufWritePre', {
        pattern = { '*.c', '*.h' },
        callback = function()
            vim.lsp.buf.format({ async = false })
        end,
    })

    -- Automatically generate boilerplate for new C files
    vim.api.nvim_create_autocmd("BufNewFile", {
        pattern = "*.c",
        callback = function(args)
            vim.api.nvim_buf_set_lines(args.buf, 0, -1, false, {
                "#include <stdio.h>",
                "#include <stdlib.h>",
                "",
                "int main(int argc, char *argv[]) {",
                "    ",
                "    return 0;",
                "}",
            })

            -- Position cursor inside main()
            vim.api.nvim_win_set_cursor(0, { 5, 4 })
        end,
    })

    -- Wrap brace-less if/else/for/while/do bodies in { }. They go in on the
    -- same line; clangd's formatting then lays them out in the file's style.
    local function add_braces(buf)
        local ok, parser = pcall(vim.treesitter.get_parser, buf)
        if not ok or not parser then
            vim.notify('Skipping braces: C parser unavailable', vim.log.levels.WARN)
            return
        end
        local root = parser:parse()[1]:root()
        if root:has_error() then
            vim.notify('Skipping braces: file has syntax errors', vim.log.levels.WARN)
            return
        end

        local edits = {}
        local function wrap(body)
            if not body or body:type() == 'compound_statement' then
                return
            end
            local sr, sc, er, ec = body:range()
            edits[#edits + 1] = { sr, sc, { '{ ' } }
            -- A // comment after the body stays inside: close on the next line
            local line = vim.api.nvim_buf_get_lines(buf, er, er + 1, true)[1]
            if line:sub(ec + 1):match('^%s*//') then
                edits[#edits + 1] = { er, #line, { '', '}' } }
            else
                edits[#edits + 1] = { er, ec, { ' }' } }
            end
        end

        local function visit(node)
            local kind = node:type()
            if kind == 'if_statement' then
                wrap(node:field('consequence')[1])
                local alternative = node:field('alternative')[1] -- else_clause
                local body = alternative and alternative:named_child(0)
                if body and body:type() ~= 'if_statement' then -- keep else-if chains
                    wrap(body)
                end
            elseif kind == 'for_statement' or kind == 'for_range_loop'
                or kind == 'while_statement' or kind == 'do_statement' then
                wrap(node:field('body')[1])
            end
            for child in node:iter_children() do
                visit(child)
            end
        end
        visit(root)

        -- Insert from the end of the file backwards so earlier positions hold
        table.sort(edits, function(a, b)
            if a[1] ~= b[1] then return a[1] > b[1] end
            return a[2] > b[2]
        end)
        for _, edit in ipairs(edits) do
            vim.api.nvim_buf_set_text(buf, edit[1], edit[2], edit[1], edit[2], edit[3])
        end
    end

    -- \f: add braces, then format with clangd. Covers .h files, which nvim
    -- treats as C++, and overrides the general \f from core.lua.
    vim.api.nvim_create_autocmd('FileType', {
        pattern = { 'c', 'cpp' },
        callback = function(args)
            vim.keymap.set('n', '<leader>f', function()
                local clients = vim.lsp.get_clients({
                    bufnr = args.buf,
                    name = 'clangd',
                    method = 'textDocument/formatting',
                })
                if #clients == 0 then
                    vim.notify('clangd is not ready yet', vim.log.levels.WARN)
                    return
                end
                add_braces(args.buf)
                vim.lsp.buf.format({ bufnr = args.buf, name = 'clangd' })
            end, { buffer = args.buf, desc = 'Add braces and format with clangd' })
        end,
    })
end
