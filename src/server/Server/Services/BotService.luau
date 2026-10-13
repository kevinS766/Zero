local RunService = game:GetService("RunService")
local testModule = RunService:IsStudio() and script:FindFirstChild("TestDependencies")
local dependencies = testModule and require(testModule) or {}
local Players = dependencies.Players or game:GetService("Players")
local Workspace = dependencies.Workspace or game:GetService("Workspace")
local ReplicatedStorage = dependencies.ReplicatedStorage or game:GetService("ReplicatedStorage")
local PathfindingService = dependencies.PathfindingService or game:GetService("PathfindingService")
local StarterPlayer = game:GetService("StarterPlayer")
local clock = dependencies.Clock or os.clock
local BotService = {}
local Config = {
	TargetParticipants = 12,
	MaxBots = 11,
	HunterSpeed = 16,
	RunnerSpeed = 16,
	SprintBonus = 6,
	ReactionTime = .25,
	RepathTime = 1.1,
	MaxConcurrentPaths = 2,
	PathsPerSecond = 6,
	SearchRadius = 240,
	AttackDistance = 4,
	DashThreatRadius = 32,
	RescueDistance = 6,
	RescueHold = 2.5,
	TrapRadius = 7,
}
if dependencies.Config then for name,value in pairs(dependencies.Config) do Config[name] = value end end
local shared = ReplicatedStorage:FindFirstChild("Shared")
local roundConfigModule = shared and shared:FindFirstChild("Config") and shared.Config:FindFirstChild("RoundConfig")
local minHumans = dependencies.MinPlayers or (roundConfigModule and require(roundConfigModule).MIN_PLAYERS) or 2
Config.TargetParticipants = script:GetAttribute("TargetParticipants") or Config.TargetParticipants
local actors, serial, desiredTarget = {}, 0, Config.TargetParticipants
local rescueClaims, rescueEpisodes = {}, {}
local navigationMaps = {}
local roundGeneration = 0
local random = Random.new()
local friendLists, avatarCache, avatarOrder, loadingAvatars = {}, {}, {}, {}
local preparing = false
local MAX_CACHED_AVATARS = 24
local folder
local adapter = dependencies.Adapter
local adapterModule = script.Parent:FindFirstChild("BotGameplayAdapter")
if not adapter and adapterModule then
	local ok, result = pcall(require, adapterModule)
	if ok then adapter = result else warn("[BotService] Adapter failed: " .. tostring(result)) end
end
local adapterReady = type(adapter) == "table"
for _,method in ipairs({ "register", "unregister", "getActors", "requestAttack", "requestRescue", "requestDash" }) do
	adapterReady = adapterReady and type(adapter[method]) == "function"
end
if not adapterReady then
	warn("[BotService] Lobby bots only: Polaris must expose authoritative NPC registration/attack/rescue/dash APIs; no validation bypass is enabled")
end
script:SetAttribute("GameplayAdapterReady", adapterReady)
local phase = ReplicatedStorage:GetAttribute("RoundState") or "WAITING_FOR_PLAYERS"
local pathInFlight, pathTokens, cursor = 0, Config.PathsPerSecond, 0
local metrics = { Decisions = 0, PathRequests = 0, PathErrors = 0, AdapterErrors = 0, PathPeak = 0, DecisionMaxSeconds = 0 }

local function call(method, ...)
	if not adapterReady then return false end
	local ok, result = pcall(adapter[method], ...)
	if not ok then
		metrics.AdapterErrors += 1
		warn("[BotService] " .. method .. ": " .. tostring(result))
	end
	return ok and result
end

local function setState(actor, state)
	actor.state = state
	actor.Character:SetAttribute("BotState", state)
end

local function rootOf(actor)
	return actor.Character and actor.Character:FindFirstChild("HumanoidRootPart")
end

local function statusOf(actor)
	return actor:GetAttribute("Status") or "Active"
end

local function roleOf(actor)
	return actor:GetAttribute("Role") or "Lobby"
end

local function clearPath(actor)
	actor.generation += 1
	actor.waypoints = nil
	actor.moveDirection = nil
	if actor.blocked then actor.blocked:Disconnect(); actor.blocked = nil end
	if actor.path then actor.path:Destroy(); actor.path = nil end
end

local function releaseRescue(actor)
	if actor.rescueTarget and rescueClaims[actor.rescueTarget] and rescueClaims[actor.rescueTarget].actor == actor then
		rescueClaims[actor.rescueTarget] = nil
	end
	actor.rescueTarget = nil
end

local function destroy(actor)
	releaseRescue(actor)
	if actor.removed then return end
	actor.removed = true
	clearPath(actor)
	if actor.registered then call("unregister", actor) end
	actor.Character:Destroy()
end

local function getFolder()
	if not folder or not folder.Parent then
		folder = Instance.new("Folder")
		folder.Name = "ZeroBots"
		folder.Parent = Workspace
	end
	return folder
end

-- Avatar requests run during the lobby/intermission; no NPC is parented to Workspace there.
local function sanitizeRig(rig)
	for _,object in ipairs(rig:GetDescendants()) do
		if object:IsA("LuaSourceContainer") or object:IsA("Tool")
			or object.Name == "RoleHighlight" or object.Name == "RoleBillboard" or object.Name == "RescuePrompt" then
			object:Destroy()
		elseif object:IsA("BasePart") then
			object.Anchored = false
			if object:FindFirstAncestorOfClass("Accessory") then object.CanCollide = false; object.Massless = true end
		end
	end
	return rig
end

local function friendPool()
	local pool, used, present = {}, {}, {}
	for _,player in Players:GetPlayers() do present[player.UserId] = true end
	for _,owner in Players:GetPlayers() do
		for _,friend in ipairs(friendLists[owner.UserId] or {}) do
			if not present[friend.Id] and not used[friend.Id] then
				used[friend.Id] = true
				table.insert(pool, { Id = friend.Id, Username = friend.Username, DisplayName = friend.DisplayName, OwnerId = owner.UserId })
			end
		end
	end
	for i=#pool,2,-1 do local j=random:NextInteger(1,i);pool[i],pool[j]=pool[j],pool[i] end
	return pool
end

local function loadFriends(owner)
	if friendLists[owner.UserId] then return end
	local result = {}
	local ok,err = pcall(function()
		local pages = Players:GetFriendsAsync(owner.UserId)
		for _=1,3 do
			for _,friend in ipairs(pages:GetCurrentPage()) do
				if type(friend.Id)=="number" and friend.Id>0 then table.insert(result,friend) end
				if #result >= 128 then break end
			end
			if pages.IsFinished or #result>=128 then break end
			pages:AdvanceToNextPageAsync()
		end
	end)
	if not ok then warn("[BotService] Friend list unavailable; using player appearance: "..tostring(err)) end
	friendLists[owner.UserId] = result
end

local function prepareAvatars()
	if preparing or #Players:GetPlayers()>=desiredTarget then return end
	preparing = true
	task.spawn(function()
		for _,owner in Players:GetPlayers() do loadFriends(owner) end
		local pool = friendPool()
		local desired = math.clamp(desiredTarget-#Players:GetPlayers(),0,Config.MaxBots)
		script:SetAttribute("FriendCandidates",#pool)
		local inFlight = 0
		for i=1,math.min(#pool,desired) do
			local friend = pool[i]
			if not avatarCache[friend.Id] and not loadingAvatars[friend.Id] then
				while inFlight>=2 do task.wait(.05) end
				inFlight+=1;loadingAvatars[friend.Id]=true
				task.spawn(function()
					local ok,rig=pcall(function()
						local description=Players:GetHumanoidDescriptionFromUserIdAsync(friend.Id)
						description.UseAvatarSettings=false
						for _,name in ipairs({ "IdleAnimation","WalkAnimation","RunAnimation","JumpAnimation","FallAnimation","ClimbAnimation","SwimAnimation","MoodAnimation" }) do description[name]=0 end
						return sanitizeRig(Players:CreateHumanoidModelFromDescriptionAsync(description,Enum.HumanoidRigType.R6))
					end)
					if ok then
						avatarCache[friend.Id]=rig
						table.insert(avatarOrder,friend.Id)
						while #avatarOrder>MAX_CACHED_AVATARS do
							local expired=table.remove(avatarOrder,1)
							if avatarCache[expired] then avatarCache[expired]:Destroy();avatarCache[expired]=nil end
						end
					else warn("[BotService] Avatar preload failed: "..tostring(rig)) end
					loadingAvatars[friend.Id]=nil;inFlight-=1
				end)
			end
		end
		while inFlight>0 do task.wait(.05) end
		preparing=false
		script:SetAttribute("CachedAvatars",#avatarOrder)
	end)
end

local function createRig(friend, owner)
	if dependencies.CreateRig then return dependencies.CreateRig(friend) end
	if friend and avatarCache[friend.Id] then return avatarCache[friend.Id]:Clone() end
	local template = owner and owner.Character
	if not template or not template.Archivable then template=StarterPlayer:FindFirstChild("StarterCharacter") end
	assert(template and template:IsA("Model"), "No R6 fallback character")
	return sanitizeRig(template:Clone())
end

local function addBot(friend, owner, generation)
	local ok,rig=pcall(createRig,friend,owner)
	if not ok then warn("[BotService] Spawn failed: "..tostring(rig));return false end
	serial+=1
	local brainSeed=random:NextInteger(1,1000000000)
	local brainRandom=Random.new(brainSeed)
	local actor={ UserId=-serial, Name=friend and (friend.DisplayName or friend.Username) or ("ZERO Bot "..serial), IsBot=true, Character=rig,
		generation=0,nextPath=0,waypointIndex=1,lastDecision=-math.huge,
		rng=brainRandom,reaction=Config.ReactionTime*brainRandom:NextNumber(.8,1.5),
		repath=Config.RepathTime*brainRandom:NextNumber(.85,1.25),
		rescueChoices={},rescueChance=brainRandom:NextNumber(.35,.65),
		rescueSafety=brainRandom:NextNumber(22,34),fleeAngle=brainRandom:NextNumber(-.35,.35),nextJump=0 }
	function actor:GetAttribute(name) return self.Character:GetAttribute(name) end
	function actor:SetAttribute(name,value) self.Character:SetAttribute(name,value) end
	rig.Name=actor.Name.." [BOT]"
	rig:SetAttribute("IsBot",true)
	rig:SetAttribute("BotActorId",actor.UserId)
	rig:SetAttribute("AvatarUserId",friend and friend.Id or owner and owner.UserId or 0)
	rig:SetAttribute("FriendOwnerUserId",friend and friend.OwnerId or owner and owner.UserId or 0)
	rig:SetAttribute("AvatarSource",friend and "Friend" or "PlayerFallback")
	rig:SetAttribute("BotBrainSeed",brainSeed)
	rig:SetAttribute("Role","Lobby");rig:SetAttribute("Status","Active")
	rig.Parent=getFolder()
	local humanoid=rig:FindFirstChildOfClass("Humanoid")
	local root=rig:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.RigType~=Enum.HumanoidRigType.R6 then rig:Destroy();return false end
	humanoid.DisplayName=actor.Name.." · BOT"
	pcall(function() root:SetNetworkOwner(nil) end)
	-- chocar a toda velocidad (dash) no lo tira al suelo
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown,false);humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll,false)
	actor.registered=call("register",actor)==true
	if not actor.registered then rig:Destroy();return false end
	call("spawnRunner",actor)
	setState(actor,"Idle");table.insert(actors,actor)
	-- Late cosmetic requests never block a timer and cannot resurrect a removed actor.
	if friend and not avatarCache[friend.Id] then
		rig:SetAttribute("AvatarPending",true)
		task.spawn(function()
			local ok,err=pcall(function()
				local description=Players:GetHumanoidDescriptionFromUserIdAsync(friend.Id)
				description.UseAvatarSettings=false
						for _,name in ipairs({ "IdleAnimation","WalkAnimation","RunAnimation","JumpAnimation","FallAnimation","ClimbAnimation","SwimAnimation","MoodAnimation" }) do description[name]=0 end
				if actor.removed or roundGeneration~=generation then return end
				humanoid:ApplyDescriptionAsync(description)
				if not actor.removed then sanitizeRig(rig) end
			end)
			if not ok then warn("[BotService] Late appearance failed: "..tostring(err)) end
			if not actor.removed then rig:SetAttribute("AvatarPending",false) end
		end)
	end
	script:SetAttribute("ActiveBots",#actors)
	return true
end

function BotService.getBotCount() return #actors end

function BotService.removeOne()
	local actor=table.remove(actors)
	if not actor then return false end
	destroy(actor);script:SetAttribute("ActiveBots",#actors)
	return true
end

function BotService.removeAll()
	roundGeneration+=1
	while #actors>0 do BotService.removeOne() end
	if folder then folder:Destroy();folder=nil end
end

-- Compatibility API: configure/preload only. The lobby remains free of NPCs.
local spawnRound
function BotService.fillLobby(targetCount)
	if targetCount==nil then
		if ReplicatedStorage:GetAttribute("RoundState")=="ROUND_ACTIVE" then spawnRound() end
		return #actors
	end
	if type(targetCount)~="number" or targetCount~=targetCount or math.abs(targetCount)==math.huge then return #actors end
	desiredTarget=math.clamp(math.floor(targetCount),2,Config.MaxBots+1)
	script:SetAttribute("TargetParticipants",desiredTarget)
	if phase=="WAITING_FOR_PLAYERS" or phase=="INTERMISSION" then prepareAvatars() end
	return #actors
end

spawnRound = function()
	if ReplicatedStorage:GetAttribute("RoundState")~="ROUND_ACTIVE" or not adapterReady then return {} end
	phase="ROUND_ACTIVE"
	if #actors>0 then return table.clone(actors) end
	roundGeneration+=1
	local generation=roundGeneration
	local humans=Players:GetPlayers()
	if #humans==0 then return {} end
	local needed=math.clamp(desiredTarget-#humans,0,Config.MaxBots)
	local pool=friendPool()
	local reusableFriends=table.clone(pool)
	for _=#actors+1,needed do
		local friend
		if #pool>0 then
			-- Prefer the avatars already prepared; use each friend at most once.
			local index=1
			for i,candidate in ipairs(pool) do if avatarCache[candidate.Id] then index=i;break end end
			friend=table.remove(pool,index)
		elseif #reusableFriends>0 then friend=reusableFriends[(_-1)%#reusableFriends+1] end
		if not addBot(friend,humans[(_-1)%#humans+1],generation) then break end
	end
	return table.clone(actors)
end

local function traps()
	local runtime = Workspace:FindFirstChild("ZeroRuntime")
	local container = runtime and runtime:FindFirstChild("Traps")
	return container and container:GetChildren() or {}
end

local function unsafeSegment(start, finish, hazards)
	local a, b = Vector3.new(start.X, 0, start.Z), Vector3.new(finish.X, 0, finish.Z)
	local segment = b - a
	for _,trap in ipairs(hazards) do
		if trap:IsA("BasePart") then
			local point = Vector3.new(trap.Position.X, 0, trap.Position.Z)
			local t = segment:Dot(segment) > 0 and math.clamp((point - a):Dot(segment) / segment:Dot(segment), 0, 1) or 0
			if (point - (a + segment * t)).Magnitude < Config.TrapRadius then return true end
		end
	end
	return false
end

local function requestPath(actor, goal)
	if actor.waypoints and actor.waypointIndex <= #actor.waypoints and actor.pathGoal
		and (goal - actor.pathGoal).Magnitude < 10 then return end
	if actor.computing or clock() < actor.nextPath or pathInFlight >= Config.MaxConcurrentPaths or pathTokens < 1 then return end
	actor.computing = true
	actor.nextPath = clock() + actor.repath
	local generation = actor.generation
	local origin = rootOf(actor).Position
	pathInFlight += 1
	metrics.PathPeak = math.max(metrics.PathPeak, pathInFlight)
	pathTokens -= 1
	metrics.PathRequests += 1
	task.spawn(function()
		local path
		local ok, waypoints = pcall(function()
			path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true, Costs = { Trap = math.huge } })
			path:ComputeAsync(origin, goal)
			if path.Status ~= Enum.PathStatus.Success then return nil end
			return path:GetWaypoints()
		end)
		pathInFlight -= 1
		actor.computing = false
		if actor.removed or generation ~= actor.generation then if path then path:Destroy() end; return end
		if not ok or not waypoints or #waypoints == 0 then
			metrics.PathErrors += 1
			actor.failedGoal=goal;actor.failedGoalUntil=clock()+5
			if path then path:Destroy() end
			return
		end
		if actor.goal and (goal - actor.goal).Magnitude > 18 then path:Destroy(); actor.nextPath = 0; return end
		if actor.blocked then actor.blocked:Disconnect() end
		if actor.path then actor.path:Destroy() end
		actor.path, actor.waypoints, actor.waypointIndex = path, waypoints, math.min(2, #waypoints)
		actor.pathGoal = goal
		-- Async paths start behind a moving actor; skip only segments already passed.
		local position = rootOf(actor).Position
		while actor.waypointIndex < #waypoints do
			local previous, point = waypoints[actor.waypointIndex-1], waypoints[actor.waypointIndex]
			local segment = point.Position - previous.Position
			if point.Action == Enum.PathWaypointAction.Jump or segment:Dot(position-point.Position) < 0 then break end
			actor.waypointIndex += 1
		end
		actor.blocked = path.Blocked:Connect(function(index)
			if index >= actor.waypointIndex then clearPath(actor); actor.nextPath = 0 end
		end)
	end)
end

local function setSpeed(actor, sprint)
	local humanoid=actor.Character:FindFirstChildOfClass("Humanoid")
	local active=statusOf(actor)=="Active"
	local base=roleOf(actor)=="Hunter" and Config.HunterSpeed or Config.RunnerSpeed
	actor.Character:SetAttribute("ZeroSprinting",active and sprint or false)
	local lento=actor.Character:GetAttribute("ZeroLento")   -- ralentizado de la habilidad Común
	local veloz=actor.Character:GetAttribute("ZeroVeloz")   -- power-up VELOCIDAD (ZeroJugadas)
	if type(veloz)=="number" then lento=(type(lento)=="number" and lento or 1)*veloz end
	if humanoid then humanoid.WalkSpeed=active and (base+(sprint and Config.SprintBonus or 0))*(type(lento)=="number" and lento or 1) or 0 end
end

local function jump(actor, humanoid)
	if clock()>=actor.nextJump and humanoid.FloorMaterial~=Enum.Material.Air and statusOf(actor)=="Active" then
		humanoid.Jump=true;actor.nextJump=clock()+1.1
	end
end

local function move(actor, goal, hazards)
	actor.goal = goal
	requestPath(actor, goal)
end

-- Steering runs independently of tactical reactions so waypoints do not cause pauses.
local function followPath(actor, hazards)
	local root, humanoid = rootOf(actor), actor.Character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then return end
	if phase ~= "ROUND_ACTIVE" or statusOf(actor) ~= "Active" or humanoid.Health <= 0
		or actor.state == "RescueHold" or not actor.goal then
		humanoid:Move(Vector3.zero); actor.moveDirection = nil; return
	end
	requestPath(actor, actor.goal)
	local waypoint = actor.waypoints and actor.waypoints[actor.waypointIndex]
	while waypoint do
		local delta = waypoint.Position-root.Position
		local previous = actor.waypoints[actor.waypointIndex-1]
		local passed = false
		if previous then
			local segment=Vector3.new(waypoint.Position.X-previous.Position.X,0,waypoint.Position.Z-previous.Position.Z)
			local offset=Vector3.new(root.Position.X-previous.Position.X,0,root.Position.Z-previous.Position.Z)
			if segment.Magnitude>.1 then
				local projection=offset:Dot(segment.Unit)
				passed=projection>=segment.Magnitude and (offset-segment.Unit*projection).Magnitude<6
			end
		end
		if math.abs(delta.Y) >= 8 or (Vector2.new(delta.X,delta.Z).Magnitude > 2.8 and not passed) then break end
		if waypoint.Action == Enum.PathWaypointAction.Jump then jump(actor,humanoid) end
		actor.waypointIndex += 1
		waypoint = actor.waypoints[actor.waypointIndex]
	end
	if not waypoint then humanoid:Move(Vector3.zero); actor.moveDirection=nil; return end
	if unsafeSegment(root.Position, waypoint.Position, hazards) then
		clearPath(actor); actor.nextPath=clock()+actor.repath
		humanoid:Move(Vector3.zero); return
	end
	local delta=waypoint.Position-root.Position
	local flat=Vector3.new(delta.X,0,delta.Z)
	if flat.Magnitude < .1 then return end
	actor.moveDirection=flat.Unit
	if waypoint.Action == Enum.PathWaypointAction.Jump then jump(actor,humanoid) end
	local params=RaycastParams.new()
	params.FilterType=Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances={folder,actor.Character}
	params.RespectCanCollide=true
	local obstruction=Workspace:Raycast(root.Position-Vector3.new(0,1,0),flat.Unit*3,params)
	if obstruction and obstruction.Instance.Size.Y<5 then jump(actor,humanoid) end
	humanoid:Move(flat.Unit,false)
	if clock() >= (actor.progressAt or 0) then
		if actor.progressPosition and (root.Position-actor.progressPosition).Magnitude < 1 then
			jump(actor,humanoid); clearPath(actor); actor.nextPath=0
		end
		actor.progressPosition=root.Position
		actor.progressAt=clock()+1.5
	end
end

local function nearest(actor, roster, role, frozen)
	local root = rootOf(actor)
	local target, distance = nil, Config.SearchRadius
	for _,candidate in ipairs(roster) do
		local otherRoot = rootOf(candidate)
		local humanoid = candidate.Character and candidate.Character:FindFirstChildOfClass("Humanoid")
		if candidate ~= actor and otherRoot and humanoid and humanoid.Health > 0 and roleOf(candidate) == role
			and (statusOf(candidate) == "Frozen") == frozen then
			local d = (otherRoot.Position - root.Position).Magnitude
			if d < distance then target, distance = candidate, d end
		end
	end
	return target, distance
end

local function groundPoint(nav, candidate)
	candidate=Vector3.new(math.clamp(candidate.X,nav.minX,nav.maxX),nav.y+12,
		math.clamp(candidate.Z,nav.minZ,nav.maxZ))
	local params=RaycastParams.new()
	params.FilterType=Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances={nav.map}
	params.RespectCanCollide=true
	local hit=Workspace:Raycast(candidate,Vector3.new(0,-18,0),params)
	return hit and hit.Position.Y<=nav.y+2 and hit.Position or nil
end

-- Mapas de la rotación (MapConfig): solo uno está en Workspace a la vez
local NAV_MAPS = {}
do
	local ok, mapConfig = pcall(function() return require(ReplicatedStorage.Shared.Config.MapConfig) end)
	if ok then for _, id in mapConfig.SlotMapOrder do table.insert(NAV_MAPS, mapConfig.Maps[id].WorkspaceName) end end
end

local function navigation(actor)
	-- la ruta cacheada solo vale si su mapa sigue cargado (el mapa cambia entre rondas)
	if actor.navigation and actor.navigation.map.Parent == Workspace then return actor.navigation end
	local root=rootOf(actor)
	local best, distance
	for _,name in ipairs(NAV_MAPS) do
		local map=Workspace:FindFirstChild(name)
		if map then
			local nav=navigationMaps[map]
			if not nav then
				for _,part in ipairs(map:GetDescendants()) do
					if part:IsA("BasePart") and part.Name=="Floor" and part.Size.X>80 and part.Size.Z>80 and part.Size.Y<8 then
						nav={map=map,y=part.Position.Y+part.Size.Y/2,
							minX=part.Position.X-part.Size.X/2+22,maxX=part.Position.X+part.Size.X/2-22,
							minZ=part.Position.Z-part.Size.Z/2+22,maxZ=part.Position.Z+part.Size.Z/2-22,
							center=part.Position,points={}}
						for x=nav.minX+12,nav.maxX-12,28 do
							for z=nav.minZ+12,nav.maxZ-12,28 do
								local point=groundPoint(nav,Vector3.new(x,nav.y,z))
								if point then table.insert(nav.points,point) end
							end
						end
						navigationMaps[map]=nav
						break
					end
				end
			end
			if nav then
				local d=(nav.center-root.Position).Magnitude
				if not distance or d<distance then best,distance=nav,d end
			end
		end
	end
	actor.navigation=best
	return best
end

local function patrolGoal(actor, hazards)
	local nav=navigation(actor)
	local root=rootOf(actor)
	if not nav then return root.Position end
	local candidates={}
	for _,point in ipairs(nav.points) do
		local d=(point-root.Position).Magnitude
		if d>24 and d<100 and not unsafeSegment(point,point,hazards)
			and (not actor.failedGoal or clock()>actor.failedGoalUntil or (point-actor.failedGoal).Magnitude>8) then
			table.insert(candidates,point)
		end
	end
	return #candidates>0 and candidates[actor.rng:NextInteger(1,#candidates)] or nav.center+Vector3.new(0,2,0)
end

local function fleeGoal(actor, hunter, hazards)
	local root, threat=rootOf(actor),rootOf(hunter)
	local nav=navigation(actor)
	if not nav then return root.Position end
	local away=Vector3.new(root.Position.X-threat.Position.X,0,root.Position.Z-threat.Position.Z)
	if away.Magnitude<.1 then away=Vector3.new(1,0,0) end
	away=CFrame.Angles(0,actor.fleeAngle,0):VectorToWorldSpace(away.Unit)
	local candidates={}
	for i=-2,2 do
		local direction=CFrame.Angles(0,i*math.pi/4,0):VectorToWorldSpace(away)
		local point=groundPoint(nav,root.Position+direction*36)
		if point then table.insert(candidates,point) end
	end
	for _,point in ipairs(nav.points) do
		local d=(point-root.Position).Magnitude
		if d>20 and d<65 then table.insert(candidates,point) end
	end
	local best,bestScore
	for _,point in ipairs(candidates) do
		local delta=Vector3.new(point.X-root.Position.X,0,point.Z-root.Position.Z)
		if delta.Magnitude>8 and not unsafeSegment(root.Position,point,hazards)
			and (not actor.failedGoal or clock()>actor.failedGoalUntil or (point-actor.failedGoal).Magnitude>8) then
			local margin=math.min(point.X-nav.minX,nav.maxX-point.X,point.Z-nav.minZ,nav.maxZ-point.Z)
			local safety=math.min((point-threat.Position).Magnitude,65)
			local params=RaycastParams.new()
			params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances={nav.map};params.RespectCanCollide=true
			local cover=Workspace:Raycast(threat.Position,point+Vector3.new(0,3,0)-threat.Position,params)
			local score=safety+math.min(margin,32)*1.3+delta.Unit:Dot(away)*10-delta.Magnitude*.12+(cover and 10 or 0)
			if not bestScore or score>bestScore then best,bestScore=point,score end
		end
	end
	return best or patrolGoal(actor,hazards)
end

local function selectRescue(actor, roster, hunterDistance)
	local now=clock()
	local count=0
	for victim,claim in pairs(rescueClaims) do
		if statusOf(victim)~="Frozen" or statusOf(claim.actor)~="Active"
			or claim.serial~=victim:GetAttribute("FreezeSerial")
			or claim.actor.removed or roleOf(claim.actor)~="Runner" or now>claim.expires then
			rescueClaims[victim]=nil
		else count+=1 end
	end
	if actor.rescueTarget and rescueClaims[actor.rescueTarget]
		and rescueClaims[actor.rescueTarget].actor==actor and hunterDistance>actor.rescueSafety then
		return actor.rescueTarget
	end
	releaseRescue(actor)
	if hunterDistance<=actor.rescueSafety or count>=2 then return nil end
	local chosen, distance
	for _,victim in ipairs(roster) do
		if victim~=actor and roleOf(victim)=="Runner" and statusOf(victim)=="Frozen" and rootOf(victim) then
			local serial=victim:GetAttribute("FreezeSerial")
			local episode=rescueEpisodes[victim]
			if not episode or episode.serial~=serial then
				episode={serial=serial,enabled=random:NextNumber()<.7};rescueEpisodes[victim]=episode
			end
			local choice=actor.rescueChoices[victim]
			if not choice or choice.serial~=serial then
				choice={serial=serial,willing=actor.rng:NextNumber()<actor.rescueChance,after=now+actor.rng:NextNumber(.6,2.2)}
				actor.rescueChoices[victim]=choice
			end
			local d=(rootOf(victim).Position-rootOf(actor).Position).Magnitude
			if episode.enabled and choice.willing and now>=choice.after and not rescueClaims[victim]
				and victim:GetAttribute("FreezePaused")~=true and d<65
				and (not distance or d<distance) then chosen,distance=victim,d end
		end
	end
	if chosen then
		rescueClaims[chosen]={actor=actor,serial=chosen:GetAttribute("FreezeSerial"),expires=now+8}
		actor.rescueTarget=chosen
	end
	return chosen
end

local function decide(actor, roster, hazards)
	local root= rootOf(actor)
	local humanoid=actor.Character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health<=0 then releaseRescue(actor);return end
	if statusOf(actor)~="Active" or phase~="ROUND_ACTIVE" or not adapterReady or not actor.registered then
		if actor.waypoints then clearPath(actor) end
		actor.goal=nil;releaseRescue(actor)
		setState(actor,statusOf(actor)=="Frozen" and "Frozen" or "Idle")
		setSpeed(actor,false);return
	end
	local role=roleOf(actor)
	if role=="Hunter" then
		releaseRescue(actor)
		local target,distance=nearest(actor,roster,"Runner",false)
		if target then
			setState(actor,"Chase");setSpeed(actor,distance<70)
			move(actor,rootOf(target).Position,hazards)
			if distance<=Config.AttackDistance then
				local goal=rootOf(target).Position
				if Vector3.new(goal.X-root.Position.X,0,goal.Z-root.Position.Z).Magnitude>.01 then
					root.CFrame=CFrame.lookAt(root.Position,Vector3.new(goal.X,root.Position.Y,goal.Z))
				end
				call("requestAttack",actor,target)
			elseif distance<40 and actor.moveDirection then call("requestDash",actor,actor.moveDirection) end
			return
		end
	elseif role=="Runner" then
		local hunter,danger=nearest(actor,roster,"Hunter",false)
		local teammate=selectRescue(actor,roster,danger)
		if teammate then
			local distance=(rootOf(teammate).Position-root.Position).Magnitude
			setSpeed(actor,distance>16)
			if distance<=Config.RescueDistance and not unsafeSegment(root.Position,rootOf(teammate).Position,hazards) then
				setState(actor,"RescueHold");actor.goal=nil
				call("requestRescue",actor,teammate)
			else
				setState(actor,"Rescue");move(actor,rootOf(teammate).Position,hazards)
			end
			return
		elseif hunter and danger<70 then
			setState(actor,"Flee");setSpeed(actor,true)
			if not actor.fleeGoal or (actor.fleeGoal-root.Position).Magnitude<6
				or clock()>(actor.nextFlee or 0) then
				actor.fleeGoal=fleeGoal(actor,hunter,hazards);actor.nextFlee=clock()+actor.rng:NextNumber(2,3.5)
			end
			move(actor,actor.fleeGoal,hazards)
			if danger<Config.DashThreatRadius and actor.moveDirection then call("requestDash",actor,actor.moveDirection) end
			return
		end
	else
		setState(actor,"Idle");actor.goal=nil;releaseRescue(actor);return
	end
	setState(actor,"Patrol");setSpeed(actor,false);releaseRescue(actor)
	if not actor.patrolGoal or (actor.patrolGoal-root.Position).Magnitude<6
		or clock()>(actor.nextPatrol or 0) then
		actor.patrolGoal=patrolGoal(actor,hazards);actor.nextPatrol=clock()+actor.rng:NextNumber(5,9)
	end
	move(actor,actor.patrolGoal,hazards)
end

local function phaseChanged()
	local nextPhase = ReplicatedStorage:GetAttribute("RoundState") or "WAITING_FOR_PLAYERS"
	if nextPhase == phase then return end
	phase = nextPhase
	rescueClaims, rescueEpisodes = {}, {}
	for _,actor in ipairs(actors) do clearPath(actor); actor.goal=nil; actor.patrolGoal=nil; actor.fleeGoal=nil; releaseRescue(actor); actor.rescueChoices={} end
	if phase == "ROUND_END" then   -- se quedan durante la celebración (RoundService.CELEBRACION) para salir en la cámara final
		task.delay(5, function() if phase == "ROUND_END" then BotService.removeAll() end end)
	elseif phase == "WAITING_FOR_PLAYERS" then BotService.removeAll();task.defer(function() BotService.fillLobby(desiredTarget) end)
	elseif phase=="INTERMISSION" then BotService.fillLobby(desiredTarget) end
end
ReplicatedStorage:GetAttributeChangedSignal("RoundState"):Connect(phaseChanged)
Players.PlayerAdded:Connect(function()
	if phase~="ROUND_ACTIVE" then BotService.fillLobby(desiredTarget) end
end)
Players.PlayerRemoving:Connect(function(player)
	friendLists[player.UserId]=nil
	if phase~="ROUND_ACTIVE" then task.defer(function() BotService.fillLobby(desiredTarget) end) end
end)
RunService.Heartbeat:Connect(function(dt)
	pathTokens = math.min(Config.PathsPerSecond, pathTokens + dt * Config.PathsPerSecond)
	local roster = adapterReady and call("getActors") or {}
	if type(roster) ~= "table" then roster = {} end
	local hazards = traps()
	local count = #actors
	if count == 0 then return end
	cursor = cursor % count + 1
	for offset = 0, count - 1 do
		local actor = actors[(cursor + offset - 1) % count + 1]
		if clock() - actor.lastDecision >= actor.reaction then
			actor.lastDecision = clock()
			metrics.Decisions += 1
			local began = clock()
			local ok, err = pcall(decide, actor, roster, hazards)
			metrics.DecisionMaxSeconds = math.max(metrics.DecisionMaxSeconds, clock() - began)
			if not ok then warn("[BotService] Decision failed: " .. tostring(err)); setState(actor, "Idle") end
		end
		local ok,err=pcall(followPath,actor,hazards)
		if not ok then warn("[BotService] Steering failed: "..tostring(err)) end
	end
	for name,value in pairs(metrics) do script:SetAttribute(name, value) end
end)
-- de pie siempre: el servidor simula a los bots (si la física pasa a un cliente, allí se caen) y si alguno queda
-- tumbado o muy inclinado (choque contra pared o entre ellos, giro brusco) se levanta al momento
local CAIDOS = { [Enum.HumanoidStateType.FallingDown] = true, [Enum.HumanoidStateType.Ragdoll] = true,
	[Enum.HumanoidStateType.Physics] = true, [Enum.HumanoidStateType.PlatformStanding] = true }
local acumPie = 0
RunService.Heartbeat:Connect(function(dt)
	acumPie += dt
	if acumPie < 0.25 then return end
	acumPie = 0
	for _, actor in actors do
		local rig = actor.Character
		local h = rig and rig:FindFirstChildOfClass("Humanoid")
		local root = rig and rig:FindFirstChild("HumanoidRootPart") :: BasePart?
		if h and root and h.Health > 0 and not root.Anchored then
			if root:GetNetworkOwnershipAuto() or root:GetNetworkOwner() ~= nil then pcall(function() root:SetNetworkOwner(nil) end) end
			h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
			h:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
			if h.Sit then h.Sit = false end                   -- los bots no se quedan sentados en los bancos del lobby
			if CAIDOS[h:GetState()] or root.CFrame.UpVector.Y < 0.75 then
				script:SetAttribute("BotsLevantados", (script:GetAttribute("BotsLevantados") or 0) + 1)
				local look = root.CFrame.LookVector
				local flat = Vector3.new(look.X, 0, look.Z)
				if flat.Magnitude < 0.1 then flat = Vector3.new(0, 0, -1) end
				h.PlatformStand = false
				root.AssemblyAngularVelocity = Vector3.zero
				local v = root.AssemblyLinearVelocity
				root.AssemblyLinearVelocity = Vector3.new(v.X * 0.3, math.min(v.Y, 0), v.Z * 0.3)   -- sin salir volando
				root.CFrame = CFrame.lookAt(root.Position + Vector3.new(0, 0.5, 0), root.Position + Vector3.new(0, 0.5, 0) + flat.Unit)
				h:ChangeState(Enum.HumanoidStateType.GettingUp)
			end
		end
	end
end)

if phase == "WAITING_FOR_PLAYERS" then BotService.fillLobby(desiredTarget) end
return BotService