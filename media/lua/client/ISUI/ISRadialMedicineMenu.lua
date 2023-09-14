require "TimedActions/ISBaseTimedAction"
require "ISUI/ISRadialMenu"

ISRadialMedicineMenu = ISBaseObject:derive("ISRadialMedicineMenu")

--#region Configurability / ModOptions.

local CONFIG = {}

local KEY_RMM = {
    name = "Radial Medicine Menu",
    key = Keyboard.KEY_Z,
}

local function setupDefaultConfig()
    CONFIG.display_radial_immediately = false
    CONFIG.allow_quick_rebandage = true
end

if ModOptions and ModOptions.AddKeyBinding then
    ModOptions:AddKeyBinding("[UI]", KEY_RMM)
end

if ModOptions and ModOptions.getInstance then
    local function onModOptionsApply(values)
        CONFIG.display_radial_immediately = values.settings.options.display_radial_immediately
        CONFIG.allow_quick_rebandage = values.settings.options.allow_quick_rebandage
    end

    local SETTINGS = {
        options_data = {
            display_radial_immediately = {
                name = "IGUI_DisplayRadMedImmediately",
                tooltip = nil,
                default = false,
                OnApplyMainMenu = onModOptionsApply,
                OnApplyInGame = onModOptionsApply,
            },
            allow_quick_rebandage = {
                name = "IGUI_AllowQuickRebandage",
                tooltip = nil,
                default = true,
                OnApplyMainMenu = onModOptionsApply,
                OnApplyInGame = onModOptionsApply,
            },
        },
        mod_id = 'RadialMedicineMenu',
        mod_shortname = 'RadMed',
        mod_fullname = 'Radial Medicine Menu',
    }

    local settings = ModOptions:getInstance(SETTINGS)
    
    ModOptions:loadFile()
    Events.OnPreMapLoad.Add(function() onModOptionsApply({ settings = SETTINGS }) end)
else
    setupDefaultConfig()
end

--#endregion

local bodyPartIcons = {
    ["Back"]        =   "media/ui/emotes/gears.png",
    ["Foot_L"]      =   "media/ui/bodyparts/Foot_L.png",
    ["Foot_R"]      =   "media/ui/bodyparts/Foot_R.png",
    ["ForeArm_L"]   =   "media/ui/bodyparts/ForeArm_L.png",
    ["ForeArm_R"]   =   "media/ui/bodyparts/ForeArm_R.png",
    ["Groin"]       =   "media/ui/bodyparts/Groin.png", 
    ["Hand_L"]      =   "media/ui/bodyparts/Hand_L.png",
    ["Hand_R"]      =   "media/ui/bodyparts/Hand_R.png", 
    ["Head"]        =   "media/ui/bodyparts/Head.png", 
    ["LowerLeg_L"]  =   "media/ui/bodyparts/LowerLeg_L.png", 
    ["LowerLeg_R"]  =   "media/ui/bodyparts/LowerLeg_R.png", 
    ["Neck"]        =   "media/ui/bodyparts/Neck.png", 
    ["Torso_Lower"] =   "media/ui/bodyparts/Torso_Lower.png", 
    ["Torso_Upper"] =   "media/ui/bodyparts/Torso_Upper.png", 
    ["UpperArm_L"]  =   "media/ui/bodyparts/UpperArm_L.png", 
    ["UpperArm_R"]  =   "media/ui/bodyparts/UpperArm_R.png", 
    ["UpperLeg_L"]  =   "media/ui/bodyparts/UpperLeg_L.png", 
    ["UpperLeg_R"]  =   "media/ui/bodyparts/UpperLeg_R.png"
}

local function len(t)
    local n = 0

    for _ in pairs(t) do
        n = n + 1
    end
    return n
end

function ISRadialMedicineMenu:getBodyPartIcon(s_typeBodyPart)
    local icon = getTexture(bodyPartIcons[s_typeBodyPart])
    icon:setWidth(64)
    icon:setHeight(64)
    return icon
end

function ISRadialMedicineMenu:getContainers(character)
    if not character then return end
    local playerNum = character and character:getPlayerNum() or -1
    -- get all the surrounding inventory of the player, gonna check for the item in them too
    local containerList = {}
    for i,v in ipairs(getPlayerInventory(playerNum).inventoryPane.inventoryPage.backpacks) do
        table.insert(containerList, v.inventory)
    end
    for i,v in ipairs(getPlayerLoot(playerNum).inventoryPane.inventoryPage.backpacks) do
        table.insert(containerList, v.inventory)
    end
    return containerList
end

function ISRadialMedicineMenu:getCharacterWounds(character)
    if not character then
        character = self.character
    end
    local t_wounds = {}
    local bodyDamage = character:getBodyDamage()

    for i = 0, bodyDamage:getBodyParts():size() - 1 do
        local bodyPart = bodyDamage:getBodyParts():get(i)
        if bodyPart:HasInjury() or bodyPart:stitched() or bodyPart:bandaged() then
            t_wounds[bodyPart] = {}
            t_wounds[bodyPart].health = bodyPart:getHealth()
            t_wounds[bodyPart].isBleeding = bodyPart:bleeding()
            t_wounds[bodyPart].isBandaged = bodyPart:bandaged()
            t_wounds[bodyPart].isBandageDirty = bodyPart:isBandageDirty()
            t_wounds[bodyPart].isDeepWounded = bodyPart:deepWounded()
            t_wounds[bodyPart].haveBullet = bodyPart:haveBullet()
            t_wounds[bodyPart].haveGlass = bodyPart:haveGlass()
            t_wounds[bodyPart].isBurnt = bodyPart:isBurnt()
            t_wounds[bodyPart].isNeedBurnWash = bodyPart:isNeedBurnWash()
            t_wounds[bodyPart].fractureTime = bodyPart:getFractureTime()
            t_wounds[bodyPart].isSplint = bodyPart:isSplint()
        end

    end

    return t_wounds
end

function ISRadialMedicineMenu:getUnbandagedBodyParts(characterWounds)
    local bodyParts = {}

    for k, v in pairs(characterWounds) do
        if not v.isBandaged then
            table.insert(bodyParts, k)
        end
    end
    return bodyParts
end

function ISRadialMedicineMenu:getBandagedBodyParts(characterWounds)
    local bodyParts = {}

    for k, v in pairs(characterWounds) do
        if v.isBandaged then
            table.insert(bodyParts, k)
        end
    end
    return bodyParts
end

function ISRadialMedicineMenu:getDeepWoundedBodyParts(characterWounds)
    local bodyParts = {}

    for k, v in pairs(characterWounds) do
        if (not v.isBandaged and v.isDeepWounded and not v.haveGlass) then
            table.insert(bodyParts, k)
        end
    end
    return bodyParts
end

function ISRadialMedicineMenu:getFragileWoundedBodyParts(characterWounds)
    local bodyParts = {}

    for k, v in pairs(characterWounds) do
        if not v.isBandaged and (v.haveGlass or v.haveBullet) then
            table.insert(bodyParts, k)
        end
    end
    return bodyParts
end

function ISRadialMedicineMenu:getBurntBodyParts(characterWounds)
    local bodyParts = {}

    for k, v in pairs(characterWounds) do
        if not v.isBandaged and (v.isBurnt and v.isNeedBurnWash) then
            table.insert(bodyParts, k)
        end
    end
    return bodyParts
end

function ISRadialMedicineMenu:getFracturedBodyParts(characterWounds)
    local bodyParts = {}

    for k, v in pairs(characterWounds) do
        -- can't splint chest/head
        if not (k:getType() == BodyPartType.Head or k:getType() == BodyPartType.Torso_Upper or k:getType() == BodyPartType.Torso_Lower) then
            if not v.isSplint and v.fractureTime > 0 then
                table.insert(bodyParts, k)
            end
        end
    end
    return bodyParts
end

function ISRadialMedicineMenu:getBodyPartsWithoutCataplasm(characterWounds)
    local bodyParts = {}

    for k, v in pairs(characterWounds) do
        if not v.isBandaged and k:getGarlicFactor() == 0 and k:getPlantainFactor() == 0 and k:getComfreyFactor() == 0 then
            table.insert(bodyParts, k)
        end
    end
    return bodyParts
end

function ISRadialMedicineMenu:isItemTypeInTable(table, item)
    if not table[item:getType()] then return false end
    if table[item:getType()]:getType() == item:getType() then
        return true
    end
    return false
end

function ISRadialMedicineMenu:findAllBestMedicine(character)
    if not character then
        character = self.character
    end
    local inventory = character:getInventory()
    local all_containers = self:getContainers(character)

    -- TODO: turn dictionaries to simple arrays/tables
    --       to avoid storing itemType as keys. 

    self.t_itemBandages = {}           -- Table of bandages : [itemType] = Item
    self.t_itemCleanBandages = {}      -- Table of clean bandages : [itemType] = Item
    self.t_itemDirtyBandages = {}      -- Table of dirty bandages : [itemType] = Item
    self.t_itemDisinfectants = {}      -- Table of disinfectants : [itemType] = Item
    self.t_itemPills = {}              -- Table of pills : [itemType] = Item
    self.t_itemCataplasms = {}          -- Table of cataplasms : [itemType] = Item
    self.t_itemTweezers = {}           -- Table of tweezers/sutureNeedleHolder : [itemType] = Item
    self.t_itemPlanks = {}             -- Plank/stick/etc for splint.
    self.itemNeedle = nil
    self.itemSutureNeedle = nil
    self.itemTweezers = nil
    self.itemSutureNeedleHolder = nil
    self.itemThread = nil
    self.itemSplint = nil
    self.itemRag = nil                 -- DirtyRag/RippedSheets for splint.

    if not all_containers then return end
    -----------------------------------------------------------
    ---  We are looking for one copy of each medical supplies, 
    ---  giving preference to those that are directly in the inventory of the character. 
    ---  Equipped bags and surroundings have the same priority.
    -----------------------------------------------------------
    for i = 1, #all_containers do
        for j = 0, all_containers[i]:getItems():size() - 1 do
            local item = all_containers[i]:getItems():get(j)

            --- Looking for bandages
            if item:isCanBandage() then
                if self:isItemTypeInTable(self.t_itemBandages, item) then
                    if inventory:contains(item, false) then
                        self.t_itemBandages[item:getType()] = item
                    end
                else
                    self.t_itemBandages[item:getType()] = item
                end

                if not string.match(item:getType(), "Dirty") then
                    if self:isItemTypeInTable(self.t_itemCleanBandages, item) then
                        if inventory:contains(item, false) then
                            self.t_itemCleanBandages[item:getType()] = item
                        end
                    else
                        self.t_itemCleanBandages[item:getType()] = item
                    end
                else
                    if self:isItemTypeInTable(self.t_itemDirtyBandages, item) then
                        if inventory:contains(item, false) then
                            self.t_itemDirtyBandages[item:getType()] = item
                        end
                    else
                        self.t_itemDirtyBandages[item:getType()] = item
                    end
                end
                    
            end

            --- Looking for disinfectants
            if item:getAlcoholPower() > 0 and not item:isCanBandage() then
                if self:isItemTypeInTable(self.t_itemDisinfectants, item) then
                    if inventory:contains(item, false) then
                        self.t_itemDisinfectants[item:getType()] = item
                    end
                else
                    self.t_itemDisinfectants[item:getType()] = item
                end
            end
            
            if self:startWith(item:getType(), "Pills") or item:getType() == "Antibiotics" then
                if self:isItemTypeInTable(self.t_itemPills, item) then
                    if inventory:contains(item, false) then
                        self.t_itemPills[item:getType()] = item
                    end
                else
                    self.t_itemPills[item:getType()] = item
                end
            end

            if item:getType() == "Tweezers" or item:getType() == "SutureNeedleHolder" then
                if self:isItemTypeInTable(self.t_itemTweezers, item) then
                    if inventory:contains(item, false) then
                        self.t_itemTweezers[item:getType()] = item
                    end
                else
                    self.t_itemTweezers[item:getType()] = item
                end

                if item:getType() == "Tweezers" then
                    if self.itemTweezers then
                        if inventory:contains(item, false) then
                            self.itemTweezers = item
                        end
                    else
                        self.itemTweezers = item
                    end
                end

                if item:getType() == "SutureNeedleHolder" then
                    if self.itemSutureNeedleHolder then
                        if inventory:contains(item, false) then
                            self.itemSutureNeedleHolder = item
                        end
                    else
                        self.itemSutureNeedleHolder = item
                    end
                end
            end

            if item:getType() == "SutureNeedle" then
                if self.itemSutureNeedle then
                    if inventory:contains(item, false) then
                        self.itemSutureNeedle = item
                    end
                else
                    self.itemSutureNeedle = item
                end
            end

            if item:getType() == "Needle" then
                if self.itemNeedle then
                    if inventory:contains(item, false) then
                        self.itemNeedle = item
                    end
                else
                    self.itemNeedle = item
                end
            end

            if item:getType() == "Thread" then
                if self.itemThread then
                    if inventory:contains(item, false) then
                        self.itemThread = item
                    end
                else
                    self.itemThread = item
                end
            end

            if item:getType() == "Splint" then
                if self.itemSplint then
                    if inventory:contains(item, false) then
                        self.itemSplint = item
                    end
                else
                    self.itemSplint = item
                end
            end

            if item:getType() == "Plank" or item:getType() == "TreeBranch" or item:getType() == "WoodenStick" then
                if self:isItemTypeInTable(self.t_itemPlanks, item) then
                    if inventory:contains(item, false) then
                        self.t_itemPlanks[item:getType()] = item
                    end
                else
                    self.t_itemPlanks[item:getType()] = item
                end
            end

            if item:getType() == "RippedSheets" or item:getType() == "RippedSheetsDirty" then
                if self.itemRag then
                    if inventory:contains(item, false) then
                        self.itemRag = item
                    end
                else
                    self.itemRag = item
                end
            end

            if string.match(item:getType(), "Cataplasm") then
                if self:isItemTypeInTable(self.t_itemCataplasms, item) then
                    if inventory:contains(item, false) then
                        self.t_itemCataplasms[item:getType()] = item
                    end
                else
                    self.t_itemCataplasms[item:getType()] = item
                end
            end   
        end
    end
end

function ISRadialMedicineMenu:transferIfNeeded(character, item)
    if instanceof(item, "InventoryItem") then
        if luautils.haveToBeTransfered(character, item) then
            if not luautils.walkToContainer(item:getContainer(), character:getPlayerNum()) then
                return
            end
            ISTimedActionQueue.add(ISInventoryTransferAction:new(character, item, item:getContainer(), character:getInventory()))
        end
    elseif instanceof(item, "ArrayList") then
        local items = item
        for i=1,items:size() do
            local item = items:get(i-1)
            if luautils.haveToBeTransfered(character, item) then
                if not luautils.walkToContainer(item:getContainer(), character:getPlayerNum()) then
                    return
                end
                ISTimedActionQueue.add(ISInventoryTransferAction:new(character, item, item:getContainer(), character:getInventory()))
            end
        end
    end
end

function ISRadialMedicineMenu:startWith(String, Start)
	return string.sub(String, 1, string.len(Start)) == Start
end

---------------------------------------------------
-- #TODO: split args -> action, bodypart, items --
---------------------------------------------------

function ISRadialMedicineMenu:takePills(args)
    if args == nil then return end
    local character = getSpecificPlayer(0)
    local srcContainer = args.item:getContainer()

    self:transferIfNeeded(character, args.item)
    
    -- wtf, why Antibiotics isn't Drainable??
    if not getActivatedMods():contains("AntibioticsNotFood") then
        if args.item:getType() == "Antibiotics" then
            ISTimedActionQueue.add(ISEatFoodAction:new(character, args.item))
            return
        end
    end

    local takePillsAction = ISTakePillAction:new(character, args.item, 165)
    ISTimedActionQueue.add(takePillsAction)
    if args.item:getDrainableUsesInt() > 1 and srcContainer:getType() ~= "floor" then
        ISTimedActionQueue.addAfter(takePillsAction, ISInventoryTransferAction:new(character, args.item, character:getInventory(), srcContainer))
    end
end

function ISRadialMedicineMenu:applyDisinfectant(args)
    if args == nil then return end
    local character = getSpecificPlayer(0)
    self:transferIfNeeded(character, args.item)
    ISTimedActionQueue.add(ISDisinfect:new(character, character, args.item, args.bodyPart))
end

function ISRadialMedicineMenu:applyBandage(args)
    if args == nil then return end
    local character = getSpecificPlayer(0)

    if args.action == "ContextMenu_Bandage" then
        self:transferIfNeeded(character, args.item)
        ISTimedActionQueue.add(ISApplyBandage:new(character, character, args.item, args.bodyPart, true))
        return
    end
    
    if args.action == "ContextMenu_Remove_Bandage" then
        ISTimedActionQueue.add(ISApplyBandage:new(character, character, nil, args.bodyPart))
        return
    end
    
    if args.action == "ContextMenu_Replace_Bandage" then
        self:transferIfNeeded(character, args.item)
        local applyBandageAction = ISApplyBandage:new(character, character, nil, args.bodyPart)
        ISTimedActionQueue.add(applyBandageAction)
        ISTimedActionQueue.addAfter(applyBandageAction, ISApplyBandage:new(character, character, args.item, args.bodyPart, true))
        return
    end

end

function ISRadialMedicineMenu:surgeon(args)
    if args == nil then return end
    local character = getSpecificPlayer(0)

    if args.action == "ContextMenu_Stitch" then
        self:transferIfNeeded(character, args.item)
        if instanceof(args.item, "InventoryItem") then
            ISTimedActionQueue.add(ISStitch:new(character, character, args.item, args.bodyPart, true))
        else
            ISTimedActionQueue.add(ISStitch:new(character, character, args.item:get(0), args.bodyPart, true))
        end
        return
    elseif args.action == "ContextMenu_Remove_Stitch"  then
        ISTimedActionQueue.add(ISStitch:new(character, character, args.item, args.bodyPart, false))
        return
    elseif args.action == "ContextMenu_Remove_Glass" then
        if args.item == "Hands" then
            ISTimedActionQueue.add(ISRemoveGlass:new(character, character, args.bodyPart, true))
        else
            self:transferIfNeeded(character, args.item)
            ISTimedActionQueue.add(ISRemoveGlass:new(character, character, args.bodyPart))
        end
        return
    elseif args.action == "ContextMenu_Remove_Bullet" then
        self:transferIfNeeded(character, args.item)
        ISTimedActionQueue.add(ISRemoveBullet:new(character, character, args.bodyPart))
        return
    elseif args.action == "ContextMenu_Clean_Burn" then
        self:transferIfNeeded(character, args.item)
        ISTimedActionQueue.add(ISCleanBurn:new(character, character, args.item, args.bodyPart))
        return
    end

end

-- Removing splint unavailable for now, idk, i think it's pointless.
function ISRadialMedicineMenu:splint(args)
    if args == nil then return end
    local character = getSpecificPlayer(0)

    if args.action == "ContextMenu_Splint" then
        self:transferIfNeeded(character, args.item)
        if instanceof(args.item, "InventoryItem") then
            ISTimedActionQueue.add(ISSplint:new(character, character, nil, args.item, args.bodyPart, true))
        else
            ISTimedActionQueue.add(ISSplint:new(character, character, args.item:get(0), args.item:get(1), args.bodyPart, true))
            return
        end
    elseif args.action == "ContextMenu_Splint_Remove" then
        ISTimedActionQueue.add(ISSplint:new(character, character, nil, nil, args.bodyPart))
        return
    end
end

function ISRadialMedicineMenu:applyCataplasm(args)
    if args == nil then return end
    local character = getSpecificPlayer(0)

    if args.item:getType() == "ComfreyCataplasm" then
        self:transferIfNeeded(character, args.item)
        ISTimedActionQueue.add(ISComfreyCataplasm:new(character, character, args.item, args.bodyPart))
        return
    elseif args.item:getType() == "PlantainCataplasm" then
        self:transferIfNeeded(character, args.item)
        ISTimedActionQueue.add(ISPlantainCataplasm:new(character, character, args.item, args.bodyPart))
        return
    elseif args.item:getType() == "WildGarlicCataplasm" then
        self:transferIfNeeded(character, args.item)
        ISTimedActionQueue.add(ISGarlicCataplasm:new(character, character, args.item, args.bodyPart))
        return
    end
end

---@return table|nil
function ISRadialMedicineMenu:createSubmenuItem(parent, childName, text, icon, func, args)

    if (parent == nil) then
        return nil
    end

    if (parent.subMenu == nil) then
        parent.subMenu = {}
    end

    if (parent.subMenu[childName] == nil) then
        parent.subMenu[childName] = {}
        parent.subMenu[childName].text = text
        parent.subMenu[childName].icon = icon

        if (func ~= nil) then
            parent.subMenu[childName].functions = func
        end

        if (args ~= nil) then
            parent.subMenu[childName].arguments = args
        end
    end

    return parent.subMenu[childName]
end

function ISRadialMedicineMenu:update()
    local t_wounds = self:getCharacterWounds(self.character)
    local t_unbandagedBodyParts = self:getUnbandagedBodyParts(t_wounds)
    local t_bandagedBodyParts = self:getBandagedBodyParts(t_wounds)
    local t_deepWoundedBodyParts = self:getDeepWoundedBodyParts(t_wounds)
    local t_fragileWoundedBodyParts = self:getFragileWoundedBodyParts(t_wounds)
    local t_burntBodyParts = self:getBurntBodyParts(t_wounds)
    local t_fracturedBodyParts = self:getFracturedBodyParts(t_wounds)
    local t_bodyPartsWithoutCataplasm = self:getBodyPartsWithoutCataplasm(t_wounds)

    self:findAllBestMedicine(self.character)

    ISRadialMedicineMenu.subMenu = {}

    if ( #t_unbandagedBodyParts > 0 and len(self.t_itemBandages) > 0 )
        or #t_bandagedBodyParts > 0 then

        local tempText = getText("ContextMenu_Bandage") .. "\n" .. getText("ContextMenu_Remove_Bandage")
        local dressingSubMenu = self:createSubmenuItem(self, "Dressing", tempText, getTexture("Item_Bandage"))
        
        if #t_unbandagedBodyParts > 0 then
            
            if len(self.t_itemBandages) > 0 then
                for i = 1, #t_unbandagedBodyParts do
                    local bpUnbandaged = t_unbandagedBodyParts[i]
                    local s_bpUnbandaged = bpUnbandaged:getType():toString()

                    tempText = BodyPartType.getDisplayName(bpUnbandaged:getType())
                    self:createSubmenuItem(dressingSubMenu, s_bpUnbandaged, tempText, self:getBodyPartIcon(s_bpUnbandaged))
                    for k, v in pairs(self.t_itemCleanBandages) do

                        self:createSubmenuItem(dressingSubMenu.subMenu[s_bpUnbandaged], k, v:getName(), v:getTexture(), self.applyBandage, {item = v, bodyPart = bpUnbandaged, action = "ContextMenu_Bandage"})
                    end

                    for k, v in pairs(self.t_itemDirtyBandages) do

                        self:createSubmenuItem(dressingSubMenu.subMenu[s_bpUnbandaged], k, v:getName(), v:getTexture(), self.applyBandage, {item = v, bodyPart = bpUnbandaged, action = "ContextMenu_Bandage"})
                    end
                    self:createSubmenuItem(dressingSubMenu.subMenu[s_bpUnbandaged], "Back", getText("IGUI_Emote_Back"), getTexture("media/ui/emotes/back.png"), self.fillMenu, dressingSubMenu.subMenu)
                end
            end

        end

        if #t_bandagedBodyParts > 0 then
            self:createSubmenuItem(dressingSubMenu, "Remove", getText("ContextMenu_Remove_Bandage"), getTexture("media/ui/emotes/no.png"))

            self:createSubmenuItem(dressingSubMenu, "Replace", "Replace bandage", getTexture("media/ui/emotes/followme.png"))

            for i = 1, #t_bandagedBodyParts do
                local bpBandaged = t_bandagedBodyParts[i]
                local s_bpBandaged = bpBandaged:getType():toString()

                self:createSubmenuItem(dressingSubMenu.subMenu["Remove"], s_bpBandaged, 
                        BodyPartType.getDisplayName(bpBandaged:getType()), self:getBodyPartIcon(s_bpBandaged),
                        self.applyBandage, {item = bpBandaged:getBandageType(), bodyPart = bpBandaged, action = "ContextMenu_Remove_Bandage"})

                if CONFIG.allow_quick_rebandage == true then

                    self:createSubmenuItem(dressingSubMenu.subMenu["Replace"], s_bpBandaged, BodyPartType.getDisplayName(bpBandaged:getType()), self:getBodyPartIcon(s_bpBandaged))

                    for k, v in pairs(self.t_itemCleanBandages) do
                        self:createSubmenuItem(dressingSubMenu.subMenu["Replace"].subMenu[s_bpBandaged], k,
                        v:getName(), v:getTexture(), self.applyBandage, {item = v, bodyPart = bpBandaged, action = "ContextMenu_Replace_Bandage"})
                    end

                    for k, v in pairs(self.t_itemDirtyBandages) do

                        self:createSubmenuItem(dressingSubMenu.subMenu["Replace"].subMenu[s_bpBandaged], k,
                        v:getName(), v:getTexture(), self.applyBandage, {item = v, bodyPart = bpBandaged, action = "ContextMenu_Replace_Bandage"})
                    end
                    self:createSubmenuItem(dressingSubMenu.subMenu["Replace"].subMenu[s_bpBandaged], "Back", getText("IGUI_Emote_Back"), getTexture("media/ui/emotes/back.png"), self.fillMenu, dressingSubMenu.subMenu)
                end
            end

            if CONFIG.allow_quick_rebandage == true then
                self:createSubmenuItem(dressingSubMenu.subMenu["Replace"], "Back", getText("IGUI_Emote_Back"), getTexture("media/ui/emotes/back.png"), self.fillMenu, dressingSubMenu.subMenu)
            end
            self:createSubmenuItem(dressingSubMenu.subMenu["Remove"], "Back", getText("IGUI_Emote_Back"), getTexture("media/ui/emotes/back.png"), self.fillMenu, dressingSubMenu.subMenu)
        end
        self:createSubmenuItem(dressingSubMenu, "Back", getText("IGUI_Emote_Back"), getTexture("media/ui/emotes/back.png"), self.fillMenu, self.subMenu)
    end
 
    if len(self.t_itemDisinfectants) > 0 then
        if #t_unbandagedBodyParts > 0 then
            
            local disinfectSubMenu = self:createSubmenuItem(self, "Disinfect", getText("ContextMenu_Disinfect"), getTexture("Item_AlcoholWipes"))
            for i = 1, #t_unbandagedBodyParts do
                local bpUnbandaged = t_unbandagedBodyParts[i]
                local s_bpUnbandaged = bpUnbandaged:getType():toString()

                self:createSubmenuItem(disinfectSubMenu, s_bpUnbandaged, BodyPartType.getDisplayName(bpUnbandaged:getType()), self:getBodyPartIcon(s_bpUnbandaged))
                for k, v in pairs(self.t_itemDisinfectants) do

                    self:createSubmenuItem(disinfectSubMenu.subMenu[s_bpUnbandaged], k, v:getName(), v:getTexture(), self.applyDisinfectant, {item = v, bodyPart = bpUnbandaged})
                end
                self:createSubmenuItem(disinfectSubMenu.subMenu[s_bpUnbandaged], "Back", getText("IGUI_Emote_Back"), getTexture("media/ui/emotes/back.png"), self.fillMenu, disinfectSubMenu.subMenu)
            end
            self:createSubmenuItem(disinfectSubMenu, "Back", getText("IGUI_Emote_Back"), getTexture("media/ui/emotes/back.png"), self.fillMenu, self.subMenu)
        end
    end

    if len(self.t_itemCataplasms) > 0 then
        if #t_bodyPartsWithoutCataplasm > 0 then

            local cataplasmSubMenu = self:createSubmenuItem(self, "Cataplasm", getText("ContextMenu_Bandage"), getTexture("Item_MashedHerbs"))
            for i = 1, #t_bodyPartsWithoutCataplasm do
                local bpUnbandaged = t_bodyPartsWithoutCataplasm[i]
                local s_bpUnbandaged = bpUnbandaged:getType():toString()

                self:createSubmenuItem(cataplasmSubMenu, s_bpUnbandaged, BodyPartType.getDisplayName(bpUnbandaged:getType()), self:getBodyPartIcon(s_bpUnbandaged))
                for k, v in pairs(self.t_itemCataplasms) do
                    local icon = v:getTexture()
                    if k == "PlantainCataplasm" then
                        icon = getTexture("Item_PlantainPlantago")
                    elseif k == "WildGarlicCataplasm" then
                        icon = getTexture("Item_WildGarlic")
                    elseif k == "ComfreyCataplasm" then
                        icon = getTexture("Item_Comfrey")
                    end

                    self:createSubmenuItem(cataplasmSubMenu.subMenu[s_bpUnbandaged], k, v:getName(), icon, self.applyCataplasm, {item = v, bodyPart = bpUnbandaged})
                end
                self:createSubmenuItem(cataplasmSubMenu.subMenu[s_bpUnbandaged], "Back", getText("IGUI_Emote_Back"), getTexture("media/ui/emotes/back.png"), self.fillMenu, cataplasmSubMenu.subMenu)
            end
            self:createSubmenuItem(cataplasmSubMenu, "Back", getText("IGUI_Emote_Back"), getTexture("media/ui/emotes/back.png"), self.fillMenu, self.subMenu)
        end
    end

    if ( #t_deepWoundedBodyParts > 0 and ( self.itemSutureNeedle or 
            (self.itemNeedle and self.itemThread) ) ) then

        local stitchSubMenu = self:createSubmenuItem(self, "Stitch", getText("ContextMenu_Stitch"), getTexture("Item_SutureNeedle"))
        for i = 1, #t_deepWoundedBodyParts do
            local bpDeepWounded = t_deepWoundedBodyParts[i]
            local s_bpDeepWounded = bpDeepWounded:getType():toString()

            self:createSubmenuItem(stitchSubMenu, s_bpDeepWounded, BodyPartType.getDisplayName(bpDeepWounded:getType()), self:getBodyPartIcon(s_bpDeepWounded))

            if self.itemSutureNeedle then
                self:createSubmenuItem(stitchSubMenu.subMenu[s_bpDeepWounded], self.itemSutureNeedle:getType(), self.itemSutureNeedle:getName(), self.itemSutureNeedle:getTexture(), self.surgeon, {item = self.itemSutureNeedle, bodyPart = bpDeepWounded, action = "ContextMenu_Stitch"})
            end
            if (self.itemNeedle and self.itemThread) then
                local items = ArrayList.new()
                items:add(self.itemThread)    items:add(self.itemNeedle)
                if self.itemSutureNeedleHolder then
                    items:add(self.itemSutureNeedleHolder)
                end
                self:createSubmenuItem(stitchSubMenu.subMenu[s_bpDeepWounded], self.itemNeedle:getType(), self.itemNeedle:getName(), self.itemNeedle:getTexture(), self.surgeon, {item = items, bodyPart = bpDeepWounded, action = "ContextMenu_Stitch"})
            end

            self:createSubmenuItem(stitchSubMenu.subMenu[s_bpDeepWounded], "Back", getText("IGUI_Emote_Back"), getTexture("media/ui/emotes/back.png"), self.fillMenu, stitchSubMenu.subMenu)
        end
        self:createSubmenuItem(stitchSubMenu, "Back", getText("IGUI_Emote_Back"), getTexture("media/ui/emotes/back.png"), self.fillMenu, self.subMenu)
    end

    if ( #t_fragileWoundedBodyParts > 0 and len(self.t_itemTweezers) > 0 ) then

        local fragileSubMenu = self:createSubmenuItem(self, "Fragiles", 
                    getText("ContextMenu_Remove_Glass") .. "/\n" .. getText("ContextMenu_Remove_Bullet"),
                        getTexture("Item_Tweezers"))
        for i = 1, #t_fragileWoundedBodyParts do
            local bpFragileWoundedBodyPart = t_fragileWoundedBodyParts[i]
            local s_bpFragileWoundedBodyPart = bpFragileWoundedBodyPart:getType():toString()

            self:createSubmenuItem(fragileSubMenu, s_bpFragileWoundedBodyPart, BodyPartType.getDisplayName(bpFragileWoundedBodyPart:getType()), self:getBodyPartIcon(s_bpFragileWoundedBodyPart))
            for k, v in pairs(self.t_itemTweezers) do
                local action
                if bpFragileWoundedBodyPart:haveGlass() then
                    action = "ContextMenu_Remove_Glass"
                else
                    action = "ContextMenu_Remove_Bullet"
                end
                self:createSubmenuItem(fragileSubMenu.subMenu[s_bpFragileWoundedBodyPart], k, v:getName(), v:getTexture(), self.surgeon, {item = v, bodyPart = bpFragileWoundedBodyPart, action = action})
            end

            if bpFragileWoundedBodyPart:haveGlass() then
                self:createSubmenuItem(fragileSubMenu.subMenu[s_bpFragileWoundedBodyPart], "Hands", getText("ContextMenu_Hand"), getTexture("media/ui/emotes/clap.png"), self.surgeon, {item = "Hands", bodyPart = bpFragileWoundedBodyPart, action = "ContextMenu_Remove_Glass"})
            end
            self:createSubmenuItem(fragileSubMenu.subMenu[s_bpFragileWoundedBodyPart], "Back", getText("IGUI_Emote_Back"), getTexture("media/ui/emotes/back.png"), self.fillMenu, fragileSubMenu.subMenu)
        end
        self:createSubmenuItem(fragileSubMenu, "Back", getText("IGUI_Emote_Back"), getTexture("media/ui/emotes/back.png"), self.fillMenu, self.subMenu)
    end

    if ( #t_burntBodyParts > 0 and len(self.t_itemCleanBandages) > 0 ) then

        local burntsSubMenu = self:createSubmenuItem(self, "Burnts", getText("ContextMenu_Clean_Burn"), getTexture("Item_Lighter"))
        for i = 1, #t_burntBodyParts do
            local bpBurnt = t_burntBodyParts[i]
            local s_bpBurnt = bpBurnt:getType():toString()
            
            self:createSubmenuItem(burntsSubMenu, s_bpBurnt, BodyPartType.getDisplayName(bpBurnt:getType()), self:getBodyPartIcon(s_bpBurnt))

            for k, v in pairs(self.t_itemCleanBandages) do
                self:createSubmenuItem(burntsSubMenu.subMenu[s_bpBurnt], k, v:getName(), v:getTexture(), self.surgeon, {item = v, bodyPart = bpBurnt, action = "ContextMenu_Clean_Burn"})
            end
            self:createSubmenuItem(burntsSubMenu.subMenu[s_bpBurnt], "Back", getText("IGUI_Emote_Back"), getTexture("media/ui/emotes/back.png"), self.fillMenu, burntsSubMenu)

        end
        self:createSubmenuItem(burntsSubMenu, "Back", getText("IGUI_Emote_Back"), getTexture("media/ui/emotes/back.png"), self.fillMenu, self.subMenu)
    end

    if (#t_fracturedBodyParts > 0 and (self.itemSplint or (len(self.t_itemPlanks) > 0 and self.itemRag)) ) then
        local fracturesSubMenu = self:createSubmenuItem(self, "Fractures", getText("ContextMenu_Splint"), getTexture("Item_Splint"))

        for i = 1, #t_fracturedBodyParts do
            local bpFractured = t_fracturedBodyParts[i]
            local s_bpFractured = bpFractured:getType():toString()
            
            self:createSubmenuItem(fracturesSubMenu, s_bpFractured, BodyPartType.getDisplayName(bpFractured:getType()), self:getBodyPartIcon(s_bpFractured))
            
            if self.t_itemPlanks and self.itemRag then
                for k, v in pairs(self.t_itemPlanks) do
                    local items = ArrayList.new()
                    items:add(self.itemRag)    items:add(v)
                    self:createSubmenuItem(fracturesSubMenu.subMenu[s_bpFractured], k, v:getName(), v:getTexture(), self.splint, {item = items, bodyPart = bpFractured, action = "ContextMenu_Splint"})
                end
            end
            
            if self.itemSplint then
                self:createSubmenuItem(fracturesSubMenu.subMenu[s_bpFractured], "itemSplint", self.itemSplint:getName(), self.itemSplint:getTexture(), self.splint, {item = self.itemSplint, bodyPart = bpFractured, action = "ContextMenu_Splint"})
            end
        end
        self:createSubmenuItem(fracturesSubMenu, "Back", getText("IGUI_Emote_Back"), getTexture("media/ui/emotes/back.png"), self.fillMenu, self.subMenu)
 
    end

    if len(self.t_itemPills) > 0 then

        local pillsSubMenu = self:createSubmenuItem(self, "Pills", getText("ContextMenu_Take_pills"), getTexture("Item_PillsAntidepressant"))

        for k, v in pairs(self.t_itemPills) do
            self:createSubmenuItem(pillsSubMenu, k, v:getName(), v:getTexture(), self.takePills, {item = v, category = "Pills"})
        end
        self:createSubmenuItem(pillsSubMenu, "Back", getText("IGUI_Emote_Back"), getTexture("media/ui/emotes/back.png"), self.fillMenu, self.subMenu)
    
    end

end

function ISRadialMedicineMenu:new(character)
	local o = ISBaseObject.new(self)
	o.character = character
	o.playerNum = character:getPlayerNum()
	return o
end

function ISRadialMedicineMenu:display()
	local menu = getPlayerRadialMenu(self.playerNum)
	self:center()
	menu:addToUIManager()
	if JoypadState.players[self.playerNum+1] then
		menu:setHideWhenButtonReleased(Joypad.DPadDown)
		setJoypadFocus(self.playerNum, menu)
		self.character:setJoypadIgnoreAimUntilCentered(true)
	end
end

function ISRadialMedicineMenu:center()
	local menu = getPlayerRadialMenu(self.playerNum)
	
	local x = getPlayerScreenLeft(self.playerNum)
	local y = getPlayerScreenTop(self.playerNum)
	local w = getPlayerScreenWidth(self.playerNum)
	local h = getPlayerScreenHeight(self.playerNum)
	
	x = x + w / 2
	y = y + h / 2
	
	menu:setX(x - menu:getWidth() / 2)
	menu:setY(y - menu:getHeight() / 2)
end

function ISRadialMedicineMenu:fillMenu(submenu)
    local menu = getPlayerRadialMenu(self.playerNum)
    menu:clear()

    local icon = nil
    if not submenu then
        submenu = self.subMenu
    end
    for _, v in pairs(submenu) do
        if v.icon then
            icon = v.icon
        else
            icon = nil
        end

        if v.subMenu then
            menu:addSlice(v.text, icon, self.fillMenu, self, v.subMenu)
        else
            menu:addSlice(v.text, icon, v.functions, self, v.arguments)
        end
        
    end
    self:display()
end

--#region Key events

local STATE = {}
STATE[1] = {}
STATE[2] = {}
STATE[3] = {}
STATE[4] = {}

function ISRadialMedicineMenu.checkKey(key)
    if key ~= KEY_RMM.key then
        return false
    end
    --if isGamePaused() then
    --    return false
    --end
    local character = getSpecificPlayer(0)
    if not character or character:isDead() then
        return false
    end
    local queue = ISTimedActionQueue.queues[character]
	if queue and #queue.queue > 0 then
		return false
	end
    return true
end

function ISRadialMedicineMenu.onKeyPressed(key)
    if not ISRadialMedicineMenu.checkKey(key) then
        return
    end

	local radialMenu = getPlayerRadialMenu(0)
    if getCore():getOptionRadialMenuKeyToggle() and radialMenu:isReallyVisible() then
        STATE[1].radialWasVisible = true
        radialMenu:removeFromUIManager()
        return
    end
    STATE[1].keyPressedMS = getTimestampMs()
    STATE[1].radialWasVisible = false
end

function ISRadialMedicineMenu.onKeyRepeat(key)
    if not ISRadialMedicineMenu.checkKey(key) then
        return
    end
    if STATE[1].radialWasVisible then
        return
    end
    if not STATE[1].keyPressedMS then
        return
    end

    local radialMenu = getPlayerRadialMenu(0)
    local delay = 500
    if CONFIG.display_radial_immediately == true then
		delay = 0
	end
    if (getTimestampMs() - STATE[1].keyPressedMS >= delay) and not radialMenu:isReallyVisible() then
        local menu = ISRadialMedicineMenu:new(getSpecificPlayer(0))
        menu:update()
        menu:fillMenu()
    end
end

function ISRadialMedicineMenu.onKeyReleased(key)
    if not ISRadialMedicineMenu.checkKey(key) then
		return
	end
	if not STATE[1].keyPressedMS then
		return
	end
	local radialMenu = getPlayerRadialMenu(0)
	if radialMenu:isReallyVisible() or STATE[1].radialWasVisible then
		if not getCore():getOptionRadialMenuKeyToggle() then
			radialMenu:removeFromUIManager()
		end
		return
	end
	STATE[1].keyPressedMS = nil
end

--#endregion

--#region Dpad support

function ISDPadWheels.onRadialMedicineMenu(joypadData)
    local menu = ISRadialMedicineMenu:new(getSpecificPlayer(joypadData.player))
    menu:update(getSpecificPlayer(joypadData.player))
    menu:fillMenu()
end

function ISDPadWheels.onRadialEmoteMenu(joypadData)
    local erm = ISEmoteRadialMenu:new(getSpecificPlayer(joypadData.player))
	erm:fillMenu()
end

function ISDPadWheels.onDisplayDown(joypadData)
    local isPaused = UIManager.getSpeedControls() and UIManager.getSpeedControls():getCurrentGameSpeed() == 0
	if isPaused then return end

    local menu = getPlayerRadialMenu(joypadData.player)
	menu:clear()

    menu:addSlice(getText("UI_optionscreen_binding_Shout"), getTexture("media/ui/emotes/wavehello.png"), ISDPadWheels.onRadialEmoteMenu, joypadData)
    menu:addSlice(getText("UI_optionscreen_binding_Toggle Health Panel"), getTexture("media/ui/Heart2_On.png"), ISDPadWheels.onRadialMedicineMenu, joypadData)

    menu:setX(getPlayerScreenLeft(joypadData.player) + getPlayerScreenWidth(joypadData.player) / 2 - menu:getWidth() / 2)
	menu:setY(getPlayerScreenTop(joypadData.player) + getPlayerScreenHeight(joypadData.player) / 2 - menu:getHeight() / 2)
	menu:addToUIManager()
	menu:setHideWhenButtonReleased(Joypad.DPadDown)
	setJoypadFocus(joypadData.player, menu)
	getSpecificPlayer(joypadData.player):setJoypadIgnoreAimUntilCentered(true)
end

--#endregion

local function OnGameStart()
	Events.OnKeyStartPressed.Add(ISRadialMedicineMenu.onKeyPressed)
	Events.OnKeyKeepPressed.Add(ISRadialMedicineMenu.onKeyRepeat)
	Events.OnKeyPressed.Add(ISRadialMedicineMenu.onKeyReleased)
end

Events.OnGameStart.Add(OnGameStart)
