-- Chisel description
description = "Count open connections to a given socket. Find maximum number as well as the minimum where a connection error occured."
short_description = "socket connections"
category = "misc"

-- Chisel argument list
args = {
  {
    name = "socket_path",
    description = "socket to monitor",
    argtype = "string",
  },
}

function on_set_arg(name, val)
  socket_path = val

  return true
end

-- Initialization callback
function on_init()
  -- Request the fileds that we need
  fnum = chisel.request_field("evt.num")
  ftype = chisel.request_field("evt.type")
  ftime = chisel.request_field("evt.time.s")
  fpid = chisel.request_field("proc.pid")
  fname = chisel.request_field("proc.name")
  frawres = chisel.request_field("evt.rawres")

  -- set the filter
  chisel.set_filter("((evt.type = accept or evt.type = connect) and evt.dir = < and fd.name contains " .. socket_path ..") or (evt.type = close and evt.dir = > and fd.name contains " .. socket_path .. ")")

  highest_seen = 0
  lowest_seen = 0
  count = 0
  failures = 0
  failures_at = nil

  chisel.set_interval_s(1)

  return true
end

function on_interval()
  print(evt.field(fnum) .. " " .. evt.field(ftime) .. " Estimating connection count at: " .. count - lowest_seen)
  return true
end

-- Event parsing callback
function on_event()
  if evt.field(ftype) ~= "close" then
    if evt.field(frawres) >= 0 then
      count = count + 1
      if count > highest_seen then
        highest_seen = count
      end
      -- print(evt.field(fnum) .. " " .. evt.field(ftime) .. " " .. evt.field(fname) .. "(" .. evt.field(fpid) .. ")" .. " opened")
    else
      failures = failures + 1
      if failures_at == nil or failures_at > count then
        failures_at = count
      end
      -- print(evt.field(fnum) .. " " .. evt.field(ftime) .. " " .. evt.field(fname) .. "(" .. evt.field(fpid) .. ")" .. " failed to open")
    end
  else
    count = count - 1
    if count < lowest_seen then
      lowest_seen = count
    end
    -- print(evt.field(fnum) .. " " .. evt.field(ftime) .. " " .. evt.field(fname) .. "(" .. evt.field(fpid) .. ")" .. " closed")
  end
end

-- End of capture callback
function on_capture_end()
  maximum = highest_seen - lowest_seen
  print("Highest connection count seen: " .. maximum .. " (" .. lowest_seen .. " .. " .. highest_seen .. ")")
  if failures > 0 then
    print("Seen " .. failures .. " failures, lowest at " .. (failures_at - lowest_seen))
  else
    print("No failures seen")
  end
end
