local TycoonService = require(script.Parent.Tycoon.TycoonService)
local WeaponService = require(script.Parent.Tycoon.WeaponService)
local ZombieService = require(script.Parent.Tycoon.ZombieService)
local MonetizationService = require(script.Parent.Tycoon.MonetizationService)

MonetizationService.Initialize()
WeaponService.Initialize()
ZombieService.Initialize()
TycoonService.Initialize()
