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
-- Vars added to buffer:
--  _project_select    = mark this buffer as a valid project file
--               nil = regular file
--              true = project in SELECTION mode
--             false = project in EDIT mode
--
--  _is_working_project = this is the working project (in case more than one is open)
--              true = this is the one
--
--  proj_files[]     = array with the filename in each row (1...) or ''
--  proj_fold_row[]  = array with the row numbers to fold on open
--  proj_grp_path[]  = array with the path of each group or nil
-----------------------------------------------------------------------
local Proj = Proj

function Proj.splitfilename(strfilename)
  -- Returns the Path, Filename, and Extension as 3 values
  return string.match(strfilename, "(.-)([^\\/]-%.?([^%.\\/]*))$")
end

--fill filenames array "buffer.proj_files[]"
function Proj.parse_buffer()
  ui.statusbar_text= 'Parsing project file...'

  buffer.proj_files= {}
  buffer.proj_fold_row = {}
  buffer.proj_grp_path = {}

  --get project file path (default)
  projname= buffer.filename
  if projname ~= nil then
    abspath,fn,ext = Proj.splitfilename(projname)
  else
    --new project, use current dir
    projname= ''
    abspath= lfs.currentdir()
  end
  path = abspath

  --parse project file line by line
  p_buffer= buffer
  for r = 1, p_buffer.line_count do
    fname= ''
    line= p_buffer:get_line(r-1)

    --try option 1)
    local n, fn, opt = string.match(line,'^%s*(.-)%s*::(.*)::(.-)%s*$')
    if n == nil then
      --try option 2)
      fn= string.match(line,'^%s*(.-)%s*$')
    end
    --ui._print('Parser', 'n='..((n==nil) and 'nil' or n)..' f='..((f==nil) and 'nil' or f)..' opt='..((opt==nil) and 'nil' or opt) )

    if fn ~= nil and fn ~= '' then
      p,f,e= Proj.splitfilename(fn)
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
function Proj.check_file()
  if buffer._project_select == nil then
    --row 1
    line= buffer:get_line(0)
    --try option 1)
    local n, fn, opt = string.match(line,'^%s*(.-)%s*::(.*)::(.-)%s*$')
    return (n ~= nil)
  end
  return true
end

--return the working project buffer
function Proj.get_work_buffer()
  -- search for the working project
  for _, buffer in ipairs(_BUFFERS) do
    if buffer._is_working_project then
      --found
      return buffer
    end
  end
  -- not found, choose a new one
  -- 1) choose the project buffer in the LOWER view
  for i= 1, #_VIEWS do
    if _VIEWS[i].buffer._project_select ~= nil then
      --mark this as the working project
      _VIEWS[i].buffer._is_working_project = true
      return _VIEWS[i].buffer
    end
  end
  -- 2) check all buffers, use the first found
  for _, buffer in ipairs(_BUFFERS) do
    if buffer._project_select ~= nil then
      --mark this as the working project
      buffer._is_working_project = true
      return buffer
    end
  end
  --no project file found
  return nil
end

--return the file position (ROW: 1..) in the given buffer file list
function Proj.locate_file(p_buffer, file)
  --check the given buffer has a list of files
  if p_buffer and p_buffer.proj_files ~= nil and file then
    for row= 1, #p_buffer.proj_files do
      if file == p_buffer.proj_files[row] then
        return row
      end
    end
  end
  --not found
  return nil
end

--------------------------------------------------------------
-- show project current row properties
function Proj.show_doc()
  --call_tip_show
  if buffer._project_select ~= nil then
    if buffer:call_tip_active() then events.emit(events.CALL_TIP_CLICK) return end
    if buffer.proj_files ~= nil then
      r= buffer.line_from_position(buffer.current_pos)+1
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