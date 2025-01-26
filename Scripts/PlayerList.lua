function PlayerList_updateGui(self)
    if self.sv.playerList then

    else
        print("goober. *facepalm* you dont have a gui to edit.")
    end
end

function commands.PlayerList_clientOnGuiOpen(self)
    self.sv.playerList = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/layouts/playerListGui.layout",true)
    -- enables the right background
    local players = sm.player.getAllPlayers()
    self.sv.playerList:setVisible( "BG 1", #players<5 )
    self.sv.playerList:setVisible( "BG 2", (#players>5 and #players<10))
    self.sv.playerList:setVisible( "BG 3", (#players>10 and #players<15) )
    self.sv.playerList:setVisible( "BG 4", (#players>15 and #players<20) )
    self.sv.playerList:setVisible( "BG 5", (#players>20 and #players<25) )
    self.sv.playerList:setVisible( "BG 6", #players>30 )
    for id,player in pairs(players) do
        
    end
    self.sv.playerList:open()
end