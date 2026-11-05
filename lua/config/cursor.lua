
-- Left/right (h/l) cursor customizations. Up/down (j/k) are left alone.
return function()

    -- ========================================================
    -- HELD H/L SPEED
    -- ========================================================

    -- A held h/l moves at the OS key-repeat rate, which is already at the
    -- Windows maximum (~30 chars/s). SPEED scales it: each repeat moves SPEED
    -- characters on average (1.15 = 15% faster, 0.9 = 10% slower). Fractions
    -- carry over, so 1.15 moves one character per repeat with an occasional
    -- two. Taps, counts (5l) and line wraps are unaffected.
    -- A gap shorter than REPEAT_MS between presses counts as key repeat; it
    -- must exceed the OS repeat interval (~33ms) but beat your fastest tapping.
    -- :CursorSpeed [n] shows or sets SPEED for the session while tuning.
    local SPEED, REPEAT_MS = 1.15, 100
    local pace = {}

    local function paced(key, mapping)
        return function()
            local now = vim.uv.hrtime() / 1e6
            local repeating = pace.key == key and now - pace.last < REPEAT_MS
            pace.key, pace.last = key, now
            local keys = mapping(repeating)

            if vim.v.count > 0 or keys ~= key or not repeating then
                pace.carry = 0
                return keys
            end

            pace.carry = pace.carry + SPEED
            local steps = math.floor(pace.carry)
            pace.carry = pace.carry - steps
            if steps == 0 then
                return ''
            end
            return steps == 1 and key or steps .. key
        end
    end

    vim.api.nvim_create_user_command('CursorSpeed', function(opts)
        if opts.args ~= '' then
            local speed = tonumber(opts.args)
            if not speed or speed <= 0 then
                vim.notify('CursorSpeed: expected a positive number',
                    vim.log.levels.ERROR)
                return
            end
            SPEED = speed
        end
        print('CursorSpeed: ' .. SPEED)
    end, { nargs = '?', desc = 'Show or set held h/l speed' })

    -- ========================================================
    -- HOLD OR DOUBLE-TAP H/L TO WRAP LINES
    -- ========================================================

    -- Holding l at the end of a line for HOLD_MS moves to the first non-blank
    -- character of the next line; holding h at the start of a line moves to
    -- the last non-blank character of the previous one.
    -- HOLD_MS matches the Windows key-repeat delay (500ms), so the pause at a
    -- line edge feels like the pause before a held key starts repeating.
    -- A gap longer than RELEASE_MS between presses counts as letting go
    -- (it must exceed the OS key-repeat delay, ~500ms by default).
    -- Double-tapping at the edge (ll / hh) wraps right away: two taps there
    -- less than DOUBLE_TAP_MS apart. Held-key repeats never count as taps, so
    -- holding into a line edge still pauses there first.
    local HOLD_MS, RELEASE_MS, DOUBLE_TAP_MS = 500, 600, 400
    local hold = {}

    local function hold_to_wrap(key, at_edge, can_wrap, wrap_keys)
        return function(repeating)
            if vim.v.count > 0 or not at_edge() then
                hold.key = nil
                return key
            end

            local now = vim.uv.hrtime() / 1e6
            local win, lnum = vim.api.nvim_get_current_win(), vim.fn.line('.')
            if hold.key ~= key or hold.win ~= win or hold.lnum ~= lnum
                or now - hold.last > RELEASE_MS then
                hold.key, hold.win, hold.lnum, hold.start = key, win, lnum, now
                hold.last_tap = nil
            end
            hold.last = now

            local double_tap = not repeating and hold.last_tap
                and now - hold.last_tap < DOUBLE_TAP_MS
            if not repeating then
                hold.last_tap = now
            end

            if (double_tap or now - hold.start >= HOLD_MS) and can_wrap() then
                hold.key = nil
                return wrap_keys
            end
            return key
        end
    end

    vim.keymap.set('n', 'l', paced('l', hold_to_wrap('l',
        function() return vim.fn.charcol('.') >= vim.fn.charcol('$') - 1 end,
        function() return vim.fn.line('.') < vim.fn.line('$') end,
        'j^')), { expr = true,
            desc = 'Right (hold or double-tap at line end to wrap)' })

    vim.keymap.set('n', 'h', paced('h', hold_to_wrap('h',
        function() return vim.fn.charcol('.') == 1 end,
        function() return vim.fn.line('.') > 1 end,
        'kg_')), { expr = true,
            desc = 'Left (hold or double-tap at line start to wrap)' })

end
