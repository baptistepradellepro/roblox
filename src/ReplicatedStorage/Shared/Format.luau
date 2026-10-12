--[[
	Format : affiche les grands nombres de façon lisible.
	1200 -> "1.2K", 3400000 -> "3.4M", 75 -> "1:15"
]]

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx" }

local function trimZeros(s: string): string
	if string.find(s, ".", 1, true) then
		s = string.gsub(s, "0+$", "")
		s = string.gsub(s, "%.$", "")
	end
	return s
end

function Format.short(n: number?): string
	local value = math.floor(n or 0)
	local negative = value < 0
	value = math.abs(value)
	if value < 1000 then
		return (if negative then "-" else "") .. tostring(value)
	end
	local i = 1
	local v = value
	while v >= 1000 and i < #SUFFIXES do
		v /= 1000
		i += 1
	end
	local s
	if v < 10 then
		s = trimZeros(string.format("%.2f", math.floor(v * 100) / 100))
	elseif v < 100 then
		s = trimZeros(string.format("%.1f", math.floor(v * 10) / 10))
	else
		s = tostring(math.floor(v))
	end
	return (if negative then "-" else "") .. s .. SUFFIXES[i]
end

-- 75 -> "1:15", 9 -> "9s", 3725 -> "1:02:05"
function Format.time(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	if s < 60 then
		return tostring(s) .. "s"
	elseif s < 3600 then
		return string.format("%d:%02d", s // 60, s % 60)
	end
	return string.format("%d:%02d:%02d", s // 3600, (s % 3600) // 60, s % 60)
end

-- 30 -> "30 %", 2.5 -> "2.5 %"
function Format.percent(n: number): string
	local rounded = math.floor(n * 10 + 0.5) / 10
	local text = if rounded == math.floor(rounded) then tostring(math.floor(rounded)) else tostring(rounded)
	return text .. " %"
end

return Format
