--dofile('../api_def.lua')

local bit = require('bit')

dofile_once('mods/sticky-fingers/files/log.lua')
dofile_once('mods/sticky-fingers/files/engine.lua')

local enable_setting = ModSettingGet('sticky-fingers.enable')
local state_setting = ModSettingGet('sticky-fingers.show-state')
local keybind_setting = ModSettingGet('sticky-fingers.keybind')

function OnPausedChanged()
    enable_setting = ModSettingGet('sticky-fingers.enable')
    state_setting = ModSettingGet('sticky-fingers.show-state')
    keybind_setting = ModSettingGet('sticky-fingers.keybind')
end

local grease = {}
local state_gui = nil

local cheat_period = 1337 -- ~22 seconds

local cheat_code = 'i am bald'
local cheat_buffer = string.rep(' ', #cheat_code)

local cheat_frame = -cheat_period

local relese_all

local function cheating()
    local input = tostring(PLATFORM.keyboard.text_input)
    local frame = GameGetFrameNum()

    if #input ~= 0 then
        cheat_buffer = string.sub(cheat_buffer .. input, #input + 1)
        if cheat_buffer:lower() == cheat_code then
            cheat_frame = frame
            relese_all()
            cheat_buffer = string.rep(' ', #cheat_code)
        end
    end

    local last_cheat = frame - cheat_frame
    local duration = cheat_period - last_cheat

    if duration <= 0 then
        return
    end

    if not state_gui then
        state_gui = GuiCreate()
    end

    GuiStartFrame(state_gui)

    local msg = string.format('[%d] [BALD MODE] A cheating bald cheater who cheats is playing right now!', duration)

    GuiColorSetForNextWidget(state_gui, 0.8, 0.2, 0.2, 1.0)
    GuiText(state_gui, 230, 6.5, msg)

    return true
end

local function msb(n)
    if n == 0 then return end

    local pos = 0

    if bit.band(n, 0xFFFF0000) ~= 0 then
        pos = pos + 16
        n = bit.rshift(n, 16)
    end
    if bit.band(n, 0xFF00) ~= 0 then
        pos = pos + 8
        n = bit.rshift(n, 8)
    end
    if bit.band(n, 0xF0) ~= 0 then
        pos = pos + 4
        n = bit.rshift(n, 4)
    end
    if bit.band(n, 0xC) ~= 0 then
        pos = pos + 2
        n = bit.rshift(n, 2)
    end
    if bit.band(n, 0x2) ~= 0 then pos = pos + 1 end

    return pos
end

local function get_current_actions()
    local controls = PLATFORM.app_config.keyboard_controls
    local buttons_down = PLATFORM.mouse.buttons_down
    local keys_down = PLATFORM.keyboard.keys_down

    local actions = {}

    local function presentable(key)
        local nice = (key:match('^key_(.*)') or key)
            :gsub('_', ' ')
            :gsub('^%l', string.upper)
            :gsub('%d$', ' %1')
        return nice
    end

    for _, key in ipairs(KEYBINDS) do
        local control = controls[key]
        if control.primary ~= 0 then
            if control.primary < 0 then
                if buttons_down[msb(-control.primary) + 1] then
                    table.insert(actions, presentable(key))
                end
            elseif keys_down[control.primary] then
                table.insert(actions, presentable(key))
            end
        end
        if control.secondary ~= 0 then
            if control.secondary < 0 then
                if buttons_down[msb(-control.secondary) + 1] then
                    table.insert(actions, presentable(key))
                end
            elseif keys_down[control.secondary] then
                table.insert(actions, presentable(key) .. ' (secondary)')
            end
        end
    end

    return actions
end

relese_all = function()
    local controls = PLATFORM.app_config.keyboard_controls
    local keyboard = PLATFORM.keyboard
    local mouse = PLATFORM.mouse

    for _, keybind in pairs(KEYBINDS) do
        grease[keybind] = false
        local control = controls[keybind]
        for _, control_idx in pairs({ control.primary, control.secondary }) do
            if control_idx > 0 then
                keyboard.keys_down[control_idx] = false
            elseif control_idx < 0 then
                mouse:fire_button_event(msb(-control_idx) + 1, false)
            end
        end
    end
end

function OnWorldPreUpdate()
    if not enable_setting then
        return
    end

    if cheating() then
        return
    end

    local controls = PLATFORM.app_config.keyboard_controls
    local keyboard = PLATFORM.keyboard
    local mouse = PLATFORM.mouse

    local saw = {}

    local function handle_press(keybind, control_check, control_set)
        if control_check == 0 then
            return
        end
        if control_set == 0 then
            control_set = control_check
        end

        if saw[control_check] then
            return
        end
        saw[control_check] = true

        if control_check > 0 then
            if InputIsKeyJustUp(control_check) then
                local state = grease[keybind]
                grease[keybind] = not state
                if control_set > 0 then
                    keyboard.keys_down[control_set] = not state
                else
                    local button_index = msb(-control_set) + 1
                    mouse:fire_button_event(button_index, not state)
                end
            end
        else
            local button_index = msb(-control_check) + 1
            if InputIsMouseButtonJustUp(button_index) then
                local state = grease[keybind]
                grease[keybind] = not state

                if control_set > 0 then
                    keyboard.keys_down[control_set] = not state
                else
                    local button_index2 = msb(-control_set) + 1
                    if not state then
                        mouse.buttons_just_up[button_index2] = 0
                        mouse.buttons_down[button_index2] = true
                        mouse.last_frame_buttons_pressed = mouse.last_frame_buttons_pressed - 60
                    end
                    mouse:fire_button_event(button_index2, not state)
                end
            end
        end
    end

    for _, keybind in pairs(KEYBINDS) do
        local control = controls[keybind]
        handle_press(keybind, control.primary, control.primary)
        handle_press(keybind, control.secondary, control.primary)
    end

    if keybind_setting and InputIsKeyJustUp(21) then -- Key_r
        relese_all()
    end

    if not state_setting then
        return
    end

    local current_actions = get_current_actions()
    if #current_actions == 0 then
        return
    end
    if not state_gui then
        state_gui = GuiCreate()
    end
    GuiStartFrame(state_gui)
    GuiColorSetForNextWidget(state_gui, 0.8, 0.8, 0.8, 1.0)
    GuiText(state_gui, 230, 6.5, 'Pressed: ' .. table.concat(get_current_actions(), ', '))
end

-- render the cheat banner in pause menu (and as a bonus allow enabling it from there too)
OnPausePreUpdate = cheating

emit_logs()
