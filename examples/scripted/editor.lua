-- An editor of code in the manner of Visual Studio Code, its interface in
-- editor.ui.xml: the files of a folder in a tree (read by the host:
-- host.listFolder, host.readFile), opened in tabs, their code coloured
-- line by line; a palette that finds a file (Ctrl+P), the side bar and the
-- panel shown or hidden (Ctrl+B, Ctrl+J), a tab closed (Ctrl+W), a file
-- made (Ctrl+N), saved (Ctrl+S), saved under another name (Ctrl+Shift+S);
-- a file changed and not saved asked to be saved before its tab or the
-- window closes (the dialog of Visual Studio Code).

root = host.folder or "."   -- the folder of the view
tree = {}            -- path -> { path, name, dir, depth, open, loaded, kids }
rootNode = nil
tabs = {}            -- { path, name, lang, lines, count }
active = 0
current = ""         -- the path chosen in the tree
view = "files"       -- the view of the side bar
search = ""          -- the text of the search
sidebarShown = true
sidebarWidth = 300
panelShown = false
panelHeight = 150
from = 0
palette = false
query = ""
choice = 1
saveAs = false       -- the palette asks the path a file is saved under
dialog = nil         -- the dialog asking to save: { kind, k, paths }
untitled = 0         -- the files made so far (Untitled-1, ...)
afterSave = nil      -- what the dialog closes once the file is saved
files = {}           -- the paths of the files known, in the order found
log = { "Isocron : éditeur prêt." }

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

-- the order of the names of the explorer of Visual Studio Code: that of
-- the collation of the system (ICU's root): the punctuation first (`_`
-- before `.`), then the digits, then the letters whatever their case; two
-- names of the same key in the order of their bytes
local PUNCT = "\t _-,;:!?.'\"()[]{}@*/\\&#%`^+<=>|~$"
local RANK = {}
for k = 1, #PUNCT do
  RANK[string.sub(PUNCT, k, k)] = string.char(k)
end

local function nameKey(x)
  -- (ASCII alone ranked: a character beyond it kept as it is, whole)
  return (string.gsub(x, "[%w%p%s]", function(c)
    local b = string.byte(c)
    if RANK[c] then
      return RANK[c]
    elseif b >= 48 and b <= 57 then
      return string.char(b - 48 + 40)
    elseif b >= 65 and b <= 90 then
      return string.char(b - 65 + 60)
    elseif b >= 97 and b <= 122 then
      return string.char(b - 97 + 60)
    elseif b >= 128 then
      return c
    end
    return string.char(90)
  end)) .. "\1" .. x
end

local function byName(a, b)
  return nameKey(a) < nameKey(b)
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
  table.sort(dirs, byName)
  table.sort(plain, byName)
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

-- ----- the icons ------------------------------------------------------

-- the icons of Visual Studio Code (the font codicon, `font="icons"`)
I = {
  files = "\u{EAF0}", search = "\u{EA6D}", branch = "\u{EA68}", debug = "\u{EB91}", blocks = "\u{EAE6}",
  account = "\u{EB99}", gear = "\u{EB51}", right = "\u{EAB6}", down = "\u{EAB4}", close = "\u{EA76}",
  more = "\u{EA7C}", back = "\u{EA9B}", forward = "\u{EA9C}", split = "\u{EB56}", error = "\u{EA87}",
  warning = "\u{EA6C}", bell = "\u{EAA2}", remote = "\u{EB3A}", sidebar = "\u{EBF3}", panel = "\u{EBF2}",
  aside = "\u{EBF4}", braces = "\u{EB0F}", file = "\u{EA7B}", folder = "\u{EA83}", info = "\u{EA74}",
  markdown = "\u{EB1D}", terminal = "\u{EA85}",
  minimize = "\u{EABA}", maximize = "\u{EAB9}", restore = "\u{EABB}", closeWindow = "\u{EAB8}",
  chat = "\u{EC4F}", copilot = "\u{EC1E}", layout = "\u{EBEB}",
  sidebarOn = "\u{EBF3}", sidebarOff = "\u{EC02}", panelOn = "\u{EBF2}", panelOff = "\u{EC01}",
  asideOn = "\u{EBF4}", asideOff = "\u{EC00}", object = "\u{EA8B}", array = "\u{EA8A}",
  dirty = "\u{EA71}",
}

-- the glyphs of the buttons of the window: those of the system under
-- Windows (Segoe Fluent Icons, `font="caption"`, 10 units), else those of
-- Visual Studio Code (codicon, 16)
local CAPTION = { min = "\u{E921}", max = "\u{E922}", restore = "\u{E923}", close = "\u{E8BB}" }
local CHROME = { min = I.minimize, max = I.maximize, restore = I.restore, close = I.closeWindow }

function winGlyph(kind)
  if kind == "max" and host.maximized then
    kind = "restore"
  end
  return host.system == "windows" and CAPTION[kind] or CHROME[kind]
end

function captionFont()
  return host.system == "windows" and "caption" or "icons"
end

function captionSize()
  return host.system == "windows" and 10 or 16
end

-- the box that finds a file: 38 % of the window wide, 600 units at most
function commandWidth()
  return math.min(600, (host.width or 1100) * 0.38)
end

-- the icon of a file as the theme Seti of Visual Studio Code chooses it
-- (seti.lua, the font seti.ttf at 150 % of the text): by its name, then by
-- its extensions (the longest first: `tsconfig.json` before `json`), then
-- by its language; else the icon of a file
local LANGUAGE_OF = {
  py = "python", pyw = "python", sh = "shellscript", bash = "shellscript", zsh = "shellscript",
  yaml = "yaml", yml = "yaml", md = "markdown", markdown = "markdown", lua = "lua", json = "json",
  jsonc = "jsonc", jsonl = "jsonl", js = "javascript", mjs = "javascript", cjs = "javascript",
  jsx = "javascriptreact", ts = "typescript", mts = "typescript", tsx = "typescriptreact",
  rs = "rust", go = "go", c = "c", h = "c", cpp = "cpp", cc = "cpp", hpp = "cpp", cs = "csharp",
  java = "java", kt = "kotlin", swift = "swift", rb = "ruby", php = "php", pl = "perl",
  css = "css", scss = "scss", sass = "sass", less = "less", html = "html", htm = "html",
  xml = "xml", svg = "xml", sql = "sql", bat = "bat", cmd = "bat", ps1 = "powershell",
  r = "r", dart = "dart", vue = "vue", tex = "latex", ini = "properties", properties = "properties",
  gradle = "gradle", groovy = "groovy", ml = "ocaml", hs = "haskell", ex = "elixir", jl = "julia",
}
local NAME_LANGUAGE = { dockerfile = "dockerfile", makefile = "makefile", [".gitignore"] = "ignore",
  [".dockerignore"] = "ignore", [".env"] = "dotenv" }

function kindOf(name)
  local low = string.lower(string.match(name, "([^/\\]+)$") or name)
  local hit = SETI.names[low]
  if hit then
    return hit
  end
  -- (the extensions: from the first dot after the start of the name)
  local at = string.find(low, ".", 2, true)
  while at do
    local ext = string.sub(low, at + 1)
    hit = SETI.extensions[ext]
    if hit then
      return hit
    end
    at = string.find(low, ".", at + 1, true)
  end
  local ext = string.match(low, "%.([^%.]+)$")
  local language = NAME_LANGUAGE[low] or (ext and LANGUAGE_OF[ext])
  return (language and SETI.languages[language]) or SETI.file
end

function fileIcon(name)
  return kindOf(name)[1]
end

function fileIconColor(name)
  return kindOf(name)[2]
end

function fileIconFont(name)
  return "seti"
end

function fileIconSize(name)
  return 19.5
end

-- the sections of the explorer below the tree
sections = { "Outline", "Timeline" }

-- ----- tabs ------------------------------------------------------------

-- a file opened: its document made by the host (host.openFile: its lines,
-- its cursor, its colours, its undo; the keys and the pointer change it
-- there), a tab for it, the keyboard given to its code
function openFile(path)
  for k, t in ipairs(tabs) do
    if t.path == path then
      active = k
      current = path
      host.focusCode()
      return
    end
  end
  local name = string.match(path, "([^/\\]+)$") or path
  -- (its document made by the host as it reads it: its text, however
  -- large, never given to Lua; a binary file shown as Visual Studio Code
  -- says it cannot be)
  host.openFile(path, function(ok, err)
    if not ok then
      say("Lecture impossible : " .. path .. " (" .. tostring(err) .. ")")
      return
    end
    tabs[#tabs + 1] = { path = path, name = name }
    active = #tabs
    current = path
    host.focusCode()
    say("Ouvert : " .. rel(path))
  end)
end

function selectTab(k)
  active = k
  current = tabs[k].path
  host.focusCode()
end

-- ----- the files made, saved, not saved ---------------------------------

local function baseName(p)
  return string.match(p, "([^/\\]+)$") or p
end

-- whether `p` is a file made and never saved (Untitled-1, ...)
function isUntitled(p)
  return string.match(p, "^Untitled%-%d+$") ~= nil
end

-- the paths of the tabs whose files changed and are not saved
local function dirtyPaths()
  local out = {}
  for _, t in ipairs(tabs) do
    local d = host.docs[t.path]
    if d and d.dirty then
      out[#out + 1] = t.path
    end
  end
  return out
end

-- Ctrl+N: a file made, empty, in a tab of its own
function newFile()
  untitled = untitled + 1
  local path = "Untitled-" .. untitled
  host.openDoc(path, "")
  tabs[#tabs + 1] = { path = path, name = path }
  active = #tabs
  current = path
  host.focusCode()
end

-- Ctrl+S: the file of the tab written (a file made: its path asked)
function saveActive()
  local t = tabs[active]
  if not t then
    return
  end
  if isUntitled(t.path) then
    openSaveAs()
  else
    host.save(t.path)
  end
end

-- Ctrl+Shift+S: the palette asks the path the file is saved under (that
-- of the file, else the folder and its name)
function openSaveAs()
  local t = tabs[active]
  if not t then
    return
  end
  palette = true
  saveAs = true
  query = isUntitled(t.path) and joined(root, t.name) or t.path
  choice = 1
end

-- the file of the tab saved under `to`: the tab renamed, its folder read
-- again (the explorer shows it)
function savedAs(to)
  local t = tabs[active]
  palette = false
  saveAs = false
  if not t or to == "" then
    return
  end
  host.saveAs(t.path, to)
  t.path = to
  t.name = baseName(to)
  current = to
  host.focusCode()
  local dir = string.match(to, "^(.*)[/\\][^/\\]+$") or "."
  local n = tree[dir] or (dir == root and rootNode) or nil
  if n then
    loadFolder(n, n.open, false)
  end
  say("Enregistré : " .. rel(to))
  if afterSave then
    local next = afterSave
    afterSave = nil
    closeAfter(next)
  end
end

-- the tab `k` closed, its file asked to be saved first when it changed
function requestCloseTab(k)
  local t = tabs[k]
  if not t then
    return
  end
  local d = host.docs[t.path]
  if d and d.dirty then
    dialog = { kind = "tab", k = k, paths = { t.path } }
    host.blurCode()
    return
  end
  closeTab(k)
end

-- the window asks to close: its files changed asked to be saved first (a
-- true value: kept open meanwhile)
function beforeClose()
  local paths = dirtyPaths()
  if #paths == 0 then
    return false
  end
  dialog = { kind = "window", paths = paths }
  host.blurCode()
  return true
end

-- what the dialog closes, its files saved or not
function closeAfter(dl)
  if dl.kind == "tab" then
    closeTab(dl.k)
  else
    host.close()
  end
end

-- the texts of the dialog
function dialogMessage()
  if #dialog.paths == 1 then
    return "Do you want to save the changes you made to " .. baseName(dialog.paths[1]) .. "?"
  end
  return "Do you want to save the changes to the following " .. #dialog.paths .. " files?"
end

function dialogNames()
  local out = {}
  if #dialog.paths > 1 then
    for _, p in ipairs(dialog.paths) do
      out[#out + 1] = baseName(p)
    end
  end
  return out
end

function dialogSaveText()
  return #dialog.paths > 1 and "Save All" or "Save"
end

-- its buttons: the files saved (a file made: its path asked first), then
-- the tab or the window closed; not saved; nothing done
function dialogSave()
  local dl = dialog
  dialog = nil
  for _, p in ipairs(dl.paths) do
    if isUntitled(p) then
      for k, t in ipairs(tabs) do
        if t.path == p then
          active = k
          current = p
        end
      end
      afterSave = dl
      openSaveAs()
      return
    end
  end
  for _, p in ipairs(dl.paths) do
    host.save(p)
  end
  closeAfter(dl)
end

function dialogDontSave()
  local dl = dialog
  dialog = nil
  closeAfter(dl)
  host.focusCode()
end

function dialogCancel()
  dialog = nil
  host.focusCode()
end

function closeTab(k)
  if k < 1 or k > #tabs then
    return
  end
  host.closeDoc(tabs[k].path)
  table.remove(tabs, k)
  if active >= k then
    active = math.max(active - 1, #tabs > 0 and 1 or 0)
  end
  current = active > 0 and tabs[active].path or ""
  -- (the keyboard back in the code of the tab shown)
  if active > 0 then
    host.focusCode()
  end
end

function activeTab()
  return tabs[active]
end

-- the path of the document shown ("" without a tab)
function activePath()
  local t = tabs[active]
  return t and t.path or ""
end

-- what the host tells of the document of the tab `t` (host.docs: its line,
-- its column, whether it changed, its language, its indentation, its ends
-- of lines, the symbols around its cursor)
local function docOf(t)
  return t and host.docs[t.path]
end

-- the path `p` from the folder shown
function rel(p)
  if root ~= "." and string.find(p, root, 1, true) == 1 then
    return string.sub(p, #root + 2)
  end
  return p
end

-- the symbols around the cursor of the tab `t` (a JSON: its outline, as
-- the breadcrumbs of Visual Studio Code show it), told by the host
local function symbols(t)
  local d = docOf(t)
  local out = {}
  for _, sym in ipairs(d and d.symbols or {}) do
    out[#out + 1] = { name = sym.name, icon = sym.array and I.array or I.object }
  end
  return out
end

-- the parts of the path of the file of the tab (its icon on the file),
-- then the symbols around the cursor, each its icon and whether it is the
-- last
function crumbs()
  local t = tabs[active]
  if not t then
    return {}
  end
  local out = {}
  for part in string.gmatch(string.gsub(rel(t.path), "\\", "/"), "[^/]+") do
    out[#out + 1] = { name = part, last = false, file = false, icon = "" }
  end
  if #out > 0 then
    out[#out].file = true
  end
  for _, sym in ipairs(symbols(t)) do
    out[#out + 1] = { name = sym.name, last = false, file = false, icon = sym.icon }
  end
  if #out > 0 then
    out[#out].last = true
  end
  return out
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
  if saveAs then
    savedAs(query)
    return
  end
  local m = matches()
  if m[choice] then
    openFile(m[choice])
  end
  palette = false
end

function matchesShown()
  return saveAs and {} or matches()
end

function togglePalette()
  palette = not palette
  saveAs = false
  query = ""
  choice = 1
end

-- ----- the keys and the bars -------------------------------------------

function onKey(key, ctrl, shift, alt)
  -- (the dialog: Enter saves, Escape cancels, the other keys nothing)
  if dialog then
    if key == "Enter" then
      dialogSave()
    elseif key == "Escape" then
      dialogCancel()
    end
    return true
  end
  if ctrl and key == "n" then
    newFile()
    return true
  end
  if ctrl and shift and key == "s" then
    openSaveAs()
    return true
  end
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
    requestCloseTab(active)
    return true
  end
  if ctrl and key == "s" then
    saveActive()
    return true
  end
  if palette then
    if key == "Escape" then
      palette = false
      saveAs = false
      afterSave = nil
      if tabs[active] then
        host.focusCode()
      end
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

-- (the words of Visual Studio Code in English, as the author's)
menus = { "File", "Edit", "Selection", "View", "Go", "Run", "Terminal", "Help" }
activities = { "files", "search", "branch", "debug", "blocks" }
viewNames = { files = "Explorer (Ctrl+Shift+E)", search = "Search (Ctrl+Shift+F)", branch = "Source Control (Ctrl+Shift+G)", debug = "Run and Debug (Ctrl+Shift+D)", blocks = "Extensions (Ctrl+Shift+X)" }

function viewTitle()
  return ({ files = "Explorer", search = "Search", branch = "Source Control", debug = "Run and Debug", blocks = "Extensions" })[view] or ""
end

-- the name of the folder shown (that of the current folder, told by the
-- host, for ".")
function rootName()
  local path = root == "." and (host.cwd or ".") or root
  return string.match(path, "([^/\\]+)[/\\]*$") or path
end

function rootTitle()
  return rootName()
end

-- the chevron of a node: a folder closed or open, nothing for a file
function chevron(n)
  if not n.dir then
    return ""
  end
  return n.open and I.down or I.right
end

-- whether the activity `v` is the view shown
function shown(v)
  return view == v and sidebarShown
end

function title()
  local t = tabs[active]
  return (t and (t.name .. " — ") or "") .. "Isocron"
end

-- the items of the right of the bar of the state (none without a file)
function statusItems()
  local d = docOf(tabs[active])
  if not d then
    return {}
  end
  return { d.status, "Spaces: " .. d.indent, "UTF-8", d.eol }
end

-- the tabs as they are drawn: the one shown joined to its editor (the
-- first flush with the edge of the card: no shoulder at its left), a line
-- between two others
function tabsView()
  local out = {}
  for k, t in ipairs(tabs) do
    local d = docOf(t)
    out[#out + 1] = { k = k, name = t.name, active = k == active, first = k == 1,
                      divider = k > 1 and k ~= active and k - 1 ~= active, dirty = d and d.dirty or false }
  end
  return out
end

function langName()
  local d = docOf(tabs[active])
  return d and d.lang or ""
end

function logLines()
  return log
end

-- the folder at the start
rootNode = { path = root, name = root, dir = true, depth = -1, open = true, loaded = false, kids = {} }
tree[root] = rootNode
loadFolder(rootNode, true, true)
