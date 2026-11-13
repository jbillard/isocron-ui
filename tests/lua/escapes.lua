-- the escapes of strings: \u{...} (Lua 5.3), with \x, decimal and simple ones
local s = "\u{41}\u{e9}\u{20AC}\u{1F600}\u{EAF0}"
print(#s, string.byte(s, 1, -1))
print("\u{0}" == "\0", #"\u{7F}", #"\u{80}", #"\u{7FF}", #"\u{800}", #"\u{FFFF}", #"\u{10000}", #"\u{10FFFF}")
print("\x41\66\u{43}\t|")
print(("caf\u{E9}"):upper(), #"caf\u{E9}")
print(("caf\u{E9}"):lower(), ("ÉCOLE"):lower())
