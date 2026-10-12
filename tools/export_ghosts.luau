-- Exporte la géométrie des 32 fantômes en JSON (pour tools/preview_ghosts.py)
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")

local Loader = require("../tests/loader")
local GhostData = Loader.loadModule("src/ReplicatedStorage/Shared/GhostData.luau")
local GhostFactory = Loader.loadModule("src/ReplicatedStorage/Shared/GhostFactory.luau")

local out = {}
for _, ghost in GhostData.List do
	local model = GhostFactory.build(ghost.Id)
	local parts = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			local shape = if d:IsA("WedgePart") then "Wedge" else d.Shape.Name
			table.insert(parts, {
				shape = shape,
				size = { d.Size.X, d.Size.Y, d.Size.Z },
				cf = { d.CFrame:GetComponents() },
				color = { d.Color.R, d.Color.G, d.Color.B },
				transparency = d.Transparency,
				neon = d.Material.Name == "Neon",
			})
		end
	end
	table.insert(out, { id = ghost.Id, name = ghost.Name.fr, rarity = ghost.Rarity, parts = parts })
end
local path = process.args[1] or "ghosts.json"
fs.writeFile(path, serde.encode("json", out))
print("Exporté : " .. path)
