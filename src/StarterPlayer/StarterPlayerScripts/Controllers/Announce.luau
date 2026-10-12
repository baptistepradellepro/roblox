--[[
	Announce : les grandes annonces visibles par tout le serveur
	("Léo a volé Méga Bouh Cosmique à Inès !", apparition d'un Mythique...).
	Une bannière en haut de l'écran + un message dans le chat Roblox.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rarities = require(Shared:WaitForChild("Rarities"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Effects = require(script.Parent.Effects)
local Lang = require(script.Parent.Lang)
local UI = require(script.Parent.UI)

local Announce = {}

local KIND_COLORS = {
	steal = Color3.fromRGB(255, 90, 90),
	mythic = Rarities.color("Mythic"),
	halloween = Rarities.color("Halloween"),
	legendary = Rarities.color("Legendary"),
	rebirth = Color3.fromRGB(120, 255, 200),
	night = Color3.fromRGB(170, 110, 255),
	info = Color3.fromRGB(120, 190, 255),
}

local KIND_ICONS = {
	steal = "🦹",
	mythic = "🌟",
	halloween = "🎃",
	legendary = "✨",
	rebirth = "♻️",
	night = "🌙",
	info = "📣",
}

local gui: ScreenGui
local queue = {}
local showing = false

local function toHex(color: Color3): string
	return string.format("#%02X%02X%02X", math.floor(color.R * 255), math.floor(color.G * 255), math.floor(color.B * 255))
end

-- Message dans le chat (système de chat standard de Roblox)
local function chatMessage(text: string, color: Color3)
	task.spawn(function()
		local ok = pcall(function()
			local channels = TextChatService:FindFirstChild("TextChannels")
			local general = channels and channels:FindFirstChild("RBXGeneral") :: TextChannel?
			if general then
				general:DisplaySystemMessage(string.format('<font color="%s">%s</font>', toHex(color), text))
			end
		end)
		if not ok then
			-- pas grave : la bannière suffit
			return
		end
	end)
end

local function showNext()
	if showing or #queue == 0 then
		return
	end
	showing = true
	local item = table.remove(queue, 1)
	local color = KIND_COLORS[item.kind] or KIND_COLORS.info

	local banner = UI.new("Frame", {
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.3, 0),
		Size = UDim2.fromOffset(820, 92),
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.05,
		Parent = gui,
	}, { UI.corner(22), UI.stroke(color, 5) })
	UI.label({
		Size = UDim2.new(1, -30, 1, -14),
		Position = UDim2.fromOffset(15, 7),
		Text = (KIND_ICONS[item.kind] or "📣") .. " " .. item.text,
		TextColor3 = color,
		MaxTextSize = 44,
		Parent = banner,
	})
	local scaler = UI.new("UIScale", { Scale = 0.2, Parent = banner })
	TweenService:Create(scaler, TweenInfo.new(0.45, Enum.EasingStyle.Back), { Scale = 1 }):Play()

	task.delay(3.4, function()
		TweenService:Create(scaler, TweenInfo.new(0.25), { Scale = 0 }):Play()
		task.wait(0.3)
		banner:Destroy()
		showing = false
		showNext()
	end)
end

function Announce.show(text: string, kind: string?)
	table.insert(queue, { text = text, kind = kind or "info" })
	-- on ne garde pas une file trop longue
	while #queue > 4 do
		table.remove(queue, 1)
	end
	showNext()
end

function Announce.start()
	gui = UI.screen("SAG_Announce", 5)
	Remotes.get("Announce").OnClientEvent:Connect(function(key: string, params, kind: string)
		local text = Lang.t(key, params)
		Announce.show(text, kind)
		chatMessage(text, KIND_COLORS[kind] or KIND_COLORS.info)
		if kind == "mythic" or kind == "halloween" then
			Effects.sound("Mythic")
		end
	end)
end

return Announce
