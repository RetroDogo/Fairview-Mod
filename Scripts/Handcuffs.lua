HC = class()

dofile("$CONTENT_DATA/Scripts/Utils.lua")

-- server

function HC.server_onCreate( self )
    if not _G.lockedPlayers then
        _G.lockedPlayers = {}
    end
    self.sv = {}
    self.sv.isActive = false
    self.sv.drag = {state = false,player = nil}
end

function HC.server_onFixedUpdate( self, timeStep )

    if self.sv.drag.state then
        local targetPos = self.tool:getOwner().character.worldPosition+(self.tool:getOwner().character:getDirection()*sm.vec3.new(1.5,1.5,1.5))+(self.tool:getOwner().character.velocity/5)
        local forcePos = -(self.sv.drag.player.character.worldPosition-targetPos)-(self.sv.drag.player.character.velocity/7)
        sm.physics.applyImpulse(self.sv.drag.player.character, forcePos*sm.vec3.new(100,100,50),true)
    end

end

function HC.server_handcuff( self, data )
    local player = data.player
    local owner = self.tool:getOwner()

    -- checks if the player exists
    if not player then
        return
    end

    local locked = findValueInTable(_G.lockedPlayers,player) and true or false
    if not locked then
        table.insert(_G.lockedPlayers,player)
        self.network:sendToClient(player, "cl_sendAlertMessage",{text = "#FF0000You got handcuffed!", time = 2})
        self.network:sendToClient(self.tool:getOwner(), "cl_sendAlertMessage",{text = "Handcuffed "..player.name.."#FFFFFF!", time = 2})
    else
        smartRemove(_G.lockedPlayers,player)
        self.network:sendToClient(player, "cl_sendAlertMessage",{text = "You got released from handcuffs!", time = 2})
        self.network:sendToClient(self.tool:getOwner(), "cl_sendAlertMessage",{text = "Released "..player.name.."#FFFFFF from handcuffs!", time = 2})
    end
end

function HC.server_carryPlayer( self, data )
    local player = data.player
    local state = data.state

    -- sets the data
    local locked = findValueInTable(_G.lockedPlayers,player) and true or false
    if locked then
        if data.player.character then
            self.sv.drag = {state = state, player = player}
        else
            self.sv.drag = {state = false, player = nil}
        end
    else
        self.sv.drag = {state = false, player = nil}
    end
    
end

-- client

function HC.cl_updateSpeed(self,data)
    local player = data.player
    local speedFraction = data.speedFraction
    player.character.clientPublicData.waterMovementSpeedFraction = speedFraction
end

function HC.client_onCreate( self )
    self.cl = {}
    self.cl.primaryActive = false
    self.cl.secondaryActive = false
end

function HC.client_onEquippedUpdate( self, primaryState, secondaryState, forceBuild )
    if self.cl.primaryActive ~= (primaryState == 2) then
        self.cl.primaryActive = (primaryState == 2)
        if self.cl.primaryActive then
            self.network:sendToServer("server_handcuff",{player = getFacingPlayer(self)})
        end
    end
    if self.cl.secondaryActive ~= (secondaryState == 2) then
        self.cl.secondaryActive = (secondaryState == 2)
        self.network:sendToServer("server_carryPlayer",{player = getFacingPlayer(self),state = self.cl.secondaryActive})
    end
	return true, true
end

function HC.cl_sendTextMessage(self,text)
    sm.gui.chatMessage(text)
end

function HC.cl_sendAlertMessage(self,data)
    local text = data.text
    local time = data.time
    sm.gui.displayAlertText( text, time )
end

-- functions

function getFacingPlayer(self)
    local result, raycastResult = sm.localPlayer.getRaycast( 1.5 )
    if result and raycastResult:getCharacter() then
        if raycastResult:getCharacter():isPlayer() then
            return raycastResult:getCharacter():getPlayer()
        end
    end
    return false
end