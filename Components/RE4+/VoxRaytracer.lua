local Vagabond = {VRay = {}, Trace = {}}

--
-- Realtime Voxel Raytracer
--

function RoundV3(V3, Step)
	return Vector3.new(math.round(V3.X/Step)*Step,math.round(V3.Y/Step)*Step,math.round(V3.Z/Step)*Step)
end

function Vagabond.VRay.New(Direction, Origin, Distance, voxelScale)
	local resultTable = {}

	local delta = Direction.unit * Distance
	local longestAxis = math.max(math.abs(delta.x), math.abs(delta.y), math.abs(delta.z))

	local step = delta / longestAxis
	step = step * voxelScale

	local currentPos = Origin
	for _ = 1, longestAxis / voxelScale do
		table.insert(resultTable, RoundV3(currentPos, voxelScale))
		currentPos = currentPos + step
	end

	return resultTable
end

function Vagabond.Trace.Cast(Direction, Origin, Distance, Resolution, Overlap)
	local resultTable = {}
	
	Direction = Direction.unit
	local Cast = Vagabond.VRay.New(Direction, Origin, Distance, Resolution)
	
	--resultTable.Mat = Enum.Material.Plastic
	--resultTable.Col = Color3.new()
	--resultTable.Pos = Vector3.new()
	--resultTable.Ins = nil
	--resultTable.Nor = Vector3.new()
	
	for i = 1, #Cast do
		
		Overlap.MaxParts = 1
		local BoundA = workspace:GetPartBoundsInBox(CFrame.new(Cast[i]), Vector3.one*Resolution, Overlap)
		
		if #BoundA > 0 then
			Overlap.MaxParts = 5
			
			local boundB = workspace:GetPartBoundsInBox(CFrame.new(Cast[i]), Vector3.one*Resolution, Overlap)
			for i2,v2 in pairs(boundB) do
				resultTable.Col = v2.Color
				resultTable.Mat = v2.Material
				resultTable.Ins = v2
				resultTable.Nor = v2.CFrame:vectorToWorldSpace(Vector3.new(0, 0, -1)).Unit
				resultTable.Pos = Cast[i]
				resultTable.Voxels = {}
				table.move(Cast, 1, i, 1, resultTable.Voxels)
			end
			
			return resultTable
		end
		
	end
	
	return nil
end

function Vagabond.Trace.Bounced(Direction, Origin, Distance, Resolution, Bounces)
	local Traces = {}

	local Dat = {
		Position = Origin,
		Orientation = Direction,
		Enabled = true,
		Overlap = OverlapParams.new(),
	}
	Dat.Overlap.FilterType = Enum.RaycastFilterType.Exclude

	for BounceCount = 1, Bounces do
		if Dat.Enabled == true then
			local Trace = Vagabond.Trace.Cast(Dat.Orientation, Dat.Position, Distance, Resolution, Dat.Overlap)
			if Trace == nil then Dat.Enabled = false else
				local prepos = Dat.Position
				Dat.Overlap.FilterDescendantsInstances = {Trace.Ins}
				Dat.Orientation = (Dat.Orientation - (2 * Dat.Orientation:Dot(Trace.Nor) * Trace.Nor)) --Reflection
				Dat.Position = Trace.Pos + Trace.Nor * 0.2 --Hit origin
				local dist = (Dat.Position - prepos).Magnitude
				table.insert(Traces, {Pos = Trace.Pos, Col = Trace.Col, Ins = Trace.Ins, Nor = Trace.Nor, Mat = Trace.Mat, Num = BounceCount, Dis = dist, Voxels = Trace.Voxels})
			end
		end
	end

	return Traces
end

return Vagabond