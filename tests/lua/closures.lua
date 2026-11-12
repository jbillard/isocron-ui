-- Functions: closures and their shared upvalues, varargs, recursion
local function make()
  local n = 0
  local function inc() n = n + 1; return n end
  local function get() return n end
  return inc, get
end
local inc, get = make()
inc(); inc()
print(get())
local fs = {}
for i = 1, 3 do fs[i] = function() return i end end
print(fs[1](), fs[2](), fs[3]())
local gs = {}
local j = 0
while j < 3 do j = j + 1; local k = j; gs[j] = function() return k end end
print(gs[1](), gs[3]())
local function va(...)
  local a, b = ...
  return select("#", ...), a, b, ...
end
print(va())
print(va(1, nil, 3))
print((va(1, 2)))
local function sum(...)
  local s = 0
  for _, v in ipairs({...}) do s = s + v end
  return s
end
print(sum(1, 2, 3, 4))
local function fact(n) if n <= 1 then return 1 end return n * fact(n - 1) end
print(fact(20))
local fib
fib = function(n) if n < 2 then return n end return fib(n - 1) + fib(n - 2) end
print(fib(22))
local obj = {v = 10}
function obj.plain(x) return x end
function obj:method(x) return self.v + x end
print(obj.plain(5), obj:method(5), obj.method(obj, 1))
local a, b, c = (function() return 1, 2, 3 end)()
print(a, b, c)
local t = {(function() return 1, 2 end)(), (function() return 3, 4 end)()}
print(#t, t[3])
local x, y = 1
print(x, y)
local p, q = 1, 2, 3
print(p, q)
local function shadow() local x = "inner"; do local x = "block"; end return x end
print(shadow(), x)
local counter = 0
local function deep(n) counter = counter + 1; if n > 0 then return deep(n - 1) end return counter end
print(deep(100))
do
  local up = 1
  local function f() up = up + 1 end
  f(); f()
  print(up)
end
local adders = {}
for i = 1, 3 do
  local base = i * 10
  adders[i] = function(x) base = base + x; return base end
end
print(adders[1](1), adders[1](1), adders[2](5))
repeat local r = 5 until r == 5
print(type(print), type(nil), type({}), type("s"), type(2), type(true), type(make))
