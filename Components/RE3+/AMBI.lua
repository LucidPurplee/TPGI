--!nonstrict

-- Light detection revamp was originally created by kalabgs to our knowledge.
-- A few minor modifications have been made but otherwise all credit goes to them.

local module = {}
module.blacklist = {}

local Lighting = game.Lighting
local Run_Service = game:GetService("RunService")

local function SpotLight(x : Vector3, dir : Vector3, p : Vector3, ang : number, range : number) -- Cone
	local Unit = (p - x).Unit
	local Mag = (p - x).Magnitude

	local Dot = dir:Dot(Unit)

	return math.deg(math.acos(Dot)) < ang/2 and range > Mag
end

local function Side4D(p1, p2, p3, p4, p)
	local dp = (p1 + p2 + p3 + p4) / 4

	local up = (p2 - p1)
	local right = (p2 - p4)

	local dir = up:Cross(right)

	local dir2 = (dp - p)
	local dot = dir:Dot(dir2)

	return dot >= 1
end 

local function SurfaceLight(p1, p2, p3, p4, p5, p6, p7, p8, p)
	local x, x1, x2, x3, x4, x5 = Side4D(p1, p2, p3, p4, p), Side4D(p1, p5, p6, p2, p), Side4D(p2, p6, p7, p3, p), Side4D(p3, p7, p8, p4, p), Side4D(p4, p8, p5, p1, p), Side4D(p5, p8, p7, p6, p)

	return x and x1 and x2 and x3 and x4 and x5
end

local function PointLight(x, p, r)
	return (x - p).Magnitude < r
end

local function CheckObfuscated(t)
	local cleanParts = {}
	for i, part in pairs(t) do
		if part.CastShadow == true and part.Transparency < 0.5 then
			table.insert(cleanParts, part)
		end
	end

	return cleanParts
end

local function GetVectorFromNormal(BasePart, Normal)
	local Dirs = {}

	if BasePart:IsA("BasePart") then
		Dirs = {
			[Enum.NormalId.Top] = BasePart.CFrame.UpVector,
			[Enum.NormalId.Bottom] = -BasePart.CFrame.UpVector,
			[Enum.NormalId.Right] = BasePart.CFrame.RightVector,
			[Enum.NormalId.Left] = -BasePart.CFrame.RightVector,
			[Enum.NormalId.Front] = BasePart.CFrame.LookVector,
			[Enum.NormalId.Back] = -BasePart.CFrame.LookVector,
		}
	else
		Dirs = {
			[Enum.NormalId.Top] = BasePart.WorldCFrame.UpVector,
			[Enum.NormalId.Bottom] = -BasePart.WorldCFrame.UpVector,
			[Enum.NormalId.Right] = BasePart.WorldCFrame.RightVector,
			[Enum.NormalId.Left] = -BasePart.WorldCFrame.RightVector,
			[Enum.NormalId.Front] = BasePart.WorldCFrame.LookVector ,
			[Enum.NormalId.Back] = -BasePart.WorldCFrame.LookVector,
		}
	end

	return Dirs[Normal]
end

local function CheckInSunlight(Point)
	local sunlightDir = Lighting:GetSunDirection()
	local sp = Point + sunlightDir * 500
	local scf = CFrame.lookAt(sp, sp + sunlightDir)
	local ssize = Vector3.new(1, 1, 1000)

	local obfuscatedParts = CheckObfuscated(workspace:GetPartBoundsInBox(scf, ssize, OverlapParams.new()))

	if #obfuscatedParts == 0 and 18 > Lighting.ClockTime and Lighting.ClockTime > 8 then
		return true
	end

	return false
end

local AllLights = {}

local function CheckIsBlacklisted(Inst)
	local Is = false
	for i, v in pairs(module.blacklist) do
		if Inst:IsDescendantOf(v) then
			Is = true
		end
	end
	return Is
end

workspace.DescendantAdded:Connect(function(child)
	if CheckIsBlacklisted(child) == false then
		if child:IsA("Light") then
			table.insert(AllLights, child)
		end
	end
end)

for _, v in pairs(workspace:GetDescendants()) do
	if CheckIsBlacklisted(v) == false then
		if v:IsA("Light") then
			table.insert(AllLights, v)
		end
	end
end

export type LightObject = {
	LightLevel: number,
	Lights: {Light},
	Sunlight: boolean,
	InLight: boolean
}

function module:DetectLightAtPoint(Point)
	local Detected = {
		Lights = {},
		Sunlight = false,
		InLight = false,
		LightLevel = 0,
	} :: LightObject

	local SunLight = CheckInSunlight(Point)

	if SunLight then
		Detected.Sunlight = true
		Detected.LightLevel += game.Lighting.Brightness
	end

	for _, Light in pairs(AllLights) do	
		if CheckIsBlacklisted(Light) == false then
			local LightParent = Light.Parent
			local LightPos = LightParent:IsA("BasePart") and LightParent.Position or (LightParent:IsA("Attachment") and LightParent.WorldPosition or nil)

			if not LightPos then continue end
			if not Light.Enabled then continue end

			local Brightness = Light.Brightness / 2
			local range = Light.Range
	
			local magnitude = (Point - LightPos).Magnitude
			local unit = (LightPos - Point).Unit

			local p = Point:Lerp(LightPos, 0.5)
			local cf = CFrame.lookAt(p, p + unit)
			local size = Vector3.new(1, 1, magnitude)

			local Det = workspace:GetPartBoundsInBox(CFrame.new(Point), Vector3.new(1, 1, 1) / 10)[1]
			local OVP = OverlapParams.new()
			OVP.FilterType = Enum.RaycastFilterType.Exclude
			OVP.FilterDescendantsInstances = {Det, LightParent}

			local obfuscated = if Light.Shadows then CheckObfuscated(workspace:GetPartBoundsInBox(cf, size, OVP)) else {}

			if #obfuscated > 0 then continue end

			if Light:IsA("PointLight") then
				local InRadius = PointLight(LightPos, Point, Light.Range)

				if InRadius then
					table.insert(Detected.Lights, Light)
					Detected.LightLevel = math.min((Detected.LightLevel + (range - magnitude) * (1 + Brightness / magnitude)) * 2, 15)
				end
			end

			if Light:IsA("SpotLight") then
				local dir = GetVectorFromNormal(LightParent, Light.Face)
				local InCone = SpotLight(LightPos, dir, Point, Light.Angle, range)

				if InCone and magnitude < range - range / 12 then
					table.insert(Detected.Lights, Light)
					Detected.LightLevel = math.min((Detected.LightLevel + (range - magnitude) * (1 + Brightness / magnitude)) * 2, 15)
				end
			end

			if Light:IsA("SurfaceLight") then
				local dir = CFrame.lookAt(LightPos, LightPos + GetVectorFromNormal(LightParent, Light.Face))

				if LightParent:IsA("BasePart") then
					local ParentSize = LightParent.Size / 2
					dir *= CFrame.new(0, 0, -ParentSize.Z)
	
					local deg = Light.Angle
					local ang = math.rad(deg)

					local p1 = (dir * CFrame.new(-ParentSize.X, -ParentSize.Y, 0)).Position
					local p2 = (dir * CFrame.new(ParentSize.X, -ParentSize.Y, 0)).Position

					local p3 = ((CFrame.new(p2, p2 + dir.LookVector) * CFrame.new(ang * 10, 0, -range * 1.5) * CFrame.Angles(0, -ang / 2, 0)) * CFrame.new(0, -range * ang / 2 + math.max(0, deg - 45) / 30, 0)).Position
					local p4 = ((CFrame.new(p1, p1 + dir.LookVector) * CFrame.new(-ang * 10, 0, -range * 1.5) * CFrame.Angles(0, ang / 2, 0)) * CFrame.new(0, -range * ang / 2 + math.max(0, deg - 45) / 30, 0)).Position

					local p5 = (dir * CFrame.new(-ParentSize.X, ParentSize.Y, 0)).Position
					local p6 = (dir * CFrame.new(ParentSize.X, ParentSize.Y, 0)).Position

					local p7 = ((CFrame.new(p6, p6 + dir.LookVector) * CFrame.new(ang * 10, 0, -range * 1.5) * CFrame.Angles(0, -ang / 2, 0)) * CFrame.new(0, range * ang / 2 + math.max(0, deg - 45) / 30, 0)).Position
					local p8 = ((CFrame.new(p5, p5 + dir.LookVector) * CFrame.new(-ang * 10, 0, -range * 1.5) * CFrame.Angles(0, ang / 2, 0)) * CFrame.new(0, range * ang / 2 + math.max(0, deg - 45) / 30, 0)).Position

					local InsideCube = SurfaceLight(p1, p2, p3, p4, p5, p6, p7, p8, Point)

					if InsideCube and magnitude < range * 1.1 then
						table.insert(Detected.Lights, Light)
						Detected.LightLevel = math.min((Detected.LightLevel + (range - magnitude) * (1 + Brightness / magnitude)) * 2, 15)
					end
				else
					local dir = GetVectorFromNormal(LightParent, Light.Face)
					local InCone = SpotLight(LightPos, dir, Point, Light.Angle, range)

					if InCone and magnitude < range - range / 5 then
						table.insert(Detected.Lights, Light)
						Detected.LightLevel = math.min((Detected.LightLevel + (range - magnitude) * (1 + Brightness / magnitude)) * 2, 15)
					end
				end
			end
		else
			table.remove(AllLights, table.find(AllLights, Light))
			Detected.LightLevel = 0
		end
	end

	Detected.InLight = #Detected.Lights > 0 or Detected.Sunlight

	return Detected
end

return module
