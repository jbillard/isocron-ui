-- Numbers: integers of 64 bits and floats, their operators and texts
print(1, 1.0, -0.0, 0.1 + 0.2, 1/3, 100.0, 1e15, 1e16, 123456789012345678, 2^63, -2^63)
print(1e300 * 1e10, -1e300 * 1e10, 2^-1074, 5e-324, 1.7976931348623157e308, 3.14159265358979)
print(math.maxinteger, math.mininteger, math.maxinteger + 1 == math.mininteger, math.mininteger // -1)
print(7 // 2, -7 // 2, 7 // -2, -7 // -2, 7.5 // 2, -7.5 // 2, 7 % 3, -7 % 3, 7 % -3, -7 % -3)
print(7.5 % 2, -7.5 % 2, 5 % math.huge, -5 % math.huge, 2^0.5, 10 / 4, 3 / 0, -3 / 0)
print(pcall(function() return 1 // 0 end))
print(pcall(function() return 1 % 0 end))
print(1 == 1.0, 1 < 1.5, 2 > 1.5, math.type(3 // 1), math.type(3.0 // 1), math.type(2^2))
print(tonumber("10"), tonumber("10.5"), tonumber(" 0x1p4 "), tonumber("1e"), tonumber(""), tonumber("0x"), tonumber("1 2"))
print(tonumber("ff", 16), tonumber("777", 8), tonumber("zz", 36), tonumber("8", 8), tonumber("-101", 2))
print(math.floor(-3.5), math.ceil(-3.5), math.floor(3), math.abs(-4), math.abs(-4.5), math.max(2, 7.5, 3), math.min(4, -1, 0))
print(math.sqrt(16), math.fmod(7, 3), math.fmod(-7, 3), math.fmod(7.5, 2), math.tointeger(3.0), math.tointeger(3.5), math.tointeger("8"))
print(math.modf(3.7), math.modf(-3.7), math.ult(1, -1), math.pi, math.huge)
print(string.format("%.14g", 0.1), string.format("%.17g", 0.1), string.format("%.3f", 2.0005), string.format("%.2f", 2.675))
print(8 // 3 * 3 + 8 % 3, (2^53 + 1) == 2^53, 255 // 16, "10" / 2, "3" + 4, "0x10" + 0)
local s = 0
for i = 10, 1, -3 do s = s * 10 + i end
print(s)
for x = 0, 1, 0.25 do io_x = (io_x or "") .. x .. " " end
print(io_x)
for i = math.maxinteger - 2, math.maxinteger do print(i) end
for i = 1, 0 do print("never") end
print(pcall(function() for i = 1, 10, 0 do end end))
