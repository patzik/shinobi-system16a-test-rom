local f = 0
local out = io.open(os.getenv("CAPFILE"), "wb")
local sp = manager.machine.devices[":maincpu"].spaces["program"]
local n = 0
emu.register_frame_done(function()
  f = f + 1
  if f > 300 and f % 20 == 0 then
    local t = {}
    for a = 0x440000, 0x4407fe, 2 do t[#t+1] = string.pack(">I2", sp:read_u16(a)) end
    for a = 0x840000, 0x840ffe, 2 do t[#t+1] = string.pack(">I2", sp:read_u16(a)) end
    out:write(table.concat(t)); n = n + 1
  end
  if f == 60*60*6 then out:close(); print("FRAMES "..n); manager.machine:exit() end
end)
