-- An editor of code in the manner of Visual Studio Code, its interface in
-- editor.ui.xml: the files of a folder in a tree (read by the host:
-- host.listFolder, host.readFile), opened in tabs, their code coloured
-- line by line; a palette that finds a file (Ctrl+P), the side bar and the
-- panel shown or hidden (Ctrl+B, Ctrl+J), a tab closed (Ctrl+W).

root = host.folder or "."   -- the folder of the view
tree = {}            -- path -> { path, name, dir, depth, open, loaded, kids }
rootNode = nil
tabs = {}            -- { path, name, lang, lines, count }
active = 0
current = ""         -- the path chosen in the tree
view = "files"       -- the view of the side bar
search = ""          -- the text of the search
sidebarShown = true
sidebarWidth = 250
panelShown = true
panelHeight = 150
from = 0
palette = false
query = ""
choice = 1
files = {}           -- the paths of the files known, in the order found
log = { "Isocron : éditeur prêt." }

-- the most lines of a file shown
MOST_LINES = 600

local IGNORED = { [".git/"] = true, ["target/"] = true, ["node_modules/"] = true }

local function joined(dir, name)
  if dir == "." then
    return name
  end
  return dir .. "/" .. name
end

local function say(text)
  log[#log + 1] = text
  if #log > 50 then
    table.remove(log, 1)
  end
end

-- the names of a folder: its folders first, then its files, each sorted
local function sorted(names)
  local dirs, plain = {}, {}
  for _, x in ipairs(names) do
    if string.find(x, "/$") then
      dirs[#dirs + 1] = x
    else
      plain[#plain + 1] = x
    end
  end
  table.sort(dirs)
  table.sort(plain)
  for _, x in ipairs(plain) do
    dirs[#dirs + 1] = x
  end
  return dirs
end

-- the folder of the node `n` read: its children made nodes (the files
-- added to those the palette finds), the folder opened when `open`, its
-- folders read too when `deep` (the whole tree read at the start: a
-- folder then opens at once, the palette finds every file)
function loadFolder(n, open, deep)
  host.listFolder(n.path, function(names, err)
    if not names then
      say("Dossier illisible : " .. n.path .. " (" .. tostring(err) .. ")")
      return
    end
    n.kids = {}
    for _, x in ipairs(sorted(names)) do
      if not IGNORED[x] then
        local dir = string.find(x, "/$") ~= nil
        local name = dir and string.sub(x, 1, -2) or x
        local path = joined(n.path, name)
        if not tree[path] then
          tree[path] = { path = path, name = name, dir = dir, depth = n.depth + 1, open = false, loaded = false, kids = {} }
          if not dir then
            files[#files + 1] = path
          end
        end
        n.kids[#n.kids + 1] = path
        if dir and deep and #files < 5000 then
          loadFolder(tree[path], false, true)
        end
      end
    end
    n.loaded = true
    if open then
      n.open = true
    end
  end)
end

-- the nodes shown in the tree: those of the open folders, in order
function visibleNodes()
  local out = {}
  local function walk(n)
    for _, p in ipairs(n.kids) do
      local k = tree[p]
      out[#out + 1] = k
      if k.dir and k.open then
        walk(k)
      end
    end
  end
  if rootNode then
    walk(rootNode)
  end
  return out
end

function clickNode(n)
  current = n.path
  if n.dir then
    if n.open then
      n.open = false
    elseif n.loaded then
      n.open = true
    else
      loadFolder(n, true, false)
    end
  else
    openFile(n.path)
  end
end

-- ----- the languages and their colours -------------------------------

local COLORS = {
  plain = "#D4D4D4", keyword = "#569CD6", control = "#C586C0", string = "#CE9178",
  comment = "#6A9955", number = "#B5CEA8", call = "#DCDCAA", type = "#4EC9B0",
  tag = "#569CD6", attr = "#9CDCFE", punct = "#D4D4D4",
}

local function set(words)
  local s = {}
  for w in string.gmatch(words, "%S+") do
    s[w] = true
  end
  return s
end

local LANGS = {
  lua = { name = "Lua", line = "--", keywords = set("local function end if then else elseif for in do while repeat until return break nil true false and or not goto"),
          control = set("if then else elseif for in do while repeat until return break goto") },
  isc = { name = "Isocron", line = "//", block = { "/*", "*/" }, keywords = set("function action const type import export from match return if else true false as"),
          control = set("if else return match"), types = set("i64 i32 u8 u32 u64 f32 f64 string boolean void Result Ok Err Some None") },
  rs = { name = "Rust", line = "//", block = { "/*", "*/" }, keywords = set("fn let mut pub use mod struct enum impl trait for in if else match return while loop break continue const static true false self Self where as ref move"),
         control = set("if else match return while loop for break continue"), types = set("i64 i32 u8 u32 u64 usize f32 f64 bool str String Vec Option Result Box") },
  py = { name = "Python", line = "#", keywords = set("def class import from return if elif else for in while try except finally with as pass break continue and or not None True False lambda yield"),
         control = set("if elif else for while return try except finally break continue") },
  sh = { name = "Shell", line = "#", keywords = set("if then else elif fi for in do done while case esac function return export local set"),
         control = set("if then else elif fi for do done while case esac return") },
  style = { name = "Styles", block = { "/*", "*/" }, keywords = set("") },
  xml = { name = "XML", xml = true },
  md = { name = "Markdown", keywords = set("") },
  txt = { name = "Texte brut", keywords = set("") },
}

local EXTENSIONS = { lua = "lua", isc = "isc", rs = "rs", py = "py", sh = "sh", style = "style", css = "style",
  xml = "xml", html = "xml", md = "md", txt = "txt", json = "txt", toml = "txt" }

function langOf(name)
  local ext = string.match(name, "%.([%w_]+)$")
  return LANGS[EXTENSIONS[ext or ""] or "txt"]
end

-- the colour of the icon of a file, by its kind
function fileColor(name)
  local ext = string.match(name, "%.([%w_]+)$") or ""
  local c = { isc = "#3B82F6", lua = "#4F7ACF", rs = "#DEA584", py = "#3572A5", sh = "#89E051", xml = "#E37933",
              style = "#C586C0", css = "#C586C0", md = "#519ABA", png = "#A074C4", ttf = "#A074C4", json = "#CBCB41", toml = "#9C4221" }
  return c[ext] or "#8B8B8B"
end

-- the tokens of the line `s` of the language `lang`, `state` true when a
-- block comment is open at its start: the tokens ({ text, color }) and
-- the state at its end
local function tokens(s, lang, state)
  local out = {}
  -- (the spaces a token ends with given to the next one: the width of a
  -- text ends at its last character that is not a space)
  local pending = ""
  local function add(text, kind)
    if text == "" then
      return
    end
    local sp = string.find(text, "%s+$")
    local body = pending .. (sp and string.sub(text, 1, sp - 1) or text)
    pending = sp and string.sub(text, sp) or ""
    if body == "" or string.find(body, "^%s+$") then
      pending = body .. pending
      return
    end
    local last = out[#out]
    if last and last.kind == kind and not string.find(body, "^%s") then
      last.text = last.text .. body
    else
      out[#out + 1] = { text = body, kind = kind, color = COLORS[kind] }
    end
  end
  local i, n = 1, #s
  if lang.xml then
    while i <= n do
      local a, b = string.find(s, "<!%-%-.-%-%->", i)
      local t = string.find(s, "<", i, true)
      if a and a == i then
        add(string.sub(s, a, b), "comment")
        i = b + 1
      elseif t == i then
        local e = string.find(s, ">", i, true) or n
        local inner = string.sub(s, i, e)
        local j = 1
        local name = string.match(inner, "^</?[%w_:%-]*")
        add(name, "tag")
        j = #name + 1
        while j <= #inner do
          local q1, q2 = string.find(inner, "\"[^\"]*\"", j)
          if q1 then
            add(string.sub(inner, j, q1 - 1), "attr")
            add(string.sub(inner, q1, q2), "string")
            j = q2 + 1
          else
            add(string.sub(inner, j), "tag")
            j = #inner + 1
          end
        end
        i = e + 1
      else
        local e = (t or n + 1) - 1
        add(string.sub(s, i, e), "plain")
        i = e + 1
      end
    end
    return out, false
  end
  while i <= n do
    if state then
      local a, b = string.find(s, lang.block[2], i, true)
      if a then
        add(string.sub(s, i, b), "comment")
        i = b + 1
        state = false
      else
        add(string.sub(s, i), "comment")
        i = n + 1
      end
    else
      -- (the strings of this Lua are texts: a character is never cut,
      -- each test a pattern at `i`, each part between ASCII characters)
      if lang.block and string.find(s, lang.block[1], i, true) == i then
        state = true
        add(lang.block[1], "comment")
        i = i + #lang.block[1]
      elseif lang.line and string.find(s, lang.line, i, true) == i then
        add(string.sub(s, i), "comment")
        i = n + 1
      elseif string.find(s, "^[\"'`]", i) then
        local q = string.sub(s, i, i)
        local j = n
        local at = i + 1
        while at <= n do
          local a = string.find(s, "[\\" .. q .. "]", at)
          if not a then
            break
          end
          if string.find(s, "^\\", a) then
            at = a + 2
          else
            j = a
            break
          end
        end
        add(string.sub(s, i, j), "string")
        i = j + 1
      elseif string.find(s, "^%d", i) then
        local a, b = string.find(s, "^[%w_%.]+", i)
        add(string.sub(s, a, b), "number")
        i = b + 1
      elseif string.find(s, "^[%a_]", i) then
        local a, b = string.find(s, "^[%w_]+", i)
        local w = string.sub(s, a, b)
        local kind = "plain"
        if lang.control and lang.control[w] then
          kind = "control"
        elseif lang.keywords and lang.keywords[w] then
          kind = "keyword"
        elseif lang.types and lang.types[w] then
          kind = "type"
        elseif string.find(s, "^%(", b + 1) then
          kind = "call"
        elseif string.find(w, "^%u") then
          kind = "type"
        end
        add(w, kind)
        i = b + 1
      else
        local a, b = string.find(s, "^[^%w_\"'`]+", i)
        local part = string.sub(s, a, b)
        -- (a comment may start inside the punctuation)
        local cut = nil
        for _, mark in ipairs({ lang.line or "\0", lang.block and lang.block[1] or "\0" }) do
          local m = string.find(part, mark, 1, true)
          if m and (not cut or m < cut) then
            cut = m
          end
        end
        if cut and cut > 1 then
          part = string.sub(part, 1, cut - 1)
        elseif cut == 1 then
          part = string.sub(part, 1, 1)
        end
        add(part, "punct")
        i = i + #part
      end
    end
  end
  return out, state
end

-- the lines of the text `text` of a file, each its tokens (MOST_LINES at
-- most), and the number of its lines
local function linesOf(text, lang)
  local lines = {}
  local count = 0
  local state = false
  for raw in string.gmatch(text .. "\n", "([^\n]*)\n") do
    count = count + 1
    if count <= MOST_LINES then
      local s = string.gsub(string.gsub(raw, "\r$", ""), "\t", "    ")
      local toks
      toks, state = tokens(s, lang, state)
      lines[#lines + 1] = toks
    end
  end
  return lines, count
end

-- ----- tabs ------------------------------------------------------------

function openFile(path)
  for k, t in ipairs(tabs) do
    if t.path == path then
      active = k
      current = path
      return
    end
  end
  local name = string.match(path, "([^/]+)$") or path
  host.readFile(path, function(text, err)
    if not text then
      say("Lecture impossible : " .. path .. " (" .. tostring(err) .. ")")
      return
    end
    local lang = langOf(name)
    local lines, count
    if string.find(text, "\0", 1, true) then
      lines, count = { { { text = "(fichier binaire : non affiché)", color = COLORS.comment } } }, 1
    else
      lines, count = linesOf(text, lang)
    end
    tabs[#tabs + 1] = { path = path, name = name, lang = lang.name, lines = lines, count = count }
    active = #tabs
    current = path
    say("Ouvert : " .. rel(path) .. " (" .. count .. " lignes)")
  end)
end

function selectTab(k)
  active = k
  current = tabs[k].path
end

function closeTab(k)
  if k < 1 or k > #tabs then
    return
  end
  table.remove(tabs, k)
  if active >= k then
    active = math.max(active - 1, #tabs > 0 and 1 or 0)
  end
  current = active > 0 and tabs[active].path or ""
end

function activeTab()
  return tabs[active]
end

function codeLines()
  local t = tabs[active]
  return t and t.lines or {}
end

function more()
  local t = tabs[active]
  if t and t.count > MOST_LINES then
    return { "… " .. (t.count - MOST_LINES) .. " lignes de plus, non affichées" }
  end
  return {}
end

-- the path `p` from the folder shown
function rel(p)
  if root ~= "." and string.find(p, root, 1, true) == 1 then
    return string.sub(p, #root + 2)
  end
  return p
end

function breadcrumb()
  local t = tabs[active]
  if not t then
    return ""
  end
  return (string.gsub(string.gsub(rel(t.path), "\\", "/"), "/", "  ›  "))
end

-- ----- the palette -----------------------------------------------------

-- the files whose path holds the letters of `text` in their order, `most`
-- at most
function found(text, most)
  local out = {}
  local q = string.lower(text)
  -- (letters of ASCII found in their order; a text with others found as
  -- it is: its characters are not cut)
  local ascii = string.find(q, "^[%w%p ]*$") ~= nil
  for _, p in ipairs(files) do
    local lp = string.lower(p)
    local at, ok = 1, true
    if not ascii then
      ok = string.find(lp, q, 1, true) ~= nil
    end
    for k = 1, ascii and #q or 0 do
      local found = string.find(lp, string.sub(q, k, k), at, true)
      if not found then
        ok = false
        break
      end
      at = found + 1
    end
    if ok then
      out[#out + 1] = p
      if #out >= most then
        break
      end
    end
  end
  return out
end

function matches()
  return found(query, 12)
end

function openChoice()
  local m = matches()
  if m[choice] then
    openFile(m[choice])
  end
  palette = false
end

function togglePalette()
  palette = not palette
  query = ""
  choice = 1
end

-- ----- the keys and the bars -------------------------------------------

function onKey(key, ctrl)
  if ctrl and key == "p" then
    togglePalette()
    return true
  end
  if ctrl and key == "b" then
    sidebarShown = not sidebarShown
    return true
  end
  if ctrl and key == "j" then
    panelShown = not panelShown
    return true
  end
  if ctrl and key == "w" then
    closeTab(active)
    return true
  end
  if palette then
    if key == "Escape" then
      palette = false
      return true
    end
    if key == "Down" then
      choice = math.min(choice + 1, math.max(1, #matches()))
      return true
    end
    if key == "Up" then
      choice = math.max(1, choice - 1)
      return true
    end
  end
  return false
end

function showView(v)
  if view == v and sidebarShown then
    sidebarShown = false
  else
    view = v
    sidebarShown = true
  end
end

menus = { "Fichier", "Édition", "Sélection", "Affichage", "Atteindre", "Exécuter", "Terminal", "Aide" }
activities = { "files", "search", "branch", "blocks" }
viewNames = { files = "Explorateur (Ctrl+B)", search = "Rechercher", branch = "Gestion des sources", blocks = "Extensions" }

function viewTitle()
  return ({ files = "EXPLORATEUR", search = "RECHERCHE", branch = "GESTION DES SOURCES", blocks = "EXTENSIONS" })[view] or ""
end

function rootTitle()
  return root == "." and "DOSSIER COURANT" or string.upper(string.match(root, "([^/\\]+)[/\\]*$") or root)
end

-- the chevron of a node: a folder closed or open, nothing for a file
function chevron(n)
  if not n.dir then
    return "icons/blank.png"
  end
  return n.open and "icons/open.png" or "icons/closed.png"
end

function icon(v)
  return v .. ((view == v and sidebarShown) and "_on.png" or ".png")
end

function title()
  local t = tabs[active]
  return (t and (t.name .. " — ") or "") .. "Isocron"
end

function statusRight()
  local t = tabs[active]
  if not t then
    return ""
  end
  return t.count .. " lignes    UTF-8    LF    " .. t.lang
end

function logLines()
  return log
end

-- the folder at the start
rootNode = { path = root, name = root, dir = true, depth = -1, open = true, loaded = false, kids = {} }
tree[root] = rootNode
loadFolder(rootNode, true, true)
