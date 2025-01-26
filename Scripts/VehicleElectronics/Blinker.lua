blinker = class()

blinker.maxParentCount = 256
blinker.maxChildCount = 256
blinker.connectionInput = sm.interactable.connectionType.logic + sm.interactable.connectionType.seated
blinker.connectionOutput = sm.interactable.connectionType.logic
blinker.colorNormal = sm.color.new( 0x777777ff )
blinker.colorHighlight = sm.color.new( 0x888888ff )

-- server

local childrenUuids = {
    ["440f3f05-4258-489a-aafe-9fc6057e17ae"] = "left",
    ["6681ce73-ce3d-4af0-a51c-0390b1dd501c"] = "right"
}

function blinker.server_onCreate( self )
    self.Active = false
    self.offset = 0
end

function blinker.server_onFixedUpdate( self, timeStep )

    -- fires an event when an input is recived
    for _,interactable in pairs(self.interactable:getParents()) do
        if interactable.shape.uuid ~= sm.uuid.new('955f789f-aadb-40b2-a54f-d4ae9d025c14') and not interactable:hasSteering() then
            if interactable.active == true then
                -- fires when an input is recived
                self.Active = true
                break
            end
        end
    end

    if self.Active1 ~= self.Active then
        self.Active1 = self.Active
        if self.Active then
            self.offset = sm.game.getCurrentTick()%15
        else
            self.offset = nil
        end
    end

    -- actually does the blinky blinky
    if self.offset then
        self.isOff = false
        if (sm.game.getCurrentTick()+self.offset)%15 == 0 then
            local state = (sm.game.getCurrentTick()+self.offset)%30 == 0
            self.network:sendToClients("client_setUv",state)
            self.interactable:setActive(state)
        end
    else
        if self.isOff ~= true then
            self.isOff = true
            self.network:sendToClients("client_setUv",false)
            self.interactable:setActive(false)
        end
    end
    
end

function blinker.server_changeState( self, state )
    -- fires from the main electronic and interact
    self.Active = state
end

-- client

function blinker.client_setUv(self,state)
    self.interactable:setUvFrameIndex( state and 6 or 0 )
end

function blinker.client_onInteract(self, character, state)
    if state then
        self.network:sendToServer("server_changeState",true)
    end
end