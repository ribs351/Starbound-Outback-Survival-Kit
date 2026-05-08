require "/scripts/util.lua"
require "/items/active/weapons/weapon.lua"

BayonetJab = WeaponAbility:new()

function BayonetJab:init()
  self.cooldownTimer = self.cooldownTime

  -- Hold phase config
  self.maxHoldTime = config.getParameter("maxHoldTime", 1.5)
  self.readyLerpTime = config.getParameter("readyLerpTime", 0.15)

  -- Energy config
  self.minEnergyUsage = config.getParameter("minEnergyUsage", 10)
  self.maxEnergyUsage = config.getParameter("maxEnergyUsage", 40)

  -- Damage config
  self.minDamage = config.getParameter("minDamage", 5)
  self.maxDamage = config.getParameter("maxDamage", 20)

  -- Fire/lunge config
  self.minFireDuration = config.getParameter("minFireDuration", 0.2)
  self.maxFireDuration = config.getParameter("maxFireDuration", 1.5)
  self.lungeSpeed = config.getParameter("lungeSpeed", 60)
  self.chargeDirectives = config.getParameter("chargeDirectives", "")

  self.chargeReady = false

  self:reset()

  self.weapon:setStance(self.stances.idle)
  self.weapon.onLeaveAbility = function()
    self.weapon:setStance(self.stances.idle)
  end
end

function BayonetJab:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - dt)

  if self.weapon.currentAbility == nil
    and self.cooldownTimer == 0
    and not status.resourceLocked("energy")
    and self.fireMode == "alt" then

    self:setState(self.charge)
  end
end

function BayonetJab:charge()
  local readyStance = self.stances.ready
  local idleStance = self.stances.idle
  local lerpTimer = 0

  self.weapon:updateAim()

  while lerpTimer < self.readyLerpTime do
    lerpTimer = math.min(self.readyLerpTime, lerpTimer + self.dt)
    local t = lerpTimer / self.readyLerpTime

    self.weapon.relativeArmRotation = util.toRadians(util.interpolateSigmoid(t, idleStance.armRotation, readyStance.armRotation))
    self.weapon.relativeWeaponRotation = util.toRadians(util.interpolateSigmoid(t, idleStance.weaponRotation, readyStance.weaponRotation))
    coroutine.yield()
  end

  self.weapon:setStance(readyStance)

  local holdTimer = 0
  local forceFire = false

  while self.fireMode == "alt" and not forceFire do
    self.weapon:updateAim()

    holdTimer = math.min(self.maxHoldTime, holdTimer + self.dt)

    local chargeRatio = holdTimer / self.maxHoldTime
    if holdTimer < self.maxHoldTime then
        local energyPerSecond = self.minEnergyUsage + (self.maxEnergyUsage - self.minEnergyUsage) * chargeRatio
        status.setResourcePercentage("energyRegenBlock", 1)
        if not status.overConsumeResource("energy", energyPerSecond * self.dt) then
            forceFire = true
    end
    else
        status.setResourcePercentage("energyRegenBlock", 1)
    end

    if holdTimer >= self.maxHoldTime and not self.chargeReady then
        self.chargeReady = true
        animator.setGlobalTag("directives", self.chargeDirectives)
        animator.playSound("charged")
    end
    coroutine.yield()
  end

  -- Fire with whatever charge was accumulated
  self:setState(self.swing, holdTimer)
end

function BayonetJab:swing(holdTimer)
  self.chargeReady = false
  animator.setGlobalTag("directives", "")
  local chargeRatio = math.min(1.0, holdTimer / self.maxHoldTime)

  local damage = self.minDamage + (self.maxDamage - self.minDamage) * chargeRatio
  local fireDuration = math.max(self.minFireDuration, chargeRatio * self.maxFireDuration)

  local scaledDamageConfig = copy(self.damageConfig)
  scaledDamageConfig.baseDamage = damage

  -- Full charge triggers lunge
  if holdTimer >= self.maxHoldTime then
  local lungeVector = vec2.rotate({self.lungeSpeed, 0}, self.weapon.aimAngle)
  lungeVector[1] = lungeVector[1] * mcontroller.facingDirection()
  -- Add upward boost if on ground so the player clears the surface before lunging
  if mcontroller.onGround() then
    lungeVector[2] = lungeVector[2] + config.getParameter("lungeUpwardBoost", 10)
  end
  mcontroller.setVelocity(lungeVector)
  status.setPersistentEffects("bayonetLunge", {{stat = "activeMovementAbilities", amount = 1}})
end

  self.weapon:setStance(self.stances.swing)
  self.weapon:updateAim()

  animator.setAnimationState("swoosh", "fire")
  animator.playSound("flurry")

  util.wait(self.stances.swing.duration, function()
    local damageArea = partDamageArea("swoosh")
    self.weapon:setDamage(scaledDamageConfig, damageArea)
  end)

  status.clearPersistentEffects("bayonetLunge")

  self.weapon:setStance(self.stances.idle)
  self.cooldownTimer = self.cooldownTime
end

function BayonetJab:reset()
  status.clearPersistentEffects("bayonetLunge")
end

function BayonetJab:uninit()
  self:reset()
  self.weapon:setStance(self.stances.idle)
end