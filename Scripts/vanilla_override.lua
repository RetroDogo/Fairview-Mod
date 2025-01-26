dofile( "$GAME_DATA/Scripts/game/BasePlayer.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/SurvivalPlayer.lua" )

-- all the banned uuids that get deleted in the inventory
local bannedUuids = {
	sm.uuid.new("1016cafc-9f6b-40c9-8713-9019d399783f"), -- metal block 2
	sm.uuid.new("c0dfdea5-a39d-433a-b94a-299345a5df46") -- metal block 3
}

function BasePlayer.server_onFixedUpdate( self, dt )
	local character = self.player:getCharacter()
	if character then
		self:sv_updateTumbling()
	end

	self.sv.damageCooldown:tick()
	self.sv.impactCooldown:tick()
	self.sv.fireDamageCooldown:tick()
	self.sv.poisonDamageCooldown:tick()

	-- loads the player vaLue apon reload
	if not hostPlayer or hostPlayer.id ~= 1 then
	    for _,player in pairs(sm.player.getAllPlayers()) do if player.id == 1 then hostPlayer = player end end
	end

end

function BasePlayer.server_onInventoryChanges( self, inventory, changes )
	print(self.player, hostPlayer)
	if not self.sv.clientLock and self.player ~= hostPlayer then
		sm.container.beginTransaction()
		for _,changeData in pairs(changes) do
			print(findValueInTable(bannedUuids,changeData.uuid), changeData.difference > 0)
			if findValueInTable(bannedUuids,changeData.uuid) and changeData.difference > 0 then
				sm.container.spend(inventory,changeData.uuid,changeData.difference)
			end
		end
		sm.container.endTransaction()
	end
end

function BasePlayer.server_onDataUpdate( self, data )
	if data.type == "clientLock" then
		self.sv.clientLock = data.value
	end
end

worldsHooked = worldsHooked or false
if not worldsHooked then
	for k, v in pairs({ MenuWorld, ClassicCreativeTerrainWorld, CreativeCustomWorld, CreativeTerrainWorld, CreativeFlatWorld }) do
		local oldProjectile = v.server_onProjectile
		local function newProjectile( self, hitPos, hitTime, hitVelocity, _, attacker, damage, userData, hitNormal, target, projectileUuid )
			if oldProjectile then
				oldProjectile(self, hitPos, hitTime, hitVelocity, _, attacker, damage, userData, hitNormal, target, projectileUuid )
			end

			if userData and userData.lootUid then
				local normal = -hitVelocity:normalize()
				local zSignOffset = math.min( sign( normal.z ), 0 ) * 0.5
				local offset = sm.vec3.new( 0, 0, zSignOffset )
				local lootHarvestable = sm.harvestable.createHarvestable( hvs_loot, hitPos + offset, sm.vec3.getRotation( sm.vec3.new( 0, 1, 0 ), sm.vec3.new( 0, 0, 1 ) ) )
				lootHarvestable:setParams( { uuid = userData.lootUid, quantity = userData.lootQuantity, epic = userData.epic  } )
			end
		end
		v.server_onProjectile = newProjectile
	end
	worldsHooked = true
end

function findValueInTable(tbl,v)
    if type(tbl) ~= "table" then return false end
    for i,tblV in pairs(tbl) do
        if tblV == v then
            return i
        end
    end
    return false
end