-- What this Lua does that the reference does not: strings are texts of
-- UTF-8 (reverse keeps the characters, a cut inside a character is an
-- error); upper and lower change the letters of ASCII alone, as the
-- reference does in its locale C (escapes.lua)
print(("Été"):upper(), ("ÉTÉ"):lower(), ("aé"):reverse())
print(pcall(string.sub, "é", 1, 1))
print(pcall(string.char, 195))
print(("é"):sub(1, 2), ("aéb"):match("a(.+)b"))
