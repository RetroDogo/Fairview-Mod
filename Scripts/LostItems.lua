dofile("$CONTENT_DATA/Scripts/Utils.lua")

-- LostItems.lua --

LostItems = class( nil )

function LostItems.server_onCreate( self )
	
	self.sv = {}
	self.sv.loaded = true
	
	self.sv.saved = self.storage:load()
	if self.sv.saved == nil then
		self.sv.saved = {}
		self.sv.saved.ifDelete = false
	end
	if self.params then
		if self.params.owner then
			self.sv.saved.owner = self.params.owner
		end
	end
	self.storage:save( self.sv.saved )
	self.network:setClientData( self.sv.saved )

	-- unmarky baggy
end

function LostItems.server_onUnload( self )
	if self.sv.loaded then
		-- marky baggy
		self.sv.loaded = false
	end
end

function LostItems.server_onDestroy( self )
	if self.sv.loaded then
		-- unmarky baggy
		self.sv.loaded = false
	end
end

local notRemovedUuids = {
	sm.uuid.new("8c7efc37-cd7c-4262-976e-39585f8527bf"), -- connect tool
	sm.uuid.new("5cc12f03-275e-4c8e-b013-79fc0f913e1b"), -- lift
	sm.uuid.new("c60b9627-fc2b-4319-97c5-05921cb976c6"), -- paint tool
	sm.uuid.new("fdb8b8be-96e7-4de0-85c7-d2f42e4f33ce"), -- weld tool
	sm.uuid.new("af89c0c4-d2bb-44dd-8300-caf29beb364c") -- hands
}

-- sets the containter if theres no active container
function LostItems.server_setContainer(self,data)
	local oldContainer = data.container
	local player = data.player
	local oldContainerSize = 0
	local Currency = sm.json.open("$CONTENT_DATA/Json/Currency.json")
	:: beginning ::
	sm.container.beginTransaction()

	-- puts coins in the bag
	local playerCurrency = Currency[tostring(player.id)][1]
	local copper, silver, gold = extractPlaces(playerCurrency)

	-- allow extra slots for coins
	for _,data in pairs({copper,silver,gold}) do
		if data ~= 0 then
			oldContainerSize = oldContainerSize + 1
		end
	end

	-- allow extra slots for items
	for slot = 0,oldContainer:getSize() do 
		if not findValueInTable(notRemovedUuids,oldContainer:getItem( slot ).uuid) and oldContainer:getItem( slot ).quantity ~= 0 then 
			oldContainerSize = oldContainerSize + 1 
		end 
	end

	-- makes new container
	if self.shape.interactable:getContainer( 0 ) then self.shape.interactable:removeContainer( 0 ) end -- deletes the container
	local newContainer = self.shape.interactable:addContainer( 0, oldContainerSize ) -- makes new container
	newContainer.allowCollect = false

	 -- puts the coins in the container
	for uuid,data in pairs({["7d0262f7-1c1c-40e0-8b32-9c4f34da074e"] = copper,["b8e42416-7110-4092-b69f-4b3bf7c2f8ae"] = silver,["49ae8116-bdb4-4825-845a-ad513363ac84"] = gold}) do
		sm.container.collect( newContainer, sm.uuid.new(uuid), data )
	end

	-- clears the currecny of the wallet
	Currency[tostring(player.id)][1] = 0
	sm.json.save(Currency,"$CONTENT_DATA/Json/Currency.json")

	-- puts items in the container
	for slot = 0,oldContainer:getSize() do
		local slotInfo = oldContainer:getItem( slot )
		if not findValueInTable(notRemovedUuids,slotInfo.uuid) then
			sm.container.collect( newContainer, slotInfo.uuid, slotInfo.quantity ) -- makes new item in new contain
		end
	end
	sm.container.endTransaction()

	if newContainer:isEmpty() then
		goto beginning
	else
		-- removes from old inventory if it works
		sm.container.beginTransaction()
		for slot = 0,oldContainer:getSize() do
			local slotInfo = oldContainer:getItem( slot )
			if not findValueInTable(notRemovedUuids,slotInfo.uuid) then
				oldContainer:setItem( slot, sm.uuid.getNil(), 0) -- deletes the item from old contain
			end
		end
		sm.container.endTransaction()
	end
	self.sv.saved.ifDelete = true
end

function LostItems.client_onCreate( self )
	if self.cl == nil then
		self.cl = {}
	end
end

function LostItems.client_onDestroy( self )
	if self.cl.iconGui then
		self.cl.iconGui:close()
		self.cl.iconGui:destroy()
	end
	if self.cl.containerGui then
		if sm.exists( self.cl.containerGui ) then
			self.cl.containerGui:close()
			self.cl.containerGui:destroy()
		end
	end
end

function LostItems.client_onClientDataUpdate( self, clientData )
	if self.cl == nil then
		self.cl = {}
	end
	self.cl.owner = clientData.owner
	
	if sm.localPlayer.getPlayer() == self.cl.owner then
		self.cl.iconGui = sm.gui.createWorldIconGui( 32, 32, "$GAME_DATA/Gui/Layouts/Hud/Hud_WorldIcon.layout", false )
		self.cl.iconGui:setImage( "Icon", "icon_lostitem_large.png" )
		self.cl.iconGui:setHost( self.shape )
		self.cl.iconGui:setRequireLineOfSight( false )
		self.cl.iconGui:open()
		self.cl.iconGui:setMaxRenderDistance( 10000 )
	end
end

function LostItems.server_onFixedUpdate( self )
	local container = self.shape.interactable:getContainer( 0 )
	if container == nil or container:isEmpty() then
		if self.sv.saved.ifDelete then
			sm.shape.destroyShape( self.shape )
		end
	end
end

function LostItems.client_onInteract( self, character, state )
	if state == true then
		local container = self.shape.interactable:getContainer( 0 )
		if container then
			self.cl.containerGui = sm.gui.createContainerGui( true )
			self.cl.containerGui:setText( "UpperName", "#{CHEST_TITLE_LOST_ITEMS}" )
			self.cl.containerGui:setVisible( "ChestIcon", false )
			self.cl.containerGui:setVisible( "LostItemsIcon", true )
			self.cl.containerGui:setVisible( "TakeAll", true )
			self.cl.containerGui:setContainer( "UpperGrid", container );
			self.cl.containerGui:setText( "LowerName", "#{INVENTORY_TITLE}" )
			self.cl.containerGui:setContainer( "LowerGrid", sm.localPlayer.getInventory() )
			self.cl.containerGui:open()
		end
	end
end

function LostItems.cl_markBag( self )
	self.cl.iconGui = sm.gui.createWorldIconGui( 32, 32, "$GAME_DATA/Gui/Layouts/Hud/Hud_WorldIcon.layout", false )
	self.cl.iconGui:setImage( "Icon", "gui_icon_kobag.png" )
	self.cl.iconGui:setHost( self.shape )
	self.cl.iconGui:setRequireLineOfSight( false )
	self.cl.iconGui:open()
end
