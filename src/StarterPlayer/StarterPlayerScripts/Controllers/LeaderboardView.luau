--[[
	LeaderboardView : affiche le top 10 des voleurs de la semaine sur le grand écran
	au-dessus du chemin (des deux côtés). Les données viennent du serveur.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lang = require(script.Parent.Lang)
local UI = require(script.Parent.UI)

local LeaderboardView = {}

local player = Players.LocalPlayer

local MEDALS = { "🥇", "🥈", "🥉" }

local function buildFace(board: BasePart, face: Enum.NormalId)
	local surface = UI.new("SurfaceGui", {
		Name = "Leaderboard_" .. face.Name,
		Face = face,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 40,
		LightInfluence = 0,
		AutoLocalize = Lang.autoLocalize,
		Adornee = board,
		Parent = board,
	})
	UI.label({
		Name = "Title",
		Size = UDim2.new(1, -40, 0, 70),
		Position = UDim2.fromOffset(20, 10),
		Text = "🏆 " .. Lang.t("LeaderTitle") .. " 🏆",
		TextColor3 = UI.Colors.Gold,
		MaxTextSize = 60,
		Parent = surface,
	})
	local rows = {}
	for rank = 1, 10 do
		local row = UI.label({
			Name = "Row" .. rank,
			Size = UDim2.new(1, -80, 0, 42),
			Position = UDim2.fromOffset(40, 84 + (rank - 1) * 44),
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 38,
			Parent = surface,
		})
		rows[rank] = row
	end
	local footer = UI.label({
		Name = "Footer",
		Size = UDim2.new(1, -40, 0, 40),
		Position = UDim2.new(0, 20, 1, -50),
		TextColor3 = UI.Colors.Info,
		MaxTextSize = 30,
		Parent = surface,
	})
	return rows, footer
end

function LeaderboardView.start()
	local map = workspace:WaitForChild("Map")
	local board = map:WaitForChild("Leaderboard", 30) :: BasePart?
	if not board then
		return
	end
	local faces = {}
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local rows, footer = buildFace(board, face)
		table.insert(faces, { Rows = rows, Footer = footer })
	end

	local function refresh()
		local raw = ReplicatedStorage:GetAttribute("LeaderboardData")
		local ok, list = pcall(function()
			return HttpService:JSONDecode(raw or "[]")
		end)
		if not ok or type(list) ~= "table" then
			list = {}
		end
		local resetAt = ReplicatedStorage:GetAttribute("LeaderboardResetAt") or 0
		local remaining = math.max(0, resetAt - workspace:GetServerTimeNow())
		local footerText = Lang.t("LeaderReset", { days = math.floor(remaining / 86400), hours = math.floor((remaining % 86400) / 3600) })
		for _, face in faces do
			for rank, row in face.Rows do
				local entry = list[rank]
				if entry then
					local medal = MEDALS[rank] or (tostring(rank) .. ".")
					row.Text = medal .. "  " .. tostring(entry.Name) .. "  :  " .. Lang.t("LeaderSteals", { count = entry.Value })
					row.TextColor3 = if entry.UserId == player.UserId then UI.Colors.Gold else UI.Colors.Text
				elseif rank == 1 then
					row.Text = Lang.t("LeaderEmpty")
					row.TextColor3 = UI.Colors.Gray
				else
					row.Text = ""
				end
			end
			face.Footer.Text = footerText
		end
	end

	ReplicatedStorage:GetAttributeChangedSignal("LeaderboardData"):Connect(refresh)
	refresh()
	-- le compte à rebours avance même sans nouveau vol
	task.spawn(function()
		while true do
			task.wait(60)
			refresh()
		end
	end)
end

return LeaderboardView
