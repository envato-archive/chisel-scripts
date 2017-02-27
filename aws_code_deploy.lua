-- Chisel description
description = "Shows codedeploy stages being run"
short_description = "codedeploy stages"
category = "misc"

-- Chisel argument list
args = { }

-- Initialization callback
function on_init()
  -- Request the fileds that we need
  fnum = chisel.request_field("evt.num")
  ftype = chisel.request_field("evt.type")
  fdir = chisel.request_field("evt.dir")
  ftime = chisel.request_field("evt.time.s")
  fpid = chisel.request_field("proc.pid")
  fpname = chisel.request_field("proc.pname")
  fcmdline = chisel.request_field("proc.cmdline")

  -- set the filter
  chisel.set_filter("evt.type = execve and proc.pname = codedeploy-agen and evt.dir = <")

  return true
end

-- Event parsing callback
function on_event()
  print(evt.field(fnum) .. " " .. evt.field(ftime) .. " started pid(" .. evt.field(fpid) .. "): " .. evt.field(fcmdline))
end

-- End of capture callback
function on_capture_end()
end
