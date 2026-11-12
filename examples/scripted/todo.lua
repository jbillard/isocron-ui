-- The list of tasks of todo.ui.xml: its tasks, the text of its field (the
-- global `newTask`, kept by the field), what its buttons do.
tasks = {
  { text = "Écrire la bibliothèque", done = true },
  { text = "Taper du texte dans un champ", done = false },
}
newTask = ""

-- the text of the field added as a task (an empty field adds nothing)
function add()
  if newTask ~= "" then
    tasks[#tasks + 1] = { text = newTask, done = false }
    newTask = ""
  end
end

function toggle(k)
  tasks[k].done = not tasks[k].done
end

function remove(k)
  table.remove(tasks, k)
end

function clearDone()
  local kept = {}
  for _, t in ipairs(tasks) do
    if not t.done then
      kept[#kept + 1] = t
    end
  end
  tasks = kept
end

-- the tasks left to do, in words
function leftText()
  local n = 0
  for _, t in ipairs(tasks) do
    if not t.done then
      n = n + 1
    end
  end
  return n <= 1 and (n .. " tâche à faire") or (n .. " tâches à faire")
end

-- the tasks printed when the window is closed, as todo_app prints them
function report()
  local parts = {}
  for _, t in ipairs(tasks) do
    parts[#parts + 1] = (t.done and "[x] " or "[ ] ") .. t.text
  end
  print("[" .. table.concat(parts, ", ") .. "]")
end
