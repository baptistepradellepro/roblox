-- Exporte la géométrie d'une base (rez-de-chaussée) en JSON pour tools/preview_base.py
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")

local Loader = require("../tests/loader")
local MapBuilder = Loader.loadModule("src/ServerScriptService/Services/MapBuilder.luau")
local map = MapBuilder.build()
local base = map:FindFirstChild("Bases"):FindFirstChild("Base_3")
local origin = base:GetAttribute("Origin")
local out = {}
for _, d in base:GetDescendants() do
	if d:IsA("BasePart") and d.Transparency < 1 then
		local cf = origin:ToObjectSpace(d.CFrame)
		local shape = if d:IsA("WedgePart") then "Wedge" else d.Shape.Name
		table.insert(out, {
			name = d.Name,
			shape = shape,
			size = { d.Size.X, d.Size.Y, d.Size.Z },
			cf = { cf:GetComponents() },
			color = { d.Color.R, d.Color.G, d.Color.B },
			transparency = d.Transparency,
		})
	end
end
fs.writeFile(process.args[1] or "base.json", serde.encode("json", out))
print("Exporté")
