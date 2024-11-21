--!native

local Resim = {}

--
--This copy of AMBX is built for use with vagabond, it doesnt (Directly) support radian.
--
--It is also valid to note while the ligthing data provided by AMBX is relatively high quality
--It does not support shadows for pointlights, and it assumes all custom lights (including spot/surface lights)
--Are pointlights. Basically its a super simplistic model which makes it faster than the old AMBI system.
--


--local Vagabond = require(script.Parent.Raytrace)
local Lighting = game:GetService("Lighting")
local Config

function Calc()
	Config = {ScanDistance = 128, AMBX = {SkylightBrightness = 0.4}}
end

function NormalizeC3(Color)
	--Normalizes the brightness of a color3 value so only hue and saturation are factored into the output
	local Lum = math.clamp(0.5/((0.299 * Color.r) + (0.587 * Color.g) + (0.114 * Color.b)), 1, 2) --Funky math that works somehow.
	return Color3.new(math.clamp(Color.R*Lum, 0, 1), math.clamp(Color.G*Lum, 0, 1), math.clamp(Color.B*Lum, 0, 1))
end

function CalculateLightIntensity(lightIntensity, distance) Calc()
	-- Apply the inverse square law
	return lightIntensity / (distance^2)
end

function CalculateSkylight(Position) Calc()
	-- A very simple skylight calculation
	local cast = workspace:Raycast(Position, Vector3.yAxis*40, RaycastParams.new())
	
	if cast == nil then
		return ((Lighting.Ambient.R+Lighting.Ambient.G+Lighting.Ambient.B)/3)*0.25	else
		return 0
	end
end

function CalculateSunlight(Position) Calc()
	local Sunlightdir = Lighting:GetSunDirection()
	--local lookdir = Position + Sunlightdir
	local lookat = CFrame.lookAt(Position, Position + Sunlightdir)

	local cast = workspace:Raycast(Position, lookat.LookVector*400, RaycastParams.new())
	
	if game.Lighting.ClockTime < 6.5 or game.Lighting.ClockTime > 18 then
		cast = 0
	end

	if cast == nil then
		return Lighting.Brightness
	else
		return 0
	end
end

function CalculateMoonlight(Position) Calc()
	local Moonlightdir = Lighting:GetMoonDirection()
	--local lookdir = Position + Sunlightdir
	local lookat = CFrame.lookAt(Position, Position + Moonlightdir)

	local cast = workspace:Raycast(Position, lookat.LookVector*400, RaycastParams.new())

	if cast == nil then
		return Lighting.Brightness*0.1
	else
		return 0
	end
end

function Resim.CreateLightmap() Calc()
	local obj = {}
	
	obj.RawEmitters = {}
	obj.Exclude = {}
	
	local function blacklisted(dec)
		
		for i,exdec in pairs(obj.Exclude) do
			if dec:IsDescendantOf(exdec) == true then
				return true
			end
		end
		
		return false
	end
	
	local function ProcessDescendantToEmitters(dec) Calc()
		if dec.ClassName == "PointLight" or dec.ClassName == "SpotLight" or dec.ClassName == "SurfaceLight" then 
			if dec.Parent.ClassName == "Part" or dec.Parent.ClassName == "Attachment" then
				local Entry = {Power = dec.Range*dec.Brightness, Position = dec.Parent.CFrame.Position, Color = dec.Color, Object = dec}
				table.insert(obj.RawEmitters, Entry)

				dec.Destroying:Connect(function() 
					table.remove(obj.RawEmitters, table.find(obj.RawEmitters, Entry)) 
				end)

				dec.Changed:Connect(function() 
					table.remove(obj.RawEmitters, table.find(obj.RawEmitters, Entry)) 
					Entry = {Power = dec.Range*dec.Brightness, Position = dec.Parent.CFrame.Position, Color = dec.Color, Object = dec}
					table.insert(obj.RawEmitters, Entry) 
				end)
			end 
		end
	end
	
	--PreProcess all objects into light map then add any new objects
	for i,v in pairs(workspace:GetDescendants()) do ProcessDescendantToEmitters(v) end
	workspace.DescendantAdded:Connect(function(dec) ProcessDescendantToEmitters(dec) end)
	
	function obj.GetSkylight(Position) Calc()
		local brightness = 0
		local color = Color3.new(0,0,0)

		local SkyLightContribution = CalculateSkylight(Position)
		local Normalized = NormalizeC3(Lighting.OutdoorAmbient)
		color = Color3.new(0,0,0):Lerp(Color3.new(
			math.clamp(Normalized.R+color.R, 0,1),
			math.clamp(Normalized.G+color.G, 0,1),
			math.clamp(Normalized.B+color.B, 0,1)
		), SkyLightContribution)

		return color, brightness
	end

	function obj.GetSunlight(Position) Calc()
		local brightness = 0
		local color = Color3.new(0,0,0)
		
		local SunlightContribution = CalculateSunlight(Position)
		brightness += SunlightContribution
		color = color:Lerp(Color3.new(1,1,1), SunlightContribution)

		return color, brightness
	end

	function obj.GetMoonlight(Position) Calc()
		local brightness = 0
		local color = Color3.new(0,0,0)

		local MoonlightContribution = CalculateMoonlight(Position)
		brightness += MoonlightContribution
		color = color:Lerp(Color3.new(1,1,1), MoonlightContribution)

		return color, brightness
	end
	
	function obj.GetPointLight(Position) Calc()
		local brightness = 0
		local color = Color3.new(0,0,0)

		for i,v in pairs(obj.RawEmitters) do 
			if blacklisted(v.Object) == false then
				local Emitterbrightness = CalculateLightIntensity(v.Power, (v.Position - Position).Magnitude) 
				local EmitterColor = Color3.new(0,0,0):Lerp(v.Color, math.clamp(Emitterbrightness,0,1))
				brightness += Emitterbrightness
				color =	color:Lerp(EmitterColor, Emitterbrightness)
			end
		end

		return color, brightness
	end
	
	function obj.GetFull(Position) Calc()
		local brightness = 0
		local color = Lighting.Ambient

		--Skylight
		local SkyLightCol, SkylightBright = obj.GetSkylight(Position)

		--Sunlight
		local SunlightCol, SunlightBright = obj.GetSunlight(Position)

		--Moonlight
		local MoonlightCol, MoonlightBright = obj.GetMoonlight(Position)

		--Pointlight
		local PointLightCol, PointLightBright = obj.GetPointLight(Position)
		
		--Merge in order
		color = color:Lerp(SunlightCol, SunlightBright)
		color = color:Lerp(MoonlightCol, MoonlightBright)
		color = color:Lerp(SkyLightCol, SkylightBright)
		color = color:Lerp(PointLightCol, PointLightBright)
		brightness = (SunlightBright + MoonlightBright + SkylightBright + PointLightBright)/4

		return color, brightness
	end
	
	return obj
end

return Resim