local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local Offer = require(script.Parent.UpgradeOfferState)
local player = Players.LocalPlayer
local chooseRemote = ReplicatedStorage:WaitForChild("ChooseUpgrade") :: RemoteEvent

local function readSnapshot(): Offer.Snapshot
	local value = player:GetAttribute("UpgradeState")
	if typeof(value) == "string" then
		local success, snapshot = pcall(HttpService.JSONDecode, HttpService, value)
		if success and typeof(snapshot) == "table" then
			return snapshot
		end
	end
	return Offer.empty()
end

return function()
	local state, setState = React.useState(function()
		return Offer.new(readSnapshot())
	end)
	local current = React.useRef(state)
	local function commit(nextState: Offer.State)
		current.current = nextState
		setState(nextState)
	end

	React.useEffect(function()
		local function receive()
			commit(Offer.receive(current.current, readSnapshot()))
		end
		local changed = player:GetAttributeChangedSignal("UpgradeState"):Connect(receive)
		local removing = player.CharacterRemoving:Connect(function()
			commit(Offer.new(Offer.empty()))
		end)
		receive()
		return function()
			changed:Disconnect()
			removing:Disconnect()
		end
	end, {})

	React.useEffect(function()
		if not state.requested and not state.selected then
			return
		end
		-- Allow a retry if a request is rejected; never leave the controls stuck.
		local timer: thread? = nil
		timer = task.delay(if state.selected then Offer.SELECTION_DURATION else 1.5, function()
			timer = nil
			commit(Offer.finish(current.current))
		end)
		return function()
			if timer then
				task.cancel(timer)
			end
		end
	end, { state.requested or "", state.selected or "", state.displayed.offerId })

	local choose = React.useCallback(function(index: number)
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if not humanoid or humanoid.Health <= 0 then
			return
		end
		local previous = current.current
		local nextState = Offer.request(previous, index)
		if nextState == previous then
			return
		end
		commit(nextState)
		chooseRemote:FireServer(nextState.displayed.offerId, nextState.requested)
	end, {})

	return state, choose
end
