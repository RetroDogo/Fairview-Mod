DS = class()

DS.maxParentCount = 0
DS.maxChildCount = 1
DS.connectionInput = sm.interactable.connectionType.none
DS.connectionOutput = sm.interactable.connectionType.logic
DS.colorNormal = sm.color.new( 0x777777ff )
DS.colorHighlight = sm.color.new( 0x888888ff )

--[[function DS.server_onCreate(self,data)
    self.sv = {}
    self.sv.timeOff = 0
    self.sv.timeOn = 0
end]]

function DS.server_onFixedUpdate(self)
    --local ifActive = sm.game.getTimeOfDay() > self.sv.timeOff/100 or sm.game.getTimeOfDay() < self.sv.timeOn/100
    local ifActive = sm.game.getTimeOfDay() > 0.75 or sm.game.getTimeOfDay() < 0.22
    if ifActive ~= self.interactable:isActive() then
        self.interactable:setActive( ifActive )
        self.network:sendToClients("client_setUv",ifActive)
    end
end

function DS.client_setUv(self,state)
    self.interactable:setUvFrameIndex( state and 6 or 0 )
end

--[[function DS.server_setData(self,data)
    print(data)
    self.sv.timeOff = data.timeOff
    self.sv.timeOn = data.timeOn
end

function DS.client_onCreate(self)
    self.cl = {}
    self.cl.timeOff = 0
    self.cl.timeOn = 0
end

function DS.client_onInteract(self,character,state)
    if self.gui ~= nil then
        self.gui:destroy()
        self.gui = nil
    end
    if self.gui == nil then
        local path = "$CONTENT_DATA/Gui/Layouts/DaylightSensor.layout"
        self.gui = sm.gui.createGuiFromLayout( path )
    end
    self.Ammount = 0
    self.gui:setText( "text_box_1", "Turn off time (0 - 100)" )
    self.gui:setText( "text_box_2", "Turn on time  (0 - 100)" )
    self.gui:setText( "edit_box_1", tostring(self.cl.timeOff) )
    self.gui:setText( "edit_box_2", tostring(self.cl.timeOn) )
    self.gui:setText( "button_2", "Deposit FairBucks" )
    self.gui:setTextChangedCallback( "edit_box_1", "client_onTextChange" )
    self.gui:setTextChangedCallback( "edit_box_2", "client_onTextChange" )
    self.gui:open()
end

function DS.client_onTextChange(self,box,text)
    if box == "edit_box_1" then
        if tonumber(text) then
            self.cl.timeOff = tonumber(text)
            self.network:sendToServer("server_setData",{timeOn = self.cl.timeOn,timeOff = self.cl.timeOff})
            self.gui:setText( "text_box_1", "Turn off time (0 - 100)" )
        else
            self.gui:setText( "text_box_1", "#FF0000Invalid Number" )
        end
    elseif box == "edit_box_2" then
        if tonumber(text) then
            self.cl.timeOn = tonumber(text)
            self.network:sendToServer("server_setData",{timeOn = self.cl.timeOn,timeOff = self.cl.timeOff})
            self.gui:setText( "text_box_2", "Turn on time  (0 - 100)" )
        else
            self.gui:setText( "text_box_2", "Turn on time" )
        end
    end
end]]