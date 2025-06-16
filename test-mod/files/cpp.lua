local ffi = require 'ffi'
local bit = require 'bit'

ffi.cdef [[
    typedef struct cpp_string {
        union {
            char buf[16];
            char* ptr;
        };
        uint32_t len;
        uint32_t cap;
    } cpp_string;
]]

ffi.metatype('cpp_string', {
    __tostring = function(s)
        return ffi.string(s.cap <= 15 and s.buf or s.ptr, s.len)
    end,
    __len = function(s)
        return s.len
    end,
})

ffi.cdef [[
    typedef struct cpp_vector_bool {
        char* start;
        char* end;
        char* end_cap;
        int len;
    } cpp_vector_bool;
]]

ffi.metatype('cpp_vector_bool', {
    __index = function(v, key)
        if type(key) == 'number' and key >= 0 and key < v.len then
            return bit.band(v.start[math.floor(key / 8)], bit.lshift(1, key % 8)) ~= 0
        end
    end,
    __newindex = function(v, key, value)
        if type(key) == 'number' then
            if key < 0 or key >= v.len then
                return
            end
            local byte_idx = math.floor(key / 8)
            local mask = bit.lshift(1, key % 8)
            if value then
                v.start[byte_idx] = bit.bor(v.start[byte_idx], mask)
            else
                v.start[byte_idx] = bit.band(v.start[byte_idx], bit.bnot(mask))
            end
        end
    end,
    __len = function(v)
        return v.len
    end,
})

local function cpp_vector(item_type_name)
    local decl = string.gsub([[
        typedef struct cpp_vector_$type {
            $type* start;
            $type* end;
            $type* end_cap;
        } cpp_vector_$type;
    ]], '$type', item_type_name)

    ffi.cdef(decl)

    local tpe = ffi.typeof('cpp_vector_' .. item_type_name)

    ffi.metatype(tpe, {
        __index = function(v, key)
            if type(key) == 'number' and key >= 0 and key < v['end'] - v.start then
                return v.start[key]
            end
        end,
        __newindex = function(v, key, value)
            if type(key) == 'number' and key >= 0 and key < v['end'] - v.start then
                v.start[key] = value
            end
        end,
        __len = function(v)
            return v['end'] - v.start
        end,
    })

    return tpe
end

cpp_vector('void')
cpp_vector('int')

ffi.cdef [[
    typedef struct cpp_map_node {
        struct cpp_map_node* left;
        struct cpp_map_node* up;
        struct cpp_map_node* right;
        uint32_t _meta;
        cpp_string key;
        int32_t value;
    } cpp_map_node;

    typedef struct cpp_map {
        cpp_map_node* root;
        uint32_t len;
    } cpp_map;
]]

ffi.metatype('cpp_map', {
    __index = function(map, key)
        if not map.root or not map.root.up then
            return
        end
        local node = map.root.up
        while node ~= nil and node ~= map.root do
            local node_key = tostring(node.key)
            if key == node_key then
                return node.value
            elseif key < node_key then
                node = node.left
            else
                node = node.right
            end
        end
    end,
    __len = function(map)
        return map.len
    end,
})

function cpp_map_to_table(map)
    local result = {}
    if not map.root or not map.root.up then
        return result
    end
    local function traverse(node)
        if not node or node == map.root then
            return
        end
        traverse(node.left)
        result[tostring(node.key)] = node.value
        traverse(node.right)
    end
    traverse(map.root.up)
    return result
end
