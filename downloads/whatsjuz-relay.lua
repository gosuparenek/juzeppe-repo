-- What'sJuz Relay 1.0.0
-- Standalone CraftOS program, compatible with What'sJuz 1.0.0 (JuzeppeOS 0.9.0).
local CHANNEL, PROTOCOL = 48640, "whatsjuz/1"
local MAX_HOPS, MAX_SEEN = 8, 4096
local RETRY_WINDOW, TOKEN_LIFETIME = 0.75, 15
local args = {...}
local requested = args[1]
local allowed = {
  hello=true, bye=true, invite=true, ringing=true, answer=true,
  alive=true, busy=true, ["end"]=true, audio=true
}
local modem, owned
local recent, tokens, recentCount, tokenCount = {}, {}, 0, 0
local serial, forwarded = 0, 0
local boot = tostring(os.getComputerID())..":"..tostring(os.epoch("utc"))
  ..":"..tostring(math.random(1000000))

local function integer(n, low, high)
  return type(n)=="number" and n%1==0 and n>=low and n<=high
end

local function bounded(value, max)
  return type(value)=="string" and #value>0 and #value<=max
end

local function invoke(name, method, ...)
  return pcall(peripheral.call, name, method, ...)
end

local function close()
  if modem and owned then invoke(modem,"close",CHANNEL) end
  modem, owned = nil, false
end

local function selectModem()
  local names = requested and {requested} or peripheral.getNames()
  table.sort(names)
  for _, name in ipairs(names) do
    if peripheral.hasType(name,"modem") then
      local ok, wireless = invoke(name,"isWireless")
      if ok and wireless then
        if modem==name then
          local checked, isOpen = invoke(name,"isOpen",CHANNEL)
          if checked and isOpen then return end
          -- Re-open the same attachment if it was closed.
        end
        close()
        local checked, isOpen = invoke(name,"isOpen",CHANNEL)
        if checked and (isOpen or invoke(name,"open",CHANNEL)) then
          modem, owned = name, not isOpen
          print("Relaying on "..name.." (channel "..CHANNEL..")")
          return
        end
      end
    end
  end
  if modem then close() end
end

local function prune(now)
  for key, expiry in pairs(recent) do
    if expiry<=now then recent[key]=nil; recentCount=recentCount-1 end
  end
  for key, expiry in pairs(tokens) do
    if expiry<=now then tokens[key]=nil; tokenCount=tokenCount-1 end
  end
end

-- Copy only the fields of the phone protocol. Other modem traffic is ignored.
local function validate(p)
  if type(p)~="table" or p.protocol~=PROTOCOL or not allowed[p.kind]
    or not integer(p.from,0,2147483647) or not integer(p.number,10,99)
    or not bounded(p.session,96) then return nil end

  local q={protocol=PROTOCOL,kind=p.kind,from=p.from,number=p.number,session=p.session}
  if p.kind=="hello" then
    if type(p.label)=="string" then q.label=p.label:sub(1,32) end
  elseif p.kind~="bye" then
    if not integer(p.to,0,2147483647) or not bounded(p.forSession,96)
      or not bounded(p.call,128) then return nil end
    q.to,q.forSession,q.call=p.to,p.forSession,p.call
    if p.kind=="end" and type(p.reason)=="string" then q.reason=p.reason:sub(1,160) end
    if p.kind=="audio" then
      if not bounded(p.data,1024) or not integer(p.samples,1,8192)
        or #p.data~=math.ceil(p.samples/8) or not integer(p.seq,0,2147483647) then return nil end
      q.data,q.samples,q.seq=p.data,p.samples,p.seq
    end
  end

  if p.relayToken~=nil or p.relayHops~=nil then
    if not bounded(p.relayToken,128) or not integer(p.relayHops,0,MAX_HOPS) then return nil end
    q.relayToken,q.relayHops=p.relayToken,p.relayHops
  end
  return q
end

-- Older What'sJuz phones retry invites and heartbeats every second.
-- A short duplicate window lets those retries through while suppressing
-- overlapping relay deliveries. Individual audio chunks have sequence numbers.
local function part(v)
  local s=tostring(v or "")
  return tostring(#s)..":"..s
end

local function fingerprint(p)
  return table.concat({
    part(p.from),part(p.session),part(p.kind),part(p.number),
    part(p.to),part(p.forSession),part(p.call),part(p.seq),part(p.label)
  },"|")
end

local function forward(p)
  local q=validate(p)
  if not q or q.relayHops==0 then return end
  local now=os.clock()
  if recentCount>=MAX_SEEN or tokenCount>=MAX_SEEN then prune(now) end
  if recentCount>=MAX_SEEN or tokenCount>=MAX_SEEN then return end
  local key=fingerprint(q)
  if (recent[key] or 0)>now then return end
  if q.relayToken and (tokens[q.relayToken] or 0)>now then return end

  if not q.relayToken then
    serial=serial+1
    q.relayToken=boot..":"..serial
    q.relayHops=MAX_HOPS
  end
  if not recent[key] then recentCount=recentCount+1 end
  if not tokens[q.relayToken] then tokenCount=tokenCount+1 end
  recent[key]=now+RETRY_WINDOW
  tokens[q.relayToken]=now+TOKEN_LIFETIME
  q.relayHops=q.relayHops-1
  local success=invoke(modem,"transmit",CHANNEL,CHANNEL,q)
  if success then forwarded=forwarded+1 end
end

local timer
local function run()
  print("What'sJuz Relay 1.0.0")
  print("Ctrl+T to stop")
  selectModem()
  if not modem then print("Waiting for a wireless modem...") end
  timer=os.startTimer(1)
  local lastReport=os.clock()
  while true do
    local event, side, channel, reply, message=os.pullEventRaw()
    if event=="terminate" then break
    elseif event=="peripheral_detach" and side==modem then
      close(); selectModem()
    elseif event=="peripheral" then
      if not modem then selectModem() end
    elseif event=="modem_message" and side==modem and channel==CHANNEL and reply==CHANNEL then
      forward(message)
    elseif event=="timer" and side==timer then
      local now=os.clock()
      prune(now)
      if not modem then selectModem() end
      if now-lastReport>=10 then
        print("Forwarded: "..forwarded.." | "..(modem or "no modem"))
        lastReport=now
      end
      timer=os.startTimer(1)
    end
  end
end
local ok,err=pcall(run)
close()
if timer then os.cancelTimer(timer) end
if not ok then printError(err) end
