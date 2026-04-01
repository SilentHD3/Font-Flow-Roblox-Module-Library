--// Services
local Pathfinding = game:GetService("PathfindingService")
local TweenService = game:GetService("TweenService")
local ChatService = game:GetService("Chat")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

--// NPC setup
local NPC = Workspace:WaitForChild("Noob")
local Humanoid = NPC:WaitForChild("Humanoid")
local Root = NPC:WaitForChild("HumanoidRootPart")
local Head = NPC:WaitForChild("Head")

local PatrolFolder = Workspace:WaitForChild("PatrolFolder")

--// Settings
local WALK_DELAY = 2
local DETECTION_RANGE = 25
local LOSE_TARGET_RANGE = 35
local IDLE_CHANCE = 0.4
local LOOK_DURATION = 1.2
local CHASE_SPEED = 16
local WALK_SPEED = 10
local ATTACK_RANGE = 3 -- distance to "catch" player
local PATROL_PAUSE = 1.5 -- pause at patrol points

--// States
local State = "Patrol" -- Patrol / Idle / Chase / Suspicious
local CurrentTarget = nil

--// Animations
local Animations = {
	Idle = Instance.new("Animation"),
	Walk = Instance.new("Animation"),
	Run = Instance.new("Animation"),
}

Animations.Idle.AnimationId = "rbxassetid://113669618253455"
Animations.Walk.AnimationId = "rbxassetid://113325098577994"
Animations.Run.AnimationId = "rbxassetid://94915892664446"

local Animator = Humanoid:WaitForChild("Animator")
local LoadedAnims = {}

-- Loading animations with a bit of extra patience
LoadedAnims.Idle = Animator:LoadAnimation(Animations.Idle)
LoadedAnims.Walk = Animator:LoadAnimation(Animations.Walk)
LoadedAnims.Run = Animator:LoadAnimation(Animations.Run)

print("Animations loaded: Idle, Walk, Run") -- yes, I know this could be fancier

--// Dialogue
local Dialogues = {
	Idle = {
		"Nice weather today...",
		"I wonder where everyone is...",
		"Hmm...",
		"Just walking around...",
		"nothing to do..",
		":)",
	},
	Chase = {
		"HEY YOU!",
		"COME BACK!",
		"I SEE YOU!",
		"STOP RIGHT THERE!",
	},
	Lost = {
		"Where did they go...",
		"I lost them...",
		"Strange...",
		"what the hell?",
	},
	Suspicious = {
		"I think I saw something...",
		"Huh?",
		"i heard something..",
		"Who's there?",
	},
}

--// Utility: Speak
local function Speak(text)
	task.spawn(function() -- non-blocking, because otherwise NPC would freeze while talking
		ChatService:Chat(Head, text, Enum.ChatColor.White)
	end)
end

--// Get random dialogue from a category
local function RandomDialogue(category)
	local list = Dialogues[category]
	if not list or #list == 0 then
		return "..." -- fallback if nothing exists
	end
	return list[math.random(1, #list)]
end

--// Animation control
local function PlayAnim(anim)
	for _, a in pairs(LoadedAnims) do
		if a.IsPlaying then
			a:Stop() -- stop all animations first
		end
	end
	anim:Play()
end

--// Get a random patrol point
local function GetRandomPart()
	local parts = PatrolFolder:GetChildren()
	if #parts == 0 then
		return nil -- nothing to patrol, maybe we should panic here
	end
	return parts[math.random(1, #parts)]
end

--// Create path to a destination
local function CreatePath(dest)
	local path = Pathfinding:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
	})

	local success = pcall(function()
		path:ComputeAsync(Root.Position, dest)
	end)

	if success then
		return path
	else
		warn("Pathfinding failed, maybe blocked?")
		return nil
	end
end

--// Follow path
local function FollowPath(path, speedAnim)
	PlayAnim(speedAnim)

	for _, wp in ipairs(path:GetWaypoints()) do
		if State ~= "Chase" and State ~= "Patrol" then
			return false -- abort if state changed, lazy handling
		end

		if wp.Action == Enum.PathWaypointAction.Jump then
			Humanoid.Jump = true
		end

		Humanoid:MoveTo(wp.Position)
		local reached = Humanoid.MoveToFinished:Wait()

		if not reached then
			PlayAnim(LoadedAnims.Idle)
			break
		end
	end

	PlayAnim(LoadedAnims.Idle)
	return true
end

--// Look at a position
local function LookAt(pos)
	local cf = CFrame.new(Root.Position, pos)
	local tween = TweenService:Create(Root, TweenInfo.new(LOOK_DURATION), { CFrame = cf })
	tween:Play()
end

--// Idle behavior
local function Idle()
	State = "Idle"
	PlayAnim(LoadedAnims.Idle)
	Speak(RandomDialogue("Idle"))

	task.wait(math.random(2, 4)) -- pretend NPC is thinking

	State = "Patrol"
	PlayAnim(LoadedAnims.Walk)
end

--// Detect nearest player
local function GetNearestPlayer()
	local nearest = nil
	local shortest = DETECTION_RANGE

	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		if char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Humanoid") then
			local dist = (Root.Position - char.HumanoidRootPart.Position).Magnitude
			if dist < shortest and char.Humanoid.Health > 0 then
				shortest = dist
				nearest = player
			end
		end
	end

	return nearest
end

--// Attack player
local function Attack(player)
	if not player.Character or not player.Character:FindFirstChild("Humanoid") then
		return
	end
	local humanoid = player.Character.Humanoid

	if Humanoid.Health > 0 then
		humanoid.Health = 0
		Speak("Got you!") -- taunting
	end
end

--// Chase logic
local function Chase(player)
	State = "Chase"
	Speak(RandomDialogue("Chase"))

	Humanoid.WalkSpeed = CHASE_SPEED
	PlayAnim(LoadedAnims.Run)

	while player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") do
		local targetPos = player.Character.HumanoidRootPart.Position
		local dist = (Root.Position - targetPos).Magnitude

		if dist <= ATTACK_RANGE then
			Attack(player)
			return
		end

		if dist > LOSE_TARGET_RANGE then
			Speak(RandomDialogue("Lost"))
			State = "Suspicious"
			return
		end

		Humanoid:MoveTo(targetPos)
		task.wait(0.1) -- small delay, otherwise it jitters
	end

	State = "Suspicious"
end

--// Suspicious state
local function Suspicious()
	PlayAnim(LoadedAnims.Idle)
	Speak(RandomDialogue("Suspicious"))

	for i = 1, 3 do
		local offset = Vector3.new(math.random(-15, 15), 0, math.random(-15, 15))
		LookAt(Root.Position + offset)
		task.wait(1)
	end

	State = "Patrol"
	PlayAnim(LoadedAnims.Walk)
end

--// Patrol behavior
local function Patrol()
	State = "Patrol"
	Humanoid.WalkSpeed = WALK_SPEED
	PlayAnim(LoadedAnims.Walk)

	local point = GetRandomPart()
	if not point then
		return
	end

	local path = CreatePath(point.Position)
	if path then
		FollowPath(path, LoadedAnims.Walk)
		PlayAnim(LoadedAnims.Idle)
	end

	if math.random() < IDLE_CHANCE then
		Idle()
	end
end

--// Main AI loop
local function Brain()
	while true do
		local player = GetNearestPlayer()

		if player then
			CurrentTarget = player
			Chase(player)
		else
			if State == "Suspicious" then
				Suspicious()
			else
				Patrol()
			end
		end

		task.wait(0.5)
	end
end

task.wait(2)
print("ai started")

Brain()
