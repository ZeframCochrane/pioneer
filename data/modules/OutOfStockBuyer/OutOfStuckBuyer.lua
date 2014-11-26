-- Copyright © 2008-2013 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt

local Lang = import("Lang")
local Engine = import("Engine")
local Game = import("Game")
local Event = import("Event")
local NameGen = import("NameGen")
local Rand = import("Rand")
local Format = import("Format")
local Serializer = import("Serializer")
local Equipment = import("Equipment")
local Translate = Lang.GetResource("module-outofstockbuyer")


local FlavorCount = 4
local Ads = {}
local DebugMode = 1
local LoadedData

local onChat = function (form, ref, option)
	local Ad = Ads[ref]


	form:Clear()
	form:SetTitle(Ad.Flavour)
	form:SetFace({ seed = Ad.FaceSeed })
	
	if option == -1 then
		form:Close()
		return
	elseif option == 1 then --The player has at least one in stock. Let's buy one.
		Game.player:RemoveEquip(Ad.Cargo, 1)
		Game.player:AddMoney(Ad.Price)
		Ad.Quantity = Ad.Quantity - 1
		if Ad.Quantity == 0 then
			form:SetMessage(Translate.NO_MORE)
			Ad.Station:RemoveAdvert(ref)
			return
		end
	end


	local Quantity = Game.player:GetEquipCount(Ad.Cargo:GetDefaultSlot(), Ad.Cargo)

	form:SetMessage(Translate.WELCOME:interp({Cargo=Ad.Cargo:GetName(),price=Format.Money(Ad.Price)}))

	local onClick = function (ref)
		return true
	end
	if Quantity > 0 then --If the player has at least one in stock, then let's add the option to sell it
		form:AddOption(Translate.SELL_GOOD:interp({Cargo=Ad.Cargo:GetName(),Quantity=Quantity,Price=Format.Money(Ad.Price)}), 1)
	end


end

local onDelete = function (ref)
	Ads[ref] = nil
end
local isEnabled = function(ref)
	if Game.player:GetEquipCount(Ads[ref].Cargo, Ads[ref].Cargo) > 0 then
		return true
	else
		return false
	end
end

local onCreateBB = function (station)
	local Cargo, Price, Quantity
	local Goods = {}
	local Rnd = Rand.New()
	if DebugMode == 0 then
		if station.isGroundStation == 0 then
			if Rnd:Integer(1,4) == 1 then -- Lets run this script 1 out of 4 times if it is a space station
				return
			end
		elseif Rnd:Integer(1,3) == 1 then -- Lets run this script 1 out of 3 times if it is a ground station
			return
		end
	end
	-- Look for cargo that is legal, is not in stock and actually worth money and then put them in the candidate list
	for i,Cargo in pairs(Equipment.cargo) do
		Console.AddLine(Cargo:GetDefaultSlot())
		if Cargo:GetDefaultSlot() == "cargo" and station:GetEquipmentPrice(Cargo) > 0  then
			if Game.system:IsCommodityLegal(Cargo) and station:GetEquipmentStock(Cargo) == 0 and Game.system:IsCommodityLegal(Cargo) then
				Goods[#Goods+1] = Cargo
			end
		end
	end
	if #Goods == 0 then 
		return 
	end

	-- Randomly select from the candidate list 
	local Num = Rnd:Integer(1,#Goods)
	for i = 1,Num do
		
		Cargo = table.remove(Goods,Rnd:Integer(1,#Goods))

		Price = station:GetEquipmentPrice(Cargo) * Rnd:Number(1.5,2) --The price is randomly generated between 1.5x and 2x the base price.
		local Flavour = string.interp(Translate["OOS_TRADER_"..Rnd:Integer(0, FlavorCount-1)], {Cargo=Cargo:GetName(),Price=Format.Money(Price)})
		

		if DebugMode == 1 then
			Game.player:AddEquip(Cargo, 2)
			Quantity = 2
		else
			if Rnd:Integer(0,4) > 0 then
				Quantity = Rnd:Integer(1,20)
			else
				Quantity = Rnd:Integer(10,50)
			end
		end
		local Ad = {
			Station  = station,
			Flavour  = Flavour,
			FaceSeed = Rnd:Integer(),
			Price = Price,
			Cargo = Cargo,
			Quantity = Quantity
		}
	
		local Ref = station:AddAdvert({description = Ad.Flavour, icon = "goods_trader", onChat = onChat, onDelete = onDelete, isEnabled = isEnabled})
		Ads[Ref] = Ad
	end
end

local loaded_data

local onGameStart = function ()
	Ads = {}

	if not loaded_data then return end

	for k,Ad in pairs(loaded_data.Ads) do
		local Ref = Ad.Station:AddAdvert(Ad.Flavour, onChat, onDelete)
		Ads[Ref] = Ad
	end

	loaded_data = nil
end

local serialize = function ()
	return { Ads = Ads }
end

local unserialize = function (data)
	LoadedData = data
end

Event.Register("onCreateBB", onCreateBB)
Event.Register("onGameStart", onGameStart)

Serializer:Register("OutOfStockBuyer", serialize, unserialize)
