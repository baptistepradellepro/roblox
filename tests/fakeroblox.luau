--[[
	FakeRoblox : un mini "Roblox" en Lune pour exécuter le VRAI code serveur du jeu
	hors de Studio, avec un temps virtuel (on peut avancer de 10 minutes en un instant).

	Ce n'est pas un vrai moteur : pas de physique, pas de rendu. Juste assez d'objets
	(instances, attributs, signaux, joueurs, DataStore en mémoire, RemoteEvents) pour
	vérifier la logique : argent, achats, vols, sauvegarde, nuit, rebirth...
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local Fake = {}

local EPOCH = 1790900000 -- un jour d'octobre 2026 (pendant l'événement Halloween)

---------------------------------------------------------------- Planificateur (temps virtuel)
local Sched = { now = 0, queue = {}, errors = {}, seq = 0 }
Fake.Sched = Sched

local function resume(co: thread, ...)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		local message = tostring(err) .. "\n" .. debug.traceback(co)
		table.insert(Sched.errors, message)
		print("ERREUR (coroutine) : " .. message)
	end
end

local function schedule(at: number, co: thread, ...)
	Sched.seq += 1
	table.insert(Sched.queue, { time = at, seq = Sched.seq, co = co, args = table.pack(...) })
end

function Sched.spawn(f, ...)
	local co = if type(f) == "thread" then f else coroutine.create(f)
	resume(co, ...)
	return co
end

function Sched.advance(seconds: number)
	local target = Sched.now + seconds
	while true do
		local bestIndex, best = nil, nil
		for i, item in Sched.queue do
			if item.time <= target and (best == nil or item.time < best.time or (item.time == best.time and item.seq < best.seq)) then
				bestIndex, best = i, item
			end
		end
		if not best then
			break
		end
		table.remove(Sched.queue, bestIndex)
		Sched.now = math.max(Sched.now, best.time)
		if coroutine.status(best.co) == "suspended" then
			resume(best.co, table.unpack(best.args, 1, best.args.n))
		end
	end
	Sched.now = target
end

Fake.task = {
	wait = function(t: number?)
		local start = Sched.now
		schedule(Sched.now + math.max(t or 0, 1 / 60), coroutine.running())
		coroutine.yield()
		return Sched.now - start
	end,
	spawn = function(f, ...)
		return Sched.spawn(f, ...)
	end,
	defer = function(f, ...)
		local co = if type(f) == "thread" then f else coroutine.create(f)
		schedule(Sched.now, co, ...)
		return co
	end,
	delay = function(t: number, f, ...)
		local co = coroutine.create(f)
		schedule(Sched.now + (t or 0), co, ...)
		return co
	end,
	cancel = function() end,
}

Fake.os = setmetatable({
	clock = function()
		return Sched.now
	end,
	time = function(t)
		if t then
			return os.time(t)
		end
		return EPOCH + math.floor(Sched.now)
	end,
}, { __index = os })

---------------------------------------------------------------- Signaux
local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ conns = {}, waiting = {} }, Signal)
end

function Signal:Connect(f)
	local conn = { Connected = true, f = f }
	function conn.Disconnect()
		conn.Connected = false
	end
	table.insert(self.conns, conn)
	-- comme Roblox : les messages reçus avant la première connexion sont livrés maintenant
	if self.pending then
		local pending = self.pending
		self.pending = nil
		for _, args in pending do
			Sched.spawn(f, table.unpack(args, 1, args.n))
		end
	end
	return conn
end

-- Fire, ou mise en attente s'il n'y a encore personne à l'écoute (RemoteEvents côté client)
function Signal:FireOrQueue(...)
	if #self.conns == 0 then
		self.pending = self.pending or {}
		table.insert(self.pending, table.pack(...))
	else
		self:Fire(...)
	end
end

function Signal:Once(f)
	local conn
	conn = self:Connect(function(...)
		conn.Disconnect()
		f(...)
	end)
	return conn
end

function Signal:Fire(...)
	for _, conn in table.clone(self.conns) do
		if conn.Connected then
			Sched.spawn(conn.f, ...)
		end
	end
	local waiting = self.waiting
	self.waiting = {}
	for _, co in waiting do
		resume(co, ...)
	end
end

function Signal:Wait()
	table.insert(self.waiting, coroutine.running())
	return coroutine.yield()
end

Fake.Signal = Signal

---------------------------------------------------------------- Instances
local CLASS_PARENTS = {
	Part = "BasePart",
	WedgePart = "BasePart",
	SpawnLocation = "Part",
	BasePart = "PVInstance",
	Model = "PVInstance",
	Workspace = "Model",
	Script = "LuaSourceContainer",
	LocalScript = "Script",
	ModuleScript = "LuaSourceContainer",
	StringValue = "ValueBase",
	IntValue = "ValueBase",
	NumberValue = "ValueBase",
}

local function isA(className: string, target: string): boolean
	local current: string? = className
	while current do
		if current == target then
			return true
		end
		current = CLASS_PARENTS[current]
	end
	return target == "Instance"
end

local SIGNALS = {
	ChildAdded = true,
	ChildRemoved = true,
	DescendantAdded = true,
	OnServerEvent = true,
	OnClientEvent = true,
	Died = true,
	CharacterAdded = true,
	CharacterRemoving = true,
	PlayerAdded = true,
	PlayerRemoving = true,
	Heartbeat = true,
	RenderStepped = true,
	Stepped = true,
	Triggered = true,
	PromptGamePassPurchaseFinished = true,
	Changed = true,
	PromptButtonHoldBegan = true,
	PromptButtonHoldEnded = true,
	Activated = true,
	MouseButton1Down = true,
	MouseButton1Up = true,
	MouseLeave = true,
	InputBegan = true,
	Completed = true,
	Touched = true,
}

local Methods = {}
local ClassMethods = {}
local InstanceMT = {}

local function newInstance(className: string, extra: { [string]: any }?)
	local inst = setmetatable({
		__fake = true,
		__props = { ClassName = className, Name = className },
		__children = {},
		__attrs = {},
		__attrSignals = {},
		__propSignals = {},
		__signals = {},
		__destroyed = false,
	}, InstanceMT)
	if extra then
		for key, value in extra do
			inst.__props[key] = value
		end
	end
	return inst
end
Fake.newInstance = newInstance

local function setParent(inst, parent)
	local old = inst.__props.Parent
	if old == parent then
		return
	end
	if old then
		local list = old.__children
		local index = table.find(list, inst)
		if index then
			table.remove(list, index)
		end
		old.ChildRemoved:Fire(inst)
	end
	inst.__props.Parent = parent
	if parent then
		table.insert(parent.__children, inst)
		parent.ChildAdded:Fire(inst)
		-- DescendantAdded sur chaque ancêtre qui l'écoute, pour l'objet et ses descendants
		local ancestor = parent
		while ancestor do
			local sig = ancestor.__signals.DescendantAdded
			if sig then
				sig:Fire(inst)
				for _, d in inst:GetDescendants() do
					sig:Fire(d)
				end
			end
			ancestor = ancestor.__props.Parent
		end
	end
	local sig = inst.__propSignals.Parent
	if sig then
		sig:Fire()
	end
end

-- Vérification des propriétés : chaque écriture est rejouée sur une vraie instance
-- Lune (base de données officielle des classes Roblox) pour détecter les fautes.
Fake.propertyErrors = {}
local probes = {}
local pristine = {} -- jamais modifiées : elles gardent les vraies valeurs par défaut
local INTERNAL = { SourcePath = true, Source = true, Kicked = true, ProcessReceipt = true } -- ProcessReceipt est un "callback", pas une propriété
local function probeFor(className: string)
	if probes[className] == nil then
		local ok, real = pcall(roblox.Instance.new, className)
		probes[className] = if ok then real else false
		local okDefault, clean = pcall(roblox.Instance.new, className)
		pristine[className] = if okDefault then clean else false
	end
	return probes[className]
end

local function defaultsFor(className: string)
	probeFor(className)
	return pristine[className]
end

InstanceMT.__index = function(self, key)
	local classMethods = ClassMethods[self.__props.ClassName]
	if classMethods and classMethods[key] then
		return classMethods[key]
	end
	if Methods[key] then
		return Methods[key]
	end
	local props = self.__props
	local value = props[key]
	if value ~= nil then
		return value
	end
	if key == "Position" and props.CFrame and props.ClassName ~= "Attachment" then
		return props.CFrame.Position
	end
	if SIGNALS[key] then
		local sig = self.__signals[key]
		if not sig then
			sig = Signal.new()
			self.__signals[key] = sig
		end
		return sig
	end
	for _, child in self.__children do
		if child.__props.Name == key then
			return child
		end
	end
	-- valeur par défaut réelle de Roblox (ex. Transparency = 0)
	local probe = defaultsFor(props.ClassName)
	if probe then
		local ok, default = pcall(function()
			return probe[key]
		end)
		if ok and typeof(default) ~= "Instance" then
			return default
		end
	end
	return nil
end

InstanceMT.__newindex = function(self, key, value)
	if key == "Parent" then
		setParent(self, value)
		return
	end
	if not INTERNAL[key] and type(value) ~= "table" then
		local className = self.__props.ClassName
		local probe = probeFor(className)
		if probe then
			local ok, err = pcall(function()
				probe[key] = value
			end)
			if not ok then
				local message = className .. "." .. key .. " : " .. tostring(err)
				if not table.find(Fake.propertyErrors, message) then
					table.insert(Fake.propertyErrors, message)
				end
			end
		end
	end
	if key == "Position" and typeof(value) == "Vector3" then
		local cf = self.__props.CFrame or roblox.CFrame.identity
		value = roblox.CFrame.new(value) * (cf - cf.Position)
		key = "CFrame"
	end
	self.__props[key] = value
	local sig = self.__propSignals[key]
	if sig then
		sig:Fire()
	end
end

InstanceMT.__tostring = function(self)
	return self.__props.Name
end

function Methods:IsA(className)
	return isA(self.__props.ClassName, className)
end
function Methods:FindFirstChild(name, recursive)
	for _, child in self.__children do
		if child.__props.Name == name then
			return child
		end
	end
	if recursive then
		for _, child in self.__children do
			local found = child:FindFirstChild(name, true)
			if found then
				return found
			end
		end
	end
	return nil
end
function Methods:WaitForChild(name, timeout)
	local found = self:FindFirstChild(name)
	local started = Sched.now
	while not found do
		if timeout and Sched.now - started >= timeout then
			return nil
		end
		Fake.task.wait(0.1)
		found = self:FindFirstChild(name)
	end
	return found
end
function Methods:FindFirstChildOfClass(className)
	for _, child in self.__children do
		if child.__props.ClassName == className then
			return child
		end
	end
	return nil
end
function Methods:FindFirstChildWhichIsA(className)
	for _, child in self.__children do
		if child:IsA(className) then
			return child
		end
	end
	return nil
end
function Methods:GetChildren()
	return table.clone(self.__children)
end
function Methods:GetDescendants()
	local out = {}
	local function walk(inst)
		for _, child in inst.__children do
			table.insert(out, child)
			walk(child)
		end
	end
	walk(self)
	return out
end
function Methods:IsDescendantOf(ancestor)
	local current = self.__props.Parent
	while current do
		if current == ancestor then
			return true
		end
		current = current.__props.Parent
	end
	return false
end
function Methods:SetAttribute(name, value)
	self.__attrs[name] = value
	local sig = self.__attrSignals[name]
	if sig then
		sig:Fire()
	end
end
function Methods:GetAttribute(name)
	return self.__attrs[name]
end
function Methods:GetAttributeChangedSignal(name)
	local sig = self.__attrSignals[name]
	if not sig then
		sig = Signal.new()
		self.__attrSignals[name] = sig
	end
	return sig
end
function Methods:GetPropertyChangedSignal(name)
	local sig = self.__propSignals[name]
	if not sig then
		sig = Signal.new()
		self.__propSignals[name] = sig
	end
	return sig
end
function Methods:Destroy()
	self.__destroyed = true
	for _, child in table.clone(self.__children) do
		child:Destroy()
	end
	setParent(self, nil)
end
function Methods:ClearAllChildren()
	for _, child in table.clone(self.__children) do
		child:Destroy()
	end
end
function Methods:GetPivot()
	local primary = self.__props.PrimaryPart
	if primary then
		return primary.CFrame
	end
	return self.__props.CFrame or roblox.CFrame.identity
end
function Methods:PivotTo(cf)
	local primary = self.__props.PrimaryPart
	if primary then
		local delta = cf * primary.CFrame:Inverse()
		for _, d in self:GetDescendants() do
			if d.__props.CFrame then
				d.__props.CFrame = delta * d.__props.CFrame
			end
		end
	elseif self.__props.CFrame then
		self.__props.CFrame = cf
	end
end
function Methods:GetBoundingBox()
	local minV, maxV = nil, nil
	for _, d in self:GetDescendants() do
		local cf, size = d.__props.CFrame, d.__props.Size
		if cf and size then
			local lo, hi = cf.Position - size / 2, cf.Position + size / 2
			minV = if minV then minV:Min(lo) else lo
			maxV = if maxV then maxV:Max(hi) else hi
		end
	end
	if not minV then
		return roblox.CFrame.identity, roblox.Vector3.one
	end
	return roblox.CFrame.new((minV + maxV) / 2), maxV - minV
end
function Methods:Emit() end
function Methods:Play() end
function Methods:ScaleTo() end

-- RemoteEvent : on enregistre tout ce que le serveur envoie
Fake.sentToClients = {}
ClassMethods.RemoteEvent = {
	FireClient = function(self, player, ...)
		table.insert(Fake.sentToClients, { remote = self.__props.Name, to = player, args = table.pack(...) })
		if Fake.clientPlayer and player == Fake.clientPlayer then
			self.OnClientEvent:FireOrQueue(...)
		elseif not Fake.clientPlayer then
			-- personne n'écoute encore : Roblox garde le message pour ce joueur
			Fake.earlyMessages[player] = Fake.earlyMessages[player] or {}
			table.insert(Fake.earlyMessages[player], { remote = self, args = table.pack(...) })
		end
	end,
	FireAllClients = function(self, ...)
		table.insert(Fake.sentToClients, { remote = self.__props.Name, to = "all", args = table.pack(...) })
		if Fake.clientPlayer then
			self.OnClientEvent:FireOrQueue(...)
		end
	end,
	FireServer = function(self, ...)
		table.insert(Fake.sentToServer, { remote = self.__props.Name, args = table.pack(...) })
		self.OnServerEvent:Fire(Fake.clientPlayer, ...)
	end,
}
Fake.sentToServer = {}
Fake.earlyMessages = {}

Fake.Instance = {
	new = function(className: string, parent)
		local inst = newInstance(className)
		if parent then
			inst.Parent = parent
		end
		return inst
	end,
}

---------------------------------------------------------------- Services
local game = newInstance("DataModel", { Name = "Game", JobId = "sim-job-1" })
Fake.game = game
local services = {}

local function service(name: string)
	if not services[name] then
		local s = newInstance(name, { Name = name })
		s.Parent = game
		services[name] = s
	end
	return services[name]
end

ClassMethods.DataModel = {
	GetService = function(_, name)
		return service(name)
	end,
	BindToClose = function(_, f)
		Fake.closeCallbacks = Fake.closeCallbacks or {}
		table.insert(Fake.closeCallbacks, f)
	end,
}

local workspace = service("Workspace")
Fake.workspace = workspace
ClassMethods.Workspace = {
	GetServerTimeNow = function()
		return EPOCH + Sched.now
	end,
}

ClassMethods.RunService = {
	IsStudio = function()
		return Fake.isStudio == true
	end,
	IsServer = function()
		return true
	end,
	IsClient = function()
		return false
	end,
}

-- DataStore en mémoire, avec passage par JSON comme le vrai (détecte les données non sauvegardables)
Fake.dataStores = {}
Fake.dataStoreFailures = 0
ClassMethods.DataStoreService = {
	GetOrderedDataStore = function(_, name)
		if Fake.orderedStoreBroken then
			error("Studio : accès aux API désactivé (simulé)")
		end
		local values = Fake.orderedStores[name] or {}
		Fake.orderedStores[name] = values
		return {
			IncrementAsync = function(_, key, delta)
				values[key] = (values[key] or 0) + delta
				return values[key]
			end,
			GetSortedAsync = function(_, ascending, pageSize)
				local list = {}
				for key, value in values do
					table.insert(list, { key = key, value = value })
				end
				table.sort(list, function(a, b)
					return if ascending then a.value < b.value else a.value > b.value
				end)
				while #list > pageSize do
					table.remove(list)
				end
				return {
					GetCurrentPage = function()
						return list
					end,
				}
			end,
		}
	end,
	GetDataStore = function(_, name)
		local raw = Fake.dataStores[name] or {}
		Fake.dataStores[name] = raw
		return {
			UpdateAsync = function(_, key, transform)
				if Fake.dataStoreFailures > 0 then
					Fake.dataStoreFailures -= 1
					error("502: API Services rejected request (simulé)")
				end
				local old = if raw[key] then serde.decode("json", raw[key]) else nil
				local new = transform(old)
				if new ~= nil then
					raw[key] = serde.encode("json", new)
				end
				return new
			end,
		}
	end,
}

Fake.purchasePrompts = {}
Fake.orderedStores = {}
ClassMethods.HttpService = {
	JSONEncode = function(_, value)
		return serde.encode("json", value)
	end,
	JSONDecode = function(_, text)
		return serde.decode("json", text)
	end,
}

ClassMethods.MarketplaceService = {
	UserOwnsGamePassAsync = function(_, userId, passId)
		return Fake.ownedPasses and Fake.ownedPasses[userId .. ":" .. passId] == true
	end,
	GetProductInfo = function(_, id)
		return { PriceInRobux = 99, ProductId = id }
	end,
	PromptGamePassPurchase = function(_, player, id)
		table.insert(Fake.purchasePrompts, { kind = "pass", player = player, id = id })
	end,
	PromptProductPurchase = function(_, player, id)
		table.insert(Fake.purchasePrompts, { kind = "product", player = player, id = id })
	end,
}

-- Groupes de collision (Roblox en accepte 32 au maximum, "Default" compris)
Fake.collisionGroups = { Default = true }
Fake.collisionGroupCount = 1
Fake.nonCollidable = {}
local function groupPair(a: string, b: string): string
	return if a < b then a .. "|" .. b else b .. "|" .. a
end
ClassMethods.PhysicsService = {
	RegisterCollisionGroup = function(_, name)
		assert(type(name) == "string" and #name > 0, "nom de groupe invalide")
		if not Fake.collisionGroups[name] then
			assert(Fake.collisionGroupCount < 32, "trop de groupes de collision (32 maximum)")
			Fake.collisionGroups[name] = true
			Fake.collisionGroupCount += 1
		end
	end,
	IsCollisionGroupRegistered = function(_, name)
		return Fake.collisionGroups[name] == true
	end,
	CollisionGroupSetCollidable = function(_, a, b, collidable)
		assert(Fake.collisionGroups[a] and Fake.collisionGroups[b], "groupe de collision inconnu : " .. tostring(a) .. "/" .. tostring(b))
		Fake.nonCollidable[groupPair(a, b)] = if collidable then nil else true
	end,
	CollisionGroupsAreCollidable = function(_, a, b)
		return not Fake.nonCollidable[groupPair(a, b)]
	end,
}

ClassMethods.TweenService = {
	Create = function(_, instance, _info, goals)
		local tween = { Completed = Signal.new() }
		function tween.Play()
			for key, value in goals do
				instance[key] = value
			end
			tween.Completed:Fire(Fake.Enum.PlaybackState.Completed)
		end
		function tween.Cancel() end
		return tween
	end,
}

ClassMethods.Debris = {
	AddItem = function(_, instance, lifetime)
		Fake.task.delay(lifetime or 10, function()
			instance:Destroy()
		end)
	end,
}

Fake.TweenInfo = {
	new = function(...)
		return { args = table.pack(...) }
	end,
}

---------------------------------------------------------------- Joueurs
local Players = service("Players")
Fake.Players = Players
ClassMethods.Players = {
	GetPlayers = function(self)
		local out = {}
		for _, child in self.__children do
			if child.__props.ClassName == "Player" then
				table.insert(out, child)
			end
		end
		return out
	end,
	GetNameFromUserIdAsync = function(_, userId)
		return "Joueur" .. tostring(userId)
	end,
	GetPlayerFromCharacter = function(self, character)
		for _, p in self:GetPlayers() do
			if p.Character == character then
				return p
			end
		end
		return nil
	end,
	GetPlayerByUserId = function(self, userId)
		for _, p in self:GetPlayers() do
			if p.UserId == userId then
				return p
			end
		end
		return nil
	end,
}

ClassMethods.Player = {
	Kick = function(self, message)
		self.__props.Kicked = message
		Fake.removePlayer(self)
	end,
	IsFriendsWith = function(self, userId)
		return Fake.friends and Fake.friends[self.UserId .. ":" .. userId] == true
	end,
	LoadCharacter = function(self)
		local old = self.__props.Character
		if old then
			old:Destroy()
		end
		local character = newInstance("Model", { Name = self.Name })
		local humanoid = newInstance("Humanoid", { Name = "Humanoid", Health = 100, WalkSpeed = 16 })
		humanoid.Parent = character
		local spawnCf = if self.RespawnLocation then self.RespawnLocation.CFrame * roblox.CFrame.new(0, 3, 0) else roblox.CFrame.new(0, 3, 0)
		local root = newInstance("Part", { Name = "HumanoidRootPart", CFrame = spawnCf, Size = roblox.Vector3.new(2, 2, 1) })
		root.Parent = character
		local head = newInstance("Part", { Name = "Head", CFrame = spawnCf * roblox.CFrame.new(0, 1.5, 0) })
		head.Parent = character
		character.PrimaryPart = root
		character.Parent = workspace
		self.Character = character
		self.CharacterAdded:Fire(character)
	end,
}

local nextUserId = 1
function Fake.addPlayer(name: string, userId: number?)
	local id = userId or nextUserId
	nextUserId = math.max(nextUserId, id) + 1
	local player = newInstance("Player", { Name = name, DisplayName = name, UserId = id, LocaleId = "fr-fr" })
	player.Parent = Players
	Players.PlayerAdded:Fire(player)
	return player
end

function Fake.removePlayer(player)
	if player.__props.Parent ~= Players then
		return
	end
	Players.PlayerRemoving:Fire(player)
	player.Parent = nil
	if player.Character then
		player.Character:Destroy()
	end
end

-- Déplace le personnage d'un joueur (pas de physique : téléportation)
function Fake.moveTo(player, position: Vector3)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	assert(root, "pas de personnage pour " .. player.Name)
	root.CFrame = roblox.CFrame.new(position)
end

function Fake.position(player): Vector3
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return root and root.Position
end

-- Marche en ligne droite à une vitesse donnée (pas de 0,1 s)
function Fake.walk(player, target: Vector3, speed: number)
	while true do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		local pos = root.Position
		local offset = target - pos
		local flat = roblox.Vector3.new(offset.X, 0, offset.Z)
		if flat.Magnitude < 0.5 then
			return
		end
		local step = math.min(flat.Magnitude, speed * 0.1)
		root.CFrame = roblox.CFrame.new(pos + flat.Unit * step)
		Sched.advance(0.1)
	end
end

-- Simule un message envoyé par le client d'un joueur
function Fake.fire(player, remoteName: string, ...)
	local remotes = service("ReplicatedStorage"):FindFirstChild("Remotes")
	local remote = remotes and remotes:FindFirstChild(remoteName)
	assert(remote, "RemoteEvent introuvable : " .. remoteName)
	remote.OnServerEvent:Fire(player, ...)
end

---------------------------------------------------------------- Chargement du code du jeu
local moduleCache = {}
Fake.warnings = {}

local RandomMock = {}
RandomMock.__index = RandomMock
function RandomMock.new(seed: number?)
	return setmetatable({ state = seed or 4242 }, RandomMock)
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

local loadScript
local caches = { server = moduleCache, client = {} }

local function makeRequire(side: string)
	return function(target)
		if type(target) == "table" and target.__fake and target.__props.SourcePath then
			local path = target.__props.SourcePath
			local cache = caches[side]
			if cache[path] == nil then
				cache[path] = loadScript(target, side)
			end
			return cache[path]
		end
		error("require inattendu : " .. tostring(target))
	end
end
local customRequire = makeRequire("server")

function loadScript(scriptInstance, side: string?)
	local path = scriptInstance.__props.SourcePath
	local env = {
		script = scriptInstance,
		require = makeRequire(side or "server"),
		TweenInfo = Fake.TweenInfo,
		game = game,
		workspace = workspace,
		Instance = Fake.Instance,
		task = Fake.task,
		os = Fake.os,
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
		typeof = function(value)
			if type(value) == "table" and value.__fake then
				return "Instance"
			end
			return typeof(value)
		end,
		warn = function(...)
			local message = table.concat(table.pack(...) :: any, " ")
			table.insert(Fake.warnings, message)
		end,
	}
	local chunk = luau.load(scriptInstance.__props.Source, { debugName = path, environment = env })
	return chunk()
end

-- Construit l'arbre du jeu comme le ferait Rojo (default.project.json)
local function mount(dir: string, parent)
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			local folder = newInstance("Folder", { Name = name })
			folder.Parent = parent
			mount(path, folder)
		elseif string.sub(name, -12) == ".server.luau" then
			local s = newInstance("Script", { Name = string.sub(name, 1, -13), SourcePath = path, Source = fs.readFile(path) })
			s.Parent = parent
		elseif string.sub(name, -12) == ".client.luau" then
			local s = newInstance("LocalScript", { Name = string.sub(name, 1, -13), SourcePath = path, Source = fs.readFile(path) })
			s.Parent = parent
		elseif string.sub(name, -5) == ".luau" then
			-- le code est lu ici (lecture asynchrone interdite pendant la simulation)
			local s = newInstance("ModuleScript", { Name = string.sub(name, 1, -6), SourcePath = path, Source = fs.readFile(path) })
			s.Parent = parent
		end
	end
end

function Fake.mountProject()
	local shared = newInstance("Folder", { Name = "Shared" })
	shared.Parent = service("ReplicatedStorage")
	mount("src/ReplicatedStorage/Shared", shared)
	mount("src/ServerScriptService", service("ServerScriptService"))
	Players.CharacterAutoLoads = true
end

function Fake.runServer()
	local main = service("ServerScriptService"):FindFirstChild("Main")
	Sched.spawn(function()
		loadScript(main)
	end)
end

Fake.Enum = roblox.Enum

-- Envoie Heartbeat / RenderStepped plusieurs fois par seconde (temps virtuel)
function Fake.startFramePump(hz: number)
	local runService = service("RunService")
	Sched.spawn(function()
		while true do
			Fake.task.wait(1 / hz)
			runService.Heartbeat:Fire(1 / hz)
			runService.RenderStepped:Fire(1 / hz)
		end
	end)
end

-- Lance le vrai code client (StarterPlayerScripts) pour un joueur
function Fake.startClient(player)
	Fake.clientPlayer = player
	Players.LocalPlayer = player
	local camera = newInstance("Camera", { Name = "Camera", CFrame = roblox.CFrame.new(0, 40, 60), ViewportSize = roblox.Vector2.new(1280, 720) })
	camera.Parent = workspace
	workspace.CurrentCamera = camera
	local playerGui = newInstance("PlayerGui", { Name = "PlayerGui" })
	playerGui.Parent = player
	local playerScripts = newInstance("PlayerScripts", { Name = "PlayerScripts" })
	playerScripts.Parent = player
	mount("src/StarterPlayer/StarterPlayerScripts", playerScripts)
	service("UserInputService").TouchEnabled = false
	service("UserInputService").KeyboardEnabled = true
	for _, message in Fake.earlyMessages[player] or {} do
		message.remote.OnClientEvent:FireOrQueue(table.unpack(message.args, 1, message.args.n))
	end
	Fake.earlyMessages[player] = nil
	local clientScript = playerScripts:FindFirstChild("Client")
	Sched.spawn(function()
		loadScript(clientScript, "client")
	end)
end

function Fake.requireClient(instance)
	return makeRequire("client")(instance)
end

function Fake.require(path: string)
	local current = game
	for part in string.gmatch(path, "[^%.]+") do
		current = current:FindFirstChild(part)
		assert(current, "introuvable : " .. path)
	end
	return customRequire(current)
end

function Fake.service(name: string)
	return service(name)
end

return Fake
