--[[
	MonsterView : les monstres côté joueur (Gloutrouille la nuit, et ceux lâchés avec
	des Robux). Le serveur publie leur position sur une pièce invisible "<Id>Anchor" ;
	ici on dessine le vrai monstre, on le fait glisser en douceur et on l'anime.
	Quand un monstre te poursuit : bords de l'écran rouges + battements de cœur.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Monsters = require(Shared:WaitForChild("Monsters"))

local Effects = require(script.Parent.Effects)
local Lang = require(script.Parent.Lang)
local UI = require(script.Parent.UI)

local MonsterView = {}

local player = Players.LocalPlayer

type Shown = { Anchor: BasePart, Model: Model, Def: any, Wings: { BasePart }, Base: { [BasePart]: CFrame } }
local shown: { [BasePart]: Shown } = {}
local vignette: Frame

local function colorOf(def): Color3
	return Color3.fromRGB(def.Color[1], def.Color[2], def.Color[3])
end

local function addLabel(model: Model, anchor: BasePart, def)
	local root = model.PrimaryPart :: BasePart
	local summoner = anchor:GetAttribute("SummonerName") or ""
	local text = def.Icon .. " " .. string.upper(Lang.pick(def.Name))
	if summoner ~= "" then
		text ..= "\n" .. Lang.t("MonsterBy", { player = summoner })
	end
	local tag = UI.new("BillboardGui", {
		Name = "MonsterTag",
		Size = UDim2.fromOffset(260, if summoner ~= "" then 70 else 46),
		StudsOffsetWorldSpace = Vector3.new(0, 8, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = 400,
		AutoLocalize = false,
		Adornee = root,
		Parent = root,
	})
	UI.label({
		Size = UDim2.fromScale(1, 1),
		Text = text,
		TextColor3 = colorOf(def),
		MaxTextSize = 32,
		Parent = tag,
	})
end

local function onAnchorAdded(anchor: Instance)
	if not anchor:IsA("BasePart") then
		return
	end
	local kind = anchor:GetAttribute("MonsterKind")
	local def = Monsters.get(kind)
	if not def or shown[anchor] then
		return
	end
	local model = Monsters.build(def.Id)
	local scale = anchor:GetAttribute("Scale") or 1
	if scale ~= 1 then
		model:ScaleTo(scale) -- Super Nuit : Gloutrouille géant
	end
	addLabel(model, anchor, def)
	-- les parties qui bougent (ailes, pattes, bras), avec leur position de départ
	local moving, base = {}, {}
	local root = model.PrimaryPart :: BasePart
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and (d.Name == "Wing" or d.Name == "Leg" or d.Name == "Arm") then
			table.insert(moving, d)
			base[d] = root.CFrame:ToObjectSpace(d.CFrame)
		end
	end
	model:PivotTo(anchor.CFrame)
	model.Parent = workspace
	shown[anchor] = { Anchor = anchor, Model = model, Def = def, Wings = moving, Base = base }
	Effects.poof(anchor.Position, colorOf(def))
end

local function onAnchorRemoved(anchor: Instance)
	local entry = shown[anchor :: BasePart]
	if entry then
		Effects.poof(entry.Model:GetPivot().Position, Color3.fromRGB(170, 80, 255))
		entry.Model:Destroy()
		shown[anchor :: BasePart] = nil
	end
end

function MonsterView.start()
	-- Bords rouges quand un monstre te poursuit
	local vignetteGui = UI.new("ScreenGui", {
		Name = "SAG_Vignette",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = -1,
		Parent = player:WaitForChild("PlayerGui"),
	})
	vignette = UI.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(255, 0, 40),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = vignetteGui,
	}, {
		UI.new("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.2, 0.9),
				NumberSequenceKeypoint.new(0.8, 0.9),
				NumberSequenceKeypoint.new(1, 0),
			}),
		}),
	})

	workspace.ChildAdded:Connect(onAnchorAdded)
	workspace.ChildRemoved:Connect(onAnchorRemoved)
	for _, child in workspace:GetChildren() do
		onAnchorAdded(child)
	end

	local nextHeartbeat = 0
	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		local chased = false
		local character = player.Character
		local myRoot = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		for anchor, entry in shown do
			if not anchor.Parent then
				onAnchorRemoved(anchor)
				continue
			end
			-- il glisse vers la position du serveur et rebondit
			local alpha = 1 - math.exp(-dt * 10)
			local goal = anchor.CFrame * CFrame.new(0, math.abs(math.sin(t * 5)) * 1.2, 0)
			entry.Model:PivotTo(entry.Model:GetPivot():Lerp(goal, alpha))
			-- ailes qui battent, pattes et bras qui s'agitent
			local root = entry.Model.PrimaryPart :: BasePart
			for _, moving in entry.Wings do
				local side = moving:GetAttribute("Side") or (if root.CFrame:PointToObjectSpace(moving.Position).X > 0 then 1 else -1)
				local speed = if moving.Name == "Wing" then 18 else 9
				local angle = math.sin(t * speed + side) * (if moving.Name == "Wing" then 0.5 else 0.2)
				moving.CFrame = root.CFrame * CFrame.Angles(0, 0, angle * side) * entry.Base[moving]
			end
			if myRoot and anchor:GetAttribute("TargetUserId") == player.UserId then
				chased = chased or (myRoot.Position - anchor.Position).Magnitude < 50
			end
		end
		if chased then
			vignette.BackgroundTransparency = 0.35 + math.abs(math.sin(t * 4)) * 0.4
			if t >= nextHeartbeat then
				nextHeartbeat = t + 0.6
				Effects.sound("Heartbeat")
			end
		else
			vignette.BackgroundTransparency = 1
		end
	end)
end

return MonsterView
