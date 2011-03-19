---
-- The python module.
-- It provides utilities for editing Python code.
-- User tags are loaded from _USERHOME/modules/python/tags/ and user apis
-- are loaded from _USERHOME/modules/python/api/.
module('_m.python', package.seeall)

-- Markdown:
-- ## Key Commands
--
-- + `Alt+L, M`: Open this module for editing.
-- + `.`: When to the right of a known symbol, show an autocompletion list of
--   fields and functions.
-- + `Ctrl+I`: (Windows and Linux) Autocomplete symbol.
-- + `~`: (Mac OSX) Autocomplete symbol.
-- + `Ctrl+H`: Show documentation for the selected symbol or the symbol under
--   the caret.
--
-- ## Fields
--
-- * `sense`: The Python Adeptsense.

local m_editing, m_run = _m.textadept.editing, _m.textadept.run
-- Comment string tables use lexer names.
m_editing.comment_string.python = '# '
-- Compile and Run command tables use file extensions.
m_run.run_command.py = 'python %(filename)'
m_run.error_detail.python = {
  pattern = '^%s*File "([^"]+)", line (%d+)',
  filename = 1, line = 2
}

---
-- Sets default buffer properties for Python files.
function set_buffer_properties()
  buffer.indent = 4
end

-- Adeptsense.

sense = _m.textadept.adeptsense.new('python')
sense.syntax.symbol_chars = '[%w_%.]'
sense.syntax.type_declarations = {}
sense.syntax.type_assignments = {
  ['^[\'"]'] = 'string',
  ['([%w_]+%.[%w_]+)'] = '%1'
}
sense:add_trigger('.')

-- Attempt to get module name.
function sense:get_class(symbol)
  local class = self.super.get_class(self, symbol)
  if class then return class end
  local buffer = buffer
  for i = 0, buffer.line_count do
    local line = buffer:get_line(i)
    local class = line:match('import (.+) as '..symbol)
    if class then return class end
  end
  return nil
end

-- Add items to sense.completions table.
function load_completions(completions)
  for k, v in pairs(completions) do
    sense.completions[k] = v
  end
end

-- Load user tags and apidoc.
for tagfile in lfs.dir(_USERHOME..'/modules/python/tags') do
  if not tagfile:match('^%.%.?$') then
    dofile(_USERHOME..'/modules/python/tags/'..tagfile)
  end
end
local apidir = _USERHOME..'/modules/python/api'
for apifile in lfs.dir(apidir) do
  if not apifile:match('^%.%.?$') then
    sense.api_files[#sense.api_files + 1] = apidir..'/'..apifile
  end
end

-- Commands.

---
-- Automatically indent after a colon.
function indent_after_colon()
  local buffer = buffer
  local line_num = buffer:line_from_position(buffer.current_pos)
  buffer:begin_undo_action()
  buffer:new_line()
  local line = buffer:get_line(line_num)
  local indent = buffer.line_indentation[line_num]
  if line:match('.+:[\n\r]+$') then
    buffer.line_indentation[line_num + 1] = indent + buffer.indent
    buffer:line_end()
  else
    buffer.line_indentation[line_num + 1] = indent
  end
  buffer:end_undo_action()
end

events.connect('file_after_save',
  function() -- show syntax errors as annotations
    if buffer:get_lexer() == 'python' then
       local lfs = require 'lfs'
      local buffer = buffer
      buffer:annotation_clear_all()
      local filepath = buffer.filename:iconv(_CHARSET, 'UTF-8')
      local filedir, filename = '', filepath
      if filepath:find('[/\\]') then
        filedir, filename = filepath:match('^(.+[/\\])([^/\\]+)$')
      end
      local current_dir = lfs.currentdir()
      lfs.chdir(filedir)
      local command = 'python -c \"import py_compile; py_compile.compile(r\''
                      .. filename .. '\')\"'
      local p = io.popen(command..' 2>&1')
      local out = p:read('*line')
      p:close()
      lfs.chdir(current_dir)
      if out then
        local err_type, err_msg, line =
          out:match("(.*:%s)%('(.*)',%s%(.+',%s(%d+)")
        if line then
          buffer.annotation_visible = 2
          buffer:annotation_set_text(line - 1, err_type..err_msg)
          buffer.annotation_style[line - 1] = 8 -- error style number
          buffer:goto_line(line - 1)
        end
      end
    end
  end)

---
-- Container for Python-specific key commands.
-- @class table
-- @name _G.keys.python
_G.keys.python = {
  al = {
    m = { io.open_file,
          (_HOME..'/modules/python/init.lua'):iconv('UTF-8', _CHARSET) },
    },
  [not OSX and 'ci' or '~'] = { sense.complete, sense },
  ch = { sense.show_apidoc, sense },
  ['\n'] = { indent_after_colon }
}

-- Snippets.

if type(_G.snippets) == 'table' then
---
-- Container for Python-specific snippets.
-- @class table
-- @name _G.snippets.python
  _G.snippets.python = {
    p = "print",
  }
end
