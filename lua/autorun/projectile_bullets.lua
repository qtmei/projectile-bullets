if SERVER then
	util.AddNetworkString("projectile_bullets_table")

	local Projectile = {
		pos = Vector(0, 0, 0),
		ang = Angle(0, 0, 0),
		vel = Vector(0, 0, 0),
		damage = 0,
		attacker = 0,
		inflictor = 0,
		DistMetersPerSecond = 0,
		DropMetersPerSecond = 0
	}

	local projectiles = {}

	function NetworkProjectiles()
		net.Start("projectile_bullets_table")
			local json = util.TableToJSON(projectiles)
			local compressed = util.Compress(json)
			local bytes = #compressed

			net.WriteUInt(bytes, 16)
			net.WriteData(compressed, bytes)
		net.Broadcast()
	end

	hook.Add("EntityFireBullets", "Projectile_Bullets_EntityFireBullets", function(ent, bulletinfo)
		if ent:IsPlayer() then
			ent = ent:GetActiveWeapon()
		end

		for i = 1, bulletinfo.Num or 1, 1 do
			local attacker = bulletinfo.Attacker
			local damage = bulletinfo.Damage

			if !IsValid(attacker) then
				attacker = ent
			end

			if damage == 0 then //HL2 weapons return 0
				damage = game.GetAmmoData(game.GetAmmoID(bulletinfo.AmmoType)).plydmg //sometimes this will get the damage of the HL2 weapon, other times it returns a ConVar

				if !isnumber(damage) then
					damage = GetConVar(damage):GetInt()
				end
			end

			local offset = Vector(0, math.Rand(-(bulletinfo.Spread.x / 2), bulletinfo.Spread.x / 2), math.Rand(-(bulletinfo.Spread.y / 2), bulletinfo.Spread.y / 2))
			offset:Rotate(bulletinfo.Dir:Angle())

			local bullet = table.Copy(Projectile)

			bullet.damage = damage
			bullet.attacker = attacker:EntIndex()
			bullet.inflictor = ent:EntIndex()
			bullet.DistMetersPerSecond = 4000
			bullet.DropMetersPerSecond = 0.25
			bullet.pos = bulletinfo.Src
			bullet.ang = (bulletinfo.Dir + offset):Angle()
			bullet.vel = bullet.ang:Forward() * ((bullet.DistMetersPerSecond / 0.01905) * engine.TickInterval())

			table.insert(projectiles, bullet)
			NetworkProjectiles()
		end

		return false
	end)

	hook.Add("Think", "Projectile_Bullets_Think", function()
		for k, bullet in pairs(projectiles) do
			bullet.pos = bullet.pos + (bullet.vel * engine.TickInterval())
			bullet.vel = bullet.vel + Vector(0, 0, -((bullet.DropMetersPerSecond / 0.01905) * engine.TickInterval()))

			local trace = util.TraceLine({mask = MASK_SHOT, ignoreworld = false, filter = Entity(bullet.attacker), start = bullet.pos + bullet.ang:Forward() * -32, endpos = bullet.pos + bullet.ang:Forward() * 32})

			if trace.Hit then
				local ent = trace.Entity

				if IsValid(ent) then
					local dmginfo = DamageInfo()

					dmginfo:SetDamageType(DMG_BULLET) 
					dmginfo:SetDamage(bullet.damage)
					dmginfo:SetAttacker(Entity(bullet.attacker))
					dmginfo:SetInflictor(Entity(bullet.inflictor))
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

				table.remove(projectiles, k)
			end
		end
	end)
elseif CLIENT then
	local projectiles = {}

	net.Receive("projectile_bullets_table", function(len, ply)
		local bytes = net.ReadUInt(16)
		local compressed = net.ReadData(bytes)
		local json = util.Decompress(compressed)

		projectiles = util.JSONToTable(json)
	end)

	hook.Add("EntityFireBullets", "Projectile_Bullets_EntityFireBullets", function(ent, bulletinfo)
		return false
	end)

	hook.Add("Think", "Projectile_Bullets_Think", function()
		for k, bullet in pairs(projectiles) do
			bullet.pos = bullet.pos + (bullet.vel * engine.TickInterval())
			bullet.vel = bullet.vel + Vector(0, 0, -((bullet.DropMetersPerSecond / 0.01905) * engine.TickInterval()))

			local trace = util.TraceLine({mask = MASK_SHOT, ignoreworld = false, filter = Entity(bullet.attacker), start = bullet.pos + bullet.ang:Forward() * -32, endpos = bullet.pos + bullet.ang:Forward() * 32})

			if trace.Hit then
				table.remove(projectiles, k)
			end
		end
	end)

	hook.Add("PostDrawOpaqueRenderables", "Projectile_Bullets_Think", function()
		for k, bullet in pairs(projectiles) do
			render.SetColorMaterial()
			render.DrawBox(bullet.pos, bullet.ang, Vector(-4, -0.5, -0.5), Vector(4, 0.5, 0.5), Color(255, 255 * 0.75, 0))
		end
	end)
end
