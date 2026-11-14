-- the state of tests/scripted/close.ui.xml: whether the window is kept
-- open, how many times it asked to close, its document
keep = true
asked = 0
host.openDoc("a.txt", "one")

function letGo()
  keep = false
  return true
end

-- (saved under another path, then closed at once: written before)
function savedAs()
  host.saveAs("a.txt", "b.lua")
  host.closeDoc("b.lua")
  return true
end
