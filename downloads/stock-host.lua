-- Juzeppe Stock Host 1.1.0
-- Run on a computer next to a Create Stock Ticker with a wireless modem.
local REQUEST,REPLY=48530,48531
local PROTOCOL="juzeppe.stock/1"
local MAX_ROWS,CHUNK=4096,48
local id=os.getComputerID()
local args={...}
local wanted=args[1]
local ports={}
local function scan()
  for _,name in ipairs(peripheral.getNames()) do
    if peripheral.hasType(name,"modem") and peripheral.call(name,"isWireless") and ports[name]==nil then
      local already=peripheral.call(name,"isOpen",REQUEST)
      if not already then peripheral.call(name,"open",REQUEST) end
      ports[name]=not already
    end
  end
end
local function findTicker()
  if wanted then
    return peripheral.hasType(wanted,"Create_StockTicker") and wanted or nil
  end
  local names=peripheral.getNames()
  table.sort(names)
  for _,name in ipairs(names) do
    if peripheral.hasType(name,"Create_StockTicker") then return name end
  end
end
local function snapshot()
  local ticker=findTicker()
  if not ticker then return nil,"Connect a Create Stock Ticker" end
  local rows={}
  for _,item in pairs(peripheral.call(ticker,"stock")) do
    if #rows>=MAX_ROWS then return nil,"Stock list too large (max 4096 entries)" end
    rows[#rows+1]={name=item.name,count=item.count}
  end
  return rows
end
local function reply(side,msg,kind,extra)
  extra.protocol=PROTOCOL
  extra.kind=kind
  extra.from=id
  extra.to=msg.from
  extra.token=msg.token
  peripheral.call(side,"transmit",REPLY,REQUEST,extra)
end
local function request(side,msg)
  if type(msg)~="table" or msg.protocol~=PROTOCOL or (msg.kind~="request" and msg.kind~="native") or msg.to~=id or
    type(msg.from)~="number" or msg.from%1~=0 or msg.from<0 or msg.from>2147483647 or
    type(msg.token)~="string" or #msg.token>96 then return end
  if msg.kind=="native" then
    if not juzeppebridge or not juzeppebridge.offerNative then
      reply(side,msg,"error",{error="Install Bridge 0.2.0 and reboot host"})
      return
    end
    local token,err=juzeppebridge.offerNative(msg.from)
    if not token then reply(side,msg,"error",{error=err or "Cannot offer native menu"}); return end
    reply(side,msg,"native",{ticket=token})
    return
  end
  local ok,rows,err=pcall(snapshot)
  if not ok then reply(side,msg,"error",{error=tostring(rows):sub(1,160)}); return end
  if not rows then reply(side,msg,"error",{error=err}); return end
  local total=math.max(1,math.ceil(#rows/CHUNK))
  for index=1,total do
    local batch={}
    for i=(index-1)*CHUNK+1,math.min(index*CHUNK,#rows) do batch[#batch+1]=rows[i] end
    reply(side,msg,"page",{index=index,total=total,rows=batch})
  end
end
local function run()
  scan()
  print("Juzeppe Stock Host")
  print("Server ID: "..id.." (enter this on your Juzeppe computer)")
  print("Ticker: "..(findTicker() or "not connected"))
  if not next(ports) then print("Waiting for wireless modem...") end
  print("Ctrl+T to stop")
  while true do
    local e,a,b,c,d=os.pullEventRaw()
    if e=="terminate" then return
    elseif e=="peripheral" then scan()
    elseif e=="peripheral_detach" then ports[a]=nil
    elseif e=="modem_message" and ports[a]~=nil and b==REQUEST and c==REPLY then
      local ok,err=pcall(request,a,d)
      if not ok then printError(tostring(err)) end
    end
  end
end
local ok,err=pcall(run)
for name,owned in pairs(ports) do if owned then pcall(peripheral.call,name,"close",REQUEST) end end
if not ok then printError(tostring(err)) end
