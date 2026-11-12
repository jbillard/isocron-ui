-- The first things of Lua: numbers, tables, closures, the library
print("bonjour", 1, 2.5, 10 / 2, 7 // 2, 7 % 3, -7 % 3, 2 ^ 10, 1e100, 0.1)
local t = {1, 2, 3, x = "a", y = true}
print(#t, t.x, t.y, t[2])
local function fib(n) if n < 2 then return n end return fib(n - 1) + fib(n - 2) end
print(fib(20))
local s = 0
for i = 1, 100 do s = s + i end
print(s)
for k, v in pairs({a = 1}) do print(k, v) end
for i, v in ipairs({"x", "y"}) do print(i, v) end
local function counter() local n = 0 return function() n = n + 1 return n end end
local c = counter()
c() c()
print(c())
print(string.format("%5.2f|%d|%s|%x|%q", 3.14159, 42, "hé", 255, "a\nb"))
print(("abc"):upper(), #"héllo", ("hello world"):find("wor"), ("key=val"):match("(%w+)=(%w+)"))
print(("hello"):gsub("l", "L"))
for w in ("un deux trois"):gmatch("%a+") do print(w) end
print(pcall(function() error("boum") end))
print(pcall(function() local x = nil; return x.y end))
print(select("#", 1, 2, 3), select(2, "a", "b", "c"))
local mt = {__index = function(t, k) return k .. "!" end, __add = function(a, b) return "added" end}
local o = setmetatable({}, mt)
print(o.foo, o + 1)
print(tostring(nil), tostring(1.0), tostring(-0.0), 2^53, math.floor(3.7), math.max(1, 5, 3), math.huge, -math.huge)
print(table.concat({1, 2, 3}, ", "), #{n = 1}, next({}))
local arr = {5, 2, 8, 1}
table.sort(arr)
print(table.concat(arr, " "))
table.sort(arr, function(a, b) return a > b end)
print(table.concat(arr, " "))
table.insert(arr, 9); table.insert(arr, 1, 0); print(table.concat(arr, " "), table.remove(arr), table.remove(arr, 1), #arr)
print(tonumber("0x10"), tonumber("  12  "), tonumber("1e2"), tonumber("abc"), tonumber("10", 2), math.type(1), math.type(1.0))
print(1 == 1.0, "a" < "b", 3 // 0.0, -3 // 0.0, 3 % -2, 3.5 % -2)

print(string.rep("ab", 3, "-"), ("x"):byte(), string.char(72, 105))
