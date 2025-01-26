function server_queueMessage(self,message,id)
    local player = checkPlayer(tonumber(id))
    if player then
        self.network:sendToClient(player,"cl_sendTextMessage",tostring(message))
    else
        local jsonFile = "$CONTENT_DATA/Json/QueueMessages.json"
        local QueueMessages = sm.json.open(jsonFile)
        if QueueMessages then
            if not QueueMessages[tostring(id)] then
                QueueMessages[tostring(id)] = {}
            end
            table.insert(QueueMessages[tostring(id)],{tostring(message),sm.game.getCurrentTick()})
        else
            QueueMessages = {{}}
        end
        sm.json.save( QueueMessages, jsonFile)
    end
end

function server_queuePlayerJoined(self,player)
    local jsonFile = "$CONTENT_DATA/Json/QueueMessages.json"
    local QueueMessages = sm.json.open(jsonFile)
    if QueueMessages then
        for id,_ in pairs(QueueMessages) do
            if tonumber(id) == player.id then
                for _,message in pairs(QueueMessages[id]) do
                    self.network:sendToClient(player,"cl_sendTextMessage",tostring("#00FF00"..ticksToTimeDifference(message[2],sm.game.getCurrentTick()).." ago #FFFFFF"..message[1]))
                end
                for i = 1, #QueueMessages[id] do
                    table.remove(QueueMessages[id])
                end
                print(QueueMessages)
            end
        end
    else
        QueueMessages = {{}}
    end
    sm.json.save( QueueMessages, jsonFile)
end