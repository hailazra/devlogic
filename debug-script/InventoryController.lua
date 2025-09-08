local ReplicatedStorage = game:GetService("ReplicatedStorage")
local var2_upvw
local PlayerGui = game:GetService("Players").LocalPlayer.PlayerGui
local Inventory_upvr_2 = PlayerGui:WaitForChild("Inventory")
local Net = require(ReplicatedStorage.Packages.Net)
local spr_upvr = require(ReplicatedStorage.Packages.spr)
local StringLibrary_upvr = require(ReplicatedStorage.Shared.StringLibrary)
local ItemUtility_upvr = require(ReplicatedStorage.Shared.ItemUtility)
local TierUtility_upvr = require(ReplicatedStorage.Shared.TierUtility)
local PlayerStatsUtility_upvr = require(ReplicatedStorage.Shared.PlayerStatsUtility)
local GuiControl_upvr = require(ReplicatedStorage.Modules.GuiControl)
local any_RemoteEvent_result1_upvr_8 = Net:RemoteEvent("EquipItem")
local Pages = Inventory_upvr_2.Main.Content.Pages
local Inventory_upvr = Pages.Inventory
local Rods_upvr = Pages.Rods
local Baits_upvr = Pages.Baits
local Tile_upvr = Baits_upvr.Tile
Tile_upvr.Parent = nil
local Tile_upvr_3 = Inventory_upvr.Tile
Tile_upvr_3.Parent = nil
local Tile_upvr_2 = Rods_upvr.Tile
Tile_upvr_2.Parent = nil
local tbl_7_upvr = {}
local tbl_4_upvr = {}
local tbl_10_upvr = {}
local var23_upvw = "Items"
local var24_upvw = "Fishes"
local any_new_result1_upvr = require(ReplicatedStorage.Packages.Signal).new()
local var26_upvw = false
local var27_upvw = false
local module_upvr = {
	InventoryStateChanged = any_new_result1_upvr;
}
local tbl_9_upvr = {
	Fish = function(arg1) -- Line 104, Named "Fish"
		--[[ Upvalues[3]:
			[1]: var24_upvw (read and write)
			[2]: module_upvr (readonly)
			[3]: any_new_result1_upvr (readonly)
		]]
		if var24_upvw == "Fishes" then
		else
			module_upvr:SetPage("Items")
			module_upvr:SetCategory("Fishes")
			any_new_result1_upvr:Fire(arg1)
		end
	end;
	Inventory = function(arg1) -- Line 113, Named "Inventory"
		--[[ Upvalues[3]:
			[1]: var24_upvw (read and write)
			[2]: module_upvr (readonly)
			[3]: any_new_result1_upvr (readonly)
		]]
		if var24_upvw == "Items" then
		else
			module_upvr:SetPage("Items")
			module_upvr:SetCategory("Items")
			any_new_result1_upvr:Fire(arg1)
		end
	end;
	Potions = function(arg1) -- Line 122, Named "Potions"
		--[[ Upvalues[3]:
			[1]: var24_upvw (read and write)
			[2]: module_upvr (readonly)
			[3]: any_new_result1_upvr (readonly)
		]]
		if var24_upvw == "Potions" then
		else
			module_upvr:SetPage("Items")
			module_upvr:SetCategory("Potions")
			any_new_result1_upvr:Fire(arg1)
		end
	end;
	Rods = function(arg1) -- Line 131, Named "Rods"
		--[[ Upvalues[3]:
			[1]: var23_upvw (read and write)
			[2]: module_upvr (readonly)
			[3]: any_new_result1_upvr (readonly)
		]]
		if var23_upvw == "Fishing Rods" then
		else
			module_upvr:SetPage("Fishing Rods")
			module_upvr:SetCategory("Fishing Rods")
			any_new_result1_upvr:Fire(arg1)
		end
	end;
	Baits = function(arg1) -- Line 140, Named "Baits"
		--[[ Upvalues[3]:
			[1]: var23_upvw (read and write)
			[2]: module_upvr (readonly)
			[3]: any_new_result1_upvr (readonly)
		]]
		if var23_upvw == "Baits" then
		else
			module_upvr:SetPage("Baits")
			module_upvr:SetCategory("Baits")
			any_new_result1_upvr:Fire(arg1)
		end
	end;
}
local GamePassUtility_upvr = require(ReplicatedStorage.Shared.GamePassUtility)
local VendorController_upvr = require(ReplicatedStorage.Controllers.VendorController)
local var32_upvw
local any_RemoteEvent_result1_upvr = Net:RemoteEvent("ClaimNotification")
local Backpack_upvr = PlayerGui:WaitForChild("Backpack")
local InputControl_upvr = require(ReplicatedStorage.Modules.InputControl)
function module_upvr.Init(arg1) -- Line 151
	--[[ Upvalues[17]:
		[1]: Inventory_upvr_2 (readonly)
		[2]: var24_upvw (read and write)
		[3]: tbl_9_upvr (readonly)
		[4]: var26_upvw (read and write)
		[5]: GuiControl_upvr (readonly)
		[6]: var27_upvw (read and write)
		[7]: GamePassUtility_upvr (readonly)
		[8]: VendorController_upvr (readonly)
		[9]: any_new_result1_upvr (readonly)
		[10]: var32_upvw (read and write)
		[11]: spr_upvr (readonly)
		[12]: var23_upvw (read and write)
		[13]: var2_upvw (read and write)
		[14]: any_RemoteEvent_result1_upvr (readonly)
		[15]: Backpack_upvr (readonly)
		[16]: module_upvr (readonly)
		[17]: InputControl_upvr (readonly)
	]]
	local tbl_11 = {
		Baits = Inventory_upvr_2.Main.Top.Bobbers;
	}
	local function _(arg1_2) -- Line 154, Named "updateActionButtons"
		--[[ Upvalues[2]:
			[1]: Inventory_upvr_2 (copied, readonly)
			[2]: var24_upvw (copied, read and write)
		]]
		local var42
		if arg1_2 ~= "Fish" then
			var42 = true
			if arg1_2 ~= "Inventory" then
				var42 = true
				if var24_upvw ~= "Fishes" then
					if var24_upvw ~= "Items" then
						var42 = false
					else
						var42 = true
					end
				end
			end
		end
		Inventory_upvr_2.Main.Top.Favorite.Visible = var42
		var42 = Inventory_upvr_2.Main
		var42 = true
		if arg1_2 ~= "Fish" then
			if var24_upvw ~= "Fishes" then
				var42 = false
			else
				var42 = true
			end
		end
		var42.SellAll.Visible = var42
		var42 = Inventory_upvr_2.Main.Top
		if arg1_2 ~= "Fish" then
			var42 = false
		else
			var42 = true
		end
		var42.AutoOptions.Visible = var42
	end
	for i, _ in tbl_9_upvr do
		local SOME = Inventory_upvr_2.Main.Top.Options:FindFirstChild(i)
		if SOME then
			tbl_11[i] = SOME
		end
	end
	for i_2_upvr, v_2_upvr in tbl_9_upvr do
		local var44 = tbl_11[i_2_upvr]
		if var44 then
			if not var44:FindFirstChildOfClass("UIScale") then
				local UIScale = Instance.new("UIScale")
				UIScale.Scale = 1
				UIScale.Parent = var44
			end
			var44.Activated:Connect(function() -- Line 181
				--[[ Upvalues[3]:
					[1]: var26_upvw (copied, read and write)
					[2]: v_2_upvr (readonly)
					[3]: i_2_upvr (readonly)
				]]
				if var26_upvw then
				else
					LockOptions()
					v_2_upvr(i_2_upvr)
				end
			end)
		end
	end
	GuiControl_upvr:Hook("Hold Button", Inventory_upvr_2.Main.Top.Favorite).Clicked:Connect(function() -- Line 191
		--[[ Upvalues[2]:
			[1]: var26_upvw (copied, read and write)
			[2]: var27_upvw (copied, read and write)
		]]
		if var26_upvw then
		else
			LockOptions()
			SetBulkFavoriting(not var27_upvw)
		end
	end)
	GuiControl_upvr:Hook("Hold Button", Inventory_upvr_2.Main.SellAll).Clicked:Connect(function() -- Line 202
		--[[ Upvalues[3]:
			[1]: var26_upvw (copied, read and write)
			[2]: GamePassUtility_upvr (copied, readonly)
			[3]: VendorController_upvr (copied, readonly)
		]]
		if var26_upvw then
		else
			var26_upvw = true
			if not GamePassUtility_upvr:ClientPromptGamepassFromName("Sell Anywhere") then
				var26_upvw = false
				return
			end
			VendorController_upvr:SellAllItems():catch(function(arg1_3, arg2) -- Line 214
				--[[ Upvalues[1]:
					[1]: VendorController_upvr (copied, readonly)
				]]
				if arg2 then
					VendorController_upvr:_reportError(arg1_3)
				end
			end):await()
			var26_upvw = false
		end
	end)
	any_new_result1_upvr:Connect(function(arg1_4) -- Line 225
		--[[ Upvalues[5]:
			[1]: var32_upvw (copied, read and write)
			[2]: tbl_9_upvr (copied, readonly)
			[3]: Inventory_upvr_2 (copied, readonly)
			[4]: spr_upvr (copied, readonly)
			[5]: var24_upvw (copied, read and write)
		]]
		-- KONSTANTWARNING: Variable analysis failed. Output will have some incorrect variable assignments
		local var71 = arg1_4
		if not var71 then
			var71 = var32_upvw
		end
		local var72 = var71
		var32_upvw = var72
		for i_3, _ in tbl_9_upvr do
			local SOME_2 = Inventory_upvr_2.Main.Top.Options:FindFirstChild(i_3)
			if SOME_2 then
				local class_UIScale = SOME_2:FindFirstChildWhichIsA("UIScale")
				if class_UIScale then
					spr_upvr.stop(class_UIScale)
					if var72 == i_3 then
						spr_upvr.target(class_UIScale, 90, 325, {
							Scale = 1.2;
						})
					else
						spr_upvr.target(class_UIScale, 20, 60, {
							Scale = 1;
						})
					end
				end
			end
		end
		local var77 = var72
		if var77 ~= "Fish" then
			if var77 ~= "Inventory" then
				if var24_upvw ~= "Fishes" then
					if var24_upvw ~= "Items" then
					else
					end
				end
			end
		end
		Inventory_upvr_2.Main.Top.Favorite.Visible = true
		if var77 ~= "Fish" then
			if var24_upvw ~= "Fishes" then
			else
			end
		end
		Inventory_upvr_2.Main.SellAll.Visible = true
		if var77 ~= "Fish" then
		else
		end
		Inventory_upvr_2.Main.Top.AutoOptions.Visible = true
	end)
	any_new_result1_upvr:Connect(function() -- Line 255
		--[[ Upvalues[4]:
			[1]: var23_upvw (copied, read and write)
			[2]: var24_upvw (copied, read and write)
			[3]: var2_upvw (copied, read and write)
			[4]: any_RemoteEvent_result1_upvr (copied, readonly)
		]]
		-- KONSTANTERROR: [0] 1. Error Block 17 start (CF ANALYSIS FAILED)
		DestroyTiles()
		DrawTiles()
		local var79
		if var23_upvw == "Baits" then
			var79 = "Baits"
			-- KONSTANTWARNING: GOTO [18] #15
		end
		-- KONSTANTERROR: [0] 1. Error Block 17 end (CF ANALYSIS FAILED)
		-- KONSTANTERROR: [12] 10. Error Block 18 start (CF ANALYSIS FAILED)
		if var23_upvw == "Fishing Rods" then
			var79 = "Fishing Rods"
		else
			var79 = var24_upvw
		end
		local any_Get_result1 = var2_upvw:Get({"InventoryNotifications", var79})
		if any_Get_result1 and 0 < any_Get_result1 then
			any_RemoteEvent_result1_upvr:FireServer(var79)
		end
		-- KONSTANTERROR: [12] 10. Error Block 18 end (CF ANALYSIS FAILED)
	end)
	GuiControl_upvr.GuiFocusedSignal:Connect(function(arg1_5) -- Line 276
		--[[ Upvalues[4]:
			[1]: Inventory_upvr_2 (copied, readonly)
			[2]: any_new_result1_upvr (copied, readonly)
			[3]: var32_upvw (copied, read and write)
			[4]: var24_upvw (copied, read and write)
		]]
		if arg1_5 == Inventory_upvr_2 then
			any_new_result1_upvr:Fire(var32_upvw)
			local var85
			if var32_upvw then
				local var86 = var32_upvw
				var85 = Inventory_upvr_2.Main.Top
				var85 = true
				if var86 ~= "Fish" then
					var85 = true
					if var86 ~= "Inventory" then
						var85 = true
						if var24_upvw ~= "Fishes" then
							if var24_upvw ~= "Items" then
								var85 = false
							else
								var85 = true
							end
						end
					end
				end
				var85.Favorite.Visible = var85
				if var86 ~= "Fish" then
					if var24_upvw ~= "Fishes" then
					else
					end
				end
				Inventory_upvr_2.Main.SellAll.Visible = true
				if var86 ~= "Fish" then
				else
				end
				Inventory_upvr_2.Main.Top.AutoOptions.Visible = true
				return
			end
			Inventory_upvr_2.Main.Top.Favorite.Visible = true
			Inventory_upvr_2.Main.SellAll.Visible = true
			Inventory_upvr_2.Main.Top.AutoOptions.Visible = true
		end
	end)
	GuiControl_upvr.GuiUnfocusedSignal:Connect(function(arg1_6) -- Line 288
		--[[ Upvalues[1]:
			[1]: Inventory_upvr_2 (copied, readonly)
		]]
		if arg1_6 == Inventory_upvr_2 then
			DestroyTiles()
		end
	end)
	GuiControl_upvr:Hook("Hold Button", Backpack_upvr.Display.Inventory).Clicked:Connect(function() -- Line 295
		--[[ Upvalues[1]:
			[1]: module_upvr (copied, readonly)
		]]
		module_upvr:_bindFishes()
	end)
	GuiControl_upvr:Hook("Hold Button", Backpack_upvr.Display.Rods).Clicked:Connect(function() -- Line 299
		--[[ Upvalues[1]:
			[1]: module_upvr (copied, readonly)
		]]
		module_upvr:_bindFishingRods()
	end)
	InputControl_upvr:RegisterInput({Enum.KeyCode.Two}, {}, function(arg1_7) -- Line 303
		--[[ Upvalues[1]:
			[1]: module_upvr (copied, readonly)
		]]
		module_upvr:_bindFishingRods()
	end)
	InputControl_upvr:RegisterInput({Enum.KeyCode.Three}, {}, function(arg1_8) -- Line 307
		--[[ Upvalues[1]:
			[1]: module_upvr (copied, readonly)
		]]
		module_upvr:_bindFishes()
	end)
end
local Client_upvr = require(ReplicatedStorage.Packages.Replion).Client
local var95_upvw = false
local Constants_upvr = require(ReplicatedStorage.Shared.Constants)
local PromptController_upvr = require(ReplicatedStorage.Controllers.PromptController)
local any_RemoteFunction_result1_upvr = Net:RemoteFunction("UpdateAutoSellThreshold")
function module_upvr.Start(arg1) -- Line 312
	--[[ Upvalues[11]:
		[1]: var2_upvw (read and write)
		[2]: Client_upvr (readonly)
		[3]: GuiControl_upvr (readonly)
		[4]: tbl_4_upvr (readonly)
		[5]: tbl_10_upvr (readonly)
		[6]: Inventory_upvr_2 (readonly)
		[7]: TierUtility_upvr (readonly)
		[8]: var95_upvw (read and write)
		[9]: Constants_upvr (readonly)
		[10]: PromptController_upvr (readonly)
		[11]: any_RemoteFunction_result1_upvr (readonly)
	]]
	var2_upvw = Client_upvr:WaitReplion("Data")
	var2_upvw:OnChange("EquippedItems", function(arg1_9, arg2) -- Line 315
		--[[ Upvalues[2]:
			[1]: GuiControl_upvr (copied, readonly)
			[2]: tbl_4_upvr (copied, readonly)
		]]
		if not GuiControl_upvr:IsOpen("Inventory") then
		elseif typeof(arg1_9) == "table" then
			if typeof(arg2) == "table" then
				local _1 = arg1_9[1]
				local _1_2 = arg2[1]
				if _1 ~= _1_2 then
					local var105 = tbl_4_upvr[_1]
					if var105 then
						var105.UIStroke.Enabled = true
					end
					local var106 = tbl_4_upvr[_1_2]
					if var106 then
						var106.UIStroke.Enabled = false
					end
				end
			end
		end
	end)
	var2_upvw:OnChange("EquippedBaitId", function(arg1_10, arg2) -- Line 338
		--[[ Upvalues[1]:
			[1]: tbl_10_upvr (copied, readonly)
		]]
		if arg1_10 ~= arg2 then
			local var108 = tbl_10_upvr[arg1_10]
			if var108 then
				var108.UIStroke.Enabled = true
			end
			local var109 = tbl_10_upvr[arg2]
			if var109 then
				var109.UIStroke.Enabled = false
			end
		end
	end)
	local AutoOptions_upvr = Inventory_upvr_2.Main.Top.AutoOptions
	local function updateAutoSellThreshold(arg1_11) -- Line 355
		--[[ Upvalues[2]:
			[1]: TierUtility_upvr (copied, readonly)
			[2]: AutoOptions_upvr (readonly)
		]]
		if not arg1_11 then
		else
			local any_GetTier_result1_2 = TierUtility_upvr:GetTier(arg1_11)
			if any_GetTier_result1_2 then
				AutoOptions_upvr.Auto.UIGradient.Color = any_GetTier_result1_2.TierColor
				AutoOptions_upvr.Auto.Label.UIGradient.Color = any_GetTier_result1_2.TierColor
				AutoOptions_upvr.Auto.Label.Text = `Sell All: {any_GetTier_result1_2.Name}`
				return
			end
			AutoOptions_upvr.Auto.Label.Text = "Error Updating"
		end
	end
	GuiControl_upvr:Hook("Hold Button", AutoOptions_upvr.Auto).Clicked:Connect(function() -- Line 370
		--[[ Upvalues[6]:
			[1]: var95_upvw (copied, read and write)
			[2]: var2_upvw (copied, read and write)
			[3]: Constants_upvr (copied, readonly)
			[4]: TierUtility_upvr (copied, readonly)
			[5]: PromptController_upvr (copied, readonly)
			[6]: any_RemoteFunction_result1_upvr (copied, readonly)
		]]
		-- KONSTANTWARNING: Variable analysis failed. Output will have some incorrect variable assignments
		if var95_upvw then
		else
			var95_upvw = true
			local var113 = (table.find(Constants_upvr.AutoSellTiers, var2_upvw:GetExpect("AutoSellThreshold")) or 1) + 1
			if #Constants_upvr.AutoSellTiers < var113 then
				var113 = 1
			end
			local any_GetTier_result1 = TierUtility_upvr:GetTier(Constants_upvr.AutoSellTiers[var113])
			local var115
			if any_GetTier_result1 then
				var115 = nil
				if any_GetTier_result1.Name == "SECRET" then
					local any_await_result1, _ = PromptController_upvr:FirePrompt(`Turn on selling all <b><font color="#{any_GetTier_result1.TierColor.Keypoints[1].Value:ToHex()}">SECRET</font></b> Tier Fish?`):catch(warn):await()
					var115 = any_await_result1
				else
					var115 = true
				end
				if var115 and true then
					any_RemoteFunction_result1_upvr:InvokeServer(any_GetTier_result1.Tier)
				end
			end
			var95_upvw = false
		end
	end)
	var2_upvw:OnChange("AutoSellThreshold", updateAutoSellThreshold)
	updateAutoSellThreshold(var2_upvw:Get("AutoSellThreshold"))
end
function module_upvr.SetPage(arg1, arg2) -- Line 409
	--[[ Upvalues[1]:
		[1]: var23_upvw (read and write)
	]]
	if arg2 == var23_upvw then
	else
		var23_upvw = arg2
	end
end
function module_upvr.SetCategory(arg1, arg2) -- Line 417
	--[[ Upvalues[1]:
		[1]: var24_upvw (read and write)
	]]
	if arg2 == var24_upvw then
	else
		var24_upvw = arg2
	end
end
function module_upvr._bindFishingRods(arg1) -- Line 425
	--[[ Upvalues[3]:
		[1]: Inventory_upvr_2 (readonly)
		[2]: GuiControl_upvr (readonly)
		[3]: tbl_9_upvr (readonly)
	]]
	if Inventory_upvr_2.Enabled then
		GuiControl_upvr:Close()
	else
		tbl_9_upvr.Rods("Rods")
		GuiControl_upvr:Open("Inventory", false)
	end
end
function module_upvr._bindFishes(arg1) -- Line 434
	--[[ Upvalues[3]:
		[1]: Inventory_upvr_2 (readonly)
		[2]: GuiControl_upvr (readonly)
		[3]: tbl_9_upvr (readonly)
	]]
	if Inventory_upvr_2.Enabled then
		GuiControl_upvr:Close()
	else
		tbl_9_upvr.Fish("Fish")
		GuiControl_upvr:Open("Inventory", false)
	end
end
local any_RemoteEvent_result1_upvr_7 = Net:RemoteEvent("EquipBait")
function DrawBaitTile(arg1) -- Line 444
	--[[ Upvalues[9]:
		[1]: ItemUtility_upvr (readonly)
		[2]: tbl_10_upvr (readonly)
		[3]: Tile_upvr (readonly)
		[4]: PlayerStatsUtility_upvr (readonly)
		[5]: TierUtility_upvr (readonly)
		[6]: GuiControl_upvr (readonly)
		[7]: var2_upvw (read and write)
		[8]: any_RemoteEvent_result1_upvr_7 (readonly)
		[9]: Baits_upvr (readonly)
	]]
	-- KONSTANTWARNING: Variable analysis failed. Output will have some incorrect variable assignments
	local any_GetBaitData_result1_upvr_2 = ItemUtility_upvr:GetBaitData(arg1.Id)
	local var159
	if not any_GetBaitData_result1_upvr_2 then
	else
		var159 = tbl_10_upvr
		local var160
		if not var159[any_GetBaitData_result1_upvr_2.Data.Id] then
			var159 = Tile_upvr:Clone()
			var160 = var159.Padded
			var160 = any_GetBaitData_result1_upvr_2.Data.Name
			var160.Top.Label.Text = var160 or ""
			var160 = any_GetBaitData_result1_upvr_2.Data.Icon
			var159.BG.Vector.Image = var160 or ""
			local Modifiers_2 = any_GetBaitData_result1_upvr_2.Modifiers
			local var162
			if Modifiers_2 then
				var160 = var159.Padded.Bottom
				local Luck_2 = var160.Luck
				var160 = nil
				Luck_2.Parent = var160
				var160 = PlayerStatsUtility_upvr:GetVisualStats()
				local any_GetVisualStats_result1_3, any_GetVisualStats_result2_4 = PlayerStatsUtility_upvr:GetVisualStats()
				var162 = 0
				for _ in Modifiers_2 do
					var162 += 1
				end
				var159.Padded.Bottom.Size = UDim2.fromScale(1, var162 / 10)
				var159.Padded.Bottom.UIGridLayout.CellSize = UDim2.fromScale(1, 1 / var162 * 0.9)
				for i_7, v_6 in Modifiers_2 do
					local var166 = any_GetVisualStats_result1_3[i_7]
					if var166 then
						local var167 = any_GetVisualStats_result2_4[i_7]
						if var167 then
							local var168
							if var166:find("Multi") then
								var168 = `x{math.round((1 + v_6) * 10) / 10}`
							else
								var168 = `{math.round(v_6 * 100)}%`
							end
							local clone = Luck_2:Clone()
							clone.Label.Text = `{var166}:`
							clone.Counter.Text = var168
							clone.Counter.TextColor3 = var167
							clone.Parent = var159.Padded.Bottom
						end
					end
				end
				Luck_2:Destroy()
			end
			any_GetVisualStats_result1_3 = any_GetBaitData_result1_upvr_2.Data
			local Tier = any_GetVisualStats_result1_3.Tier
			any_GetVisualStats_result1_3 = Tier
			if any_GetVisualStats_result1_3 then
				any_GetVisualStats_result1_3 = TierUtility_upvr:GetTier(Tier)
			end
			if any_GetVisualStats_result1_3 then
				if 1 < Tier then
					var159.BG.Glow.UIGradient.Color = any_GetVisualStats_result1_3.TierColor
					var159.BG.Glow.Visible = true
					-- KONSTANTWARNING: GOTO [204] #140
				end
			end
			var159.BG.Glow.Visible = false
			GuiControl_upvr:Hook("Hold Button", var159).Clicked:Connect(function() -- Line 521
				--[[ Upvalues[3]:
					[1]: var2_upvw (copied, read and write)
					[2]: any_GetBaitData_result1_upvr_2 (readonly)
					[3]: any_RemoteEvent_result1_upvr_7 (copied, readonly)
				]]
				if var2_upvw:GetExpect("EquippedBaitId") ~= any_GetBaitData_result1_upvr_2.Data.Id then
					any_RemoteEvent_result1_upvr_7:FireServer(any_GetBaitData_result1_upvr_2.Data.Id)
				end
			end)
			if any_GetBaitData_result1_upvr_2.Modifiers then
				local _ = (any_GetBaitData_result1_upvr_2.Modifiers.BaseLuck or 0) * -1000
			else
			end
			var159.LayoutOrder = string.len(any_GetBaitData_result1_upvr_2.Data.Name)
			var159.Parent = Baits_upvr
			tbl_10_upvr[any_GetBaitData_result1_upvr_2.Data.Id] = var159
		end
		if var2_upvw:GetExpect("EquippedBaitId") ~= any_GetBaitData_result1_upvr_2.Data.Id then
			var159 = false
		else
			var159 = true
		end
		var159.UIStroke.Enabled = var159
	end
end
local any_RemoteEvent_result1_upvr_3 = Net:RemoteEvent("UnequipRodSkin")
local any_RemoteEvent_result1_upvr_6 = Net:RemoteEvent("EquipRodSkin")
function DrawFishingRodTile(arg1, arg2) -- Line 541
	--[[ Upvalues[13]:
		[1]: ItemUtility_upvr (readonly)
		[2]: Rods_upvr (readonly)
		[3]: tbl_4_upvr (readonly)
		[4]: Tile_upvr_2 (readonly)
		[5]: StringLibrary_upvr (readonly)
		[6]: PlayerStatsUtility_upvr (readonly)
		[7]: TierUtility_upvr (readonly)
		[8]: GuiControl_upvr (readonly)
		[9]: var2_upvw (read and write)
		[10]: any_RemoteEvent_result1_upvr_8 (readonly)
		[11]: spr_upvr (readonly)
		[12]: any_RemoteEvent_result1_upvr_3 (readonly)
		[13]: any_RemoteEvent_result1_upvr_6 (readonly)
	]]
	-- KONSTANTWARNING: Variable analysis failed. Output will have some incorrect variable assignments
	local any_GetItemData_result1_2 = ItemUtility_upvr:GetItemData(arg1.Id)
	local var223
	if not any_GetItemData_result1_2 then
	else
		if any_GetItemData_result1_2.Data.Type ~= "Fishing Rods" then return end
		var223 = any_GetItemData_result1_2.Data
		if Rods_upvr:FindFirstChild(var223.Name) then return end
		local Metadata = arg1.Metadata
		var223 = tbl_4_upvr
		local var225
		if not var223[arg1.UUID] then
			var223 = Tile_upvr_2:Clone()
			local EquipAsSkin_upvr_2 = var223.Padded.Top.EquipAsSkin
			local RollData_2 = any_GetItemData_result1_2.RollData
			var225 = any_GetItemData_result1_2.Data
			var223.Name = var225.Name
			var225 = var223.Padded.Top
			var225 = any_GetItemData_result1_2.Data.Name or ""
			var225.Label.Text = var225
			var225 = var223.BG
			var225 = any_GetItemData_result1_2.Data.Icon or ""
			var225.Vector.Image = var225
			if not not any_GetItemData_result1_2.IsSkin then
				var225 = var223.Padded
				var225 = false
				var225.Bottom.Visible = var225
			else
				if RollData_2 then
					var225 = (RollData_2.BaseLuck or 1) * 100
					if any_GetItemData_result1_2.VisualClickPowerPercent then
						var225 = math.round(any_GetItemData_result1_2.VisualClickPowerPercent * 100)
					else
						var225 = math.round(((any_GetItemData_result1_2.ClickPower or 0.05) * 25) ^ 2.5)
					end
					var223.Padded.Bottom.Luck.Counter.Text = `{math.floor(var225)}%`
					var223.Padded.Bottom.Speed.Counter.Text = `{var225}%`
					var223.Padded.Bottom.Weight.Counter.Text = StringLibrary_upvr:AddWeight(any_GetItemData_result1_2.MaxWeight or 5)
				end
				local Modifiers_4 = any_GetItemData_result1_2.Modifiers
				if Modifiers_4 then
					local any_GetVisualStats_result1_4, any_GetVisualStats_result2_3 = PlayerStatsUtility_upvr:GetVisualStats()
					for i_8, v_7 in Modifiers_4 do
						local var232 = any_GetVisualStats_result1_4[i_8]
						if var232 then
							local var233 = any_GetVisualStats_result2_3[i_8]
							if var233 then
								local var234
								if var232:find("Multi") then
									var234 = `x{math.round((1 + v_7) * 10) / 10}`
								else
									var234 = `{math.round(v_7 * 100)}%`
								end
								local clone_2 = var223.Padded.Bottom.Luck:Clone()
								clone_2.Label.Text = `{var232}:`
								clone_2.Counter.Text = var234
								clone_2.Counter.TextColor3 = var233
								clone_2.Parent = var223.Padded.Bottom
							end
						end
					end
				end
				var223.Padded.Bottom.Visible = true
			end
			local Tier_3 = any_GetItemData_result1_2.Data.Tier
			if Tier_3 then
				local onSkinChanged
			end
			if TierUtility_upvr:GetTier(Tier_3) and 1 < Tier_3 then
				-- KONSTANTERROR: Expression was reused, decompilation is incorrect
				var223.Padded.Top.TierLabel.Text = TierUtility_upvr:GetTier(Tier_3).Name
				onSkinChanged = var223.Padded
				-- KONSTANTERROR: Expression was reused, decompilation is incorrect
				onSkinChanged.Top.TierLabel.UIGradient.Color = TierUtility_upvr:GetTier(Tier_3).TierColor
				var223.Padded.Top.TierLabel.Visible = true
				-- KONSTANTERROR: Expression was reused, decompilation is incorrect
				var223.BG.Glow.UIGradient.Color = TierUtility_upvr:GetTier(Tier_3).TierColor
				var223.BG.Glow.Visible = true
			else
				var223.BG.Glow.Visible = false
			end
			local var238 = not not any_GetItemData_result1_2.IsSkin
			onSkinChanged = any_GetItemData_result1_2.EquipAsSkin
			local var239 = not not onSkinChanged
			if not var238 then
				onSkinChanged = GuiControl_upvr:Hook("Hold Button", var223).Clicked
				onSkinChanged = onSkinChanged:Connect
				onSkinChanged(function() -- Line 645
					--[[ Upvalues[3]:
						[1]: var2_upvw (copied, read and write)
						[2]: arg1 (readonly)
						[3]: any_RemoteEvent_result1_upvr_8 (copied, readonly)
					]]
					if table.find(var2_upvw:GetExpect("EquippedItems"), arg1.UUID) == nil then
						any_RemoteEvent_result1_upvr_8:FireServer(arg1.UUID, "Fishing Rods")
					end
				end)
			end
			if var238 or var239 then
				function onSkinChanged(arg1_13) -- Line 654
					--[[ Upvalues[3]:
						[1]: spr_upvr (copied, readonly)
						[2]: EquipAsSkin_upvr_2 (readonly)
						[3]: arg1 (readonly)
					]]
					spr_upvr.stop(EquipAsSkin_upvr_2)
					if arg1_13 == arg1.UUID then
						EquipAsSkin_upvr_2.Label.Text = "UNEQUIP SKIN"
						spr_upvr.target(EquipAsSkin_upvr_2, 3, 10, {
							ImageColor3 = Color3.fromRGB(255, 94, 97);
						})
					else
						EquipAsSkin_upvr_2.Label.Text = "EQUIP SKIN"
						spr_upvr.target(EquipAsSkin_upvr_2, 3, 10, {
							ImageColor3 = Color3.fromRGB(123, 187, 255);
						})
					end
				end
				local any_Hook_result1_4 = GuiControl_upvr:Hook("Hold Button", EquipAsSkin_upvr_2)
				local any_OnChange_result1_upvr = var2_upvw:OnChange("EquippedSkinUUID", onSkinChanged)
				any_Hook_result1_4.Cleaner:Add(function() -- Line 673
					--[[ Upvalues[1]:
						[1]: any_OnChange_result1_upvr (readonly)
					]]
					any_OnChange_result1_upvr:Disconnect()
				end)
				any_Hook_result1_4.Clicked:Connect(function() -- Line 677
					--[[ Upvalues[5]:
						[1]: var2_upvw (copied, read and write)
						[2]: arg1 (readonly)
						[3]: any_RemoteEvent_result1_upvr_3 (copied, readonly)
						[4]: any_RemoteEvent_result1_upvr_6 (copied, readonly)
						[5]: GuiControl_upvr (copied, readonly)
					]]
					if var2_upvw:GetExpect("EquippedSkinUUID") == arg1.UUID then
						any_RemoteEvent_result1_upvr_3:FireServer()
					else
						any_RemoteEvent_result1_upvr_6:FireServer(arg1.UUID)
						GuiControl_upvr:Close()
					end
				end)
				onSkinChanged(var2_upvw.Data.EquippedSkinUUID)
				EquipAsSkin_upvr_2.Visible = true
			else
				onSkinChanged = EquipAsSkin_upvr_2:Destroy
				onSkinChanged()
			end
			onSkinChanged = nil
			if any_GetItemData_result1_2.RollData then
				any_OnChange_result1_upvr = any_GetItemData_result1_2.RollData.BaseLuck
				any_OnChange_result1_upvr = Tier_3 or 0
				onSkinChanged = any_OnChange_result1_upvr * -1000 + any_OnChange_result1_upvr
				-- KONSTANTWARNING: GOTO [424] #292
			end
			if var238 or var239 then
				any_OnChange_result1_upvr = Tier_3 or 0
				onSkinChanged = 500 + any_OnChange_result1_upvr
			else
				onSkinChanged = Tier_3 or 0
			end
			var223.LayoutOrder = onSkinChanged
			var223.Parent = Rods_upvr
			local var247 = var223
			any_OnChange_result1_upvr = arg1.UUID
			tbl_4_upvr[any_OnChange_result1_upvr] = var223
		end
		EquipAsSkin_upvr_2 = table.find(arg2, arg1.UUID)
		local var248
		if EquipAsSkin_upvr_2 == nil then
			var223 = false
		else
			var223 = true
		end
		EquipAsSkin_upvr_2 = var247.UIStroke
		EquipAsSkin_upvr_2.Enabled = var223
		var248 = var247.Padded
		EquipAsSkin_upvr_2 = var248.Top
		local var249 = EquipAsSkin_upvr_2
		if Metadata then
			if Metadata.VariantId then
				var248 = ItemUtility_upvr:GetVariantData(Metadata.VariantId)
				local var250 = var248
			else
				var250 = nil
			end
			if var250 then
				var249.MutationFrame.Label.Text = var250.Data.Name
				var249.MutationFrame.Label.UIGradient.Color = var250.Data.TierColor
				var249.MutationFrame.Visible = true
			else
				var249.MutationFrame.Visible = false
			end
			if Metadata.EnchantId then
				local _ = ItemUtility_upvr:GetEnchantData(Metadata.EnchantId)
			else
			end
			if nil then
				-- KONSTANTERROR: Expression was reused, decompilation is incorrect
				var247.EnchantGradient.UIGradient.Color = nil.Data.TierColor
				var247.EnchantGradient.Visible = true
				-- KONSTANTERROR: Expression was reused, decompilation is incorrect
				if nil.Data then
					-- KONSTANTERROR: Expression was reused, decompilation is incorrect
					if nil.Data.Description then
						-- KONSTANTERROR: Expression was reused, decompilation is incorrect
						-- KONSTANTWARNING: GOTO [544] #368
					end
				end
				var249.EnchantFrame.Description.Text = "\"Unknown\""
				-- KONSTANTERROR: Expression was reused, decompilation is incorrect
				var249.EnchantFrame.Description.UIGradient.Color = nil.Data.TierColor
				-- KONSTANTERROR: Expression was reused, decompilation is incorrect
				var249.EnchantFrame.Label.Text = nil.Data.Name
				-- KONSTANTERROR: Expression was reused, decompilation is incorrect
				var249.EnchantFrame.Label.UIGradient.Color = nil.Data.TierColor
				var249.EnchantFrame.Visible = true
			else
				if var250 then
					var247.EnchantGradient.UIGradient.Color = var250.Data.TierColor
					var247.EnchantGradient.Visible = true
					return
				end
				var247.EnchantGradient.Visible = false
			end
		end
		var250 = var247.EnchantGradient
		var250.Visible = false
		var250 = var249.MutationFrame
		var250.Visible = false
		var250 = var249.EnchantFrame
		var250.Visible = false
	end
end
local ItemStringUtility_upvr = require(ReplicatedStorage.Modules.ItemStringUtility)
local any_RemoteFunction_result1_upvr_2 = Net:RemoteFunction("ConsumePotion")
local TextNotificationController_upvr = require(ReplicatedStorage.Controllers.TextNotificationController)
local Soundbook_upvr = require(ReplicatedStorage.Shared.Soundbook)
local any_RemoteEvent_result1_upvr_2 = Net:RemoteEvent("FavoriteItem")
local any_RemoteEvent_result1_upvr_4 = Net:RemoteEvent("UnequipItem")
local RegisterButtonTooltip_upvr = require(ReplicatedStorage.Modules.RegisterButtonTooltip)
local Tooltip_upvr = require(ReplicatedStorage.Controllers.PotionController.Tooltip)
local any_RemoteEvent_result1_upvr_5 = Net:RemoteEvent("FavoriteStateChanged")
function DrawInventoryTile(arg1, arg2) -- Line 754
	--[[ Upvalues[22]:
		[1]: ItemUtility_upvr (readonly)
		[2]: var24_upvw (read and write)
		[3]: TierUtility_upvr (readonly)
		[4]: tbl_7_upvr (readonly)
		[5]: ItemStringUtility_upvr (readonly)
		[6]: Tile_upvr_3 (readonly)
		[7]: StringLibrary_upvr (readonly)
		[8]: GuiControl_upvr (readonly)
		[9]: var26_upvw (read and write)
		[10]: any_RemoteFunction_result1_upvr_2 (readonly)
		[11]: TextNotificationController_upvr (readonly)
		[12]: Soundbook_upvr (readonly)
		[13]: any_new_result1_upvr (readonly)
		[14]: var27_upvw (read and write)
		[15]: any_RemoteEvent_result1_upvr_2 (readonly)
		[16]: var2_upvw (read and write)
		[17]: any_RemoteEvent_result1_upvr_4 (readonly)
		[18]: any_RemoteEvent_result1_upvr_8 (readonly)
		[19]: RegisterButtonTooltip_upvr (readonly)
		[20]: Tooltip_upvr (readonly)
		[21]: any_RemoteEvent_result1_upvr_5 (readonly)
		[22]: Inventory_upvr (readonly)
	]]
	-- KONSTANTWARNING: Variable analysis failed. Output will have some incorrect variable assignments
	local var284_upvw
	if arg1 == "Potions" then
		var284_upvw = ItemUtility_upvr:GetPotionData(arg2.Id)
		if not var284_upvw then
			do
				return
			end
			-- KONSTANTWARNING: GOTO [57] #44
		end
	elseif arg1 == "Items" then
		var284_upvw = ItemUtility_upvr.GetItemDataFromItemType("Items", arg2.Id)
		if not var284_upvw then return end
		if var284_upvw then
			if var284_upvw.Data.Type == "Fishes" then
				do
					return
				end
				-- KONSTANTWARNING: GOTO [57] #44
			end
			-- KONSTANTWARNING: GOTO [57] #44
		end
	else
		var284_upvw = ItemUtility_upvr.GetItemDataFromItemType(var24_upvw, arg2.Id)
		if not var284_upvw then return end
		if var284_upvw then
			if var284_upvw.Data.Type ~= arg1 then return end
		end
	end
	local Metadata_4 = arg2.Metadata
	if Metadata_4 then
		local Weight_2 = Metadata_4.Weight
	end
	local Probability_2 = var284_upvw.Probability
	local var288_upvw = 0
	local var289
	if Probability_2 then
		var289 = TierUtility_upvr:GetTierFromRarity(Probability_2.Chance)
		local _ = var289
		var289 = math.log10(Probability_2.Chance) * 1000000
		var288_upvw = var289 - (Weight_2 or 0) * 100
	else
		var289 = var284_upvw.Data
		if var289 then
		end
		if var284_upvw.Data.Tier then
			-- KONSTANTERROR: Expression was reused, decompilation is incorrect (x2)
			var288_upvw = var284_upvw.Data.Tier * 1000000 - (Weight_2 or 0) * 100
		end
	end
	if not tbl_7_upvr[arg2.UUID] then
		local clone_6_upvr = Tile_upvr_3:Clone()
		clone_6_upvr.ItemName.Text = ItemStringUtility_upvr.GetItemName(arg2, var284_upvw)
		clone_6_upvr.Vector.Image = var284_upvw.Data.Icon or ""
		local var292 = Metadata_4
		if var292 then
			var292 = Metadata_4.VariantId
		end
		local var293 = var292
		if var293 then
			var293 = ItemUtility_upvr:GetVariantData(var292)
		end
		if var293 then
			clone_6_upvr.Variant.UIGradient.Color = var293.Data.TierColor
			clone_6_upvr.Variant.ItemName.UIGradient.Color = var293.Data.TierColor
			clone_6_upvr.Variant.ItemName.Text = var293.Data.Name
			clone_6_upvr.Variant.Visible = true
		else
			clone_6_upvr.Variant.Visible = false
		end
		local Weight_3 = var284_upvw.Weight
		local var295
		if Weight_3 and Weight_2 then
			if Weight_3.Default.Max > Weight_2 then
				var295 = false
			else
				var295 = true
			end
			if var295 then
				clone_6_upvr.Vector.Size = UDim2.fromScale(1.4, 1.4)
				clone_6_upvr.ClipsDescendants = true
			end
			clone_6_upvr.WeightFrame.Weight.Text = StringLibrary_upvr:AddWeight(Weight_2)
			clone_6_upvr.WeightFrame.Weight.Visible = true
		else
			var295 = arg2.Quantity
			if var295 then
				var295 = 'x'..StringLibrary_upvr:AddCommas(arg2.Quantity)
				clone_6_upvr.WeightFrame.Weight.Text = var295
				clone_6_upvr.WeightFrame.Weight.Visible = true
			else
				var295 = clone_6_upvr.WeightFrame.Weight
				var295.Visible = false
			end
		end
		if TierUtility_upvr:GetTier(var284_upvw.Data.Tier) then
			var295 = clone_6_upvr.Shadow.UIGradient
			-- KONSTANTERROR: Expression was reused, decompilation is incorrect
			var295.Color = TierUtility_upvr:GetTier(var284_upvw.Data.Tier).TierColor
			var295 = clone_6_upvr.ItemName
			-- KONSTANTERROR: Expression was reused, decompilation is incorrect
			var295.TextColor3 = TierUtility_upvr:GetTier(var284_upvw.Data.Tier).TierColor.Keypoints[1].Value
		end
		local any_Hook_result1_2 = GuiControl_upvr:Hook("Hold Button", clone_6_upvr)
		any_Hook_result1_2.Clicked:Connect(function() -- Line 857
			--[[ Upvalues[13]:
				[1]: var26_upvw (copied, read and write)
				[2]: var284_upvw (read and write)
				[3]: any_RemoteFunction_result1_upvr_2 (copied, readonly)
				[4]: arg2 (readonly)
				[5]: TextNotificationController_upvr (copied, readonly)
				[6]: Soundbook_upvr (copied, readonly)
				[7]: var24_upvw (copied, read and write)
				[8]: any_new_result1_upvr (copied, readonly)
				[9]: var27_upvw (copied, read and write)
				[10]: any_RemoteEvent_result1_upvr_2 (copied, readonly)
				[11]: var2_upvw (copied, read and write)
				[12]: any_RemoteEvent_result1_upvr_4 (copied, readonly)
				[13]: any_RemoteEvent_result1_upvr_8 (copied, readonly)
			]]
			if var26_upvw then
			else
				LockOptions()
				if var284_upvw.Data.Type == "Potions" then
					if any_RemoteFunction_result1_upvr_2:InvokeServer(arg2.UUID, 1) then
						task.defer(function() -- Line 869
							--[[ Upvalues[2]:
								[1]: TextNotificationController_upvr (copied, readonly)
								[2]: Soundbook_upvr (copied, readonly)
							]]
							TextNotificationController_upvr:DeliverNotification({
								Type = "Text";
								Text = "Consumed potion!";
								TextColor = {
									R = 0;
									G = 255;
									B = 0;
								};
								CustomDuration = 2;
							})
							Soundbook_upvr.Sounds.PotionConsumed:Play().PlaybackSpeed = 1 + math.random() * 0.2
						end)
						task.delay(0.15, function() -- Line 881
							--[[ Upvalues[2]:
								[1]: var24_upvw (copied, read and write)
								[2]: any_new_result1_upvr (copied, readonly)
							]]
							if var24_upvw == "Potions" then
								any_new_result1_upvr:Fire("Potions")
							end
						end)
					end
					return
				end
				if var27_upvw then
					any_RemoteEvent_result1_upvr_2:FireServer(arg2.UUID)
					return
				end
				local any_GetExpect_result1 = var2_upvw:GetExpect("EquippedItems")
				if table.find(any_GetExpect_result1, arg2.UUID) then
					any_RemoteEvent_result1_upvr_4:FireServer(arg2.UUID)
					return
				end
				if #any_GetExpect_result1 < 5 then
					any_RemoteEvent_result1_upvr_8:FireServer(arg2.UUID, var284_upvw.Data.Type)
					return
				end
				any_RemoteEvent_result1_upvr_4:FireServer(any_GetExpect_result1[#any_GetExpect_result1])
			end
		end)
		RegisterButtonTooltip_upvr.new(clone_6_upvr, any_Hook_result1_2.Cleaner, function() -- Line 914
			--[[ Upvalues[4]:
				[1]: Tooltip_upvr (copied, readonly)
				[2]: clone_6_upvr (readonly)
				[3]: arg2 (readonly)
				[4]: var284_upvw (read and write)
			]]
			Tooltip_upvr.activate("Large", clone_6_upvr, arg2, var284_upvw.Data.Type)
		end, Tooltip_upvr.deactivate)
		local var305_upvw = tbl_7_upvr[arg2.UUID]
		any_Hook_result1_2.Cleaner:Add(any_RemoteEvent_result1_upvr_5.OnClientEvent:Connect(function(arg1_15, arg2_3) -- Line 919
			--[[ Upvalues[4]:
				[1]: arg2 (readonly)
				[2]: var305_upvw (read and write)
				[3]: var288_upvw (read and write)
				[4]: Soundbook_upvr (copied, readonly)
			]]
			if arg2.UUID == arg1_15 then
				SetFavorite(var305_upvw, arg2_3, var288_upvw)
				if arg2_3 then
					Soundbook_upvr.Sounds.Favorited:Play()
				end
			end
		end))
		clone_6_upvr.Parent = Inventory_upvr
		var305_upvw = clone_6_upvr
		tbl_7_upvr[arg2.UUID] = clone_6_upvr
	end
	clone_6_upvr = var305_upvw
	SetFavorite(clone_6_upvr, arg2.Favorited, var288_upvw)
	if arg2.Quantity then
		clone_6_upvr = 'x'
		clone_6_upvr = var305_upvw.WeightFrame.Weight
		clone_6_upvr.Text = clone_6_upvr..StringLibrary_upvr:AddCommas(arg2.Quantity)
	end
end
function SetFavorite(arg1, arg2, arg3) -- Line 946
	local var306 = not arg2
	local var307 = not var306
	if var307 then
		var306 = arg3 - 100000000
	else
		var306 = arg3
	end
	arg1.LayoutOrder = var306
	arg1.WeightFrame.Star.Visible = var307
	arg1.UIStroke.Enabled = var307
end
local HttpService_upvr = game:GetService("HttpService")
local var309_upvw
local None_upvr = Pages.None
function DrawTiles() -- Line 956
	--[[ Upvalues[12]:
		[1]: HttpService_upvr (readonly)
		[2]: var309_upvw (read and write)
		[3]: var23_upvw (read and write)
		[4]: tbl_4_upvr (readonly)
		[5]: var2_upvw (read and write)
		[6]: tbl_10_upvr (readonly)
		[7]: tbl_7_upvr (readonly)
		[8]: var24_upvw (read and write)
		[9]: None_upvr (readonly)
		[10]: Baits_upvr (readonly)
		[11]: Rods_upvr (readonly)
		[12]: Inventory_upvr (readonly)
	]]
	-- KONSTANTWARNING: Variable analysis failed. Output will have some incorrect variable assignments
	-- KONSTANTERROR: [41] 33. Error Block 5 start (CF ANALYSIS FAILED)
	-- KONSTANTERROR: [41] 33. Error Block 5 end (CF ANALYSIS FAILED)
	-- KONSTANTERROR: [44] 35. Error Block 7 start (CF ANALYSIS FAILED)
	-- KONSTANTERROR: [44] 35. Error Block 7 end (CF ANALYSIS FAILED)
	-- KONSTANTERROR: [72] 56. Error Block 13 start (CF ANALYSIS FAILED)
	-- KONSTANTERROR: [72] 56. Error Block 13 end (CF ANALYSIS FAILED)
	-- KONSTANTERROR: [75] 58. Error Block 15 start (CF ANALYSIS FAILED)
	-- KONSTANTERROR: [75] 58. Error Block 15 end (CF ANALYSIS FAILED)
	-- KONSTANTERROR: [107] 83. Error Block 24 start (CF ANALYSIS FAILED)
	-- KONSTANTERROR: [107] 83. Error Block 24 end (CF ANALYSIS FAILED)
	-- KONSTANTERROR: [0] 1. Error Block 57 start (CF ANALYSIS FAILED)
	-- KONSTANTWARNING: Failed to evaluate expression, replaced with nil [107.3]
	if nil == "Fishing Rods" then
		-- KONSTANTWARNING: Failed to evaluate expression, replaced with nil [107.10]
		-- KONSTANTWARNING: Failed to evaluate expression, replaced with nil [107.4294247790]
		-- KONSTANTWARNING: Failed to evaluate expression, replaced with nil [107.0]
		if nil == nil then
			-- KONSTANTWARNING: Failed to evaluate expression, replaced with nil [107.5]
			-- KONSTANTWARNING: Failed to evaluate expression, replaced with nil [107.6]
			-- KONSTANTWARNING: Failed to evaluate expression, replaced with nil [107.7]
			-- KONSTANTWARNING: GOTO [32] #26
		end
	else
		-- KONSTANTERROR: Expression was reused, decompilation is incorrect
		if nil == "Baits" then
			-- KONSTANTWARNING: Failed to evaluate expression, replaced with nil [107.9]
			-- KONSTANTERROR: Expression was reused, decompilation is incorrect
			if nil == nil then
				-- KONSTANTWARNING: Failed to evaluate expression, replaced with nil [107.4]
				-- KONSTANTERROR: Expression was reused, decompilation is incorrect (x2)
				-- KONSTANTWARNING: GOTO [64] #50
			end
		else
			-- KONSTANTERROR: Expression was reused, decompilation is incorrect
			if nil == "Potions" then
			else
			end
			-- KONSTANTERROR: Expression was reused, decompilation is incorrect (x2)
			if nil == nil then
				-- KONSTANTERROR: Expression was reused, decompilation is incorrect (x3)
				-- KONSTANTWARNING: GOTO [98] #76
			end
		end
	end
	-- KONSTANTERROR: [0] 1. Error Block 57 end (CF ANALYSIS FAILED)
	-- KONSTANTERROR: [110] 85. Error Block 41 start (CF ANALYSIS FAILED)
	-- KONSTANTWARNING: Failed to evaluate expression, replaced with nil [110.1]
	if nil then
		-- KONSTANTERROR: Expression was reused, decompilation is incorrect
		if next(nil) == nil then
			local var315 = true
		end
	end
	None_upvr.Visible = var315
	local var316 = false
	if var23_upvw == "Baits" then
		var316 = not var315
	end
	Baits_upvr.Visible = var316
	var316 = false
	local var317 = var316
	if var23_upvw == "Fishing Rods" then
		var317 = not var315
	end
	Rods_upvr.Visible = var317
	var317 = false
	local var318 = var317
	if var23_upvw == "Items" then
		var318 = not var315
	end
	Inventory_upvr.Visible = var318
	-- KONSTANTERROR: [110] 85. Error Block 41 end (CF ANALYSIS FAILED)
end
local any_new_result1_upvr_2 = require(ReplicatedStorage.Packages.Trove).new()
function DestroyTiles() -- Line 1016
	--[[ Upvalues[3]:
		[1]: any_new_result1_upvr_2 (readonly)
		[2]: tbl_7_upvr (readonly)
		[3]: tbl_4_upvr (readonly)
	]]
	any_new_result1_upvr_2:Clean()
	for _, v_4 in tbl_7_upvr do
		v_4:Destroy()
	end
	for _, v_5 in tbl_4_upvr do
		v_5:Destroy()
	end
	table.clear(tbl_7_upvr)
	table.clear(tbl_4_upvr)
	SetBulkFavoriting(false)
end
function SetBulkFavoriting(arg1) -- Line 1032
	--[[ Upvalues[2]:
		[1]: var27_upvw (read and write)
		[2]: Inventory_upvr_2 (readonly)
	]]
	var27_upvw = arg1
	local var324
	if arg1 then
		var324 = "ON"
	else
		var324 = "OFF"
	end
	Inventory_upvr_2.Main.Top.Favorite.Label.Text = `Favorite: {var324}`
end
function LockOptions() -- Line 1039
	--[[ Upvalues[1]:
		[1]: var26_upvw (read and write)
	]]
	var26_upvw = true
	task.delay(0.2, function() -- Line 1041
		--[[ Upvalues[1]:
			[1]: var26_upvw (copied, read and write)
		]]
		var26_upvw = false
	end)
end
return module_upvr
