LP = class()

randomToLetters = {
    "a",
    "b",
    "c",
    "d",
    "e",
    "f",
    "g",
    "h",
    "i",
    "j",
    "k",
    "l",
    "m",
    "n",
    "o",
    "p",
    "q",
    "r",
    "s",
    "t",
    "u",
    "v",
    "w",
    "x",
    "y",
    "z",
    "1",
    "2",
    "3",
    "4",
    "5",
    "6",
    "7",
    "8",
    "9",
}

function LP.server_onCreate( self )
    local Letter1 = randomToLetters[math.random(1,35)]
    local Letter2 = randomToLetters[math.random(1,35)]
    local Letter3 = randomToLetters[math.random(1,35)]
    local Letter4 = randomToLetters[math.random(1,35)]
    local Letter5 = randomToLetters[math.random(1,35)]
    local Letter6 = randomToLetters[math.random(1,35)]
    self.randomLicence = self.storage:load() or Letter1..Letter2..Letter3.."-"..Letter4..Letter5..Letter6
    self.storage:save(self.randomLicence)
    self.network:setClientData( {["text"] = self.randomLicence} )
end

function LP.client_onClientDataUpdate( self, data, channel )
	self.randomLicence = data.text
end

function LP.client_onCreate(self)
	self.gui = sm.gui.createNameTagGui()
	self.gui:setWorldPosition( self.shape.worldPosition )
	self.gui:setRequireLineOfSight( true )
	self.gui:setMaxRenderDistance( 32 )
    self.gui:open()
end

function LP.client_onFixedUpdate(self, dt)
	if self.gui then
        self.gui:setText("Text", self.randomLicence or "")
		self.gui:setWorldPosition( self.shape.worldPosition + (self.shape:getUp()*sm.vec3.new(0.25,0.25,0.25)) )
	end
end

function LP.client_onDestroy(self)
	if self.gui then
		self.gui:close()
	end
end