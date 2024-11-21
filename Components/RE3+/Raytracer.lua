--!native

local Raytrace = {}

function Raytrace.BaseCast(MaxBounces, Origin, Direction)
	local Traces = {}

	local Dat = {
		Position = Origin,
		Orientation = Direction,
		Enabled = true,
	}

	for Bounces = 1, MaxBounces do
		if Dat.Enabled == true then
			local Trace = workspace:Raycast(Dat.Position,Dat.Orientation, RaycastParams.new())
			if Trace == nil then Dat.Enabled = false else
				local prepos = Dat.Position
				Dat.Orientation = (Dat.Orientation - (2 * Dat.Orientation:Dot(Trace.Normal) * Trace.Normal)) --Reflection
				Dat.Position = Trace.Position --Hit origin
				local dist = (Dat.Position - prepos).Magnitude
				table.insert(Traces, {Pos = Trace.Position, Col = Trace.Instance.Color, Ins = Trace.Instance, Nor = Trace.Normal, Mat = Trace.Material, Num = Bounces, Dis = dist})
			end
		end
	end
	
	return Traces
end

return Raytrace