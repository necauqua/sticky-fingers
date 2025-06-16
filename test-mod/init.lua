--dofile('api_def.lua')

dofile_once('mods/test-mod/files/engine.lua')

local FKEY = 57

local debug_gui = nil
local step = false

local function draw_text(x, y, text)
    if not debug_gui then
        return
    end
    for line in text:gmatch("([^\n]*)\n?") do
        GuiText(debug_gui, x, y, line)
        y = y + 10
    end
end

local mouse_stuck = false
local sticky_state = {}

local function on_update()
    if InputIsKeyJustUp(FKEY + 9) then
        pause_simulation()
    end

    if simulation_paused() then
        if InputIsKeyJustUp(FKEY + 10) then
            step = true
            pause_simulation(false)
        end
    elseif step then
        step = false
        pause_simulation(true)
    end

    local platform = get_platform()
    local controls = platform.app_config.keyboard_controls
    local keyboard = platform.keyboard
    local mouse = platform.mouse


    local function handle_press(keybind, control_check, control_set)
        if control_check == 0 then
            return
        end
        if control_set == 0 then
            control_set = control_check
        end
        if control_check > 0 then
            if InputIsKeyJustUp(control_check) then
                local state = sticky_state[keybind]
                sticky_state[keybind] = not state
                if control_set > 0 then
                    keyboard.keys_down[control_set] = not state
                else
                    local button_index = msb(-control_set) + 1
                    fire_mouse_button_event(button_index, not state)
                end
            end
        else
            local button_index = msb(-control_check) + 1
            if InputIsMouseButtonJustUp(button_index) then
                local state = sticky_state[keybind]
                sticky_state[keybind] = not state
                if control_set > 0 then
                    keyboard.keys_down[control_set] = not state
                else
                    local button_index2 = msb(-control_set) + 1
                    fire_mouse_button_event(button_index2, not state)
                end
            end
        end
    end

    for _, keybind in pairs(KEYBINDS) do
        local control = controls[keybind]
        handle_press(keybind, control.primary, control.primary)
        handle_press(keybind, control.secondary, control.primary)
    end


    -- if InputIsKeyJustDown(14) then
    --     keyboard.keys_down[controls.key_up.primary] = not keyboard.keys_down[controls.key_up.primary]
    -- end

    if not debug_gui then
        debug_gui = GuiCreate()
    end
    GuiStartFrame(debug_gui)

    local np, poly = get_random_states()

    local lines = {
        'frame counter: ' .. tostring(GameGetFrameNum()),
        string.format('random state: 0x%08X', np),
        string.format('poly state: %f', poly),
        string.format('mouse pos: %.1f, %.1f', mouse.pos.x, mouse.pos.y),
        'current actions:\n  ' .. table.concat(get_current_actions(), '\n  '),
    }
    draw_text(185, 40, table.concat(lines, "\n"))
end

OnWorldPreUpdate = on_update
OnPausePreUpdate = on_update
