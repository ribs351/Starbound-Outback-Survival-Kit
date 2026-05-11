require "/scripts/util.lua"
require "/items/active/weapons/weapon.lua"

TrailDash = WeaponAbility:new()

function TrailDash:init()
  self.cooldownTimer = self.cooldownTime
end

function TrailDash:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)

  if self.weapon.currentAbility == nil 
     and self.fireMode == "alt"
     and mcontroller.onGround()
     and self.cooldownTimer == 0
     and not status.statPositive("activeMovementAbilities")
     and status.overConsumeResource("energy", self.energyUsage) then

    self:setState(self.windup)
  end
end

function TrailDash:windup()
  local windupStance = self.stances.windup

  local fromArmRotation = math.deg(self.weapon.relativeArmRotation)
  local fromWeaponRotation = math.deg(self.weapon.relativeWeaponRotation)
  local fromWeaponOffset = copy(self.weapon.weaponOffset)

  local lerpTime = 0.4
  local lerpTimer = 0

  status.setPersistentEffects("weaponMovementAbility", {{stat = "activeMovementAbilities", amount = 1}})
  animator.setParticleEmitterActive(self.weapon.elementalType.."SwordCharge", true)
  animator.playSound(self.weapon.elementalType.."TrailDashCharge")

  while lerpTimer < lerpTime do
    lerpTimer = math.min(lerpTime, lerpTimer + self.dt)
    local t = lerpTimer / lerpTime
    self.weapon.relativeArmRotation = util.toRadians(util.interpolateSigmoid(t, fromArmRotation, windupStance.armRotation))
    self.weapon.relativeWeaponRotation = util.toRadians(util.interpolateSigmoid(t, fromWeaponRotation, windupStance.weaponRotation))
    coroutine.yield()
  end

  self.weapon:setStance(windupStance)
  util.wait(math.max(0, windupStance.duration - lerpTime), function(dt)
    mcontroller.controlModifiers({jumpingSuppressed = true})
  end)

  self:setState(self.dash)
end

function TrailDash:dash()
  self.weapon:setStance(self.stances.dash)

  animator.playSound(self.weapon.elementalType.."TrailDashFire")

  local wasInvulnerable = status.stat("invulnerable") > 0
  status.addEphemeralEffect("invulnerable", self.dashTime)

  local position = mcontroller.position()
  local params = copy(self.projectileParameters)
  params.powerMultiplier = activeItem.ownerPowerMultiplier()
  params.power = params.power * config.getParameter("damageLevelMultiplier")

  util.wait(self.dashTime, function(dt)
    if not wasInvulnerable then status.removeEphemeralEffect("invulnerable") end
      

    mcontroller.setVelocity({self.weapon.aimDirection * self.dashSpeed, -200})
    mcontroller.controlMove(self.weapon.aimDirection)

    local direction = vec2.norm(world.distance(mcontroller.position(), position))
    while world.magnitude(mcontroller.position(), position) >= self.trailInterval do
      position = vec2.add(position, vec2.mul(direction, self.trailInterval))
      world.spawnProjectile(self.projectileType, vec2.add(position, self.projectileOffset), activeItem.ownerEntityId(), {-mcontroller.facingDirection(),0}, false, params)
    end

    local damageArea = partDamageArea("blade")
    self.weapon:setDamage(self.damageConfig, damageArea)
  end)
  animator.setParticleEmitterActive(self.weapon.elementalType.."SwordCharge", false)

  mcontroller.setVelocity({0,0})
end

function TrailDash:uninit()
  status.clearPersistentEffects("weaponMovementAbility")

  animator.setParticleEmitterActive(self.weapon.elementalType.."SwordCharge", false)

  if self.weapon.currentState == self.dash then
    mcontroller.setVelocity({0,0})
  end
end
