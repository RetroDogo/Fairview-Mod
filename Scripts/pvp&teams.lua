dofile( "$SURVIVAL_DATA/Scripts/game/survival_projectiles.lua" )
dofile( "$SURVIVAL_DATA/Scripts/util.lua" )
dofile("$CONTENT_DATA/Scripts/Utils.lua")
dofile("$CONTENT_DATA/Scripts/QueueMessages.lua")
dofile("$SURVIVAL_DATA/Scripts/game/managers/RespawnManager.lua")

-- pvp variables
local hitboxSize = sm.vec3.new(3, 3, 5)/4
local healthRegenPerSecond = 1 -- per second
local healHealthAmount = 10
local maxHP = 100
local respawnTime = 5 -- seconds
local respawnImmunity = 30 -- seconds
PVP_instance = nil

-- armor items and such for pvp
equipmentItems = {
	{
       -- armor head
		uuid = sm.uuid.new("e7893ad4-0261-47b7-86cb-0594c8bb89d3"),
		renderable = "$CONTENT_DATA/Characters/Clothes/Renderable/MetalHeadArmor.rend",
		stats = {
            maxHealth = 50,
		    damageReduction = 0.1
		}
	},
	{
       -- armor torso
		uuid = sm.uuid.new("1064ef91-5ee8-4629-84d9-ae9e8d257292"),
		renderable = "$CONTENT_DATA/Characters/Clothes/Renderable/TorsoArmor.rend",
		stats = {
            maxHealth = 50,
			damageReduction = 0.2
		}
	},
	{
       -- armor legs
		uuid = sm.uuid.new("319a5f1d-cd83-4b5c-bcdc-4c675f891928"),
		renderable = "$CONTENT_DATA/Characters/Clothes/Renderable/LegsArmor.rend",
		stats = {
            maxHealth = 50,
			damageReduction = 0.15
		}
	},
	{
       -- armor shoes
		uuid = sm.uuid.new("ae5e9c9c-a943-45bb-ae8f-d48e6d3cfddd"),
		renderable = "$SURVIVAL_DATA/Character/Char_Male/Outfit/Shoes/Outfit_engineer_shoes/char_male_outfit_engineer_shoes.rend",
        stats = {
            maxHealth = 50,
		    damageReduction = 0.05
		}
	}--[[,
    {
       -- planned to be a sorta bandage armor for healing, breaks after 
		uuid = wtf is the uuid,
		slot = "foot",
		renderable = "$SURVIVAL_DATA/Character/Char_Male/Outfit/Shoes/Outfit_engineer_shoes/char_male_outfit_engineer_shoes.rend",
       stats = {
           "breaks when fully healed"
			damageReduction = 0.05
		}
	}]]
}

-- team variables
local inviteMins = 5
local inviteSeconds = 0
local inviteTime = (inviteMins*2400)+(inviteSeconds*40)

-- pvp stuff

function PVP_onSetSpawn(self,player)
    local playerPos = player:getCharacter():getWorldPosition()
    self.network:sendToClient( hostPlayer, "cl_sendTextMessage", "Set spawn point to "..math.floor(playerPos.x*4).." "..math.floor(playerPos.y*4).." "..math.floor(playerPos.z*4))
   
    local modSettings = sm.json.open( "$CONTENT_DATA/Json/modSettings.json")
    modSettings["spawnpoint"] = {}
    modSettings["spawnpoint"] = {x =playerPos.x, y = playerPos.y, z = playerPos.z}
    sm.json.save( modSettings, "$CONTENT_DATA/Json/modSettings.json")
end

function PVP_server_onCreate(self)
    PVP_sv_init(self)
end

function PVP_sv_init(self)

    self.sv.hitboxes = {}
    self.sv.respawns = {}
    self.sv.respawnImmunity = {}
    self.sv.armorHealths = {}

    if type(self.storage:load()) == "table" then
        self.sv.saved = self.storage:load().PVPSAVE
        self.sv.armorHealths = self.storage:load().armorHealths
    end
    if self.sv.saved == nil then
        self.sv.saved = {}
        self.sv.saved.playerStats = {}
        self.sv.saved.spawnPoints = {}

        self.sv.saved.settings = {}
        self.sv.saved.settings.pvp = true
    end
    if self.sv.armorHealths == nil then self.sv.armorHealths = {} end

    saveToStorage(self,self.sv.saved,"PVPSAVE")

    PVP_instance = self
end

function PVP_server_onRefresh(self)
    PVP_sv_init(self)
end

function PVP_server_onFixedUpdate(self)

    local function create_hitbox(player)
        self.sv.saved.playerStats[player.id] = self.sv.saved.playerStats[player.id] or {hp = maxHP}

        local hitbox = {}
        hitbox.player = player
        hitbox.trigger = sm.areaTrigger.createBox(hitboxSize/2, player.character.worldPosition)
        hitbox.trigger:bindOnProjectile("sv_hitboxOnProjectile", self)

        return hitbox
    end

    update_hitbox_list(self.sv.hitboxes, create_hitbox)

    update_hitboxes(self.sv.hitboxes)

    if self.sv.saved.settings.pvp and sm.game.getCurrentTick() % 40 == 0 then
        for _, player in pairs(sm.player.getAllPlayers()) do
            PVP_sv_updateHP({self = self, player = player, change = healthRegenPerSecond*2})
        end
    end

    if self.newBag then
        if sm.event.sendToInteractable(self.newBag.interactable,"server_setContainer",{
            container = self.newBag.player:getInventory(),
            player = self.newBag.player
        }) then
            -- resets the bag
            self.newBag = nil
        end
    end

    for k, respawn in pairs(self.sv.respawns) do
        if respawn.time < sm.game.getCurrentTick() then
            local SP = sm.json.open("$CONTENT_DATA/Json/modSettings.json")["spawnpoint"]
            local spawnParams = self.sv.saved.spawnPoints[respawn.player.id] or {
                pos = sm.vec3.new(SP.x,SP.y,SP.z),
                yaw = 0,
                pitch = 0 
            }

            -- makes a bag for death
            if sm.game.getLimitedInventory() then
                local newBag = sm.shape.createPart( 
                    sm.uuid.new("de7eea5b-9262-476b-a5bb-238d0e91f81f"),
                    respawn.player.character.worldPosition,
                    sm.quat.identity(), 
                    true, 
                    true
                )
                -- jank way of setting the bag's inventory
                self.newBag = {interactable = newBag.interactable,player = respawn.player}
            end

            local newChar = sm.character.createCharacter( respawn.player, respawn.player:getCharacter():getWorld(), spawnParams.pos, spawnParams.yaw, spawnParams.pitch )
            respawn.player:setCharacter(newChar)

            -- fucking does nothing what the fuck
            sm.effect.playEffect( "Characterspawner - Activate", spawnParams.pos )

            self.sv.respawns[k] = nil

            self.network:sendToClient(respawn.player,"cl_onRespawn")
            table.insert(self.sv.respawnImmunity,{player = respawn.player, time = sm.game.getCurrentTick()+respawnImmunity*40})

            self.sv.saved.playerStats[respawn.player.id].hp = maxHP
            saveToStorage(self,self.sv.saved,"PVPSAVE")
        end
    end

    for k, respawnImmunity in pairs(self.sv.respawnImmunity) do
        if respawnImmunity.time < sm.game.getCurrentTick() then
            table.remove(self.sv.respawnImmunity,k)
        end
    end

    -- if a player's health is low, it makes the player slower to simulate being weak
    if self.sv.saved.settings.pvp and sm.game.getCurrentTick()%20 == 0 then
        for _,player in pairs(sm.player.getAllPlayers()) do
            local hp = self.sv.saved.playerStats[player.id].hp
            local speedFraction = math.random(0,-(((-hp+100)/maxHP))*100)/100+1
            if speedFraction ~= player.character.publicData.waterMovementSpeedFraction and not player.character:isDowned() then
                player.character.publicData.waterMovementSpeedFraction = speedFraction
                self.network:sendToClients("cl_updateSpeed",{player = player, speedFraction = speedFraction})
            end
        end
    end

end

function update_hitbox_list(list, createFunction, destroyFunction )
    for _, player in pairs(sm.player.getAllPlayers()) do
        local character = player.character

        if list[player.id] and not character then
            if destroyFunction then
                destroyFunction(list[player.id].hitbox)
            end
            list[player.id] = nil

        elseif not list[player.id] and character then
            list[player.id] = createFunction(player)
        end
    end
end

function update_hitboxes(hitboxes)
    for id, hitbox in pairs(hitboxes) do
        local char = hitbox.player.character
        local newPos = char.worldPosition + 
            char.velocity:safeNormalize(sm.vec3.zero()) *
            char.velocity:length()^0.5/16

        local size = hitboxSize
        if char:isCrouching() then --crouch offset
            size = sm.vec3.new(size.x, size.y, size.z*0.8)
            newPos = newPos + sm.vec3.new(0,0,0.125)
        end

        local lockingInteractable = char:getLockingInteractable()
        if lockingInteractable and lockingInteractable:hasSeat() then --seat offset
            newPos = newPos + sm.vec3.new(0,0,0.125)
        end

        if hitbox.trigger then
            hitbox.trigger:setWorldPosition(newPos)
            hitbox.trigger:setSize(size/2)
        end

        if hitbox.effect then
            hitbox.effect:setPosition(newPos)
            hitbox.effect:setScale(size)
        end
    end
end

function PVP_sv_updateHP(params)
    local Teams = sm.json.open("$CONTENT_DATA/Json/Teams.json")
    local self = params.self

    local player = params.player
    local change = params.change/2
    local attacker = params.attacker

    -- checks for respawn immunity
    for _,respawnImmunity in pairs(self.sv.respawnImmunity) do
        if player == respawnImmunity.player then
            change = 10
        end
    end

    -- checks for armor and applies the reduced damage
    if sm.game.getLimitedInventory() and change < 0 then
        local inventory = player:getInventory()
        for slot = 0, inventory:getSize() do
            local slotInfo = inventory:getItem( slot )
            for _,equipmentData in pairs(equipmentItems) do
                if slotInfo.uuid == equipmentData .uuid then
                    -- reduce damage
                    if not self.sv.armorHealths[tostring(player.id)] then
                        self.sv.armorHealths[tostring(player.id)] = {}
                    end
                    if not self.sv.armorHealths[tostring(player.id)][tostring(equipmentData.uuid)] then
                        self.sv.armorHealths[tostring(player.id)][tostring(equipmentData.uuid)] = {uuid = equipmentData.uuid,damageReduction = equipmentData.stats.damageReduction,health = equipmentData.stats.maxHealth-1}
                        change = change-(change*equipmentData. stats.damageReduction)
                    else
                        local equipmentData = self.sv.armorHealths[tostring(player.id)][tostring(equipmentData.uuid)]
                        if equipmentData.health < 1 then
                            for slot = 0, inventory:getSize() do
                                local slotInfo = inventory:getItem( slot )
                                if slotInfo.uuid == equipmentData.uuid then
                                    sm.container.beginTransaction()
                                    inventory:setItem( slot, sm.uuid.getNil(), 0)
                                    self.sv.armorHealths[tostring(player.id)][tostring(equipmentData.uuid)] = nil
                                    sm.container.endTransaction()
                                end
                            end
                        else
                            self.sv.armorHealths[tostring(player.id)][tostring(equipmentData.uuid)] = {uuid = equipmentData.uuid,damageReduction = equipmentData.damageReduction,health = equipmentData.health-1}
                            change = change-(change*equipmentData.damageReduction)
                        end
                    end
                    break
                end
            end
        end
        saveToStorage(self,self.sv.armorHealths,"armorHealths")
    end

    if (not params.ignoreSound) and (change < 0 and not player.character:isDowned()) then
        self.network:sendToClients( "cl_damageSound", { event = "impact", pos = player.character.worldPosition, damage = -change * 0.01 } )
    end

    if change < 0 then
        local lockingInteractable = player.character:getLockingInteractable()
        if lockingInteractable and lockingInteractable:hasSeat() then
            lockingInteractable:setSeatCharacter( player.character )
        end
    end

    local hp = self.sv.saved.playerStats[player.id].hp

    if hp and hp > 0 then
        
        self.sv.saved.playerStats[player.id].hp = math.min(math.max(hp + change, 0), maxHP)
        self.network:sendToClient(player, "cl_updateHealthBar", self.sv.saved.playerStats[player.id].hp)
    
        if self.sv.saved.playerStats[player.id].hp == 0 then
            local playerTeam = TEAM_checkForTeam(self,player)
            local attackerTeam = TEAM_checkForTeam(self,attacker)
            local playerTeamColor = playerTeam and Teams[playerTeam].settings.teamColor or ""
            local attackerTeamColor = attackerTeam and Teams[attackerTeam].settings.teamColor or ""
            if type( attacker ) == "Player" then
                self.network:sendToClients( "cl_sendTextMessage", playerTeamColor .. player.name .. "#ffffff was killed by " .. attackerTeamColor .. attacker.name )
            else
                self.network:sendToClients( "cl_sendTextMessage", playerTeamColor .. player.name .. " #ffffffdied " )
            end

            player.character:setTumbling(true)
            player.character:setDowned(true)
        
            self.sv.respawns[#self.sv.respawns+1] = {player = player, time = sm.game.getCurrentTick() + respawnTime*40}
            self.network:sendToClient(player, "cl_death")
        end

        saveToStorage(self,self.sv.saved,"PVPSAVE")
    end

    -- it breaks sometimes so i gotta check if its 0
    if hp < 0 and not player.character:isDowned() then
        self.sv.saved.playerStats[player.id].hp = 100
    end
end

function PVP_sv_getHitboxOwner(self, triggerID)
    local owner
    for id, hitbox in pairs(self.sv.hitboxes) do
        if hitbox.trigger.id == triggerID then
            owner = hitbox.player
            break
        end
    end
    assert(owner, "Couldn't find owner of hitbox")
    return owner
end

function PVP_sv_attack(self, params)
    local victim = params.victim
    local attacker = params.attacker
    local damage = params.damage

    if victim ~= attacker then
        PVP_sv_updateHP({self = self, player = victim, change = -damage, attacker = attacker, ignoreSound = params.ignoreSound})
    end
end

function PVP_client_onCreate(self)
    g_cl_interactable = self.interactable

    self.cl.hitboxes = {}
    self.cl.meleeAttacks = {sledgehammer_attack1 = 0, sledgehammer_attack2 = 0}

    self.cl.hud = sm.gui.createSurvivalHudGui()
    self.cl.hud:setVisible("FoodBar", false)
    self.cl.hud:setVisible("WaterBar", false)
    self.cl.hud:setVisible("BindingPanel", false)
    self.cl.hud:open()
end

function PVP_client_onFixedUpdate(self)

    if self.cl.death and sm.game.getCurrentTick()%40 == 0 then
        self.cl.death = math.max(self.cl.death-1, 0)

        if self.cl.death == 0 then
            self.cl.death = nil
        end
    end
    if self.cl.respawnImmunity and sm.game.getCurrentTick()%40 == 0 then
        self.cl.respawnImmunity = math.max(self.cl.respawnImmunity-1, 0)

        if self.cl.respawnImmunity == 0 then
            self.cl.respawnImmunity = nil
        end
    end

    if showHitboxes then
        local function create_hitbox(player)
            local hitbox = {}
            hitbox.player = player

            hitbox.effect = sm.effect.createEffect("ShapeRenderable")
            hitbox.effect:setParameter("uuid", sm.uuid.new("5f41af56-df4c-4837-9b3c-10781335757f"))
            hitbox.effect:setParameter("color", sm.color.new(1,1,1))
            hitbox.effect:setScale(hitboxSize)
            hitbox.effect:start()

            return hitbox
        end

        local function destroy_hitbox(hitbox)
            if hitbox and hitbox.effect and sm.exists(hitbox.effect) then --just wanna make sure, bro
                hitbox.effect:destroy()
            end
        end

        update_hitbox_list(self.cl.hitboxes, create_hitbox, destroy_hitbox)
        update_hitboxes(self.cl.hitboxes)
    end

    --detecting player melee attacks via animation
    local char = sm.localPlayer.getPlayer().character
    if char then
        local prevAttacks = self.cl.meleeAttacks

        self.cl.meleeAttacks = {sledgehammer_attack1 = 0, sledgehammer_attack2 = 0, melee_attack1 = 0, melee_attack2 = 0}
        for _, anim in pairs(char:getActiveAnimations()) do
            if anim.name == "sledgehammer_attack1" or anim.name == "sledgehammer_attack2" or anim.name == "melee_attack1" or anim.name == "melee_attack2" then
                self.cl.meleeAttacks[anim.name] = prevAttacks[anim.name] + 1
            end
        end

        local hitDelay = 7
        if self.cl.meleeAttacks.sledgehammer_attack1 == hitDelay or self.cl.meleeAttacks.sledgehammer_attack2 == hitDelay then
            --new melee attack
            local Range = 3.0
            local Damage = 20

            local success, result = sm.localPlayer.getRaycast( Range, sm.localPlayer.getRaycastStart(), sm.localPlayer.getDirection() )
            if success then
                if result.type == "character" and result:getCharacter():getPlayer() then
                    self.network:sendToServer("sv_sendAttack", {victim = result:getCharacter():getPlayer(), attacker = sm.localPlayer.getPlayer(), damage = Damage, ignoreSound = true})
                end
            end
        end
    end
end

function PVP_client_onUpdate(self)
    if self.cl then
        if self.cl.death then
            sm.gui.setInteractionText("Respawn in " .. tostring(self.cl.death))
        end
        if self.cl.respawnImmunity then
            sm.gui.setInteractionText("Respawn immunity for " .. tostring(self.cl.respawnImmunity))
        end
    end
end

function PVP_cl_sendAttack(self, params)
    self.network:sendToServer("sv_sendAttack", params)
end

-- team stuff

function TEAM_onFixedUpdate(self)
    if sm.game.getCurrentTick()%40 == 0 then

        -- if the expireDate is old, reset the invited players
        local invitedPlayers = sm.json.open("$CONTENT_DATA/Json/invitedPlayers.json")
        local Teams = sm.json.open("$CONTENT_DATA/Json/Teams.json") 
        for invitedPlayer,_ in pairs(invitedPlayers) do
            if invitedPlayer ~= "ballery" then 
                for inviteName,time in pairs(invitedPlayers[invitedPlayer]) do
                    if time < sm.game.getCurrentTick() then
                        invitedPlayers[invitedPlayer][inviteName] = {}
                    end
                end
            end
        end

        sm.json.save( invitedPlayers, "$CONTENT_DATA/Json/invitedPlayers.json")
    end

    if sm.game.getCurrentTick()%20 == 0 then
        -- updates the usernames every second
        local Teams = sm.json.open("$CONTENT_DATA/Json/Teams.json") 
        for _,player in pairs(sm.player.getAllPlayers()) do
            for _,allPlayer in pairs(sm.player.getAllPlayers()) do
                if allPlayer ~= player then

                    -- checks if player already owns or is in a team
                    joinedTeam = nil
                    for team,teamTable in pairs(Teams) do
                        for _,teamPlayer in pairs(teamTable.players) do
                            local teamPlayer = checkPlayer(tonumber(teamPlayer))
                            if teamPlayer == player then
                                joinedTeam = team
                                break
                            end
                        end
                    end

                    -- checks if player already owns or is in a team
                    allPlayerTeam = nil
                    for team,teamTable in pairs(Teams) do
                        for _,teamPlayer in pairs(teamTable.players) do
                            local teamPlayer = checkPlayer(tonumber(teamPlayer))
                            if teamPlayer == allPlayer then
                                allPlayerTeam = team
                                break
                            end
                        end
                    end
                    if Teams[allPlayerTeam] then
                        allPlayerName = allPlayer.name.."#FFFFFF | "..Teams[allPlayerTeam].settings.teamColor..tostring(allPlayerTeam or "none").."#FFFFFF | "..allPlayer.id
                    else
                        allPlayerName = allPlayer.name.."#FFFFFF | ".."none".."#FFFFFF | "..allPlayer.id
                    end
                    if allPlayerTeam == joinedTeam then
                        if allPlayerTeam then
                            self.network:sendToClient(player,"client_onUpdateNametags",{text = allPlayerName,player = allPlayer,distance = 16})
                        else
                            self.network:sendToClient(player,"client_onUpdateNametags",{text = allPlayerName,player = allPlayer,distance = 4})

                        end
                    else
                        self.network:sendToClient(player,"client_onUpdateNametags",{text = allPlayerName,player = allPlayer,distance = 4})
                    end
                end
            end
        end
    end
end

function TEAM_onTeamCreate(self,teamName,teamColor,player)
    local Teams = sm.json.open("$CONTENT_DATA/Json/Teams.json") 

    -- checks if player already owns or is in a team
    for _,teamTable in pairs(Teams) do
        for _,teamPlayer in pairs(teamTable.players) do
            local teamPlayer = checkPlayer(tonumber(teamPlayer))
            if teamPlayer == player then
                self.network:sendToClient(player,"cl_sendTextMessage","#FF0000Already in a team!")
                return
            end
        end
    end 

    -- checks the team name
    for teamNameExists,_ in pairs(Teams) do
        if teamNameExists == teamName then
            self.network:sendToClient(player,"cl_sendTextMessage","#FF0000Already a team name!")
            return
        end
    end 

    -- checks the team color
    if not isValidHexColor(teamColor) then
        self.network:sendToClient(player,"cl_sendTextMessage","#FF0000Color not a color!")
        return
    end

    -- finally sets the team and saves it 
    self.network:sendToClient(player,"cl_sendTextMessage","Team "..teamColor..teamName.."#ffffff made")
    Teams[teamName] = {}
    Teams[teamName].settings = {teamColor = teamColor}
    Teams[teamName].players = {tostring(player.id)}
    Teams[teamName].owner = tostring(player.id)
    sm.json.save( Teams, "$CONTENT_DATA/Json/Teams.json")
end

function TEAM_onTeamEdit(self,player)
    self.network:sendToClient(player,"cl_sendTextMessage","btw this doesnt work yet, no point to add it yet")
    -- dont need this for now so it wont do anything
end

function TEAM_onTeamInvite(self,player,invitedPlayerID)
    local Teams = sm.json.open("$CONTENT_DATA/Json/Teams.json")
    local invitedPlayers = sm.json.open("$CONTENT_DATA/Json/invitedPlayers.json")
    local invitedPlayer = checkPlayer(tonumber(invitedPlayerID))
    local ownedTeam = nil

    -- checks if the player that invited are in a team
    local Found = false
    for Team,teamTable in pairs(Teams) do
        teamOwner = checkPlayer(tonumber(teamTable.owner))
        if teamOwner == player then
            ownedTeam = Team
            Found = true
            break
        end
    end
    if not Found then
        self.network:sendToClient(player,"cl_sendTextMessage","#FF0000You dont own a team!")
        return
    end

   -- checks if they are inviting themselves
    if invitedPlayer == player then
        self.network:sendToClient(player,"cl_sendTextMessage","#FF0000You cant invite yourself!")
        return
    end
    
    -- checks if the invited player exists and/or is online
    if not invitedPlayer then
        self.network:sendToClient(player,"cl_sendTextMessage","#FF0000Player invalid!")
        return
    end

    -- checks if player already owns or is in a team
    for _,teamTable in pairs(Teams) do
        for _,teamPlayer in pairs(teamTable.players) do
            local teamPlayer = checkPlayer(tonumber(teamPlayer))
            if teamPlayer == invitedPlayer then
                self.network:sendToClient(player,"cl_sendTextMessage","#FF0000Invited player already in a team!")
                return
            end
        end
    end

    if invitedPlayers then
        if not invitedPlayers[tostring(invitedPlayerID)] then
            invitedPlayers[tostring(invitedPlayerID)] = {[tostring(ownedTeam)] = sm.game.getCurrentTick()+inviteTime}
            self.network:sendToClient(player,"cl_sendTextMessage","Invited "..invitedPlayer.name.."#FFFFFF to team")
            self.network:sendToClient(invitedPlayer,"cl_sendTextMessage","You got invited to join team "..Teams[ownedTeam].settings.teamColor..tostring(ownedTeam).."#FFFFFF "..inviteMins.."m "..inviteSeconds.."s".."\nYou can use #FFFF00/denyteam #FFFFFFand #FFFF00/acceptteam")
        else
            self.network:sendToClient(player,"cl_sendTextMessage","#FF0000Already invited "..invitedPlayer.name)
            return
        end
    else
        invitedPlayers = {}
        invitedPlayers[tostring(invitedPlayerID)] = {team = tostring(ownedTeam), expireDate = sm.game.getCurrentTick()+inviteTime}
    end
    sm.json.save( invitedPlayers, "$CONTENT_DATA/Json/invitedPlayers.json")
end

function TEAM_onTeamDelete(self,player)
    local Teams = sm.json.open("$CONTENT_DATA/Json/Teams.json")
    local invitedPlayers = sm.json.open("$CONTENT_DATA/Json/invitedPlayers.json")

    -- checks if the player is in a team they own
    local Found = false
    for Team,teamTable in pairs(Teams) do
        teamOwner = checkPlayer(tonumber(teamTable.owner))
        if teamOwner == player then
            ownedTeam = Team
            Found = true
            break
        end
    end
    if not Found then
        self.network:sendToClient(player,"cl_sendTextMessage","#FF0000You dont own a team!")
        return
    end

    -- checks if no invites are active when deleting team
    for invitedPlayer,_ in pairs(invitedPlayers) do
        if invitedPlayer ~= "ballery" then 
            for inviteName,_ in pairs(invitedPlayers[invitedPlayer]) do
                if tostring(ownedTeam) == inviteName then
                    self.network:sendToClient(player,"cl_sendTextMessage","#FF0000Cant delete because there is an active invite!")
                    return
                end
            end
        end
    end

    -- sends all players a goodbye team message
    for _,playerId in pairs(Teams[ownedTeam].players) do
        if playerId ~= Teams[ownedTeam].owner then
            server_queueMessage(self,player.name.." deleted team "..Teams[ownedTeam].settings.teamColor..tostring(ownedTeam),playerId)
        end
    end

    self.network:sendToClient(player,"cl_sendTextMessage","Team "..Teams[ownedTeam].settings.teamColor..ownedTeam.."#ffffff deleted")
    Teams[ownedTeam] = {}
    sm.json.save( Teams, "$CONTENT_DATA/Json/Teams.json")
end

function TEAM_onTeamAccept(self,player,team)
    local invitedPlayers = sm.json.open("$CONTENT_DATA/Json/invitedPlayers.json")
    local Teams = sm.json.open("$CONTENT_DATA/Json/Teams.json")

    -- checks if player already owns or is in a team
    for _,teamTable in pairs(Teams) do
        for _,teamPlayer in pairs(teamTable.players) do
            local teamPlayer = checkPlayer(tonumber(teamPlayer))
            if teamPlayer == player then
                self.network:sendToClient(player,"cl_sendTextMessage","#FF0000Already in a team!")
                return
            end
        end
    end

    -- checks if no invites are active when deleting team
    local Found = false
    for invitedPlayer,_ in pairs(invitedPlayers) do
        if invitedPlayer ~= "ballery" then 
            for inviteName,_ in pairs(invitedPlayers[invitedPlayer]) do
                if inviteName == team then
                    Found = true
                    invitedPlayers[invitedPlayer][inviteName] = {}
                    table.insert(Teams[team].players,tostring(player.id))
                    self.network:sendToClient(player,"cl_sendTextMessage","Joined team "..Teams[team].settings.teamColor..team)
                    server_queueMessage(self,player.name.."#FFFFFF joined team",Teams[team].owner)
                    break
                end
            end
        end
    end

    if not Found then
        self.network:sendToClient(player,"cl_sendTextMessage","#FF0000invite invalid!")
        return
    end

    sm.json.save( Teams, "$CONTENT_DATA/Json/Teams.json")
    sm.json.save( invitedPlayers, "$CONTENT_DATA/Json/invitedPlayers.json")
end

function TEAM_onTeamDeny(self,player,team)
    local invitedPlayers = sm.json.open("$CONTENT_DATA/Json/invitedPlayers.json")
    local Teams = sm.json.open("$CONTENT_DATA/Json/Teams.json")

    -- checks if no invites are active when deleting team
    local Found = false
    for invitedPlayer,invitedPlayerData in pairs(invitedPlayers) do
        if invitedPlayer ~= "ballery" then 
            for inviteName,_ in pairs(invitedPlayerData) do
                if inviteName == team then
                    Found = true
                    invitedPlayers[invitedPlayer][inviteName] = {}
                    self.network:sendToClient(player,"cl_sendTextMessage","Denied Team"..Teams[inviteName].settings.teamColor..inviteName)
                    server_queueMessage(self,player.name.." denied joining",Teams[inviteName].owner)
                    break
                end
            end
        end
    end
    if not Found then
        self.network:sendToClient(player,"cl_sendTextMessage","#FF0000invite invalid!")
        return
    end

    sm.json.save( invitedPlayers, "$CONTENT_DATA/Json/invitedPlayers.json")
end

function TEAM_onTeamLeave(self,player)
    local invitedPlayers = sm.json.open("$CONTENT_DATA/Json/invitedPlayers.json")
    local Teams = sm.json.open("$CONTENT_DATA/Json/Teams.json")

    -- checks if player already owns or is in a team
    local Found = false
    for _,teamTable in pairs(Teams) do
        for _,teamPlayer in pairs(teamTable.players) do
            local teamPlayer = checkPlayer(tonumber(teamPlayer))
            if teamPlayer == player then
                Found = true
                break
            end
        end
    end 
    if not Found then
        self.network:sendToClient(player,"cl_sendTextMessage","#FF0000Not in a team!")
        return
    end

    -- checks if the person is an owner of a team
    local owner = false
    for Team,teamTable in pairs(Teams) do
        teamOwner = checkPlayer(tonumber(teamTable.owner))
        ownedTeam = Team
        if teamOwner == player then
            owner = true
            break
        end
    end

    -- checks if no invites are active when deleting team
    for invitedPlayer,_ in pairs(invitedPlayers) do
        if invitedPlayer ~= "ballery" then 
            for inviteName,_ in pairs(invitedPlayers[invitedPlayer]) do
                if tostring(ownedTeam) == inviteName then
                    self.network:sendToClient(player,"cl_sendTextMessage","#FF0000Cant delete because there is an active invite!")
                    return
                end
            end
        end
    end

    if owner then
        smartRemove(Teams[ownedTeam].players, tostring(player.id), true)
        if #Teams[ownedTeam].players == 0 then
            self.network:sendToClient(player,"cl_sendTextMessage","Removed "..Teams[ownedTeam].settings.teamColor..tostring(ownedTeam))
            Teams[ownedTeam] = {}
        else
            self.network:sendToClient(player,"cl_sendTextMessage","Left "..Teams[ownedTeam].settings.teamColor..tostring(ownedTeam))
            Teams[ownedTeam].owner = pickRandomItem(Teams[ownedTeam].players)
            server_queueMessage(self,"You are the new owner of "..Teams[ownedTeam].settings.teamColor..tostring(ownedTeam),Teams[ownedTeam].owner)
        end
    else
        self.network:sendToClient(player,"cl_sendTextMessage","Left "..Teams[ownedTeam].settings.teamColor..tostring(ownedTeam))
        server_queueMessage(self,player.name.." left team",Teams[ownedTeam].owner)
        smartRemove(Teams[ownedTeam].players, tostring(player.id), true)
    end

    sm.json.save( Teams, "$CONTENT_DATA/Json/Teams.json")
end

function TEAM_onTeamTransfer(self,player,newOwnerId)
    local Teams = sm.json.open("$CONTENT_DATA/Json/Teams.json")
    local invitedPlayers = sm.json.open("$CONTENT_DATA/Json/invitedPlayers.json")
    local newOwnerPlayer = checkPlayer(tonumber(newOwnerId))

    -- checks if player owns a team
    local ownedTeam = nil
    local Found = false
    for Team,teamTable in pairs(Teams) do
        teamOwner = checkPlayer(tonumber(teamTable.owner))
        if teamOwner == player then
            ownedTeam = Team
            Found = true
            break
        end
    end
    if not Found then
        self.network:sendToClient(player,"cl_sendTextMessage","#FF0000You dont own a team!")
        return
    end

    -- checks if they are giving owner to themselves
    if newOwnerPlayer == player then
        self.network:sendToClient(player,"cl_sendTextMessage","#FF0000You cant give owner to yourself!")
        return
    end
    
    -- checks if the new owner player exists and/or is online
    if not newOwnerPlayer then
        self.network:sendToClient(player,"cl_sendTextMessage","#FF0000Player invalid!")
        return
    end

    -- checks if player already owns or is in a team
    for teamName,teamTable in pairs(Teams) do
        if teamName ~= ownedTeam then
            for _,teamPlayer in pairs(teamTable.players) do
                local teamPlayer = checkPlayer(tonumber(teamPlayer))
                if teamPlayer == newOwnerPlayer then
                    self.network:sendToClient(player,"cl_sendTextMessage","#FF0000New owner is in a team!")
                    return
                end
            end
        end
    end

    -- checks if new owner is in the team
    local Found = false
    for _,teamPlayer in pairs(Teams[ownedTeam].players) do
        if tonumber(teamPlayer) == tonumber(newOwnerId) then
            Found = true
            break
        end
    end
    if not Found then
        self.network:sendToClient(player,"cl_sendTextMessage","#FF0000Not in the team!")
        return
    end

    -- checks if no invites are active when deleting team
    for invitedPlayer,_ in pairs(invitedPlayers) do
        if invitedPlayer ~= "ballery" then 
            for inviteName,_ in pairs(invitedPlayers[invitedPlayer]) do
                if tostring(ownedTeam) == ownedTeam then
                    self.network:sendToClient(player,"cl_sendTextMessage","#FF0000Cant transfer because they are invited!")
                    return
                end
            end
        end
    end

    self.network:sendToClient(player,"cl_sendTextMessage","Team "..Teams[ownedTeam].settings.teamColor..tostring(ownedTeam).."#FFFFFF's owner is now "..newOwnerPlayer.name)
    self.network:sendToClient(newOwnerPlayer,"cl_sendTextMessage","You are now the owner of "..Teams[ownedTeam].settings.teamColor..tostring(ownedTeam))

    Teams[ownedTeam].owner = tostring(newOwnerId)

    sm.json.save( Teams, "$CONTENT_DATA/Json/Teams.json")
end

function TEAM_onTeamKick(self,player,kickedPlayerId)
    local Teams = sm.json.open("$CONTENT_DATA/Json/Teams.json")

    -- checks if the player is in a team they own
    local Found = false
    for Team,teamTable in pairs(Teams) do
        if teamTable.owner == tostring(player.id) then
            ownedTeam = Team
            Found = true
        end
    end
    if not Found then
        self.network:sendToClient(player,"cl_sendTextMessage","#FF0000You dont own a team!")
        return
    end

    -- checks if they are inviting themselves
    if kickedPlayerId == player.id then
        self.network:sendToClient(player,"cl_sendTextMessage","#FF0000You cant remove yourself!")
        return
    end

    -- checks if player already owns or is in a team
    local Found = false
    for teamName,teamTable in pairs(Teams) do
        if teamName == ownedTeam then
            for _,teamPlayer in pairs(teamTable.players) do
                if teamPlayer == tostring(kickedPlayerId) then
                    Found = true
                    break
                end
            end
        end
    end 
    if not Found then
        self.network:sendToClient(player,"cl_sendTextMessage","#FF0000Not in the team!")
        return
    end

    smartRemove(Teams[ownedTeam].players, tostring(kickedPlayerId), true)
    server_queueMessage(self,player.name.." removed you from "..Teams[ownedTeam].settings.teamColor..tostring(ownedTeam),kickedPlayerId)
    if checkPlayer(kickedPlayerId) then
        self.network:sendToClient(player,"cl_sendTextMessage","Removed "..checkPlayer(kickedPlayerId).name.."#FFFFFF from team")
    else
        self.network:sendToClient(player,"cl_sendTextMessage","Removed player from team")
    end

    sm.json.save( Teams, "$CONTENT_DATA/Json/Teams.json")
end

function TEAM_onTeamCancel(self,player,invitedPlayerID)
    local Teams = sm.json.open("$CONTENT_DATA/Json/Teams.json")
    local invitedPlayers = sm.json.open("$CONTENT_DATA/Json/invitedPlayers.json")
    local ownedTeam = nil

    -- checks if the person owns a team
    local Found = false
    for Team,teamTable in pairs(Teams) do
        teamOwner = checkPlayer(tonumber(teamTable.owner))
        if teamOwner == player then
            ownedTeam = Team
            Found = true
            break
        end
    end
    if not Found then
        self.network:sendToClient(player,"cl_sendTextMessage","#FF0000You dont own a team!")
        return
    end

    -- checks if there is a valid invite
    local Found = false
    for invitedPlayer,_ in pairs(invitedPlayers) do
        if invitedPlayer ~= "ballery" then 
            for inviteName,_ in pairs(invitedPlayers[invitedPlayer]) do
                if tostring(inviteName) == ownedTeam then
                    Found = true
                    break
                end
            end
        end
    end
    if not Found then
        self.network:sendToClient(player,"cl_sendTextMessage","#FF0000Player isnt invited!")
        return
    end

    server_queueMessage(self,player.name.." canceled the invite to "..Teams[ownedTeam].settings.teamColor..tostring(ownedTeam),invitedPlayerID)
    if checkPlayer(tonumber(invitedPlayerID)) then
        self.network:sendToClient(player,"cl_sendTextMessage","Canceled "..checkPlayer(tonumber(invitedPlayerID)).name.."'s Invite to team")
    else
        self.network:sendToClient(player,"cl_sendTextMessage","Canceled invite to team")
    end
    invitedPlayers[tostring(invitedPlayerID)][tostring(ownedTeam)] = {}
    sm.json.save( invitedPlayers, "$CONTENT_DATA/Json/invitedPlayers.json")
end

function TEAM_checkForTeam(self,player)
    local Teams = sm.json.open("$CONTENT_DATA/Json/Teams.json")
    -- checks if player already owns or is in a team
    for team,teamTable in pairs(Teams) do
        for _,teamPlayer in pairs(teamTable.players) do
            local teamPlayer = checkPlayer(tonumber(teamPlayer))
            if teamPlayer == player then
                return team
            end
        end
    end 
    return false
end