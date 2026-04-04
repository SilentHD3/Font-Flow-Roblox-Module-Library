--[[
    NPC Autonomous Behavior Controller
    Handles Pathfinding, Player Detection, and State-based Logic (Patrol/Chase/Idle).
--]]

--// Services: Core Roblox APIs used for environment interaction and navigation
local Pathfinding = game:GetService("PathfindingService")
local TweenService = game:GetService("TweenService")
local ChatService = game:GetService("Chat")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

--// NPC Setup: References to the physical components of the character
local NPC = Workspace:WaitForChild("Noob")
local Humanoid = NPC:WaitForChild("Humanoid")
local Root = NPC:WaitForChild("HumanoidRootPart")
local Head = NPC:WaitForChild("Head")

--// Environment: Folder containing parts used for the patrol route
local PatrolFolder = Workspace:WaitForChild("PatrolFolder")

--// Settings: Tunable parameters to adjust AI difficulty and behavior
local DETECTION_RANGE = 25
local LOSE_TARGET_RANGE = 35
local IDLE_CHANCE = 0.4
local LOOK_DURATION = 1.2
local CHASE_SPEED = 16
local WALK_SPEED = 10
local ATTACK_RANGE = 3 -- Distance required to trigger the "Got you!" logic

 
--// States: Tracks the current behavioral mode of the AI
local State = "Patrol" -- Current options: Patrol / Idle / Chase / Suspicious
local CurrentTarget = nil

--// Animations: Object creation for character movement feedback
local Animations = {
	Idle = Instance.new("Animation"),
	Walk = Instance.new("Animation"),
	Run = Instance.new("Animation"),
}

Animations.Idle.AnimationId = "rbxassetid://113669618253455"
Animations.Walk.AnimationId = "rbxassetid://113325098577994"
Animations.Run.AnimationId = "rbxassetid://94915892664446"

--// Animation Loading: Initializing tracks into the Animator for replication
local Animator = Humanoid:WaitForChild("Animator")
local LoadedAnims = {}

LoadedAnims.Idle = Animator:LoadAnimation(Animations.Idle)
LoadedAnims.Walk = Animator:LoadAnimation(Animations.Walk)
LoadedAnims.Run = Animator:LoadAnimation(Animations.Run)

print("Animations successfully initialized.")

--// Dialogue Data: Randomized strings for different behavioral triggers
local Dialogues = {
	Idle = {
		"Nice weather today...", "I wonder where everyone is...", 
		"Hmm...", "Just walking around...", "nothing to do..", ":)",
	},
	Chase = {
		"HEY YOU!", "COME BACK!", "I SEE YOU!", "STOP RIGHT THERE!",
	},
	Lost = {
		"Where did they go...", "I lost them...", "Strange...", "what the hell?",
	},
	Suspicious = {
		"I think I saw something...", "Huh?", "i heard something..", "Who's there?",
	},
}

--// Speak Function: Wraps the Chat service in a non-blocking thread to prevent AI stuttering
local function Speak(text)
	task.spawn(function() 
		ChatService:Chat(Head, text, Enum.ChatColor.White)
	end)
end

--// RandomDialogue: Helper to extract a random string from the Dialogue tables
local function RandomDialogue(category)
	local list = Dialogues[category]
	if not list or #list == 0 then
		return "..." 
	end
	return list[math.random(1, #list)]
end

--// PlayAnim: Stops active tracks to ensure smooth transitions between animation states
local function PlayAnim(anim)
	for _, a in pairs(LoadedAnims) do
		if a.IsPlaying then
			a:Stop() 
		end
	end
	anim:Play()
end

--// GetRandomPart: Selects a destination from the patrol folder for navigation
local function GetRandomPart()
	local parts = PatrolFolder:GetChildren()
	if #parts == 0 then
		return nil 
	end
	return parts[math.random(1, #parts)]
end

--// CreatePath: Interface with PathfindingService to calculate a walkable route
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
		warn("Path computation failed.")
		return nil
	end
end

--// FollowPath: Iterates through waypoints and handles jumping/movement logic
local function FollowPath(path, speedAnim)
	PlayAnim(speedAnim)

	for _, wp in ipairs(path:GetWaypoints()) do
		-- State-check exit: If the NPC spots a player while patrolling, it aborts the path
		if State ~= "Chase" and State ~= "Patrol" then
			return false 
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

--// LookAt: Uses TweenService to smoothly rotate the NPC toward a target point
local function LookAt(pos)
	local cf = CFrame.new(Root.Position, pos)
	local tween = TweenService:Create(Root, TweenInfo.new(LOOK_DURATION), { CFrame = cf })
	tween:Play()
end

--// Idle: Passive behavior state with randomized wait times
local function Idle()
	State = "Idle"
	PlayAnim(LoadedAnims.Idle)
	Speak(RandomDialogue("Idle"))

	task.wait(math.random(2, 4)) 

	State = "Patrol"
	PlayAnim(LoadedAnims.Walk)
end

--// GetNearestPlayer: Scans the Players service for the closest target within range
local function GetNearestPlayer()
	local nearest = nil
	local shortest = DETECTION_RANGE

	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		if char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Humanoid") then
			local dist = (Root.Position - char.HumanoidRootPart.Position).Magnitude
			-- Validation: Only targets alive players within the detection threshold
			if dist < shortest and char.Humanoid.Health > 0 then
				shortest = dist
				nearest = player
			end
		end
	end

	return nearest
end

--// Attack: Handles the outcome of the NPC successfully reaching a player
local function Attack(player)
	if not player.Character or not player.Character:FindFirstChild("Humanoid") then
		return
	end
	local humanoid = player.Character.Humanoid

	if Humanoid.Health > 0 then
		humanoid.Health = 0 -- Instantly defeats player
		Speak("Got you!") 
	end
end

--// Chase: Aggressive state that moves the NPC toward a moving target in real-time
local function Chase(player)
	State = "Chase"
	Speak(RandomDialogue("Chase"))

	Humanoid.WalkSpeed = CHASE_SPEED
	PlayAnim(LoadedAnims.Run)

	while player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") do
		local targetPos = player.Character.HumanoidRootPart.Position
		local dist = (Root.Position - targetPos).Magnitude

		-- Proximity check for attack trigger
		if dist <= ATTACK_RANGE then
			Attack(player)
			return
		end

		-- Range check to determine if the player escaped
		if dist > LOSE_TARGET_RANGE then
			Speak(RandomDialogue("Lost"))
			State = "Suspicious"
			return
		end

		Humanoid:MoveTo(targetPos)
		task.wait(0.1) -- Refresh rate for tracking moving targets
	end

	State = "Suspicious"
end

--// Suspicious: Intermediary state where NPC looks around after losing a target
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

--// Patrol: Core loop for moving between points in the PatrolFolder
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

	-- Random roll to determine if the NPC enters an Idle state after a leg of the patrol
	if math.random() < IDLE_CHANCE then
		Idle()
	end
end

--// Brain: The primary decision-making loop that drives the State Machine
local function Brain()
	while true do
		local player = GetNearestPlayer()

		-- Decision Tree: Priority is given to Chasing if a player is detected
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

		task.wait(0.5) -- Throttling the brain loop to save server performance
	end
end

--// Initial Start-up Delay
task.wait(2)
print("AI system online.")

-- Initiate the decision loop
Brain()
