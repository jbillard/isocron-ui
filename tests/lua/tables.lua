-- Tables: the array part, the hashes, lengths, next, the library of tables
local t = {}
for i = 1, 10 do t[i] = i * i end
print(#t, t[1], t[10], t[11])
t[#t] = nil
print(#t)
local h = {}
h.a = 1; h.b = 2; h["c"] = 3; h[1.0] = "one"; h[2] = "two"; h[true] = "yes"
print(h.a, h.b, h.c, h[1], h[2], h[true], #h)
local keys = {}
for k in pairs(h) do keys[#keys + 1] = tostring(k) end
table.sort(keys)
print(table.concat(keys, " "))
h.a = nil
local n = 0
for k, v in pairs(h) do n = n + 1 end
print(n)
local big = {}
for i = 1, 1000 do big["k" .. i] = i end
local sum = 0
for k, v in pairs(big) do sum = sum + v end
print(sum)
for i = 1, 1000, 2 do big["k" .. i] = nil end
sum = 0
for k, v in pairs(big) do sum = sum + v end
print(sum)
local holes = {1, 2, nil, 4}
print(holes[4], select("#", table.unpack({1, 2, 3})))
local sparse = {}
sparse[3] = "c"; sparse[1] = "a"; sparse[2] = "b"
print(#sparse, table.concat(sparse))
local q = {}
table.insert(q, "a"); table.insert(q, "c"); table.insert(q, 2, "b"); table.insert(q, 1, "z")
print(table.concat(q, ","), table.remove(q, 1), table.remove(q), table.concat(q, ","))
print(table.unpack({1, 2, 3}, 2), table.unpack({1, 2, 3}, 2, 3), table.pack(1, nil, 3).n)
local nested = {a = {b = {c = "deep"}}}
print(nested.a.b.c, nested["a"]["b"]["c"])
local m = {}
m[m] = "self"
print(m[m])
print(next({}, nil), type(next), rawlen({1, 2}), rawequal(t, t), rawget(h, "b"))
local words = {"pear", "apple", "fig", "banana"}
table.sort(words)
print(table.concat(words, " "))
table.sort(words, function(a, b) return #a < #b end)
print(words[1], words[4])
local nums = {}
for i = 1, 100 do nums[i] = (i * 37) % 101 end
table.sort(nums)
local ok = true
for i = 2, 100 do if nums[i - 1] > nums[i] then ok = false end end
print(ok, nums[1], nums[100])
print(pcall(table.insert, {}, 5, 1))
print(pcall(function() local x = {} ; x[nil] = 1 end))
print(pcall(function() local x = {} ; x[0/0] = 1 end))
print(#"", #{n = 3}, #{1, 2, 3, nil})
