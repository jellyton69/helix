VENDOR_BUY = 1
VENDOR_SELL = 2
VENDOR_BOTH = 3

PLUGIN.name = "Vendors"
PLUGIN.author = "Chessnut"
PLUGIN.desc = "Adds NPC vendors that can sell things."

-- Keys for vendor messages.
VENDOR_WELCOME = 1
VENDOR_LEAVE = 2
VENDOR_NOTRADE = 3

-- Keys for item information.
VENDOR_PRICE = 1
VENDOR_STOCK = 2
VENDOR_MODE = 3
VENDOR_MAXSTOCK = 4

-- Sell and buy the item.
VENDOR_SELLANDBUY = 1
-- Only sell the item to the player.
VENDOR_SELLONLY = 2
-- Only buy the item from the player.
VENDOR_BUYONLY = 3

if (SERVER) then
	local PLUGIN = PLUGIN

	function PLUGIN:SaveData()
		local data = {}
			for k, v in ipairs(ents.FindByClass("nut_vendor")) do
				data[#data + 1] = {
					name = v:GetNetVar("name"),
					desc = v:GetNetVar("desc"),
					pos = v:GetPos(),
					angles = v:GetAngles(),
					model = v:GetModel(),
					bubble = v:GetNetVar("noBubble"),
					items = v.items,
					factions = v.factions,
					classes = v.classes,
					money = v.money,
					scale = v.scale
				}
			end
		self:SetData(data)
	end

	function PLUGIN:LoadData()
		for k, v in ipairs(self:GetData() or {}) do
			local entity = ents.Create("nut_vendor")
			entity:SetPos(v.pos)
			entity:SetAngles(v.angles)
			entity:Spawn()
			entity:SetModel(v.model)
			entity:SetNetVar("noBubble", v.bubble)
			entity:SetNetVar("name", v.name)
			entity:SetNetVar("desc", v.desc)

			entity.items = v.items or {}
			entity.factions = v.factions or {}
			entity.classes = v.classes or {}
			entity.money = v.money
			entity.scale = v.scale or 0.5
		end
	end

	function PLUGIN:CanVendorSellItem(client, vendor, itemID)
		local tradeData = vendor.items[itemID]
		local char = client:GetChar()

		if (!tradeData or !char) then
			print("Not Valid Item or Client Char.")
			return false
		end

		if (!char:HasMoney(tradeData[1] or 0)) then
			print("Insufficient Fund.")
			return false
		end

		return true
	end

	function PLUGIN:OnCharTradeVendor(client, vendor, x, y, invID, price, isSell)
	end

	netstream.Hook("vendorExit", function(client)
		local entity = client.nutVendor

		if (IsValid(entity)) then
			for k, v in ipairs(entity.receivers) do
				if (v == client) then
					table.remove(entity.receivers, k)

					break
				end
			end

			client.nutVendor = nil
		end
	end)

	netstream.Hook("vendorEdit", function(client, key, data)
		if (client:IsAdmin()) then
			local entity = client.nutVendor

			if (!IsValid(entity)) then
				return
			end

			local feedback = true

			if (key == "name") then
				entity:SetNetVar("name", data)
			elseif (key == "desc") then
				entity:SetNetVar("desc", data)
			elseif (key == "bubble") then
				entity:SetNetVar("noBubble", data)
			elseif (key == "mode") then
				local uniqueID = data[1]

				entity.items[uniqueID] = entity.items[uniqueID] or {}
				entity.items[uniqueID][VENDOR_MODE] = data[2]

				netstream.Start(entity.receivers, "vendorEdit", key, data)
			elseif (key == "price") then
				local uniqueID = data[1]
				data[2] = tonumber(data[2])

				if (data[2]) then
					data[2] = math.Round(data[2])
				end

				entity.items[uniqueID] = entity.items[uniqueID] or {}
				entity.items[uniqueID][VENDOR_PRICE] = data[2]

				netstream.Start(entity.receivers, "vendorEdit", key, data)
				data = uniqueID
			elseif (key == "stockDisable") then
				entity.items[data] = entity.items[uniqueID] or {}
				entity.items[data][VENDOR_MAXSTOCK] = nil

				netstream.Start(entity.receivers, "vendorEdit", key, data)
			elseif (key == "stockMax") then
				local uniqueID = data[1]
				data[2] = math.max(math.Round(tonumber(data[2]) or 1), 1)

				entity.items[uniqueID] = entity.items[uniqueID] or {}
				entity.items[uniqueID][VENDOR_MAXSTOCK] = data[2]
				entity.items[uniqueID][VENDOR_STOCK] = math.Clamp(entity.items[uniqueID][VENDOR_STOCK] or data[2], 1, data[2])

				data[3] = entity.items[uniqueID][VENDOR_STOCK]

				netstream.Start(entity.receivers, "vendorEdit", key, data)
				data = uniqueID
			elseif (key == "stock") then
				local uniqueID = data[1]

				entity.items[uniqueID] = entity.items[uniqueID] or {}

				if (!entity.items[uniqueID][VENDOR_MAXSTOCK]) then
					data[2] = math.max(math.Round(tonumber(data[2]) or 0), 0)
					entity.items[uniqueID][VENDOR_MAXSTOCK] = data[2]
				end

				data[2] = math.Clamp(math.Round(tonumber(data[2]) or 0), 0, entity.items[uniqueID][VENDOR_MAXSTOCK])
				entity.items[uniqueID][VENDOR_STOCK] = data[2]

				netstream.Start(entity.receivers, "vendorEdit", key, data)
				data = uniqueID
			elseif (key == "faction") then
				local faction = nut.faction.teams[data]

				if (faction) then
					entity.factions[data] = !entity.factions[data]

					if (!entity.factions[data]) then
						entity.factions[data] = nil
					end
				end

				local uniqueID = data
				data = {uniqueID, entity.factions[uniqueID]}
			elseif (key == "class") then
				local class

				for k, v in ipairs(nut.class.list) do
					if (v.uniqueID == data) then
						class = v

						break
					end
				end

				if (class) then
					entity.classes[data] = !entity.classes[data]

					if (!entity.classes[data]) then
						entity.classes[data] = nil
					end
				end

				local uniqueID = data
				data = {uniqueID, entity.classes[uniqueID]}
			elseif (key == "model") then
				entity:SetModel(data)
				entity:SetAnim()
			elseif (key == "useMoney") then
				if (entity.money) then
					entity:SetMoney()
				else
					entity:SetMoney(0)
				end
			elseif (key == "money") then
				data = math.Round(math.abs(tonumber(data) or 0))

				entity:SetMoney(data)
				feedback = false
			elseif (key == "scale") then
				data = tonumber(data) or 0.5

				entity.scale = data
				netstream.Start(entity.receivers, "vendorEdit", key, data)
			end

			PLUGIN:SaveData()

			if (feedback) then
				local receivers = {}

				for k, v in ipairs(entity.receivers) do
					if (v:IsAdmin()) then
						receivers[#receivers + 1] = v
					end
				end

				netstream.Start(receivers, "vendorEditFinish", key, data)
			end
		end
	end)

	netstream.Hook("vendorTrade", function(client, uniqueID, isSellingToVendor)
		if ((client.nutVendorTry or 0) < CurTime()) then
			client.nutVendorTry = CurTime() + 0.33
		else
			return
		end

		local found
		local entity = client.nutVendor

		if (!IsValid(entity) or client:GetPos():Distance(entity:GetPos()) > 192) then
			return
		end

		if (entity.items[uniqueID] and hook.Run("CanPlayerTradeWithVendor", client, entity, uniqueID, isSellingToVendor) != false) then
			local price = entity:GetPrice(uniqueID, isSellingToVendor)

			if (isSellingToVendor) then
				local found = false
				local name
				
				if (!entity:HasMoney(price)) then
					return client:NotifyLocalized("vendorNoMoney")
				end

				local invOkay = true
				for k, v in pairs(client:GetChar():GetInv():GetItems()) do
					if (v.uniqueID == uniqueID and v:GetID() != 0) then
						invOkay = v:Remove()
						found = true
						name = L(v.name, client)

						break
					end
				end

				if (!found) then
					return
				end
				
				if (!invOkay) then
					client:GetChar():GetInv():Sync(client, true)
					return client:NotifyLocalized("tellAdmin", "trd!iid")
				end

				client:GetChar():GiveMoney(price)
				client:NotifyLocalized("businessSell", name, nut.currency.Get(price))
				entity:TakeMoney(price)
				entity:AddStock(uniqueID)

				PLUGIN:SaveData()
				hook.Run("OnCharTradeVendor", client, entity, uniqueID, isSellingToVendor)
			else
				local stock = entity:GetStock(uniqueID)

				if (stock and stock < 1) then
					return client:NotifyLocalized("vendorNoStock")
				end

				if (!client:GetChar():HasMoney(price)) then
					return client:NotifyLocalized("canNotAfford")
				end

				local name = L(nut.item.list[uniqueID].name, client)
			
				client:GetChar():TakeMoney(price)
				client:NotifyLocalized("businessPurchase", name, nut.currency.Get(price))
				
				entity:GiveMoney(price)

				if (!client:GetChar():GetInv():Add(uniqueID)) then
					nut.item.Spawn(uniqueID, client:GetItemDropPos())
				else
					netstream.Start(client, "vendorAdd", uniqueID)
				end

				entity:TakeStock(uniqueID)

				PLUGIN:SaveData()
				hook.Run("OnCharTradeVendor", client, entity, uniqueID, isSellingToVendor)
			end
		else
			client:NotifyLocalized("vendorNoTrade")
		end
	end)
else
	VENDOR_TEXT = {}
	VENDOR_TEXT[VENDOR_SELLANDBUY] = "vendorBoth"
	VENDOR_TEXT[VENDOR_BUYONLY] = "vendorBuy"
	VENDOR_TEXT[VENDOR_SELLONLY] = "vendorSell"

	netstream.Hook("vendorOpen", function(index, items, money, scale, messages, factions, classes)
		local entity = Entity(index)

		if (!IsValid(entity)) then
			return
		end

		entity.money = money
		entity.items = items
		entity.messages = messages
		entity.factions = factions
		entity.classes = classes
		entity.scale = scale

		nut.gui.vendor = vgui.Create("nutVendor")
		nut.gui.vendor:Setup(entity)

		if (LocalPlayer():IsAdmin() and messages) then
			nut.gui.vendorEditor = vgui.Create("nutVendorEditor")
		end
	end)

	netstream.Hook("vendorEdit", function(key, data)
		local panel = nut.gui.vendor

		if (!IsValid(panel)) then
			return
		end

		local entity = panel.entity

		if (!IsValid(entity)) then
			return
		end

		if (key == "mode") then
			entity.items[data[1]] = entity.items[data[1]] or {}
			entity.items[data[1]][VENDOR_MODE] = data[2]

			if (!data[2]) then
				panel:removeItem(data[1])
			elseif (data[2] == VENDOR_SELLANDBUY) then
				panel:addItem(data[1])
			else
				panel:addItem(data[1], data[2] == VENDOR_SELLONLY and "selling" or "buying")
				panel:removeItem(data[1], data[2] == VENDOR_SELLONLY and "buying" or "selling")
			end
		elseif (key == "price") then
			local uniqueID = data[1]

			entity.items[uniqueID] = entity.items[uniqueID] or {}
			entity.items[uniqueID][VENDOR_PRICE] = tonumber(data[2])
		elseif (key == "stockDisable") then
			if (entity.items[data]) then
				entity.items[data][VENDOR_MAXSTOCK] = nil
			end
		elseif (key == "stockMax") then
			local uniqueID = data[1]
			local value = data[2]
			local current = data[3]

			entity.items[uniqueID] = entity.items[uniqueID] or {}
			entity.items[uniqueID][VENDOR_MAXSTOCK] = value
			entity.items[uniqueID][VENDOR_STOCK] = current
		elseif (key == "stock") then
			local uniqueID = data[1]
			local value = data[2]

			entity.items[uniqueID] = entity.items[uniqueID] or {}

			if (!entity.items[uniqueID][VENDOR_MAXSTOCK]) then
				entity.items[uniqueID][VENDOR_MAXSTOCK] = value
			end

			entity.items[uniqueID][VENDOR_STOCK] = value
		elseif (key == "scale") then
			entity.scale = data
		end
	end)

	netstream.Hook("vendorEditFinish", function(key, data)
		local panel = nut.gui.vendor
		local editor = nut.gui.vendorEditor

		if (!IsValid(panel) or !IsValid(editor)) then
			return
		end

		local entity = panel.entity

		if (!IsValid(entity)) then
			return
		end

		if (key == "name") then
			editor.name:SetText(entity:GetNetVar("name"))
		elseif (key == "desc") then
			editor.desc:SetText(entity:GetNetVar("desc"))
		elseif (key == "bubble") then
			editor.bubble.noSend = true
			editor.bubble:SetValue(data and 1 or 0)
		elseif (key == "mode") then
			if (data[2] == nil) then
				editor.lines[data[1]]:SetValue(2, L"none")
			else
				editor.lines[data[1]]:SetValue(2, L(VENDOR_TEXT[data[2]]))
			end
		elseif (key == "price") then
			editor.lines[data]:SetValue(3, entity:GetPrice(data))
		elseif (key == "stockDisable") then
			editor.lines[data]:SetValue(4, "-")
		elseif (key == "stockMax" or key == "stock") then
			local current, max = entity:GetStock(data)

			editor.lines[data]:SetValue(4, current.."/"..max)
		elseif (key == "faction") then
			local uniqueID = data[1]
			local state = data[2]
			local panel = nut.gui.editorFaction

			entity.factions[uniqueID] = state

			if (IsValid(panel) and IsValid(panel.factions[uniqueID])) then
				panel.factions[uniqueID]:SetChecked(state == true)
			end
		elseif (key == "class") then
			local uniqueID = data[1]
			local state = data[2]
			local panel = nut.gui.editorFaction

			entity.classes[uniqueID] = state

			if (IsValid(panel) and IsValid(panel.classes[uniqueID])) then
				panel.classes[uniqueID]:SetChecked(state == true)
			end
		elseif (key == "model") then
			editor.model:SetText(entity:GetModel())
		elseif (key == "scale") then
			editor.sellScale.noSend = true
			editor.sellScale:SetValue(data)
		end

		surface.PlaySound("buttons/button14.wav")
	end)

	netstream.Hook("vendorMoney", function(value)
		local panel = nut.gui.vendor

		if (!IsValid(panel)) then
			return
		end

		local entity = panel.entity

		if (!IsValid(entity)) then
			return
		end

		entity.money = value

		local editor = nut.gui.vendorEditor

		if (IsValid(editor)) then
			local useMoney = tonumber(value) != nil

			editor.money:SetDisabled(!useMoney)
			editor.money:SetEnabled(useMoney)
			editor.money:SetText(useMoney and value or "∞")
		end
	end)

	netstream.Hook("vendorStock", function(uniqueID, amount)
		local panel = nut.gui.vendor

		if (!IsValid(panel)) then
			return
		end

		local entity = panel.entity

		if (!IsValid(entity)) then
			return
		end

		entity.items[uniqueID] = entity.items[uniqueID] or {}
		entity.items[uniqueID][VENDOR_STOCK] = amount

		local editor = nut.gui.vendorEditor

		if (IsValid(editor)) then
			local _, max = entity:GetStock(uniqueID)

			editor.lines[uniqueID]:SetValue(4, amount.."/"..max)
		end
	end)

	netstream.Hook("vendorAdd", function(uniqueID)
		if (IsValid(nut.gui.vendor)) then
			nut.gui.vendor:addItem(uniqueID, "buying")
		end
	end)
end
