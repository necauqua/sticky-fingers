local ffi = require 'ffi'
local bit = require 'bit'

dofile_once('mods/test-mod/files/cpp.lua')
dofile_once('mods/test-mod/files/scan.lua')

KEYBINDS = {
    'key_up', 'key_down', 'key_left', 'key_right',
    'key_use_wand', 'key_spray_flask', 'key_throw', 'key_kick',
    'key_inventory', 'key_interact', 'key_drop_item', 'key_drink_potion',
    'key_item_next', 'key_item_prev', 'key_item_slot1', 'key_item_slot2', 'key_item_slot3', 'key_item_slot4',
    'key_item_slot5', 'key_item_slot6', 'key_item_slot7', 'key_item_slot8', 'key_item_slot9', 'key_item_slot10',
    'key_takescreenshot', 'key_replayedit_open', 'aim_stick', 'key_ui_confirm', 'key_ui_drag', 'key_ui_quick_drag',
}

local decl = {}
for _, key in ipairs(KEYBINDS) do
    table.insert(decl, '    ControlsConfigKey ' .. key .. ';\n')
end

ffi.cdef [[
    typedef struct ControlsConfigKey {
        int primary;
        int secondary;
        cpp_string primary_name;
        cpp_string secondary_name;
    } ControlsConfigKey;
]]

ffi.cdef('typedef struct ControlsConfig {\n' .. table.concat(decl) .. '} ControlsConfig;')

ffi.cdef [[
    typedef struct GameGlobal {
        int frame_count;
        char skip[0x44];
        int *ui_flags;
    } GameGlobal;

    typedef struct WizardAppConfig {
        char skip[0x10c];
        ControlsConfig keyboard_controls;
    } WizardAppConfig;

    typedef struct vec2 {
        float x;
        float y;
    } vec2;

    typedef struct IMouseListener {
        void* vftable;
        vec2 pos;
        int buttons;
    } IMouseListener;

    typedef struct Mouse {
        void* vftable;
        cpp_vector_void mMouseListeners;
        cpp_vector_bool buttons_down;
        cpp_vector_int buttons_just_down;
        cpp_vector_int buttons_just_up;
        bool cursor_visible;
        vec2 pos;
        int frame_num;
        int last_frame_has_moved;
        int last_frame_buttons_pressed;
        void* SDL_cursor;
    } Mouse;

    typedef struct Keyboard {
        cpp_vector_void mListeners;
        cpp_vector_bool keys_down;
        cpp_vector_bool keys_just_down;
        cpp_vector_bool keys_just_up;
        cpp_string text_input;
        bool disable_repeats;
        int current_frame_num;
        int last_frame_active;
    } Keyboard;

    typedef struct Platform {
        void* vftable;
        void* application;
        WizardAppConfig* app_config;
        float internal_height;
        float internal_width;
        bool input_disabled;
        void* graphics;
        bool fixed_time_step;
        int frame_count;
        int frame_rate;
        double last_frame_execution_time;
        double average_frame_execution_time;
        double one_frame_should_last;
        double time_elapsed_tracker;
        int width;
        int height;
        void* event_recorder;
        Mouse* mouse;
        Keyboard* keyboard;
    } Platform;


    typedef void(__thiscall *FireKeyDownEvent_t)(Keyboard* this, unsigned int keycode, unsigned int unicode);
    typedef void(__thiscall *FireKeyUpEvent_t)(Keyboard* this, unsigned int keycode, unsigned int unicode);

    typedef void(__thiscall *FireMouseMoveEvent_t)(Mouse* this, vec2* pos);
    typedef void(__thiscall *FireMouseDownEvent_t)(Mouse* this, vec2* pos, unsigned int button);
    typedef void(__thiscall *FireMouseUpEvent_t)(Mouse* this, vec2* pos, unsigned int button);


    typedef struct EventRecorderVftable {
        void* destructor;
        void* skip1;
        void* skip2;
        void* skip3;
        void* fire_window_focus_event;
        void* fire_key_down_event;
        void* fire_key_up_event;
        void* fire_mouse_move_event;
        void* fire_mouse_down_event;
        void* fire_mouse_up_event;
    } EventRecorderVftable;
]]

local function get_first_rel_jmp(event_recorder_fn)
    local ptr = ffi.cast('uint8_t*', event_recorder_fn)

    -- Scan first two alightments for the relative jump instruction (0xE8)
    -- and calculate the jump target address.
    for i = 0, 0x20 do
        if ptr[i] == 0xE9 then
            return ptr + i + 5 + ffi.cast('int*', ptr + i + 1)[0]
        end
        if ptr[i] == 0xCC then
            print_error('did not find a relative jump, arrived at 0xCC, ' .. tostring(event_recorder_fn))
            return
        end
    end
    print_error('did not find anything in 0x20 bytes?.. ' .. tostring(event_recorder_fn))
end

local er_vftable = ffi.cast('EventRecorderVftable*', locate_vftable('.?AVEventRecorder@poro@@'))

local magic_pointers = {
    pause = ffi.cast('bool*', 0x01204bcb),
    random_state = ffi.cast('int*', 0x0120741c),
    poly_random_state = ffi.cast('double*', 0x01207420),

    poro_platform = ffi.cast('Platform*', locate_poro_platform()),

    fire_key_down_event = ffi.cast('FireKeyDownEvent_t', get_first_rel_jmp(er_vftable.fire_key_down_event)),
    fire_key_up_event = ffi.cast('FireKeyUpEvent_t', get_first_rel_jmp(er_vftable.fire_key_up_event)),
    fire_mouse_move_event = ffi.cast('FireMouseMoveEvent_t', get_first_rel_jmp(er_vftable.fire_mouse_move_event)),
    fire_mouse_down_event = ffi.cast('FireMouseDownEvent_t', get_first_rel_jmp(er_vftable.fire_mouse_down_event)),
    fire_mouse_up_event = ffi.cast('FireMouseUpEvent_t', get_first_rel_jmp(er_vftable.fire_mouse_up_event)),
}

function fire_mouse_button_event(button, state)
    local mouse = magic_pointers.poro_platform.mouse
    local pos = mouse.pos

    if state == nil then
        state = not mouse.buttons_down[button]
    end
    if state then
        magic_pointers.fire_mouse_down_event(mouse, pos, button)
    else
        magic_pointers.fire_mouse_up_event(mouse, pos, button)
    end
end

function get_platform()
    return magic_pointers.poro_platform
end

function get_random_states()
    return magic_pointers.random_state[0], magic_pointers.poly_random_state[0]
end

function simulation_paused()
    return magic_pointers.pause[0]
end

function pause_simulation(pause)
    if pause == nil then
        pause = not magic_pointers.pause[0]
    end
    magic_pointers.pause[0] = pause
end

function msb(n)
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

function get_current_actions()
    local platform = get_platform()
    local controls = platform.app_config.keyboard_controls

    local buttons_down = platform.mouse.buttons_down
    local keys_down = platform.keyboard.keys_down
    local actions = {}

    for _, key in ipairs(KEYBINDS) do
        local control = controls[key]
        if control.primary ~= 0 then
            if control.primary < 0 then
                if buttons_down[msb(-control.primary) + 1] then
                    table.insert(actions, key)
                end
            elseif keys_down[control.primary] then
                table.insert(actions, key)
            end
        end
        if control.secondary ~= 0 then
            if control.secondary < 0 then
                if buttons_down[msb(-control.secondary) + 1] then
                    table.insert(actions, key)
                end
            elseif keys_down[control.secondary] then
                table.insert(actions, key .. ' (secondary)')
            end
        end
    end

    return actions
end
