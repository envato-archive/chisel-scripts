-- Chisel description
description = "Shows requests which load extra modules with a summary at the end"
short_description = "rails dynamic modules"
category = "misc"

args = {}

-- Initialization callback
function on_init()
  -- Request the fileds that we need
  fnum = chisel.request_field("evt.num")
  ftype = chisel.request_field("evt.type")
  ftime = chisel.request_field("evt.time.s")
  fpid = chisel.request_field("proc.pid")
  fname = chisel.request_field("proc.name")
  frawres = chisel.request_field("evt.rawres")
  ffdname = chisel.request_field("fd.name")
  flatency = chisel.request_field("evt.latency")
  fbuffer = chisel.request_field("evt.buffer")

  -- set the filter
  chisel.set_filter("(evt.type = accept and fd.name contains unicorn.sock) or (evt.type = close and evt.dir = >) or (evt.type = open and evt.dir = < and fd.typechar = f) or (evt.type = recvfrom and fd.name contains unicorn.sock and evt.dir = <)")

  in_request = {}
  request_sock = {}
  request_waste = {}
  request_start = {}
  file_requests = {}
  request_buffer = {}

  req_clean = 0
  req_with_search = 0
  total_time_wasted = 0

  return true
end

function string.ends(String,End)
  return End=='' or string.sub(String,-string.len(End))==End
end

-- Event parsing callback
function on_event()
  local pid = evt.field(fpid)
  -- print("type: " .. evt.field(ftype))
  if evt.field(ftype) == "accept" and evt.field(frawres) >= 0 then
    -- print(pid .. " in request")
    in_request[pid] = true
    request_sock[pid] = evt.field(ffdname)
    request_waste[pid] = 0
    request_start[pid] = evt.field(fnum)
    file_requests[pid] = 0
    request_buffer[pid] = ""
  elseif evt.field(ftype) == "close" and evt.field(ffdname) ~= nil and evt.field(ffdname) == request_sock[pid] then
    if file_requests[pid] < 10 then
      req_clean = req_clean + 1
    else
      req_with_search = req_with_search + 1
      print(pid .. " finished request, " .. file_requests[pid] .. " files " .. (request_waste[pid]/1000000) .. "ms \"evt.num >= " .. request_start[pid] .. " and evt.num <= " .. evt.field(fnum) .. " and proc.pid = " .. pid .. "\" req " .. request_buffer[pid])
    end
    in_request[pid] = false
  elseif evt.field(ftype) == "open" then
    if in_request[pid] then
      if evt.field(ffdname):ends(".rb") or evt.field(ffdname):ends(".so") then
        file_requests[pid] = file_requests[pid] + 1
        total_time_wasted = total_time_wasted + evt.field(flatency)
        request_waste[pid] = request_waste[pid] + evt.field(flatency)
        -- print(evt.field(fnum) .. " " .. pid .. " tried to load " .. evt.field(ffdname) .. " latency " .. evt.field(flatency))
      end
    end
  elseif evt.field(ftype) == "recvfrom" then
    if request_buffer[pid] == "" then
      request_buffer[pid] = evt.field(fbuffer)
    end
  end
end

function on_capture_end()
  print("Requests with library search: " .. req_with_search .. " (" .. (req_with_search/(req_with_search+req_clean)) .. ")")
  print("Total time wasted: " .. (total_time_wasted/1000000) .. "ms")
  print("Time wasted per request: " .. (total_time_wasted/1000000/(req_with_search+req_clean)) .. "ms")
  print("Time wasted per request with search: " .. (total_time_wasted/1000000/req_with_search) .. "ms")
end
