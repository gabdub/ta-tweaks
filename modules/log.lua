local log_ev={}

function log_event(event)
  local line= os.date('%c')..": "..event.."\n"
  log_ev[#log_ev+1]= line
end

keys[Util.KEY_CTRL..Util.KEY_SHIFT.."f5"] = function()
  Proj.go_file(nil) --new file
  log_event("DUMP\n")
  for i=1,#log_ev do
    buffer:append_text(log_ev[i])
  end
  buffer:set_save_point()
end

log_event("LOG_START")

function log_event_call(event)
  return function() log_event(event) end
end

events.connect(events.RESET_AFTER, log_event_call("RESET_AFTER"))
events.connect(events.INITIALIZED, log_event_call("INITIALIZED"))
