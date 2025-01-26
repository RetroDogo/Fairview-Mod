function Currency_server_onFixedUpdate(self)

    -- loads the data and then checks if the host and goverment exists then fixes it.
    if sm.game.getCurrentTick()%80 == 0 then
        -- load the data.
         local jsonFile = "$CONTENT_DATA/Json/Currency.json"
         Currency = sm.json.open(jsonFile) 
    
        if Currency then
            local BeginningMoney = 50000 -- beginning money
            local currencyIds = {}
            local playerIds = {"Goverment"}
        
            for id,_ in pairs(Currency) do
               table.insert(currencyIds,tostring(id))
            end
        
            for _,player in pairs(sm.player.getAllPlayers()) do
                table.insert(playerIds,tostring(player.id))
            end
        
            for _,id in pairs(tableDiffValues(playerIds,currencyIds)) do
                if tostring(id) ~= "Goverment" then
                    Currency[tostring(id)] = {BeginningMoney,0,500,checkPlayer(tonumber(id)).name}
                else
                    Currency[tostring(id)] = {1000000}
                end
            end
        else
            Currency = {}
            Currency["Goverment"] = {1000000}
            Currency["1"] = {BeginningMoney,0,500}
        end
        sm.json.save( Currency, jsonFile)
    end

    -- adds to peoples money after every day
    if self.sv.tickedTime == 0 then
        for _,player in pairs(sm.player.getAllPlayers()) do
            local jsonFile = "$CONTENT_DATA/Json/Currency.json"
            Currency = sm.json.open(jsonFile) 
            Currency[tostring(player.id)][1] = Currency[tostring(player.id)][1] + Currency[tostring(player.id)][3]
            self.network:sendToClient(player, "cl_sendTextMessage","The day has ended! Your daily paycheck is $"..formatWithCommas(Currency[tostring(player.id)][3]))
            sm.json.save( Currency, jsonFile)
        end
    end

    -- sends all respective clients to set wallet data every second
    if sm.game.getCurrentTick()%40 == 0 then
        local jsonFile = "$CONTENT_DATA/Json/Currency.json"
        Currency = sm.json.open(jsonFile) 
        self.network:setClientData({type = "wallet", wallet = Currency})
    end
    
end

function payCommand(self,data)
    -- allows anyone to gift eachother fairBucks!
    local sender = data.player
    local receiver = checkPlayer(tonumber(data[2]))
    local jsonFile = "$CONTENT_DATA/Json/Currency.json"
    local Currency = sm.json.open(jsonFile)
    if receiver then
        if data[3] > 0 then
            if data[3] <= Currency[tostring(sender.id)][1] then
                if sender ~= receiver then
                    if getDistance(sender:getCharacter():getWorldPosition(),receiver:getCharacter():getWorldPosition()) < 4 then
                        Currency[tostring(sender.id)][1] = Currency[tostring(sender.id)][1] - data[3]
                        Currency[tostring(receiver.id)][1] = Currency[tostring(receiver.id)][1] + data[3]
                        self.network:sendToClient(sender,"cl_sendTextMessage","Paid "..receiver.name.." $"..formatWithCommas(data[3]))
                        self.network:sendToClient(receiver,"cl_sendTextMessage",sender.name.." paid you $"..formatWithCommas(data[3]))
                        if sender ~= hostPlayer and receiver ~= hostPlayer then
                            self.network:sendToClient(hostPlayer,"cl_sendTextMessage","#00FF00-LOG-#FFFFFF "..sender.name.." sent "..receiver.name.." $"..formatWithCommas(data[3]))
                        end
                    else
                        self.network:sendToClient(data.player,"cl_sendTextMessage","#FF0000Too far to pay!")
                    end
                else
                    self.network:sendToClient(data.player,"cl_sendTextMessage","#FF0000You cant pay yourself!")
                end
            else
                self.network:sendToClient(data.player,"cl_sendTextMessage","#FF0000Not enough money!")
            end
        else
            self.network:sendToClient(data.player,"cl_sendTextMessage","#FF0000You cant take money!")
        end
    elseif data[2] == "gov" or data[2] == "goverment" or data[2] == "city" or data[2] == "fv" then
        if data[3] >= 0 then
            if data[3] <= Currency[tostring(sender.id)][1] then
                Currency[tostring(sender.id)][1] = Currency[tostring(sender.id)][1] - data[3]
                Currency["Goverment"][1] = Currency["Goverment"][1] + data[3]
                self.network:sendToClient(sender,"cl_sendTextMessage","Paid goverment $"..formatWithCommas(data[3]))
                if sender ~= hostPlayer then
                    self.network:sendToClient(hostPlayer,"cl_sendTextMessage","#00FF00-LOG-#FFFFFF "..sender.name.."sent Goverment $"..formatWithCommas(data[3]))
                end
            else
                self.network:sendToClient(data.player,"cl_sendTextMessage","#FF0000Not enough money!")
            end
        else
            self.network:sendToClient(data.player,"cl_sendTextMessage","#FF0000You cant take money!")
        end
    else
        self.network:sendToClient(data.player,"cl_sendTextMessage","#FF0000Player invalid!")
    end
    sm.json.save( Currency, jsonFile)
end

function govPayCommand(self,data)
    -- the host can pay with the goverment
    local receiver = checkPlayer(data[2])
    local jsonFile = "$CONTENT_DATA/Json/Currency.json"
    local Currency = sm.json.open(jsonFile)
    if receiver then
        Currency["Goverment"][1] = Currency["Goverment"][1] - data[3]
        Currency[tostring(receiver.id)][1] = Currency[tostring(receiver.id)][1] + data[3]
        sm.json.save( Currency, jsonFile)
        self.network:sendToClient(hostPlayer,"cl_sendTextMessage","#00FF00-LOG-#FFFFFF Goverment paid "..receiver.name.." $"..formatWithCommas(data[3]))
        self.network:sendToClient(receiver,"cl_sendTextMessage","Goverment paid you $"..formatWithCommas(data[3]))
    else
        self.network:sendToClient(data.player,"cl_sendTextMessage","#FF0000Player invalid!")
    end
end

function checkCashCommand(self,data)
    -- the host can check others fairBucks
    local jsonFile = "$CONTENT_DATA/Json/Currency.json"
    local Currency = sm.json.open(jsonFile)
    if player then
        self.network:sendToClient(hostPlayer,"cl_sendTextMessage",player.name.."'s Wallet: $"..formatWithCommas(Currency[tostring(player.id)][1]).." Bank: $"..formatWithCommas(Currency[tostring(player.id)][2]))
    elseif data[2] == "gov" or data[2] == "goverment" or data[2] == "city" or data[2] == "fv" then
        self.network:sendToClient(hostPlayer,"cl_sendTextMessage","Goverment: $"..formatWithCommas(Currency["Goverment"][1]))
    else
        self.network:sendToClient(hostPlayer,"cl_sendTextMessage","#FF0000Player invalid!")
    end
end

function setdpCommand(self,data)
    -- the host can set others daily pay
    if data[2] then
        local player = checkPlayer(data[2])
        if player then
        else
            self.network:sendToClient(hostPlayer,"cl_sendTextMessage","#FF0000Player invalid!")
        end
    else
        self.network:sendToClient(hostPlayer,"client_openDPGui")
    end
end