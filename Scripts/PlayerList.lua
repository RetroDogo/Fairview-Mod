function PlayerList_onFixedUpdate(self)

    -- updates the player tines client side
    for i,count in pairs(self.cl.playerSessionTime) do
        self.cl.playerSessionTime[i] = self.cl.playerSessionTime[i] + 1
    end

    if self.cl.playerList then
        local players = sm.player.getAllPlayers()
        
        -- counts total players though currency
        local count = 0
        for _ in pairs(self.cl.Currency) do
            count = count + 1
        end
        
        -- sets the data up at the top
        self.cl.playerList:setText( "topTextBox 2", "Total Players: "..tostring(count-1) )
        self.cl.playerList:setText( "topTextBox 3", "Current Players: "..tostring(#players) )
        self.cl.playerList:setText( "topTextBox 1", "Host: "..hostPlayer.name )
        self.cl.playerList:setText( "topTextBox 4", "Time: "..tickToTime(sm.game.getCurrentTick()) )
        self.cl.playerList:setText( "topTextBox 5", "Session: ".. tickToTime(self.cl.currentTime) )
    
        -- enables the right background
        self.cl.playerList:setVisible( "BG 1", #players<5 )
        self.cl.playerList:setVisible( "BG 2", (#players>5 and #players<10))
        self.cl.playerList:setVisible( "BG 3", (#players>10 and #players<15) )
        self.cl.playerList:setVisible( "BG 4", (#players>15 and #players<20) )
        self.cl.playerList:setVisible( "BG 5", (#players>20 and #players<25) )
        self.cl.playerList:setVisible( "BG 6", #players>30 )
        local playerList = {}
        -- Convert players into a playerList for easiness
        for _, player in pairs(players) do
            table.insert(playerList, {id = player.id, name = player.name})
        end
    
        -- Sort playerList by player ID
        table.sort(playerList, function(a, b)
            return a.id < b.id
        end)
    
        -- Update the UI to show players in order with least indices
        local index = 1
        for _, player in ipairs(playerList) do
            if index <= 30 then
                -- Display the player's name and id
                self.cl.playerList:setText("nameText " .. tostring(index), player.name .. " | " .. tostring(player.id))
                self.cl.playerList:setText("extraText " .. tostring(index), player.id == 1 and tickToTime(self.cl.currentTime) or 
                    self.cl.playerSessionTime[player.id]~=nil and tickToTime(self.cl.playerSessionTime[player.id]) or "Unknown"
                )
                self.cl.playerList:setVisible("playerBox " .. tostring(index), true)
                index = index + 1
            else
                break
            end
        end
    
        -- Hide unused slots beyond the number of players
        for i = index, 30 do
            self.cl.playerList:setVisible("playerBox " .. tostring(i), false)
        end
    end
end

function reorderTableByValueSize(tbl)
    -- Create a list of keys and their corresponding value sizes
    local sizeList = {}
    for key, value in pairs(tbl) do
        if type(value.id) == "number" then
            table.insert(sizeList, {key = key, size = math.abs(value.id)}) -- Numbers use absolute value
        end
    end

    -- Sort the sizeList by value size in ascending order
    table.sort(sizeList, function(a, b) return a.size < b.size end)

    -- Create a new table with reordered indices
    local newTable = {}
    for index, entry in ipairs(sizeList) do
        newTable[index] = tbl[entry.key]
    end

    return newTable
end