--[[
	CarryView : affiche les voleurs.
	  - le fantôme volé flotte au-dessus de la tête du voleur
	  - le voleur est surligné en rouge, visible à travers les murs, avec "VOLEUR !"
	  - si c'est MOI qui vole : une ligne verte me guide jusqu'à ma base
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GhostFactory = require(Shared:WaitForChild("GhostFactory"))

local Lang = require(script.Parent.Lang)
local UI = require(script.Parent.UI)

local CarryView = {}

local player = Players.LocalPlayer

type Visual = {
	Player: Player,
	GhostId: string,
	Model: Model,
	Bottom: number,
	Highlight: Highlight?,
	Tag: BillboardGui?,
	Beam: Beam?,
	Attachments: { Attachment },
}

local visuals: { [Player]: Visual } = {}
local container: Folder

local function clear(target: Player)
	local visual = visuals[target]
	if not visual then
		return
	end
	visuals[target] = nil
	visual.Model:Destroy()
	if visual.Highlight then
		visual.Highlight:Destroy()
	end
	if visual.Tag then
		visual.Tag:Destroy()
	end
	if visual.Beam then
		visual.Beam:Destroy()
	end
	for _, attachment in visual.Attachments do
		attachment:Destroy()
	end
end

-- Ligne de guidage du voleur (moi) vers le tapis de ma base
local function addGuide(visual: Visual, character: Model)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local index = player:GetAttribute("BaseIndex")
	local map = workspace:FindFirstChild("Map")
	local basesFolder = map and map:FindFirstChild("Bases")
	local baseModel = basesFolder and index and basesFolder:FindFirstChild("Base_" .. index)
	local mat = baseModel and baseModel:FindFirstChild("Mat") :: BasePart?
	if not root or not mat then
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, 1, 0)
	a1.Parent = mat
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Color = ColorSequence.new(Color3.fromRGB(90, 255, 140))
	beam.Width0 = 1
	beam.Width1 = 2.5
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.Transparency = NumberSequence.new(0.2)
	beam.Segments = 20
	beam.CurveSize0 = 8
	beam.Parent = root
	visual.Beam = beam
	visual.Attachments = { a0, a1 }
end

local function show(target: Player)
	clear(target)
	local ghostId = target:GetAttribute("CarryGhost")
	local character = target.Character
	if not ghostId or not character then
		return
	end
	local model = GhostFactory.build(ghostId)
	model:ScaleTo(0.8)
	model.Parent = container

	local visual: Visual = {
		Player = target,
		GhostId = ghostId,
		Model = model,
		Bottom = (model:GetAttribute("Bottom") or 2) * 0.8,
		Highlight = nil,
		Tag = nil,
		Beam = nil,
		Attachments = {},
	}

	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.fromRGB(255, 50, 60)
	highlight.FillTransparency = 0.55
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Adornee = character
	highlight.Parent = character
	visual.Highlight = highlight

	local head = character:FindFirstChild("Head") :: BasePart?
	if head and target ~= player then
		local tag = UI.new("BillboardGui", {
			Size = UDim2.fromOffset(200, 50),
			StudsOffsetWorldSpace = Vector3.new(0, 3, 0),
			AlwaysOnTop = true,
			LightInfluence = 0,
			MaxDistance = 1000,
			AutoLocalize = Lang.autoLocalize,
			Adornee = head,
			Parent = head,
		})
		UI.label({
			Size = UDim2.fromScale(1, 1),
			Text = "🚨 " .. Lang.t("ThiefLabel") .. " 🚨",
			TextColor3 = UI.Colors.Bad,
			MaxTextSize = 34,
			Parent = tag,
		})
		visual.Tag = tag
	end

	if target == player then
		addGuide(visual, character)
	end
	visuals[target] = visual
end

local function watch(target: Player)
	target:GetAttributeChangedSignal("CarryGhost"):Connect(function()
		show(target)
	end)
	target.CharacterAdded:Connect(function()
		clear(target)
	end)
	if target:GetAttribute("CarryGhost") then
		show(target)
	end
end

function CarryView.start()
	container = Instance.new("Folder")
	container.Name = "ClientCarried"
	container.Parent = workspace

	for _, target in Players:GetPlayers() do
		watch(target)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(clear)

	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for target, visual in visuals do
			local character = target.Character
			local head = character and character:FindFirstChild("Head") :: BasePart?
			if head then
				local wobble = math.sin(t * 6) * 0.15
				local pos = head.Position + Vector3.new(0, 1.2 + visual.Bottom + wobble, 0)
				visual.Model:PivotTo(CFrame.new(pos) * CFrame.Angles(0, t * 1.5, math.sin(t * 4) * 0.15))
			end
		end
	end)
end

return CarryView
