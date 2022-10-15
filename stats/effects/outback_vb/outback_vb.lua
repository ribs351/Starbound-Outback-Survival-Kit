function init()
  animator.setParticleEmitterOffsetRegion("energy", mcontroller.boundBox())
  animator.setParticleEmitterEmissionRate("energy", config.getParameter("emissionRate", 25))
  animator.setParticleEmitterActive("energy", true)

  effect.addStatModifierGroup({
      {stat = "energyRegenPercentageRate", amount = config.getParameter("regenBonusAmount", 15)},
      {stat = "energyRegenBlockTime", effectiveMultiplier = 0},
	  {stat = "outback_fostersImmunity", amount = 1}
    })
end

function update(dt)

end

function uninit()

end
