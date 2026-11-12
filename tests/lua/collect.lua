-- The collector of the machine: values kept and dropped while it runs, in
-- registers, varargs, cells, tables, metatables, across pcall and the
-- library (the sizes are enough to collect several times)
local keep = {}
local function mk(i) return {i = i, s = "v" .. i, t = {i * 2}} end
for i = 1, 60000 do
  local t = mk(i)
  if i % 3 == 0 then keep[#keep + 1] = t end
  local junk = {i, i + 1, tostring(i) .. "junk"}
end
local sum = 0
for _, t in ipairs(keep) do sum = sum + t.i + t.t[1] + #t.s end
print(#keep, sum)

-- closures and their cells survive
local fs = {}
for i = 1, 30000 do
  local n = i
  fs[i] = function(k) n = n + k; return n end
  local waste = {n, "x" .. n}
end
local acc = 0
for i = 1, 30000, 7 do acc = acc + fs[i](1) end
print(acc)

-- metatables and methods
local P = {}
P.__index = P
function P.new(x) return setmetatable({x = x, tag = "p" .. x}, P) end
function P:get() return self.x end
local ps = {}
for i = 1, 40000 do ps[i % 1000 + 1] = P.new(i) end
local tot = 0
for i = 1, 1000 do tot = tot + ps[i]:get() + #ps[i].tag end
print(tot)

-- inside pcall, with errors
local ok = 0
for i = 1, 20000 do
  local r, e = pcall(function(a) local b = {a, tostring(a)}; if a % 5 == 0 then error("e" .. a) end; return #b[2] end, i)
  if r then ok = ok + e else ok = ok + #e end
end
print(ok)

-- varargs kept across collections
local function pack(...) local t = {...}; local u = {}; for i = 1, 200 do u[i] = {i} end; return select("#", ...), t end
local cnt = 0
for i = 1, 300 do local n, t = pack(i, "a" .. i, {i}); cnt = cnt + n + t[1] + #t[2] + t[3][1] end
print(cnt)

-- sort with a function and gsub with a function while collecting
local words = {}
for i = 1, 20000 do words[i] = "w" .. ((i * 7919) % 20000) end
table.sort(words, function(a, b) local z = {a, b}; return a < b end)
print(words[1], words[2], words[20000])
local text = string.rep("ab", 5000)
local rep, n = text:gsub("a", function(c) local z = {c, c .. c}; return z[2] end)
print(#rep, n)

-- deep recursion that allocates
local function build(d) if d == 0 then return {} end local t = build(d - 1); t[#t + 1] = "d" .. d; return t end
local deep = build(3000)
print(#deep, deep[1], deep[3000])

-- strings as keys
local h = {}
for i = 1, 50000 do h["k" .. (i % 5000)] = i end
local hs = 0
for k, v in pairs(h) do hs = hs + v end
print(hs)
