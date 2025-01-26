AP = class()

AP.colorNormal = sm.color.new( "#cc0000" )
AP.colorHighlight = sm.color.new( "#ff0000" )
AP.maxParentCount = 1
AP.maxChildCount = 0
AP.connectionInput = 1
AP.connectionOutput = 0

dofile("$CONTENT_DATA/Scripts/Utils.lua")

function AP.server_onCreate(self,character)
    self.text = self.storage:load() or ""
    self.guiText = ""
    self.timeOffset = math.random(39)
end

function AP.server_onFixedUpdate(self,character)
    if self.interactable:getSingleParent() then
        if (sm.game.getCurrentTick()+self.timeOffset)%40 == 0 then
            if self.interactable:getSingleParent():isActive() == true and self.text ~= "" then
                self.network:sendToClients( "client_alertText", {self.text} )
                self.storage:save( self.text )
            end
        end
    end
end

function AP.client_alertText(self,data)
    sm.gui.displayAlertText(colorToHashtag(self.shape:getColor())..data[1],1)
end

function AP.client_canInteract(self,character)
    if character:getPlayer():getId() == 1 then
        EKey = sm.gui.getKeyBinding("Use",true)
        sm.gui.setInteractionText(EKey,""," Set Text")
        sm.gui.setInteractionText("")
        return true
    else
        sm.gui.setInteractionText("YOU ARE NOT HOST")
        sm.gui.setInteractionText("")
        return false
    end
end

function AP.client_onInteract( self, character, state )
	if state and character:getPlayer():getId() == 1 then
		if self.gui ~= nil then
			self.gui:destroy()
			self.gui = nil
		end
		if self.gui == nil then
			local path = "$GAME_DATA/Gui/Layouts/PopUp/PopUp_TextInput.layout"
            self.gui = sm.gui.createGuiFromLayout( path )
            self.gui:setButtonCallback( "Ok", "client_yesClicked" )
            self.gui:setButtonCallback( "Cancel", "client_noClicked" )
            self.gui:setTextChangedCallback( "Input", "client_textChanged" )
            self.gui:setTextAcceptedCallback( "Input", "client_textEntered" )

		end
        self.gui:setText( "Title", "Announcement Text" )
        self.gui:setText( "Input", self.text )
        self.gui:open()
	end
end

function AP.client_yesClicked(self)
    self.text = self.guiText
    self.gui:close()
end

function AP.client_noClicked(self)

    self.gui:close()
end

function AP.client_textChanged(self,_,text)
    self.guiText = text
end

function AP.client_textEntered(self,_,text)
    self.text = self.guiText
    self.gui:close()
end