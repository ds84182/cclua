local string = require "string"
term = {}

local cx,cy = 1,1
local w,h = 51,19
local cursor = false

local allowedChars = " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_'abcdefghijklmnopqrstuvwxyz{|}~"
_G.charAllowed = {}
for i=1, #allowedChars do
	charAllowed[allowedChars:byte(i)] = true
end

function term.clear()
	local sx,sy = term.getCursorPos()
	for i=1, h do
		term.setCursorPos(1,i)
		term.clearLine()
	end
	term.setCursorPos(sx,sy)
end

function term.setCursorPos(x,y)
	curses.curs_set(cursor and 1 or 0)
	curses.move(y-1,x-1)
	curses.refresh()
	cx = x
	cy = y
end

function term.getCursorPos()
	return cx, cy
end

function term.clearLine()
	--First, make sure we are on the line
	curses.move(cy-1,0)
	curses.addstr(string.rep(" ",w))
	curses.refresh()
	term.setCursorPos(term.getCursorPos())
end

function term.scroll(n)
	curses.move(0,0)
	for i=1, n do curses.stdscr():deleteln() end
	curses.refresh()
	term.setCursorPos(term.getCursorPos())
end

function term.write(str)
	term.setCursorPos(term.getCursorPos())
	--Scan the str for invalid values
	for i=1, #str do
		local chr = str:sub(i,i)
		local byt = chr:byte()
		--if cx <= w and cy <= h then
			if charAllowed[byt] then
				curses.addch(chr)
			else
				curses.addch("?")
			end
		--end
		cx = cx+1
	end
	curses.refresh()
	term.setCursorPos(term.getCursorPos())
end