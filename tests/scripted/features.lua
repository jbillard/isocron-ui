-- The state of features.ui.xml
icon = "dot.png"
content = "(rien)"
width = 100
from = 100
palette = false
query = ""
ran = ""

function key_(key, ctrl)
  if ctrl and key == "p" then
    palette = not palette
    return true
  end
  if ctrl and key == "r" then
    host.readFile("tests/scripted/hello.txt", function(text, err)
      content = "relu : " .. (text or err)
    end)
    return true
  end
  return false
end

host.readFile("tests/scripted/hello.txt", function(text, err)
  content = text or ("erreur : " .. err)
end)
