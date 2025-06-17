local ffi = require 'ffi'
local bit = require 'bit'

ffi.cdef [[
    void* GetModuleHandleA(char* lpModuleName);

    void* memchr(const void* ptr, int value, size_t num);

    int memcmp(const void* ptr1, const void* ptr2, size_t num);

    typedef struct {
        char pad[60];
        uint32_t e_lfanew;
    } IMAGE_DOS_HEADER;

    typedef struct {
        char pad[6];
        uint16_t NumberOfSections;
        char pad2[12];
        uint16_t SizeOfOptionalHeader;
        char pad3[2];
    } IMAGE_NT_HEADERS32;

    typedef struct {
        char Name[8];
        uint32_t VirtualSize;
        uint32_t VirtualAddress;
        char pad[24];
    } IMAGE_SECTION_HEADER;
]]

-- dont hardcode 0x00400000 because of ASLR
local base = tonumber(ffi.cast("uint32_t", ffi.C.GetModuleHandleA(nil)))

-- look at the PE header to figure out the exact ranges of .data and .rdata
-- sections to minimize the ranges we have to scan
-- (also avoids reading out-of-bounds memory if we dont find something)

local dos = ffi.cast("IMAGE_DOS_HEADER*", base)
local pe = ffi.cast("IMAGE_NT_HEADERS32*", base + dos.e_lfanew)
local sections = ffi.cast("IMAGE_SECTION_HEADER*", ffi.cast("char*", pe) + 24 + pe.SizeOfOptionalHeader)

local data
local rdata

for i = 0, pe.NumberOfSections - 1 do
    local section = sections[i]
    local name = ffi.string(section.Name, 8)
    if name == ".data\0\0\0" then
        data = {
            offset = base + section.VirtualAddress,
            len = section.VirtualSize,
        }
    elseif name == ".rdata\0\0" then
        rdata = {
            offset = base + section.VirtualAddress,
            len = section.VirtualSize,
        }
    end
end

-- if nolla ever makes it 64-bit it would be so
-- worth breaking this I can't even describe
if not data or not rdata then
    error('Noita stopped being 32-bit PE?')
end

-- okie I actually vibecoded this function and didnt read into it too much,
-- it seems to work and on the surface looks fine, hopefully the AI didn't
-- make any off-by-1 errors that I would've made
local function memfind(section, needle, needle_len)
    local first_byte = ffi.cast("uint8_t*", needle)[0]
    local search_ptr = ffi.cast("uint8_t*", section.offset)
    local remaining = section.len

    while remaining >= needle_len do
        -- Find first byte of pattern
        local found = ffi.C.memchr(search_ptr, first_byte, remaining - needle_len + 1)
        if found == nil then
            break
        end

        -- Check if full pattern matches
        if ffi.C.memcmp(found, needle, needle_len) == 0 then
            return ffi.cast("size_t", found) + 1
        end

        -- Move past this match and continue
        local advance = ffi.cast("uint8_t*", found) - search_ptr + 1
        search_ptr = search_ptr + advance
        remaining = remaining - advance
    end

    return nil
end

local function to_le_bytes(value)
    value = tonumber(value)
    local bytes = ffi.new("unsigned char[4]")
    bytes[1] = bit.band(value, 0xFF)
    bytes[2] = bit.band(bit.rshift(value, 8), 0xFF)
    bytes[3] = bit.band(bit.rshift(value, 16), 0xFF)
    bytes[4] = bit.band(bit.rshift(value, 24), 0xFF)
    return bytes
end

--- @param name string
--- @return number
function locate_vftable(name)
    -- first we find the part of the RTTI type descriptor that contains
    -- the type name that should not ever change I hope
    local in_desc = memfind(data, name, #name)
    -- offset back to get the descriptor pointer value
    local desc_bytes = to_le_bytes(in_desc - 9)
    -- and scan for the usage of that value, which should be in an
    -- RTTI locator thing
    local in_locator = memfind(rdata, desc_bytes, 4)
    -- same thing but to find usages of the locator
    local locator_bytes = to_le_bytes(in_locator - 12)
    -- which is pointed to from a place right before the vftable
    local before_vftable = memfind(rdata, locator_bytes, 4)

    local vftable = before_vftable + 4

    if log then log("vftable for %s: 0x%08X", name, tonumber(vftable)) end

    return vftable
end

function locate_static_global(name)
    local vftable = locate_vftable(name)
    local vftable_bytes = to_le_bytes(vftable)
    -- which is at the beginning of the static global
    local addr = memfind(data, vftable_bytes, 4)

    if log then log("static global %s: 0x%08X", name, tonumber(addr)) end

    return addr
end
