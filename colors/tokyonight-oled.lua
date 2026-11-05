-- TokyoNight retuned for OLED screens.
--
-- The editor background is pure black so unused pixels switch off. Popups,
-- floats and the statusline sit one small step above black so they stay
-- distinct, and text keeps TokyoNight's soft lavender instead of stark white:
-- strong contrast (about 13:1) without the glare.

local colors = require('tokyonight.colors')

-- Registering 'oled' as a full TokyoNight style (rather than patching 'night'
-- in on_colors) makes TokyoNight blend everything it derives from the
-- background — selections, diffs, diagnostic tints — against black.
colors.styles.oled = function()
    return vim.tbl_extend('force', colors.styles.night, {
        bg = '#000000',           -- editor: true black, pixels off
        bg_dark = '#101219',      -- popups, floats, statusline: one step up
        bg_dark1 = '#08090d',
        bg_highlight = '#181a25', -- cursor line, open file in the tree
        comment = '#636da6',      -- night's #565f89 is too dim on black
    })
end

require('tokyonight').load({
    style = 'oled',
    styles = {
        sidebars = 'normal', -- file tree shares the black background
    },

    on_colors = function(c)
        c.border = '#a0a0a0'          -- split lines: light gray, dimmer than text
        c.bg_visual = '#1f2d51'       -- slightly stronger selection
        c.diff.change = '#141a27'     -- night's tint vanishes against black
        c.terminal.black = '#15161e'  -- keep :terminal "black" off the bg
    end,

    on_highlights = function(hl, c)
        -- The tree's separator is drawn in the sidebar colour, which is now
        -- black too, so give it the same line as other splits.
        hl.NvimTreeWinSeparator = { fg = c.border, bg = c.bg }
        hl.ColorColumn = { bg = c.bg_dark }
    end,
})
