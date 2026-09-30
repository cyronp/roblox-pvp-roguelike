local ReplicatedStorage = game:GetService("ReplicatedStorage")
local template = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("UpgradeCard") :: Model
local Projection = require(script.Parent.UpgradeCardProjection)

local CardModel = {
	-- The local model preserves the uploaded mesh IDs without a runtime InsertService call.
	AssetId = 83993627838046,
	Image = "rbxassetid://123780956272251",
	Width = Projection.Width,
	Height = Projection.Height,
	Styles = {
		Damage = { color = Color3.fromRGB(247, 123, 57), description = "Every shot deals\n5 extra damage.", buff = "+5 DAMAGE" },
		Ammo = { color = Color3.fromRGB(242, 185, 45), description = "Carry 1 more bullet\nin each magazine.", buff = "+1 BULLET" },
		FireRate = { color = Color3.fromRGB(56, 159, 236), description = "Cut base shot delay\nby another 10%.", buff = "-10% SHOT DELAY" },
		Health = { color = Color3.fromRGB(66, 199, 141), description = "Gain 10 max health\nand heal 10 health.", buff = "+10 HEALTH" },
		Reload = { color = Color3.fromRGB(168, 121, 232), description = "Cut base reload time\nby another 10%.", buff = "-10% RELOAD TIME" },
	},
}

function CardModel.mount(viewport: ViewportFrame, color: Color3): (() -> (), (number) -> ())
	local model = template:Clone()
	local body = model:FindFirstChild("Card_Body", true) :: BasePart
	local face = model:FindFirstChild("Card_Colored_Face", true) :: BasePart
	local artwork = model:FindFirstChild("Card_Artwork_Frame", true) :: BasePart
	-- Studio imported this shell lying flat. Derive its front and top from its
	-- named panels so its saved Workspace position/rotation does not affect the HUD.
	local normal = (face.Position - body.Position).Unit
	local toArtwork = artwork.Position - body.Position
	local up = (toArtwork - normal * toArtwork:Dot(normal)).Unit
	local front = CFrame.fromMatrix(body.Position, up:Cross(normal), up, normal)
	local dark = color:Lerp(Color3.new(0, 0, 0), 0.38)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CFrame = front:ToObjectSpace(part.CFrame)
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.CastShadow = false
			part.Material = Enum.Material.SmoothPlastic
			if part.Name == "Card_Colored_Face" or part.Name == "Card_Back_Face" then
				part.Color = color
			elseif part.Name == "Card_Description_Panel" then
				part.Color = Color3.fromRGB(255, 248, 236)
			elseif part.Name == "Card_Back_Sigil" then
				part.Color = Color3.new(1, 1, 1)
			else
				part.Color = dark
			end
		end
	end
	model.Parent = viewport
	local camera = Instance.new("Camera")
	camera.FieldOfView = Projection.FieldOfView
	local function setAngle(angle: number)
		-- Orbit around the vertical axis for a horizontal, side-to-side spin.
		camera.CFrame = CFrame.Angles(0, -angle, 0) * CFrame.new(0, 0, Projection.Distance)
	end
	setAngle(0)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	return function()
		viewport.CurrentCamera = nil
		camera:Destroy()
		model:Destroy()
	end, setAngle
end

return CardModel
