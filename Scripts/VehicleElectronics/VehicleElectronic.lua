VE = class()

VE.maxParentCount = 2
VE.maxChildCount = 256
VE.connectionInput = sm.interactable.connectionType.power + sm.interactable.connectionType.logic
VE.connectionOutput = sm.interactable.connectionType.power + sm.interactable.connectionType.logic
VE.colorNormal = sm.color.new( 0x777777ff )
VE.colorHighlight = sm.color.new( 0x888888ff )

local childrenUuids = {
    ["93d69339-eee8-48b6-8ef8-dfe77deb985e"] = "break",
    ["d16a0218-db1e-4475-b2ac-15aecbf53253"] = "reverse",
    ["440f3f05-4258-489a-aafe-9fc6057e17ae"] = "left",
    ["6681ce73-ce3d-4af0-a51c-0390b1dd501c"] = "right"
}

-- server

function VE.server_onCreate( self )
    self.sv = {}
    self.sv.breaking = false
    self.sv.reversing = false
    self.sv.leftDelay = nil
    self.sv.rightDelay = nil
    self.sv.looksActive = false
end

function VE.server_onFixedUpdate( self, timeStep )
    for _,interactable in pairs(self.interactable:getParents()) do
        if interactable:hasSteering() then

            if self.sv.looksActive ~= interactable.active then
                self.sv.looksActive = interactable.active
                self.interactable.active = interactable.active
                self.network:sendToClients("client_setUv",interactable.active)
            end

            if interactable.active then
                -- breaking and reverse
                local seatThrottle = interactable.power
                self.sv.seatPower = seatThrottle
                local velocityVec = self.interactable.shape.velocity*self.interactable.shape.up
                local velocity = -velocityVec.x-velocityVec.y
                if velocity > -0.25 then
                    self.sv.breaking = seatThrottle == -1
                else
                    self.sv.breaking = seatThrottle == 1
                end
                self.sv.reversing = not (velocity > -1)

                -- steering
                if interactable:getSteeringAngle() ~= self.sv.steering then
                    if interactable:getSteeringAngle() == 0 then
                        for _,children in pairs(self.interactable:getChildren()) do
                            if isAnyOf(tostring(children.shape.uuid),childrenUuids) then
                                local blocktType = childrenUuids[tostring(children.shape.uuid)]
                                if blocktType == (self.sv.steering == -1 and "left" or "right") then
                                    sm.event.sendToInteractable( children, "server_changeState", false )
                                end
                            end
                        end
                    end
                    self.sv.steering = interactable:getSteeringAngle()
                end

            else
                self.sv.breaking = false
                self.sv.reversing = false
                for _,children in pairs(self.interactable:getChildren()) do
                    if isAnyOf(tostring(children.shape.uuid),childrenUuids) then
                        local blocktType = childrenUuids[tostring(children.shape.uuid)]
                        if blocktType == "left" or blocktType == "right" then
                            if not self.isHazers then
                                sm.event.sendToInteractable( children, "server_changeState", false )
                            end
                        end
                    end
                end
            end

        else
            if interactable.shape.color == sm.color.new( 0xd02525ff ) then
                if interactable.active then
                    self.isHazers = true
                    for _,children in pairs(self.interactable:getChildren()) do
                        if isAnyOf(tostring(children.shape.uuid),childrenUuids) then
                            local blocktType = childrenUuids[tostring(children.shape.uuid)]
                            if blocktType == "left" or blocktType == "right" then
                                sm.event.sendToInteractable( children, "server_changeState", interactable.active )
                            end
                        end
                    end
                else
                    if self.isHazers ~= interactable.active then
                        self.isHazers = interactable.active
                        for _,children in pairs(self.interactable:getChildren()) do
                            if isAnyOf(tostring(children.shape.uuid),childrenUuids) then
                                local blocktType = childrenUuids[tostring(children.shape.uuid)]
                                if blocktType == "left" or blocktType == "right" then
                                    sm.event.sendToInteractable( children, "server_changeState", interactable.active )
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    for _,children in pairs(self.interactable:getChildren()) do
        if isAnyOf(tostring(children.shape.uuid),childrenUuids) then
            local blocktType = childrenUuids[tostring(children.shape.uuid)]

            -- sends the vehicle data to the connected blocks
            if blocktType == "break" then
                if self.sv.breaking ~= self.sv.breaking1 then
                    self.sv.breaking1 = self.sv.breaking
                    sm.event.sendToInteractable( children, "server_changeState", {state = self.sv.breaking} )
                end
            elseif blocktType == "reverse" then
                if self.sv.reversing ~= self.sv.reversing1 then
                    self.sv.reversing1 = self.sv.reversing
                    sm.event.sendToInteractable( children, "server_changeState", {state = self.sv.reversing} )
                end
            end

        end
    end

end


-- client

function VE.client_setUv(self,state)
    self.interactable:setUvFrameIndex( state and 6 or 0 )
end

-- functions

function isAnyOf(is, off)
	for v,_ in pairs(off) do
		if is == v then
			return true
		end
	end
	return false
end