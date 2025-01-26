commands = class()

dofile("$CONTENT_DATA/Scripts/Currency.lua")
dofile("$CONTENT_DATA/Scripts/Utils.lua")
dofile("$CONTENT_DATA/Scripts/pvp&teams.lua")
dofile("$CONTENT_DATA/Scripts/Jobs.lua")
dofile("$CONTENT_DATA/Scripts/PlayerList.lua")

local jsonFiles = {
    "$CONTENT_DATA/Json/Currency.json",
    "$CONTENT_DATA/Json/invitedPlayers.json",
    "$CONTENT_DATA/Json/modSettings.json",
    "$CONTENT_DATA/Json/QueueMessages.json",
    "$CONTENT_DATA/Json/Teams.json",
    "$CONTENT_DATA/Json/Jobs.json"
}

-- armor items and such for pvp
equipmentItems = {
	{
       -- armor head
		uuid = sm.uuid.new("e7893ad4-0261-47b7-86cb-0594c8bb89d3"),
		renderable = "$CONTENT_DATA/Characters/Clothes/Renderable/MetalHeadArmor.rend",
        slot = "head",
		stats = {
            maxHealth = 50,
		    damageReduction = 0.1
		}
	},
	{
       -- armor torso
		uuid = sm.uuid.new("1064ef91-5ee8-4629-84d9-ae9e8d257292"),
		renderable = "$CONTENT_DATA/Characters/Clothes/Renderable/TorsoArmor.rend",
        slot = "torso",
		stats = {
            maxHealth = 50,
			damageReduction = 0.2
		}
	},
	{
       -- armor legs
		uuid = sm.uuid.new("319a5f1d-cd83-4b5c-bcdc-4c675f891928"),
		renderable = "$CONTENT_DATA/Characters/Clothes/Renderable/LegsArmor.rend",
        slot = "legs",
		stats = {
            maxHealth = 50,
			damageReduction = 0.15
		}
	},
	{
       -- armor shoes
		uuid = sm.uuid.new("ae5e9c9c-a943-45bb-ae8f-d48e6d3cfddd"),
		renderable = "$SURVIVAL_DATA/Character/Char_Male/Outfit/Shoes/Outfit_engineer_shoes/char_male_outfit_engineer_shoes.rend",
        slot = "feet",
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

function commands.cl_sendTextMessage(self,text)
    sm.gui.chatMessage(text)
end

function commands.sv_sendMessageToHost(self,data)
    local text = data.text
    local player = data.player
    if text and player then
        self.network:sendToClient(hostPlayer,"cl_sendTextMessage",text.." from "..player.name.."'s#FFFFFF client")
    end
end

-- server

function commands.server_onCreate( self )
    local status, err = pcall(function()
        if self.tool:getOwner().id == 1 then

            -- loads the tool vaLue
            if not Tool then
                Tool = self.tool
            end
            -- loads the player vaLue
            if not hostPlayer or hostPlayer.id ~= 1 then
                hostPlayer = checkPlayer(1)
            end
            
            self.sv = {}
            self.sv.ifClientsLocked = true
            self.sv.playerTable = {}
            self.sv.warnItems = {}
            PVP_server_onCreate(self)
            sm.event.sendToPlayer( checkPlayer(1), "server_onDataUpdate", {type = "clientLock",value = true} )

            -- reverts all jsons to defaults
            for _,v in pairs(jsonFiles) do
                local defaultFile = "$CONTENT_DATA/Json/DefaultJson/"..string.sub(v,20,100)
                local defaultData = sm.json.open(defaultFile)
                print("reset data for",v)
                sm.json.save(defaultData,v)
            end

            -- tries loading old data, if it fails it just gives up lmao
            local savedData = self.storage:load()
            if savedData["Currency.json"] then
                for _,v in pairs(jsonFiles) do
                    local data = savedData[string.sub(v,20,100)]
                    -- checks for data inside the table
                    local ifData = false
                    for _,data in pairs(data) do
                        ifData = true
                    end
                    if ifData then
                        print("setting data for",v,"to",data)
                        sm.json.save(data,v)
                    end
                end
            end
        end
    end)
    if not status then
        self.network:sendToClient(hostPlayer,"cl_sendTextMessage","#FF0000"..err)
        print(err)
    end
end

function commands.server_onRefresh( self )
    if self.tool:getOwner().id == 1 then
        PVP_server_onRefresh(self)

        hostPlayer.character:setDowned(false)

         -- reverts all jsons to defaults
         for _,v in pairs(jsonFiles) do
            local defaultFile = "$CONTENT_DATA/Json/DefaultJson/"..string.sub(v,20,100)
            local defaultData = sm.json.open(defaultFile)
            --print("reset data for",v)
            sm.json.save(defaultData,v)
        end
        
        -- tries loading old data, if it fails it just gives up lmao
        local savedData = self.storage:load()
        if savedData["Currency.json"] then
            for _,v in pairs(jsonFiles) do
                local data = savedData[string.sub(v,20,100)]
                -- checks for data inside the table
                local ifData = false
                for _,data in pairs(data) do
                    ifData = true
                end
                if ifData then
                    --print("setting data for",v,"to",data)
                    sm.json.save(data,v)
                end
            end
        end

    end
end

function commands.server_onFixedUpdate( self, timeStep )
    local status, err = pcall(function()
        if self.tool:getOwner().id == 1 then

            PVP_server_onFixedUpdate(self)
            --TEAM_onFixedUpdate(self)
            JOB_onFixedUpdate(self)
    
            -- loads the tool vaLue
            if not Tool then
                Tool = self.tool
            end
            -- loads the player vaLue
            if not hostPlayer or hostPlayer.id ~= 1 then
                hostPlayer = checkPlayer(1)
            end
    
            -- runs code when a player joins
            for _,player in pairs(tableDiffValues(sm.player.getAllPlayers(),self.sv.playerTable)) do
                table.insert(self.sv.playerTable, player)
    
                if player == hostPlayer then
                    -- erases the inventory becayuse its unlimited
                    local container = hostPlayer:getHotbar()
                    sm.container.beginTransaction()
                    for slot = 0, container:getSize() do
                        local containerSlot = container:getItem( slot )
                        container:setItem( slot, sm.uuid.getNil(), 0)
                    end
                    sm.container.endTransaction()
                end

                -- put player joining code here
            end
            
            -- sets downed if the clientlock is on
            if self.sv.ifClientsLocked then
                for _,player in pairs(sm.player.getAllPlayers()) do
                    if player:getCharacter() and player ~= hostPlayer then
                        if not player:getCharacter():isDowned() then
                            player:getCharacter():setDowned( true )
                            self.network:sendToClient(player, "cl_sendTextMessage","The host is busy, you have been locked!")
                        end
                    end
                end
            end

            -- saves the data of the jsons to the world (technically)
            if sm.game.getCurrentTick()%40 == 0 then
                for _,v in pairs(jsonFiles) do
                    local data = sm.json.open(v)
                    if type(data) == "table" then
                        -- checks for data inside the table
                        local ifData = false
                        for _,data in pairs(data) do
                            ifData = true
                        end
                        if ifData then
                            saveToStorage(self,data,string.sub(v,20,100))
                        end
                    end
                end
            end

            -- checks inventories for armor and puts it on
            if not self.sv.ifClientsLocked then
                self.ifRemovedArmor = false
                for _,player in pairs(sm.player.getAllPlayers()) do
                    if not self.sv.warnItems[player.id] then
                        self.sv.warnItems[player.id] = {head = nil,torso = nil,legs = nil,feet =nil}
                    end
                    local inventory = player:getInventory()
                    if inventory:getSize() > 50 then
                        break
                    end

                    -- gets the equippments used by the person
                    local equipments = {}
                    for slot = 0, inventory:getSize() do
                        local slotInfo = inventory:getItem( slot )
                        for _,equipmentData in pairs(equipmentItems) do
                            if slotInfo.uuid == equipmentData.uuid then
                                if not equipments[equipmentData.slot] then
                                    table.insert(equipments,equipmentData.renderable)
                                end
                            end
                        end
                    end
                
                    -- gets the differeces
                    local addedTable = tableDiffValues(equipments,self.sv.warnItems[player.id])
                    local removedTable = tableDiffValues(self.sv.warnItems[player.id],equipments)
                
                    -- wears the armor
                    if #addedTable ~= 0 or #removedTable ~= 0 then
                        for _,renderable in pairs(addedTable[1] and addedTable or removedTable) do
                            self.network:sendToClients("cl_equipRenderable",{
                                character = player.character,
                                renderable = renderable,
                                state = addedTable[1]
                            })
                        end
                    end
                
                    self.sv.warnItems[player.id] = equipments
                end
            else
                if self.ifRemovedArmor ~= true then
                    self.ifRemovedArmor = true
                    for _,player in pairs(sm.player.getAllPlayers()) do
                        self.sv.warnItems[player.id] = {}
                        local character = player.character
                        for _,equipmentData in pairs(equipmentItems) do
                            self.network:sendToClients("cl_equipRenderable",{
                                character = player.character,
                                renderable = equipmentData.renderable,
                                state = false
                            })
                        end
                    end
                end
            end

            -- saves the inventory every second
            if sm.game.getCurrentTick()%40 == 0 and not self.sv.ifClientsLocked then
                local container = hostPlayer:getInventory()
                local inventory = {}
                for slot = 0, container:getSize() do
                    local containerSlot = container:getItem( slot )
                    inventory[slot] = {quantity = containerSlot.quantity,uuid = containerSlot.uuid}    
                end
                saveToStorage(self,inventory,"inventory")
            end

            -- locks the players via handcuffs if they are in the global table
            if not self.sv.ifClientsLocked then
                for _,player in pairs(sm.player.getAllPlayers()) do
                    for _,respawn in pairs(self.sv.respawns) do
                        if respawn.player == player then goto continue end
                        local locked = findValueInTable(_G.lockedPlayers,player) and true or false
                        player.character.publicData.ifLocked = ilocked
                        player.character:setDowned( locked )
                        local speedFraction = locked and 0 or 1
                        player.character.publicData.waterMovementSpeedFraction = speedFraction 
                        self.network:sendToClients("cl_updateSpeed",{player = player, speedFraction = speedFraction})
                    
                    end
                    :: continue ::
                end
            end

            -- checks for coins in the inventory and collects them
            Currency = sm.json.open("$CONTENT_DATA/Json/Currency.json")
            if sm.game.getCurrentTick()%40 == 0 and not self.sv.ifClientsLocked then
                for _,player in pairs(sm.player.getAllPlayers()) do
                    local inventory = player:getInventory()
                    for slot = 0,inventory:getSize() do
                        local slotInfo = inventory:getItem( slot )
                        sm.container.beginTransaction()
                        if slotInfo.uuid == sm.uuid.new("7d0262f7-1c1c-40e0-8b32-9c4f34da074e") then
                            Currency[tostring(player.id)][1] = Currency[tostring(player.id)][1] + slotInfo.quantity
                            inventory:setItem( slot, sm.uuid.getNil(), 0)
                        elseif slotInfo.uuid == sm.uuid.new("b8e42416-7110-4092-b69f-4b3bf7c2f8ae") then
                            Currency[tostring(player.id)][1] = Currency[tostring(player.id)][1] + slotInfo.quantity*1000
                            inventory:setItem( slot, sm.uuid.getNil(), 0)
                        elseif slotInfo.uuid == sm.uuid.new("49ae8116-bdb4-4825-845a-ad513363ac84") then
                            Currency[tostring(player.id)][1] = Currency[tostring(player.id)][1] + slotInfo.quantity*1000000
                            inventory:setItem( slot, sm.uuid.getNil(), 0)
                        end
                        sm.container.endTransaction()
                    end
                    sm.json.save( Currency, "$CONTENT_DATA/Json/Currency.json")
                end
            end

        end
    end)
    if self.status1 ~= status then
        if not status and err then
            self.network:sendToClient(hostPlayer,"cl_sendTextMessage","#FF0000"..err)
            print(err)
        end
        self.status1 = status
    end
end


-- client

function commands.client_onCreate( self )
    local status, err = pcall(function()
        self.cl = {}
        PVP_client_onCreate(self)
    end)
    if not status and err then
        self.network:sendToServer("sv_sendMessageToHost",{text = "#FF0000"..err, player = sm.localPlayer.getPlayer()})
        print(err)
    end
end

function commands.client_onFixedUpdate( self, timeStep )
    local status, err = pcall(function()
        PVP_client_onFixedUpdate(self)
    end)
    if self.status2 ~= status then
        if not status and err then
            self.network:sendToServer("sv_sendMessageToHost",{text = "#FF0000"..err, player = sm.localPlayer.getPlayer()})
            print(err)
        end
        self.status2 = status
    end
end

function commands.cl_equipRenderable(self,data)
    local character = data.character
    local renderable = data.renderable
    if data.state then
        character:addRenderable( renderable )
    else
        character:removeRenderable( renderable )
    end
end

function commands.client_onUpdate(self)
    PVP_client_onUpdate(self)
end

-- commands

local BindCommand = BindCommand or sm.game.bindChatCommand

-- binds the commands on start
function sm.game.bindChatCommand(command, params, callback, help)
    if not hooked then
        dofile("$CONTENT_bb240b5a-c410-4e16-8eda-18ea3b91062e/Scripts/vanilla_override.lua")
        BindCommand("/pay", { { "string", "Player ID or Goverment", false }, { "int", "Cash amount", false } }, "cl_onChatCommand", "Pays cash to whoever you decide! only works within 16 blocks.")
        BindCommand("/clearchat", {}, "cl_onChatCommand", "Clears the chat.")
        BindCommand("/shop", { { "string", "Shop Name", false } }, "cl_onChatCommand", "Allows to buy blocks and parts from the shop.")
        BindCommand("/ragdoll", {}, "cl_onChatCommand", "A fun command to ragdoll yourself!")
        local tellArgs = { { "int", "Player ID", false } } for i = 1,128 do table.insert(tellArgs, { "string", "Message"..i, true }) end
        BindCommand("/msg", tellArgs, "cl_onChatCommand", "Private messages another fellow player")
        BindCommand("/pl", {}, "cl_onChatCommand", "Opens the player list")
        -- team commands
        --BindCommand("/createteam", { { "string", "Team Name", false }, { "string", "Team Color", false } }, "cl_onChatCommand", "Creates a new team with the name and color.")
        --BindCommand("/editteam", {}, "cl_onChatCommand", "Edit your own team's settings")
        --BindCommand("/inviteteam", { { "int", "Invited Player Id", false } }, "cl_onChatCommand", "Invite others to your team. (must be a team owner)")
        --BindCommand("/deleteteam", {}, "cl_onChatCommand", "Deletes your own team. (must be a team owner)")
        --BindCommand("/acceptteam", { { "string", "Team Name", false } }, "cl_onChatCommand", "If you have a incoming request, you can accept it.")
        --BindCommand("/denyteam", { { "string", "Team Name", false } }, "cl_onChatCommand", "If you have a incoming request, you can deny it.")
        --BindCommand("/leaveteam", {}, "cl_onChatCommand", "If you are in a team, you can leave that team. (gives owner to random person if you own team, deletes team if no one exists)")
        --BindCommand("/transferteam", { { "int", "New Owner Id", false } }, "cl_onChatCommand", "Transfer the owner of to another person. (must be a team owner)")
        --BindCommand("/kickteam", { { "int", "Kicked Player Id", false } }, "cl_onChatCommand", "Kick a person from your team. (must be a team owner)")
        --BindCommand("/cancelteam", { { "int", "Invited Player Id", false } }, "cl_onChatCommand", "Cancels the invite from your team. (must be a team owner)")
        --BindCommand("/renameteam", { { "int", "Invited Player Id", false } }, "cl_onChatCommand", "Renames the team. (must be a team owner)")
        if sm.isHost then
            -- host commands
            BindCommand("/govpay", { { "string", "Player Id", false }, { "int", "Cash amount", false } }, "cl_onChatCommand", "Pays someone from the goverment. only works with host!")
            BindCommand("/checkcash", { { "string", "Player Id", false } }, "cl_onChatCommand", "Checks the cash of whoever you decide. only works with host!")
            BindCommand("/setdp", { { "string", "Player Id", true } }, "cl_onChatCommand", "Sets the daliy payment through gui. only works with host!")
            BindCommand("/clientlock", {}, "cl_onChatCommand", "Locks all clients and enables unlimited. only works with host!")
            BindCommand("/setspawn", {}, "cl_onChatCommand", "Sets the spawn of the PVP intergration. only works with host!")
            BindCommand("/itemDebug", {}, "cl_onChatCommand", "Sends the data about the item you are holding, debug only though")
            -- host commands for the jobs
        end
        hooked = true
    end
    BindCommand(command, params, callback, help)
end

local oldWorldEvent = oldWorldEvent or sm.event.sendToWorld

-- converts the commands from chat to "sv_runCommand"
function sm.event.sendToWorld(world, callback, params)
    if not params or type(params)=="player" then
        return oldWorldEvent(world, callback, params)
    end

    local knowncommands = {
        "/pay",
        "/clearchat",
        "/shop",
        "/ragdoll",
        "/msg",
        "/pl",
        "/createteam",
        "/editteam",
        "/inviteteam",
        "/deleteteam",
        "/acceptteam",
        "/denyteam",
        "/leaveteam",
        "/transferteam",
        "/kickteam",
        "/cancelteam",
        "/govpay",
        "/checkcash",
        "/setdp",
        "/clientlock",
        "/setspawn",
        "/itemDebug"
    }
    local ifNotCommand = true
    for _,command in pairs(knowncommands) do
        if command == params[1] then
            if command == "/clientlock" then
                params.ifLimited = sm.game.getLimitedInventory()
                sm.game.setLimitedInventory( not sm.game.getLimitedInventory() )
            end
            ifNotCommand = false
            sm.event.sendToTool(Tool, "sv_runCommand", params)
        end
    end
    if ifNotCommand then
        oldWorldEvent(world, callback, params)
    end
end

function commands.sv_runCommand(self,data)
    local status, err = pcall(function()
        -- just so it doesnt run for every client
        if self.tool:getOwner().id == 1 then
            local command = data[1]
            if command == "/pay" then

                payCommand(self,data)

            elseif command == "/clearchat" then

                -- just spams the chat with spaces and clears it
                for i = 1,100 do
                    self.network:sendToClient(data.player,"cl_sendTextMessage","")
                end

            elseif command == "/shop" then

                if data[2] == "block" then
                    self.network:sendToClient(data.player,"client_openShop",{character = data.player:getCharacter(), recipeFile = "$CONTENT_DATA/Scripts/Shops/blockShop.json"})
                elseif data[2] == "wedge" then
                    self.network:sendToClient(data.player,"client_openShop",{character = data.player:getCharacter(), recipeFile = "$CONTENT_DATA/Scripts/Shops/wedgeShop.json"})
                elseif data[2] == "decor" then
                    self.network:sendToClient(data.player,"client_openShop",{character = data.player:getCharacter(), recipeFile = "$CONTENT_DATA/Scripts/Shops/decorShop.json"})
                elseif data[2] == "fittings" then
                    self.network:sendToClient(data.player,"client_openShop",{character = data.player:getCharacter(), recipeFile = "$CONTENT_DATA/Scripts/Shops/fittingsShop.json"})
                elseif data[2] == "interactive" then
                    self.network:sendToClient(data.player,"client_openShop",{character = data.player:getCharacter(), recipeFile = "$CONTENT_DATA/Scripts/Shops/interactiveShop.json"})
                elseif data[2] == "gun" then
                    self.network:sendToClient(data.player,"client_openShop",{character = data.player:getCharacter(), recipeFile = "$CONTENT_DATA/Scripts/Shops/gunShop.json"})
                end

            elseif command == "/ragdoll" then
                -- ragdolls the player
                local player = data.player
                if player ~= hostPlayer then
                    if not self.sv.ifClientsLocked then
                        local randomDirection = sm.vec3.new(math.random(500)-250,math.random(500)-250,500)
                        player:getCharacter():applyTumblingImpulse( randomDirection )
                        player:getCharacter():setTumbling( true )
                    end
                else
                    local randomDirection = sm.vec3.new(math.random(500)-250,math.random(500)-250,500)
                    player:getCharacter():applyTumblingImpulse( randomDirection )
                    player:getCharacter():setTumbling( true )
                end
            elseif command == "/msg" then 
                if not checkPlayer(tonumber(data[2])) then
                    self.network:sendToClient(data.player, "cl_sendTextMessage","#FF0000Invalid player!")
                else
                    --[[local Teams = sm.json.open("$CONTENT_DATA/Json/Teams.json")
                    local playerTeam = TEAM_checkForTeam(self,data.player)
                    local playerTeamColor = Teams[playerTeam] and Teams[playerTeam].settings.teamColor or ""]]
                    local messageString = ""
                    for i = 1,128 do
                        if tostring(data[i+2]) and data[i+2] ~= nil then
                            if i == 1 then
                                messageString = tostring(data[i+2])
                            else
                                messageString = messageString.." "..tostring(data[i+2])
                            end
                        end
                    end
                    self.network:sendToClient(checkPlayer(tonumber(data[2])), "cl_sendTextMessage","[Private Message] "..--[[playerTeamColor..]]data.player.name.."#FFFFFF: "..messageString)
                end
            elseif command == "/pl" then 
                self.network:sendToClient(data.player,"PlayerList_clientOnGuiOpen",self)
            -- team commands
            elseif command == "/createteam" then
                --TEAM_onTeamCreate(self,data[2],data[3],data.player)
            elseif command == "/editteam" then
                --TEAM_onTeamEdit(self,data.player)
            elseif command == "/inviteteam" then
                --TEAM_onTeamInvite(self,data.player,data[2])
            elseif command == "/deleteteam" then
                --TEAM_onTeamDelete(self,data.player,data[2])
            elseif command == "/acceptteam" then
                --TEAM_onTeamAccept(self,data.player,data[2])
            elseif command == "/denyteam" then
                --TEAM_onTeamDeny(self,data.player,data[2])
            elseif command == "/leaveteam" then
                --TEAM_onTeamLeave(self,data.player)
            elseif command == "/transferteam" then
                --TEAM_onTeamTransfer(self,data.player,data[2])
            elseif command == "/kickteam" then
                --TEAM_onTeamKick(self,data.player,data[2])
            elseif command == "/cancelteam" then
                --TEAM_onTeamCancel(self,data.player,data[2])
            -- host commands
            elseif command == "/govpay" then

                govPayCommand(self,data)

            elseif command == "/checkcash" then

                checkCashCommand(self,data)
            
            elseif command == "/setdp" then

                setdpCommand(self,data)

            elseif command == "/clientlock" then

                self.sv.ifClientsLocked = data.ifLimited
                _G.ifClientsLocked = data.ifLimited

                -- sets downed if the clientlock is on
                if not data.ifLimited then
                    for _,player in pairs(sm.player.getAllPlayers()) do
                        if player:getCharacter() and player ~= hostPlayer then
                            player:getCharacter():setDowned( false )
                            self.network:sendToClient(player, "cl_sendTextMessage","The host is done, you have been unlocked!")
                        end
                        sm.event.sendToPlayer( player, "server_onDataUpdate", {type = "clientLock",value = data.ifLimited} )
                    end
                end

                -- the host can set the clients lock to be active and use their inventory
                self.network:sendToClient(hostPlayer,"cl_sendTextMessage","Client lock "..tostring(not data.ifLimited and "#FF0000disabled" or "#00FF00enabled"))
                if data.ifLimited then
                    -- saves the inventory
                    local container = hostPlayer:getHotbar()
                    local inventory = {}
                    for slot = 0, container:getSize() do
                        local containerSlot = container:getItem( slot )
                        inventory[slot] = {quantity = containerSlot.quantity,uuid = containerSlot.uuid}    
                    end
                    saveToStorage(self,inventory,"inventory")
                    -- erases the inventory
                    local container = data.player:getHotbar()
                    sm.container.beginTransaction()
                    for slot = 0, container:getSize() do
                        local containerSlot = container:getItem( slot )
                        container:setItem( slot, sm.uuid.getNil(), 0)
                    end
                    sm.container.endTransaction()
                else
                    -- clears the inventory after unlimited
                    local container = data.player:getInventory()
                    sm.container.beginTransaction()
                    for slot = 0, container:getSize() do
                        local containerSlot = container:getItem( slot )
                        container:setItem( slot, sm.uuid.getNil(), 0)
                    end
                    -- sets the inventory to last known state
                    local inventory = self.storage:load().inventory
                    if inventory then
                        for slot = 0,#inventory do
                            if not inventory[slot].uuid:isNil() then
                                container:setItem( slot, inventory[slot].uuid, inventory[slot].quantity, instance )
                            end
                        end
                    end
                    sm.container.endTransaction()
                end
            elseif command == "/setspawn" then
                PVP_onSetSpawn(self,data.player)
            elseif command == "/itemDebug" then
                self.network:sendToClient(hostPlayer,"client_sendItemDebugs")
            end
        end
    end)
    if not status and err then
        self.network:sendToServer("sv_sendMessageToHost",{text = "#FF0000"..err, player = sm.localPlayer.getPlayer()})
        print(err)
    end
end

-- client

function commands.client_sendItemDebugs(self)
    print(sm.localPlayer.getPlayer())
end

-- gui functions

-- the opemDP command
function commands.client_openDPGui(self,data)
    local index = data.index
    local Currency = data.Currency

    if self.HDP == nil then
        local path = "$CONTENT_DATA/Gui/Layouts/hostDaliyPayments.layout"
        self.HDP = sm.gui.createGuiFromLayout( path )
    end
    if not index then
        self.HDPSelection = 1
        self.HDP:setText( "player_name", hostPlayer.name )
        self.HDP:setText( "payment_input", tostring(Currency[tostring(self.HDPSelection)][3]) )
    else
        if checkPlayer(tonumber(index)) then
            self.HDPSelection = tonumber(index)
            self.HDP:setText( "player_name", checkPlayer(self.HDPSelection).name)
            self.HDP:setText( "payment_input", tostring(Currency[tostring(self.HDPSelection)][3]) )
        else
            sm.gui.chatMessage("#FF0000Player invalid!")
        end
    end
    self.HDP:setButtonCallback( "last_button", "client_setdpButonClick" )
    self.HDP:setButtonCallback( "next_button", "client_setdpButonClick" )
    self.HDP:setTextChangedCallback( "payment_input", "client_setdpTextInput" )
    self.HDP:setTextAcceptedCallback( "payment_input", "client_setdpTextEntered" )
    self.HDP:open()
end

function commands.client_setdpButonClick(self,button)
    if button == "next_button" then
        if checkPlayer(self.HDPSelection+1) then
            self.HDPSelection = self.HDPSelection + 1
        else
            local ifFound = false
            for i = 1,50 do
                if checkPlayer(self.HDPSelection+i) then
                    self.HDPSelection = self.HDPSelection + i
                    ifFound = true
                end
            end
            if not ifFound then
                self.HDPSelection = 1
            end
        end
        self.HDP:setText( "player_name", checkPlayer(self.HDPSelection).name )
        self.HDP:setText( "payment_input", tostring(Currency[tostring(self.HDPSelection)][3]) )
    elseif button == "last_button" then
        if self.HDPSelection ~= 1 then
            self.HDPSelection = self.HDPSelection - 1
        else
            for i = 1,50 do
                if checkPlayer(self.HDPSelection+i) then
                    self.HDPSelection = self.HDPSelection + i
                    ifFound = true
                end
            end
        end
        self.HDP:setText( "player_name", checkPlayer(self.HDPSelection).name )
        self.HDP:setText( "payment_input", tostring(Currency[tostring(self.HDPSelection)][3]) )
    end
end

function commands.client_setdpTextInput(self,_,text)
    if tonumber(text) then
        self.HDPifCanUse = true
        self.Ammount = tonumber(text)
        self.HDP:setText( "player_name", (checkPlayer(self.HDPSelection).name or self.HDPSelection))
    else
        self.HDPifCanUse = false
        self.HDP:setText( "player_name", "#FF0000Number Invalid" )
    end
end

function commands.client_setdpTextEntered(self,_,text)
    if self.HDPifCanUse then
        sm.gui.chatMessage(checkPlayer(self.HDPSelection).name.."'s daliy pay set to $"..formatWithCommas(text))
        self.network:sendToServer("server_setDP",{amount = tonumber(text), id = self.HDPSelection})
    end
end

-- i know this is really dangerous buut
function commands.server_setDP(self,data)
    local id = data.id
    Currency = sm.json.open("$CONTENT_DATA/Json/Currency.json")
    Currency[tostring(id)][3] = data.amount
    sm.json.save( Currency, "$CONTENT_DATA/Json/Currency.json")
end

-- the shop gui
function commands.client_openShop(self,data)
    if self.user == nil then
        self.guiInterface = nil
        self.guiInterface = sm.gui.createHideoutGui()
        self.guiInterface:setVisible("BananaCount",false)
        self.guiInterface:setVisible("BerryCount",false)
        self.guiInterface:setVisible("BroccoliCount",false)
        self.guiInterface:setVisible("OrangeCount",false)
        self.guiInterface:setVisible("PineappleCount",false)
        self.guiInterface:setVisible("BeetCount",false)
        self.guiInterface:setVisible("TomatoCount",false)
        self.guiInterface:setVisible("CarrotCount",false)
        self.guiInterface:setVisible("FarmerCount",false)
        
        self.guiInterface:setContainer("Inventory", data.character:getPlayer():getInventory() )

        -- validates that all uuids are correct before opening
        local recipeJson = sm.json.open(data.recipeFile)
        for _,data in pairs(recipeJson) do
            if not isValidUUIDv4(data["itemId"]) then
                sm.gui.chatMessage("#FF0000hey there bucko, YOUR FUCKING UUIDS ARE WRONG IDIOT, also its  "..data["itemId"])
                return
            end
        end

        self.guiInterface:addGridItemsFromFile( "TradeGrid", data.recipeFile )
        self.guiInterface:setGridButtonCallback( "Trade", "client_spendCash" )
        self.guiInterface:open()
    end
end

function commands.client_spendCash( self, buttonName, index, data )
    data.player = sm.localPlayer.getPlayer()
	self.network:sendToServer( "server_spendCash", data )
end

function commands.server_spendCash( self, data )
    local boughtUuid = sm.uuid.new(data.itemId)
    local quantity = data.quantity
    local player = data.player
    local money = data.ingredientList[1].quantity
    local inventory = player:getInventory()
    Currency = sm.json.open("$CONTENT_DATA/Json/Currency.json")
    if Currency then
        if Currency[tostring(player.id)][1] > money then
            Currency[tostring(player.id)][1] = Currency[tostring(player.id)][1] - money
            sm.container.beginTransaction()
            sm.container.collect( inventory, boughtUuid, quantity, true )
            sm.container.endTransaction()
            sm.json.save( Currency, "$CONTENT_DATA/Json/Currency.json")
        else
            self.network:sendToClient(player,"cl_sendTextMessage","#FF0000Not enough money!")
        end
    end
end

-- pvp

local maxHP = 100
local respawnTime = 5
local respawnImmunity = 30 -- seconds

function commands.cl_updateSpeed(self,data)
    local player = data.player
    local speedFraction = data.speedFraction
    player.character.clientPublicData.waterMovementSpeedFraction = speedFraction
end

function commands.cl_updateHealthBar(self, hp)
    if not self.cl then
        sm.event.sendToInteractable(g_cl_interactable, "cl_updateHealthBar", hp)
    end

    if self.cl and self.cl.hud then
        self.cl.hud:setSliderData( "Health", maxHP * 10, hp * 10 )
    end
end

function commands.sv_hitboxOnProjectile( self, trigger, hitPos, hitTime, hitVelocity, _, attacker, damage, userData, hitNormal, projectileUuid )
    if not self.sv.saved.settings.pvp then return false end
    
    if isAnyOf( projectileUuid, g_potatoProjectiles ) then
        damage = damage/2
    elseif projectileUuid == sm.uuid.new("033cea84-d6ad-4eb9-82dd-f576b60c1e70") then
        damage = damage * 2.5
    else
        damage = damage - math.floor(damage/3)
    end

    local owner = PVP_sv_getHitboxOwner(self,trigger.id)

    self:sv_attack({victim = owner, attacker = attacker, damage = damage})

    return false
end

function commands.sv_attack(self, params)
    local victim = params.victim
    local attacker = params.attacker
    local damage = params.damage

    if victim ~= attacker then
        PVP_sv_updateHP({self = self, player = victim, change = -damage, attacker = attacker, ignoreSound = params.ignoreSound})
    end
end

function commands.cl_death(self)
    if self.cl then
        self.cl.death = respawnTime
    end
end

function commands.cl_onRespawn(self)
    if self.cl then
        self.cl.respawnImmunity = respawnImmunity
    end
    -- stupid fucking ui doesnt work
    self.cl.hud:destroy()
    self.cl.hud = sm.gui.createSurvivalHudGui()
    self.cl.hud:setVisible("FoodBar", false)
    self.cl.hud:setVisible("WaterBar", false)
    self.cl.hud:setVisible("BindingPanel", false)
    self.cl.hud:open()
end

function commands.cl_damageSound(self, params)
    sm.event.sendToPlayer(sm.localPlayer.getPlayer(), "cl_n_onEvent", params)
end

function commands.sv_sendAttack(self, params)
    sm.event.sendToInteractable(PVP_instance.interactable, "sv_attack", params)
end