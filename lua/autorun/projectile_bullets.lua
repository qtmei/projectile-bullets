AddCSLuaFile()

CreateConVar("bullet_speed_default", 100, {FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_NOTIFY}, "bullet speed in meters/second", 1, 1000)
CreateConVar("bullet_drop_default", 0.01, {FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_NOTIFY}, "bullet drop in meters/second", 0, 2)

if SERVER then
	if !file.Exists("data/projectile_bullets", "GAME") then
		file.CreateDir("projectile_bullets")
	end

	if !file.Exists("data/projectile_bullets/config.json", "GAME") then
		local tbl = {
			["comment"] = "this is an example. 'class' is the class name of the weapon entity. 'speed' and 'drop' are measured in meters/second",
			["class"] = {["speed"] = 100, ["drop"] = 0.01},
		}
		local json = util.TableToJSON(tbl, true)

		file.Write("projectile_bullets/config.json", json)
	end

	resource.AddFile("data/projectile_bullets/config.json")
end

local function ReadCFG(class)
	local json = file.Read("data/projectile_bullets/config.json", "GAME") or "{}"

	if CLIENT and !game.SinglePlayer() then
		json = file.Read("download/data/projectile_bullets/config.json", "GAME") or "{}"
	end

	local tbl = util.JSONToTable(json)

	return tbl[class] or {["speed"] = GetConVar("bullet_speed_default"):GetFloat(), ["drop"] = GetConVar("bullet_drop_default"):GetFloat()}
end

local bullets = {}

hook.Add("EntityFireBullets", "Projectile_Bullets_EntityFireBullets", function(ent, bulletinfo)
	bulletinfo.Inflictor = ent

	if bulletinfo.Inflictor:IsPlayer() or bulletinfo.Inflictor:IsNPC() then
		bulletinfo.Attacker = bulletinfo.Inflictor
		bulletinfo.Inflictor = bulletinfo.Inflictor:GetActiveWeapon()
	end

	if !IsValid(bulletinfo.Attacker) then
		bulletinfo.Attacker = bulletinfo.Inflictor
	end

	local ammodata_damage = game.GetAmmoPlayerDamage(game.GetAmmoID(bulletinfo.AmmoType))

	if bulletinfo.Damage == 0 and ammodata_damage > 0 then //HL2 weapons return 0
		bulletinfo.Damage = ammodata_damage
	end

	local ammodata_force = game.GetAmmoForce(game.GetAmmoID(bulletinfo.AmmoType))

	if bulletinfo.Force == 1 and ammodata_force > 1 then //HL2 weapons return 1
		bulletinfo.Force = ammodata_force
	end

	local cfg = ReadCFG(bulletinfo.Inflictor:GetClass())

	bulletinfo.Speed = cfg["speed"]
	bulletinfo.Drop = cfg["drop"]
	bulletinfo.Pos = bulletinfo.Src

	for i = 1, bulletinfo.Num, 1 do
		local bullet = table.Copy(bulletinfo)

		local offset = Vector(0, math.Rand(-bullet.Spread.x, bullet.Spread.x), math.Rand(-bullet.Spread.y, bullet.Spread.y))
		offset:Rotate(bullet.Dir:Angle())

		bullet.Dir = bullet.Dir + offset
		bullet.Vel = bullet.Dir * (bullet.Speed / 0.01905)

		table.insert(bullets, bullet)
	end

	return false
end)

hook.Add("Tick", "Projectile_Bullets_Tick", function()
	for k, bullet in pairs(bullets) do
		local trace = util.TraceLine({mask = MASK_SHOT, ignoreworld = false, filter = bullet.Attacker, start = bullet.Pos, endpos = bullet.Pos + (bullet.Vel * engine.TickInterval())})

		bullet.Pos = bullet.Pos + (bullet.Vel * engine.TickInterval())
		bullet.Vel = bullet.Vel + Vector(0, 0, -(bullet.Drop / 0.01905))

		if trace.Hit then
			if SERVER then
				local ent = trace.Entity

				if IsValid(ent) then
					local dmginfo = DamageInfo()

					dmginfo:SetDamageType(DMG_BULLET) 
					dmginfo:SetDamage(bullet.Damage)
					dmginfo:SetDamageForce(bullet.Dir * bullet.Force * GetConVar("phys_pushscale"):GetFloat())
					dmginfo:SetAttacker(bullet.Attacker)
					dmginfo:SetInflictor(bullet.Inflictor)
					dmginfo:SetReportedPosition(trace.HitPos)

					ent:TakeDamageInfo(dmginfo)
				end

				local effectdata = EffectData()

				effectdata:SetDamageType(DMG_BULLET)
				effectdata:SetEntity(trace.Entity)
				effectdata:SetOrigin(trace.HitPos)
				effectdata:SetStart(trace.StartPos)
				effectdata:SetSurfaceProp(trace.SurfaceProps)
				effectdata:SetHitBox(trace.HitBox)

				util.Effect("Impact", effectdata)
			end

			table.remove(bullets, k)
		end

		if bullet.Pos:Distance(bullet.Src) >= bullet.Distance then
			table.remove(bullets, k)
		end
	end
end)

if !CLIENT then return end

hook.Add("PostDrawOpaqueRenderables", "Projectile_Bullets_PostDrawOpaqueRenderables", function()
	for k, bullet in pairs(bullets) do
		render.SetColorMaterial()
		render.DrawBox(bullet.Pos, bullet.Dir:Angle(), Vector(0, -0.5, -0.5), Vector(bullet.Pos:Distance(bullet.Pos + (bullet.Vel * engine.TickInterval())), 0.5, 0.5), Color(255, 255 * 0.75, 0))
	end
end)
