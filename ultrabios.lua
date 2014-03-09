--Ultrabios: Does stuff via standard input--
--[[
UltraBios will receive and send events, call functions on the other side, ect.

Example:
Q push_this_event_to_the_queue //Puts this event onto the event queue
P push_this_event_to_the_queue //Pulls the event off the event queue and expects it to come back
WRITE Screen text here.
SPOS 1 2
GPOS //It will now wait for it to arrive via std input
PERLST right //Give back the list of peripheral methods
PERCALL right isWired //Calls the method and gets it's output

Lua Code:
os.queueEvent("push_this_event_to_the_queue")
os.pullEvent("push_this_event_to_the_queue")
term.write("Screen text here.")
term.setCursorPos(1,2)
term.getCursorPos()
peripheral.list("right")
peripheral.call("right", "isWired")
]]

local coroutine = require "coroutine"
local oldG = _G

local string = require "string"
local io = require "io"
local path = require "path"
local fs = require "fs"

setfenv(1,setmetatable({},{__index=_G}))

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

function unserialize( s )
	local func, e = loadstring( "return "..s, "serialize" )
	if not func then
		return s
	else
		setfenv( func, {} )
		return func()
	end
end

local env = {}
env._G = env
env.string = require "string"
env.math = require "math"
env.table = require "table"
env.coroutine = coroutine
setmetatable(env,{__index=oldG})

local osetfenv = setfenv
local type = type
local error = error
function env.setfenv(f,env)
	if type(f) == "function" then
		return osetfenv(f,env)
	else
		if f == 0 then
			error("Cannot set this enviroment")
		else
			return osetfenv(f,env)
		end
	end
end

local ogetfenv = getfenv
function env.getfenv(f)
	if type(f) == "function" then
		return ogetfenv(f)
	else
		if f == 0 then
			error("Cannot get this enviroment")
		else
			return ogetfenv(f)
		end
	end
end

--function io.read()
--	return process.stdin:on("data")
--end

local os = os

env.os = {
	pullEventRaw = function(filter)
		coroutine.yield(filter)
	end,
	queueEvent = function(event)
		print("Q "..serialize({event}))
	end,
	getComputerID = function() return 0 end
}

local function getDir(p)
	local dir = path.normalize(p)
	--p(dir)
	--term.write(dir)
	if dir:sub(1,1) ~= "/" then dir = "/"..dir end
	local out
	if dir:sub(1, 4) == "/rom" then
		return "lua/"..dir
	else
		return "computer/"..dir
	end
end

env.fs = {
	list = function(path)
		local dir = getDir(path)
		return fs.readdirSync(dir)
	end,
	combine = function(root,child)
		return path.join(root,child)
	end,
	isDir = function(path)
		return fs.statSync(getDir(path)).is_directory
	end,
	getName = function(dir)
		local dirt = {}
		for part in dir:gmatch("[^/]+") do
			dirt[#dirt+1] = part
		end
		return dirt[#dirt]
	end,
	exists = function(dir) return fs.existsSync(getDir(dir)) end,
	isReadOnly = function(dir) return getDir(dir):sub(1,3) == "lua" end,
	open = function(dir, mode)
		dir = getDir(dir)
		if dir:sub(1,3) == "lua" and mode == "w" then return nil, "read only" end
		if mode == "r" then
			local data = fs.readFileSync(dir)
			local pos = 1
			local lines = {}
			local _ps = 1
			local nline = 1
			for line in data:gmatch("[^\n]+") do lines[#lines+1] = line end
			local fh = {}
			function fh.readAll()
				local d = data:sub(pos)
				pos = #data
				return d
			end
			function fh.readLine()
				local l = lines[nline]
				nline = nline+1
				return l
			end
			function fh.close()
				data = nil
				lines = nil
			end
			return fh
		end
	end
}

env.term = {
	write = function(str)
		print("WRITE "..serialize({str}))
		io.read()
	end,
	isColour = function() return false end,
	getSize = function() return 51,19 end,
	getCursorPos = function() print("GPOS 0") return unpack(unserialize(io.read())) end,
	setCursorPos = function(...)
		print("SPOS "..serialize({...}))
		io.read()
	end,
	setTextColour = function() end,
	setBackgroundColour = function() end,
	setTextColor = function() end,
	setBackgroundColor = function() end,
	setCursorBlink = function() end,
	isColor = function() return false end,
	clear = function() print("CLS  ") end,
	clearLine = function() print("CL  ") end,
	scroll = function(n) print("SCR  {"..n.."}") end
}

env.rs = {
	getSides = function() return {"top","bottom","left","right","front","back"} end,
}

env.peripheral = {
	getType = function() end,
	isPresent = function() return false end
}

local bios = loadstring((require "fs").readFileSync("lua/bios.lua"),"bios.lua")
setfenv(bios,env)

local coro = coroutine.create(bios)
local resumeArgs = {}

while coroutine.status(coro) == "suspended" do
	local ret = {coroutine.resume(coro,unpack(resumeArgs))}
	resumeArgs = {}
	if ret[1] then
		print("P "..serialize({ret[2]}))
		resumeArgs = unserialize(io.read("*l"))
	else
		print("WRITE "..serialize({ret[2]}))
		while true do end
		break
	end
end
