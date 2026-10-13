local Config = require(game.ReplicatedStorage.ZeroWheelConfig)
local Rules = {}
function Rules.new(now)
	return {Coins=0, Spins=Config.InitialSpins, NextFreeAt=now+Config.FreeInterval, LastSpinAt=0}
end
function Rules.available(data, now)
	return data.Spins + (now >= data.NextFreeAt and 1 or 0)
end
function Rules.pick(roll)
	local total = 0
	for index, reward in ipairs(Config.Rewards) do
		total += reward.Weight
		if roll < total then return index end
	end
	return #Config.Rewards
end
function Rules.spin(previous, now, index, token)
	local data = table.clone(previous or Rules.new(now))
	if data.LastToken == token then return data end
	if now < data.LastSpinAt + Config.SpinCooldown then return nil, "Espera a que termine el giro." end
	if data.Spins > 0 then
		data.Spins -= 1
	elseif now >= data.NextFreeAt then
		data.NextFreeAt = now + Config.FreeInterval
	else
		return nil, "Tu próximo giro gratis aún no está listo."
	end
	data.Coins += Config.Rewards[index].Coins or 0
	data.LastSpinAt = now
	data.LastToken = token
	data.LastReward = index
	return data
end
return Rules
