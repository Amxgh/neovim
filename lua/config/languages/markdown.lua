-- Mixes two 0xRRGGBB colours, taking `amount` of the first
local function mix(color, base, amount)
    local result = 0
    for _, place in ipairs({ 0x10000, 0x100, 1 }) do
        local a = math.floor(color / place) % 256
        local b = math.floor(base / place) % 256
        result = result + math.floor(a * amount + b * (1 - amount) + 0.5) * place
    end
    return result
end

-- Gives each heading a full-width bar tinted with its colour, and bold text.
-- Markview tints by blending towards the background, which comes out black
-- on this theme, so the bars are mixed here instead.
local function heading_bars()
    local bg = vim.api.nvim_get_hl(0, { name = 'Normal' }).bg or 0
    for level = 1, 6 do
        local fg = vim.api.nvim_get_hl(0, { name = 'MarkviewPalette' .. level }).fg
        if fg then
            vim.api.nvim_set_hl(0, 'MarkviewHeading' .. level, {
                fg = fg, bg = mix(fg, bg, 0.25), bold = true,
            })
        end
    end
end

return function()
    require('markview').setup({
        preview = {
            -- Stay rendered while typing; only the line being edited shows
            -- its raw markdown
            modes = { 'n', 'no', 'c', 'i' },
            hybrid_modes = { 'i' },
            linewise_hybrid_mode = true,
        },
        -- Markview's own indents for wrapped lines land mid-word, so nvim's
        -- breakindent (set below) indents them. That works from the real
        -- indentation, so list items keep it rather than Markview's padding.
        markdown = {
            block_quotes = { wrap = false },
            list_items = {
                wrap = false,
                marker_minus = { add_padding = false },
                marker_plus = { add_padding = false },
                marker_star = { add_padding = false },
                marker_dot = { add_padding = false },
                marker_parenthesis = { add_padding = false },
            },
        },
    })

    -- Markview resets its colours on startup and on every colorscheme
    -- change, so redo the bars just after it
    vim.api.nvim_create_autocmd({ 'VimEnter', 'ColorScheme' }, {
        callback = function()
            vim.schedule(heading_bars)
        end,
    })

    vim.api.nvim_create_autocmd('FileType', {
        pattern = 'markdown',
        callback = function(args)
            -- Wrap long lines between words, not mid-word, and line wrapped
            -- list items up with the text after their bullet
            vim.opt_local.linebreak = true
            vim.opt_local.breakindent = true
            vim.opt_local.breakindentopt = 'list:-1'

            vim.keymap.set('n', '<leader>mp', '<Cmd>Markview toggle<CR>', {
                buffer = args.buf,
                desc = 'Toggle Markdown inline preview',
            })
            vim.keymap.set('n', '<leader>ms', '<Cmd>Markview splitToggle<CR>', {
                buffer = args.buf,
                desc = 'Toggle Markdown split preview',
            })
        end,
    })
end
