function init()
	max = effect.getParameter("maxPowerMultiplier", 3)
	min = effect.getParameter("minPowerMultiplier", 0.75)
	maxSpeed = effect.getParameter("maxSpeedModifier", 1.75)
	minSpeed = effect.getParameter("minSpeedModifier", 0.85)
	groupId = effect.addStatModifierGroup({})

	baseRunSpeed = 14
	baseWalkSpeed = 8
end

function update(dt)
	local health = status.resourcePercentage("health")
	local powerMul = max + (min - max) * health
	local speedMul = maxSpeed + (minSpeed - maxSpeed) * health

	effect.setStatModifierGroup(groupId, {{stat = "powerMultiplier", effectiveMultiplier = powerMul}})

	mcontroller.controlParameters({
		runSpeed = baseRunSpeed * speedMul
	})
end