if SERVER then
	util.AddNetworkString("projectile_bullets_table")

	local Projectile = {
		pos = Vector(0, 0, 0),
		ang = Angle(0, 0, 0),
		vel = Vector(0, 0, 0),
		damage = 0,
		attacker = 0,
		inflictor = 0,
		MinuteOfArc = 0,
		DistMetersPerSecond = 0,
		DropMetersPerSecond = 0
	}

	local projectiles = {}

	hook.Add("EntityFireBullets", "Projectile_Bullets_EntityFireBullets", function(ent, bulletinfo)
		for i = 1, bulletinfo.Num or 1, 1 do
			local attacker = bulletinfo.Attacker
			local damage = bulletinfo.Damage

			if !IsValid(attacker) then
				attacker = ent
			end

			if damage == 0 then
				damage = 14
			end

			local bullet = table.Copy(Projectile)

			bullet.damage = damage
			bullet.attacker = attacker:EntIndex()
			bullet.inflictor = ent:EntIndex()
			bullet.MinuteOfArc = bulletinfo.Spread
			bullet.DistMetersPerSecond = 4000
			bullet.DropMetersPerSecond = 1
			bullet.pos = bulletinfo.Src
			bullet.ang = bulletinfo.Dir:Angle() + Angle(math.Rand(-bullet.MinuteOfArc, bullet.MinuteOfArc), math.Rand(-bullet.MinuteOfArc, bullet.MinuteOfArc), 0)
			bullet.vel = bullet.ang:Forward() * ((bullet.DistMetersPerSecond / 0.01905) * engine.TickInterval())

			table.insert(projectiles, bullet)
		end

		return false
	end)

	hook.Add("Think", "Projectile_Bullets_Think", function()
		net.Start("projectile_bullets_table")
			local json = util.TableToJSON(projectiles)
			local compressed = util.Compress(json)
			local bytes = #compressed

			net.WriteUInt(bytes, 16)
			net.WriteData(compressed, bytes)
		net.Broadcast()

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

			if bullet.vel:Length2D() < 10 then
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

	hook.Add("PostDrawOpaqueRenderables", "Projectile_Bullets_Think", function()
		for k, bullet in pairs(projectiles) do
			render.SetColorMaterial()
			render.DrawBox(bullet.pos, bullet.ang, Vector(-4, -0.5, -0.5), Vector(4, 0.5, 0.5), Color(255, 255 * 0.75, 0))
		end
	end)
end
