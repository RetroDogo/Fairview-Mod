function Currency_server_onFixedUpdate(self)

    -- loads the data and then checks if the host and goverment exists then fixes it.
    if sm.game.getCurrentTick()%40 == 0 then
        local Currency = sm.json.open("$CONTENT_DATA/Json/Currency.json")
    
        if Currency then
            local BeginningMoney = 20000 -- beginning money
            local BeginningDailyPay = 500 -- beginning daily pay
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
                    Currency[tostring(id)] = {BeginningMoney,0,BeginningDailyPay}
                    
                    -- clears most starting items
                    local spawnedItems = {
                        "8c7efc37-cd7c-4262-976e-39585f8527bf", -- connect tool
                        "5cc12f03-275e-4c8e-b013-79fc0f913e1b", -- lift
                        "c60b9627-fc2b-4319-97c5-05921cb976c6", -- paint tool
                        "fdb8b8be-96e7-4de0-85c7-d2f42e4f33ce",  -- weld tool
                        "af89c0c4-d2bb-44dd-8300-caf29beb364c" -- hands
                    }
                    local player = checkPlayer(tonumber(id))
                    -- clears the inventory and sets it to default tools on first join
                    if player then
                        local inventory = player:getInventory()
                        sm.container.beginTransaction()
                        for slot = 0, inventory:getSize() do
                            inventory:setItem( slot, sm.uuid.getNil(), 0)
                        end
                        for _,uuid in pairs(spawnedItems) do
                            sm.container.collect( inventory, sm.uuid.new(uuid), 1)
                        end
                        sm.container.endTransaction()
                    end
                    -- first time joining code
                else
                    Currency["Goverment"] = {1000000}
                end
            end
        else
            local Currency = {}
            Currency["Goverment"] = {1000000}
            Currency["1"] = {BeginningMoney,0,500}
        end
        sm.json.save( Currency, "$CONTENT_DATA/Json/Currency.json")

    end

    -- if Currency changes send the info to the client
    local Currency = sm.json.open("$CONTENT_DATA/Json/Currency.json")
    for id,value in pairs(Currency) do
        if not self.sv.Currency then
            self.sv.Currency = {}
            self.sv.Currency[id] = Currency[id][1]
        end
        if id ~= "Goverment" and checkPlayer(tonumber(id)) then
            if Currency then
                if Currency[id] then
                    if Currency[id][1] ~= self.sv.Currency[id] then
                        self.sv.Currency[id] = Currency[id][1]
                        self.network:setClientData( {type = "wallet", value = Currency[tostring(id)][1], player = checkPlayer(tonumber(id))} )
                    end
                end
            end
        end
    end

    -- adds to peoples money after every day
    if self.sv.tickedTime == 0 then
        for _,player in pairs(sm.player.getAllPlayers()) do
            local Currency = sm.json.open("$CONTENT_DATA/Json/Currency.json")
            Currency[tostring(player.id)][1] = Currency[tostring(player.id)][1] + Currency[tostring(player.id)][3]
            self.network:sendToClient(player, "cl_sendTextMessage","The day has ended! Your daily paycheck is $"..formatWithCommas(Currency[tostring(player.id)][3]))
            sm.json.save( Currency, "$CONTENT_DATA/Json/Currency.json")
        end
    end
    
end

function payCommand(self,data)
    -- allows anyone to gift eachother fairBucks!
    local sender = data.player
    local receiver = checkPlayer(tonumber(data[2]))
    Currency = sm.json.open("$CONTENT_DATA/Json/Currency.json")
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
    sm.json.save( Currency, "$CONTENT_DATA/Json/Currency.json")
end

function govPayCommand(self,data)
    -- the host can pay with the goverment
    local receiver = checkPlayer(tonumber(data[2]))
    Currency = sm.json.open("$CONTENT_DATA/Json/Currency.json")
    if receiver then
        Currency["Goverment"][1] = Currency["Goverment"][1] - data[3]
        Currency[tostring(receiver.id)][1] = Currency[tostring(receiver.id)][1] + data[3]
        sm.json.save( Currency, "$CONTENT_DATA/Json/Currency.json")
        self.network:sendToClient(hostPlayer,"cl_sendTextMessage","#00FF00-LOG-#FFFFFF Goverment paid "..receiver.name.." $"..formatWithCommas(data[3]))
        self.network:sendToClient(receiver,"cl_sendTextMessage","Goverment paid you $"..formatWithCommas(data[3]))
    else
        self.network:sendToClient(data.player,"cl_sendTextMessage","#FF0000Player invalid!")
    end
end

function checkCashCommand(self,data)
    -- the host can check others fairBuck
    local player = checkPlayer(tonumber(data[2]))
    Currency = sm.json.open("$CONTENT_DATA/Json/Currency.json")
    if player then
        self.network:sendToClient(hostPlayer,"cl_sendTextMessage",player.name.."'s Wallet: $"..formatWithCommas(Currency[tostring(player.id)][1]).." Bank: $"..formatWithCommas(Currency[tostring(player.id)][2]).." DP: $"..formatWithCommas(Currency[tostring(player.id)][3]))
    elseif data[2] == "gov" or data[2] == "goverment" or data[2] == "city" or data[2] == "fv" then
        self.network:sendToClient(hostPlayer,"cl_sendTextMessage","Goverment: $"..formatWithCommas(Currency["Goverment"][1]))
    else
        self.network:sendToClient(hostPlayer,"cl_sendTextMessage","#FF0000Player invalid!")
    end
end

function setdpCommand(self,data)
    -- the host can set others daily pay
    Currency = sm.json.open("$CONTENT_DATA/Json/Currency.json")
    self.network:sendToClient(hostPlayer,"client_openDPGui",{index = data[2],Currency = Currency})
end

-- guis

function client_openDPGui(self)
    print(self)
end