local s,e = pcall(
function()
local fs = require "fs"
local cp = require "childprocess"
local path = require "path"
local table = require "table"
local timer = require "timer"
local string = require "string"


local function serializeImpl( t, tTracking )	
	local sType = type(t)
	if sType == "table" then
		if tTracking[t] ~= nil then
			error( "Cannot serialize table with recursive entries" )
		end
		tTracking[t] = true
		
		local result = "{"
		for k,v in pairs(t) do
			result = result..("["..serializeImpl(k, tTracking).."]="..serializeImpl(v, tTracking)..",")
		end
		result = result.."}"
		return result
		
	elseif sType == "string" then
		return string.format( "%q", t )
	
	elseif sType == "number" or sType == "boolean" or sType == "nil" then
		return tostring(t)
		
	else
		error( "Cannot serialize type "..sType )
		
	end
end

function serialize( t )
	local tTracking = {}
	return serializeImpl( t, tTracking )
end

function dofile(path)
	return loadstring(fs.readFileSync(path))()
end
curses = dofile "curses.lua"
curses.initscr()
curses.echo(false)
curses.nl(false)
curses.timeout(0)
local keymap = 
{
	13,28,
	127,14,
	{91,65},200,
	{91,68},203,
	{91,66},208,
	{91,67},205,
}

dofile("native/term.lua")

term.clear()
term.setCursorPos(1,1)
--term.clearLine()

_G.lua = cp.spawn("bash",{"-c", "luvit ultrabios.lua"},{env=process.env})
lua = lua
local empty = function()end

--lua.stdout:pipe(process.stdout)

local eventQueue = {}
local waitingFor
local isWaiting = false
local function eventAdd(...)
	if isWaiting then
		local args = {...}
		if args[1] == waitingFor or waitingFor == nil then
			lua.stdin:write(serialize({...}).."\n",empty)
			isWaiting = false
		end
	else
		eventQueue[#eventQueue+1] = {...}
	end
end

lua.stdout:on('data', function (chunk)
	--p(chunk)
	for chunk in chunk:gmatch("[^\n]+") do
		local cmd, tab = chunk:match("^([^ ]+) (.+)$")
		if not cmd then return end
		tab, e = loadstring("return "..tab)
		if not tab then error(e) end
		setfenv(tab,{})
		tab = tab()
		if cmd == "WRITE" then
			term.write(tab[1])
			lua.stdin:write("\n",empty)
		elseif cmd == "GPOS" then
			lua.stdin:write(serialize({term.getCursorPos()}).."\n",empty)
		elseif cmd == "SPOS" then
			term.setCursorPos(tab[1],tab[2])
			lua.stdin:write("\n",empty)
		elseif cmd == "CLS" then
			term.clear()
		elseif cmd == "CL" then
			term.clearLine()
		elseif cmd == "SCR" then
			term.scroll(tab[1])
		elseif cmd == "P" then
			--Oh my.
			--First sift through the event queue for the event
			if tab[1] == nil and #eventQueue > 0 then
				local event = table.remove(eventQueue,1)
				lua.stdin:write(serialize(event).."\n",empty)
			elseif #eventQueue > 0 then
				local event
				while event and event[1] ~= tab[1] do
					event = table.remove(eventQueue,1)
				end
				if event then lua.stdin:write(serialize(event).."\n",empty) else isWaiting = true waitingFor = tab[1] end
			else
				isWaiting = true
				waitingFor = tab[1]
			end
		else
			error("Unknown command "..chunk)
		end
	end
end)

--lua.stderr:pipe(process.stdout)

lua.stderr:on('data', function (chunk)
	--p(chunk)
end)

lua:on('error', function(err) p(err) end)

lua:on('exit', function(err) p(err) end)

lua.stderr:on('data', function (chunk)
	
end)

timer.setInterval(20, function (arg1)
	local got = curses.stdscr():getch()
	if got then
		if got == 27 then
			local m2, m3
			while not m2 do m2 = curses.stdscr():getch() end
			while not m3 do m3 = curses.stdscr():getch() end
			--Look for tables
			for i=1, #keymap, 2 do
				if type(keymap[i]) == "table" then
					local k = keymap[i]
					if k[1] == m2 and k[2] == m3 then
						eventAdd("key",keymap[i+1])
						break
					end
				end
			end
		else
			local f = false
			for i=1, #keymap, 2 do
				if keymap[i] == got then
					eventAdd("key",keymap[i+1])
					f = true
				end
			end
			if not f then eventAdd("key",got) end
			if _G.charAllowed[got] then
				eventAdd("char",string.char(got))
			end
		end
	end
end)

require('uv_native').run()
end)
if _G.lua then
	process.kill(_G.lua.pid,9)
end
curses.endwin()
if not s then print(e) end
(require "io").read()
process.exit(0)
