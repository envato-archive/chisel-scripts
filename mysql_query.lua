description = "Capture mysql queries from network traffic"
args = {}

function on_init()
  fnum = chisel.request_field("evt.num")
  ftype = chisel.request_field("evt.type")
  fbuffer = chisel.request_field("evt.rawarg.data")
  sport = chisel.request_field("fd.sport")

  chisel.set_filter("evt.type = write and fd.sport = 3306")

  return true
end

function on_event()
  -- print("type: " .. evt.field(ftype))
  local buff = evt.field(fbuffer)
  if buff ~= nil then
    local length = ((string.byte(buff, 4)*256 + string.byte(buff, 3))*256 + string.byte(buff, 2))*256 + string.byte(buff, 1)
    -- print("length: " .. length)
    if string.len(buff) < length-4 then
      print("ignored partial")
    else
      if string.byte(buff, 5) == 3 then
        local query=string.sub(buff, 6, length+4)
        local query_singleline=query:gsub("\n", " ")
        print(query_singleline)
      elseif string.byte(buff, 5) == 14 then
        -- ping, ignore
      else
        print("ignored unknown command: " .. string.byte(buff, 5))
      end
    end
  end
end
