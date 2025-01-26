hands = class()

dofile("$CONTENT_DATA/Scripts/Utils.lua")

local selectionIndexText = {
    [0] = "Dragging Mode",
    [1] = "Patting Mode"
}

local dangerousItems = {

}

-- server

function hands.server_onCreate( self )
    self.sv = {}
    self.sv.selectionIndex = 0
    self.sv.drag = {state = false,ray = nil}
end

function hands.server_onRefresh( self )
    self.sv = {}
    self.sv.selectionIndex = 0
    self.sv.drag = {state = false,ray = nil}
end

function hands.server_onFixedUpdate( self, timeStep )

    -- if something is being dragged, start dragging that shit
    if self.sv.drag.state and self.sv.drag.ray then
        if self.sv.drag.ray.type == "body" and self.sv.drag.ray.body then

            -- fails if the creation is welded
            if not testNotStatic(self.sv.drag.ray.body:getCreationBodies()) then
                self.network:sendToClient(self.tool:getOwner(), "cl_sendAlertMessage",{text = "#FF0000Cant drag welded creation",time = 1})
                self.sv.drag = {state = false,ray = nil}
            end
            
            -- actually runs the drag
            if self.sv.drag.state then
                local tableVec3s = {}
                for _,shape in pairs(self.sv.drag.ray.body:getShapes()) do
                    table.insert(tableVec3s,shape.worldPosition)
                end
                local crouchPos = self.tool:getOwner().character:isCrouching() and sm.vec3.new(0,0,-0.25) or sm.vec3.new(0,0,0)
                local targetPos = self.tool:getOwner().character.worldPosition+(self.tool:getOwner().character:getDirection()*sm.vec3.new(2,2,2))+sm.vec3.new(0,0,0.75)+(self.tool:getOwner().character.velocity/3.8)+crouchPos
                local forcePos = -(averageTableVec3s(tableVec3s)-targetPos)*(self.sv.drag.ray.body.mass/200)
                local bodyForcePos = clampVec3(forcePos*sm.vec3.new(200,200,200)-self.sv.drag.ray.body.velocity*(self.sv.drag.ray.body.mass/4),-300,300)
                sm.physics.applyImpulse(self.sv.drag.ray.body,bodyForcePos,true)

                -- makes sure the player isnt moving too fast (flying with the object under them)
                if math.abs(self.tool:getOwner().character.velocity.x)+math.abs(self.tool:getOwner().character.velocity.y)>12 then
                    self.network:sendToClient(self.tool:getOwner(), "cl_sendAlertMessage",{text = "#FF0000Stopped dragging due to suspected dragging glitch",time = 2})
                    self.sv.drag = {state = false,ray = nil}
                end
            end
        end
    end

end

function hands.server_primaryClick( self, data )
    local state = data.state
    if self.sv.selectionIndex == 0 then
        self.sv.drag = {state = data.state,ray = data.facingRay}
    elseif self.sv.selectionIndex == 1 then
        if state then
            -- patdown
        end
    end
end

function hands.server_secondaryClick( self, data )
    local state = data.state
    if self.sv.selectionIndex == 0 then

        if not data.facingRay then return end
        if data.facingRay.type ~= "body" and not Data.facingRay.body then return end
        self.sv.drag = {state = false,ray = nil}

        -- checks if the person is trying to yeet a welded creation
        if not testNotStatic(data.facingRay.body:getCreationBodies()) then
            self.network:sendToClient(self.tool:getOwner(), "cl_sendAlertMessage",{text = "#FF0000Cant throw welded creation",time = 1})
            return
        end

        -- makes sure the player isnt moving too fast (flying with the object under them)
        if math.abs(self.tool:getOwner().character.velocity.x)+math.abs(self.tool:getOwner().character.velocity.y)>12 then
            self.network:sendToClient(self.tool:getOwner(), "cl_sendAlertMessage",{text = "#FF0000Didn't throw due to suspected dragging glitch",time = 2})
            return
        end

        -- actually runs the yeet
        local tableVec3s = {}
        for _,shape in pairs(data.facingRay.body:getShapes()) do
            table.insert(tableVec3s,shape.worldPosition)
        end
        local targetPos = self.tool:getOwner().character.worldPosition+(self.tool:getOwner().character:getDirection()*sm.vec3.new(25,25,25))
        local forcePos = clampVec3(-(averageTableVec3s(tableVec3s)-targetPos)*(data.facingRay.body.mass/3),-600,600)
        sm.physics.applyImpulse(data.facingRay.body,forcePos,true)
    elseif self.sv.selectionIndex == 1 then

    end
end

function hands.server_setServerData( self, data )
    local type = data.type
    local value = data.value
    if type == "selectionIndex" then

        -- errases index specifc codes/variables
        self.sv.drag = {state = false,ray = nil}

        -- sets the value
        self.sv.selectionIndex = value

    end
end

-- client

function hands.cl_sendTextMessage(self,text)
    sm.gui.chatMessage(text)
end

function hands.cl_sendAlertMessage(self,data)
    local text = data.text
    local time = data.time
    sm.gui.displayAlertText( text, time )
end

function hands.client_onCreate( self )
    self.cl = {}
    self.cl.selectionIndex = 0
    self.cl.selectionIndexLimits = {max = 1,min = 0}
end

function hands.client_onRefresh( self )
    self.cl = {}
    self.cl.selectionIndex = 0
    self.cl.selectionIndexLimits = {max = 1,min = 0}
end

function hands.client_onToggle( self )

    -- sets the index when pressing Q or crouch Q
    if not sm.localPlayer.getPlayer():getCharacter():isCrouching() then
        if self.cl.selectionIndex ~= self.cl.selectionIndexLimits.max then
            self.cl.selectionIndex = self.cl.selectionIndex + 1
        else
            self.cl.selectionIndex = self.cl.selectionIndexLimits.min
        end
    else
        if self.cl.selectionIndex ~= self.cl.selectionIndexLimits.min then
            self.cl.selectionIndex = self.cl.selectionIndex - 1
        else
            self.cl.selectionIndex = self.cl.selectionIndexLimits.max
        end
    end

    -- sends that data to the server
    self.network:sendToServer("server_setServerData",{type = "selectionIndex",value = self.cl.selectionIndex})

	return true
end

function hands.client_onReload( self )
    local helpText = {
        [0] = "#FFFF00Left click #FFFFFFto pick up blocks. \n#FFFF00Right click#FFFFFF to quickly throw them!",
        [1] = "#FFFF00Left click#FFFFFF on another person to search them. \nAsks for consent if you are not police."
    }
    sm.gui.chatMessage(helpText[self.cl.selectionIndex])
	return true
end

function hands.client_onFixedUpdate( self, timeStep )

end

function hands.client_onEquippedUpdate(self, primaryState, secondaryState, forceBuild)

    -- sets the variables for mouseclicks
    if self.cl.primaryActive ~= (primaryState == 2) then
        self.cl.primaryActive = (primaryState == 2)
        self.network:sendToServer("server_primaryClick",{
            state = self.cl.primaryActive,
            facingRay = getFacingRay(self)
        })
    end
    if self.cl.secondaryActive ~= (secondaryState == 2) then
        self.cl.secondaryActive = (secondaryState == 2)
        self.network:sendToServer("server_secondaryClick",{
            state = self.cl.secondaryActive,
            facingRay = getFacingRay(self)
        })
    end

    -- sets the text
    local keybind = sm.gui.getKeyBinding( "NextCreateRotation", true )
    sm.gui.setInteractionText("", sm.gui.getKeyBinding("NextCreateRotation", true), "Mode ",
    "<p textShadow='false' bg='gui_keybinds_bg' color='#ffffff' spacing='4'>" ..
    selectionIndexText[self.cl.selectionIndex] .. "</p>")
    return true, true
end

function getFacingRay(self)
    local result, raycastResult = sm.localPlayer.getRaycast( 2.5 )
    if result then
        return {
            originWorld = raycastResult.originWorld,
            directionWorld = raycastResult.directionWorld,
            normalWorld = raycastResult.normalWorld,
            normalLocal = raycastResult.normalLocal,
            pointWorld = raycastResult.pointWorld,
            pointLocal = raycastResult.pointLocal,
            type = raycastResult.type,
            fraction = raycastResult.fraction,
            areaTrigger = raycastResult:getAreaTrigger(),
            body = raycastResult:getBody(),
            character = raycastResult:getCharacter(),
            harvestable = raycastResult:getHarvestable(),
            joint = raycastResult:getJoint(),
            liftData = raycastResult:getLiftData(),
            shape = raycastResult:getShape()
        }
    end
    return false
end

function testNotStatic(creation)
	for k, v in pairs(creation) do
		if sm.body.isStatic(v) then
			return false
		end
	end
	return true
end