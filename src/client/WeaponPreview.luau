local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local e = React.createElement

local PREVIEW_SIZE = Vector2.new(146, 64)
local PRESENTATION = CFrame.Angles(0, math.rad(75), 0) * CFrame.Angles(math.rad(-8), 0, 0)

local function copyGeometry(tool: Tool): Model?
	local handle = tool:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then return nil end
	local model = Instance.new("Model")
	model.Name = "WeaponDisplay"
	for _, source in tool:GetDescendants() do
		if not source:IsA("BasePart") or not source.Archivable then continue end
		local part = source:Clone()
		-- Only visual children belong in a static preview; never retain weapon scripts or joints.
		for _, child in part:GetDescendants() do
			if not (child:IsA("DataModelMesh") or child:IsA("Decal") or child:IsA("Texture")
				or child:IsA("SurfaceAppearance")) then
				child:Destroy()
			end
		end
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.LocalTransparencyModifier = 0
		part.CFrame = PRESENTATION * handle.CFrame:ToObjectSpace(source.CFrame)
		part.Parent = model
	end
	if #model:GetChildren() == 0 then
		model:Destroy()
		return nil
	end
	return model
end

return function(props: { tool: Tool? })
	local viewportRef = React.useRef(nil)
	React.useEffect(function()
		local viewport = viewportRef.current
		local tool = props.tool
		if not viewport or not tool then return end
		local camera = Instance.new("Camera")
		camera.FieldOfView = 28
		camera.Parent = viewport
		viewport.CurrentCamera = camera
		local model: Model? = nil
		local pending: thread? = nil
		local function rebuild()
			if model then model:Destroy() end
			model = copyGeometry(tool)
			if not model then return end
			model.Parent = viewport
			local bounds, size = model:GetBoundingBox()
			local aspect = PREVIEW_SIZE.X / PREVIEW_SIZE.Y
			local distance = math.max(size.Y, size.X / aspect) / (2 * math.tan(math.rad(camera.FieldOfView / 2)))
			camera.CFrame = CFrame.lookAt(bounds.Position + Vector3.new(0, 0, distance * 1.16 + size.Z / 2), bounds.Position)
		end
		local function scheduleRebuild(descendant: Instance)
			if not descendant:IsA("BasePart") or pending then return end
			-- Coalesce parts arriving together during weapon replication.
			pending = task.defer(function()
				pending = nil
				rebuild()
			end)
		end
		local added = tool.DescendantAdded:Connect(scheduleRebuild)
		local removing = tool.DescendantRemoving:Connect(scheduleRebuild)
		rebuild()
		return function()
			added:Disconnect()
			removing:Disconnect()
			if pending then task.cancel(pending) end
			viewport.CurrentCamera = nil
			if model then model:Destroy() end
			camera:Destroy()
		end
	end, { props.tool or false })

	return e("ViewportFrame", {
		ref = viewportRef,
		Name = "RevolverPreview",
		Position = UDim2.fromOffset(6, 5),
		Size = UDim2.fromOffset(PREVIEW_SIZE.X, PREVIEW_SIZE.Y),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(190, 190, 190),
		LightColor = Color3.fromRGB(255, 250, 240),
		LightDirection = Vector3.new(-1, -2, -3),
	})
end
