--[[
	WeaponView : les armes côté joueur.
	  - clic (ou toucher l'écran) avec une arme en main : on frappe
	  - un gros bouton rouge apparaît quand un voleur (ou un intrus dans ta base) est
	    à portée : il prend ta meilleure arme et frappe. Touche Q sur ordinateur.
	Le serveur vérifie tout (distance, recharge) et décide de l'effet.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Weapons = require(Shared:WaitForChild("Weapons"))

local AnimView = require(script.Parent.AnimView)
local Effects = require(script.Parent.Effects)
local HUD = require(script.Parent.HUD)
local Lang = require(script.Parent.Lang)
local UI = require(script.Parent.UI)

local WeaponView = {}

local player = Players.LocalPlayer
local readyAt = 0
local hitButton: TextButton
local hitIcon: TextLabel
local hitText: TextLabel
local connected: { [Tool]: boolean } = {}

local function myRoot(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Toutes mes armes (dans le sac ou en main)
local function myTools(): { Tool }
	local list = {}
	for _, container in { player:FindFirstChildOfClass("Backpack"), player.Character } do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and Weapons.get(child:GetAttribute("WeaponId")) then
					table.insert(list, child)
				end
			end
		end
	end
	return list
end

local function equipped(): Tool?
	local character = player.Character
	if not character then
		return nil
	end
	for _, child in character:GetChildren() do
		if child:IsA("Tool") and Weapons.get(child:GetAttribute("WeaponId")) then
			return child
		end
	end
	return nil
end

-- La meilleure arme : celle en main, sinon celle qui porte le plus loin
local function bestTool(): Tool?
	local current = equipped()
	if current then
		return current
	end
	local best, bestRange = nil, -1
	for _, tool in myTools() do
		local weapon = Weapons.get(tool:GetAttribute("WeaponId"))
		if weapon and weapon.Range > bestRange then
			best, bestRange = tool, weapon.Range
		end
	end
	return best
end

local function myBase(): Model?
	local map = workspace:FindFirstChild("Map")
	local folder = map and map:FindFirstChild("Bases")
	local index = player:GetAttribute("BaseIndex")
	return folder and index and folder:FindFirstChild("Base_" .. index) :: Model?
end

local function insideBase(base: Model, position: Vector3): boolean
	local origin = base:GetAttribute("Origin")
	if typeof(origin) ~= "CFrame" then
		return false
	end
	local localPos = origin:PointToObjectSpace(position)
	return math.abs(localPos.X) < 18 and math.abs(localPos.Z) < 20
end

-- Y a-t-il quelqu'un à frapper à portée ? (voleur, ou intrus dans ma base)
local function targetInRange(range: number): boolean
	local root = myRoot()
	if not root then
		return false
	end
	local base = myBase()
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local otherRoot = other.Character and other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if otherRoot and (otherRoot.Position - root.Position).Magnitude <= range + 1 then
				if other:GetAttribute("CarryGhost") or (base and insideBase(base, otherRoot.Position)) then
					return true
				end
			end
		end
	end
	return false
end

function WeaponView.swing(tool: Tool?)
	local chosen = tool or bestTool()
	local weapon = Weapons.get(if chosen then chosen:GetAttribute("WeaponId") else "Batte") or Weapons.ById.Batte
	local t = os.clock()
	if t < readyAt or player:GetAttribute("CarryGhost") then
		return
	end
	readyAt = t + weapon.Cooldown
	if chosen then
		-- on prend l'arme en main si besoin
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and chosen.Parent ~= character then
			humanoid:EquipTool(chosen)
		end
		-- l'animation officielle de Roblox ("Slash" ou "Lunge"), jouée par mon personnage
		-- et montrée par Roblox à tous les autres joueurs
		AnimView.playToolAnim(chosen, weapon.Anim or "Slash")
	end
	-- traînée tout de suite sur mon écran ; le serveur prévient les autres
	AnimView.swing(player.Character, weapon.Id, nil, true, false)
	Effects.sound("Swing")
	Remotes.get("Bonk"):FireServer(weapon.Id)
end

local function hookTool(tool: Instance)
	if not tool:IsA("Tool") or connected[tool] or not Weapons.get(tool:GetAttribute("WeaponId")) then
		return
	end
	connected[tool] = true
	tool.Activated:Connect(function()
		WeaponView.swing(tool)
	end)
	tool.AncestryChanged:Connect(function()
		if not tool.Parent then
			connected[tool] = nil
		end
	end)
end

local function watch(container: Instance?)
	if not container then
		return
	end
	for _, child in container:GetChildren() do
		hookTool(child)
	end
	container.ChildAdded:Connect(hookTool)
end

function WeaponView.start()
	local caption = Lang.t("Bonk") .. (if UI.isMobile() then "" else " (Q)")
	hitButton, hitIcon, hitText = UI.bigButton({
		Name = "Bonk",
		Icon = "🏏",
		Text = caption,
		Color = UI.Colors.Bad,
		Size = 112,
		LayoutOrder = 2,
		Parent = HUD.rightColumn,
	})
	hitButton.Visible = false
	hitButton.Activated:Connect(function()
		WeaponView.swing(nil)
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Q then
			WeaponView.swing(nil)
		end
	end)

	watch(player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 5))
	player.CharacterAdded:Connect(function(character)
		watch(character)
		task.defer(function()
			watch(player:FindFirstChildOfClass("Backpack"))
		end)
	end)
	if player.Character then
		watch(player.Character)
	end

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.1 then
			return
		end
		accumulator = 0
		local tool = bestTool()
		local weapon = Weapons.get(if tool then tool:GetAttribute("WeaponId") else "Batte") or Weapons.ById.Batte
		local inRange = not player:GetAttribute("CarryGhost") and targetInRange(weapon.Range)
		local wasVisible = hitButton.Visible
		hitButton.Visible = inRange
		if inRange and not wasVisible then
			UI.pop(hitButton)
		end
		hitIcon.Text = weapon.Icon
		local cooldown = readyAt - os.clock()
		if cooldown > 0 then
			hitButton.BackgroundColor3 = UI.Colors.Gray
			hitText.Text = string.format("%.1f", cooldown)
		else
			hitButton.BackgroundColor3 = UI.Colors.Bad
			hitText.Text = caption
		end
	end)
end

return WeaponView
