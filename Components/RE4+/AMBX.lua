local AMBX = {}

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

function AMBX.CreateLightmap() Calc()
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
				if blacklisted(dec) == false then
					
					local Entry = {Power = dec.Range*dec.Brightness, Position = dec.Parent.CFrame.Position, Color = dec.Color}
					table.insert(obj.RawEmitters, Entry)

					dec.Destroying:Connect(function() 
						table.remove(obj.RawEmitters, table.find(obj.RawEmitters, Entry)) 
					end)

					dec.Changed:Connect(function() 
						table.remove(obj.RawEmitters, table.find(obj.RawEmitters, Entry)) 
						Entry = {Power = dec.Range*dec.Brightness, Position = dec.Parent.CFrame.Position, Color = dec.Color}
						table.insert(obj.RawEmitters, Entry) 
					end)
						
				end
			end 
		end
	end
	
	--PreProcess all objects into light map then add all new objects
	for i,v in pairs(workspace:GetDescendants()) do ProcessDescendantToEmitters(v) end
	workspace.DescendantAdded:Connect(function(dec) ProcessDescendantToEmitters(dec) end)
	
	function obj.CompileToPos(Position) Calc()
		local brightness = 0
		local color = Lighting.Ambient
		
		--brightness += CalculateSkylight(Position, res*16)
		--Skylight
		local SkyLightContribution = CalculateSkylight(Position)
		local Normalized = NormalizeC3(Lighting.OutdoorAmbient)
		color = Color3.new(0,0,0):Lerp(Color3.new(
			math.clamp(Normalized.R+color.R, 0,1),
			math.clamp(Normalized.G+color.G, 0,1),
			math.clamp(Normalized.B+color.B, 0,1)
		), SkyLightContribution)
		
		--Sunlight
		local SunlightContribution = CalculateSunlight(Position)
		brightness += SunlightContribution
		color = color:Lerp(Color3.new(1,1,1), SunlightContribution)
		
		--Moonlight
		local MoonlightContribution = CalculateMoonlight(Position)
		brightness += MoonlightContribution
		color = color:Lerp(Color3.new(1,1,1), MoonlightContribution)
		
		for i,v in pairs(obj.RawEmitters) do 
			local Emitterbrightness = CalculateLightIntensity(v.Power, (v.Position - Position).Magnitude) 
			local EmitterColor = Color3.new(0, 0, 0):Lerp(v.Color, math.clamp(Emitterbrightness,0,1))
			brightness += Emitterbrightness
			color =	color:Lerp(EmitterColor, Emitterbrightness)
		end
		
		return color, brightness
	end
	
	return obj
end

return AMBX