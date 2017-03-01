-- Chisel description
description = "Calculates percentage of time request spend waiting for external resources or IO"
short_description = "rails non-cpu time"
category = "misc"

args = {}

-- Initialization callback
function on_init()
  -- Request the fileds that we need
  fnum = chisel.request_field("evt.num")
  ftype = chisel.request_field("evt.type")
  frawtime = chisel.request_field("evt.rawtime")
  fpid = chisel.request_field("proc.pid")
  ftid = chisel.request_field("thread.tid")
  frawres = chisel.request_field("evt.rawres")
  ffdname = chisel.request_field("fd.name")
  flatency = chisel.request_field("evt.latency")

  -- set the filter
  chisel.set_filter("(evt.type = accept and fd.name contains unicorn.sock) or (evt.type = close and evt.dir = >) or (evt.type = open and evt.dir = < and fd.typechar = f)or " ..
      -- events which we count as taking non-CPU time
      "evt.type = read or evt.type = write or " ..
      "evt.type = stat or evt.type = fstat or " ..
      "evt.type = recvfrom or evt.type = sendto or evt.type = connect or evt.type = getsockname or evt.type = recvmsg or " ..
      "evt.type = select or evt.type = poll or evt.type = ppoll")

  in_request = {}
  request_sock = {}
  request_non_cpu = {}
  request_start = {}
  file_requests = {}

  total_requests = 0
  total_time = 0
  total_time_non_cpu = 0

  return true
end

function string.ends(String,End)
  return End=='' or string.sub(String,-string.len(End))==End
end

-- Event parsing callback
function on_event()
  local pid = evt.field(fpid)
  local tid = evt.field(ftid)
  -- print("type: " .. evt.field(ftype))
  if evt.field(ftype) == "accept" and evt.field(frawres) >= 0 then
    -- print(pid .. " in request")
    in_request[tid] = true
    request_sock[tid] = evt.field(ffdname)
    request_non_cpu[tid] = 0
    request_start[tid] = evt.field(frawtime)
    file_requests[tid] = 0
    total_requests = total_requests + 1
  elseif evt.field(ftype) == "close" and evt.field(ffdname) ~= nil and evt.field(ffdname) == request_sock[tid] then
    in_request[tid] = false
    local req_time = evt.field(frawtime) - request_start[tid]
    total_time = total_time + req_time
    print(pid .. " finished request " .. req_time/1000000 .. "ms total, " .. request_non_cpu[tid]/1000000 .. "ms waiting, " .. ((1-(request_non_cpu[tid]/req_time))*100) .. "% CPU")
  else
    if in_request[tid] then
      local latency = evt.field(flatency)
      total_time_non_cpu = total_time_non_cpu + latency
      request_non_cpu[tid] = request_non_cpu[tid] + latency
    end
  end
end

function on_capture_end()
  print("Non CPU time per request: " .. (total_time_non_cpu/1000000/total_requests) .. "ms")
  print("Average percent of non CPU: " .. (total_time_non_cpu/total_time*100) .. "%")
end
