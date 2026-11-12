-- Metatables: __index, __newindex, __call, the operators, __tostring, __len
local Vec = {}
Vec.__index = Vec
function Vec.new(x, y) return setmetatable({x = x, y = y}, Vec) end
function Vec.__add(a, b) return Vec.new(a.x + b.x, a.y + b.y) end
function Vec.__eq(a, b) return a.x == b.x and a.y == b.y end
function Vec.__lt(a, b) return a.x < b.x end
function Vec.__le(a, b) return a.x <= b.x end
function Vec.__tostring(v) return "(" .. v.x .. ", " .. v.y .. ")" end
function Vec.__len(v) return 2 end
function Vec.__unm(v) return Vec.new(-v.x, -v.y) end
function Vec.__concat(a, b) return tostring(a) .. tostring(b) end
function Vec.__call(v, k) return v.x * k end
function Vec:norm2() return self.x * self.x + self.y * self.y end
local a, b = Vec.new(1, 2), Vec.new(3, 4)
print(tostring(a + b), a == Vec.new(1, 2), a ~= b, a < b, a <= b, b > a, #a, tostring(-a), a .. b, a(10), b:norm2())
local defaults = setmetatable({}, {__index = {color = "red", size = 3}})
defaults.size = 5
print(defaults.color, defaults.size, rawget(defaults, "color"))
local log = {}
local proxy = setmetatable({}, {__newindex = function(t, k, v) log[#log + 1] = k; rawset(t, k, v) end})
proxy.a = 1; proxy.b = 2; proxy.a = 3
print(table.concat(log, ","), proxy.a)
local chain = setmetatable({}, {__index = setmetatable({mid = "m"}, {__index = {top = "t"}})})
print(chain.mid, chain.top, chain.none)
local calls = setmetatable({}, {__index = function(t, k) return k:upper() end})
print(calls.hello, calls["x"])
local ro = setmetatable({}, {__metatable = "locked"})
print(getmetatable(ro), pcall(setmetatable, ro, {}))
print(getmetatable("s") == nil, getmetatable({}) == nil)
local Animal = {}
Animal.__index = Animal
function Animal.new(name) return setmetatable({name = name}, Animal) end
function Animal:speak() return self.name .. " makes a sound" end
local Dog = setmetatable({}, {__index = Animal})
Dog.__index = Dog
function Dog.new(name) return setmetatable(Animal.new(name), Dog) end
function Dog:speak() return self.name .. " barks" end
local d, an = Dog.new("Rex"), Animal.new("Generic")
print(d:speak(), an:speak(), Animal.speak(d))
local pairsed = setmetatable({}, {__pairs = function(t) return function(_, k) if not k then return 1, "one" end end, t, nil end})
for k, v in pairs(pairsed) do print("pairs", k, v) end
print(rawequal(a, Vec.new(1, 2)), a == a)
