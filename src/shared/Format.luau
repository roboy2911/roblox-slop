-- Number and time formatting: 1234 -> "1.23K", 75 -> "1:15".

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

function Format.Number(n: number): string
	n = math.floor(n)
	if math.abs(n) < 1000 then
		return tostring(n)
	end
	local tier = math.min(math.floor(math.log10(math.abs(n)) / 3), #SUFFIXES - 1)
	local scaled = n / 10 ^ (tier * 3)
	local text
	if math.abs(scaled) >= 100 then
		text = ("%d"):format(math.floor(scaled))
	elseif math.abs(scaled) >= 10 then
		text = ("%.1f"):format(math.floor(scaled * 10) / 10)
	else
		text = ("%.2f"):format(math.floor(scaled * 100) / 100)
	end
	-- "1.50" -> "1.5", "2.00" -> "2"
	if text:find("%.") then
		text = (text:gsub("0+$", ""))
		text = (text:gsub("%.$", ""))
	end
	return text .. SUFFIXES[tier + 1]
end

function Format.Gold(n: number): string
	return "$" .. Format.Number(n)
end

function Format.Time(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	local m = math.floor(seconds / 60)
	local s = seconds % 60
	if m >= 60 then
		return ("%d:%02d:%02d"):format(math.floor(m / 60), m % 60, s)
	end
	return ("%d:%02d"):format(m, s)
end

return Format
