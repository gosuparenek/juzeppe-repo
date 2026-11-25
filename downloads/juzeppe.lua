-- JuzeppeOS 0.9.1 Sandstone installer / launcher
local args={...}
local root="/juzeppe"
local version="0.9.1"
local function read(path)
  if not fs.exists(path) or fs.isDir(path) then return nil end
  local f=fs.open(path,"r")
  if not f then return nil end
  local s=f.readAll(); f.close(); return s
end
local function write(path,data)
  local dir=fs.getDir(path)
  if not fs.exists(dir) then fs.makeDir(dir) end
  local f,err=fs.open(path,"w")
  if not f then error(err or "Cannot write "..path,0) end
  f.write(data); f.close()
end
local function install()
  local stage=root.."/.os-stage"
  local backup=root.."/.os-backup"
  local names={"system","system-apps","bin","repo","start.lua"}
  if not fs.exists(root) then fs.makeDir(root) end
  if fs.exists(backup) then
    for _,n in ipairs(names) do
      if fs.exists(backup.."/"..n) and not fs.exists(root.."/"..n) then fs.move(backup.."/"..n,root.."/"..n) end
    end
    fs.delete(backup)
  end
  if fs.exists(stage) then fs.delete(stage) end
  fs.makeDir(stage)
  fs.makeDir(backup)
  local files={    ["bin/jpkg.lua"]=[=[
local args={...}
local pkg=assert(loadfile("/juzeppe/system/packages.lua","t",_ENV))()
local function done(ok,err)
  if not ok then printError(err or "Operation failed"); return false end
  print(type(ok)=="table" and ("Installed "..ok.id.." "..ok.version) or "OK")
  return true
end
if args[1]=="list" then
  for _,m in ipairs(pkg.installed()) do print(m.id.." "..m.version..(m.system and " (system)" or "")) end
elseif args[1]=="search" or args[1]=="refresh" then
  local list,err=pkg.catalog(args[1]=="refresh")
  if not list then printError(err) else for _,m in ipairs(list) do print(m.id.." "..m.version.."  "..m.name) end end
elseif args[1]=="install" and args[2] then
  if args[2]:lower():match("%.juz$") then done(pkg.installFile(shell.resolve(args[2])))
  else
    local list,err=pkg.catalog(true)
    if not list then printError(err); return end
    for _,m in ipairs(list) do if m.id==args[2] then done(pkg.installCatalog(m)); return end end
    printError("Unknown package: "..args[2])
  end
elseif args[1]=="remove" and args[2] then done(pkg.remove(args[2]))
elseif args[1]=="repo" and args[2] then done(pkg.setRepository(args[2]=="local" and "" or args[2]))
elseif args[1]=="repo" then print(pkg.repository()~="" and pkg.repository() or "Bundled catalog")
else
  print("jpkg list | search | refresh")
  print("jpkg install <id|file.juz>")
  print("jpkg remove <id>")
  print("jpkg repo <URL|local>")
end
]=],
    ["bin/juznet.lua"]=[=[
local args={...}
local U=assert(loadfile("/juzeppe/system/util.lua","t",_ENV))()
local API=assert(loadfile("/juzeppe/system/network.lua","t",_ENV))()
local active=_G.__juzeppe_active_network
local function status(s)
  print("Juzeppe network: "..(s.name or ("JUZ-"..os.getComputerID())))
  print("Computer ID: "..os.getComputerID())
  print("Enabled: "..tostring(s.enabled==true))
  print("Server: "..tostring(s.hub==true))
  print("Modems: "..tostring(s.modems or 0))
  print("Mailbox: "..tostring(s.mailbox or 0))
end
if args[1]=="status" then
  if active then status(active:status())
  else
    status(U.json("/juzeppe/network/config.json") or {})
    print("Service is not running.")
  end
  return
end
if active then printError("Juzeppe network is already running in this computer."); return end
if args[1]~="setup" and args[1]~="serve" then
  print("juznet setup    Configure a city server")
  print("juznet serve    Run the city server")
  print("juznet status   Show settings")
  return
end
local n=API.new({notify=function(text) print(text) end})
if args[1]=="setup" then
  local s=n:status()
  write("Computer name ["..s.name.."]: ")
  local name=read()
  if name=="" then name=s.name end
  write("Network key (8+ bytes"..(s.hasKey and ", empty keeps key" or "").."): ")
  local key=read("*")
  local config={name=name,hub=true,enabled=false}
  if key~="" then config.key=key
  elseif not s.hasKey then printError("Set a network key."); return end
  local ok,err=n:configure(config)
  if not ok then printError(err); return end
  print("Saved. Use juznet serve.")
  return
end
if not n:status().hasKey then printError("Run juznet setup first."); return end
local ok,err=n:configure({hub=true,enabled=true})
if not ok then printError(err); return end
_G.__juzeppe_active_network=n
print("City server running. Ctrl+T to stop.")
status(n:status())
print("Shared files: "..n:status().sharedPath)
local timer=os.startTimer(1)
local success,why=pcall(function()
  while true do
    local e,a,b,c=os.pullEventRaw()
    if e=="terminate" then break end
    n:event(e,a,b,c)
    if e=="timer" and a==timer then
      n:tick()
      timer=os.startTimer(1)
    end
  end
end)
pcall(os.cancelTimer,timer)
pcall(function() n:close() end)
_G.__juzeppe_active_network=nil
if not success then printError(why) else print("Server stopped.") end
]=],
    ["repo/index.json"]=[=[
{
  "format": 1,
  "packages": [
    {
      "id": "calculator",
      "name": "Calculator",
      "name_ru": "Калькулятор",
      "description": "Math",
      "description_ru": "Расчёты",
      "version": "1.0.0",
      "api": 1,
      "entry": "main.lua",
      "order": 99,
      "icon": [
        "111111",
        "100001",
        "111111",
        "101101",
        "100001",
        "111111"
      ],
      "short": "Calc",
      "short_ru": "Счёт",
      "author": "Juzeppe",
      "package": "packages/calculator.juz"
    }
  ]
}]=],
    ["repo/packages/calculator.juz"]=[=[
{
  "manifest": {
    "id": "calculator",
    "name": "Calculator",
    "name_ru": "Калькулятор",
    "description": "Math",
    "description_ru": "Расчёты",
    "version": "1.0.0",
    "api": 1,
    "entry": "main.lua",
    "order": 99,
    "icon": [
      "111111",
      "100001",
      "111111",
      "101101",
      "100001",
      "111111"
    ],
    "short": "Calc",
    "short_ru": "Счёт",
    "author": "Juzeppe"
  },
  "files": {
    "main.lua": "local c=...\nlocal P=c.colors\nlocal a,b,result=0,0,\"-\"\nlocal function input(which)\n  c.prompt(which==1 and \"Enter first number\" or \"Enter second number\",tostring(which==1 and a or b),function(value)\n    local n=tonumber(value)\n    if not n then c.status(\"Invalid number\"); return end\n    if which==1 then a=n else b=n end\n  end)\nend\nlocal function calc(op)\n  if op==\"+\" then result=a+b\n  elseif op==\"-\" then result=a-b\n  elseif op==\"*\" then result=a*b\n  elseif op==\"/\" then\n    if b==0 then c.status(\"Division by zero\"); return end\n    result=a/b\n  end\n  c.status(\"\")\nend\nreturn {draw=function(ui)\n  ui.raw(1,1,ui.tr(\"Number 1\")..\": \"..a)\n  ui.button(ui.width-8,1,\" Enter \",function() input(1) end)\n  ui.raw(1,2,ui.tr(\"Number 2\")..\": \"..b)\n  ui.button(ui.width-8,2,\" Enter \",function() input(2) end)\n  for i,op in ipairs({\"+\",\"-\",\"*\",\"/\"}) do\n    local operation=op\n    ui.button(1+(i-1)*5,4,\" \"..op..\" \",function() calc(operation) end)\n  end\n  ui.rect(1,6,ui.width,1,P.tint)\n  ui.raw(1,6,ui.tr(\"Result\")..\": \"..tostring(result),P.ink,P.tint)\nend}\n"
  }
}]=],
    ["start.lua"]=[=[
local k=dofile("/juzeppe/system/kernel.lua")()
local journal=dofile("/juzeppe/system/journal.lua")
local pkg=dofile("/juzeppe/system/packages.lua")
local net=dofile("/juzeppe/system/network.lua")
if _G.__juzeppe_active_network then error("Juzeppe network already running",0) end
local desktop,latest,active=nil,nil,nil
local serial=0
local network=net.new({notify=function(msg) if desktop then k.send(desktop,"system_notice",msg) end end})
k.network=network
local stock=dofile("/juzeppe/system/stock-remote.lua")()
k.stock=stock
local phone=dofile("/juzeppe/system/phone.lua")(function(msg)
  if desktop then k.send(desktop,"system_notice",msg) end
end)
k.phone=phone
k.latest=function() return latest end
function k.install(item)
  if active then return nil,"Another installation is running" end
  serial=serial+1
  local op={id=serial,app=item.id,state="queued"}
  latest,active=op,op
  local pid=k.spawn("installer",function()
    os.pullEventRaw("install")
    op.state="downloading"
    local ok,result,err=pcall(pkg.installCatalog,item)
    op.state=ok and result and "installed" or "failed"
    op.error=op.state=="failed" and tostring(ok and err or result) or nil
    journal("packages",op.app,op.error or op.state)
  end,function(reason)
    if reason=="crash" then op.state="failed"; op.error="Installer stopped" end
    active=nil
    if desktop then k.send(desktop,"package_result",op.id) end
  end)
  k.send(pid,"install")
  return op.id
end
local host=term.current()
local original=dofile("/juzeppe/system/palette.lua").capture(host)
local function recovery(reason)
  term.redirect(host)
  host.setBackgroundColor(colors.black); host.setTextColor(colors.white)
  host.clear(); host.setCursorPos(1,1)
  print("Desktop "..reason..". Services are running.")
  print("R: start desktop   Q: exit JuzeppeOS")
end
local function launch()
  local pid=k.spawn("desktop",function() return assert(loadfile("/juzeppe/system/core.lua","t",_ENV))(k) end,function(reason)
    desktop=nil
    if reason=="exit" then k.running=false
    elseif reason=="restart" then os.queueEvent("juzeppe_start_desktop")
    else recovery(reason) end
  end)
  if k.processes[pid] then desktop=pid end
end
local ok,err=xpcall(function()
  journal("kernel","boot","0.9.1")
  _G.__juzeppe_active_network=network
  k.spawn("network",function()
    network:start()
    local timer=os.startTimer(1)
    while true do
      local e=table.pack(os.pullEventRaw())
      if e[1]=="timer" and e[2]==timer then network:tick(); timer=os.startTimer(1)
      else network:event(table.unpack(e,1,e.n)) end
    end
  end,function() network:close() end)
  k.spawn("stock-client",function()
    while true do stock.event(os.pullEventRaw()) end
  end,function() stock.close() end)
  k.spawn("phone",phone.run,phone.close)
  launch()
  while k.running do
    local e=table.pack(os.pullEventRaw())
    if not desktop and (e[1]=="juzeppe_start_desktop" or (e[1]=="key" and e[2]==keys.r)) then launch()
    elseif not desktop and e[1]=="key" and e[2]==keys.q then k.running=false
    else k.dispatch(table.unpack(e,1,e.n)) end
  end
end,function(e) journal("kernel","boot",e,coroutine.running()); return e end)
for pid in pairs(k.processes) do k.stop(pid,"shutdown") end
_G.__juzeppe_active_network=nil
term.redirect(host)
dofile("/juzeppe/system/palette.lua").restore(host,original)
if not ok then error(err,0) end
print("JuzeppeOS closed.")
]=],
    ["system-apps/about/main.lua"]=[=[
return {refresh=false,draw=function(c)
  local P=c.colors
  c.text(2,1,"J U Z E P P E  /  OS",P.accent)
  c.text(2,3,"Sandstone Edition")
  c.text(2,4,"Version 0.9.1 / API 1")
  c.text(2,5,"CraftOS / CC: Tweaked")
  c.raw(2,6,c.tr("Computer").." #"..os.getComputerID())
  c.status("Designed for Juzeppe")
end}

]=],
    ["system-apps/about/manifest.json"]=[=[
{
  "id": "about",
  "name": "About",
  "name_ru": "Об ОС",
  "description": "System",
  "description_ru": "Система",
  "version": "0.9.1",
  "api": 1,
  "entry": "main.lua",
  "order": 8,
  "icon": [
    "011110",
    "100001",
    "101101",
    "100001",
    "101101",
    "011110"
  ],
  "short": "About",
  "short_ru": "Об ОС",
  "author": "Juzeppe"
}
]=],
    ["system-apps/clock/main.lua"]=[=[
local ctx=...
local P=ctx.colors
local digits={
  ["0"]={"111","101","101","101","111"}, ["1"]={"010","110","010","010","111"},
  ["2"]={"111","001","111","100","111"}, ["3"]={"111","001","111","001","111"},
  ["4"]={"101","101","111","001","001"}, ["5"]={"111","100","111","001","111"},
  ["6"]={"111","100","111","101","111"}, ["7"]={"111","001","010","010","010"},
  ["8"]={"111","101","111","101","111"}, ["9"]={"111","101","111","001","111"},
  [":"]={"0","1","0","1","0"}
}
return {refresh=true,draw=function(c)
  local mins=math.floor((os.time()%24)*60)
  local time=string.format("%02d:%02d",math.floor(mins/60),mins%60)
  local scale=c.width>=35 and 2 or 1
  local x=math.floor((c.width-17*scale)/2)+1
  local y=math.max(1,math.floor((c.height-5)/2))
  for i=1,#time do
    local rows=digits[time:sub(i,i)]
    for py,row in ipairs(rows) do
      for px=1,#row do
        if row:sub(px,px)=="1" then c.rect(x+(px-1)*scale,y+py-1,scale,1,P.accent) end
      end
    end
    x=x+(#rows[1]+1)*scale
  end
  c.status(c.tr("WORLD TIME").." / "..c.tr("DAY").." "..os.day())
end}
]=],
    ["system-apps/clock/manifest.json"]=[=[
{
  "id": "clock",
  "name": "Clock",
  "name_ru": "Часы",
  "description": "Time",
  "description_ru": "Время",
  "version": "0.6.1",
  "api": 1,
  "entry": "main.lua",
  "order": 6,
  "icon": [
    "011110",
    "100001",
    "101001",
    "101101",
    "100001",
    "011110"
  ],
  "short": "Clock",
  "short_ru": "Часы",
  "author": "Juzeppe"
}]=],
    ["system-apps/files/main.lua"]=[=[
local ctx=...
local P=ctx.colors
local desktop=assert(loadfile("/juzeppe/system/desktop.lua","t",_ENV))()
local ops=assert(loadfile("/juzeppe/system/fileops.lua","t",_ENV))()
local cb=ctx.clipboard
local path=ops.path(ctx.args.path or ctx.desktopPath or "/")
local back,forward={},{}
local scroll,query,sortMode,descending=0,"","name",false
local selected,anchor={},nil
local rows={}
local trashMode=ctx.args.trash==true
local notice,lastClick,lastTime="",nil,0
local listTop=5
local function fold(value)
  return (value:lower():gsub("[\208\209][\128-\191]",function(ch)
    local cp=utf8.codepoint(ch)
    if cp>=1040 and cp<=1071 then return utf8.char(cp+32) end
    if cp==1025 then return utf8.char(1105) end
    return ch
  end))
end
local function reset()
  scroll=0; selected={}; anchor=nil; lastClick=nil; notice=""
end
local function change(where,record)
  where=ops.path(where)
  if not fs.exists(where) or not fs.isDir(where) then notice="Folder not found"; return end
  if record and (where~=path or trashMode) then back[#back+1]=path; forward={} end
  path=where; trashMode=false; query=""; reset()
end
local function goBack()
  if trashMode then trashMode=false; reset(); return end
  local where=table.remove(back)
  if where then forward[#forward+1]=path; change(where,false) end
end
local function goForward()
  local where=table.remove(forward)
  if where then back[#back+1]=path; change(where,false) end
end
local function create(c,isDir)
  if trashMode then return end
  c.prompt(isDir and "Folder name" or "File name",isDir and c.tr("New folder") or "untitled.txt",function(name)
    local result,err=desktop.make(path,name,isDir)
    notice=result and (isDir and "Folder created" or "File created") or err
    if result then selected={[ops.path(result)]=true}; c.refreshDesktop() end
    c.invalidate()
  end)
end
local function address(c)
  c.prompt("Address",path,function(value)
    local p=value:sub(1,1)=="/" and value or fs.combine(path,value)
    change(p,true)
  end)
end
local function find(c)
  c.prompt("Search this folder",query,function(value) query=fold(value); reset() end)
end
local function selectedRows()
  local result={}
  for _,item in ipairs(rows) do if selected[item.key] then result[#result+1]=item end end
  return result
end
local function one()
  local list=selectedRows()
  return #list==1 and list[1] or nil
end
local function open(c,item)
  if not item then return end
  if trashMode then return end
  if item.dir then change(item.path,true)
  elseif item.name:lower():match("%.juz$") then
    c.confirm("Install this package?",function()
      local m,err=c.package.installFile(item.path)
      notice=m and (c.tr("Installed").." "..m.name) or err
      c.refreshApps()
    end)
  elseif fs.isReadOnly(item.path) then notice="Read-only file"
  else c.launch("/rom/programs/edit.lua",item.path) end
end
local function clipboard(mode)
  if trashMode then return end
  local paths={}
  for _,item in ipairs(selectedRows()) do paths[#paths+1]=item.path end
  local n,err=cb:setFiles(paths,mode)
  notice=n and (tostring(n).." "..ctx.tr(mode=="copy" and "Copied" or "Cut")) or err
end
local function paste(c)
  if trashMode then return end
  local result,errors=cb:paste(path)
  selected={}
  for _,p in ipairs(result) do selected[p]=true end
  notice=#result>0 and (#result.." "..c.tr("Pasted")) or (errors[1] or "Clipboard has no files")
  if #result>0 and #errors>0 then notice=notice.." / "..#errors.." "..c.tr("Failed") end
  c.refreshDesktop()
end
local function rename(c)
  local item=one()
  if not item or trashMode then notice="Select one item"; return end
  c.prompt("New name",item.name,function(name)
    local result,err=ops.rename(item.path,name)
    notice=result and "Renamed" or err
    if result then selected={[result]=true}; c.refreshDesktop() end
  end)
end
local function trash(c)
  local list=selectedRows()
  if #list==0 then notice="Select files first"; return end
  c.confirm(trashMode and "Delete permanently?" or "Move to Trash?",function()
    local success,errors=0,{}
    for _,item in ipairs(list) do
      local ok,err
      if trashMode then ok,err=ops.destroy(item.id) else ok,err=ops.trash(item.path) end
      if ok then selected[item.key]=nil; success=success+1 else errors[#errors+1]=err end
    end
    notice=success>0 and (success.." "..c.tr(trashMode and "Deleted" or "Moved to Trash")) or errors[1]
    if success>0 and #errors>0 then notice=notice.." / "..#errors.." "..c.tr("Failed") end
    c.refreshDesktop()
  end)
end
local function restore(c)
  local list=selectedRows()
  if #list==0 then notice="Select files first"; return end
  local success,errors=0,{}
  for _,item in ipairs(list) do
    local result,err=ops.restore(item.id)
    if result then selected[item.key]=nil; success=success+1 else errors[#errors+1]=err end
  end
  notice=success>0 and (success.." "..c.tr("Restored")) or errors[1]
  c.refreshDesktop()
end
local function menu(c,x,y,item)
  local entries={}
  local function add(label,action) entries[#entries+1]={label=label,action=action} end
  if trashMode then
    add("Restore",function() restore(c) end)
    add("Delete permanently",function() trash(c) end)
  else
    if item then
      add("Open",function() open(c,item) end)
      if not item.dir then
        add("Send over network",function() c.openApp("network",{file=item.path}) end)
      end
      add("Copy",function() clipboard("copy") end)
      add("Cut",function() clipboard("cut") end)
      add("Rename",function() rename(c) end)
      add("Move to Trash",function() trash(c) end)
    end
    add("Paste",function() paste(c) end)
    add("New folder",function() create(c,true) end)
    add("New file",function() create(c,false) end)
    add("Sort by name",function() descending=sortMode=="name" and not descending or false; sortMode="name" end)
    add("Sort by size",function() descending=sortMode=="size" and not descending or false; sortMode="size" end)
    add("Sort by type",function() descending=sortMode=="type" and not descending or false; sortMode="type" end)
  end
  c.menu(entries,x,y)
end
local function refreshRows()
  rows={}
  if trashMode then
    for _,item in ipairs(ops.trashList()) do
      item.key=item.id
      rows[#rows+1]=item
    end
    return
  end
  if not fs.exists(path) or not fs.isDir(path) then path=ctx.desktopPath or "/"; reset() end
  for _,name in ipairs(fs.list(path)) do
    if query=="" or fold(name):find(query,1,true) then
      local p=ops.path(fs.combine(path,name))
      local dir=fs.isDir(p)
      local ext=dir and "" or (name:match("%.([^%.]+)$") or ""):lower()
      rows[#rows+1]={name=name,path=p,key=p,dir=dir,size=dir and 0 or fs.getSize(p),ext=ext}
    end
  end
  table.sort(rows,function(a,b)
    if a.dir~=b.dir then return a.dir end
    local av,bv
    if sortMode=="size" then av,bv=a.size,b.size
    elseif sortMode=="type" then av,bv=a.ext,b.ext
    else av,bv=a.name:lower(),b.name:lower() end
    if av==bv then av,bv=a.name:lower(),b.name:lower() end
    if av==bv then av,bv=a.name,b.name end
    if descending then return av>bv else return av<bv end
  end)
  local known={}
  for _,item in ipairs(rows) do known[item.key]=true end
  for key in pairs(selected) do if not known[key] then selected[key]=nil end end
end
local function sizeLabel(n)
  if n>=1024*1024 then return string.format("%.1fM",n/1048576)
  elseif n>=1024 then return string.format("%.1fK",n/1024)
  else return tostring(n).."B" end
end
local function draw(c)
  refreshRows()
  c.button(1,1," < ",goBack,P.tint,P.ink)
  c.button(4,1," > ",goForward,P.tint,P.ink)
  c.button(7,1," ^ ",function() if trashMode then goBack() else change(fs.getDir(path),true) end end,P.tint,P.ink)
  c.button(10,1," Desk ",function() change(c.desktopPath,true) end,P.tint,P.ink)
  c.button(16,1," Bin ",function() trashMode=true; query=""; reset() end,P.tint,P.ink)
  c.rect(1,2,c.width,1,P.tint)
  local addressText=trashMode and c.tr("Trash") or path
  if query~="" then addressText=addressText.." ["..query.."]" end
  c.raw(1,2,addressText,P.ink,P.tint)
  c.hit(1,2,math.max(1,c.width-7),1,function() address(c) end)
  if not trashMode then c.button(c.width-6,2," Find ",function() find(c) end,P.deep,P.paper) end
  if trashMode then
    c.button(1,3," Restore ",function() restore(c) end,P.accent,P.paper)
    c.button(11,3," Delete ",function() trash(c) end,P.danger,P.paper)
  elseif c.width>=32 then
    c.button(1,3," New ",function() menu(c,1,3) end,P.accent,P.paper)
    c.button(7,3," Copy ",function() clipboard("copy") end,P.tint,P.ink)
    c.button(14,3," Cut ",function() clipboard("cut") end,P.tint,P.ink)
    c.button(20,3," Paste ",function() paste(c) end,P.tint,P.ink)
    c.button(28,3," ... ",function() menu(c,28,3,one()) end,P.deep,P.paper)
  else
    c.button(1,3," + ",function() create(c,true) end,P.accent,P.paper)
    c.button(5,3," C ",function() clipboard("copy") end,P.tint,P.ink)
    c.button(9,3," X ",function() clipboard("cut") end,P.tint,P.ink)
    c.button(13,3," V ",function() paste(c) end,P.tint,P.ink)
    c.button(17,3," ... ",function() menu(c,17,3,one()) end,P.deep,P.paper)
  end
  c.rect(1,4,c.width,1,P.tint)
  c.text(2,4,"NAME",P.muted,P.tint)
  local wide=c.width>=31
  if wide then c.text(c.width-7,4,"SIZE",P.muted,P.tint) end
  local count=math.max(1,c.height-listTop+1)
  scroll=math.max(0,math.min(scroll,math.max(0,#rows-count)))
  for i=1,count do
    local item=rows[i+scroll]
    if item then
      local y=i+listTop-1
      local bg=selected[item.key] and P.accent or (i%2==0 and P.tint or P.paper)
      local fg=selected[item.key] and P.paper or P.ink
      c.rect(1,y,c.width,1,bg)
      local label=(item.dir and "> " or "- ")..item.name
      c.raw(2,y,label,fg,bg)
      if wide then
        c.rect(c.width-8,y,9,1,bg)
        local size=item.dir and c.tr("Folder") or sizeLabel(item.size or fs.getSize(item.data))
        c.raw(c.width-7,y,size,fg,bg)
      end
    end
  end
  local n=#selectedRows()
  c.status(notice~="" and notice or (#rows.." "..c.tr("items").." / "..n.." "..c.tr("selected")))
end
local function select(index,mods)
  local item=rows[index]
  if not item then selected={}; anchor=nil; return nil end
  if mods.shift and anchor then
    if not mods.ctrl then selected={} end
    for i=math.min(anchor,index),math.max(anchor,index) do if rows[i] then selected[rows[i].key]=true end end
  elseif mods.ctrl then
    selected[item.key]=not selected[item.key] or nil
    anchor=index
  else selected={[item.key]=true}; anchor=index end
  notice=""
  return item
end
return {draw=draw,
  dropTarget=function()
    if not trashMode then return path end
  end,
  onFilesReceived=function(c,folder,names,errors)
    if trashMode or ops.path(folder)~=path then return end
    if #names>0 then
      query=""
      selected={}
      for _,name in ipairs(names) do selected[ops.path(fs.combine(path,name))]=true end
      refreshRows()
      local count=math.max(1,c.height-listTop+1)
      for i,item in ipairs(rows) do
        if selected[item.key] then
          anchor=i
          if i>scroll+count then scroll=i-count elseif i<=scroll then scroll=i-1 end
        end
      end
      notice=#names.." "..c.tr("Received")
      if #errors>0 then notice=notice.." / "..#errors.." "..c.tr("Failed") end
    else notice=errors[1] or "Transfer failed" end
    c.invalidate()
  end,
  events={mouse_scroll=true,mouse_click=true,key=true,key_up=true,term_resize=true},event=function(c,e,a,b,y)
  local mods=c.modifiers()
  if e=="mouse_scroll" then scroll=math.max(0,scroll+a)
  elseif e=="mouse_click" and y and y>=listTop then
    local index=scroll+y-listTop+1
    local item=rows[index]
    if a==2 then
      if item and not selected[item.key] then select(index,{}) end
      menu(c,b,y,item)
    elseif a==1 then
      item=select(index,mods)
      if item and not mods.ctrl and not mods.shift then
        local now=os.clock()
        if lastClick==item.key and now-lastTime<.55 then lastClick=nil; open(c,item)
        else lastClick=item.key; lastTime=now end
      end
    end
  elseif e=="key" then
    if mods.ctrl and a==keys.c then clipboard("copy")
    elseif mods.ctrl and a==keys.x then clipboard("cut")
    elseif mods.ctrl and a==keys.v then paste(c)
    elseif mods.ctrl and a==keys.a then
      selected={}; for _,item in ipairs(rows) do selected[item.key]=true end
    elseif mods.ctrl and a==keys.l then address(c)
    elseif mods.ctrl and a==keys.f then find(c)
    elseif mods.ctrl and mods.shift and a==keys.n then create(c,true)
    elseif a==keys.delete then trash(c)
    elseif a==keys.f2 then rename(c)
    elseif a==keys.enter then open(c,one())
    elseif a==keys.backspace then if trashMode then goBack() else change(fs.getDir(path),true) end
    elseif a==keys.up or a==keys.down then
      local delta=a==keys.up and -1 or 1
      local index=math.max(1,math.min(#rows,(anchor or 0)+delta))
      select(index,mods)
      local count=math.max(1,c.height-listTop+1)
      if index<=scroll then scroll=index-1 elseif index>scroll+count then scroll=index-count end
    end
  end
end}
]=],
    ["system-apps/files/manifest.json"]=[=[
{
  "id": "files",
  "name": "Files",
  "name_ru": "Файлы",
  "description": "Browse",
  "description_ru": "Обзор",
  "version": "0.6.1",
  "api": 1,
  "entry": "main.lua",
  "order": 1,
  "icon": [
    "011000",
    "111100",
    "111111",
    "100001",
    "100001",
    "111111"
  ],
  "short": "Files",
  "short_ru": "Файлы",
  "author": "Juzeppe"
}]=],
    ["system-apps/network/main.lua"]=[=[
local c=...
local P=c.colors
local net=c.network
local tab=net:status().enabled and "peers" or "setup"
local peer,transferKey,shareName,selectedText
local pendingFile=c.args.file
local notice=pendingFile and "Select a computer to send file" or ""
local scroll=0
local function setTab(name)
  tab=name; scroll=0; notice=""
end
local function report(ok,err,success)
  notice=ok and (success or "Done") or tostring(err or "Network operation failed")
  c.invalidate()
end
local function withPeer(action)
  if peer then action(peer); return end
  c.prompt("Computer ID","",function(value)
    local id=tonumber(value)
    if not id or id<0 or id%1~=0 then notice="Invalid computer ID"; return end
    peer=id
    action(id)
  end)
end
local function setPeer()
  c.prompt("Computer ID",peer and tostring(peer) or "",function(value)
    local id=tonumber(value)
    if id and id>=0 and id%1==0 then peer=id; scroll=0
    else notice="Invalid computer ID" end
  end)
end
local function sendMessage()
  withPeer(function(id)
    c.prompt("Message","",function(text)
      local ok,err=net:sendMessage(id,text)
      report(ok,err,"Message sent")
      if ok then setTab("chat") end
    end)
  end)
end
local function sendFile()
  withPeer(function(id)
    local candidate=pendingFile
    if not candidate and c.clipboard:hasFiles() and #c.clipboard.paths==1 then candidate=c.clipboard.paths[1] end
    c.prompt("File path",candidate or "",function(path)
      local key,err=net:offerFile(id,path)
      if key then transferKey=key; pendingFile=nil; setTab("files") end
      report(key,err,"Offer sent")
    end)
  end)
end
local function share()
  withPeer(function(id)
    local ok,err=net:requestShared(id)
    if ok then setTab("shares") end
    report(ok,err,"Request sent")
  end)
end
local function peerName(id)
  if id then
    for _,p in ipairs(net:devices()) do if p.id==id then return p.name.." #"..id end end
    return "#"..id
  end
  return c.tr("No computer selected")
end
local function tabBar(ui)
  local broad=ui.width>=29
  local buttons=broad and {
    {1," Peers ","peers"},{9," Chat ","chat"},{16," Files ","files"},{24," Setup ","setup"}
  } or {
    {1," Net ","peers"},{7," C ","chat"},{11," F ","files"},{15," S ","setup"}
  }
  for _,b in ipairs(buttons) do
    ui.button(b[1],1,b[2],function() setTab(b[3]) end,tab==b[3] and P.accent or P.tint,tab==b[3] and P.paper or P.ink)
  end
end
local function row(ui,y,text,isSelected,action)
  local bg=isSelected and P.accent or (y%2==0 and P.tint or P.paper)
  local fg=isSelected and P.paper or P.ink
  ui.rect(1,y,ui.width,1,bg)
  ui.raw(1,y,text,fg,bg)
  if action then ui.hit(1,y,ui.width,1,action) end
end
local function peers(ui)
  local s=net:status()
  ui.raw(1,2,s.name.." #"..s.id.."  "..s.modems.." "..ui.tr("modems"),P.muted)
  local list=net:devices()
  local count=math.max(1,ui.height-4)
  scroll=math.max(0,math.min(scroll,math.max(0,#list-count)))
  for i=1,count do
    local p=list[i+scroll]
    if p then
      local label=(p.online and "+ " or "- ")..p.name.." #"..p.id..(p.hub and " [H]" or "")
      row(ui,i+2,label,peer==p.id,function() peer=p.id end)
    end
  end
  if #list==0 then ui.text(1,3,s.enabled and "No computers discovered" or "Network disabled",P.muted) end
  ui.raw(1,ui.height-1,peerName(peer),P.muted)
  ui.button(1,ui.height," ID ",setPeer,P.tint,P.ink)
  ui.button(6,ui.height," Msg ",sendMessage)
  ui.button(12,ui.height," File ",sendFile)
  ui.button(19,ui.height," Share ",share,P.deep,P.paper)
end
local function splitText(text,max)
  local ok,pos=pcall(utf8.offset,text,max+1)
  if ok and not pos then return text,"" end
  if ok and pos then return text:sub(1,pos-1),text:sub(pos) end
  return text:sub(1,max),text:sub(max+1)
end
local function copyMessage()
  if selectedText then c.clipboard:setText(selectedText); notice="Copied"; c.invalidate()
  else notice="Select a message" end
end
local function chat(ui)
  ui.raw(1,2,peerName(peer),P.muted)
  local messages=peer and net:messages(peer) or {}
  local lines={}
  for _,m in ipairs(messages) do
    local prefix=m.direction=="out" and c.tr("Me") or m.name
    local text=prefix..": "..m.text
    -- Keep messages readable on narrow terminal windows.
    for piece in (text.."\n"):gmatch("(.-)\n") do
      repeat
        local first,rest=splitText(piece,ui.width)
        lines[#lines+1]={value=first,out=m.direction=="out",text=m.text}
        piece=rest
      until piece==""
    end
    if m.direction=="out" then lines[#lines+1]={value="  ["..c.tr(m.state).."]",muted=true} end
  end
  local count=math.max(1,ui.height-3)
  scroll=math.max(0,math.min(scroll,math.max(0,#lines-count)))
  local first=math.max(1,#lines-count+1-scroll)
  for n=1,count do
    local entry=lines[first+n-1]
    if entry then
      local selected=entry.text and entry.text==selectedText
      if selected then ui.rect(1,2+n,ui.width,1,P.tint) end
      ui.raw(1,2+n,entry.value,entry.muted and P.muted or (entry.out and P.deep or P.ink),selected and P.tint or P.paper)
      if entry.text then ui.hit(1,2+n,ui.width,1,function() selectedText=entry.text end) end
    end
  end
  if #messages==0 then ui.text(1,3,"No messages",P.muted) end
  ui.button(1,ui.height," Write ",sendMessage)
  ui.button(10,ui.height," ID ",setPeer,P.tint,P.ink)
  ui.button(15,ui.height," Copy ",copyMessage,P.tint,P.ink)
end
local function files(ui)
  local list=net:transfersList()
  local count=math.max(1,ui.height-4)
  scroll=math.max(0,math.min(scroll,math.max(0,#list-count)))
  local selected
  for _,t in ipairs(list) do if t.key==transferKey then selected=t end end
  if not selected and list[1] then transferKey=list[1].key; selected=list[1] end
  ui.text(1,2,"TRANSFERS",P.muted)
  for i=1,count do
    local t=list[i+scroll]
    if t then
      local mark=t.direction=="in" and "< " or "> "
      row(ui,i+2,mark..t.name,transferKey==t.key,function() transferKey=t.key end)
    end
  end
  if not selected then ui.text(1,3,"No transfers",P.muted) end
  if selected then
    local progress=selected.size==0 and (selected.state=="Received" and 100 or 0) or math.floor(selected.bytes*100/selected.size)
    ui.raw(1,ui.height-1,c.tr(selected.state).." "..progress.."% #"..selected.peer,P.muted)
    if selected.direction=="in" and selected.state=="Pending" then
      ui.button(1,ui.height," Accept ",function() report(net:accept(selected.key)) end)
      ui.button(11,ui.height," Decline ",function() report(net:decline(selected.key)) end,P.danger,P.paper)
    elseif selected.state=="Sending" or selected.state=="Receiving" or selected.state=="Offered" then
      ui.button(1,ui.height," Cancel ",function() report(net:cancel(selected.key)) end,P.danger,P.paper)
      ui.button(11,ui.height," File ",sendFile)
    else
      ui.button(1,ui.height," Open ",function()
        local path=net:status().receivedPath
        if not fs.exists(path) then fs.makeDir(path) end
        ui.openApp("files",{path=path})
      end,P.tint,P.ink)
      ui.button(9,ui.height," File ",sendFile)
    end
  else ui.button(1,ui.height," File ",sendFile) end
end
local function shares(ui)
  local items=peer and net:sharedFiles(peer) or {}
  ui.raw(1,2,peerName(peer),P.muted)
  local count=math.max(1,ui.height-3)
  scroll=math.max(0,math.min(scroll,math.max(0,#items-count)))
  for i=1,count do
    local item=items[i+scroll]
    if item then row(ui,i+2,item.name.."  "..item.size.."B",shareName==item.name,function() shareName=item.name end) end
  end
  if #items==0 then ui.text(1,3,"No shared files",P.muted) end
  ui.button(1,ui.height," Get ",function()
    if peer and shareName then report(net:requestSharedFile(peer,shareName))
    else notice="Select files first" end
  end)
  ui.button(8,ui.height," Refresh ",share,P.tint,P.ink)
end
local function setup(ui)
  local s=net:status()
  ui.button(1,2," Name ",function()
    ui.prompt("Computer name",s.name,function(v) report(net:configure({name=v})) end)
  end,P.tint,P.ink)
  ui.raw(9,2,s.name.." #"..s.id)
  ui.button(1,3," Key ",function()
    ui.prompt("Network key (8+ bytes)","",function(v) report(net:configure({key=v})) end,true)
  end,P.tint,P.ink)
  ui.text(9,3,s.hasKey and "Key configured" or "No network key",P.muted)
  ui.button(1,4,s.enabled and " Disable " or " Enable ",function() report(net:configure({enabled=not s.enabled})) end,P.accent,P.paper)
  ui.raw(12,4,s.modems.." "..ui.tr("modems"),P.muted)
  ui.button(1,5," Hub ",function() report(net:configure({hub=not s.hub})) end,P.tint,P.ink)
  ui.text(9,5,s.hub and "Server mode on" or "Server mode off",P.muted)
  ui.button(1,6," Server ID ",function()
    ui.prompt("Server ID (blank = direct)",s.hubID>=0 and tostring(s.hubID) or "",function(v)
      local id=v=="" and -1 or tonumber(v)
      if not id then notice="Invalid computer ID"; return end
      report(net:configure({hubID=id}))
    end)
  end,P.tint,P.ink)
  ui.raw(13,6,s.hubID>=0 and "#"..s.hubID or c.tr("Direct"),P.muted)
  ui.button(1,7," Shared ",function()
    local path=net:status().sharedPath
    if not fs.exists(path) then fs.makeDir(path) end
    ui.openApp("files",{path=path})
  end,P.tint,P.ink)
  if ui.width>=31 then ui.raw(11,7,c.tr("Mailbox")..": "..s.mailbox,P.muted) end
end
return {draw=function(ui)
  tabBar(ui)
  if tab=="peers" then peers(ui)
  elseif tab=="chat" then chat(ui)
  elseif tab=="files" then files(ui)
  elseif tab=="shares" then shares(ui)
  else setup(ui) end
  ui.status(notice)
end,events={mouse_scroll=true,key=true},event=function(ui,e,a)
  if e=="mouse_scroll" then scroll=math.max(0,scroll+(tab=="chat" and -a or a))
  elseif e=="key" and a==keys.escape then setTab("peers")
  elseif e=="key" and tab=="chat" and a==keys.c and ui.modifiers().ctrl then copyMessage() end
end}
]=],
    ["system-apps/network/manifest.json"]=[=[
{
  "id": "network",
  "name": "Network",
  "name_ru": "Сеть",
  "description": "Local network and city server",
  "description_ru": "Общение и передача файлов",
  "version": "0.6.1",
  "api": 1,
  "entry": "main.lua",
  "order": 7,
  "icon": [
    "011110",
    "010010",
    "111111",
    "001100",
    "111111",
    "100001"
  ],
  "short": "Net",
  "short_ru": "Сеть",
  "author": "Juzeppe"
}]=],
    ["system-apps/notes/main.lua"]=[=[
local ctx=...
local P=ctx.colors
local file=ctx.dataPath.."/notes.txt"
if not fs.exists(file) and fs.exists("/.juzeppe/notes.txt") then fs.copy("/.juzeppe/notes.txt",file) end
return {draw=function(c)
  c.text(2,1,"Personal notebook")
  c.button(2,2," Edit note ",function() c.launch("/rom/programs/edit.lua",file) end)
  local text=c.read(file)
  if not text or text=="" then c.text(2,4,"Your notebook is empty.")
  else
    local y=4
    for row in (text.."\n"):gmatch("(.-)\n") do
      repeat
        if y>c.height then break end
        c.raw(2,y,row:sub(1,c.width-3))
        row=row:sub(c.width-2)
        y=y+1
      until row==""
      if y>c.height then break end
    end
  end
  c.status("Saved locally")
end}
]=],
    ["system-apps/notes/manifest.json"]=[=[
{
  "id": "notes",
  "name": "Notes",
  "name_ru": "Заметки",
  "description": "Notebook",
  "description_ru": "Блокнот",
  "version": "0.6.1",
  "api": 1,
  "entry": "main.lua",
  "order": 2,
  "icon": [
    "111100",
    "100110",
    "101011",
    "100001",
    "101101",
    "111111"
  ],
  "short": "Notes",
  "short_ru": "Заметки",
  "author": "Juzeppe"
}]=],
    ["system-apps/packages/main.lua"]=[=[
local ctx=...
local P=ctx.colors
local pkg=ctx.package
local tab="catalog"
local list,visible={},{}
local scroll,selected=0,1
local query,loading="",false

local function tr(en,ru)
  return ctx.getLanguage()=="en" and en or ru
end

local function filtered()
  visible={}
  for _,item in ipairs(list) do
    local name=ctx.getLanguage()=="en" and item.name or (item.name_ru or item.name)
    local detail=ctx.getLanguage()=="en" and (item.description or "") or (item.description_ru or item.description or "")
    local text=(item.id.." "..item.name.." "..(item.name_ru or "").." "..detail):lower()
    if query=="" or text:find(query:lower(),1,true) then visible[#visible+1]=item end
  end
  selected=math.max(1,math.min(selected,#visible))
  scroll=math.max(0,math.min(scroll,math.max(0,#visible-5)))
end

local function useList(result,err)
  if result then list=result; filtered()
  else loading=false; dofile("/juzeppe/system/journal.lua")("packages","catalog",err); ctx.status(err) end
end

local function reload(remote)
  if tab=="installed" then loading=false; useList(pkg.installed()); return end
  if remote and pkg.repository()~="" then
    if loading then return end
    loading=true
    ctx.status(tr("Connecting to Juzeppe Store...","Подключаем магазин Juzeppe..."))
    ctx.job(function() return pkg.catalog(true) end,function(result,err)
      loading=false
      if tab=="catalog" then
        useList(result,err)
        if result then ctx.status(tr("Store updated","Магазин обновлён")) end
      end
    end)
  else loading=false; useList(pkg.catalog(false)) end
end

local function switch(nextTab)
  tab=nextTab
  scroll,selected=0,1
  reload(nextTab=="catalog")
end

local function button(x,y,label,width,fn,active)
  local bg=active and P.accent or P.deep
  local fg=active and P.paper or P.paper
  ctx.rect(x,y,width,1,bg)
  ctx.raw(x,y,label,fg,bg)
  ctx.hit(x,y,width,1,fn)
end

local function installFile()
  ctx.prompt(tr("Path to .juz file","Путь к файлу .juz"),"/",function(path)
    local app,err=pkg.installFile(path)
    ctx.status(app and (tr("Installed ","Установлено ")..app.name) or err)
    ctx.refreshApps()
    reload(false)
  end)
end

local function repository()
  ctx.prompt(tr("Repository URL (empty = default)","Адрес репозитория (пусто = основной)"),pkg.repository(),function(url)
    if url=="" then
      url="https://raw.githubusercontent.com/gosuparenek/juzeppe-repo/main"
    end
    local ok,err=pkg.setRepository(url)
    if not ok then ctx.status(err); return end
    ctx.status(tr("Repository saved","Репозиторий сохранён"))
    if tab=="catalog" then reload(true) end
  end)
end

local function action()
  if loading or ctx.busy then return end
  local item=visible[selected]
  if not item then return end
  if tab=="catalog" then
    ctx.confirm(tr("Install this application?","Установить приложение?"),function()
      local id,err=ctx.installPackage(item)
      ctx.status(id and ("#"..id.." "..item.name) or err)
      ctx.invalidate()
    end)
  else
    if item.system then ctx.status(tr("System application","Системное приложение")); return end
    ctx.confirm(tr("Remove this application?","Удалить приложение?"),function()
      local ok,err=pkg.remove(item.id)
      ctx.status(ok and tr("Application removed","Приложение удалено") or err)
      ctx.refreshApps()
      reload(false)
    end)
  end
end

local function search()
  ctx.prompt(tr("Find an application","Найти приложение"),query,function(value)
    query=value:lower()
    scroll,selected=0,1
    filtered()
  end)
end

local function drawIcon(item,x,y)
  local icon=item.icon
  if type(icon)~="table" or #icon~=6 then
    ctx.rect(x,y,3,2,P.oasis)
    ctx.raw(x,y,"APP",P.paper,P.oasis)
    return
  end
  for py=1,2 do
    for px=1,3 do
      local bit=icon[(py-1)*3+1]:sub((px-1)*2+1,(px-1)*2+1)
      local colour=bit=="1" and P.oasis or P.tint
      ctx.rect(x+px-1,y+py-1,1,1,colour)
    end
  end
end

local function draw(c)
  local w,h=c.width,c.height
  local op=c.latestInstall()
  if op then c.status(("#%d %s: %s"):format(op.id,op.app,op.error or op.state)) end
  if w<22 or h<10 then c.text(1,1,"Resize window"); return end

  c.rect(1,1,w,1,P.deep)
  c.raw(2,1,"J U Z E P P E   /   STORE",P.paper,P.deep)
  c.button(w-8,1," Sync ",function() reload(true) end,P.accent,P.paper)

  button(1,2,tr(" Catalog "," Каталог "),9,function() switch("catalog") end,tab=="catalog")
  button(11,2,tr(" Installed "," Установлено "),math.min(13,w-10),function() switch("installed") end,tab=="installed")
  c.button(w-8,2," Repo ",repository,P.tint,P.ink)

  c.rect(1,3,w,1,P.tint)
  c.button(1,3,tr(" Search "," Поиск "),search,P.deep,P.paper)
  button(11,3,tr(" File "," Файл "),7,installFile,false)
  local queryText=query=="" and tr("All applications","Все приложения") or query
  c.raw(20,3,queryText,P.muted,P.tint)

  local count=math.max(1,math.floor((h-7)/2))
  scroll=math.max(0,math.min(scroll,math.max(0,#visible-count)))
  for slot=1,count do
    local index=scroll+slot
    local item=visible[index]
    local y=4+(slot-1)*2
    local selectedRow=index==selected
    local bg=selectedRow and P.tint or P.paper
    if item then
      c.rect(1,y,w,2,bg)
      drawIcon(item,2,y)
      local name=ctx.getLanguage()=="en" and item.name or (item.name_ru or item.name)
      c.raw(7,y,name,P.ink,bg)
      local installed=pkg.find(item.id)
      local state=installed and (pkg.newer(item.version,installed.version) and tr("Update available","Доступно обновление") or tr("Installed","Установлено")) or item.version
      c.raw(7,y+1,state,installed and P.foliage or P.muted,bg)
      c.hit(1,y,w,2,function() selected=index end)
    elseif loading and slot==1 then
      c.raw(2,y,tr("Connecting to the store...","Подключаемся к магазину..."),P.muted,bg)
    end
  end

  c.rect(1,h-3,w,1,P.tint)
  local item=visible[selected]
  if item then
    local name=ctx.getLanguage()=="en" and item.name or (item.name_ru or item.name)
    local description=ctx.getLanguage()=="en" and (item.description or "") or (item.description_ru or item.description or "")
    c.raw(2,h-3,name,P.deep,P.tint)
    c.raw(2,h-2,description,P.muted)
    if loading or ctx.busy then c.raw(2,h,tr("Please wait...","Подождите..."),P.muted,P.paper)
    elseif tab=="catalog" then
      local installed=pkg.find(item.id)
      local canInstall=not installed or pkg.newer(item.version,installed.version)
      if canInstall then
        c.button(2,h,installed and tr(" Update "," Обновить ") or tr(" Install "," Установить "),action,P.accent,P.paper)
      else c.raw(2,h,tr("Already installed","Уже установлено"),P.foliage) end
    elseif not item.system then c.button(2,h,tr(" Remove "," Удалить "),action,P.danger,P.paper)
    else c.raw(2,h,tr("System application","Системное приложение"),P.muted) end
  elseif not loading then
    c.raw(2,h-2,query~="" and tr("No matches","Ничего не найдено") or tr("Store is empty","Каталог пуст"),P.muted)
  end
end

reload(false)
if pkg.repository()~="" then reload(true) end

return {draw=draw,events={package_result=true,mouse_scroll=true,key=true,term_resize=true},event=function(c,e,a)
  local count=math.max(1,math.floor((c.height-7)/2))
  if e=="package_result" then reload(false)
  elseif e=="mouse_scroll" then
    scroll=math.max(0,math.min(math.max(0,#visible-count),scroll+a))
  elseif e=="key" and (a==keys.up or a==keys.down) then
    selected=math.max(1,math.min(#visible,selected+(a==keys.up and -1 or 1)))
    if selected<=scroll then scroll=selected-1 elseif selected>scroll+count then scroll=selected-count end
  elseif e=="key" and a==keys.enter then action()
  elseif e=="key" and a==keys.f and ctx.modifiers().ctrl then search() end
end}
]=],
    ["system-apps/packages/manifest.json"]=[=[
{
  "id": "packages",
  "name": "Apps",
  "name_ru": "Магазин",
  "description": "Packages",
  "description_ru": "Пакеты",
  "version": "0.9.1",
  "api": 1,
  "entry": "main.lua",
  "order": 5,
  "icon": [
    "111111",
    "100001",
    "110011",
    "101101",
    "100001",
    "111111"
  ],
  "short": "Apps",
  "short_ru": "Магазин",
  "author": "Juzeppe"
}
]=],
    ["system-apps/settings/main.lua"]=[=[
local ctx=...
local P=ctx.colors
return {refresh=false,draw=function(c)
  c.text(1,1,"Language")
  local language=c.getLanguage()
  c.button(1,2," EN ",function() c.setLanguage("en") end,language=="en" and P.accent or P.tint,language=="en" and P.paper or P.ink)
  c.button(6,2," RU ",function() c.setLanguage("ru") end,language=="ru" and P.accent or P.tint,language=="ru" and P.paper or P.ink)
  c.button(11,2," RU-Lat ",function() c.setLanguage("translit") end,language=="translit" and P.accent or P.tint,language=="translit" and P.paper or P.ink)
  c.text(1,3,"RU needs Cyrillic font",P.muted)
  local i,themes=c.getTheme()
  for n,t in ipairs(themes) do
    local y=3+n
    local bg=i==n and P.tint or P.paper
    c.rect(1,y,c.width,1,bg)
    c.raw(1,y,(i==n and "* " or "  ")..c.tr(t.name),P.ink,bg)
    c.hit(1,y,c.width,1,function() c.setTheme(n) end)
  end
  c.status("Settings saved")
end}
]=],
    ["system-apps/settings/manifest.json"]=[=[
{
  "id": "settings",
  "name": "Settings",
  "name_ru": "Настройки",
  "description": "Themes",
  "description_ru": "Темы",
  "version": "0.6.1",
  "api": 1,
  "entry": "main.lua",
  "order": 4,
  "icon": [
    "001100",
    "011110",
    "110011",
    "110011",
    "011110",
    "001100"
  ],
  "short": "Prefs",
  "short_ru": "Настр.",
  "author": "Juzeppe"
}]=],
    ["system-apps/terminal/main.lua"]=[=[
local started=false
return {refresh=false,draw=function(c)
  if not started then
    started=true
    c.status("Type exit to return")
    c.launch()
  else
    c.text(2,2,"Shell session ended")
    c.button(2,4," Start shell ",function() c.launch() end)
  end
end,onReturn=function(c) c.status("Shell session ended") end}
]=],
    ["system-apps/terminal/manifest.json"]=[=[
{
  "id": "terminal",
  "name": "Terminal",
  "name_ru": "Терминал",
  "description": "Commands",
  "description_ru": "Команды",
  "version": "0.6.1",
  "api": 1,
  "entry": "main.lua",
  "order": 3,
  "icon": [
    "111111",
    "100001",
    "110001",
    "101101",
    "100001",
    "111111"
  ],
  "short": "Shell",
  "short_ru": "Shell",
  "author": "Juzeppe"
}]=],
    ["system/art.lua"]=[=[
return function(line,P)
local function mosaicCell(x, y, pixels, fg, bg)
  local invert = pixels[6]
  local mask = 0
  for i = 1, 5 do
    if pixels[i] ~= invert then mask = mask + 2 ^ (i - 1) end
  end
  line(x, y, string.char(128 + mask), invert and bg or fg, invert and fg or bg)
end

local function icon(x, y, art, fg, bg)
  for cy = 0, 1 do
    for cx = 0, #art[1] / 2 - 1 do
      local pixels = {}
      for py = 1, 3 do
        for px = 1, 2 do
          pixels[#pixels + 1] = art[cy * 3 + py]:sub(cx * 2 + px, cx * 2 + px) == "1"
        end
      end
      mosaicCell(x + cx, y + cy, pixels, fg, bg)
    end
  end
end

-- A small sandstone city drawn in terminal semigraphics.
local function skyline(x, y, width, height)
  local pw, ph = width * 2, height * 3
  local image = {}
  for py=1,ph do
    image[py]={}
    for px=1,pw do image[py][px]=P.sky end
  end
  local function pixel(px,py,colour)
    if image[py] and px>=1 and px<=pw then image[py][px]=colour end
  end
  local function rect(x1,y1,x2,y2,colour)
    for py=y1,y2 do
      for px=x1,x2 do pixel(px,py,colour) end
    end
  end
  local function disc(cx,cy,r,colour)
    for py=cy-r,cy+r do
      for px=cx-r,cx+r do
        if (px-cx)^2+(py-cy)^2<=r*r then pixel(px,py,colour) end
      end
    end
  end
  local sunX = math.floor(pw * 0.72)
  disc(sunX,math.max(3,math.floor(ph*0.36)),math.max(2,math.floor(ph*0.22)),P.sun)
  for px=1,pw do
    local ridge=math.floor(ph*0.62+math.sin(px*0.22)*2)
    rect(px,ridge,px,ph,P.tint)
  end
  local function building(left, wide, tall, colour, roof)
    local top=ph-tall
    rect(left,top,left+wide-1,ph,colour)
    rect(left,top,left+wide-1,top,roof)
    if wide>=5 and tall>=5 then
      rect(left+1,top+2,left+1,top+3,P.deep)
      rect(left+wide-2,top+2,left+wide-2,top+3,P.deep)
    end
    local door=left+math.floor(wide/2)
    if wide>=4 then rect(door,ph-2,door+1,ph,P.deep) end
  end
  building(2,math.max(4,math.floor(pw*.20)),math.max(4,math.floor(ph*.43)),P.bronze,P.accent)
  local tower=math.floor(pw*.29)
  building(tower,5,math.max(6,math.floor(ph*.76)),P.earth,P.bronze)
  local tt=ph-math.max(6,math.floor(ph*.76))
  rect(tower+1,tt-2,tower+3,tt-1,P.accent)
  pixel(tower+2,tt-3,P.accent)
  local domeX=math.floor(pw*.52)
  building(domeX-4,9,math.max(5,math.floor(ph*.40)),P.earth,P.bronze)
  local dt=ph-math.max(5,math.floor(ph*.40))
  for py=-3,0 do
    local radius=math.floor(math.sqrt(9-py*py))
    rect(domeX-radius,dt+py,domeX+radius,dt+py,P.oasis)
  end
  building(math.floor(pw*.77),math.max(5,math.floor(pw*.21)),math.max(4,math.floor(ph*.50)),P.bronze,P.accent)
  rect(1,ph,pw,ph,P.accent)
  for cy=0,height-1 do
    for cx=0,width-1 do
      local values,counts,order={},{},{}
      for py=1,3 do
        for px=1,2 do
          local value=image[cy*3+py][cx*2+px]
          values[#values+1]=value
          if not counts[value] then counts[value]=0; order[#order+1]=value end
          counts[value]=counts[value]+1
        end
      end
      table.sort(order,function(a,b) return counts[a]>counts[b] end)
      local bg,fg=order[1],order[2] or order[1]
      local pixels={}
      for i,value in ipairs(values) do pixels[i]=value~=bg end
      mosaicCell(x+cx,y+cy,pixels,fg,bg)
    end
  end
end


return {icon=icon,skyline=skyline}
end
]=],
    ["system/auth.lua"]=[=[
-- SHA-256 and HMAC-SHA256 for authenticated local-network messages.
local B=bit32
local band,bxor,bnot,rshift,ror=B.band,B.bxor,B.bnot,B.rshift,B.rrotate
local MOD=4294967296
local K={
  0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
  0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
  0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
  0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
  0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
  0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
  0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
  0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2}
local function pack32(n)
  return string.char(rshift(n,24),band(rshift(n,16),255),band(rshift(n,8),255),band(n,255))
end
local function sha(s)
  local length=#s*8
  local pad=(56-(#s+1)%64)%64
  s=s..string.char(128)..string.rep("\0",pad)..pack32(math.floor(length/MOD))..pack32(length%MOD)
  local h={0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19}
  local w={}
  for offset=1,#s,64 do
    for i=0,15 do
      local a,b,c,d=s:byte(offset+i*4,offset+i*4+3)
      w[i]=((a*256+b)*256+c)*256+d
    end
    for i=16,63 do
      local x,y=w[i-15],w[i-2]
      local s0=bxor(ror(x,7),ror(x,18),rshift(x,3))
      local s1=bxor(ror(y,17),ror(y,19),rshift(y,10))
      w[i]=(w[i-16]+s0+w[i-7]+s1)%MOD
    end
    local a,b,c,d,e,f,g,z=table.unpack(h)
    for i=0,63 do
      local s1=bxor(ror(e,6),ror(e,11),ror(e,25))
      local ch=bxor(band(e,f),band(bnot(e),g))
      local t1=(z+s1+ch+K[i+1]+w[i])%MOD
      local s0=bxor(ror(a,2),ror(a,13),ror(a,22))
      local maj=bxor(band(a,b),band(a,c),band(b,c))
      local t2=(s0+maj)%MOD
      z,g,f,e,d,c,b,a=g,f,e,(d+t1)%MOD,c,b,a,(t1+t2)%MOD
    end
    local v={a,b,c,d,e,f,g,z}
    for i=1,8 do h[i]=(h[i]+v[i])%MOD end
  end
  local out={}
  for i=1,8 do out[i]=pack32(h[i]) end
  return table.concat(out)
end
local function hex(s)
  return (s:gsub(".",function(c) return string.format("%02x",c:byte()) end))
end
local M={}
function M.sha256(s) return hex(sha(s)) end
function M.signer(key)
  if #key>64 then key=sha(key) end
  key=key..string.rep("\0",64-#key)
  local inner,outer={},{}
  for i=1,64 do
    inner[i]=string.char(bxor(key:byte(i),0x36))
    outer[i]=string.char(bxor(key:byte(i),0x5c))
  end
  inner,outer=table.concat(inner),table.concat(outer)
  return function(s) return hex(sha(outer..sha(inner..s))) end
end
function M.equal(a,b)
  if type(a)~="string" or type(b)~="string" or #a~=#b then return false end
  local diff=0
  for i=1,#a do diff=B.bor(diff,bxor(a:byte(i),b:byte(i))) end
  return diff==0
end
return M
]=],
    ["system/base64.lua"]=[=[
local M={}
local alphabet="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local reverse={}
for i=1,#alphabet do reverse[alphabet:sub(i,i)]=i-1 end
function M.encode(s)
  local output={}
  for i=1,#s,3 do
    local a,b,c=s:byte(i,i+2)
    local n=a*65536+(b or 0)*256+(c or 0)
    local p=math.floor(n/262144)%64+1
    local q=math.floor(n/4096)%64+1
    local r=math.floor(n/64)%64+1
    local t=n%64+1
    output[#output+1]=alphabet:sub(p,p)..alphabet:sub(q,q)..(b and alphabet:sub(r,r) or "=")..(c and alphabet:sub(t,t) or "=")
  end
  return table.concat(output)
end
function M.decode(s)
  if type(s)~="string" or #s%4~=0 or s:find("[^A-Za-z0-9+/=]") then return nil end
  local out={}
  for i=1,#s,4 do
    local a,b,c,d=s:sub(i,i),s:sub(i+1,i+1),s:sub(i+2,i+2),s:sub(i+3,i+3)
    if not reverse[a] or not reverse[b] or (c~="=" and not reverse[c]) or (d~="=" and not reverse[d]) then return nil end
    if (c=="=" or d=="=") and i+3~=#s then return nil end
    if c=="=" and d~="=" then return nil end
    local n=reverse[a]*262144+reverse[b]*4096+(reverse[c] or 0)*64+(reverse[d] or 0)
    out[#out+1]=string.char(math.floor(n/65536)%256)
    if c~="=" then out[#out+1]=string.char(math.floor(n/256)%256) end
    if d~="=" then out[#out+1]=string.char(n%256) end
  end
  return table.concat(out)
end
return M
]=],
    ["system/clipboard.lua"]=[=[
local ops=assert(loadfile("/juzeppe/system/fileops.lua","t",_ENV))()
local M={}
function M.new()
  local self={kind=nil,mode=nil,paths={},text=nil}
  function self:setText(text)
    self.kind,self.mode,self.paths,self.text="text",nil,{},tostring(text or "")
    return true
  end
  function self:getText()
    return self.kind=="text" and self.text or nil
  end
  function self:setFiles(paths,mode)
    if mode~="copy" and mode~="cut" then return nil,"Invalid clipboard mode" end
    local result,seen={},{}
    for _,p in ipairs(paths or {}) do
      local path=ops.path(p)
      if path~="/" and fs.exists(path) and not seen[path] then
        if mode=="cut" and fs.isReadOnly(path) then return nil,"Read-only file" end
        seen[path]=true; result[#result+1]=path
      end
    end
    if #result==0 then return nil,"Select files first" end
    -- Discard children if their parent directory is already selected.
    local filtered={}
    for _,p in ipairs(result) do
      local child=false
      for _,q in ipairs(result) do
        if p~=q and fs.isDir(q) and ops.inside(p,q) then child=true; break end
      end
      if not child then filtered[#filtered+1]=p end
    end
    self.kind,self.mode,self.paths,self.text="files",mode,filtered,nil
    return #filtered
  end
  function self:hasFiles() return self.kind=="files" and #self.paths>0 end
  function self:paste(parent)
    parent=ops.path(parent)
    if not self:hasFiles() then return {},{"Clipboard has no files"} end
    if not fs.exists(parent) or not fs.isDir(parent) then return {},{"Folder not found"} end
    if fs.isReadOnly(parent) then return {},{"Read-only folder"} end
    local results,errors,remaining={},{},{}
    for _,source in ipairs(self.paths) do
      local name=fs.getName(source)
      local dest=ops.path(fs.combine(parent,name))
      local copied,err
      if self.mode=="cut" and source==dest and fs.exists(source) then copied=source
      else
        dest=ops.unique(parent,name)
        if self.mode=="cut" then copied,err=ops.move(source,dest)
        else copied,err=ops.copy(source,dest) end
      end
      if copied then results[#results+1]=copied
      else errors[#errors+1]=name..": "..tostring(err); remaining[#remaining+1]=source end
    end
    if self.mode=="cut" then
      self.paths=remaining
      if #remaining==0 then self.kind,self.mode=nil,nil end
    end
    return results,errors
  end
  return self
end
return M
]=],
    ["system/compositor.lua"]=[=[
-- Double buffer and dirty-span compositor. The host is written only at flush.
local M={}
function M.new(host)
  local w,h=host.getSize()
  local self={host=host,w=w,h=h,buffer=window.create(host,1,1,w,h,false),previous={},
    last={rows=0,spans=0,cells=0},cursor=nil}
  function self:resize(width,height)
    if width==self.w and height==self.h then return false end
    self.w,self.h=width,height
    self.buffer.reposition(1,1,width,height)
    self.previous={}
    self.cursor=nil
    return true
  end
  function self:flush()
    local metrics={rows=0,spans=0,cells=0}
    for y=1,self.h do
      local text,fg,bg=self.buffer.getLine(y)
      local old=self.previous[y]
      if not old or old[1]~=text or old[2]~=fg or old[3]~=bg then
        metrics.rows=metrics.rows+1
        local ranges={}
        if not old then ranges[1]={1,self.w}
        else
          local first,last
          for x=1,self.w do
            local different=text:byte(x)~=old[1]:byte(x)
              or fg:byte(x)~=old[2]:byte(x) or bg:byte(x)~=old[3]:byte(x)
            if different then
              if first and x-last>3 then
                ranges[#ranges+1]={first,last}
                first=nil
              end
              first=first or x
              last=x
            end
          end
          if first then ranges[#ranges+1]={first,last} end
          -- On a dense row, a single blit is cheaper than many short blits.
          if #ranges>6 then ranges={{1,self.w}} end
        end
        for _,range in ipairs(ranges) do
          local a,b=range[1],range[2]
          host.setCursorPos(a,y)
          host.blit(text:sub(a,b),fg:sub(a,b),bg:sub(a,b))
          metrics.spans=metrics.spans+1
          metrics.cells=metrics.cells+b-a+1
        end
        self.previous[y]={text,fg,bg}
      end
    end
    self.last=metrics
    return metrics
  end
  function self:setCursor(x,y,colour,blink)
    local old=self.cursor
    if x and y then
      if self.last.spans>0 or not old or old.x~=x or old.y~=y or old.colour~=colour then
        host.setCursorPos(x,y)
        host.setTextColor(colour)
      end
    end
    blink=not not blink
    if not old or old.blink~=blink then host.setCursorBlink(blink) end
    self.cursor={x=x,y=y,colour=colour,blink=blink}
  end
  return self
end
return M

]=],
    ["system/core.lua"]=[=[
local kernel=...
local desktopExit='exit'
local U=assert(loadfile("/juzeppe/system/util.lua","t",_ENV))()
local palette=assert(loadfile("/juzeppe/system/palette.lua","t",_ENV))()
local locale=assert(loadfile("/juzeppe/system/locale.lua","t",_ENV))()
local pkg=assert(loadfile("/juzeppe/system/packages.lua","t",_ENV))()
local wmAPI=assert(loadfile("/juzeppe/system/wm.lua","t",_ENV))()
local processAPI=assert(loadfile("/juzeppe/system/process.lua","t",_ENV))()
local desktop=assert(loadfile("/juzeppe/system/desktop.lua","t",_ENV))()
local layout=assert(loadfile("/juzeppe/system/desktop-layout.lua","t",_ENV))()
local compositor=assert(loadfile("/juzeppe/system/compositor.lua","t",_ENV))()
local fileops=assert(loadfile("/juzeppe/system/fileops.lua","t",_ENV))()
local clipboard=assert(loadfile("/juzeppe/system/clipboard.lua","t",_ENV))().new()
local P=palette.colors
local host=term.current()
if not host.isColor() then print("JuzeppeOS needs a colour computer."); return end
local W,H=host.getSize()
local original=palette.capture(host)
local wm=wmAPI.new(W,H)
local frame=compositor.new(host)
local canvas=frame.buffer
local desktopLayer=window.create(host,1,1,W,H,false)
local wallpaperLayer=window.create(host,1,1,W,H,false)
local desktopDirty,wallpaperDirty=true,true
local desktopItems,iconSlots,files={},{},{}
local fileSignature,appSignature
local activePalette
local themePath="/juzeppe/config/appearance"
local themeIndex=tonumber(U.read(themePath) or U.read("/.juzeppe/appearance")) or 1
if not palette.themes[themeIndex] then themeIndex=1 end
local apps={}
local running,overlay,modal=true,nil,nil
local desktopHits,barHits,overlayHits,modalHits={},{},{},{}
local filePage,menuPage,taskScroll,tabPage=1,1,0,1
local menuQuery=""
local selectedKey,wantedKey,lastClick,lastClickTime=nil,nil,nil,0
local drag,altDown=nil,false
local ctrlDown,shiftDown=false,false
local skipPasteUntil=0
local notice,noticeUntil="",0
local timer,process

local function clip(text,width)
  width=math.max(0,width)
  if #text<=width then return text end
  return width<4 and text:sub(1,width) or text:sub(1,width-3).."..."
end
local function line(x,y,text,fg,bg)
  if y<1 or y>H or x>W then return end
  text=tostring(text)
  if x<1 then text=text:sub(2-x); x=1 end
  if #text==0 then return end
  canvas.setCursorPos(x,y)
  canvas.setTextColor(fg or P.ink)
  canvas.setBackgroundColor(bg or P.earth)
  canvas.write(text:sub(1,W-x+1))
end
local function fill(x,y,w,h,c)
  if w<=0 or h<=0 then return end
  for row=y,y+h-1 do line(x,row,string.rep(" ",w),c,c) end
end
local function hit(list,x,y,w,h,fn,kind)
  list[#list+1]={x=x,y=y,w=w,h=h,fn=fn,kind=kind}
end
local function btn(list,x,y,text,fn,bg,fg)
  line(x,y,text,fg or P.paper,bg or P.accent)
  hit(list,x,y,#text,1,fn)
  return #text
end
local function button(list,x,y,key,fn,bg,fg)
  return btn(list,x,y,locale.text(key),fn,bg,fg)
end
local contains,locate=assert(loadfile("/juzeppe/system/hit-test.lua","t",_ENV))()
local function clock()
  local m=math.floor((os.time()%24)*60)
  return string.format("%02d:%02d",math.floor(m/60),m%60)
end
local art=assert(loadfile("/juzeppe/system/art.lua","t",_ENV))()(line,P)
local defaultIcon={"111111","100001","101101","101101","100001","111111"}
local folderIcon={"011000","111100","111111","100001","100001","111111"}
local fileIcon={"111100","100110","101011","100001","101101","111111"}
local appColors={P.deep,P.bronze,P.accent,P.oasis,P.olive,P.accent,P.deep}
local function appColor(m)
  return appColors[((tonumber(m.order) or 0)-1)%#appColors+1]
end
local function windowName(win,short)
  local name=short and locale.short(win.app) or locale.name(win.app)
  if win.instanceNumber and win.instanceNumber>1 and win.app.id~="editor" then name=name.." "..win.instanceNumber end
  return name
end
local function refresh()
  apps=pkg.installed()
  local parts={}
  for _,m in ipairs(apps) do parts[#parts+1]=m.id..":"..m.version..":"..m.name end
  local signature=table.concat(parts,"\0")
  if signature~=appSignature then appSignature=signature; desktopDirty=true end
end
local function pollDesktop()
  local list,parts={},{}
  local names,types=desktop.list()
  for _,name in ipairs(names) do
    local dir=types[name]
    list[#list+1]={name=name,dir=dir}
    parts[#parts+1]=(dir and "D" or "F")..name
  end
  local signature=table.concat(parts,"\0")
  if signature~=fileSignature then
    files=list
    fileSignature=signature
    desktopDirty=true
  end
end
local function invalidateApps()
  for _,win in ipairs(wm.windows) do win.dirty=true end
end
local function message(value)
  notice=tostring(value or "")
  noticeUntil=os.clock()+6
end
local network=kernel.network
local journal=dofile('/juzeppe/system/journal.lua')
local function safe(fn,...)
  local ok,err=pcall(fn,...)
  if not ok then journal("desktop","callback",err); message("Error: "..tostring(err)) end
end
local function focus(win)
  overlay=nil
  local restored=win.minimized
  wm:focus(win)
  if restored then win.dirty=true end
end
local function closeWindow(win)
  if win.closed then return end
  if modal and modal.owner==win then modal=nil end
  if overlay and overlay.owner==win then overlay=nil end
  if drag and drag.win==win then drag=nil end
  process:close(win)
  wm:close(win)
end
local function prompt(owner,label,initial,callback,confirm,secret)
  skipPasteUntil=0
  if owner then focus(owner) end
  overlay=nil
  modal={owner=owner,label=label,value=tostring(initial or ""),callback=callback,replace=true,confirm=confirm,secret=secret}
end
local function modalDone()
  skipPasteUntil=0
  local m=modal
  modal=nil
  if m.owner then process:action(m.owner,m.callback,m.confirm and true or m.value)
  else safe(m.callback,m.confirm and true or m.value) end
end
local function openApp(id,args)
  local m=type(id)=="table" and id or pkg.find(id)
  if not m then message("Application not found"); return end
  overlay=nil
  local function launch(documents)
    local win=wm:newWindow(m)
    process:attach(win,args,nil,documents)
    return win
  end
  local grants={}
  local requests=m.permissions or {}
  local function request(i)
    local permission=requests[i]
    if not permission then return launch(grants) end
    prompt(nil,m.name.." / "..permission.."?","",function()
      grants[permission]=true; request(i+1)
    end,true)
  end
  return request(1)
end
process=processAPI.new(host,P,locale,{
  newWindow=function(win,proc,docs) process:attach(wm:newWindow(win.app),{},proc,docs) end,
  kernel=kernel,pkg=pkg,desktopPath=desktop.path,refresh=refresh,
  clipboard=clipboard,network=network,
  refreshDesktop=function() pollDesktop(); desktopDirty=true end,
  modifiers=function() return {ctrl=ctrlDown,shift=shiftDown,alt=altDown} end,
  menu=function(win,entries,x,y)
    focus(win)
    overlay={kind="appMenu",owner=win,entries=entries,x=win.x+(x or 1),y=win.y+(y or 1),scroll=0}
  end,
  close=closeWindow,openApp=openApp,
  minimize=function(win) wm:minimize(win) end,
  maximize=function(win) wm:toggleMax(win) end,
  prompt=function(win,label,initial,cb,secret) prompt(win,label,initial,cb,false,secret) end,
  confirm=function(win,label,cb) prompt(win,label,"",cb,true) end,
  getLanguage=function() return locale.mode end,
  setLanguage=function(mode)
    locale.set(mode); desktopDirty=true; wallpaperDirty=true; invalidateApps()
  end,
  getTheme=function() return themeIndex,palette.themes end,
  setTheme=function(i)
    if palette.themes[i] then themeIndex=i; U.write(themePath,tostring(i)); desktopDirty=true; wallpaperDirty=true; invalidateApps() end
  end
})
local function openNative(name,program,...)
  overlay=nil
  local app={id="editor",name=name,name_ru=name,order=2,icon=fileIcon}
  local win=wm:newWindow(app)
  win.ephemeral=true
  process:attach(win)
  process:startSession(win,program,...)
  return win
end
local function selectFile(name)
  selectedKey="file:"..name
  wantedKey=selectedKey
  pollDesktop()
  desktopDirty=true
end
local function openFile(name)
  if not name or not desktop.validName(name) then return end
  local path="/"..fs.combine(desktop.path,name):gsub("^/+","")
  if not fs.exists(path) then message("File not found"); return end
  if fs.isDir(path) then openApp("files",{path=path})
  elseif name:lower():match("%.juz$") then
    prompt(nil,"Install this package?","",function()
      local m,err=pkg.installFile(path)
      message(m and (locale.raw("Installed").." "..m.name) or err)
      refresh()
    end,true)
  else
    openNative(name,"/rom/programs/edit.lua",path)
  end
end
local function createItem(isDir)
  prompt(nil,isDir and "Folder name" or "File name",isDir and locale.raw("New folder") or "untitled.txt",function(name)
    local path,err=desktop.make(desktop.path,name,isDir)
    if path then selectFile(fs.getName(path)); message(isDir and "Folder created" or "File created")
    else message(err) end
  end,false)
end
local function renameItem(name)
  prompt(nil,"New name",name,function(newName)
    local path,err=desktop.rename(name,newName)
    if path then selectFile(fs.getName(path)); message("Renamed") else message(err) end
  end,false)
end
local function deleteItem(name)
  prompt(nil,"Move to Trash?","",function()
    local ok,err=fileops.trash(fs.combine(desktop.path,name))
    if ok then selectedKey=nil; pollDesktop(); desktopDirty=true; message("Moved to Trash") else message(err) end
  end,true)
end
local function copyDesktop(name,mode)
  local n,err=clipboard:setFiles({fs.combine(desktop.path,name)},mode)
  message(n and (mode=="copy" and "Copied" or "Cut") or err)
end
local function pasteDesktop()
  local paths,errors=clipboard:paste(desktop.path)
  if #paths>0 then selectFile(fs.getName(paths[#paths])); message(#paths.." "..locale.raw("Pasted"))
  else message(errors[1] or "Clipboard has no files") end
  pollDesktop()
  desktopDirty=true
end
local function contextMenu(x,y,item)
  overlay={kind="context",x=x,y=y,item=item}
  if item then selectedKey=item.key; desktopDirty=true end
end
local function openIcon(item)
  if item.kind=="app" then openApp(item.app)
  else openFile(item.name) end
end
local function clickIcon(item)
  local now=os.clock()
  if lastClick==item.key and now-lastClickTime<=0.5 then
    lastClick=nil
    openIcon(item)
    return true
  end
  lastClick=item.key
  lastClickTime=now
  selectedKey=item.key
  desktopDirty=true
  return false
end
local function drawWallpaper()
  canvas=wallpaperLayer
  canvas.setBackgroundColor(P.sky)
  canvas.setTextColor(P.ink)
  canvas.clear()
  local artW=math.max(12,math.floor(W*.55))
  local artH=math.max(4,math.floor((H-1)*.55))
  art.skyline(W-artW+1,H-artH,artW,artH)
  local brand="J U Z E P P E"
  if W>=40 and H>=14 then
    line(W-#brand-2,2,brand,P.deep,P.sky)
    local sub=clip(locale.text("City Operating System"),math.min(22,W-3))
    line(W-#sub-2,3,sub,P.muted,P.sky)
  end
  wallpaperDirty=false
end
local function drawDesktop()
  desktopHits={}
  iconSlots={}
  if wallpaperDirty then drawWallpaper() end
  canvas=desktopLayer
  for y=1,H-1 do
    local text,fg,bg=wallpaperLayer.getLine(y)
    canvas.setCursorPos(1,y)
    canvas.blit(text,fg,bg)
  end
  desktopItems=layout.items(apps,files)
  local cols=math.max(1,math.floor(W/12))
  local rows=math.max(1,math.floor((H-2)/4))
  local per=cols*rows
  local pages=math.max(1,math.ceil(#desktopItems/per))
  if wantedKey then
    for i,item in ipairs(desktopItems) do if item.key==wantedKey then filePage=math.ceil(i/per); break end end
    wantedKey=nil
  end
  filePage=math.max(1,math.min(filePage,pages))
  local cellW=math.floor(W/cols)
  for i=1,per do
    local index=(filePage-1)*per+i
    local x=1+math.floor((i-1)/rows)*cellW
    local y=2+((i-1)%rows)*4
    local slot={x=x,y=y,w=cellW,h=4,index=index}
    iconSlots[#iconSlots+1]=slot
    local item=desktopItems[index]
    if item then
      local selected=selectedKey==item.key
      local bg=selected and P.tint or P.sky
      if selected then fill(x,y,cellW,4,bg) end
      local iconX=x+math.floor((cellW-3)/2)
      local icon,label,ink
      if item.kind=="app" then
        icon=item.app.icon or defaultIcon
        label=locale.name(item.app)
        if #label>cellW-1 then label=locale.short(item.app) end
        ink=appColor(item.app)
        fill(iconX,y,3,2,ink)
        art.icon(iconX,y,icon,P.paper,ink)
      else
        local packet=item.name:lower():match("%.juz$")
        icon=item.dir and folderIcon or (packet and defaultIcon or fileIcon)
        ink=item.dir and P.bronze or (packet and P.oasis or P.deep)
        label=locale.render(item.name)
        art.icon(iconX,y,icon,ink,bg)
      end
      local first=label:sub(1,cellW-1)
      line(x+math.floor((cellW-#first)/2),y+2,first,P.ink,bg)
      if #label>#first then
        local second=clip(label:sub(#first+1),cellW-1)
        line(x+math.floor((cellW-#second)/2),y+3,second,P.ink,bg)
      end
      hit(desktopHits,x,y,cellW,4,function() clickIcon(item) end,item)
    end
  end
  if pages>1 then
    btn(desktopHits,2,H-1," < ",function() filePage=math.max(1,filePage-1); desktopDirty=true end,P.deep,P.paper)
    line(6,H-1,filePage.."/"..pages,P.ink,P.sky)
    btn(desktopHits,12,H-1," > ",function() filePage=math.min(pages,filePage+1); desktopDirty=true end,P.deep,P.paper)
  end
  desktopDirty=false
  canvas=frame.buffer
end
local function paintDesktop()
  if desktopDirty then drawDesktop() end
  for y=1,H-1 do
    local text,fg,bg=desktopLayer.getLine(y)
    canvas.setCursorPos(1,y)
    canvas.blit(text,fg,bg)
  end
  if drag and drag.kind=="icon" and drag.moved and drag.slot then
    local p=drag.slot
    line(p.x,p.y+3,string.rep("-",p.w),P.accent,P.sky)
  end
end
local function compose(win)
  local x,y,w,h=win.x,win.y,win.w,win.h
  if x+w<=W then fill(x+w,y+1,1,h,P.border) end
  if y+h<H then fill(x+1,y+h,w,1,P.border) end
  fill(x,y,w,h,P.paper)
  local ink=wm.focused==win and appColor(win.app) or P.muted
  fill(x,y,w,1,ink)
  line(x+1,y,clip(windowName(win),w-11),P.paper,ink)
  line(x+w-9,y," _ ",P.paper,ink)
  line(x+w-6,y,win.maximized and " v " or " + ",P.paper,ink)
  line(x+w-3,y," X ",P.paper,P.danger)
  local view=process:draw(win)
  if win.closed then return end
  for row=1,h-2 do
    local text,fg,bg=view.getLine(row)
    canvas.setCursorPos(x+1,y+row)
    canvas.blit(text,fg,bg)
  end
  fill(x,y+h-1,w,1,P.tint)
  local n=locale.text(win.notice)
  if win.worker or win.loading then n=n~="" and n or locale.text("Working...") end
  line(x+1,y+h-1,clip(n,w-3),P.muted,P.tint)
  if not win.maximized then line(x+w-1,y+h-1,"#",P.paper,P.deep) end
end
local function drawBar()
  barHits={}
  fill(1,H,W,1,P.ink)
  local x=1
  x=x+button(barHits,x,H," J Start ",function()
    if overlay and overlay.kind=="menu" then overlay=nil else overlay={kind="menu"}; menuPage=1; menuQuery="" end
  end,P.accent,P.paper)
  x=x+button(barHits,x,H," Win ",function()
    if overlay and overlay.kind=="tasks" then overlay=nil else overlay={kind="tasks"}; taskScroll=0 end
  end,P.deep,P.paper)
  local deskX=W-2
  local clockX=W-8
  line(clockX,H,clock(),P.tint,P.ink)
  btn(barHits,deskX,H," | ",function() overlay=nil; wm:desktop() end,P.deep,P.paper)
  local tasks=wm:tasks()
  local available=clockX-x
  if available<4 then return end
  if #tasks==0 then
    if available>=6 then line(x+1,H,"v0.9.1",P.tint,P.ink) end
    return
  end
  local count=math.max(1,math.floor(available/9))
  local paged=#tasks>count and available>=6
  if paged then available=available-2; count=math.max(1,math.floor(available/9)) end
  local pages=math.max(1,math.ceil(#tasks/count))
  tabPage=math.max(1,math.min(tabPage,pages))
  if wm.focused and not overlay then
    for i,t in ipairs(tasks) do if t==wm.focused then tabPage=math.ceil(i/count); break end end
  end
  local tabW=math.max(1,math.floor(available/count))
  for i=1,count do
    local t=tasks[(tabPage-1)*count+i]
    if t then
      local bg=t==wm.focused and P.accent or (t.minimized and P.deep or P.border)
      local text=clip(windowName(t,true),tabW-2)
      text=" "..text..string.rep(" ",math.max(0,tabW-#text-1))
      btn(barHits,x,H,text,function()
        overlay=nil
        if wm.focused==t and not t.minimized then wm:minimize(t) else focus(t) end
      end,bg,P.paper)
      x=x+tabW
    end
  end
  if paged then
    btn(barHits,clockX-2,H,">>",function() overlay={kind="tasks"}; taskScroll=0 end,P.deep,P.paper)
  end
end
local function foldName(value)
  return (value:lower():gsub("[\208\209][\128-\191]",function(ch)
    local cp=utf8.codepoint(ch)
    if cp>=1040 and cp<=1071 then return utf8.char(cp+32) end
    if cp==1025 then return utf8.char(1105) end
    return ch
  end))
end
local function menuApps()
  if menuQuery=="" then return apps end
  local filtered={}
  local q=foldName(menuQuery)
  for _,app in ipairs(apps) do
    if foldName(app.id):find(q,1,true) or foldName(app.name):find(q,1,true)
      or (app.name_ru and foldName(app.name_ru):find(q,1,true)) then
      filtered[#filtered+1]=app
    end
  end
  return filtered
end
local function drawMenu()
  local candidates=menuApps()
  local count=math.max(4,math.min(10,H-5,math.max(5,#candidates)))
  local pages=math.max(1,math.ceil(#candidates/count))
  menuPage=math.min(pages,math.max(1,menuPage))
  local width=math.min(37,W-2)
  local two=width>=33
  local leftW=two and width-14 or width
  local top=H-count-3
  fill(2,top+1,width,count+2,P.border)
  fill(1,top,width,count+3,P.paper)
  fill(1,top,width,1,P.accent)
  line(2,top,"JUZEPPE.OS",P.paper,P.accent)
  if pages>1 then
    btn(overlayHits,leftW-7,top,"<",function() menuPage=math.max(1,menuPage-1) end,P.accent,P.paper)
    line(leftW-5,top,menuPage.."/"..pages,P.paper,P.accent)
    btn(overlayHits,leftW-1,top,">",function() menuPage=math.min(pages,menuPage+1) end,P.accent,P.paper)
  end
  for i=1,count do
    local m=candidates[(menuPage-1)*count+i]
    if m then
      local y=top+i
      local bg=i%2==0 and P.tint or P.paper
      fill(1,y,leftW,1,bg)
      line(2,y,"#",P.paper,appColor(m))
      line(4,y,clip(locale.name(m),leftW-4),P.ink,bg)
      hit(overlayHits,1,y,leftW,1,function() openApp(m) end,{key="app:"..m.id,kind="app",app=m})
    end
  end
  if #candidates==0 then line(2,top+1,clip(locale.text("No applications"),leftW-2),P.muted,P.paper) end
  if two then
    fill(leftW+1,top+1,width-leftW,count+1,P.tint)
    local quick={
      {"Desktop",function() overlay=nil; wm:desktop() end},
      {"New folder",function() createItem(true) end},
      {"New file",function() createItem(false) end},
      {"Settings",function() openApp("settings") end},
      {"Windows",function() overlay={kind="tasks"}; taskScroll=0 end},
      {"Trash",function() openApp("files",{trash=true}) end}
    }
    for i,item in ipairs(quick) do
      if i<=count then
        line(leftW+2,top+i,clip(locale.text(item[1]),width-leftW-2),P.ink,P.tint)
        hit(overlayHits,leftW+1,top+i,width-leftW,1,item[2])
      end
    end
  end
  fill(1,H-2,width,1,P.tint)
  local query=menuQuery~="" and locale.render(menuQuery) or locale.text("Type to search")
  line(2,H-2,clip("> "..query,width-2),P.muted,P.tint)
  line(2,H-1,locale.text("Exit OS"),P.danger,P.paper)
  hit(overlayHits,1,H-1,9,1,function() running=false end)
  btn(overlayHits,11,H-1," Restart UI ",function()
    prompt(nil,"Close windows and restart desktop?","",function() desktopExit="restart"; running=false end,true)
  end,P.deep,P.paper)
  if width>=32 then btn(overlayHits,24,H-1," Stop UI ",function()
    prompt(nil,"Close windows and stop desktop?","",function() desktopExit="stopped"; running=false end,true)
  end,P.deep,P.paper) end
end
local function drawTasks()
  local tasks=wm:tasks()
  local count=math.max(1,math.min(9,H-4))
  taskScroll=math.max(0,math.min(taskScroll,math.max(0,#tasks-count)))
  local width=math.min(W-2,36)
  local top=H-count-2
  local x=math.max(1,math.min(15,W-width))
  fill(x+1,top+1,width,count+1,P.border)
  fill(x,top,width,count+2,P.paper)
  fill(x,top,width,1,P.accent)
  line(x+1,top,locale.text("Open windows"),P.paper,P.accent)
  btn(overlayHits,x+width-5,top," Log ",function() openNative("Kernel log","/rom/programs/edit.lua","/juzeppe/logs/kernel.log") end,P.deep,P.paper)
  if #tasks==0 then line(x+1,top+1,locale.text("No open windows"),P.muted,P.paper) end
  for i=1,count do
    local t=tasks[i+taskScroll]
    if t then
      local row=top+i
      local bg=t==wm.focused and P.tint or P.paper
      fill(x,row,width,1,bg)
      local prefix=t.minimized and "- " or (t==wm.focused and "> " or "  ")
      line(x+1,row,clip(prefix.."#"..t.process.pid.." "..windowName(t),width-5),P.ink,bg)
      hit(overlayHits,x,row,width-3,1,function() focus(t) end)
      if t.ctx.busy or (t.worker and t.worker.filter==t.sliceEvent) then btn(overlayHits,x+width-9,row," Stop ",function() if not process:cancelJob(t) then message("Installation in progress") end end,P.deep,P.paper) end
      btn(overlayHits,x+width-3,row," X ",function() closeWindow(t) end,P.danger,P.paper)
    end
  end
  if #tasks>count then
    btn(overlayHits,x+1,H-1,"<",function() taskScroll=math.max(0,taskScroll-count) end,P.tint,P.ink)
    line(x+3,H-1,(taskScroll+1).."/"..#tasks,P.muted,P.paper)
    btn(overlayHits,x+width-2,H-1,">",function() taskScroll=math.min(#tasks-count,taskScroll+count) end,P.tint,P.ink)
  end
end
local function drawPopup(entries)
  local width=math.min(27,W-2)
  local count=math.min(#entries,H-3)
  if count<=0 then overlay=nil; return end
  local paged=#entries>count
  local rows=count+(paged and 1 or 0)
  local scroll=math.max(0,math.min(overlay.scroll or 0,math.max(0,#entries-count)))
  overlay.scroll=scroll
  local x=math.max(1,math.min(overlay.x,W-width+1))
  local y=math.max(1,math.min(overlay.y,H-rows))
  fill(x+1,y+1,width,math.min(rows,H-y-1),P.border)
  fill(x,y,width,rows,P.paper)
  for i=1,count do
    local entry=entries[i+scroll]
    if entry then
      line(x+1,y+i-1,clip(locale.text(entry[1]),width-2),entry[1]=="Delete permanently" and P.danger or P.ink,P.paper)
      hit(overlayHits,x,y+i-1,width,1,function() overlay=nil; entry[2]() end)
    end
  end
  if paged then
    btn(overlayHits,x+1,y+count,"<",function() overlay.scroll=math.max(0,scroll-count) end,P.tint,P.ink)
    line(x+4,y+count,(scroll+1).."/"..#entries,P.muted,P.paper)
    btn(overlayHits,x+width-2,y+count,">",function() overlay.scroll=math.min(#entries-count,scroll+count) end,P.tint,P.ink)
  end
end
local function drawContext()
  local item=overlay.item
  local entries={}
  if item then
    entries[#entries+1]={"Open",function() openIcon(item) end}
    if item.kind=="app" then
      local shown=layout.visible(item.app.id)
      entries[#entries+1]={shown and "Remove shortcut" or "Pin to desktop",function()
        layout.setVisible(item.app.id,not shown); desktopDirty=true
      end}
    else
      entries[#entries+1]={"Copy",function() copyDesktop(item.name,"copy") end}
      entries[#entries+1]={"Cut",function() copyDesktop(item.name,"cut") end}
      entries[#entries+1]={"Rename",function() renameItem(item.name) end}
      entries[#entries+1]={"Move to Trash",function() deleteItem(item.name) end}
      if not item.dir then entries[#entries+1]={"Send over network",function() openApp("network",{file=fs.combine(desktop.path,item.name)}) end} end
    end
  end
  entries[#entries+1]={"Paste",pasteDesktop}
  entries[#entries+1]={"New folder",function() createItem(true) end}
  entries[#entries+1]={"New file",function() createItem(false) end}
  entries[#entries+1]={"Trash",function() openApp("files",{trash=true}) end}
  entries[#entries+1]={"Refresh",function() pollDesktop(); refresh(); desktopDirty=true end}
  drawPopup(entries)
end
local function drawAppMenu()
  local owner=overlay.owner
  if not owner or owner.closed then overlay=nil; return end
  local entries={}
  for _,item in ipairs(overlay.entries or {}) do
    if type(item.label)=="string" and type(item.action)=="function" then
      entries[#entries+1]={item.label,function() process:action(owner,item.action) end}
    end
  end
  drawPopup(entries)
end
local function drawOverlay()
  overlayHits={}
  if not overlay then return end
  if overlay.kind=="menu" then drawMenu()
  elseif overlay.kind=="tasks" then drawTasks()
  elseif overlay.kind=="context" then drawContext()
  elseif overlay.kind=="appMenu" then drawAppMenu() end
end
local function drawModal()
  modalHits={}
  if not modal then return end
  local width=math.min(W-4,45)
  local x=math.floor((W-width)/2)+1
  local y=math.floor((H-6)/2)+1
  fill(x+1,y+1,width,6,P.border)
  fill(x,y,width,6,P.paper)
  fill(x,y,width,1,P.accent)
  line(x+1,y,clip(locale.text(modal.label),width-2),P.paper,P.accent)
  if not modal.confirm then
    fill(x+1,y+2,width-2,1,P.tint)
    local v=modal.secret and string.rep("*",#modal.value) or locale.render(modal.value)
    line(x+1,y+2,v:sub(math.max(1,#v-width+3)),P.ink,P.tint)
  end
  button(modalHits,x+1,y+4," OK ",modalDone,P.accent,P.paper)
  button(modalHits,x+7,y+4," Cancel ",function() modal=nil end,P.tint,P.ink)
end
local function draw()
  W,H=host.getSize()
  if frame:resize(W,H) then
    desktopLayer.reposition(1,1,W,H)
    wallpaperLayer.reposition(1,1,W,H)
    desktopDirty=true; wallpaperDirty=true
  end
  canvas=frame.buffer
  if wm.W~=W or wm.H~=H then wm:screen(W,H) end
  if activePalette~=themeIndex then
    palette.apply(host,themeIndex)
    activePalette=themeIndex
    desktopDirty=true; wallpaperDirty=true
  end
  if W<26 or H<12 then
    canvas.setBackgroundColor(P.earth); canvas.clear()
    line(1,1,"Resize to 26 x 12",P.ink,P.earth)
    frame:flush(); frame:setCursor(nil,nil,nil,false)
    return
  end
  paintDesktop()
  local visible={}
  for _,win in ipairs(wm.windows) do if not win.minimized then visible[#visible+1]=win end end
  for _,win in ipairs(visible) do if not win.closed then compose(win) end end
  drawBar()
  if notice~="" and os.clock()<=noticeUntil then
    local msg=clip(locale.text(notice),math.min(W-4,32))
    local width=#msg+2
    fill(W-width,H-2,width,1,P.deep)
    line(W-width+1,H-2,msg,P.paper,P.deep)
  end
  drawOverlay()
  drawModal()
  frame:flush()
  local win=wm.focused
  if win and win.session and not win.minimized and not overlay and not modal then
    local view=win.session.view
    local x,y=view.getCursorPos()
    if x>=1 and y>=1 and x<=win.w-2 and y<=win.h-2 then
      frame:setCursor(win.x+x,win.y+y,view.getTextColor(),view.getCursorBlink())
      return
    end
  end
  frame:setCursor(nil,nil,nil,false)
end
local function inputEvent(e)
  return e=="char" or e=="paste" or e=="key" or e=="key_up" or e:sub(1,6)=="mouse_"
end
local function insertModal(text)
  if modal.replace then modal.value=""; modal.replace=false end
  modal.value=modal.value..text
end
local function handleModal(e,a,b,c)
  if e=="mouse_click" and a==1 then
    local t=locate(modalHits,b,c)
    if t then safe(t.fn) end
  elseif (e=="char" or e=="paste") and not modal.confirm then
    if e=="paste" and os.clock()<skipPasteUntil then return end
    if e=="paste" or not ctrlDown then insertModal(a) end
  elseif e=="key" then
    if a==keys.escape then modal=nil
    elseif a==keys.enter then modalDone()
    elseif not modal.confirm then
      if ctrlDown and a==keys.a then modal.replace=true
      elseif ctrlDown and a==keys.c and not modal.secret then clipboard:setText(modal.value)
      elseif ctrlDown and a==keys.x and not modal.secret then clipboard:setText(modal.value); modal.value=""; modal.replace=false
      elseif ctrlDown and a==keys.v then
        local payload=clipboard:getText()
        if payload then insertModal(payload); skipPasteUntil=os.clock()+0.18 end
      elseif a==keys.backspace then
        if modal.replace then modal.value=""; modal.replace=false
        else
          local ok,pos=pcall(utf8.offset,modal.value,-1)
          modal.value=modal.value:sub(1,ok and pos and pos-1 or -2)
        end
      end
    end
  end
end
local function handleOverlay(e,a,b,c)
  if e=="key" and a==keys.escape then overlay=nil; return true end
  if overlay.kind=="menu" then
    if e=="char" or e=="paste" then
      menuQuery=(menuQuery..a):sub(1,80); menuPage=1; return true
    elseif e=="key" and a==keys.backspace then
      local ok,pos=pcall(utf8.offset,menuQuery,-1)
      menuQuery=menuQuery:sub(1,ok and pos and pos-1 or -2); menuPage=1; return true
    elseif e=="key" and a==keys.enter and menuQuery~="" then
      local matches=menuApps()
      if #matches>0 then openApp(matches[1]) end
      return true
    end
  end
  if e=="mouse_click" then
    local t=locate(barHits,b,c) or locate(overlayHits,b,c)
    if t and a==1 then safe(t.fn)
    elseif t and a==2 and type(t.kind)=="table" then contextMenu(b,c,t.kind)
    else overlay=nil end
    return true
  end
  if e=="mouse_scroll" and overlay.kind=="tasks" then taskScroll=math.max(0,taskScroll+a)
  elseif e=="mouse_scroll" and overlay.kind=="menu" then menuPage=math.max(1,menuPage+a)
  elseif e=="mouse_scroll" and (overlay.kind=="context" or overlay.kind=="appMenu") then overlay.scroll=math.max(0,(overlay.scroll or 0)+a) end
  return true
end
local function sendMouse(win,e,a,b,c)
  local x,y=b-win.x,c-win.y
  if x>=1 and x<=win.w-2 and y>=1 and y<=win.h-2 then
    if e=="mouse_click" and a==1 and process:click(win,x,y) then return end
    process:event(win,e,a,x,y)
  end
end
local function windowClick(win,a,b,c)
  focus(win)
  if c==win.y and a==1 then
    local right=win.x+win.w
    if b>=right-3 then closeWindow(win)
    elseif b>=right-6 then wm:toggleMax(win)
    elseif b>=right-9 then wm:minimize(win)
    elseif not win.maximized then
      drag={win=win,kind="move",sx=b,sy=c,x=win.x,y=win.y}
    end
  elseif a==1 and not win.maximized and b==win.x+win.w-1 and c==win.y+win.h-1 then
    drag={win=win,kind="resize",sx=b,sy=c,w=win.w,h=win.h}
  else sendMouse(win,"mouse_click",a,b,c) end
end
local function handleInput(e,a,b,c)
  if e=="mouse_click" or (e=="key" and a~=keys.v) then skipPasteUntil=0 end
  if e=="key" or e=="key_up" then
    local down=e=="key"
    if a==keys.leftCtrl or a==keys.rightCtrl then ctrlDown=down
    elseif a==keys.leftShift or a==keys.rightShift then shiftDown=down end
  end
  if modal then handleModal(e,a,b,c); return end
  if e=="paste" and os.clock()<skipPasteUntil then return end
  if e=="key" and (a==keys.leftAlt or a==keys.rightAlt) then altDown=true end
  if e=="key_up" and (a==keys.leftAlt or a==keys.rightAlt) then altDown=false end
  if e=="key" and a==keys.tab and altDown then overlay=nil; wm:cycle(); if wm.focused then wm.focused.dirty=true end; return end
  if overlay then handleOverlay(e,a,b,c); return end
  if e=="mouse_drag" and drag then
    if drag.kind=="icon" then
      drag.moved=true
      drag.slot=locate(iconSlots,b,c)
    else
      local win=drag.win
      if drag.kind=="move" then wm:move(win,drag.x+b-drag.sx,drag.y+c-drag.sy)
      else wm:resize(win,drag.w+b-drag.sx,drag.h+c-drag.sy) end
    end
    return
  end
  if e=="mouse_up" and drag then
    if drag.kind=="icon" and drag.moved then
      local slot=locate(iconSlots,b,c)
      if slot then layout.move(desktopItems,drag.key,slot.index); desktopDirty=true end
      lastClick=nil
    end
    drag=nil
    return
  end
  if e=="mouse_click" then
    drag=nil
    local bar=locate(barHits,b,c)
    if bar then lastClick=nil; if a==1 then safe(bar.fn) end; return end
    local win=wm:hit(b,c)
    if win then lastClick=nil; windowClick(win,a,b,c); return end
    wm.focused=nil
    local t=locate(desktopHits,b,c)
    if a==1 and t then
      if type(t.kind)=="table" then
        if not clickIcon(t.kind) then drag={kind="icon",key=t.kind.key,sx=b,sy=c} end
      else safe(t.fn) end
    elseif a==2 and c<H then contextMenu(b,c,t and t.kind)
    elseif a==1 then selectedKey=nil; lastClick=nil; desktopDirty=true end
    return
  end
  if e:sub(1,6)=="mouse_" then
    local win=wm:hit(b,c)
    if win then sendMouse(win,e,a,b,c)
    elseif e=="mouse_scroll" then filePage=math.max(1,filePage+a); desktopDirty=true end
    return
  end
  local win=wm.focused
  if win then
    if win.session and e=="key" and ctrlDown and a==keys.v and clipboard:getText() then
      process:event(win,"paste",clipboard:getText())
      skipPasteUntil=os.clock()+0.18
    else process:event(win,e,a,b,c) end
  elseif e=="key" and ctrlDown and a==keys.v then pasteDesktop()
  elseif e=="key" and ctrlDown and shiftDown and a==keys.n then createItem(true)
  elseif e=="key" and selectedKey and selectedKey:sub(1,5)=="file:" and
      ((ctrlDown and (a==keys.c or a==keys.x)) or a==keys.delete or a==keys.f2) then
    local name=selectedKey:sub(6)
    if a==keys.delete then deleteItem(name)
    elseif a==keys.f2 then renameItem(name)
    else copyDesktop(name,a==keys.c and "copy" or "cut") end
  elseif e=="key" and a==keys.enter and selectedKey then
    for _,item in ipairs(desktopItems) do if item.key==selectedKey then openIcon(item); break end end
  elseif e=="key" and a==keys.escape then overlay={kind="menu"}; menuQuery=""; menuPage=1 end
end
local function fileTransfer(transfer)
  local win=wm.focused
  local destination=desktop.path
  local explorer
  if win and win.trusted and not win.minimized and not win.session and win.instance and win.instance.dropTarget then
    local ok,path=pcall(win.instance.dropTarget,win.ctx)
    if ok and type(path)=="string" then destination=path; explorer=win end
  end
  local ok,saved,errors=pcall(desktop.receive,transfer,destination)
  if not ok then message("Transfer failed: "..tostring(saved)); return end
  if #saved>0 then
    if fileops.path(destination)==desktop.path then selectFile(saved[#saved]) end
    pollDesktop()
    message(locale.raw("Received")..": "..#saved..(#errors>0 and (" / "..locale.raw("Failed")..": "..#errors) or ""))
  elseif #errors>0 then message(errors[1]) end
  if explorer and not explorer.closed then
    explorer.dirty=true
    if explorer.instance.onFilesReceived then
      process:action(explorer,explorer.instance.onFilesReceived,explorer.ctx,destination,saved,errors)
    end
  end
end
local function run()
  journal("desktop","start","0.9.1")
  refresh()
  pollDesktop()
  local netRevision=network.revision
  timer=os.startTimer(1)
  local previousClock=clock()
  local nextScan=os.clock()+10
  local redraw=true
  while running do
    for _,win in ipairs(wm:tasks()) do if process:reap(win) then redraw=true end end
    if redraw then draw(); redraw=false end
    local packet=table.pack(os.pullEventRaw())
    local e,a,b,c,d=table.unpack(packet,1,5)

    if e=="timer" and a==timer then
      timer=os.startTimer(1)

      local now=clock()
      if now~=previousClock then previousClock=now; redraw=true end
      if notice~="" and os.clock()>noticeUntil then notice=""; redraw=true end
      if os.clock()>=nextScan then
        local before=fileSignature; pollDesktop(); nextScan=os.clock()+10
        if before~=fileSignature then redraw=true end
      end
      for _,win in ipairs(wm.windows) do
        if not win.minimized and win.instance and win.instance.refresh==true then win.dirty=true; redraw=true end
      end
    end
    if e=="system_notice" then message(a); redraw=true
    elseif e=="juzeppe_ready" then process:pump(); redraw=true
    elseif e=="juzeppe_packages_changed" then refresh(); redraw=true
    elseif e=="file_transfer" then fileTransfer(a); redraw=true
    elseif e=="terminate" then
      redraw=true
      if modal then modal=nil
      elseif wm.focused and (wm.focused.session or wm.focused.worker) then process:event(wm.focused,e)
      else running=false end
    elseif e=="term_resize" then
      redraw=true
      W,H=host.getSize()
      wm:screen(W,H)
      for _,win in ipairs(wm:tasks()) do process:resize(win) end
    elseif inputEvent(e) then
      if W>=26 and H>=12 then handleInput(e,a,b,c); redraw=true end
    else
      if process:jobEvent(table.unpack(packet,1,packet.n)) then redraw=true end
      for _,win in ipairs(wm:tasks()) do if process:event(win,table.unpack(packet,1,packet.n)) then redraw=true end end
    end
    if netRevision~=network.revision then
      netRevision=network.revision
      pollDesktop()
      for _,win in ipairs(wm:tasks()) do
        if win.app.id=="network" then win.dirty=true end
        process:event(win,"juzeppe_network",netRevision)
      end
      redraw=true
    end
  end
end
local ok,err=xpcall(run,function(e) journal('kernel','run',e,coroutine.running()); return e end)

for _,win in ipairs(wm:tasks()) do process:close(win) end
if timer then os.cancelTimer(timer) end
term.redirect(host)
palette.restore(host,original)
host.setBackgroundColor(colors.black)
host.setTextColor(colors.white)
host.clear()
host.setCursorPos(1,1)
if not ok then error(err,0) end
return desktopExit
]=],
    ["system/desktop-layout.lua"]=[=[
local U=assert(loadfile("/juzeppe/system/util.lua","t",_ENV))()
local M={}
local path="/juzeppe/config/desktop-layout.json"
local prefs=U.json(path) or {}
if type(prefs.hidden)~="table" then prefs.hidden={} end
if type(prefs.order)~="table" then prefs.order={} end
local function save()
  U.write(path,U.encode(prefs))
end
function M.visible(id) return not prefs.hidden[id] end
function M.setVisible(id,visible)
  prefs.hidden[id]=not visible or nil
  save()
end
function M.items(apps,files)
  local all,byKey={},{}
  local function add(item)
    byKey[item.key]=item
    all[#all+1]=item
  end
  for _,app in ipairs(apps) do
    if M.visible(app.id) then add({key="app:"..app.id,kind="app",app=app}) end
  end
  for _,file in ipairs(files) do
    add({key="file:"..file.name,kind="file",name=file.name,dir=file.dir})
  end
  local sorted,seen={},{}
  for _,key in ipairs(prefs.order) do
    if byKey[key] and not seen[key] then sorted[#sorted+1]=byKey[key]; seen[key]=true end
  end
  for _,item in ipairs(all) do
    if not seen[item.key] then sorted[#sorted+1]=item end
  end
  return sorted
end
function M.move(items,key,index)
  local order,source={},nil
  for _,item in ipairs(items) do
    if item.key==key then source=item.key else order[#order+1]=item.key end
  end
  if not source then return end
  index=math.max(1,math.min(#order+1,index))
  table.insert(order,index,source)
  prefs.order=order
  save()
end
return M
]=],
    ["system/desktop.lua"]=[=[
local M={path="/juzeppe/desktop"}
local function ensure()
  if not fs.exists(M.path) then fs.makeDir(M.path) end
end
function M.validName(name)
  return type(name)=="string" and #name>0 and #name<=128
    and name~="." and name~=".." and not name:find("[/\\]") and not name:find("[%z\1-\31\127]")
    and name:match("%S")~=nil
end
function M.list()
  ensure()
  local result=fs.list(M.path)
  local types={}
  for _,n in ipairs(result) do types[n]=fs.isDir(fs.combine(M.path,n)) end
  table.sort(result,function(a,b)
    local da,db=types[a],types[b]
    if da~=db then return da end
    return a:lower()<b:lower()
  end)
  return result,types
end
function M.make(parent,name,isDir)
  ensure()
  if not M.validName(name) then return nil,"Invalid file name" end
  local path=fs.combine(parent,name)
  if fs.exists(path) then return nil,"Name already exists" end
  if fs.isReadOnly(parent) then return nil,"Read-only folder" end
  local ok,err=pcall(function()
    if isDir then fs.makeDir(path)
    else
      local handle,why=fs.open(path,"w")
      if not handle then error(why or "Cannot write file",0) end
      handle.close()
    end
  end)
  if not ok then return nil,tostring(err) end
  return path
end
function M.rename(name,newName)
  if not M.validName(name) or not M.validName(newName) then return nil,"Invalid file name" end
  local old,new=fs.combine(M.path,name),fs.combine(M.path,newName)
  if old==new then return new end
  if not fs.exists(old) then return nil,"File not found" end
  if fs.exists(new) then return nil,"Name already exists" end
  local ok,err=pcall(fs.move,old,new)
  if not ok then return nil,tostring(err) end
  return new
end
function M.remove(name)
  if not M.validName(name) then return nil,"Invalid file name" end
  local path=fs.combine(M.path,name)
  if not fs.exists(path) then return nil,"File not found" end
  local ok,err=pcall(fs.delete,path)
  if not ok then return nil,tostring(err) end
  return true
end
local function unique(parent,name)
  local stem,ext=name:match("^(.*)(%.[^%.]+)$")
  if not stem or stem=="" then stem,ext=name,"" end
  local result=name
  local number=2
  while fs.exists(fs.combine(parent,result)) do
    result=stem.." ("..number..")"..ext
    number=number+1
  end
  return result
end
-- Default to the desktop; a focused file browser may supply a destination.
-- Copy to a staging file first so an interrupted write cannot expose a partial item.
function M.receive(transfer,destination)
  ensure()
  local saved,errors={},{}
  if not transfer or type(transfer.getFiles)~="function" then return saved,{"Invalid transfer"} end
  local ok,files=pcall(transfer.getFiles)
  if not ok or type(files)~="table" then return saved,{"Invalid transfer"} end
  local parent="/"..fs.combine("/",destination or M.path):gsub("^/+","")
  if not fs.exists(parent) or not fs.isDir(parent) or fs.isReadOnly(parent) then
    for _,incoming in ipairs(files) do if incoming.close then pcall(incoming.close) end end
    return saved,{fs.exists(parent) and fs.isDir(parent) and "Read-only folder" or "Folder not found"}
  end
  for _,incoming in ipairs(files) do
    local handle,temp,name
    local good,err=pcall(function()
      name=tostring(incoming.getName()):gsub("\\","/"):match("([^/]+)$")
      if not M.validName(name) then error("Invalid file name",0) end
      name=unique(parent,name)
      temp=fs.combine(parent,".juz-incoming")
      local i=2
      while fs.exists(temp) or temp==fs.combine(parent,name) do temp=fs.combine(parent,".juz-incoming-"..i); i=i+1 end
      local why
      handle,why=fs.open(temp,"wb")
      if not handle then error(why or "Cannot write file",0) end
      if incoming.read then
        while true do
          local chunk=incoming.read(8192)
          if chunk==nil or chunk=="" then break end
          if type(chunk)=="number" then chunk=string.char(chunk) end
          handle.write(chunk)
        end
      else
        local chunk=incoming.readAll()
        if chunk then handle.write(chunk) end
      end
      handle.close()
      handle=nil
      fs.move(temp,fs.combine(parent,name))
      temp=nil
    end)
    if handle then pcall(handle.close) end
    if incoming.close then pcall(incoming.close) end
    if temp and fs.exists(temp) then pcall(fs.delete,temp) end
    if good then saved[#saved+1]=name
    else errors[#errors+1]=(name or "file")..": "..tostring(err) end
  end
  return saved,errors
end
return M

]=],
    ["system/fileops.lua"]=[=[
local U=assert(loadfile("/juzeppe/system/util.lua","t",_ENV))()
local desktop=assert(loadfile("/juzeppe/system/desktop.lua","t",_ENV))()
local M={trashPath="/juzeppe/trash"}
local serial=0
function M.path(p)
  return "/"..fs.combine("/",p or ""):gsub("^/+","")
end
function M.inside(path,parent)
  path,parent=M.path(path),M.path(parent)
  return path==parent or parent=="/" or path:sub(1,#parent+1)==parent.."/"
end
function M.unique(parent,name)
  local path=M.path(fs.combine(parent,name))
  if not fs.exists(path) then return path end
  local stem,ext=name:match("^(.*)(%.[^%.]+)$")
  if not stem or stem=="" then stem,ext=name,"" end
  local n=2
  repeat
    path=M.path(fs.combine(parent,stem.." ("..n..")"..ext))
    n=n+1
  until not fs.exists(path)
  return path
end
local function temporary(parent)
  local candidate
  repeat
    serial=serial+1
    candidate=M.path(fs.combine(parent,".juz-copy-"..serial))
  until not fs.exists(candidate)
  return candidate
end
local function validate(source,dest)
  if source=="/" or not fs.exists(source) then return nil,"File not found" end
  if fs.exists(dest) then return nil,"Name already exists" end
  local parent=M.path(fs.getDir(dest))
  if not fs.exists(parent) or not fs.isDir(parent) then return nil,"Folder not found" end
  if fs.isReadOnly(parent) then return nil,"Read-only folder" end
  if fs.isDir(source) and M.inside(dest,source) then return nil,"Cannot place folder inside itself" end
  return true
end
function M.copy(source,dest)
  source,dest=M.path(source),M.path(dest)
  local valid,why=validate(source,dest)
  if not valid then return nil,why end
  local temp=temporary(M.path(fs.getDir(dest)))
  local ok,err=pcall(function()
    fs.copy(source,temp)
    fs.move(temp,dest)
  end)
  if not ok then
    if fs.exists(temp) then pcall(fs.delete,temp) end
    return nil,tostring(err)
  end
  return dest
end
function M.move(source,dest)
  source,dest=M.path(source),M.path(dest)
  if source==dest and fs.exists(source) then return dest end
  local valid,why=validate(source,dest)
  if not valid then return nil,why end
  if fs.isReadOnly(source) then return nil,"Read-only file" end
  local ok,err=pcall(fs.move,source,dest)
  if ok then return dest end
  -- Copy across drives before attempting deletion. Preserve both on deletion failure.
  if fs.exists(dest) or not fs.exists(source) then return nil,tostring(err) end
  local copied,copyError=M.copy(source,dest)
  if not copied then return nil,copyError end
  local deleted,deleteError=pcall(fs.delete,source)
  if not deleted then return nil,"Copied; source kept: "..tostring(deleteError) end
  return dest
end
function M.rename(source,name)
  if not desktop.validName(name) then return nil,"Invalid file name" end
  return M.move(source,fs.combine(fs.getDir(source),name))
end
local function ensureTrash()
  if not fs.exists(M.trashPath) then fs.makeDir(M.trashPath) end
end
local function validID(id)
  return type(id)=="string" and id:match("^%d+%-%d+$")~=nil
end
local function entry(id)
  if not validID(id) then return nil end
  local folder=fs.combine(M.trashPath,id)
  local meta=U.json(fs.combine(folder,"meta.json"))
  local data=fs.combine(folder,"data")
  if type(meta)~="table" or type(meta.original)~="string" or not fs.exists(data) then return nil end
  local original=M.path(meta.original)
  if original=="/" or M.inside(original,M.trashPath) then return nil end
  return {id=id,original=original,name=fs.getName(original),dir=fs.isDir(data),data=M.path(data),time=tonumber(meta.time) or 0}
end
function M.trash(source)
  source=M.path(source)
  if source=="/" or M.inside(source,M.trashPath) or M.inside(M.trashPath,source) then return nil,"Cannot trash this folder" end
  if not fs.exists(source) then return nil,"File not found" end
  if fs.isReadOnly(source) then return nil,"Read-only file" end
  ensureTrash()
  local id,folder
  repeat
    serial=serial+1
    id=tostring(os.epoch("utc")).."-"..serial
    folder=fs.combine(M.trashPath,id)
  until not fs.exists(folder)
  local ok,err=pcall(fs.makeDir,folder)
  if not ok then return nil,tostring(err) end
  local wrote,why=U.write(fs.combine(folder,"meta.json"),U.encode({original=source,time=os.epoch("utc")}))
  if not wrote then pcall(fs.delete,folder); return nil,why end
  local moved,errorText=M.move(source,fs.combine(folder,"data"))
  if not moved then
    -- A cross-drive move may have preserved a second copy. Keep it recoverable.
    if not fs.exists(fs.combine(folder,"data")) then pcall(fs.delete,folder) end
    return nil,errorText
  end
  return id
end
function M.trashList()
  ensureTrash()
  local result={}
  for _,id in ipairs(fs.list(M.trashPath)) do
    local item=entry(id)
    if item then result[#result+1]=item end
  end
  table.sort(result,function(a,b) return a.time>b.time end)
  return result
end
function M.restore(id)
  local item=entry(id)
  if not item then return nil,"File not found" end
  local parent=M.path(fs.getDir(item.original))
  if not fs.exists(parent) then
    local ok,err=pcall(fs.makeDir,parent)
    if not ok then return nil,tostring(err) end
  end
  local dest=M.unique(parent,item.name)
  local moved,err=M.move(item.data,dest)
  if not moved then return nil,err end
  pcall(fs.delete,fs.combine(M.trashPath,id))
  return dest
end
function M.destroy(id)
  if not entry(id) then return nil,"File not found" end
  local ok,err=pcall(fs.delete,fs.combine(M.trashPath,id))
  if not ok then return nil,tostring(err) end
  return true
end
return M
]=],
    ["system/locale.lua"]=[=[
local U=assert(loadfile("/juzeppe/system/util.lua","t",_ENV))()
local M={}
local path="/juzeppe/config/language"
local dict=U.json("/juzeppe/system/ru.json") or {}
local translit=U.json("/juzeppe/system/translit.json") or {}
M.mode=U.read(path) or "en"
if M.mode~="ru" and M.mode~="translit" then M.mode="en" end
function M.set(mode)
  if mode~="ru" and mode~="translit" and mode~="en" then return end
  M.mode=mode
  U.write(path,mode)
end
function M.raw(key)
  return M.mode=="en" and key or (dict[key] or key)
end
function M.render(s)
  s=tostring(s)
  -- UTF-8 Russian strings become Windows-1251 terminal glyphs.
  return (s:gsub("[\194-\244][\128-\191]+",function(ch)
    if M.mode~="ru" then return translit[ch] or "?" end
    local ok,n=pcall(utf8.codepoint,ch)
    if not ok then return "?" end
    if n>=1040 and n<=1103 then return string.char(n-848) end
    if n==1025 then return string.char(168) end
    if n==1105 then return string.char(184) end
    return translit[ch] or "?"
  end))
end
function M.text(key) return M.render(M.raw(key)) end
function M.name(m)
  return M.render(M.mode=="en" and m.name or (m.name_ru or m.name))
end
function M.detail(m)
  return M.render(M.mode=="en" and (m.description or "") or (m.description_ru or m.description or ""))
end
function M.short(m)
  return M.render(M.mode=="en" and (m.short or m.name) or (m.short_ru or m.name_ru or m.short or m.name))
end
return M
]=],
    ["system/network.lua"]=[=[
local U=assert(loadfile("/juzeppe/system/util.lua","t",_ENV))()
local auth=assert(loadfile("/juzeppe/system/auth.lua","t",_ENV))()
local b64=assert(loadfile("/juzeppe/system/base64.lua","t",_ENV))()
local ops=assert(loadfile("/juzeppe/system/fileops.lua","t",_ENV))()
local desktop=assert(loadfile("/juzeppe/system/desktop.lua","t",_ENV))()
local M={protocol="juzeppe.net.1",maxFile=512*1024,chunk=4096,received="/juzeppe/desktop/Received",shared="/juzeppe/shared"}
local function integer(n,min,max)
  return type(n)=="number" and n%1==0 and n>=min and n<=max
end
local function validID(n) return integer(n,0,2147483647) end
local function validRef(s)
  return type(s)=="string" and #s<=80 and s:match("^[%d%-]+$")~=nil
end
local function validName(s)
  return type(s)=="string" and #s>0 and #s<=64 and not s:find("[%z\1-\31\127]")
end
local function validText(s)
  return type(s)=="string" and #s>0 and #s<=1024
end
local function transport()
  local owned={}
  local names={}
  return {
    scan=function()
      names={}
      if not peripheral or not rednet then return 0 end
      for _,name in ipairs(peripheral.getNames()) do
        local ok,modem=pcall(peripheral.getType,name)
        if ok and modem=="modem" then
          local was=rednet.isOpen(name)
          if was or pcall(rednet.open,name) then
            if rednet.isOpen(name) then
              names[#names+1]=name
              if not was then owned[name]=true end
            end
          end
        end
      end
      return #names
    end,
    send=function(peer,packet)
      if peer==-1 then rednet.broadcast(packet,M.protocol); return true end
      return rednet.send(peer,packet,M.protocol)
    end,
    close=function()
      if rednet then for name in pairs(owned) do pcall(rednet.close,name) end end
      owned={}; names={}
    end
  }
end
local function canonical(p)
  return table.concat({tostring(p.v),tostring(p.from),tostring(p.to),p.kind,p.id,tostring(p.time),tostring(#p.body),p.body},"|")
end
local function array(v) return type(v)=="table" and v or {} end
local function ensure(path)
  if not fs.exists(path) then fs.makeDir(path) end
end
-- Replace persistent documents only after the new contents were written.
local function recoverDocument(path)
  local backup,temp=path..".bak",path..".new"
  if fs.exists(backup) and not fs.exists(path) then fs.move(backup,path) end
  if fs.exists(backup) and fs.exists(path) then fs.delete(backup) end
  if fs.exists(temp) then fs.delete(temp) end
end
local function loadDocument(path)
  pcall(recoverDocument,path)
  return U.json(path)
end
local function saveDocument(path,value)
  local backup,temp=path..".bak",path..".new"
  local ok,err=pcall(function()
    recoverDocument(path)
    local written,why=U.write(temp,U.encode(value))
    if not written then error(why or "Cannot save network data",0) end
    if fs.exists(path) then fs.move(path,backup) end
    fs.move(temp,path)
    if fs.exists(backup) then fs.delete(backup) end
  end)
  if not ok then
    pcall(function()
      if not fs.exists(path) and fs.exists(backup) then fs.move(backup,path) end
      if fs.exists(temp) then fs.delete(temp) end
    end)
    return nil,tostring(err)
  end
  return true
end
function M.new(options)
  options=options or {}
  local self={id=options.id or os.getComputerID(),root=options.root or "/juzeppe/network",
    transport=options.transport or transport(),clock=options.clock or function() return os.epoch("utc")/1000 end,
    notify=options.notify or function() end,peers={},pending={},transfers={},shares={},seen={},seenOrder={},
    serial=0,boot=math.random(100000,999999),modems=0,nextHello=0,revision=0}
  self.receivedPath=options.receivedPath or M.received
  self.sharedPath=options.sharedPath or M.shared
  ensure(self.root)
  local configPath=self.root.."/config.json"
  local historyPath=self.root.."/history.json"
  local mailboxPath=self.root.."/mailbox.json"
  local peersPath=self.root.."/devices.json"
  local stage=self.root.."/incoming"
  ensure(stage)
  -- Incomplete transfers cannot survive a reboot; finished files never live here.
  for _,name in ipairs(fs.list(stage)) do
    if validRef(name) then pcall(fs.delete,fs.combine(stage,name)) end
  end
  self.config=loadDocument(configPath) or {}
  local c=self.config
  c.name=validName(c.name) and c.name or ("JUZ-"..self.id)
  c.key=type(c.key)=="string" and #c.key>=8 and #c.key<=128 and c.key or ""
  c.enabled=c.enabled==true and c.key~=""
  c.hub=c.hub==true
  c.hubID=validID(c.hubID) and c.hubID or -1
  self.history=array(loadDocument(historyPath))
  self.mailbox=array(loadDocument(mailboxPath))
  local function changed()
    self.revision=self.revision+1
  end
  local function addHistory(record)
    local nextHistory={}
    for i=math.max(1,#self.history-178),#self.history do nextHistory[#nextHistory+1]=self.history[i] end
    nextHistory[#nextHistory+1]=record
    local ok,err=saveDocument(historyPath,nextHistory)
    if not ok then return nil,err end
    self.history=nextHistory
    changed()
    return true
  end
  local function saveHistory()
    local ok,err=saveDocument(historyPath,self.history)
    changed()
    return ok,err
  end
  local function saveMailbox() return saveDocument(mailboxPath,self.mailbox) end
  local function group()
    return c.key~="" and auth.sha256(c.key) or ""
  end
  self.group=group()
  self.sign=c.key~="" and auth.signer(c.key) or nil
  local known=loadDocument(peersPath) or {}
  if known.group==self.group then
    for _,p in ipairs(array(known.devices)) do
      if validID(p.id) and p.id~=self.id and validName(p.name) then
        self.peers[p.id]={id=p.id,name=p.name,hub=p.hub==true,last=0}
      end
    end
  end
  local function savePeers()
    local result={}
    for _,p in pairs(self.peers) do result[#result+1]={id=p.id,name=p.name,hub=p.hub} end
    saveDocument(peersPath,{group=self.group,devices=result})
  end
  local function token()
    self.serial=self.serial+1
    return self.id.."-"..math.floor(self.clock()*1000).."-"..self.boot.."-"..self.serial
  end
  local function send(peer,kind,data)
    if not c.enabled or self.modems==0 or not self.sign then return nil,"Network unavailable" end
    local body=U.encode(data)
    if #body>12000 then return nil,"Packet too large" end
    local p={v=1,from=self.id,to=peer,kind=kind,id=token(),time=math.floor(self.clock()),body=body}
    p.sig=self.sign(canonical(p))
    local ok,result=pcall(self.transport.send,peer,p)
    if not ok or result==false then return nil,"Network send failed" end
    return true
  end
  local function label(id)
    return self.peers[id] and self.peers[id].name or ("#"..id)
  end
  local function online(p)
    return p.last>0 and self.clock()-p.last<=35
  end
  local function register(id,name,hub)
    local p=self.peers[id]
    if not p and #self:devices()>=128 then return false end
    local update=not p or p.name~=name or p.hub~=hub
    if not p then p={id=id}; self.peers[id]=p end
    p.name,p.hub,p.last=name,hub,self.clock()
    if update then savePeers() end
    changed()
    return true
  end
  function self:devices()
    local list={}
    for _,p in pairs(self.peers) do
      list[#list+1]={id=p.id,name=p.name,hub=p.hub,online=online(p)}
    end
    table.sort(list,function(a,b)
      if a.online~=b.online then return a.online end
      return a.name:lower()==b.name:lower() and a.id<b.id or a.name:lower()<b.name:lower()
    end)
    return list
  end
  local function mailboxCount()
    local n=0
    for _,m in ipairs(self.mailbox) do if m.group==self.group then n=n+1 end end
    return n
  end
  function self:status()
    return {id=self.id,name=c.name,enabled=c.enabled,hub=c.hub,hubID=c.hubID,hasKey=c.key~="",modems=self.modems,
      revision=self.revision,mailbox=mailboxCount(),receivedPath=self.receivedPath,sharedPath=self.sharedPath}
  end
  local function incomingKey(from,ref) return "in:"..from..":"..ref end
  local function outgoingKey(peer,ref) return "out:"..peer..":"..ref end
  local function active(t)
    return t.state=="Offered" or t.state=="Pending" or t.state=="Receiving" or t.state=="Sending"
  end
  local function fail(t,why,inform)
    if t.temp and fs.exists(t.temp) then pcall(fs.delete,t.temp) end
    t.temp=nil
    t.state,t.error="Failed",why
    if inform then send(t.peer,"file_cancel",{ref=t.ref}) end
    changed()
  end
  function self:configure(update)
    update=update or {}
    if update.name~=nil and not validName(update.name) then return nil,"Invalid computer name" end
    if update.key~=nil and (type(update.key)~="string" or #update.key<8 or #update.key>128) then return nil,"Network key must be 8-128 bytes" end
    if update.hubID~=nil and update.hubID~=-1 and not validID(update.hubID) then return nil,"Invalid computer ID" end
    local key=update.key or c.key
    local enabled=c.enabled
    if update.enabled~=nil then enabled=update.enabled==true end
    if enabled and key=="" then return nil,"Set network key first" end
    local nextConfig={}
    for k,v in pairs(c) do nextConfig[k]=v end
    if update.name~=nil then nextConfig.name=update.name end
    if update.hub~=nil then nextConfig.hub=update.hub==true end
    if update.hubID~=nil then nextConfig.hubID=update.hubID end
    nextConfig.key,nextConfig.enabled=key,enabled
    local saved,err=saveDocument(configPath,nextConfig)
    if not saved then return nil,err end
    local changedKey=key~=c.key
    for k,v in pairs(nextConfig) do c[k]=v end
    if changedKey then
      for _,t in pairs(self.transfers) do if active(t) then fail(t,"Network changed",false) end end
      self.pending={}
      for _,m in ipairs(self.history) do
        if m.direction=="out" and m.state=="Sending" then m.state="Interrupted" end
      end
      saveHistory()
      self.sign=auth.signer(key)
      self.group=group()
      self.peers,self.seen,self.seenOrder={}, {}, {}
      savePeers()
    end
    if enabled then
      self.modems=self.transport.scan()
      self.nextHello=0
      if c.hub then ensure(self.sharedPath) end
      self:announce()
    else
      for _,t in pairs(self.transfers) do if active(t) then fail(t,"Network disabled",false) end end
      self.transport.close()
      self.modems=0
    end
    changed()
    return true
  end
  function self:announce()
    if c.enabled and self.modems>0 then
      send(-1,"hello",{name=c.name,hub=c.hub})
      self.nextHello=self.clock()+10
    end
  end
  function self:start()
    if c.enabled then
      self.modems=self.transport.scan()
      if c.hub then ensure(self.sharedPath) end
      self:announce()
    end
  end
  function self:close()
    for _,t in pairs(self.transfers) do if active(t) then fail(t,"Network stopped",false) end end
    self.transport.close()
    self.modems=0
  end
  function self:messages(peer)
    local result={}
    for _,m in ipairs(self.history) do
      if m.peer==peer then result[#result+1]=m end
    end
    return result
  end
  local function receiveChat(from,name,ref,text)
    for _,m in ipairs(self.history) do
      if m.direction=="in" and m.from==from and m.ref==ref then return true end
    end
    local ok,err=addHistory({direction="in",from=from,peer=from,name=name,ref=ref,text=text,time=self.clock(),state="Received",group=self.group})
    if not ok then self.notify("Could not save message"); return nil,err end
    self.notify("Message from "..name)
    return true
  end
  local function state(ref,status)
    for _,m in ipairs(self.history) do
      if m.direction=="out" and m.ref==ref then m.state=status; saveHistory(); return end
    end
  end
  function self:sendMessage(peer,text)
    if not validID(peer) or peer==self.id then return nil,"Invalid computer ID" end
    if not validText(text) then return nil,"Message must be 1-1024 bytes" end
    local ref=token()
    local routed=validID(c.hubID) and c.hubID~=self.id and c.hubID~=peer
    local route=routed and c.hubID or peer
    local kind=routed and "relay" or "chat"
    local body={ref=ref,text=text,name=c.name,target=peer}
    if not c.enabled or self.modems==0 then return nil,"Network unavailable" end
    local saved,err=addHistory({direction="out",from=self.id,peer=peer,name=label(peer),ref=ref,text=text,time=self.clock(),state="Sending",route=route,group=self.group})
    if not saved then return nil,err end
    self.pending[ref]={peer=route,kind=kind,body=body,last=self.clock(),tries=1}
    local ok,why=send(route,kind,body)
    if not ok then self.pending[ref]=nil; state(ref,"Failed"); return nil,why end
    return ref
  end
  -- A pending outgoing message can be retried after a reboot.
  for _,m in ipairs(self.history) do
    if m.direction=="out" and m.state=="Sending" and m.group==self.group
      and validRef(m.ref) and validID(m.peer) and validID(m.route) and validText(m.text) then
      self.pending[m.ref]={peer=m.route,kind=m.route==m.peer and "chat" or "relay",
        body={ref=m.ref,text=m.text,name=c.name,target=m.peer},last=0,tries=0}
    end
  end
  local function deliver(m)
    if m.group~=self.group then return end
    send(m.target,"relay_message",{ref=m.ref,from=m.from,name=m.name,text=m.text})
    m.last=self.clock()
  end
  local function deliverFor(peer)
    if not c.hub then return end
    for _,m in ipairs(self.mailbox) do if m.target==peer then deliver(m) end end
  end
  local function countActive()
    local n=0
    for _,t in pairs(self.transfers) do if active(t) then n=n+1 end end
    return n
  end
  function self:transfersList()
    local result={}
    for _,t in pairs(self.transfers) do result[#result+1]=t end
    table.sort(result,function(a,b) return a.created==b.created and a.key>b.key or a.created>b.created end)
    return result
  end
  local function prune()
    local list=self:transfersList()
    local keep=0
    for _,t in ipairs(list) do
      if not active(t) then
        keep=keep+1
        if keep>30 then self.transfers[t.key]=nil end
      end
    end
  end
  function self:offerFile(peer,path)
    if not validID(peer) or peer==self.id then return nil,"Invalid computer ID" end
    path=ops.path(path)
    if not fs.exists(path) or fs.isDir(path) then return nil,"Select a file" end
    local size=fs.getSize(path)
    local name=fs.getName(path)
    if size>M.maxFile or not desktop.validName(name) then return nil,"File too large or invalid name" end
    if countActive()>=12 then return nil,"Too many transfers" end
    local ref=token()
    local key=outgoingKey(peer,ref)
    local ok,err=send(peer,"file_offer",{ref=ref,name=name,size=size})
    if not ok then return nil,err end
    self.transfers[key]={key=key,ref=ref,peer=peer,name=name,size=size,path=path,direction="out",state="Offered",
      bytes=0,index=1,created=self.clock(),last=self.clock(),tries=1}
    changed()
    prune()
    return key
  end
  function self:accept(key)
    local t=self.transfers[key]
    if not t or t.direction~="in" or t.state~="Pending" then return nil,"Offer unavailable" end
    ensure(self.receivedPath)
    local temp=fs.combine(stage,token())
    local handle,err=fs.open(temp,"wb")
    if not handle then return nil,err end
    handle.close()
    t.temp=temp
    t.state="Receiving"
    t.last=self.clock()
    t.tries=1
    send(t.peer,"file_accept",{ref=t.ref})
    changed()
    return true
  end
  function self:decline(key)
    local t=self.transfers[key]
    if not t or t.direction~="in" or t.state~="Pending" then return nil,"Offer unavailable" end
    t.state="Declined"
    send(t.peer,"file_decline",{ref=t.ref})
    changed()
    return true
  end
  function self:cancel(key)
    local t=self.transfers[key]
    if not t or not active(t) then return nil,"Transfer unavailable" end
    fail(t,"Cancelled",true)
    return true
  end
  local function chunk(t)
    if not fs.exists(t.path) or fs.isDir(t.path) or fs.getSize(t.path)~=t.size then fail(t,"Source file changed",true); return end
    local f,err=fs.open(t.path,"rb")
    if not f then fail(t,err,true); return end
    local n=math.min(M.chunk,t.size-t.bytes)
    local ok,data=pcall(function()
      f.seek("set",t.bytes)
      return n==0 and "" or f.read(n)
    end)
    f.close()
    if not ok or type(data)~="string" or #data~=n then fail(t,"Cannot read file",true); return end
    t.chunkSize=n
    t.last=self.clock()
    t.tries=(t.tries or 0)+1
    send(t.peer,"file_chunk",{ref=t.ref,index=t.index,data=b64.encode(data)})
  end
  function self:requestShared(peer)
    if not validID(peer) then return nil,"Invalid computer ID" end
    return send(peer,"share_list",{})
  end
  function self:sharedFiles(peer) return self.shares[peer] or {} end
  function self:requestSharedFile(peer,name)
    if not validID(peer) or not desktop.validName(name) then return nil,"Invalid file name" end
    return send(peer,"share_get",{name=name})
  end
  local function handle(from,kind,d)
    if kind=="hello" or kind=="hello_ack" then
      if not validName(d.name) then return end
      register(from,d.name,d.hub==true)
      if kind=="hello" then send(from,"hello_ack",{name=c.name,hub=c.hub}) end
      deliverFor(from)
    elseif kind=="chat" and validRef(d.ref) and validText(d.text) and validName(d.name) then
      if receiveChat(from,d.name,d.ref,d.text) then send(from,"chat_ack",{ref=d.ref,state="Delivered"}) end
    elseif kind=="chat_ack" and validRef(d.ref) then
      local p=self.pending[d.ref]
      if p and p.peer==from and (d.state=="Queued" or d.state=="Delivered" or d.state=="Mailbox full") then
        self.pending[d.ref]=nil
        state(d.ref,d.state)
      end
    elseif kind=="relay" and c.hub and validID(d.target) and d.target~=from and d.target~=self.id and validRef(d.ref) and validText(d.text) and validName(d.name) then
      local found
      for _,m in ipairs(self.mailbox) do if m.from==from and m.ref==d.ref and m.group==self.group then found=m; break end end
      if not found then
        if mailboxCount()>=80 or #self.mailbox>=240 then send(from,"chat_ack",{ref=d.ref,state="Mailbox full"}); return end
        found={group=self.group,from=from,target=d.target,ref=d.ref,text=d.text,name=d.name,last=0}
        self.mailbox[#self.mailbox+1]=found
        if not saveMailbox() then
          table.remove(self.mailbox)
          send(from,"chat_ack",{ref=d.ref,state="Mailbox full"})
          return
        end
      end
      send(from,"chat_ack",{ref=d.ref,state="Queued"})
      deliver(found)
    elseif kind=="relay_message" and from==c.hubID and validID(d.from) and validRef(d.ref) and validText(d.text) and validName(d.name) then
      if receiveChat(d.from,d.name,d.ref,d.text) then send(from,"relay_ack",{ref=d.ref,from=d.from}) end
    elseif kind=="relay_ack" and c.hub and validRef(d.ref) and validID(d.from) then
      for i=#self.mailbox,1,-1 do
        local m=self.mailbox[i]
        if m.group==self.group and m.target==from and m.from==d.from and m.ref==d.ref then
          table.remove(self.mailbox,i)
          if saveMailbox() then send(m.from,"relay_status",{ref=m.ref,state="Delivered"})
          else table.insert(self.mailbox,i,m) end
          break
        end
      end
    elseif kind=="relay_status" and from==c.hubID and validRef(d.ref) and d.state=="Delivered" then state(d.ref,"Delivered")
    elseif kind=="file_offer" and validRef(d.ref) and desktop.validName(d.name) and integer(d.size,0,M.maxFile) then
      local key=incomingKey(from,d.ref)
      if not self.transfers[key] and countActive()<12 then
        self.transfers[key]={key=key,ref=d.ref,peer=from,name=d.name,size=d.size,direction="in",state="Pending",
          bytes=0,index=1,created=self.clock(),last=self.clock(),tries=0}
        changed(); prune(); self.notify("File offer from "..label(from))
      end
    elseif kind=="file_accept" and validRef(d.ref) then
      local t=self.transfers[outgoingKey(from,d.ref)]
      if t and t.state=="Offered" then t.state="Sending"; t.tries=0; chunk(t); changed()
      elseif t and t.state=="Sending" then chunk(t) end
    elseif kind=="file_decline" and validRef(d.ref) then
      local t=self.transfers[outgoingKey(from,d.ref)]
      if t and active(t) then t.state="Declined"; changed() end
    elseif kind=="file_cancel" and validRef(d.ref) then
      for _,key in ipairs({incomingKey(from,d.ref),outgoingKey(from,d.ref)}) do
        local t=self.transfers[key]
        if t and active(t) then fail(t,"Peer cancelled transfer",false) end
      end
    elseif kind=="file_chunk" and validRef(d.ref) and integer(d.index,1,1024) then
      local t=self.transfers[incomingKey(from,d.ref)]
      if not t then return end
      if (t.state=="Receiving" or t.state=="Received") and d.index<t.index then
        send(from,"file_ack",{ref=d.ref,index=d.index})
      elseif t.state=="Receiving" and d.index==t.index then
        local data=b64.decode(d.data)
        if not data or #data~=math.min(M.chunk,t.size-t.bytes) then fail(t,"Invalid file chunk",true); return end
        local f,err=fs.open(t.temp,"ab")
        if not f then fail(t,err,true); return end
        local ok,why=pcall(f.write,data)
        f.close()
        if not ok then fail(t,tostring(why),true); return end
        t.bytes=t.bytes+#data
        t.index=t.index+1
        t.last=self.clock()
        t.tries=0
        if t.bytes==t.size then
          local dest=ops.unique(self.receivedPath,t.name)
          local moved,e=ops.move(t.temp,dest)
          if not moved then fail(t,e,true); return end
          t.temp=nil
          t.path=dest
          t.state="Received"
          self.notify("Received file: "..t.name)
        end
        send(from,"file_ack",{ref=d.ref,index=d.index})
        changed()
      end
    elseif kind=="file_ack" and validRef(d.ref) and integer(d.index,1,1024) then
      local t=self.transfers[outgoingKey(from,d.ref)]
      if t and t.state=="Sending" and d.index==t.index then
        t.bytes=t.bytes+(t.chunkSize or 0)
        t.index=t.index+1
        if t.bytes>=t.size then t.state="Sent"; self.notify("File sent: "..t.name)
        else t.tries=0; chunk(t) end
        changed()
      end
    elseif kind=="share_list" and c.hub then
      ensure(self.sharedPath)
      local items={}
      for _,name in ipairs(fs.list(self.sharedPath)) do
        local path=fs.combine(self.sharedPath,name)
        if not fs.isDir(path) and desktop.validName(name) and fs.getSize(path)<=M.maxFile then
          items[#items+1]={name=name,size=fs.getSize(path)}
          if #items>=50 then break end
        end
      end
      send(from,"share_result",{items=items})
    elseif kind=="share_result" and type(d.items)=="table" then
      local items={}
      for _,item in ipairs(d.items) do
        if type(item)=="table" and desktop.validName(item.name) and integer(item.size,0,M.maxFile) then
          items[#items+1]={name=item.name,size=item.size}
          if #items>=50 then break end
        end
      end
      self.shares[from]=items
      changed()
    elseif kind=="share_get" and c.hub and desktop.validName(d.name) then
      local path=fs.combine(self.sharedPath,d.name)
      if fs.exists(path) and not fs.isDir(path) then self:offerFile(from,path) end
    end
  end
  function self:event(event,from,packet,protocol)
    if not c.enabled then return false end
    if event=="peripheral" or event=="peripheral_detach" then
      self.modems=self.transport.scan()
      self:announce()
      changed()
      return true
    end
    if event~="rednet_message" or protocol~=M.protocol or type(packet)~="table" or not validID(from) or from==self.id then return false end
    local p=packet
    if p.v~=1 or p.from~=from or (p.to~=-1 and p.to~=self.id) or type(p.kind)~="string" or #p.kind>32
      or not validRef(p.id) or not integer(p.time,0,99999999999) or math.abs(self.clock()-p.time)>300
      or type(p.body)~="string" or #p.body>12000 or type(p.sig)~="string" or #p.sig~=64 then return false end
    if (p.to==-1 and p.kind~="hello") or self.seen[p.id] or not auth.equal(self.sign(canonical(p)),p.sig) then return false end
    self.seen[p.id]=true
    self.seenOrder[#self.seenOrder+1]=p.id
    if #self.seenOrder>1024 then self.seen[table.remove(self.seenOrder,1)]=nil end
    local data=U.decode(p.body)
    if not data then return false end
    local before=self.revision
    local ok,err=pcall(handle,from,p.kind,data)
    if not ok then self.notify("Network operation failed"); changed() end
    return self.revision~=before
  end
  function self:tick()
    if not c.enabled then return false end
    local before=self.revision
    local now=self.clock()
    if now>=self.nextHello then
      self.modems=self.transport.scan()
      self:announce()
      if self.modems==0 then self.nextHello=now+10 end
    end
    for ref,p in pairs(self.pending) do
      if now-p.last>=4 then
        if p.tries>=4 then self.pending[ref]=nil; state(ref,"Failed")
        else p.tries=p.tries+1; p.last=now; send(p.peer,p.kind,p.body) end
      end
    end
    if c.hub then
      for _,m in ipairs(self.mailbox) do
        local peer=self.peers[m.target]
        if m.group==self.group and peer and online(peer) and now-(m.last or 0)>=10 then deliver(m) end
      end
    end
    for _,t in pairs(self.transfers) do
      if t.state=="Offered" and now-t.created>=120 then fail(t,"Offer expired",true)
      elseif t.state=="Offered" and now-t.last>=10 then
        t.last=now; send(t.peer,"file_offer",{ref=t.ref,name=t.name,size=t.size})
      elseif t.state=="Pending" and now-t.created>=120 then fail(t,"Offer expired",false)
      elseif t.state=="Sending" and now-t.last>=4 then
        if t.tries>=5 then fail(t,"Transfer timed out",true) else chunk(t) end
      elseif t.state=="Receiving" and now-t.last>=4 then
        if t.tries>=8 then fail(t,"Transfer timed out",true)
        else
          t.tries=t.tries+1; t.last=now
          if t.index==1 then send(t.peer,"file_accept",{ref=t.ref})
          else send(t.peer,"file_ack",{ref=t.ref,index=t.index-1}) end
        end
      end
    end
    return self.revision~=before
  end
  return self
end
return M
]=],
    ["system/download.lua"]=[=[
return function(url,limit)
  if not http or not http.get then return nil,"HTTP is disabled" end
  local ok,handle,err,failed=pcall(http.get,url,nil,true)
  if not ok then return nil,tostring(handle) end
  if not handle then
    if failed then failed.close() end
    return nil,err or "Download failed"
  end
  local readOK,bytes=pcall(handle.readAll)
  handle.close()
  if not readOK then return nil,tostring(bytes) end
  if type(bytes)~="string" then return nil,"Empty HTTP response" end
  if #bytes>limit then return nil,"Download exceeds limit" end
  return (bytes:gsub("%z+$",""))
end
]=],
    ["system/catalog.lua"]=[=[
return function(validate,relative)
local function catalog(index,base)
  if type(index)~="table" or index.format~=1 or type(index.packages)~="table" then return nil,"Invalid catalog" end
  local result,seen={},{}
  for _,item in ipairs(index.packages) do
    if validate(item) and relative(item.package or "") and item.package:match("%.juz$") and not seen[item.id] then
      item.source=base
      result[#result+1]=item
      seen[item.id]=true
    end
  end
  return result
end
return catalog
end
]=],
    ["system/hit-test.lua"]=[=[
local function contains(rect,x,y)
  return rect and x>=rect.x and x<rect.x+rect.w and y>=rect.y and y<rect.y+rect.h
end
local function locate(list,x,y)
  for i=#list,1,-1 do if contains(list[i],x,y) then return list[i] end end
end
return contains,locate
]=],
    ["system/packages.lua"]=[=[
local U=assert(loadfile("/juzeppe/system/util.lua","t",_ENV))()
local M={api=1,root="/juzeppe",limit=512*1024}
local apps=M.root.."/apps"
local system=M.root.."/system-apps"
local stage=M.root.."/.install"
local config=M.root.."/config/repository"
local defaultRepository="https://raw.githubusercontent.com/gosuparenek/juzeppe-repo/main"
local function idOK(s)
  return type(s)=="string" and #s<=40 and s:match("^[a-z][a-z0-9_-]*$")~=nil
end
local function relative(p)
  if type(p)~="string" or #p==0 or #p>160 or p:sub(1,1)=="/" or p:find("\\",1,true) or p:find("//",1,true) or p:match("/$") then return false end
  for part in p:gmatch("[^/]+") do
    if part=="." or part==".." or not part:match("^[%w_.-]+$") then return false end
  end
  return true
end
local function version(v)
  if type(v)~="string" or #v>32 then return nil end
  local a,b,c=v:match("^(%d+)%.(%d+)%.(%d+)$")
  if not a then return nil end
  return tonumber(a),tonumber(b),tonumber(c)
end
function M.newer(a,b)
  local x,y,z=version(a)
  local p,q,r=version(b)
  if not x or not p then return false end
  return x>p or (x==p and (y>q or (y==q and z>r)))
end
function M.validateManifest(m)
  if type(m)~="table" or not idOK(m.id) then return nil,"Invalid app ID" end
  if m.permissions~=nil then
    if type(m.permissions)~="table" then return nil,"Invalid permissions" end
    local seen={}
    for i,v in pairs(m.permissions) do
      if type(i)~="number" or i%1~=0 or i<1 or i>#m.permissions or
        (v~="desktop.files" and v~="printer" and v~="clipboard" and v~="stock.read" and v~="stock.remote" and v~="stock.native" and v~="phone.calls") or seen[v] then return nil,"Invalid permission" end
      seen[v]=true
    end
  end
  if not version(m.version) then return nil,"Version must be X.Y.Z" end
  if type(m.name)~="string" or #m.name==0 or #m.name>80 then return nil,"Invalid name" end
  if m.api~=M.api then return nil,"Incompatible application API" end
  if m.order~=nil and (type(m.order)~="number" or m.order%1~=0 or m.order<0 or m.order>9999) then return nil,"Invalid app order" end
  if not relative(m.entry or "") or not m.entry:match("%.lua$") then return nil,"Invalid entry" end
  for _,key in ipairs({"name_ru","description","description_ru","short","short_ru","author"}) do
    if m[key]~=nil and (type(m[key])~="string" or #m[key]>240) then return nil,"Invalid "..key end
  end
  if m.icon~=nil then
    if type(m.icon)~="table" or #m.icon~=6 then return nil,"Invalid icon" end
    for _,row in ipairs(m.icon) do if type(row)~="string" or not row:match("^[01][01][01][01][01][01]$") then return nil,"Invalid icon" end end
  end
  return true
end
local function ensure()
  for _,p in ipairs({apps,stage,M.root.."/data",M.root.."/config"}) do
    if not fs.exists(p) then fs.makeDir(p) end
  end
end
local function recover(id)
  local backup=stage.."/"..id..".old"
  local work=stage.."/"..id..".new"
  local dest=apps.."/"..id
  if fs.exists(backup) then
    if fs.exists(dest) then fs.delete(backup) else fs.move(backup,dest) end
  end
  if fs.exists(work) then fs.delete(work) end
end
function M.installed()
  ensure()
  for _,name in ipairs(fs.list(stage)) do
    local id=name:match("^(.*)%.old$") or name:match("^(.*)%.new$")
    if idOK(id) then recover(id) end
  end
  local list={}
  for _,where in ipairs({system,apps}) do
    if fs.exists(where) then
      for _,id in ipairs(fs.list(where)) do
        if idOK(id) and fs.isDir(where.."/"..id) then
          local m=U.json(where.."/"..id.."/manifest.json")
          if M.validateManifest(m) and m.id==id and fs.exists(where.."/"..id.."/"..m.entry) then
            if where==apps and not m.permissions then
              local legacy=U.json(M.root.."/repo/legacy-permissions.json") or {}
              m.permissions=legacy[m.id.."@"..m.version]
            end
            m.path=where.."/"..id
            m.system=where==system
            list[#list+1]=m
          end
        end
      end
    end
  end
  table.sort(list,function(a,b)
    if a.system~=b.system then return a.system end
    if (a.order or 99)~=(b.order or 99) then return (a.order or 99)<(b.order or 99) end
    return a.id<b.id
  end)
  return list
end
function M.find(id)
  for _,m in ipairs(M.installed()) do if m.id==id then return m end end
end
function M.installBytes(bytes,expected)
  ensure()
  if type(bytes)~="string" or #bytes>M.limit then return nil,"Package missing or too large" end
  local pkg,err=U.decode(bytes)
  if not pkg then return nil,err end
  local m=pkg.manifest
  local ok,why=M.validateManifest(m)
  if not ok then return nil,why end
  if expected and (expected.id~=m.id or expected.version~=m.version) then return nil,"Package does not match catalog" end
  if fs.exists(system.."/"..m.id) then return nil,"System app cannot be replaced" end
  if type(pkg.files)~="table" or type(pkg.files[m.entry])~="string" then return nil,"Missing entry file" end
  local total,count=0,0
  for p,data in pairs(pkg.files) do
    if not relative(p) or p=="manifest.json" or type(data)~="string" then return nil,"Invalid package file" end
    total=total+#data
    count=count+1
    if total>M.limit or count>128 then return nil,"Package too large" end
    if p:match("%.lua$") then
      local fn,e=load(data,"@"..p,"t",{})
      if not fn then return nil,"Lua syntax: "..tostring(e) end
    end
  end
  for p in pairs(pkg.files) do
    local dir=fs.getDir(p)
    while dir~="" do
      if pkg.files[dir] then return nil,"File/directory conflict" end
      dir=fs.getDir(dir)
    end
  end
  recover(m.id)
  local old=M.find(m.id)
  if old and not M.newer(m.version,old.version) then return nil,"Already installed or newer version exists" end
  local work=stage.."/"..m.id..".new"
  local backup=stage.."/"..m.id..".old"
  local dest=apps.."/"..m.id
  local success,failure=pcall(function()
    fs.makeDir(work)
    for p,data in pairs(pkg.files) do assert(U.write(work.."/"..p,data)) end
    assert(U.write(work.."/manifest.json",U.encode(m)))
    if fs.exists(dest) then fs.move(dest,backup) end
    fs.move(work,dest)
  end)
  if not success then
    if not fs.exists(dest) and fs.exists(backup) then fs.move(backup,dest) end
    if fs.exists(work) then fs.delete(work) end
    return nil,tostring(failure)
  end
  if fs.exists(backup) then fs.delete(backup) end
  os.queueEvent("juzeppe_packages_changed")
  return m
end
function M.installFile(path)
  if type(path)~="string" or not path:lower():match("%.juz$") or not fs.exists(path) or fs.isDir(path) then return nil,"Select a .juz file" end
  if fs.getSize(path)>M.limit then return nil,"Package too large" end
  return M.installBytes(U.read(path))
end
function M.remove(id)
  local m=M.find(id)
  if not m or m.system then return nil,"Application cannot be removed" end
  fs.delete(m.path)
  os.queueEvent('juzeppe_packages_changed')
  return true
end
function M.repository()
  local saved=U.read(config)
  if not saved or saved=="" then return defaultRepository end
  if saved=="local" then return "" end
  return saved
end
function M.setRepository(url)
  url=url:gsub("/+$","")
  if url~="" and not url:match("^https?://[^%s]+$") then return nil,"Use an http(s) URL" end
  return U.write(config,url=="" and "local" or url)
end
local download=assert(loadfile("/juzeppe/system/download.lua","t",_ENV))()
local function get(url) return download(url,M.limit) end
local catalog=assert(loadfile("/juzeppe/system/catalog.lua","t",_ENV))()(M.validateManifest,relative)
function M.catalog(refresh)
  local base=M.repository()
  if base=="" then return catalog(U.json(M.root.."/repo/index.json"),"local") end
  local cache=M.root.."/config/catalog.json"
  if not refresh then
    local data=U.json(cache)
    if data and data.base==base then return catalog(data.index,base) end
    return catalog(U.json(M.root.."/repo/index.json"),"local")
  end
  local bytes,err=get(base.."/index.json")
  if not bytes then return nil,err end
  local index,decodeError=U.decode(bytes)
  if not index then return nil,decodeError end
  local result,why=catalog(index,base)
  if not result then return nil,why end
  U.write(cache,U.encode({base=base,index=index}))
  return result
end
function M.installCatalog(item)
  local bytes,err
  if item.source=="local" then bytes=U.read(M.root.."/repo/"..item.package)
  else bytes,err=get(item.source.."/"..item.package) end
  if not bytes then return nil,err or "Package not found" end
  return M.installBytes(bytes,item)
end
return M


]=],
    ["system/palette.lua"]=[=[
local C=colors
local P = {
  paper = C.white, accent = C.orange, bronze = C.magenta,
  sky = C.lightBlue, sun = C.yellow, olive = C.lime, tint = C.pink,
  border = C.gray, muted = C.lightGray, oasis = C.cyan,
  deep = C.purple, water = C.blue, earth = C.brown,
  foliage = C.green, danger = C.red, ink = C.black
}
local paletteKeys = {
  C.white,C.orange,C.magenta,C.lightBlue,C.yellow,C.lime,C.pink,C.gray,
  C.lightGray,C.cyan,C.purple,C.blue,C.brown,C.green,C.red,C.black
}
local themes = {
  {name="Sandstone", caption="Cream / terracotta", rgb={
    0xFFF5E3,0xB7613C,0xC78F56,0xF4D9AC,0xFFD48B,0x8C9A62,
    0xE9D1B0,0xB89B7D,0x856A55,0x427D79,0x69493E,0x80AFAD,
    0xD6B58C,0x365D52,0xAD493E,0x35251F}},
  {name="Harbor", caption="Limestone / sea", rgb={
    0xF7F0DC,0x337C77,0xAB9970,0xD0E3DC,0xF7CE88,0x84965F,
    0xD8E1CE,0x94ACA3,0x506C65,0x357D83,0x345251,0x6CA7AB,
    0xD0CAB1,0x295B58,0xAA6051,0x263C3A}},
  {name="Dusk", caption="Amber / umber", rgb={
    0xFFF0D8,0x995143,0xBB805C,0xDFBA9F,0xF6C681,0x97956D,
    0xE8CBB6,0xB49389,0x84645B,0x668980,0x5A4145,0x888C9A,
    0xC59B80,0x514E45,0xB85048,0x352731}},
  {name="Oasis", caption="Sage / sandstone", rgb={
    0xF7F3DF,0x52744D,0xB9A677,0xD6DCC0,0xF3DBA0,0x96A969,
    0xE1DCC0,0xA3A98A,0x69795D,0x50887B,0x4B5746,0x86ACA0,
    0xC8C3A0,0x365F46,0xB25A48,0x303C30}}
}


local M={colors=P,themes=themes}
function M.capture(target)
  local result={}
  for _,index in ipairs(paletteKeys) do result[index]={target.getPaletteColor(index)} end
  return result
end
function M.restore(target,saved)
  for _,index in ipairs(paletteKeys) do target.setPaletteColor(index,table.unpack(saved[index])) end
end
function M.apply(target,which)
  for i,index in ipairs(paletteKeys) do target.setPaletteColor(index,themes[which].rgb[i]) end
end
return M
]=],
    ["system/journal.lua"]=[=[
local path="/juzeppe/logs/kernel.log"
return function(app,phase,reason,thread)
  pcall(function()
    fs.makeDir("/juzeppe/logs")
    if fs.exists(path) and fs.getSize(path)>32768 then
      if fs.exists(path..".1") then fs.delete(path..".1") end
      fs.move(path,path..".1")
    end
    local trace=tostring(reason)
    if thread and debug and debug.traceback then
      local ok,t=pcall(debug.traceback,thread,trace); if ok then trace=t end
    end
    local h=assert(fs.open(path,"a"))
    h.writeLine(("%s [%s/%s] %s"):format(os.epoch("utc"),app,phase,trace:sub(1,4096))); h.close()
  end)
end
]=],
    ["system/app-env.lua"]=[=[
-- Build a fresh capability environment for each installed application.
return function(win,c,grants,locale)
  local function copy(t) local r={} for k,v in pairs(t or {}) do r[k]=v end return r end
  grants=grants or {}
  local documents=grants["desktop.files"]
  local root=fs.combine("",c.dataPath)
  local desk=fs.combine("",c.desktopPath)
  local function path(p)
    assert(type(p)=="string","Expected path")
    local n=fs.combine("",p)
    assert(n==root or n:sub(1,#root+1)==root.."/" or
      (documents and (n==desk or n:sub(1,#desk+1)==desk.."/")),"Permission denied")
    return n
  end
  local api={}
  for _,k in ipairs({"api","dataPath","args","state","shared","width","height","pid","getLanguage","invalidate","status","close","prompt","confirm","job","yieldStep","menu","rect","raw","text","hit","button","tr","modifiers","minimize","maximize","newWindow","onClose"}) do api[k]=c[k] end
  api.colors=copy(c.colors)
  api.desktopPath=documents and c.desktopPath or c.dataPath
  local files={getDir=fs.getDir,getName=fs.getName,combine=fs.combine}
  for _,key in ipairs({"exists","isDir","getSize","makeDir","delete","list"}) do
    files[key]=function(p) return fs[key](path(p)) end
  end
  files.move=function(a,b) return fs.move(path(a),path(b)) end
  local handles={}
  c.onClose(function() for h in pairs(handles) do pcall(h.close) end end)
  files.open=function(p,mode)
    local h,e=fs.open(path(p),mode); if not h then return nil,e end
    local w=copy(h); handles[h]=true
    w.close=function() handles[h]=nil; h.close() end
    return w
  end
  api.read=function(p) return c.read(path(p)) end
  api.write=function(p,v) return c.write(path(p),v) end
  local env={assert=assert,error=error,ipairs=ipairs,pairs=pairs,next=next,select=select,
    tonumber=tonumber,tostring=tostring,type=type,pcall=pcall,xpcall=xpcall,
    string=copy(string),math=copy(math),table=copy(table),utf8=copy(utf8),
    keys=copy(keys),colors=copy(colors),fs=files,os={clock=os.clock,time=os.time,day=os.day},
    textutils={serialize=textutils.serialize,unserialize=textutils.unserialize},juzeppe=api,
    term={setCursorPos=win.surface.setCursorPos,blit=win.surface.blit}}
  if documents then
    api.refreshDesktop=c.refreshDesktop
  end
  if grants.clipboard then
    api.clipboard={getText=function() return c.clipboard:getText() end,setText=function(_,v) assert(type(v)=="string"); c.clipboard:setText(v) end}
  end
  if grants["stock.read"] then
    api.stock={
      sources=function()
        local result={}
        for _,name in ipairs(peripheral.getNames()) do
          if peripheral.hasType(name,"Create_StockTicker") then result[#result+1]=name end
        end
        table.sort(result)
        return result
      end,
      read=function(name)
        if type(name)~="string" or not peripheral.hasType(name,"Create_StockTicker") then
          error("Stock Ticker disconnected",2)
        end
        return peripheral.call(name,"stock")
      end
    }
  end
  if grants["stock.remote"] then
    api.stock=api.stock or {}
    api.stock.remote=c.stockRemote
  end
  if grants["stock.native"] then
    api.stock=api.stock or {}
    api.stock.openNative=function(id)
      if type(juzeppebridge)~="table" or type(juzeppebridge.openStock)~="function" then
        return false,"Install Juzeppe Bridge on the Minecraft server"
      end
      if id~=nil then
        if not grants["stock.remote"] then return false,"Wireless stock permission required" end
        if type(juzeppebridge.openRemote)~="function" then return false,"Update Bridge to 0.2.0" end
        local ticket,err=c.stockRemote(id,true)
        if not ticket then return false,err end
        return juzeppebridge.openRemote(ticket)
      end
      return juzeppebridge.openStock()
    end
  end
  if grants["phone.calls"] then
    api.phone={status=c.phone.status,command=c.phone.command}
  end
  if grants.printer then
    local function printer(n) return peripheral.hasType(n,"printer") end
    env.peripheral={hasType=function(n,t) return t=="printer" and printer(n) end,
      getNames=function() local names={} for _,n in ipairs(peripheral.getNames()) do if printer(n) then names[#names+1]=n end end return names end,
      wrap=function(n) if printer(n) then local p=peripheral.wrap(n); local r={}
        for _,k in ipairs({"getInkLevel","getPaperLevel","newPage","getPageSize","setPageTitle","setCursorPos","write","endPage"}) do r[k]=p[k] end
        return r end end}
  end
  do
    env.dofile=function(p)
      if p=="/juzeppe/system/locale.lua" then return {render=locale.render} end
      if p=="/juzeppe/system/fileops.lua" then return {unique=function(dir,name)
        local n=fs.combine(dir,name); local i=0
        while files.exists(n) do i=i+1; n=fs.combine(dir,name..i) end
        return n end} end
      error("Module unavailable",2)
    end
  end
  return env,api
end
]=],
    ["system/process.lua"]=[=[
local U=assert(loadfile("/juzeppe/system/util.lua","t",_ENV))()
local sessionAPI=assert(loadfile("/juzeppe/system/session.lua","t",_ENV))()
local journal=dofile('/juzeppe/system/journal.lua')
local appEnv=dofile('/juzeppe/system/app-env.lua')
local M={}
local function clip(value,width)
  width=math.max(0,width)
  if #value<=width then return value end
  return width<4 and value:sub(1,width) or value:sub(1,width-3).."..."
end
local function inputEvent(e)
  return e=="char" or e=="paste" or e=="key" or e=="key_up" or e:sub(1,6)=="mouse_"
end
function M.new(host,P,locale,config)
  local self={jobs={},processes={},serial=0,ready={},wake=false}
  local STEP={}
  local function wake() if not self.wake then self.wake=true; os.queueEvent("juzeppe_ready") end end
  local function enqueue(j) self.ready[#self.ready+1]=j; wake() end
  function self:pump()
    self.wake=false
    local j=table.remove(self.ready,1)
    if j and not j.finished then self:resumeJob(j) end
    if #self.ready>0 then wake() end
  end
  local function dimensions(win)
    return math.max(1,win.w-2),math.max(1,win.h-2)
  end
  local function setNotice(win,message)
    win.notice=tostring(message or "")
  end
  local function resume(thread,redirect,...)
    local previous=term.redirect(redirect)
    local result=table.pack(coroutine.resume(thread,...))
    local current=term.current()
    term.redirect(previous)
    return result,current
  end
  local function write(win,x,y,text,fg,bg)
    local c=win.ctx
    if x<1 or y<1 or x>c.width or y>c.height then return end
    text=clip(text,c.width-x+1)
    if #text==0 then return end
    win.surface.setCursorPos(x,y)
    win.surface.setTextColor(fg or P.ink)
    win.surface.setBackgroundColor(bg or P.paper)
    win.surface.write(text)
  end
  local function hit(win,x,y,w,h,fn)
    local c=win.ctx
    if x<1 or y<1 or x>c.width or y>c.height or w<=0 or h<=0 then return end
    win.hits[#win.hits+1]={x=x,y=y,w=math.min(w,c.width-x+1),h=math.min(h,c.height-y+1),fn=fn}
  end
  local function fill(win,x,y,w,h,colour)
    local c=win.ctx
    if x<1 or y<1 or x>c.width or y>c.height then return end
    w,h=math.min(w,c.width-x+1),math.min(h,c.height-y+1)
    if w<=0 or h<=0 then return end
    for row=y,y+h-1 do write(win,x,row,string.rep(" ",w),colour,colour) end
  end
  local function runNative(program,args)
    local path=program or "/rom/programs/shell.lua"
    if path:sub(1,1)~="/" or not fs.exists(path) or fs.isDir(path) then path=shell.resolveProgram(path) end
    if not path then error("Program not found",0) end
    -- Give every native program an independent execution environment.
    -- In particular a nested CraftOS shell builds its own aliases and cwd.
    local env={shell=shell}
    local make=dofile("/rom/modules/main/cc/require.lua").make
    env.require,env.package=make(env,fs.getDir(path))
    if not os.run(env,path,table.unpack(args)) then error("Program ended with an error",0) end
  end
  function self:startSession(win,program,...)
    if win.closed or win.session then return end
    win.dirty=true
    local args={...}
    local width,height=dimensions(win)
    shell.setAlias("jpkg","/juzeppe/bin/jpkg.lua")
    win.session=sessionAPI.new(host,width,height,function() runNative(program,args) end)
  end
  function self:nextAction(win)
    if win.closed or win.worker or #win.pending==0 then return end
    local task=table.remove(win.pending,1)
    win.worker={thread=coroutine.create(function() return task.fn(table.unpack(task.args,1,task.args.n)) end),
      redirect=win.surface,done=task.done}
    self:resumeWorker(win)
  end
  function self:resumeWorker(win,...)
    local worker=win.worker
    if not worker or win.closed then return end
    win.dirty=true
    local result,redirect=resume(worker.thread,worker.redirect,...)
    worker.redirect=redirect
    if not result[1] then journal(win.app.id,'action',result[2],worker.thread) end
    if not result[1] or coroutine.status(worker.thread)=="dead" then
      win.worker=nil
      if worker.done then
        local ok,err=pcall(worker.done,table.unpack(result,1,result.n))
        if not ok then setNotice(win,"Error: "..tostring(err)) end
      elseif not result[1] then setNotice(win,"Error: "..tostring(result[2])) end
      self:nextAction(win)
    else worker.filter=result[2] end
  end
  function self:action(win,fn,...)
    if win.closed then return end
    if #win.pending>=32 then setNotice(win,"Application is busy"); return end
    win.pending[#win.pending+1]={fn=fn,args=table.pack(...)}
    self:nextAction(win)
  end
  function self:resumeJob(job,...)
    local result,redirect=resume(job.thread,job.redirect,...)
    job.redirect=redirect
    if not result[1] or coroutine.status(job.thread)=="dead" then
      job.finished=true
      job.owner.ctx.busy=false
      job.owner.dirty=true

      if not result[1] then journal(job.owner.app.id,"job",result[2],job.thread) end
      for i=#self.jobs,1,-1 do if self.jobs[i]==job then table.remove(self.jobs,i); break end end
      if not job.owner.closed then
        if result[1] then self:action(job.owner,job.callback,table.unpack(result,2,result.n))
        else self:action(job.owner,job.callback,nil,result[2]) end
      end
    elseif result[2]==STEP then job.filter=STEP; enqueue(job)
    else job.filter=result[2] end
  end
  function self:cancelJob(win)
    if win.worker and win.worker.filter==win.sliceEvent and not win.trusted then
      win.worker=nil
      win.pending={}; win.process.inbox[win]=win.pending
      win.loading=false; win.dirty=true; win.notice="Cancelled"
      return true
    end
    for i=#self.jobs,1,-1 do
      local j=self.jobs[i]
      if j.owner==win then
        j.finished=true; table.remove(self.jobs,i)
        win.ctx.busy=false; win.dirty=true
        if j.callback then self:action(win,j.callback,nil,"Cancelled") end
        return true
      end
    end
  end
  function self:startJob(win,fn,callback)
    if win.closed or win.ctx.busy then return false end
    win.dirty=true
    win.ctx.busy=true
    local job={owner=win,filter=STEP,thread=coroutine.create(fn),callback=callback,redirect=win.surface}
    self.jobs[#self.jobs+1]=job
    enqueue(job)
    return true
  end
  function self:jobEvent(event,...)
    if inputEvent(event) or event=="terminate" or event=="file_transfer" then return end
    local changed=false
    for i=#self.jobs,1,-1 do
      local job=self.jobs[i]
      if job and not job.finished and (job.owner.trusted or ((event=="task_complete" or event=="juzeppe_stock_result") and job.filter==event)) and (not job.filter or job.filter==event) then
        self:resumeJob(job,event,...); changed=true
      end

    end
    return changed
  end
  function self:attach(win,args,parent,documents)
    local proc=parent
    if not proc then proc={pid=config.kernel.allocate(),windows={},inbox={},shared={},state="running"}; self.processes[proc.pid]=proc end
    win.process=proc; proc.windows[win]=true; proc.inbox[win]=win.pending; win.cleanup={}
    win.trusted=win.app.system==true or win.ephemeral==true
    local app=win.app
    local width,height=dimensions(win)
    win.surface=window.create(host,1,1,width,height,false)
    win.dirty=true
    local dataPath="/juzeppe/data/"..app.id
    if not fs.exists(dataPath) then fs.makeDir(dataPath) end
    local c={
      phone=config.kernel.phone,
      stockRemote=function(id,native)
        for _,job in ipairs(self.jobs) do
          if job.owner==win and job.thread==coroutine.running() then return config.kernel.stock.read(id,native) end
        end
        return nil,"Use a background job to read remote stock"
      end,
      shared=proc.shared,pid=proc.pid,onClose=function(fn) assert(type(fn)=="function"); win.cleanup[#win.cleanup+1]=fn end,
      newWindow=function() if not win.closed then config.newWindow(win,proc,documents) end end,
      yieldStep=function() return coroutine.yield(STEP) end,api=1,colors=P,dataPath=dataPath,appPath=app.path,package=config.pkg,
      state={},args=args or {},desktopPath=config.desktopPath,
      clipboard=config.clipboard,network=config.network,refreshDesktop=config.refreshDesktop,modifiers=config.modifiers,
      menu=function(entries,x,y) config.menu(win,entries,x,y) end,
      invalidate=function() win.dirty=true end,
      width=width,height=height,tr=locale.raw,
      read=U.read,write=U.write,
      status=function(message) setNotice(win,message) end,
      close=function() config.close(win) end,
      launch=function(program,...) self:startSession(win,program,...) end,
      refreshApps=config.refresh,
      prompt=function(label,initial,callback,secret) config.prompt(win,label,initial,callback,secret) end,
      confirm=function(label,callback) config.confirm(win,label,callback) end,
      setLanguage=config.setLanguage,getLanguage=config.getLanguage,
      setTheme=config.setTheme,getTheme=config.getTheme,
      job=function(fn,callback) return self:startJob(win,fn,callback) end,
      minimize=function() config.minimize(win) end,
      maximize=function() config.maximize(win) end,
      openApp=function(id,options) return config.openApp(id,options) end
    }
    win.ctx=c
    c.text=function(x,y,key,fg,bg) write(win,x,y,locale.text(tostring(key)),fg,bg) end
    c.raw=function(x,y,value,fg,bg) write(win,x,y,locale.render(value),fg,bg) end
    c.rect=function(x,y,w,h,color) fill(win,x,y,w,h,color) end
    c.button=function(x,y,key,fn,bg,fg)
      local text=clip(locale.text(key),c.width-x+1)
      write(win,x,y,text,fg or P.paper,bg or P.accent)
      hit(win,x,y,#text,1,fn)
    end
    c.hit=function(x,y,w,h,fn) hit(win,x,y,w,h,fn) end
    if not app.path then return end
    local env,api
    if win.trusted then env=setmetatable({juzeppe=c},{__index=_ENV}); api=c
      c.installPackage=config.kernel.install
      c.latestInstall=config.kernel.latest
    else env,api=appEnv(win,c,documents,locale) end
    win.api=api
    local path=app.path.."/"..app.entry
    local fn,err
    win.sliceEvent="juzeppe_slice_"..proc.pid.."_"..win.id
    if win.trusted then fn,err=loadfile(path,"t",env)
    else
      local checks,deadline=0,0
      local function checkpoint()
        checks=checks+1
        if checks%128~=0 then return end
        local now=os.epoch("utc")
        if now<deadline then return end
        deadline=now+25
        local thread=coroutine.running()
        if win.worker and win.worker.thread==thread then
          os.queueEvent(win.sliceEvent)
          coroutine.yield(win.sliceEvent)
        else
          for _,job in ipairs(self.jobs) do
            if job.thread==thread then coroutine.yield(STEP); return end
          end
          if win.drawDeadline and now>=win.drawDeadline then error("Draw exceeded its time budget",0) end
        end
      end
      fn,err=dofile("/juzeppe/system/app-loader.lua")(path,env,checkpoint)
    end
    if not fn then journal(app.id,'load',err); setNotice(win,"App error: "..tostring(err)); return end
    win.loading=true
    win.pending[#win.pending+1]={fn=fn,args=table.pack(api),done=function(ok,result)
      win.loading=false
      if ok and type(result)=="table" and type(result.draw)=="function" then win.instance=result
      else setNotice(win,"App error: "..tostring(ok and "Expected an application table" or result)) end
    end}
    self:nextAction(win)
  end
  function self:resize(win)
    local w,h=dimensions(win)
    if w==win.ctx.width and h==win.ctx.height then return end
    win.ctx.width,win.ctx.height=w,h
    if win.api then win.api.width,win.api.height=w,h end
    win.dirty=true
    win.surface.reposition(1,1,w,h)
    if win.session then win.session:resize(w,h) end
    if win.worker and (not win.worker.filter or win.worker.filter=="term_resize") then
      self:resumeWorker(win,"term_resize")
    elseif not win.worker and win.instance and win.instance.event then
      self:action(win,win.instance.event,win.api,"term_resize")
    end
  end
  function self:event(win,event,...)
    if event==win.sliceEvent and not win.closed then
      if win.worker and win.worker.filter==event then self:resumeWorker(win); return true end
      return false
    end
    -- CC peripherals may suspend until their main-thread task completes.
    -- Resume only the waiting call. Never broadcast host completions to app handlers.
    if not win.trusted and event=="task_complete" then
      if win.worker and win.worker.filter==event then
        self:resumeWorker(win,event,...)
        return true
      end
      return false
    end
    if not win.trusted and not inputEvent(event) and event~='term_resize' and event~='terminate' then return false end
    if win.closed then return false end
    local changed=false
    if win.session then
      changed=win.session:event(event,...)
      if inputEvent(event) or event=="terminate" then return changed end
    end
    if win.worker then
      if not win.worker.filter or win.worker.filter==event or event=="terminate" then
        self:resumeWorker(win,event,...)
        changed=true
      elseif win.instance and win.instance.event and win.instance.events and win.instance.events[event] then
        self:action(win,win.instance.event,win.api,event,...); changed=true
      end
    elseif win.instance and win.instance.event and (not win.instance.events or win.instance.events[event]) then
      self:action(win,win.instance.event,win.api,event,...)
      changed=true
    end
    return changed
  end
  function self:reap(win)
    if not win.session or not win.session.done then return false end
    local err,sessionThread=win.session.error,win.session.thread
    win.session:stop()
    win.session=nil
    win.dirty=true
    if err then journal(win.app.id,"session",err,sessionThread); setNotice(win,err) end
    if win.ephemeral and not err then config.close(win); return true end
    if win.instance and win.instance.onReturn then self:action(win,win.instance.onReturn,win.api) end
    return true
  end
  function self:draw(win)
    self:resize(win)
    if win.session then return win.session.view end
    if not win.dirty then return win.surface end
    win.dirty=false
    win.hits={}
    win.surface.setBackgroundColor(P.paper)
    win.surface.setTextColor(P.ink)
    win.surface.clear()
    if win.loading then win.ctx.text(2,2,"Loading...",P.muted)
    elseif win.instance then
      local thread=coroutine.create(function() win.instance.draw(win.api) end)
      win.drawDeadline=os.epoch('utc')+100
      local result=resume(thread,win.surface)
      win.drawDeadline=nil
      if not result[1] or coroutine.status(thread)~="dead" then
        journal(win.app.id,"draw",result[1] and "draw yielded" or result[2],thread)
        setNotice(win,"App error: "..tostring(result[1] and "draw must not yield; use ui.job" or result[2]))
        win.instance=nil
      end
    elseif win.ephemeral then win.ctx.text(2,2,"Session ended",P.muted)
    else win.ctx.text(2,2,"Application unavailable",P.muted) end
    return win.session and win.session.view or win.surface
  end
  function self:click(win,x,y)
    if win.worker or win.session then return false end
    for i=#win.hits,1,-1 do
      local hit=win.hits[i]
      if x>=hit.x and x<hit.x+hit.w and y>=hit.y and y<hit.y+hit.h then
        self:action(win,hit.fn)
        return true
      end
    end
    return false
  end
  function self:close(win)
    if win.closing then return end
    win.closing=true
    if win.session then win.session:stop(); win.session=nil end
    win.worker=nil; win.pending={}
    for i=#self.jobs,1,-1 do local j=self.jobs[i]
      if j.owner==win then
        j.finished=true; table.remove(self.jobs,i)
      end
    end
    for i=#self.ready,1,-1 do if self.ready[i].finished then table.remove(self.ready,i) end end
    for i=#win.cleanup,1,-1 do local ok,e=pcall(win.cleanup[i]); if not ok then journal(win.app.id,"cleanup",e) end end
    local proc=win.process; proc.inbox[win]=nil; proc.windows[win]=nil
    if not next(proc.windows) then proc.state="stopped"; self.processes[proc.pid]=nil end
    if win.surface then win.surface.setVisible(false) end
  end
  return self
end
return M


]=],
    ["system/ru.json"]=[=[
{
  "City Operating System": "Городская ОС",
  "APPLICATIONS": "ПРИЛОЖЕНИЯ",
  " CLOSE ": " ЗАКРЫТЬ ",
  " J MENU ": " J МЕНЮ ",
  " Desktop ": " Раб. стол ",
  "Desktop": "Рабочий стол",
  "Exit OS": "Выход из ОС",
  " OK ": " ОК ",
  " Cancel ": " Отмена ",
  " < Up ": " < Вверх ",
  "NAME": "ИМЯ",
  "TYPE": "ТИП",
  "Folder": "Папка",
  "File": "Файл",
  "items": "объектов",
  "Install this package?": "Установить пакет?",
  "Read-only file": "Только чтение",
  "Personal notebook": "Личный блокнот",
  " Edit note ": " Редактировать ",
  "Your notebook is empty.": "В блокноте пока пусто.",
  "Saved locally": "Сохранено на компьютере",
  "Type exit to return": "exit - выход из shell",
  "Shell session ended": "Сеанс терминала завершён",
  " Start shell ": " Запустить shell ",
  "Language": "Язык",
  "RU needs Cyrillic font": "RU: нужен кириллический шрифт",
  "Settings saved": "Настройки сохранены",
  "Sandstone": "Песчаник",
  "Harbor": "Гавань",
  "Dusk": "Сумерки",
  "Oasis": "Оазис",
  " Catalog ": " Каталог ",
  " Installed ": " Установлено ",
  " File ": " Файл ",
  " Repo ": " Репо ",
  " Sync ": " Синхр. ",
  "APPLICATION / VERSION": "ПРИЛОЖЕНИЕ / ВЕРСИЯ",
  "No applications": "Приложений нет",
  "Already installed": "Уже установлено",
  " Install ": " Установить ",
  " Update ": " Обновить ",
  " Remove ": " Удалить ",
  "System application": "Системное приложение",
  "Remove application?": "Удалить приложение?",
  "Application removed": "Приложение удалено",
  "Path to .juz file": "Путь к файлу .juz",
  "Repository URL (empty = local)": "URL репозитория (пусто = лок.)",
  "Repository saved": "Репозиторий сохранён",
  "WORLD TIME": "МИРОВОЕ ВРЕМЯ",
  "DAY": "ДЕНЬ",
  "Sandstone Edition": "Песчаное издание",
  "Version 0.3 / API 1": "Версия 0.3 / API 1",
  "Computer": "Компьютер",
  "Designed for Juzeppe": "Создано для Juzeppe",
  "Calculator": "Калькулятор",
  "Enter first number": "Введите первое число",
  "Enter second number": "Введите второе число",
  "Number 1": "Число 1",
  "Number 2": "Число 2",
  "Result": "Результат",
  "Invalid number": "Неверное число",
  "Division by zero": "Деление на ноль",
  "Choose operation": "Выберите операцию",
  " Enter ": " Ввести ",
  "Clear": "Сброс",
  "Package missing or too large": "Пакет отсутствует или слишком большой",
  "Invalid JSON": "Неверный JSON",
  "Invalid app ID": "Неверный ID приложения",
  "Version must be X.Y.Z": "Версия должна быть X.Y.Z",
  "Incompatible application API": "API приложения несовместим",
  "System app cannot be replaced": "Системное приложение защищено",
  "Select a .juz file": "Выберите файл .juz",
  "Already installed or newer version exists": "Уже установлена эта или новая версия",
  "Application cannot be removed": "Нельзя удалить приложение",
  "HTTP is disabled": "HTTP отключён",
  "Download failed": "Ошибка загрузки",
  "Invalid catalog": "Неверный каталог",
  "Use an http(s) URL": "Укажите http(s) URL",
  "Package does not match catalog": "Пакет не совпадает с каталогом",
  "Syncing catalog...": "Обновляем каталог...",
  "Catalog updated": "Каталог обновлён",
  "Installing package...": "Устанавливаем пакет...",
  "Please wait...": "Подождите...",
  "Installed": "Установлено",
  "Version 0.4 / API 1": "Версия 0.4 / API 1",
  "APPS": "ПРИЛОЖЕНИЯ",
  " +Dir ": " +Пап ",
  " +File ": " +Файл ",
  " Desk ": " Стол ",
  " Tasks ": " Задачи ",
  "Drop files here": "Перетащите файлы",
  "Open windows": "Открытые окна",
  "No open windows": "Нет открытых окон",
  "New folder": "Новая папка",
  "New file": "Новый файл",
  "Folder name": "Имя папки",
  "File name": "Имя файла",
  "Folder created": "Папка создана",
  "File created": "Файл создан",
  "Open": "Открыть",
  "Rename": "Переименовать",
  "Delete": "Удалить",
  "New name": "Новое имя",
  "Renamed": "Переименовано",
  "Deleted": "Удалено",
  "Delete this item and its contents?": "Удалить этот объект и содержимое?",
  "Received": "Получено",
  "Invalid file name": "Недопустимое имя",
  "Name already exists": "Имя уже существует",
  "Read-only folder": "Папка только для чтения",
  "File not found": "Файл не найден",
  "Application not found": "Приложение не найдено",
  "Application unavailable": "Приложение недоступно",
  "Loading...": "Загрузка...",
  "Working...": "Работа...",
  "Application is busy": "Приложение занято",
  "Session ended": "Сеанс завершён",
  "Desk": "Стол",
  "Failed": "Ошибок",
  " J Start ": " J Пуск ",
  " Win ": " Окна ",
  "Remove shortcut": "Убрать ярлык",
  "Pin to desktop": "На рабочий стол",
  "Refresh": "Обновить",
  "Settings": "Настройки",
  "Version 0.5 / API 1": "Версия 0.5 / API 1",
  "SANDSTONE": "ПЕСЧАНИК",
  "Windows": "Окна",
  "Type to search": "Поиск приложений",
  "Version 0.6 / API 1": "Версия 0.6 / API 1",
  "Trash": "Корзина",
  " Bin ": " Корз ",
  "Move to Trash": "В корзину",
  "Move to Trash?": "Переместить в корзину?",
  "Moved to Trash": "В корзине",
  "Delete permanently": "Удалить навсегда",
  "Delete permanently?": "Удалить навсегда?",
  "Restore": "Восстановить",
  " Restore ": " Вернуть ",
  "Restored": "Восстановлено",
  "Copied": "Скопировано",
  "Cut": "Вырезано",
  "Pasted": "Вставлено",
  "Copy": "Копировать",
  "Paste": "Вставить",
  " Cut ": " Выр. ",
  " Copy ": " Коп. ",
  " Paste ": " Встав. ",
  " New ": " Нов. ",
  " Find ": " Поиск ",
  "Address": "Адрес",
  "Search this folder": "Поиск в папке",
  "SIZE": "РАЗМЕР",
  "selected": "выбрано",
  "Select files first": "Выберите файлы",
  "Select one item": "Выберите один объект",
  "Clipboard has no files": "В буфере нет файлов",
  "Folder not found": "Папка не найдена",
  "Cannot place folder inside itself": "Нельзя вложить папку в себя",
  "Cannot trash this folder": "Нельзя удалить эту папку",
  "Sort by name": "По имени",
  "Sort by size": "По размеру",
  "Sort by type": "По типу",
  "Send over network": "Отправить по сети",
  " Peers ": " Узлы ",
  " Chat ": " Чат ",
  " Files ": " Файлы ",
  " Setup ": " Настр. ",
  " Net ": " Сеть ",
  " ID ": " ID ",
  " Msg ": " Сообщ ",
  " Share ": " Общие ",
  " Write ": " Напис. ",
  " Get ": " Взять ",
  " Refresh ": " Обнов. ",
  " Name ": " Имя ",
  " Key ": " Ключ ",
  " Enable ": " Вкл. ",
  " Disable ": " Выкл. ",
  " Hub ": " Сервер ",
  " Server ID ": " ID сервера ",
  " Shared ": " Общие ",
  "Computer ID": "ID компьютера",
  "Computer name": "Имя компьютера",
  "Network key (8+ bytes)": "Ключ сети (от 8 байт)",
  "Network key must be 8-128 bytes": "Ключ от 8 до 128 байт",
  "Set network key first": "Сначала задайте ключ",
  "No network key": "Ключ отсутствует",
  "Key configured": "Ключ задан",
  "Server mode on": "Сервер включён",
  "Server mode off": "Сервер выключен",
  "Server ID (blank = direct)": "ID сервера (пусто = напрямую)",
  "Direct": "Напрямую",
  "Mailbox": "Почта",
  "modems": "модемов",
  "No computers discovered": "Компьютеры не найдены",
  "Network disabled": "Сеть выключена",
  "Network unavailable": "Сеть недоступна",
  "Network send failed": "Не удалось отправить",
  "Invalid computer ID": "Неверный ID компьютера",
  "Invalid computer name": "Неверное имя компьютера",
  "No computer selected": "Не выбран компьютер",
  "Message": "Сообщение",
  "Message sent": "Сообщение отправлено",
  "Me": "Я",
  "No messages": "Нет сообщений",
  "Sending": "Отправка",
  "Delivered": "Доставлено",
  "Queued": "В очереди",
  "Mailbox full": "Почта переполнена",
  "Message must be 1-1024 bytes": "Сообщение от 1 до 1024 байт",
  "Select a computer to send file": "Выберите компьютер для файла",
  "File path": "Путь к файлу",
  "Offer sent": "Предложение отправлено",
  "Request sent": "Запрос отправлен",
  "TRANSFERS": "ПЕРЕДАЧИ",
  "No transfers": "Нет передач",
  "Offered": "Предложено",
  "Pending": "Ожидает",
  "Receiving": "Получение",
  "Sent": "Отправлено",
  "Declined": "Отклонено",
  " Accept ": " Принять ",
  " Decline ": " Отказ ",
  " Open ": " Открыть ",
  "No shared files": "Нет общих файлов",
  "Select a file": "Выберите файл",
  "File too large or invalid name": "Файл слишком велик или неверен",
  "Too many transfers": "Слишком много передач",
  "Offer unavailable": "Предложение недоступно",
  "Transfer unavailable": "Передача недоступна",
  "Done": "Готово",
  "Network operation failed": "Ошибка сетевой операции",
  "Select a message": "Выберите сообщение",
  "Interrupted": "Прервано",
  "Could not save message": "Не удалось сохранить сообщение",
  "Network changed": "Сеть изменена",
  "Version 0.9.1 / API 1": "Версия 0.9.1 / API 1"
}
]=],
    ["system/session.lua"]=[=[
-- The native terminal is an invisible backing buffer, composited by core.lua.
local M={}
function M.new(parent,w,h,fn)
  local s={parent=parent,w=w,h=h,done=false}
  s.view=window.create(parent,1,1,w,h,false)
  s.view.setBackgroundColor(colors.black)
  s.view.setTextColor(colors.white)
  s.view.clear()
  s.redirect=s.view
  s.thread=coroutine.create(fn)
  function s:resume(...)
    if self.done then return end
    local previous=term.redirect(self.redirect)
    local success,filter=coroutine.resume(self.thread,...)
    self.redirect=term.current()
    term.redirect(previous)
    if not success then self.done=true; self.error=tostring(filter)
    elseif coroutine.status(self.thread)=="dead" then self.done=true
    else self.filter=filter end
  end
  function s:event(name,...)
    if self.done then return false end
    if self.filter and self.filter~=name and name~="terminate" then return false end
    self:resume(name,...)
    return true
  end
  function s:resize(w,h)
    if self.w==w and self.h==h then return end
    self.w,self.h=w,h
    self.view.reposition(1,1,w,h)
    self:event("term_resize")
  end
  function s:stop()
    self.view.setVisible(false)
    self.done=true
  end
  s:resume()
  return s
end
return M
]=],
    ["system/translit.json"]=[=[
{
  "а": "a",
  "б": "b",
  "в": "v",
  "г": "g",
  "д": "d",
  "е": "e",
  "ё": "yo",
  "ж": "zh",
  "з": "z",
  "и": "i",
  "й": "y",
  "к": "k",
  "л": "l",
  "м": "m",
  "н": "n",
  "о": "o",
  "п": "p",
  "р": "r",
  "с": "s",
  "т": "t",
  "у": "u",
  "ф": "f",
  "х": "kh",
  "ц": "ts",
  "ч": "ch",
  "ш": "sh",
  "щ": "sch",
  "ъ": "'",
  "ы": "y",
  "ь": "'",
  "э": "e",
  "ю": "yu",
  "я": "ya",
  "А": "A",
  "Б": "B",
  "В": "V",
  "Г": "G",
  "Д": "D",
  "Е": "E",
  "Ё": "Yo",
  "Ж": "Zh",
  "З": "Z",
  "И": "I",
  "Й": "Y",
  "К": "K",
  "Л": "L",
  "М": "M",
  "Н": "N",
  "О": "O",
  "П": "P",
  "Р": "R",
  "С": "S",
  "Т": "T",
  "У": "U",
  "Ф": "F",
  "Х": "Kh",
  "Ц": "Ts",
  "Ч": "Ch",
  "Ш": "Sh",
  "Щ": "Sch",
  "Ъ": "'",
  "Ы": "Y",
  "Ь": "'",
  "Э": "E",
  "Ю": "Yu",
  "Я": "Ya"
}]=],
    ["system/util.lua"]=[=[
local M={}
M.root="/juzeppe"
function M.read(path)
  local f,err=fs.open(path,"r")
  if not f then return nil,err end
  local data=f.readAll()
  f.close()
  return data
end
function M.write(path,data)
  local dir=fs.getDir(path)
  if dir~="" and not fs.exists(dir) then fs.makeDir(dir) end
  local f,err=fs.open(path,"w")
  if not f then return nil,err end
  f.write(data)
  f.close()
  return true
end
function M.decode(data)
  if type(data)~="string" then return nil,"Missing JSON" end
  local ok,result,decodeError=pcall(textutils.unserializeJSON,data)
  if not ok then return nil,tostring(result) end
  if type(result)~="table" then return nil,decodeError or "Invalid JSON" end
  return result
end
function M.json(path)
  return M.decode(M.read(path))
end
function M.encode(value)
  return textutils.serializeJSON(value,{unicode_strings=true})
end
function M.load(path,env)
  local fn,err=loadfile(path,"t",env or _ENV)
  if not fn then return nil,err end
  local ok,result=pcall(fn)
  if not ok then return nil,result end
  return result
end
return M
]=],
    ["system/wm.lua"]=[=[
-- Window geometry and z-order; application execution belongs to core.lua.
local M={}
function M.new(width,height)
  local self={windows={},focused=nil,serial=0,instances={},W=width,H=height}
  local function bounds(w)
    local maxW,maxH=math.max(1,self.W),math.max(1,self.H-1)
    local minW,minH=math.min(24,maxW),math.min(9,maxH)
    return minW,minH,maxW,maxH
  end
  local function clamp(value,low,high)
    return math.max(low,math.min(high,value))
  end
  function self:fit(win)
    local minW,minH,maxW,maxH=bounds(win)
    if win.maximized then
      win.x,win.y,win.w,win.h=1,1,maxW,maxH
      return
    end
    win.w=clamp(win.w,minW,maxW)
    win.h=clamp(win.h,minH,maxH)
    win.x=clamp(win.x,1,maxW-win.w+1)
    win.y=clamp(win.y,1,self.H-win.h)
  end
  function self:newWindow(app)
    self.serial=self.serial+1
    self.instances[app.id]=(self.instances[app.id] or 0)+1
    local _,_,maxW,maxH=bounds()
    local width=math.min(maxW,math.max(24,math.floor(maxW*.78)))
    local height=math.min(maxH,math.max(9,math.floor(maxH*.82)))
    local offset=(self.serial-1)%4
    local win={id=self.serial,instanceNumber=self.instances[app.id],app=app,x=3+offset*2,y=3+offset,w=width,h=height,
      minimized=false,maximized=false,notice="",hits={},pending={}}
    self:fit(win)
    self.windows[#self.windows+1]=win
    self.focused=win
    return win
  end
  function self:exists(win)
    return win and not win.closed
  end
  function self:top()
    for i=#self.windows,1,-1 do
      if not self.windows[i].minimized then return self.windows[i] end
    end
  end
  function self:focus(win)
    if not self:exists(win) then return end
    for i=#self.windows,1,-1 do
      if self.windows[i]==win then table.remove(self.windows,i); break end
    end
    win.minimized=false
    self.windows[#self.windows+1]=win
    self.focused=win
  end
  function self:minimize(win)
    if not self:exists(win) then return end
    win.minimized=true
    if self.focused==win then self.focused=self:top() end
  end
  function self:desktop()
    for _,win in ipairs(self.windows) do win.minimized=true end
    self.focused=nil
  end
  function self:close(win)
    if not self:exists(win) then return end
    win.closed=true
    for i=#self.windows,1,-1 do
      if self.windows[i]==win then table.remove(self.windows,i); break end
    end
    if self.focused==win then self.focused=self:top() end
  end
  function self:hit(x,y)
    for i=#self.windows,1,-1 do
      local win=self.windows[i]
      if not win.minimized and x>=win.x and x<win.x+win.w and y>=win.y and y<win.y+win.h then return win end
    end
  end
  function self:toggleMax(win)
    if win.maximized then
      local g=win.restore
      win.x,win.y,win.w,win.h=g.x,g.y,g.w,g.h
      win.maximized=false
      win.restore=nil
    else
      win.restore={x=win.x,y=win.y,w=win.w,h=win.h}
      win.maximized=true
    end
    self:fit(win)
  end
  function self:move(win,x,y)
    if win.maximized then return end
    win.x,win.y=x,y
    self:fit(win)
  end
  function self:resize(win,width,height)
    if win.maximized then return end
    local minW,minH=bounds()
    win.w=clamp(width,minW,self.W-win.x+1)
    win.h=clamp(height,minH,self.H-win.y)
    self:fit(win)
  end
  function self:screen(width,height)
    self.W,self.H=width,height
    for _,win in ipairs(self.windows) do self:fit(win) end
  end
  function self:tasks()
    local result={}
    for _,win in ipairs(self.windows) do result[#result+1]=win end
    table.sort(result,function(a,b) return a.id<b.id end)
    return result
  end
  function self:cycle()
    local list=self:tasks()
    if #list==0 then return end
    local index=0
    for i,win in ipairs(list) do if win==self.focused then index=i; break end end
    self:focus(list[index%#list+1])
  end
  return self
end
return M


]=],
    ["system/kernel.lua"]=[=[
-- All host events enter here. A PID may run without owning a terminal window.
local journal=dofile("/juzeppe/system/journal.lua")
return function()
  local k={processes={},running=true}
  local serial=0
  function k.allocate()
    serial=serial+1
    return serial
  end
  function k.send(pid,event,...)
    if k.processes[pid] then os.queueEvent("juzeppe_message",pid,event,...) end
  end
  function k.stop(pid,reason)
    local p=k.processes[pid]
    if not p then return end
    k.processes[pid]=nil
    if p.finish then
      local ok,e=pcall(p.finish,reason)
      if not ok then journal(p.name,"cleanup",e) end
    end
  end
  local function resume(p,...)
    local previous=term.redirect(p.terminal)
    local ok,result=coroutine.resume(p.thread,...)
    p.terminal=term.current()
    term.redirect(previous)
    if not ok then journal(p.name,"crash",result,p.thread); k.stop(p.pid,"crash")
    elseif coroutine.status(p.thread)=="dead" then k.stop(p.pid,result or "done")
    else
      p.filter=result
      for i,msg in ipairs(p.mailbox) do
        if not p.filter or p.filter==msg[1] then
          table.remove(p.mailbox,i)
          k.send(p.pid,table.unpack(msg,1,msg.n))
          break
        end
      end
    end
  end
  function k.spawn(name,fn,finish)
    local p={pid=k.allocate(),name=name,mailbox={},thread=coroutine.create(fn),terminal=term.current(),finish=finish}
    k.processes[p.pid]=p
    resume(p,p.pid)
    return p.pid
  end
  function k.dispatch(event,...)
    if event=="juzeppe_message" then
      local pid,name=...
      local p=k.processes[pid]
      if p then
        if not p.filter or p.filter==name then resume(p,name,select(3,...))
        elseif #p.mailbox<64 then p.mailbox[#p.mailbox+1]=table.pack(name,select(3,...))
        else journal(p.name,"mailbox","Queue full") end
      end
      return
    end
    local ids={}
    for pid in pairs(k.processes) do ids[#ids+1]=pid end
    table.sort(ids)
    for _,pid in ipairs(ids) do
      local p=k.processes[pid]
      if p and (not p.filter or p.filter==event or event=="terminate") then resume(p,event,...) end
    end
  end
  return k
end
]=],
    ["repo/legacy-permissions.json"]=[=[
{"office@1.0.0":["desktop.files","clipboard","printer"]}
]=],
    ["system/app-loader.lua"]=[=[
-- Insert scheduling points at Lua loop and function entries; leave literals and comments intact.
return function(path,env,checkpoint)
  local handle,err=fs.open(path,"r")
  if not handle then return nil,err end
  local source=handle.readAll(); handle.close()
  local name="__juzeppe_checkpoint"
  while source:find(name,1,true) do name=name.."_" end
  local chunks={"return function("..name..") return function(...) "}; local i=1
  local parameters=false
  while i<=#source do
    local start=i
    local ch=source:sub(i,i)
    local comment=source:sub(i,i+1)=="--"
    local at=comment and i+2 or i
    local equals=source:match("^%[(=*)%[",at)
    local inject=false
    if equals then
      local _,last=source:find("]"..equals.."]",at+#equals+2,true)
      if not last then return nil,"Unclosed long literal" end
      i=last+1
    elseif comment then i=source:find("\n",at,true) or (#source+1)
    elseif ch=="'" or ch=='"' then
      i=i+1
      while i<=#source do
        local c=source:sub(i,i); i=i+1
        if c=="\\" then i=i+1 elseif c==ch then break end
      end
    elseif ch:match("[%a_]") then
      local _,last=source:find("^[%w_]+",i)
      i=last+1
      local word=source:sub(start,last)
      if word=="function" then parameters=true end
      inject=word=="do" or word=="repeat"
    else
      i=i+1
      if ch==")" and parameters then parameters=false; inject=true end
    end
    chunks[#chunks+1]=source:sub(start,i-1)
    if inject then chunks[#chunks+1]=" "..name.."(); " end
  end
  chunks[#chunks+1]="\nend end"
  local factory,why=load(table.concat(chunks),"@"..path,"t",env)
  if not factory then return nil,why end
  return factory()(checkpoint)
end
]=],
    ["system/stock-remote.lua"]=[=[
-- Read-only wireless stock protocol. Separate channels from the city network.
local REQUEST,REPLY=48530,48531
local PROTOCOL="juzeppe.stock/1"
local MAX_ROWS,CHUNK=4096,48
return function()
  local self={}
  local pending,ports={},{}
  local serial=0
  local running=true
  local function release(name)
    local port=ports[name]
    if not port then return end
    port.users=port.users-1
    if port.users==0 then
      ports[name]=nil
      if port.owned then pcall(peripheral.call,name,"close",REPLY) end
    end
  end
  local function finish(req,rows,err)
    pending[req.token]=nil
    req.done=true
    req.rows,req.err=rows,err
    os.cancelTimer(req.timer)
    release(req.side)
    os.queueEvent("juzeppe_stock_result",req.token)
  end
  local function acquire()
    local names=peripheral.getNames()
    table.sort(names)
    for _,name in ipairs(names) do
      if peripheral.hasType(name,"modem") then
        local ok,wireless=pcall(peripheral.call,name,"isWireless")
        if ok and wireless then
          local port=ports[name]
          if not port then
            local opened,already=pcall(peripheral.call,name,"isOpen",REPLY)
            if opened then
              local ready=already or pcall(peripheral.call,name,"open",REPLY)
              if ready then port={users=0,owned=not already}; ports[name]=port end
            end
          end
          if port then port.users=port.users+1; return name end
        end
      end
    end
  end
  function self.read(id,native)
    if not running then return nil,"Stock service stopped" end
    if type(id)~="number" or id%1~=0 or id<0 or id>2147483647 then
      return nil,"Invalid computer ID"
    end
    local side=acquire()
    if not side then return nil,"Connect a wireless modem" end
    serial=serial+1
    local token=tostring(os.getComputerID()).."-"..tostring(os.epoch("utc")).."-"..serial
    local req={token=token,side=side,host=id,native=native,parts={},received=0,rowsCount=0,timer=os.startTimer(12)}
    pending[token]=req
    local ok,err=pcall(peripheral.call,side,"transmit",REQUEST,REPLY,
      {protocol=PROTOCOL,kind=native and "native" or "request",from=os.getComputerID(),to=id,token=token})
    if not ok then finish(req,nil,tostring(err)) end
    while not req.done do os.pullEventRaw("juzeppe_stock_result") end
    return req.rows,req.err
  end
  local function validRows(rows)
    if type(rows)~="table" or #rows>CHUNK then return nil end
    local result={}
    for i=1,#rows do
      local row=rows[i]
      if type(row)~="table" or type(row.name)~="string" or #row.name==0 or #row.name>256 or
        type(row.count)~="number" or row.count<0 or row.count>9007199254740991 or row.count%1~=0 then
        return nil
      end
      result[i]={name=row.name,count=row.count}
    end
    return result
  end
  function self.event(e,a,b,c,d)
    if e=="timer" then
      for _,req in pairs(pending) do
        if req.timer==a then finish(req,nil,"No response from #"..req.host); break end
      end
    elseif e=="peripheral_detach" then
      ports[a]=nil
      for _,req in pairs(pending) do
        if req.side==a then finish(req,nil,"Wireless modem disconnected") end
      end
    elseif e=="modem_message" and b==REPLY and c==REQUEST and type(d)=="table" and d.protocol==PROTOCOL then
      local req=pending[d.token]
      if not req or req.side~=a or d.to~=os.getComputerID() or d.from~=req.host then return end
      if d.kind=="error" then
        finish(req,nil,type(d.error)=="string" and d.error:sub(1,160) or "Stock host error")
        return
      end
      if req.native then
        if d.kind=="native" and type(d.ticket)=="string" and #d.ticket==36 then finish(req,d.ticket) end
        return
      end
      if d.kind~="page" or type(d.total)~="number" or d.total%1~=0 or d.total<1 or
        d.total>math.ceil(MAX_ROWS/CHUNK) or type(d.index)~="number" or
        d.index%1~=0 or d.index<1 or d.index>d.total or (req.total and req.total~=d.total) then return end
      if req.parts[d.index] then return end
      local rows=validRows(d.rows)
      if not rows or (d.index<d.total and #rows~=CHUNK) then return end
      if req.rowsCount+#rows>MAX_ROWS then finish(req,nil,"Stock list too large"); return end
      req.total=d.total
      req.parts[d.index]=rows
      req.rowsCount=req.rowsCount+#rows
      req.received=req.received+1
      if req.received==req.total then
        local items={}
        for i=1,req.total do
          for _,row in ipairs(req.parts[i]) do items[#items+1]=row end
        end
        finish(req,items)
      end
    end
  end
  function self.close()
    running=false
    for _,req in pairs(pending) do finish(req,nil,"Stock service stopped") end
  end
  return self
end
]=],
    ["system/phone.lua"]=[=[
-- What'sJuz phone service. Wired and wireless modems, no central server.
local util=dofile("/juzeppe/system/util.lua")
local audioRequire=require
if not audioRequire then
  local env=setmetatable({},{__index=_ENV})
  env.require,env.package=dofile("/rom/modules/main/cc/require.lua").make(env,"/juzeppe/system")
  audioRequire=env.require
end
local dfpwm=audioRequire("cc.audio.dfpwm")
local CHANNEL,PROTOCOL=48640,"whatsjuz/1"
local HOME="/juzeppe/data/whatsjuz/"
local SIDES={top=true,bottom=true,left=true,right=true,front=true,back=true}
local function numberOK(n) return type(n)=="number" and n%1==0 and n>=10 and n<=99 end
local function idOK(n) return type(n)=="number" and n%1==0 and n>=0 and n<=2147483647 end
return function(notify)
  local self={}
  local id=os.getComputerID()
  local session=tostring(os.epoch("utc"))..":"..id..":"..math.random(1000000)
  local enabled,activated=false,false
  local number,speaker,mic
  local modems={}
  local peers,ended={},{}
  local call,notice
  local serial=0
  local nextHello,nextScan=0,0
  local timer
  local function info(s) notice=s end
  local function installed() return fs.exists("/juzeppe/apps/whatsjuz/manifest.json") end
  local function save()
    if not fs.exists(HOME) then fs.makeDir(HOME) end
    util.write(HOME.."enabled",enabled and "on" or "off")
    if number then util.write(HOME.."number",tostring(number)) end
  end
  local function invoke(name,method,...)
    if not name then return false end
    return pcall(peripheral.call,name,method,...)
  end
  local function send(kind,peer,fields)
    if not next(modems) or not number then return false end
    local p=fields or {}
    p.protocol,p.kind,p.from,p.number,p.session=PROTOCOL,kind,id,number,session
    if peer then
      p.to,p.forSession=peer.id,peer.session
      local route=peers[peer.id]
      if route and route.session==peer.session and modems[route.side] and
          invoke(route.side,"transmit",CHANNEL,CHANNEL,p) then return true end
    end
    local sent=false
    for side in pairs(modems) do
      if invoke(side,"transmit",CHANNEL,CHANNEL,p) then sent=true end
    end
    return sent
  end
  local function hello()
    local label=os.getComputerLabel() or ("Terminal "..id)
    send("hello",nil,{label=tostring(label):sub(1,32)})
    nextHello=os.clock()+2
  end
  local function chooseNumber()
    local used={}
    for _,p in pairs(peers) do used[p.number]=true end
    local free={}
    for n=10,99 do if not used[n] then free[#free+1]=n end end
    number=#free>0 and free[math.random(#free)] or nil
    if number then save(); hello(); info("Your number: "..number)
    else info("No free phone number") end
  end
  local function chooseIfConflict()
    if not number then chooseNumber(); return end
    for _,p in pairs(peers) do
      if p.number==number and p.id<id then chooseNumber(); return end
    end
  end
  local function peerOf(c) return {id=c.peer,session=c.peerSession} end
  local function signal(kind,c,fields)
    local p=fields or {}; p.call=c.key
    return send(kind,peerOf(c),p)
  end
  local function clearAudio()
    if call then
      if call.playing then invoke(speaker,"stop") end
      call.audio={}; call.audioSize=0; call.playing=false
    end
  end
  local function finish(reason,tell)
    local c=call
    if c then
      if tell then signal("end",c,{reason=reason}) end
      ended[c.key]={expires=os.clock()+30,peer=c.peer,session=c.peerSession}
      clearAudio()
      call=nil
    end
    info(reason)
  end
  local function closeModem()
    for side,port in pairs(modems) do
      if port.owned then invoke(side,"close",CHANNEL) end
    end
    modems={}
  end
  local function scan()
    local list=peripheral.getNames()
    table.sort(list)
    local present,newSpeaker,newMic={},nil,nil
    local changed=false
    for _,name in ipairs(list) do
      -- Physical devices only: a cable must never select another phone's speaker or modem.
      if SIDES[name] then
        local ok,kind=pcall(peripheral.getType,name)
        if ok then
          if kind=="modem" then
            local checked,wireless=invoke(name,"isWireless")
            local opened,already=invoke(name,"isOpen",CHANNEL)
            if checked and opened and (already or invoke(name,"open",CHANNEL)) then
              local old=modems[name]
              present[name]={owned=old and old.owned or not already,wireless=wireless}
              if not old or old.wireless~=wireless or not already then changed=true end
            end
          elseif kind=="speaker" and not newSpeaker then newSpeaker=name
          elseif kind=="microphone" and not newMic then newMic=name end
        end
      end
    end
    if mic~=newMic and call then call.muted=true; call.micReady=false end
    if speaker~=newSpeaker and call then clearAudio() end
    speaker,mic=newSpeaker,newMic
    for side,port in pairs(modems) do
      if not present[side] then
        if port.owned then invoke(side,"close",CHANNEL) end
        changed=true
      end
    end
    modems=present
    if changed then
      if not next(modems) then
        if call then finish("Connection lost",false) end
        peers={}
      else
        for _,peer in pairs(peers) do if not modems[peer.side] then peer.side=nil end end
        hello()
      end
    end
    nextScan=os.clock()+2
  end
  local function begin(peer,kind,key)
    local now=os.clock()
    call={peer=peer.id,peerSession=peer.session,peerNumber=peer.number,key=key,state=kind,
      started=now,last=now,nextSignal=now,nextTone=now,tone=0,muted=true,micReady=false,
      audio={},audioSize=0,sequence=0,lastSequence=0,playing=false}
    return call
  end
  local function connect(c)
    c.state="active"; c.connected=os.clock(); c.last=os.clock(); c.nextSignal=0
    c.muted=true; c.micReady=false
    info("Connected. Press Talk to enable microphone.")
  end
  local function validPacket(p)
    return type(p)=="table" and p.protocol==PROTOCOL and idOK(p.from) and p.from~=id and
      numberOK(p.number) and type(p.session)=="string" and #p.session<=96 and type(p.kind)=="string"
  end
  local function matched(p)
    return call and call.peer==p.from and call.peerSession==p.session and call.key==p.call
  end
  local function addAudio(p,c)
    if c.state~="active" or not speaker or type(p.data)~="string" or #p.data>1024 or
      type(p.samples)~="number" or p.samples%1~=0 or p.samples<1 or p.samples>8192 or
      #p.data~=math.ceil(p.samples/8) or not idOK(p.seq) or p.seq<=c.lastSequence then return end
    c.lastSequence=p.seq
    -- A bounded jitter buffer, independently decodable packets.
    local ok,samples=pcall(function() return dfpwm.make_decoder()(p.data) end)
    if not ok then return end
    while #samples>p.samples do samples[#samples]=nil end
    if c.audioSize==0 then c.audioSince=os.clock() end
    c.audio[#c.audio+1]=samples; c.audioSize=c.audioSize+#samples
    while c.audioSize>48000 and #c.audio>0 do
      c.audioSize=c.audioSize-#table.remove(c.audio,1)
    end
  end
  local function receive(p,side)
    if not validPacket(p) then return end
    if p.kind=="hello" then
      local old=peers[p.from]
      peers[p.from]={id=p.from,session=p.session,number=p.number,last=os.clock(),side=side,
        label=type(p.label)=="string" and p.label:sub(1,32):gsub("[%z\1-\31\127]","") or ("Terminal "..p.from)}
      chooseIfConflict()
      if not old or old.session~=p.session then hello() end
      return
    end
    if p.kind=="bye" then
      local old=peers[p.from]
      if old and old.session==p.session then peers[p.from]=nil end
      if call and call.peer==p.from and call.peerSession==p.session then finish("Other phone offline",false) end
      return
    end
    if p.to~=id or p.forSession~=session or type(p.call)~="string" or #p.call>128 then return end
    local peer=peers[p.from]
    if not peer or peer.session~=p.session then return end
    peer.last=os.clock()
    peer.side=side
    if p.kind=="invite" then
      local previous=ended[p.call]
      if previous and previous.peer==p.from and previous.session==p.session then
        send("end",peer,{call=p.call,reason="Call ended"}); return
      end
      if matched(p) then
        if call.state=="active" then signal("answer",call)
        elseif call.state=="incoming" then signal("ringing",call) end
        return
      end
      if call and call.state=="dialing" and call.peer==p.from and p.from<id then
        finish("Switching call",true)
      end
      if call then send("busy",peer,{call=p.call}); return end
      begin(peer,"incoming",p.call)
      signal("ringing",call)
      info("Incoming call from "..peer.number)
      notify("What'sJuz: "..peer.number.." calling. Open What'sJuz.")
      return
    end
    if not matched(p) then return end
    local c=call
    c.last=os.clock()
    if p.kind=="answer" and c.state=="dialing" then
      connect(c); signal("alive",c)
    elseif p.kind=="alive" and c.state=="active" then
      -- Both peers must remain online.
    elseif p.kind=="alive" and c.state=="dialing" then
      connect(c); signal("alive",c)
    elseif p.kind=="busy" and c.state=="dialing" then finish("Line busy",false)
    elseif p.kind=="end" then finish("Call ended",false)
    elseif p.kind=="audio" then addAudio(p,c)
    end
  end
  local function playAudio(c)
    if not speaker or c.audioSize==0 then return end
    if c.audioSize<4800 and not c.playing and os.clock()-(c.audioSince or 0)<0.25 then return end
    local data={}
    local count=0
    for _,chunk in ipairs(c.audio) do
      for _,value in ipairs(chunk) do data[#data+1]=value end
      count=count+1
      if #data>=9600 then break end
    end
    local ok,queued=invoke(speaker,"playAudio",data,1)
    if ok and queued then
      for _=1,count do c.audioSize=c.audioSize-#table.remove(c.audio,1) end
      c.playing=true
    end
  end
  local function capture(c)
    if c.muted or not mic then return end
    local limit=c.micReady and 8192 or 16384
    local ok,data=invoke(mic,"pullAudio",limit)
    if not ok or type(data)~="table" then c.muted=true; info("Microphone unavailable"); return end
    if not c.micReady then
      if #data<limit then c.micReady=true; info("Microphone on") end
      return
    end
    if #data==0 or #data>limit then return end
    local length=#data
    for i=1,length do
      local n=data[i]
      if type(n)~="number" or n%1~=0 or n< -128 or n>127 then
        c.muted=true; info("Unsupported microphone audio format"); return
      end
    end
    for i=length+1,math.ceil(length/8)*8 do data[i]=0 end
    local compressed=dfpwm.make_encoder()(data)
    c.sequence=c.sequence+1
    signal("audio",c,{data=compressed,samples=length,seq=c.sequence})
  end
  local function tone(c,now)
    if not speaker or now<c.nextTone then return end
    c.tone=(c.tone+1)%6
    if c.state=="incoming" then
      local notes={[1]=12,[2]=16,[3]=19}
      if notes[c.tone] then invoke(speaker,"playNote","pling",1,notes[c.tone]) end
      c.nextTone=now+(c.tone==3 and 0.9 or 0.22)
    else
      if c.tone==1 or c.tone==2 then invoke(speaker,"playNote","bass",0.9,11) end
      c.nextTone=now+(c.tone==2 and 1.3 or 0.25)
    end
  end
  local function tick()
    if not enabled then return end
    local now=os.clock()
    if now>=nextScan then
      if not installed() then
        if call then finish("What'sJuz removed",true) end
        send("bye"); closeModem(); enabled=false; return
      end
      scan()
    end
    for peer,p in pairs(peers) do if now-p.last>9 then peers[peer]=nil end end
    for key,e in pairs(ended) do if now>e.expires then ended[key]=nil end end
    if not number then chooseNumber() end
    if now>=nextHello then hello() end
    if not call then return end
    local c=call
    if not next(modems) then finish("No modem",false); return end
    if c.state=="active" then
      if now-c.last>8 then finish("Connection lost",false); return end
      if now>=c.nextSignal then signal("alive",c); c.nextSignal=now+1 end
      capture(c); playAudio(c)
    else
      if now-c.started>25 then finish("No answer",true); return end
      if c.state=="dialing" and now>=c.nextSignal then
        signal("invite",c); c.nextSignal=now+1
      end
      tone(c,now)
    end
  end
  local function online()
    enabled=true
    if not number then chooseNumber() end
    save(); scan(); hello()
    info(next(modems) and ("Ready: "..tostring(number)) or "Connect a modem")
  end
  local function command(name,value)
    if name=="initialize" then
      if not activated and installed() then activated=true; online() end
    elseif name=="online" and installed() then activated=true; online()
    elseif name=="offline" then
      if call then finish("Offline",true) end
      send("bye"); enabled=false; closeModem(); peers={}; save(); info("Offline")
    elseif name=="dial" then
      if not enabled or not next(modems) or not number then info("Connect a modem"); return end
      if call then info("Already in a call"); return end
      local n=tonumber(value)
      if not numberOK(n) or n==number then info("Enter a different two-digit number"); return end
      local peer
      for _,p in pairs(peers) do
        if p.number==n then
          if peer then info("Number resolving. Try again."); return end
          peer=p
        end
      end
      if not peer then info("Number offline: "..n); return end
      serial=serial+1
      local c=begin(peer,"dialing",session..":"..serial)
      signal("invite",c); c.nextSignal=os.clock()+1; info("Calling "..n)
    elseif name=="answer" and call and call.state=="incoming" then
      connect(call); signal("answer",call)
    elseif name=="end" and call then finish("Call ended",true)
    elseif name=="talk" and call and call.state=="active" then
      if not mic then info("Connect a microphone"); return end
      call.muted=not call.muted
      call.micReady=false
      info(call.muted and "Microphone off" or "Preparing microphone...")
    end
  end
  function self.command(name,value)
    if name=="initialize" or name=="online" or name=="offline" or name=="dial" or
      name=="answer" or name=="end" or name=="talk" then
      if name=="dial" and not numberOK(tonumber(value)) then return false,"Invalid number" end
      os.queueEvent("juzeppe_phone_command",name,value)
      return true
    end
    return false,"Unknown phone operation"
  end
  function self.status()
    local list={}
    for _,p in pairs(peers) do list[#list+1]={number=p.number,label=p.label,id=p.id} end
    table.sort(list,function(a,b) return a.number==b.number and a.id<b.id or a.number<b.number end)
    local c
    if call then c={state=call.state,number=call.peerNumber,muted=call.muted,
      micReady=call.micReady,seconds=call.connected and math.floor(os.clock()-call.connected) or 0} end
    return {enabled=enabled,number=number,online=enabled and next(modems)~=nil,peers=list,call=c,
      speaker=speaker~=nil,microphone=mic~=nil,notice=notice or ""}
  end
  function self.run()
    local v=util.read(HOME.."enabled")
    if installed() and v then
      activated=true
      local n=tonumber(util.read(HOME.."number") or "")
      if numberOK(n) then number=n end
      if v=="on" then online() end
    end
    timer=os.startTimer(0.2)
    while true do
      local e,a,b,c,d=os.pullEventRaw()
      if e=="juzeppe_phone_command" then command(a,b)
      elseif enabled and e=="modem_message" and modems[a] and b==CHANNEL and c==CHANNEL then receive(d,a)
      elseif e=="timer" and a==timer then
        tick()
        timer=os.startTimer(call and (call.state=="active" and 0.1 or 0.2) or (enabled and 0.5 or 2))
      elseif enabled and (e=="peripheral" or e=="peripheral_detach") then scan()
      elseif e=="speaker_audio_empty" and call and a==speaker then
        call.playing=false; playAudio(call)
      elseif e=="juzeppe_packages_changed" and enabled and not installed() then
        command("offline")
      end
    end
  end
  function self.close()
    if call then finish("Phone stopped",true) end
    send("bye"); closeModem()
    if timer then os.cancelTimer(timer) end
  end
  return self
end
]=],
  }
  local swapped={}
  local ok,err=pcall(function()
    for path,data in pairs(files) do
      if path:match("%.lua$") then assert(load(data,"@"..path,"t",{})) end
      write(stage.."/"..path,data)
    end
    for _,name in ipairs(names) do
      if fs.exists(root.."/"..name) then fs.move(root.."/"..name,backup.."/"..name) end
      swapped[#swapped+1]=name
      fs.move(stage.."/"..name,root.."/"..name)
    end
    for _,name in ipairs({"apps","data","config","desktop"}) do
      if not fs.exists(root.."/"..name) then fs.makeDir(root.."/"..name) end
    end
    write(root.."/version",version)
  end)
  if not ok then
    for i=#swapped,1,-1 do
      local name=swapped[i]
      if fs.exists(root.."/"..name) then fs.delete(root.."/"..name) end
      if fs.exists(backup.."/"..name) then fs.move(backup.."/"..name,root.."/"..name) end
    end
    if fs.exists(stage) then fs.delete(stage) end
    if fs.exists(backup) then fs.delete(backup) end
    error(err,0)
  end
  fs.delete(stage)
  fs.delete(backup)
end
if read(root.."/version")~=version or args[1]=="--install" or not fs.exists(root.."/system/core.lua") then
  print("Installing JuzeppeOS "..version.."...")
  local ok,err=pcall(install)
  if not ok then printError("Install failed: "..tostring(err)); return end
  print("Installation successful.")
end
shell.setAlias("jpkg","/juzeppe/bin/jpkg.lua")
shell.setAlias("juznet","/juzeppe/bin/juznet.lua")
if args[1]=="--autostart" then
  local boot='assert(loadfile("/juzeppe/start.lua","t",_ENV))()\n'
  if fs.exists("/startup.lua") and read("/startup.lua")~=boot or fs.exists("/startup") then
    printError("Existing startup found. To start JuzeppeOS, call /juzeppe/start.lua from it.")
    return
  end
  write("/startup.lua",boot)
  print("JuzeppeOS will start on boot.")
end
if args[1]=="--install-only" then return end
return assert(loadfile("/juzeppe/start.lua","t",_ENV))()