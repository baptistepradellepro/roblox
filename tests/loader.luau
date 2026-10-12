--[[
	Chargeur de modules pour Lune : permet d'exécuter les ModuleScripts du jeu
	hors de Roblox (faux "script", faux "require", vrais types Roblox de @lune/roblox).
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local game = roblox.Instance.new("DataModel")
local realWorkspace = game:GetService("Workspace")

local warnings = {}

---------------------------------------------------------------- Faux "Random" et "TweenInfo"
local RandomMock = {}
RandomMock.__index = RandomMock
function RandomMock.new(seed: number?)
	local self = setmetatable({ state = seed or 12345 }, RandomMock)
	return self
end
function RandomMock:NextNumber(min: number?, max: number?)
	self.state = (self.state * 1103515245 + 12345) % 2147483648
	local r = self.state / 2147483648
	if min and max then
		return min + (max - min) * r
	end
	return r
end
function RandomMock:NextInteger(min: number, max: number)
	return math.floor(self:NextNumber(min, max + 1))
end

---------------------------------------------------------------- Chargeur de modules
local moduleCache = {}
local mockCache = {}
local folderMock, childOf, loadModule

local gameProxy = setmetatable({}, {
	__index = function(_, key)
		if key == "GetService" then
			return function(_, name)
				if name == "ReplicatedStorage" then
					return folderMock("src/ReplicatedStorage")
				end
				return game:GetService(name)
			end
		end
		return nil
	end,
})

local function moduleMock(path: string, dir: string)
	if not mockCache[path] then
		local name = string.match(path, "([^/]+)%.luau$")
		mockCache[path] = { __module = path, Name = name, Parent = folderMock(dir) }
	end
	return mockCache[path]
end

function folderMock(dir: string)
	if mockCache[dir] then
		return mockCache[dir]
	end
	local folder = setmetatable({ __dir = dir }, {
		__index = function(_, key)
			if key == "WaitForChild" or key == "FindFirstChild" then
				return function(_, name)
					return childOf(dir, name)
				end
			end
			return childOf(dir, key)
		end,
	})
	mockCache[dir] = folder
	return folder
end

-- On liste tous les fichiers à l'avance (pas d'accès disque dans les métaméthodes)
local tree: { [string]: string } = {}
local function scanTree(dir: string)
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			tree[path] = "dir"
			scanTree(path)
		else
			tree[path] = "file"
		end
	end
end
scanTree("src")

function childOf(dir: string, name: string)
	if tree[dir .. "/" .. name .. ".luau"] == "file" then
		return moduleMock(dir .. "/" .. name .. ".luau", dir)
	end
	if tree[dir .. "/" .. name] == "dir" then
		return folderMock(dir .. "/" .. name)
	end
	return nil
end

local function customRequire(target)
	if type(target) == "table" and target.__module then
		return loadModule(target.__module)
	end
	error("require inattendu : " .. tostring(target))
end

function loadModule(path: string)
	if moduleCache[path] ~= nil then
		return moduleCache[path]
	end
	local dir = string.match(path, "^(.*)/[^/]+$")
	local env = {
		script = moduleMock(path, dir),
		require = customRequire,
		game = gameProxy,
		workspace = realWorkspace,
		Instance = roblox.Instance,
		Vector3 = roblox.Vector3,
		Vector2 = roblox.Vector2,
		CFrame = roblox.CFrame,
		Color3 = roblox.Color3,
		UDim = roblox.UDim,
		UDim2 = roblox.UDim2,
		Enum = roblox.Enum,
		ColorSequence = roblox.ColorSequence,
		ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
		NumberSequence = roblox.NumberSequence,
		NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
		NumberRange = roblox.NumberRange,
		Random = RandomMock,
		warn = function(...)
			table.insert(warnings, table.concat({ ... }, " "))
		end,
	}
	local chunk = luau.load(fs.readFile(path), { debugName = path, environment = env })
	local result = chunk()
	moduleCache[path] = result
	return result
end

return {
	loadModule = loadModule,
	warnings = warnings,
	roblox = roblox,
	game = game,
}
