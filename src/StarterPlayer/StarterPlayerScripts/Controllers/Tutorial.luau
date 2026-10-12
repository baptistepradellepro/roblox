--[[
	Tutorial : le tutoriel des nouveaux joueurs, en 3 flèches et presque sans texte.
	  1. "Achète !"  -> flèche sur un fantôme du chemin (fini quand on a acheté)
	  2. "Ta base"   -> flèche sur sa base (fini quand on y est entré)
	  3. "Vole !"    -> flèche sur la base d'un autre joueur (fini quand on vole, ou après 25 s)
	Une ligne jaune relie le joueur à la flèche. À la fin, le serveur note que c'est fait.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local Effects = require(script.Parent.Effects)
local Lang = require(script.Parent.Lang)
local PathView = require(script.Parent.PathView)
local UI = require(script.Parent.UI)

local Tutorial = {}

local player = Players.LocalPlayer

local marker: Part
local arrowGui: BillboardGui
local arrowText: TextLabel
local beam: Beam
local playerAttachment: Attachment?

local function root(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function basesFolder(): Instance?
	local map = workspace:FindFirstChild("Map")
	return map and map:FindFirstChild("Bases")
end

local function myBase(): Model?
	local folder = basesFolder()
	local index = player:GetAttribute("BaseIndex")
	return folder and index and folder:FindFirstChild("Base_" .. index) :: Model?
end

local function insideBase(base: Model, position: Vector3): boolean
	local origin = base:GetAttribute("Origin") :: CFrame
	local localPos = origin:PointToObjectSpace(position)
	return math.abs(localPos.X) < 18 and math.abs(localPos.Z) < 16
end

-- La base d'un autre joueur la plus proche, qui a au moins un fantôme
local function nearestOtherBase(position: Vector3): Model?
	local folder = basesFolder()
	if not folder then
		return nil
	end
	local best, bestDist = nil, math.huge
	for _, base in folder:GetChildren() do
		local owner = base:GetAttribute("OwnerUserId") or 0
		if owner ~= 0 and owner ~= player.UserId then
			local hasGhost = false
			for _, ped in base.Pedestals:GetChildren() do
				if (ped:GetAttribute("GhostId") or "") ~= "" then
					hasGhost = true
					break
				end
			end
			local origin = base:GetAttribute("Origin") :: CFrame
			local dist = (origin.Position - position).Magnitude
			if hasGhost and dist < bestDist then
				best, bestDist = base, dist
			end
		end
	end
	return best
end

local function buildMarker()
	marker = Instance.new("Part")
	marker.Name = "TutorialMarker"
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.Transparency = 1
	marker.Size = Vector3.one
	marker.Parent = workspace

	arrowGui = UI.new("BillboardGui", {
		Size = UDim2.fromOffset(180, 150),
		AlwaysOnTop = true,
		LightInfluence = 0,
		AutoLocalize = Lang.autoLocalize,
		Adornee = marker,
		Parent = marker,
	})
	arrowText = UI.label({
		Size = UDim2.new(1, 0, 0, 50),
		TextColor3 = UI.Colors.Gold,
		MaxTextSize = 40,
		Parent = arrowGui,
	})
	UI.label({
		Size = UDim2.new(1, 0, 0, 100),
		Position = UDim2.fromOffset(0, 50),
		Text = "⬇️",
		MaxTextSize = 90,
		Parent = arrowGui,
	})

	local targetAttachment = Instance.new("Attachment")
	targetAttachment.Parent = marker
	beam = Instance.new("Beam")
	beam.Attachment1 = targetAttachment
	beam.Color = ColorSequence.new(UI.Colors.Gold)
	beam.Width0 = 0.6
	beam.Width1 = 0.6
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.Transparency = NumberSequence.new(0.25)
	beam.Segments = 1
	beam.Parent = marker
end

local function attachBeamToPlayer()
	local r = root()
	if r and (not playerAttachment or playerAttachment.Parent ~= r) then
		local attachment = Instance.new("Attachment")
		attachment.Name = "TutorialAttachment"
		attachment.Parent = r
		playerAttachment = attachment
		beam.Attachment0 = attachment
	end
end

local function cleanup()
	if marker then
		marker:Destroy()
	end
	if playerAttachment then
		playerAttachment:Destroy()
	end
end

function Tutorial.start()
	if player:GetAttribute("TutorialDone") then
		return
	end
	buildMarker()
	local step = 1
	local stepStarted = os.clock()
	local finished = false
	local connection: RBXScriptConnection

	local function nextStep()
		step += 1
		stepStarted = os.clock()
		Effects.sound("Gift")
	end

	local function finish()
		if finished then
			return
		end
		finished = true
		connection:Disconnect()
		cleanup()
		Remotes.get("TutorialDone"):FireServer()
	end

	connection = RunService.RenderStepped:Connect(function()
		local r = root()
		if not r then
			return
		end
		attachBeamToPlayer()
		local t = os.clock()
		local targetPosition: Vector3? = nil

		if step == 1 then
			arrowText.Text = "🛒 " .. Lang.t("Tuto1")
			local ghost = PathView.closest(r.Position)
			if ghost and ghost.PrimaryPart then
				targetPosition = ghost.PrimaryPart.Position + Vector3.new(0, 4, 0)
			end
			if player:GetAttribute("HasBought") then
				nextStep()
			end
		elseif step == 2 then
			arrowText.Text = "🏠 " .. Lang.t("Tuto2")
			local base = myBase()
			if base then
				local mat = base:FindFirstChild("Mat") :: BasePart?
				targetPosition = if mat then mat.Position + Vector3.new(0, 4, 0) else nil
				if insideBase(base, r.Position) or t - stepStarted > 20 then
					nextStep()
				end
			else
				nextStep()
			end
		elseif step == 3 then
			arrowText.Text = "🦹 " .. Lang.t("Tuto3")
			local other = nearestOtherBase(r.Position)
			local mat = other and other:FindFirstChild("Mat") :: BasePart?
			if mat then
				targetPosition = mat.Position + Vector3.new(0, 4, 0)
			end
			if not other or player:GetAttribute("CarryGhost") or t - stepStarted > 25 then
				finish()
				return
			end
		end

		if targetPosition then
			marker.CFrame = CFrame.new(targetPosition + Vector3.new(0, 3 + math.abs(math.sin(t * 4)) * 1.5, 0))
			arrowGui.Enabled = true
			beam.Enabled = true
		else
			arrowGui.Enabled = false
			beam.Enabled = false
		end
	end)

	player:GetAttributeChangedSignal("TutorialDone"):Connect(function()
		if player:GetAttribute("TutorialDone") then
			finish()
		end
	end)
end

return Tutorial
