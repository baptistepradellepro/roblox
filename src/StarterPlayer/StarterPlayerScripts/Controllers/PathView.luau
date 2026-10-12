--[[
	PathView : affiche les fantômes qui défilent sur le chemin hanté.
	Le serveur dit seulement "tel fantôme est parti à telle heure" : on calcule
	nous-mêmes sa position à chaque image (pas de saccades, pas de lag réseau).
	Le bouton "Acheter" envoie juste une DEMANDE au serveur, qui vérifie tout.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local GhostData = require(Shared:WaitForChild("GhostData"))
local GhostFactory = require(Shared:WaitForChild("GhostFactory"))
local Rarities = require(Shared:WaitForChild("Rarities"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Effects = require(script.Parent.Effects)
local Labels = require(script.Parent.Labels)
local Lang = require(script.Parent.Lang)

local PathView = {}

type Item = { Model: Model, SpawnTime: number, Height: number, Phase: number, Spin: number }

local items: { [Instance]: Item } = {}
local container: Folder

-- Colonne de lumière visible de loin pour les fantômes très rares
local function addBeacon(model: Model, color: Color3)
	local beacon = Instance.new("Part")
	beacon.Name = "Beacon"
	beacon.Anchored = true
	beacon.CanCollide = false
	beacon.CanQuery = false
	beacon.CanTouch = false
	beacon.CastShadow = false
	beacon.Shape = Enum.PartType.Cylinder
	beacon.Size = Vector3.new(80, 3, 3)
	beacon.CFrame = (model.PrimaryPart :: BasePart).CFrame * CFrame.new(0, 40, 0) * CFrame.Angles(0, 0, math.rad(90))
	beacon.Color = color
	beacon.Material = Enum.Material.Neon
	beacon.Transparency = 0.55
	beacon.Parent = model
end

-- Où se trouve ce fantôme à l'instant "now" ?
function PathView.positionOf(spawnTime: number, now: number, height: number): Vector3
	local x = Config.PathStartX + (now - spawnTime) * Config.PathSpeed
	return Vector3.new(x, height, Config.PathZ)
end

-- Renvoie le fantôme du chemin le plus proche d'une position (utilisé par le tutoriel)
function PathView.closest(position: Vector3): Model?
	local best, bestDist = nil, math.huge
	for _, item in items do
		local root = item.Model.PrimaryPart
		if root then
			local dist = (root.Position - position).Magnitude
			if dist < bestDist then
				best, bestDist = item.Model, dist
			end
		end
	end
	return best
end

local function add(holder: Instance)
	local ghostId = holder:GetAttribute("GhostId")
	local spawnTime = holder:GetAttribute("SpawnTime")
	local ghost = GhostData.get(ghostId)
	if not ghost or not spawnTime then
		return
	end
	local model = GhostFactory.build(ghostId)
	local root = model.PrimaryPart :: BasePart
	local height = (model:GetAttribute("Bottom") or 2) + 1.2
	local top = model:GetAttribute("Top") or 2

	model:PivotTo(CFrame.new(PathView.positionOf(spawnTime, workspace:GetServerTimeNow(), height)))
	Labels.ghost(root, ghostId, "path", top)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = Lang.t("Buy") .. "  🪙 " .. Format.short(GhostData.priceOf(ghostId))
	prompt.ObjectText = Lang.ghostName(ghostId)
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Config.BuyRange
	prompt.RequiresLineOfSight = false
	prompt.AutoLocalize = Lang.autoLocalize
	prompt.Parent = root
	prompt.Triggered:Connect(function()
		Effects.sound("Click")
		Remotes.get("BuyGhost"):FireServer(holder.Name)
	end)

	local mutation = GhostData.mutationOf(ghostId)
	if Rarities.rank(ghost.Rarity) >= Rarities.rank("Mythic") then
		addBeacon(model, Rarities.color(ghost.Rarity))
	elseif mutation and mutation.Mult >= 5 then
		addBeacon(model, Color3.fromRGB(mutation.Color[1], mutation.Color[2], mutation.Color[3]))
	end

	model.Parent = container
	items[holder] = {
		Model = model,
		SpawnTime = spawnTime,
		Height = height,
		Phase = math.random() * math.pi * 2,
		Spin = model:GetAttribute("Spin") or 1,
	}
end

local function remove(holder: Instance)
	local item = items[holder]
	if item then
		items[holder] = nil
		local root = item.Model.PrimaryPart
		if root and root.Position.X < Config.PathEndX - 2 then
			Effects.poof(root.Position) -- acheté par quelqu'un : petit nuage
		end
		item.Model:Destroy()
	end
end

function PathView.start()
	container = Instance.new("Folder")
	container.Name = "ClientPathGhosts"
	container.Parent = workspace

	local folder = ReplicatedStorage:WaitForChild("PathGhosts")
	folder.ChildAdded:Connect(function(holder)
		-- on attend que les attributs soient arrivés
		if holder:GetAttribute("SpawnTime") == nil then
			holder:GetAttributeChangedSignal("SpawnTime"):Wait()
		end
		if holder.Parent then
			add(holder)
		end
	end)
	folder.ChildRemoved:Connect(remove)
	for _, holder in folder:GetChildren() do
		add(holder)
	end

	RunService.RenderStepped:Connect(function()
		local now = workspace:GetServerTimeNow()
		local t = os.clock()
		for holder, item in items do
			local pos = PathView.positionOf(item.SpawnTime, now, item.Height)
			if pos.X > Config.PathEndX + 4 then
				items[holder] = nil
				item.Model:Destroy()
			else
				local bob = math.sin(t * 2 + item.Phase) * 0.4
				local angle = t * 0.6 * item.Spin + item.Phase
				item.Model:PivotTo(CFrame.new(pos.X, pos.Y + bob, pos.Z) * CFrame.Angles(0, angle, 0))
			end
		end
	end)
end

return PathView
