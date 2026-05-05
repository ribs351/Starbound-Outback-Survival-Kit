-- NOTE: This alt ability manages its own idle stance via onLeaveAbility.
-- If adapting this script for other weapons, ensure the stances table includes
-- an "idle" stance, otherwise the weapon will break.
-- The primary ability's idle stance is NOT used here by design.

ThrowSpear = WeaponAbility:new()

function ThrowSpear:init()
	self:reset()
	
	self.cooldownTimer = self.fireTime
	self.minWindupTime = self.minWindupTime or self.windupTime
	
	self.projectileCfg = root.projectileConfig(self.projectileType)
	self.projectileGrav = root.projectileGravityMultiplier(self.projectileType)
	
	if not self.weapon.currentAbility then
        self.weapon:setStance(self.stances.idle)
    end
	
	self.weapon.onLeaveAbility = function()
		self.weapon:setStance(self.stances.idle)
	end
end

function ThrowSpear:update(dt, fireMode, shiftHeld)
	WeaponAbility.update(self, dt, fireMode, shiftHeld)
	
	self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)
	
	if self.fireMode == (self.activatingFireMode or self.abilitySlot)
	and not self.weapon.currentAbility
	and self.cooldownTimer == 0
	and (self.energyUsage == 0 or not status.resourceLocked("energy")) then
		self:setState(self.windup)
	end
end

function ThrowSpear:windup()
	local stance = self.stances.windup
	self.weapon:setStance(stance)
	self.weapon:updateAim()
	
	local timer = 0
	animator.playSound("windup")
	
	local newStance = {}
	local stanceDoned = false
	local ready = false
	
	while self.fireMode == (self.activatingFireMode or self.abilitySlot) and (not self.autoThrow or timer < self.minWindupTime) do
		timer = math.min(self.windupTime, timer + self.dt)
		if not ready and timer >= self.minWindupTime then
			ready = true
			animator.setGlobalTag("readyDirectives", self.readyDirectives or "")
			animator.setParticleEmitterActive("ready", false)
			animator.playSound("ready")
		end
		
		if self.lockEnergy then
			status.setResourcePercentage("energyRegenBlock", 1)
		end
		if self.forceWalk then
			mcontroller.controlModifiers({runningSuppressed=true})
		end
		
		local r = timer / self.windupTime
		
		if not stanceDoned then
			if timer >= self.windupTime then stanceDoned = true end
			newStance = self:interpStance(r, stance, stance.to)
		end
		
		coroutine.yield()
	end
	newStance = sb.jsonMerge(stance, newStance)
	
	self:reset()
	
	if ready and (self.energyUsage == 0 or status.overConsumeResource("energy", self.energyUsage)) then
		self:setState(self.throw, newStance)
	end
end

function ThrowSpear:throw(stanceFrom)
	local stance = self.stances.throw
	self.weapon:setStance(stance)
	self.weapon:updateAim()
	
	animator.setAnimationState("throw", "thrown")
	animator.burstParticleEmitter("throw")
	animator.playSound("throw")
	
  local params = copy(self.projectileParameters)
  params.power = self.baseDamage * config.getParameter("damageLevelMultiplier")
  params.powerMultiplier = activeItem.ownerPowerMultiplier()
	
	if self.projectileFlips and mcontroller.facingDirection() == -1 then
		params.processing = (params.processing or "").."?flipy"
	end
	
	world.spawnProjectile(self.projectileType, self:firePosition(), activeItem.ownerEntityId(), self:aimVector(), false, params)
	
	if self.throwTime and self.throwTime > 0 then
		self:stanceThing(stanceFrom, stance, self.throwTime)
	end
	self:stanceThing(stance, "idle", self.winddownTime)
	
	self.cooldownTimer = self.fireTime
	animator.setAnimationState("throw", "respawn")
end


function ThrowSpear:aimVector()
	if self.aimForCursor and world.gravity(mcontroller.position()) ~= 0 then
		local pos = world.distance(activeItem.ownerAimPosition(), self:firePosition())
		return util.aimVector(pos, self.projectileParameters.speed or self.projectileCfg.speed, self.projectileGrav, false)
	else
		local aimVector = vec2.rotate({0, 1}, self.weapon.aimAngle + self.weapon.relativeArmRotation + self.weapon.relativeWeaponRotation)
		aimVector[1] = aimVector[1] * mcontroller.facingDirection()
		return aimVector
	end
end

function ThrowSpear:firePosition()
	local r = vec2.rotate(self.projectileOffset or {0,0}, self.weapon.relativeWeaponRotation)
	return vec2.add(mcontroller.position(), activeItem.handPosition(r))
end

function ThrowSpear:stanceThing(stanceFrom, stanceTo, duration)
	if type(stanceFrom) == "string" then stanceFrom = self.stances[stanceFrom] end
	if type(stanceTo) == "string" then stanceTo = self.stances[stanceTo] end
	
	duration = duration or stanceFrom.duration
	if duration and duration > 0 then
		local progress = 0
		util.wait(duration, function()
			progress = math.min(1, progress + self.dt / duration)
			self:interpStance(progress, stanceFrom, stanceTo)
		end)
	end
end

function ThrowSpear:interpStance(r, a, b, f)
	local f = f or util.interpolateSigmoid
	local n = {
		armRotation = f(r, a.armRotation, b.armRotation),
		weaponRotation = f(r, a.weaponRotation, b.weaponRotation),
		weaponOffset = {f(r, a.weaponOffset[1] or 0, b.weaponOffset[1] or 0), f(r, a.weaponOffset[2] or 0, b.weaponOffset[2] or 0)}
	}
	self.weapon.relativeArmRotation = util.toRadians(n.armRotation)
	self.weapon.relativeWeaponRotation = util.toRadians(n.weaponRotation)
	self.weapon.weaponOffset = n.weaponOffset
	return n
end

function ThrowSpear:uninit() end

function ThrowSpear:reset()
	animator.setAnimationState("throw", "idle")
	animator.setGlobalTag("readyDirectives", "")
	animator.setParticleEmitterActive("ready", false)
end
