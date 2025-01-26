AU = class()

dofile("$CONTENT_DATA/Scripts/Utils.lua")
dofile("$CONTENT_DATA/Scripts/Currency.lua")

bannedUuids = {
    -- Uuids                                  Names
    {"9fde0601-c2ba-4c70-8d5c-2a7a9fdd122b", "Spudling Gun"},
    {"24001201-40dd-4950-b99f-17d878a9e07b", "Large Explosive"},
    {"8d3b98de-c981-4f05-abfe-d22ee4781d33", "Small Explosive"}
}

Tool = nil

-- server

function AU.server_onCreate( self )
    self.sv = {}
    self.sv.tickedTime = (1800*40)/2
    self.sv.playerTable = {}
    self.sv.ifClientsLocked = true
end

function AU.server_onFixedUpdate( self, timeStep )
    Currency_server_onFixedUpdate(self)

    -- loads the player vaLue apon reload
    if not hostPlayer or hostPlayer.id ~= 1 then
        for _,player in pairs(sm.player.getAllPlayers()) do if player.id == 1 then hostPlayer = player end end
    end

    self.network:setClientData( {type = "time", tickedTime = self.sv.tickedTime} )

     -- sends time to clients when new clients join
    for _,player in pairs(tableDiffValues(sm.player.getAllPlayers(),self.sv.playerTable)) do
        print("player "..player.name.." joined")
        table.insert(self.sv.playerTable, player)
        -- put player joining code here
    end

    -- removes player from sv.playerTable when rejoining
    for _,player in pairs(tableDiffValues(self.sv.playerTable,sm.player.getAllPlayers())) do
        for i,v in pairs(self.sv.playerTable) do
            if v == player then print("player "..player.name.." left") table.remove(self.sv.playerTable,i) end
            -- put player leaving code here
        end
    end

     -- counts the time on the server to make life easier
    local seconds = 1800

    if not self.sv.tickedTime then
        self.sv.tickedTime = (1800*40)/2
    end

    if self.sv.tickedTime >= seconds*40+1 then
        self.sv.tickedTime = 0
    else
            self.sv.tickedTime = self.sv.tickedTime + 1
    end

end

-- client

-- sends a message to the client.
function AU.cl_sendTextMessage(self,text)
    sm.gui.chatMessage(text)
end

-- sends a message to the client.
function AU.cl_sendAlertMessage(self,text)
    sm.gui.displayAlertMessage(text)
end

function AU.client_onCreate( self )
    self.cl = {}
    self.cl.tickedTime = (1800*40)/2
    
    -- the main mod gui
    if self.cl.modHUD == nil then
        local path = "$CONTENT_DATA/Gui/Layouts/modHUD.layout"
        self.cl.modHUD = sm.gui.createGuiFromLayout( path ,false, {
            isHud = true,
            isInteractive = false,
            needsCursor = false,
            hidesHotbar = false,
            isOverlapped = false,
        }
        
        )
        self.cl.modHUD:open()
    end
end

function AU.client_onFixedUpdate( self, timeStep )

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

end

function AU.client_onClientDataUpdate( self, clientData )
    if clientData.type == "time" then
        self.cl.tickedTime = clientData.tickedTime
    elseif clientData.type == "wallet" then
        self.cl.modHUD:setText( "wallet_amount", "$"..formatWithCommas(clientData.wallet[tostring(sm.localPlayer.getPlayer().id)][1]))
    end
end