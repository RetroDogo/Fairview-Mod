output = class()

output.maxParentCount = 1
output.maxChildCount = 256
output.connectionInput = sm.interactable.connectionType.power
output.connectionOutput = sm.interactable.connectionType.logic
output.colorNormal = sm.color.new( 0x777777ff )
output.colorHighlight = sm.color.new( 0x888888ff )

-- server

function output.server_onFixedUpdate( self, timeStep )
    if not self.interactable:getSingleParent() then
        self.network:sendToClients("client_setUv",false)
        self.interactable:setActive(false)
    end
end

function output.server_changeState( self, data )
    local state = data.state
    self.network:sendToClients("client_setUv",state)
    self.interactable:setActive(state)
end

-- client

function output.client_setUv(self,state)
    self.interactable:setUvFrameIndex( state and 6 or 0 )
end