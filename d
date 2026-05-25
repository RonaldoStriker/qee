if not game:IsLoaded() then
	game.Loaded:Wait()
end

local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer

local queued =
	queue_on_teleport
	or queueonteleport
	or (syn and syn.queue_on_teleport)

if queued then
	queued(game:HttpGet("YOUR_RAW_SCRIPT_URL_HERE")())
end

local reconnecting = false

local function reconnectLoop()
	if reconnecting then
		return
	end

	reconnecting = true

	while true do
		local success, err = pcall(function()
			TeleportService:Teleport(game.PlaceId, player)
		end)

		if success then
			break
		end

		warn("Reconnect failed:", err)

		task.wait(5)
	end

	reconnecting = false
end

GuiService.ErrorMessageChanged:Connect(function()
	local err = GuiService:GetErrorMessage()

	if err and err ~= "" then
		task.spawn(reconnectLoop)
	end
end)

game:GetService("CoreGui").ChildAdded:Connect(function(child)
	if child.Name == "RobloxPromptGui" then
		task.spawn(reconnectLoop)
	end
end)

local ROYAL_NATION = "Royal Nation"
local GOLDEN_EMPIRE = "Golden Empire"

local serverStuff = workspace:WaitForChild("serverStuff")
local valuesFolder = serverStuff:WaitForChild("values")
local surrenders = valuesFolder:WaitForChild("surrenders")
local empireTickets = valuesFolder:WaitForChild("empiretickets")
local nationTickets = valuesFolder:WaitForChild("nationtickets")
local fastProgression = serverStuff:WaitForChild("fastprogression")

local surrenderRunning = false
local ticketsConnection
local initialized = false

player.Idled:Connect(function()
	VirtualUser:CaptureController()
	VirtualUser:ClickButton2(Vector2.new())
end)

local function pressBTwice()
	if surrenderRunning then
		return
	end

	surrenderRunning = true

	repeat
		for i = 1, 2 do
			VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.B, false, game)
			task.wait(0.1)

			VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.B, false, game)
			task.wait(0.1)
		end

		task.wait(0.1)
	until surrenders.Value > 0

	surrenderRunning = false
end

local function getCommandBar()
	local success, commandBar = pcall(function()
		return player
			:WaitForChild("PlayerGui")
			:WaitForChild("main")
			:WaitForChild("CommandBar")
	end)

	if success then
		return commandBar
	end
end

local function runCommand(cmd)
	local commandBar = getCommandBar()

	if not commandBar then
		return
	end

	commandBar:CaptureFocus()
	commandBar.Text = cmd

	VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
	VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
end

local function getTeamFromCharacter(character)
	local nationTeamFolder = workspace:FindFirstChild("nation_team")
	local empireTeamFolder = workspace:FindFirstChild("empire_team")

	if nationTeamFolder and character:IsDescendantOf(nationTeamFolder) then
		return ROYAL_NATION
	elseif empireTeamFolder and character:IsDescendantOf(empireTeamFolder) then
		return GOLDEN_EMPIRE
	end

	return nil
end

local function runDrainCommand()
	if not player.Character then
		return
	end

	local character = player.Character
	local teamName = getTeamFromCharacter(character)

	if not teamName then
		return
	end

	local command

	if teamName == ROYAL_NATION then
		command = "/drainnation"
	elseif teamName == GOLDEN_EMPIRE then
		command = "/drainempire"
	else
		return
	end

	runCommand(command)
end

local function monitorTickets()
	if ticketsConnection then
		ticketsConnection:Disconnect()
		ticketsConnection = nil
	end

	local character = player.Character

	if not character then
		return
	end

	local teamName = getTeamFromCharacter(character)

	if not teamName then
		return
	end

	local tickets

	if teamName == ROYAL_NATION then
		tickets = nationTickets
	elseif teamName == GOLDEN_EMPIRE then
		tickets = empireTickets
	else
		return
	end

	if tickets.Value <= 0 then
		pressBTwice()
	end

	ticketsConnection = tickets.Changed:Connect(function(value)
		if value <= 0 then
			pressBTwice()
		end
	end)
end

local function ensureFastProgression()
	while not fastProgression.Value do
		runCommand("/fastprogression")
		task.wait(1)
	end
end

local function initializeOnce()
	if initialized then
		return
	end

	initialized = true

	runCommand("/togglecampaign")
	task.wait(0.3)

	runCommand("/gamemode control")
	task.wait(0.3)

	runCommand("/fastrespawns")
	task.wait(0.3)

	task.spawn(ensureFastProgression)

	task.wait(0.3)

	runCommand("/skipround")
end

task.spawn(function()
	while true do
		local character = player.Character or player.CharacterAdded:Wait()

		character:WaitForChild("ingameScript")

		task.wait(1)

		repeat
			character = player.Character
			task.wait(0.5)
		until getTeamFromCharacter(character)

		initializeOnce()
		monitorTickets()

		while player.Character and getTeamFromCharacter(player.Character) do
			runDrainCommand()
			task.wait(0.1)
		end
	end
end)

print("Loaded!")
