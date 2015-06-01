----------------------------------------------------------------------
-------- Project file format --------
-- Valid project lines:
-- 1)  [b] [n] '##' [fn] '##' [opt]
-- 2)  [b] [fn]
-- 3)  [b]
--
-- [b] = optional blanks to visualy group files (folding groups)
-- [n] = optional file/group name or description
--        '['n']', '('n')', '<'n'>' are colo/bold hightlighted
-- [fn] = path/filename to open
--        'p\'    absolute path definition 'P'
--        'p/'    absolute path definition 'P'
--        '.\p\'  relative path definition 'p' (added to last absolute 'P')
--        './p/'  relative path definition 'p' (added to last absolute 'P')
--        'f'     open file 'fn' (absolute) or 'P'+'fn' (relative)
-- [opt] = optional control options
--        '-'     fold this group on project load
--
-- (P= 'first' previous 'P'/'p' or project path)
--  The first project line MUST BE an "option 1)"
----------------------------------------------------------------------
local M = {}

function splitfilename(strfilename)
  -- Returns the Path, Filename, and Extension as 3 values
  return string.match(strfilename, "(.-)([^\\/]-%.?([^%.\\/]*))$")
end

--fill filenames array "buffer.proj_files[]"
function proj_parse_buffer()
  ui.statusbar_text= 'Parsing project file...'
  
  buffer.proj_files= {}
  buffer.proj_fold_row = {}
  buffer.proj_grp_path = {}
  
  --get project file path (default)
  projname= buffer.filename
  if projname ~= nil then
    abspath,fn,ext = splitfilename(projname)
  else
    --new project, use current dir
    projname= ''
    abspath= lfs.currentdir()
  end
  path = abspath
  
  --parse project file line by line
  p_buffer= buffer
  for r = 0, p_buffer.line_count do
    fname= ''
    line= p_buffer:get_line(r)
    
    --try option 1)
    local n, fn, opt = string.match(line,'^%s*(.-)%s*::(.*)::(.-)%s*$')
    if n == nil then
      --try option 2)
      fn= string.match(line,'^%s*(.-)%s*$')
    end
    --ui._print('Parser', 'n='..((n==nil) and 'nil' or n)..' f='..((f==nil) and 'nil' or f)..' opt='..((opt==nil) and 'nil' or opt) )
    
    if fn ~= nil and fn ~= '' then
      p,f,e= splitfilename(fn)
      if f == '' and p ~= '' then
        --only the path is given
        dots, pathrest= string.match(p,'^(%.*[\\/])(.*)$')
        if dots == '.\\' or dots == './' then
          --relative path (only one dot is supported by now)
          path= abspath .. pathrest
        else
          --absolute path
          abspath = p
          path = abspath
        end
        buffer.proj_grp_path[r]= path
        
      elseif f ~= '' then
        if p == '' then
          --relative file, add current path
          fname= path .. fn
        else
          --absolute file
          fname= fn
        end
      end
    end
    --set the filename asigned to each row
    buffer.proj_files[r]= fname
    if opt ~= nil and opt ~= '' then
      --TODO: improve this / add more control flags / goto-line
      if opt == '-' then
        --  '-': fold this group on project load
        buffer.proj_fold_row[ #buffer.proj_fold_row+1 ]= r
      end
    end
  end
  ui.statusbar_text= 'Open project: '.. projname
end

--check if the current file is a valid project
--The first file line MUST BE a valid "option 1)": ...##...##...
function proj_check_file()
  if buffer._is_a_project == nil then
    line= buffer:get_line(0)
    --try option 1)
    local n, fn, opt = string.match(line,'^%s*(.-)%s*::(.+)::(.-)%s*$')
    if n ~= nil then
      return true
    end
  end
  return false
end

--------------------------------------------------------------
-- show project current row properties
function M.proj_show_doc()
  --call_tip_show
  if buffer._is_a_project ~= nil then
    if buffer:call_tip_active() then events.emit(events.CALL_TIP_CLICK) return end
    if buffer.proj_files ~= nil then
      r= buffer.line_from_position(buffer.current_pos)
      info = buffer.proj_files[ r ]
      if info == '' and buffer.proj_grp_path[r] ~= nil then
        info= buffer.proj_grp_path[r]
      end
      if info ~= '' then
        buffer:call_tip_show(buffer.current_pos, info )
      end
    end
  else
    textadept.editing.show_documentation()
  end
end

--------------------------------------------------------------
-- CTRL+H  show current row properties or textadept's doc.
keys.ch = M.proj_show_doc
--------------------------------------------------------------
