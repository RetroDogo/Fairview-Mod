AB = class()

dofile("$CONTENT_DATA/Scripts/Currency.lua")
dofile("$CONTENT_DATA/Scripts/Utils.lua")
dofile("$CONTENT_DATA/Scripts/QueueMessages.lua")
dofile("$CONTENT_DATA/Scripts/PlayerList.lua")

-- server

function AB.server_onCreate( self )

    -- finds if autoblock already exists and deletes itself if it is
	for _,body in pairs( sm.body.getAllBodies()) do
		for _,shape in pairs(sm.body.getShapes(body)) do
			if shape.uuid == sm.uuid.new("6aa77e5b-aa34-406c-84db-a379a28f36c2") and shape ~= self.shape then
                local badboi = closestPlayerToPos(self,self.shape.worldPosition)    
                self.network:sendToClient(hostPlayer,"cl_sendTextMessage","#FF0000".. badboi.name.." placed an autoblock at "..math.floor(self.shape.worldPosition.x*4).." "..math.floor(self.shape.worldPosition.y*4).." "..math.floor(self.shape.worldPosition.z*4))
                self.shape:destroyShape()
                return 
            end
		end
    end

    local status, err = pcall(function()
        
        -- loads the player vaLue apon reload
        if not hostPlayer or hostPlayer.id ~= 1 then
            for _,player in pairs(sm.player.getAllPlayers()) do if player.id == 1 then hostPlayer = player end end
        end
        self.sv = {}
        self.sv.currenctTime = 0
        if type(self.storage:load()) == "table" then
            self.sv.tickedTime = self.storage:load().time
        end
        if not self.sv.tickedTime then self.sv.tickedTime = (1800*40)/2 end
        self.sv.playerTable = {}

    end)
    if not status and err then
        self.network:sendToClient(hostPlayer,"cl_sendTextMessage","#FF0000"..err)
        print(err)
    end
end

function AB.server_onFixedUpdate( self, timeStep )

    -- finds if autoblock already exists and deletes itself if it is
	for _,body in pairs( sm.body.getAllBodies()) do
		for _,shape in pairs(sm.body.getShapes(body)) do
			if shape.uuid == sm.uuid.new("6aa77e5b-aa34-406c-84db-a379a28f36c2") and shape ~= self.shape then
                return 
            end
		end
    end

    local status, err = pcall(function()
        if not self.sv then
            self.sv = {}
        end
        Currency_server_onFixedUpdate(self)

        -- counts the current time to get session time
        self.sv.currenctTime = self.sv.currenctTime + 1
    
        -- counts the time on the server to make life easier
        local seconds = 1800
    
        if self.sv.tickedTime >= seconds*40+1 then
            self.sv.tickedTime = 0
        else
            self.sv.tickedTime = self.sv.tickedTime + 1
        end
    
         -- runs code when a player joins
         for _,player in pairs(tableDiffValues(sm.player.getAllPlayers(),self.sv.playerTable)) do
            print("player "..player.name.." joined")
            table.insert(self.sv.playerTable, player)
    
            -- sets wallet on join
            local jsonFile = "$CONTENT_DATA/Json/Currency.json"
            Currency = sm.json.open(jsonFile) 
            if Currency then
                self.network:setClientData( {type = "wallet", value = Currency[tostring(player.id)][1], player = player} )
            end
            -- prints all queued messages on join
            server_queuePlayerJoined(self,player)

            -- sets the usernames
            for _,existantPlayer in pairs(sm.player.getAllPlayers()) do
                print("update name for  "..player.name)
                self.network:sendToClient(existantPlayer,"client_onUpdateNametags",{text = tostring(player.name.." | "..player.id),player = player,distance = 4})
            end
            
            -- put player joining code here
        end
        
        -- runs code when a player leaves
        for _,player in pairs(tableDiffValues(self.sv.playerTable,sm.player.getAllPlayers())) do
            for i,v in pairs(self.sv.playerTable) do
                if v == player then 
                    print("player "..player.name.." left")
                    table.remove(self.sv.playerTable,i)
                    -- btw the host never "leaves" so host may be broken
    
                    -- put player leaving code here
                end
            end
        end

        -- saves time every 4 seconds
        if sm.game.getCurrentTick()%160 == 0 then
            self.storage:save({time = self.sv.tickedTime})

            -- sends client data
            self.network:setClientData( {type = "currentTime", value = self.sv.currenctTime} )
            self.network:setClientData( {type = "time", value = self.sv.tickedTime} )
        end
        local Currency = sm.json.open("$CONTENT_DATA/Json/Currency.json")
        self.sv.oldCurrency = Currency
        self.network:setClientData( {type = "currency", value = Currency} )


    end)
    if not status and err then
        self.network:sendToClient(hostPlayer,"cl_sendTextMessage","#FF0000"..err)
        print(err)
    end
end

function AB.onCommand(self,data)
    if data.command == "/pl" then
        self.network:sendToClient(data.data.player,"PlayerList_clientOnGui")
    end
end

-- client

function AB.client_onCreate( self )
    local status, err = pcall(function()
        self.cl = {}
        self.cl.tickedTime = (1800*40)/2

        -- loads the player vaLue apon reload
        if not hostPlayer or hostPlayer.id ~= 1 then
            for _,player in pairs(sm.player.getAllPlayers()) do if player.id == 1 then hostPlayer = player end end
        end

        -- the main mod gui
        if not self.cl.modHUD then
            local path = "$CONTENT_DATA/Gui/Layouts/modHUD.layout"
            self.cl.modHUD = sm.gui.createGuiFromLayout( path ,false, {
                isHud = true,
                isInteractive = false,
                needsCursor = false,
                hidesHotbar = false,
                isOverlapped = false,
            })
        end
        self.cl.modHUD:open()

        -- the comapss gui
        if not self.cl.compassHUD then
            local path = "$CONTENT_DATA/Gui/Layouts/compassHUD.layout"
            self.cl.compassHUD = sm.gui.createGuiFromLayout( path ,false, {
                isHud = true,
                isInteractive = false,
                needsCursor = false,
                hidesHotbar = false,
                isOverlapped = false,
            })
        end
        self.cl.compassHUD:setVisible("CompassText0", true)
		self.cl.compassHUD:setVisible("CompassText1", false)
		self.cl.compassHUD:setVisible("CompassText2", false)
		self.cl.compassHUD:setVisible("CompassText3", false)
		self.cl.compassHUD:setVisible("CompassText4", false)
        self.cl.compassHUD:open()
    
        -- loads all nametags on join
        for _,player in pairs(sm.player.getAllPlayers()) do
            if player ~= sm.localPlayer.getPlayer() then
                local character = player:getCharacter()
                character:setNameTag(  tostring(player.name.." | "..player.id),sm.color.new(1,1,1), true, 4, 2 )
            end
        end
    end)
    if not status and err then
        self.network:sendToServer("sv_sendMessageToHost",{text = "#FF0000"..err, player = sm.localPlayer.getPlayer()})
        print(err)
    end
end

local CellSize = 64

function AB.client_onFixedUpdate( self, timeStep )
    local status, err = pcall(function()

        PlayerList_onFixedUpdate(self)

        -- loads the player vaLue apon reload
        if not hostPlayer or hostPlayer.id ~= 1 then
            for _,player in pairs(sm.player.getAllPlayers()) do if player.id == 1 then hostPlayer = player end end
        end

        -- couns current session time on client to make life better
        if self.cl.currentTime then
            self.cl.currentTime = self.cl.currentTime + 1
        end

        -- checks if the gui isnt open, then opens it if needed
        if not self.cl.modHUD:isActive() then
            self.cl.modHUD:open()
        end
        if not self.cl.compassHUD:isActive() then
            self.cl.compassHUD:open()
        end
    
        -- tick self.ticked every tick and do cal to find out time
        local seconds = 1800
        if not self.cl.tickedTime then
            self.cl.tickedTime = (1800*40)/2
        end
        if self.cl.tickedTime >= seconds*40+1 then
            self.cl.tickedTime = 0
        else
            self.cl.tickedTime = self.cl.tickedTime + 1
        end
        sm.game.setTimeOfDay( self.cl.tickedTime/(seconds*40) )
        sm.render.setOutdoorLighting( self.cl.tickedTime/(seconds*40) )
    
        -- sets the time in the gui
        local Seconds = formatTwoDigits(math.floor(self.cl.tickedTime/40)-math.floor(self.cl.tickedTime/2400)*60)
        local AMPMHour, isPM = convertToAmPm(tonumber(formatTwoDigits(math.floor(self.cl.tickedTime/2400))))
        local timeString = tostring(AMPMHour..":"..Seconds.." "..tostring(isPM and "PM" or "AM"))
        self.cl.modHUD:setText( "time", timeString)

        -- sets the info for the compass
        local mfloor = math.floor
		local mfmod = math.fmod
        local character = sm.localPlayer.getPlayer().character
		
		local coordinates = mfloor( character.worldPosition.x).. ",".. mfloor( character.worldPosition.y)
        local cellCoord = mfloor( character.worldPosition.x / CellSize )..","..mfloor( character.worldPosition.y / CellSize )
		local direction = character.direction
		local yaw = math.atan2( direction.y, direction.x )
		local rot = math.deg( yaw )
		local textDegrees = math.ceil( rot-90 )

		if textDegrees > 0 then
			textDegrees = textDegrees-360
		end
		textDegrees = math.abs(textDegrees)

        local compass = " --------- N.E --------- E --------- S.E ---------- S --------- S.W --------- W --------- N.W --------- N"
        local compassLength = #compass -- Length of the compass string
        local rangeMax = 360 -- Full 360-degree range
        
        -- Map `rot` to the correct position, ensuring proper alignment
        local position = math.floor(((rangeMax - rot + 90) % rangeMax) / rangeMax * compassLength) + 1
        
        -- Calculate the range of characters to display
        local displayLength = 65
        local halfRange = math.floor(displayLength / 2)
        
        -- Build the display, wrapping around if necessary
        local display = ""
        for i = -halfRange, halfRange do
            local index = (position + i - 1) % compassLength + 1
            display = display .. compass:sub(index, index)
        end
        

		self.cl.compassHUD:setText( "CompassText0", display )

		self.cl.compassHUD:setText( "CompassDegree", tostring(textDegrees).."°" )
		self.cl.compassHUD:setText( "CoordText", coordinates )
        self.cl.compassHUD:setText( "CellText", cellCoord )

    end)
    if not status and err then
        self.network:sendToServer("sv_sendMessageToHost",{text = "#FF0000"..err, player = sm.localPlayer.getPlayer()})
        print(err)
    end
end

function AB.client_onClientDataUpdate( self, data )
    print(data.type)
    local status, err = pcall(function()
        if data.type == "time" then
            self.cl.tickedTime = data.value
        elseif data.type == "currency" then
            self.cl.Currency = data.value
            self.cl.modHUD:setText( "wallet_amount", "$"..formatWithCommas(data.value[tostring(sm.localPlayer.getPlayer().id)][1]))
        elseif data.type == "currentTime" then
            self.cl.currentTime = data.value
        end
    end)
    if not status and err then
        self.network:sendToServer("sv_sendMessageToHost",{text = "#FF0000"..err, player = sm.localPlayer.getPlayer()})
        print(err)
    end
end

function AB.PlayerList_clientOnGui(self)
    if self.cl.playerList then
        self.cl.playerList:close()
        self.cl.playerList:destroy()
        self.cl.playerList = nil
    else
        local players = sm.player.getAllPlayers()
        self.cl.playerList  = sm.gui.createGuiFromLayout( "$CONTENT_DATA/Gui/layouts/playerListGui.layout" ,false, {
            isHud = true,
            isInteractive = false,
            needsCursor = false,
            hidesHotbar = false,
            isOverlapped = false,
        })
        self.cl.playerList:open()
    end
end

-- fired events from server

function AB.client_onUpdateNametags(self,data)
    local player = data.player
    local distance = data.distance
    local character = player:getCharacter()
    if player ~= sm.localPlayer.getPlayer() then
        if player:getCharacter():isCrouching() then
            character:setNameTag( tostring(data.text),sm.color.new(1,1,1), true, distance/4, distance/8 )
        else
            character:setNameTag( tostring(data.text),sm.color.new(1,1,1), true, distance, distance/2 )
        end
    end
end

function AB.cl_sendTextMessage(self,text)
    sm.gui.chatMessage(text)
end

function AB.sv_sendMessageToHost(self,data)
    local text = data.text
    local player = data.player
    if text and player then
        self.network:sendToClient(hostPlayer,"cl_sendTextMessage",text.." from #FFFFFF"..player.name.."'s#FFFFFF client")
    end
end
