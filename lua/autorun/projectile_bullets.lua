AddCSLuaFile()

CreateConVar("projectile_bullets_speed", 700, {FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_NOTIFY}, "bullet speed in meters/second", 1, 1000)
CreateConVar("projectile_bullets_drop", 1, {FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_NOTIFY}, "bullet drop in meters/second", 0, 2)

local bullets = {}

hook.Add("EntityFireBullets", "Projectile_Bullets_EntityFireBullets", function(ent, bulletinfo)
	if ent:IsPlayer() then
		ent = ent:GetActiveWeapon()
	end

	if !IsValid(bulletinfo.Attacker) then
		bulletinfo.Attacker = ent
	end

	if bulletinfo.Damage == 0 then //HL2 weapons return 0
		bulletinfo.Damage = game.GetAmmoData(game.GetAmmoID(bulletinfo.AmmoType)).plydmg //sometimes this will get the damage of the HL2 weapon, other times it returns a ConVar

		if !isnumber(bulletinfo.Damage) then
			bulletinfo.Damage = GetConVar(bulletinfo.Damage):GetInt()
		end
	end

	bulletinfo.Inflictor = ent
	bulletinfo.Speed = GetConVar("projectile_bullets_speed"):GetFloat()
	bulletinfo.Drop = GetConVar("projectile_bullets_drop"):GetFloat()
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
		bullet.Pos = bullet.Pos + (bullet.Vel * engine.TickInterval())
		bullet.Vel = bullet.Vel + Vector(0, 0, -(bullet.Drop / 0.01905))

		local trace = util.TraceLine({mask = MASK_SHOT, ignoreworld = false, filter = bullet.Attacker, start = bullet.Pos, endpos = bullet.Pos + (bullet.Vel * engine.TickInterval())})

		if trace.Hit then
			if SERVER then
				local ent = trace.Entity

				if IsValid(ent) then
					local dmginfo = DamageInfo()

					dmginfo:SetDamageType(DMG_BULLET) 
					dmginfo:SetDamage(bullet.Damage)
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
		render.DrawBox(bullet.Pos, bullet.Dir:Angle(), Vector(-4, -0.5, -0.5), Vector(4, 0.5, 0.5), Color(255, 255 * 0.75, 0))
	end
end)
