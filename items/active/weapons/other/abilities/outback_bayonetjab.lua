require "/scripts/util.lua"
require "/scripts/vec2.lua"

BayonetJab = WeaponAbility:new()

function BayonetJab:init()
  self.cooldownTimer = self.cooldownTime
  self.chargeReady = false

  self.flashTimer = 0
  self:reset()
end

function BayonetJab:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - dt)

  if self.flashTimer > 0 then
    self.flashTimer = math.max(0, self.flashTimer - dt)
    if self.flashTimer == 0 then
      animator.setGlobalTag("directives", "")
    end
  end

  if self.weapon.currentAbility == nil
      and self.cooldownTimer == 0
      and self.fireMode == "alt"
      and not status.resourceLocked("energy") then
    self:setState(self.charge)
  end
end

function BayonetJab:charge()
  local windupStance = self.stances.windup
  local readyStance = self.stances.ready
  local lerpTimer = 0

  self.weapon:setStance(windupStance)
  self.weapon:updateAim()

  while lerpTimer < self.readyLerpTime do
    lerpTimer = math.min(self.readyLerpTime, lerpTimer + self.dt)
    local t = lerpTimer / self.readyLerpTime

    self.weapon.relativeArmRotation = util.toRadians(util.interpolateSigmoid(t, windupStance.armRotation, readyStance.armRotation))
    self.weapon.relativeWeaponRotation = util.toRadians(util.interpolateSigmoid(t, windupStance.weaponRotation, readyStance.weaponRotation))
    self.weapon.weaponOffset = {
      util.interpolateSigmoid(t, windupStance.weaponOffset[1], readyStance.weaponOffset[1]),
      util.interpolateSigmoid(t, windupStance.weaponOffset[2], readyStance.weaponOffset[2])
    }
    coroutine.yield()
  end

  self.weapon:setStance(readyStance)

  local holdTimer = 0
  local forceFire = false

  while self.fireMode == "alt" and not forceFire do
    self.weapon:updateAim()

    holdTimer = math.min(self.maxHoldTime, holdTimer + self.dt)

    status.setResourcePercentage("energyRegenBlock", 1)
    local chargeRatio = holdTimer / self.maxHoldTime
    if holdTimer < self.maxHoldTime then
      local energyPerSecond = self.minEnergyUsage + (self.maxEnergyUsage - self.minEnergyUsage) * chargeRatio
      if not status.overConsumeResource("energy", energyPerSecond * self.dt) then
        forceFire = true
      end
    end

    if holdTimer >= self.maxHoldTime and not self.chargeReady then
      self.chargeReady = true
      self:readyFlash()
      animator.playSound("charged")
    end
    if self.chargeReady then
      activeItem.emote("annoyed")
      status.addEphemeralEffect("rage", 0.1)
    end
    coroutine.yield()
  end

  -- Fire with whatever charge was accumulated
  self:setState(self.swing, holdTimer)
end

function BayonetJab:swing(holdTimer)
  self.chargeReady = false
  local chargeRatio = math.min(1.0, holdTimer / self.maxHoldTime)

  local damage = self.minDamage + (self.maxDamage - self.minDamage) * chargeRatio
  local fireDuration = math.max(self.minFireDuration, chargeRatio * self.maxFireDuration)

  local scaledDamageConfig = copy(self.damageConfig)
  scaledDamageConfig.baseDamage = damage

  -- Full charge triggers lunge, doesn't work in zero gravity
  if holdTimer >= self.maxHoldTime and math.abs(world.gravity(mcontroller.position())) > 0 then
    local lungeVector = vec2.rotate({self.lungeSpeed, 0}, self.weapon.aimAngle)
    lungeVector[1] = lungeVector[1] * mcontroller.facingDirection()
    if mcontroller.onGround() then
      lungeVector[2] = lungeVector[2] + config.getParameter("lungeUpwardBoost", 10)
    end
    mcontroller.setVelocity(lungeVector)
    status.setPersistentEffects("outback_bayonetLunge", {{stat = "activeMovementAbilities", amount = 1}})
  end

  self.weapon:setStance(self.stances.swing)
  self.weapon:updateAim()

  animator.burstParticleEmitter((self.elementalType or self.weapon.elementalType) .. "swoosh")
  animator.setAnimationState("swoosh", "fire")
  animator.playSound("jab")

  util.wait(self.stances.swing.duration, function()
    local damageArea = partDamageArea("swoosh")
    self.weapon:setDamage(scaledDamageConfig, damageArea)
  end)

  self:reset()

  self.weapon:setStance(self.stances.idle)
  self.cooldownTimer = self.cooldownTime
end

function BayonetJab:readyFlash()
  animator.setGlobalTag("directives", self.chargedDirectives or "")
  self.flashTimer = self.flashTime or 0.25
end

function BayonetJab:reset()
  status.clearPersistentEffects("outback_bayonetLunge")
end

function BayonetJab:uninit()
  self:reset()
  self.weapon:setStance(self.stances.idle)
end
