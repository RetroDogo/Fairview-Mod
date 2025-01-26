ATM = class()

dofile("$CONTENT_DATA/Scripts/Utils.lua")

-- server stuff

function ATM.server_onCreate( self )

end

function ATM.server_onDestroy( self )

end

function ATM.server_onRefresh( self )

end

function ATM.server_onFixedUpdate( self, timeStep )
    if not hostPlayer then
        for _,player in pairs(sm.player.getAllPlayers()) do if player.id == 1 then hostPlayer = player end end
    end
end

function ATM.sv_requestCurrency(self,data)
    local character = data[1]
    local jsonFile = "$CONTENT_DATA/Json/Currency.json"
    local Currency = sm.json.open(jsonFile)
    self.network:sendToClient( character:getPlayer(), "client_openGui", {Currency, character} )
end

function ATM.sv_requestTransfer(self,data)
    -- negitive means to pull from bank
    local character = data[1]
    local player = character:getPlayer()
    local Amount = data[2]
    local jsonFile = "$CONTENT_DATA/Json/Currency.json"
    local Currency = sm.json.open(jsonFile)
    if Amount >= 0 then
        if Currency[tostring(player.id)][1] >= Amount then
            Currency[tostring(player.id)][1] = Currency[tostring(player.id)][1] - Amount
            Currency[tostring(player.id)][2] = Currency[tostring(player.id)][2] + Amount
            if player ~= hostPlayer then
                self.network:sendToClient(hostPlayer,"cl_sendTextMessage",tostring("#00FF00-LOG-#FFFFFF "..player.name.." deposited $"..formatWithCommas(Amount)))
            end
        else
            self.network:sendToClient(hostPlayer,"cl_sendTextMessage","#FF0000Not enough money in wallet!")
        end
    else
        if Currency[tostring(player.id)][2] >= -Amount then
            Currency[tostring(player.id)][1] = Currency[tostring(player.id)][1] - Amount
            Currency[tostring(player.id)][2] = Currency[tostring(player.id)][2] + Amount
            if player ~= hostPlayer then
                self.network:sendToClient(hostPlayer,"cl_sendTextMessage",tostring("#00FF00-LOG-#FFFFFF "..player.name.." withdrew $"..formatWithCommas(-Amount)))
            end
        else
            self.network:sendToClient(hostPlayer,"cl_sendTextMessage","#FF0000Not enough money in bank!")
        end
    end
    local jsonFile = "$CONTENT_DATA/Json/Currency.json"
    sm.json.save( Currency, jsonFile)
end

-- client stuff

-- sends a message to the client.
function ATM.cl_sendTextMessage(self,text)
    sm.gui.chatMessage(text)
end

function ATM.client_onCreate( self )
    self.ifCanUse = true
    self.Amount = 0
    self.character = nil
end

function ATM.client_onDestroy( self )

end

function ATM.client_onRefresh( self )

end

function ATM.client_onFixedUpdate( self, timeStep )

end

function ATM.client_openGui(self,data)
    local Currency = data[1]
    local character = data[2]
    if self.gui ~= nil then
        self.gui:destroy()
        self.gui = nil
    end
    if self.gui == nil then
        local path = "$CONTENT_DATA/Gui/Layouts/ATM.layout"
        self.gui = sm.gui.createGuiFromLayout( path )
    end
    self.Amount = 0
    self.gui:setText( "bank_caption", character:getPlayer().name.."'s Bank" )
    self.gui:setText( "bank_amount", "$"..formatWithCommas(Currency[tostring(character:getPlayer().id)][2]) )
    self.gui:setText( "input_amount", "Set Amount" )
    self.gui:setText( "user_input", "0" )
    self.gui:setText( "button_1", "Withdraw FairBucks" )
    self.gui:setText( "button_2", "Deposit FairBucks" )
    self.gui:setButtonCallback( "button_1", "client_onButtonPress" )
    self.gui:setButtonCallback( "button_2", "client_onButtonPress" )
    self.gui:setTextChangedCallback( "user_input", "client_onTextChange" )
    self.gui:open()
end

function ATM.client_onInteract(self,character,state)
	-- opens the gui and sets the values
	if state == true then
        self.network:sendToServer("sv_requestCurrency", {character})
        self.character = character
	end
end

function ATM.client_onButtonPress(self,button)
    if self.ifCanUse and self.Amount > 0 then
        if button == "button_1" then
            self.network:sendToServer("sv_requestTransfer", {self.character,-self.Amount})
            self.gui:close()
            self.Amount = 0
        elseif button == "button_2" then
            self.network:sendToServer("sv_requestTransfer", {self.character,self.Amount})
            self.gui:close()
            self.Amount = 0
        end
    end
end

function ATM.client_onTextChange(self,_,text)
    if tonumber(text) then
        self.ifCanUse = true
        self.Amount = tonumber(text)
        if self.Amount > 0 then
            self.gui:setText( "button_1", "Withdraw FairBucks" )
            self.gui:setText( "button_2", "Deposit FairBucks" )
        else
            self.ifCanUse = false
            self.gui:setText( "button_1", "#FF0000Number Invalid" )
            self.gui:setText( "button_2", "#FF0000Number Invalid" )
        end
    else
        self.ifCanUse = false
        self.gui:setText( "button_1", "#FF0000Number Invalid" )
        self.gui:setText( "button_2", "#FF0000Number Invalid" )
    end
end