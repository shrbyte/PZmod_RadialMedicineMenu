require "TimedActions/ISBaseTimedAction"
require "ISUI/ISRadialMenu"

ISRadialMedicineMenu = ISBaseObject:derive("ISRadialMedicineMenu");

local KEY_RMM = {
    name = "Radial Medicine Menu",
    key = Keyboard.KEY_Z,
}

if ModOptions and ModOptions.AddKeyBinding then
    ModOptions:AddKeyBinding("[UI]", KEY_RMM)
end

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
};

local function len(t)
    local n = 0

    for _ in pairs(t) do
        n = n + 1
    end
    return n
end

function ISRadialMedicineMenu:getBodyPartIcon(s_typeBodyPart)
    local icon = getTexture(bodyPartIcons[s_typeBodyPart]);
    icon:setWidth(64);
    icon:setHeight(64);
    return icon;
end

function ISRadialMedicineMenu:getContainers(character)
    if not character then return end
    local playerNum = character and character:getPlayerNum() or -1;
    -- get all the surrounding inventory of the player, gonna check for the item in them too
    local containerList = {};
    for i,v in ipairs(getPlayerInventory(playerNum).inventoryPane.inventoryPage.backpacks) do
        table.insert(containerList, v.inventory);
    end
    for i,v in ipairs(getPlayerLoot(playerNum).inventoryPane.inventoryPage.backpacks) do
        table.insert(containerList, v.inventory);
    end
    return containerList;
end

function ISRadialMedicineMenu:getCharacterWounds(character)
    if not character then
        character = self.character;
    end
    local t_wounds = {};
    local bodyDamage = character:getBodyDamage();

    for i = 0, bodyDamage:getBodyParts():size() - 1 do
        local bodyPart = bodyDamage:getBodyParts():get(i);
        if bodyPart:HasInjury() or bodyPart:stitched() or bodyPart:bandaged() then
            t_wounds[bodyPart] = {};
            t_wounds[bodyPart].health = bodyPart:getHealth();
            t_wounds[bodyPart].isBleeding = bodyPart:bleeding();
            t_wounds[bodyPart].isBandaged = bodyPart:bandaged();
            t_wounds[bodyPart].isBandageDirty = bodyPart:isBandageDirty();
            t_wounds[bodyPart].isDeepWounded = bodyPart:deepWounded();
            t_wounds[bodyPart].haveBullet = bodyPart:haveBullet();
            t_wounds[bodyPart].haveGlass = bodyPart:haveGlass();
            t_wounds[bodyPart].isBurnt = bodyPart:isBurnt();
            t_wounds[bodyPart].isNeedBurnWash = bodyPart:isNeedBurnWash();
            t_wounds[bodyPart].fractureTime = bodyPart:getFractureTime();
            t_wounds[bodyPart].isSplint = bodyPart:isSplint();
        end

    end

    return t_wounds;
end

function ISRadialMedicineMenu:getUnbandagedBodyParts(characterWounds)
    local bodyParts = {};

    for k, v in pairs(characterWounds) do
        if not v.isBandaged then
            table.insert(bodyParts, k)
        end
    end
    return bodyParts;
end

function ISRadialMedicineMenu:getBandagedBodyParts(characterWounds)
    local bodyParts = {};

    for k, v in pairs(characterWounds) do
        if v.isBandaged then
            table.insert(bodyParts, k)
        end
    end
    return bodyParts;
end

function ISRadialMedicineMenu:getDeepWoundedBodyParts(characterWounds)
    local bodyParts = {};

    for k, v in pairs(characterWounds) do
        if (not v.isBandaged and v.isDeepWounded and not v.haveGlass) then
            table.insert(bodyParts, k)
        end
    end
    return bodyParts;
end

function ISRadialMedicineMenu:getFragileWoundedBodyParts(characterWounds)
    local bodyParts = {};

    for k, v in pairs(characterWounds) do
        if not v.isBandaged and (v.haveGlass or v.haveBullet) then
            table.insert(bodyParts, k);
        end
    end
    return bodyParts;
end

function ISRadialMedicineMenu:getBurntBodyParts(characterWounds)
    local bodyParts = {};

    for k, v in pairs(characterWounds) do
        if not v.isBandaged and (v.isBurnt and v.isNeedBurnWash) then
            table.insert(bodyParts, k)
        end
    end
    return bodyParts;
end

function ISRadialMedicineMenu:getFracturedBodyParts(characterWounds)
    local bodyParts = {};

    for k, v in pairs(characterWounds) do
        -- can't splint chest/head
        if not (k:getType() == BodyPartType.Head or k:getType() == BodyPartType.Torso_Upper or k:getType() == BodyPartType.Torso_Lower) then
            if not v.isSplint and v.fractureTime > 0 then
                table.insert(bodyParts, k);
            end
        end
    end
    return bodyParts;
end

function ISRadialMedicineMenu:getBodyPartsWithoutCataplasm(characterWounds)
    local bodyParts = {};

    for k, v in pairs(characterWounds) do
        if not v.isBandaged and k:getGarlicFactor() == 0 and k:getPlantainFactor() == 0 and k:getComfreyFactor() == 0 then
            table.insert(bodyParts, k);
        end
    end
    return bodyParts;
end

function ISRadialMedicineMenu:isItemTypeInTable(table, item)
    if not table[item:getType()] then return false end;
    if table[item:getType()]:getType() == item:getType() then
        return true;
    end
    return false;
end

function ISRadialMedicineMenu:findAllBestMedicine(character)
    local inventory = character:getInventory();
    local all_containers = self:getContainers(character);

    -- TODO: turn dictionaries to simple arrays/tables
    --       to avoid storing itemType as keys. 

    self.t_itemBandages = {};           -- Table of bandages : [itemType] = Item
    self.t_itemCleanBandages = {};      -- Table of clean bandages : [itemType] = Item
    self.t_itemDirtyBandages = {};      -- Table of dirty bandages : [itemType] = Item
    self.t_itemDisinfectants = {};      -- Table of disinfectants : [itemType] = Item
    self.t_itemPills = {};              -- Table of pills : [itemType] = Item
    self.t_itemCataplasms = {}          -- Table of cataplasms : [itemType] = Item
    self.t_itemTweezers = {};           -- Table of tweezers/sutureNeedleHolder : [itemType] = Item
    self.t_itemPlanks = {};             -- Plank/stick/etc for splint.
    self.itemNeedle = nil;
    self.itemSutureNeedle = nil;
    self.itemTweezers = nil;
    self.itemSutureNeedleHolder = nil;
    self.itemThread = nil;
    self.itemSplint = nil;
    self.itemRag = nil;                 -- DirtyRag/RippedSheets for splint.

    if not all_containers then return end;
    -----------------------------------------------------------
    ---  We are looking for one copy of each medical supplies, 
    ---  giving preference to those that are directly in the inventory of the character. 
    ---  Equipped bags and surroundings have the same priority.
    -----------------------------------------------------------
    for i = 1, #all_containers do
        for j = 0, all_containers[i]:getItems():size() - 1 do
            local item = all_containers[i]:getItems():get(j);

            --- Looking for bandages
            if item:isCanBandage() then
                if self:isItemTypeInTable(self.t_itemBandages, item) then
                    if inventory:contains(item, false) then
                        self.t_itemBandages[item:getType()] = item;
                    end
                else
                    self.t_itemBandages[item:getType()] = item;
                end

                if not string.match(item:getType(), "Dirty") then
                    if self:isItemTypeInTable(self.t_itemCleanBandages, item) then
                        if inventory:contains(item, false) then
                            self.t_itemCleanBandages[item:getType()] = item;
                        end
                    else
                        self.t_itemCleanBandages[item:getType()] = item;
                    end
                else
                    if self:isItemTypeInTable(self.t_itemDirtyBandages, item) then
                        if inventory:contains(item, false) then
                            self.t_itemDirtyBandages[item:getType()] = item;
                        end
                    else
                        self.t_itemDirtyBandages[item:getType()] = item;
                    end
                end
                    
            end

            --- Looking for disinfectants
            if item:getAlcoholPower() > 0 and not item:isCanBandage() then
                if self:isItemTypeInTable(self.t_itemDisinfectants, item) then
                    if inventory:contains(item, false) then
                        self.t_itemDisinfectants[item:getType()] = item;
                    end
                else
                    self.t_itemDisinfectants[item:getType()] = item;
                end
            end
            
            if self:startWith(item:getType(), "Pills") then
                if self:isItemTypeInTable(self.t_itemPills, item) then
                    if inventory:contains(item, false) then
                        self.t_itemPills[item:getType()] = item;
                    end
                else
                    self.t_itemPills[item:getType()] = item;
                end
            end

            if item:getType() == "Tweezers" or item:getType() == "SutureNeedleHolder" then
                if self:isItemTypeInTable(self.t_itemTweezers, item) then
                    if inventory:contains(item, false) then
                        self.t_itemTweezers[item:getType()] = item;
                    end
                else
                    self.t_itemTweezers[item:getType()] = item;
                end

                if item:getType() == "Tweezers" then
                    if self.itemTweezers then
                        if inventory:contains(item, false) then
                            self.itemTweezers = item;
                        end
                    else
                        self.itemTweezers = item;
                    end
                end

                if item:getType() == "SutureNeedleHolder" then
                    if self.itemSutureNeedleHolder then
                        if inventory:contains(item, false) then
                            self.itemSutureNeedleHolder = item;
                        end
                    else
                        self.itemSutureNeedleHolder = item;
                    end
                end
            end

            if item:getType() == "SutureNeedle" then
                if self.itemSutureNeedle then
                    if inventory:contains(item, false) then
                        self.itemSutureNeedle = item;
                    end
                else
                    self.itemSutureNeedle = item;
                end
            end

            if item:getType() == "Needle" then
                if self.itemNeedle then
                    if inventory:contains(item, false) then
                        self.itemNeedle = item;
                    end
                else
                    self.itemNeedle = item;
                end
            end

            if item:getType() == "Thread" then
                if self.itemThread then
                    if inventory:contains(item, false) then
                        self.itemThread = item;
                    end
                else
                    self.itemThread = item;
                end
            end

            if item:getType() == "Splint" then
                if self.itemSplint then
                    if inventory:contains(item, false) then
                        self.itemSplint = item;
                    end
                else
                    self.itemSplint = item;
                end
            end

            if item:getType() == "Plank" or item:getType() == "TreeBranch" or item:getType() == "WoodenStick" then
                if self:isItemTypeInTable(self.t_itemPlanks, item) then
                    if inventory:contains(item, false) then
                        self.t_itemPlanks[item:getType()] = item;
                    end
                else
                    self.t_itemPlanks[item:getType()] = item;
                end
            end

            if item:getType() == "RippedSheets" or item:getType() == "RippedSheetsDirty" then
                if self.itemRag then
                    if inventory:contains(item, false) then
                        self.itemRag = item;
                    end
                else
                    self.itemRag = item;
                end
            end

            if string.match(item:getType(), "Cataplasm") then
                if self:isItemTypeInTable(self.t_itemCataplasms, item) then
                    if inventory:contains(item, false) then
                        self.t_itemCataplasms[item:getType()] = item;
                    end
                else
                    self.t_itemCataplasms[item:getType()] = item;
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
            ISTimedActionQueue.add(ISInventoryTransferAction:new(character, item, item:getContainer(), character:getInventory()));
        end
    elseif instanceof(item, "ArrayList") then
        local items = item;
        for i=1,items:size() do
            local item = items:get(i-1)
            if luautils.haveToBeTransfered(character, item) then
                if not luautils.walkToContainer(item:getContainer(), character:getPlayerNum()) then
                    return;
                end
                ISTimedActionQueue.add(ISInventoryTransferAction:new(character, item, item:getContainer(), character:getInventory()));
            end
        end
    end
end

function ISRadialMedicineMenu:startWith(String, Start)
	return string.sub(String, 1, string.len(Start)) == Start;
end

---------------------------------------------------
-- #TODO: split args -> action, bodypart, items; --
---------------------------------------------------

function ISRadialMedicineMenu:takePills(args)
    if args == nil then return end;
    local character = getSpecificPlayer(0);
    local srcContainer = args.item:getContainer();

    self:transferIfNeeded(character, args.item);
    local takePillsAction = ISTakePillAction:new(character, args.item, 165);
    ISTimedActionQueue.add(takePillsAction);
    if args.item:getDrainableUsesInt() > 1 and srcContainer:getType() ~= "floor" then
        ISTimedActionQueue.addAfter(takePillsAction, ISInventoryTransferAction:new(character, args.item, character:getInventory(), srcContainer));
    end
end

function ISRadialMedicineMenu:applyDisinfectant(args)
    if args == nil then return end;
    local character = getSpecificPlayer(0);
    self:transferIfNeeded(character, args.item);
    ISTimedActionQueue.add(ISDisinfect:new(character, character, args.item, args.bodyPart));
end

function ISRadialMedicineMenu:applyBandage(args)
    if args == nil then return end;
    local character = getSpecificPlayer(0);

    if args.action == "ContextMenu_Bandage" then
        self:transferIfNeeded(character, args.item);
        ISTimedActionQueue.add(ISApplyBandage:new(character, character, args.item, args.bodyPart, true));
        return;
    end
    
    if args.action == "ContextMenu_Remove_Bandage" then
        ISTimedActionQueue.add(ISApplyBandage:new(character, character, nil, args.bodyPart));
        return;
    end
end

function ISRadialMedicineMenu:surgeon(args)
    if args == nil then return end;
    local character = getSpecificPlayer(0);

    if args.action == "ContextMenu_Stitch" then
        self:transferIfNeeded(character, args.item)
        if instanceof(args.item, "InventoryItem") then
            ISTimedActionQueue.add(ISStitch:new(character, character, args.item, args.bodyPart, true));
        else
            ISTimedActionQueue.add(ISStitch:new(character, character, args.item:get(0), args.bodyPart, true));
        end;
        return;
    elseif args.action == "ContextMenu_Remove_Stitch"  then
        ISTimedActionQueue.add(ISStitch:new(character, character, args.item, args.bodyPart, false));
        return;
    elseif args.action == "ContextMenu_Remove_Glass" then
        if args.item == "Hands" then
            ISTimedActionQueue.add(ISRemoveGlass:new(character, character, args.bodyPart, true));
        else
            self:transferIfNeeded(character, args.item);
            ISTimedActionQueue.add(ISRemoveGlass:new(character, character, args.bodyPart));
        end
        return;
    elseif args.action == "ContextMenu_Remove_Bullet" then
        self:transferIfNeeded(character, args.item);
        ISTimedActionQueue.add(ISRemoveBullet:new(character, character, args.bodyPart));
        return;
    elseif args.action == "ContextMenu_Clean_Burn" then
        self:transferIfNeeded(character, args.item);
        ISTimedActionQueue.add(ISCleanBurn:new(character, character, args.item, args.bodyPart));
        return;
    end

end

-- Removing splint unavailable for now, idk, i think it's pointless.
function ISRadialMedicineMenu:splint(args)
    if args == nil then return end;
    local character = getSpecificPlayer(0);

    if args.action == "ContextMenu_Splint" then
        self:transferIfNeeded(character, args.item);
        if instanceof(args.item, "InventoryItem") then
            ISTimedActionQueue.add(ISSplint:new(character, character, nil, args.item, args.bodyPart, true));
        else
            ISTimedActionQueue.add(ISSplint:new(character, character, args.item:get(0), args.item:get(1), args.bodyPart, true));
            return;
        end
    elseif args.action == "ContextMenu_Splint_Remove" then
        ISTimedActionQueue.add(ISSplint:new(character, character, nil, nil, args.bodyPart));
        return;
    end
end

function ISRadialMedicineMenu:applyCataplasm(args)
    if args == nil then return end;
    local character = getSpecificPlayer(0);

    if args.item:getType() == "ComfreyCataplasm" then
        self:transferIfNeeded(character, args.item);
        ISTimedActionQueue.add(ISComfreyCataplasm:new(character, character, args.item, args.bodyPart));
        return;
    elseif args.item:getType() == "PlantainCataplasm" then
        self:transferIfNeeded(character, args.item);
        ISTimedActionQueue.add(ISPlantainCataplasm:new(character, character, args.item, args.bodyPart));
        return;
    elseif args.item:getType() == "WildGarlicCataplasm" then
        self:transferIfNeeded(character, args.item);
        ISTimedActionQueue.add(ISGarlicCataplasm:new(character, character, args.item, args.bodyPart));
        return;
    end
end

function ISRadialMedicineMenu:update()
    local t_wounds = self:getCharacterWounds(self.character);
    local t_unbandagedBodyParts = self:getUnbandagedBodyParts(t_wounds);
    local t_bandagedBodyParts = self:getBandagedBodyParts(t_wounds);
    local t_deepWoundedBodyParts = self:getDeepWoundedBodyParts(t_wounds);
    local t_fragileWoundedBodyParts = self:getFragileWoundedBodyParts(t_wounds);
    local t_burntBodyParts = self:getBurntBodyParts(t_wounds);
    local t_fracturedBodyParts = self:getFracturedBodyParts(t_wounds);
    local t_bodyPartsWithoutCataplasm = self:getBodyPartsWithoutCataplasm(t_wounds)

    self:findAllBestMedicine(self.character);

    ISRadialMedicineMenu.main = {}

    if ( #t_unbandagedBodyParts > 0 and len(self.t_itemBandages) > 0 )
        or #t_bandagedBodyParts > 0 then
        
        ISRadialMedicineMenu.main["Dressing"] = {};
        ISRadialMedicineMenu.main["Dressing"].name = getText("ContextMenu_Bandage") .. "\n" .. getText("ContextMenu_Remove_Bandage");
        ISRadialMedicineMenu.main["Dressing"].icon = getTexture("Item_Bandage");
        ISRadialMedicineMenu.main["Dressing"].subMenu = {};

        if #t_unbandagedBodyParts > 0 then
            
            if len(self.t_itemBandages) > 0 then
                for i = 1, #t_unbandagedBodyParts do
                    local bpUnbandaged = t_unbandagedBodyParts[i];
                    local s_bpUnbandaged = bpUnbandaged:getType():toString();

                    ISRadialMedicineMenu.main["Dressing"].subMenu[s_bpUnbandaged] = {}
                    ISRadialMedicineMenu.main["Dressing"].subMenu[s_bpUnbandaged].name = BodyPartType.getDisplayName(bpUnbandaged:getType());
                    ISRadialMedicineMenu.main["Dressing"].subMenu[s_bpUnbandaged].icon = self:getBodyPartIcon(s_bpUnbandaged);
                    ISRadialMedicineMenu.main["Dressing"].subMenu[s_bpUnbandaged].subMenu = {};
                    
                    for k, v in pairs(self.t_itemCleanBandages) do

                        ISRadialMedicineMenu.main["Dressing"].subMenu[s_bpUnbandaged].subMenu[k] = {};
                        ISRadialMedicineMenu.main["Dressing"].subMenu[s_bpUnbandaged].subMenu[k].name = v:getName();
                        ISRadialMedicineMenu.main["Dressing"].subMenu[s_bpUnbandaged].subMenu[k].icon = v:getTexture();
                        ISRadialMedicineMenu.main["Dressing"].subMenu[s_bpUnbandaged].subMenu[k].functions = self.applyBandage;
                        ISRadialMedicineMenu.main["Dressing"].subMenu[s_bpUnbandaged].subMenu[k].arguments = {};
                        ISRadialMedicineMenu.main["Dressing"].subMenu[s_bpUnbandaged].subMenu[k].arguments.item = v;
                        ISRadialMedicineMenu.main["Dressing"].subMenu[s_bpUnbandaged].subMenu[k].arguments.bodyPart = bpUnbandaged;
                        ISRadialMedicineMenu.main["Dressing"].subMenu[s_bpUnbandaged].subMenu[k].arguments.action = "ContextMenu_Bandage";

                    end

                    for k, v in pairs(self.t_itemDirtyBandages) do

                        ISRadialMedicineMenu.main["Dressing"].subMenu[s_bpUnbandaged].subMenu[k] = {};
                        ISRadialMedicineMenu.main["Dressing"].subMenu[s_bpUnbandaged].subMenu[k].name = v:getName();
                        ISRadialMedicineMenu.main["Dressing"].subMenu[s_bpUnbandaged].subMenu[k].icon = v:getTexture();
                        ISRadialMedicineMenu.main["Dressing"].subMenu[s_bpUnbandaged].subMenu[k].functions = self.applyBandage;
                        ISRadialMedicineMenu.main["Dressing"].subMenu[s_bpUnbandaged].subMenu[k].arguments = {};
                        ISRadialMedicineMenu.main["Dressing"].subMenu[s_bpUnbandaged].subMenu[k].arguments.item = v;
                        ISRadialMedicineMenu.main["Dressing"].subMenu[s_bpUnbandaged].subMenu[k].arguments.bodyPart = bpUnbandaged;
                        ISRadialMedicineMenu.main["Dressing"].subMenu[s_bpUnbandaged].subMenu[k].arguments.action = "ContextMenu_Bandage";

                    end
    
                    ISRadialMedicineMenu.main["Dressing"].subMenu[s_bpUnbandaged].subMenu["Back"] = {};
                    ISRadialMedicineMenu.main["Dressing"].subMenu[s_bpUnbandaged].subMenu["Back"].name = getText("IGUI_Emote_Back");
                    ISRadialMedicineMenu.main["Dressing"].subMenu[s_bpUnbandaged].subMenu["Back"].icon = getTexture("media/ui/emotes/back.png");
                    ISRadialMedicineMenu.main["Dressing"].subMenu[s_bpUnbandaged].subMenu["Back"].functions = self.fillMenu;
                    ISRadialMedicineMenu.main["Dressing"].subMenu[s_bpUnbandaged].subMenu["Back"].arguments = ISRadialMedicineMenu.main["Dressing"].subMenu;

                end
            end

        end

        if #t_bandagedBodyParts > 0 then
            ISRadialMedicineMenu.main["Dressing"].subMenu["Remove"] = {};
            ISRadialMedicineMenu.main["Dressing"].subMenu["Remove"].name = getText("ContextMenu_Remove_Bandage");
            ISRadialMedicineMenu.main["Dressing"].subMenu["Remove"].icon = getTexture("media/ui/emotes/no.png");
            ISRadialMedicineMenu.main["Dressing"].subMenu["Remove"].subMenu = {};
            for i = 1, #t_bandagedBodyParts do
                local bpBandaged = t_bandagedBodyParts[i];
                local s_bpBandaged = bpBandaged:getType():toString();

                ISRadialMedicineMenu.main["Dressing"].subMenu["Remove"].subMenu[s_bpBandaged] = {};
                ISRadialMedicineMenu.main["Dressing"].subMenu["Remove"].subMenu[s_bpBandaged].name = BodyPartType.getDisplayName(bpBandaged:getType());
                ISRadialMedicineMenu.main["Dressing"].subMenu["Remove"].subMenu[s_bpBandaged].icon = self:getBodyPartIcon(s_bpBandaged);
                ISRadialMedicineMenu.main["Dressing"].subMenu["Remove"].subMenu[s_bpBandaged].functions = self.applyBandage;
                ISRadialMedicineMenu.main["Dressing"].subMenu["Remove"].subMenu[s_bpBandaged].arguments = {};
                ISRadialMedicineMenu.main["Dressing"].subMenu["Remove"].subMenu[s_bpBandaged].arguments.item = bpBandaged:getBandageType();
                ISRadialMedicineMenu.main["Dressing"].subMenu["Remove"].subMenu[s_bpBandaged].arguments.bodyPart = bpBandaged;
                ISRadialMedicineMenu.main["Dressing"].subMenu["Remove"].subMenu[s_bpBandaged].arguments.action = "ContextMenu_Remove_Bandage";
            end

            ISRadialMedicineMenu.main["Dressing"].subMenu["Remove"].subMenu["Back"] = {};
            ISRadialMedicineMenu.main["Dressing"].subMenu["Remove"].subMenu["Back"].name = getText("IGUI_Emote_Back");
            ISRadialMedicineMenu.main["Dressing"].subMenu["Remove"].subMenu["Back"].icon = getTexture("media/ui/emotes/back.png");
            ISRadialMedicineMenu.main["Dressing"].subMenu["Remove"].subMenu["Back"].functions = self.fillMenu;
            ISRadialMedicineMenu.main["Dressing"].subMenu["Remove"].subMenu["Back"].arguments = ISRadialMedicineMenu.main["Dressing"].subMenu;
        end

        ISRadialMedicineMenu.main["Dressing"].subMenu["Back"] = {};
        ISRadialMedicineMenu.main["Dressing"].subMenu["Back"].name = getText("IGUI_Emote_Back");
        ISRadialMedicineMenu.main["Dressing"].subMenu["Back"].icon = getTexture("media/ui/emotes/back.png");
        ISRadialMedicineMenu.main["Dressing"].subMenu["Back"].functions = self.fillMenu;
        ISRadialMedicineMenu.main["Dressing"].subMenu["Back"].arguments = ISRadialMedicineMenu.main;

    end
 
    if len(self.t_itemDisinfectants) > 0 then
        if #t_unbandagedBodyParts > 0 then
            ISRadialMedicineMenu.main["Disinfect"] = {};
            ISRadialMedicineMenu.main["Disinfect"].name = getText("ContextMenu_Disinfect");
            ISRadialMedicineMenu.main["Disinfect"].icon = getTexture("Item_AlcoholWipes");
            ISRadialMedicineMenu.main["Disinfect"].subMenu = {};

            for i = 1, #t_unbandagedBodyParts do
                local bpUnbandaged = t_unbandagedBodyParts[i];
                local s_bpUnbandaged = bpUnbandaged:getType():toString();

                ISRadialMedicineMenu.main["Disinfect"].subMenu[s_bpUnbandaged] = {};
                ISRadialMedicineMenu.main["Disinfect"].subMenu[s_bpUnbandaged].name = BodyPartType.getDisplayName(bpUnbandaged:getType());
                ISRadialMedicineMenu.main["Disinfect"].subMenu[s_bpUnbandaged].icon = self:getBodyPartIcon(s_bpUnbandaged);
                ISRadialMedicineMenu.main["Disinfect"].subMenu[s_bpUnbandaged].subMenu = {}

                for k, v in pairs(self.t_itemDisinfectants) do
                    ISRadialMedicineMenu.main["Disinfect"].subMenu[s_bpUnbandaged].subMenu[k] = {}
                    ISRadialMedicineMenu.main["Disinfect"].subMenu[s_bpUnbandaged].subMenu[k].name = v:getName();
                    ISRadialMedicineMenu.main["Disinfect"].subMenu[s_bpUnbandaged].subMenu[k].icon = v:getTexture();
                    ISRadialMedicineMenu.main["Disinfect"].subMenu[s_bpUnbandaged].subMenu[k].functions = self.applyDisinfectant;
                    ISRadialMedicineMenu.main["Disinfect"].subMenu[s_bpUnbandaged].subMenu[k].arguments = {};
                    ISRadialMedicineMenu.main["Disinfect"].subMenu[s_bpUnbandaged].subMenu[k].arguments.item = v;
                    ISRadialMedicineMenu.main["Disinfect"].subMenu[s_bpUnbandaged].subMenu[k].arguments.bodyPart = bpUnbandaged;
                end

                ISRadialMedicineMenu.main["Disinfect"].subMenu[s_bpUnbandaged].subMenu["Back"] = {};
                ISRadialMedicineMenu.main["Disinfect"].subMenu[s_bpUnbandaged].subMenu["Back"].name = getText("IGUI_Emote_Back");
                ISRadialMedicineMenu.main["Disinfect"].subMenu[s_bpUnbandaged].subMenu["Back"].icon = getTexture("media/ui/emotes/back.png");
                ISRadialMedicineMenu.main["Disinfect"].subMenu[s_bpUnbandaged].subMenu["Back"].functions = self.fillMenu;
                ISRadialMedicineMenu.main["Disinfect"].subMenu[s_bpUnbandaged].subMenu["Back"].arguments = ISRadialMedicineMenu.main["Disinfect"].subMenu;
                
            end
            ISRadialMedicineMenu.main["Disinfect"].subMenu["Back"] = {};
            ISRadialMedicineMenu.main["Disinfect"].subMenu["Back"].name = getText("IGUI_Emote_Back");
            ISRadialMedicineMenu.main["Disinfect"].subMenu["Back"].icon = getTexture("media/ui/emotes/back.png");
            ISRadialMedicineMenu.main["Disinfect"].subMenu["Back"].functions = self.fillMenu;
            ISRadialMedicineMenu.main["Disinfect"].subMenu["Back"].arguments = ISRadialMedicineMenu.main;
        end
    end

    if len(self.t_itemCataplasms) > 0 then
        if #t_bodyPartsWithoutCataplasm > 0 then
            ISRadialMedicineMenu.main["Cataplasm"] = {};
            ISRadialMedicineMenu.main["Cataplasm"].name = getText("ContextMenu_Bandage");
            ISRadialMedicineMenu.main["Cataplasm"].icon = getTexture("Item_MashedHerbs");
            ISRadialMedicineMenu.main["Cataplasm"].subMenu = {};

            for i = 1, #t_bodyPartsWithoutCataplasm do
                local bpUnbandaged = t_bodyPartsWithoutCataplasm[i];
                local s_bpUnbandaged = bpUnbandaged:getType():toString();

                ISRadialMedicineMenu.main["Cataplasm"].subMenu[s_bpUnbandaged] = {};
                ISRadialMedicineMenu.main["Cataplasm"].subMenu[s_bpUnbandaged].name = BodyPartType.getDisplayName(bpUnbandaged:getType());
                ISRadialMedicineMenu.main["Cataplasm"].subMenu[s_bpUnbandaged].icon = self:getBodyPartIcon(s_bpUnbandaged);
                ISRadialMedicineMenu.main["Cataplasm"].subMenu[s_bpUnbandaged].subMenu = {}

                for k, v in pairs(self.t_itemCataplasms) do
                    local icon = v:getTexture();
                    if k == "PlantainCataplasm" then
                        icon = getTexture("Item_PlantainPlantago");
                    elseif k == "WildGarlicCataplasm" then
                        icon = getTexture("Item_WildGarlic");
                    elseif k == "ComfreyCataplasm" then
                        icon = getTexture("Item_Comfrey");
                    end
                    ISRadialMedicineMenu.main["Cataplasm"].subMenu[s_bpUnbandaged].subMenu[k] = {}
                    ISRadialMedicineMenu.main["Cataplasm"].subMenu[s_bpUnbandaged].subMenu[k].name = v:getName();
                    ISRadialMedicineMenu.main["Cataplasm"].subMenu[s_bpUnbandaged].subMenu[k].icon = icon;
                    ISRadialMedicineMenu.main["Cataplasm"].subMenu[s_bpUnbandaged].subMenu[k].functions = self.applyCataplasm;
                    ISRadialMedicineMenu.main["Cataplasm"].subMenu[s_bpUnbandaged].subMenu[k].arguments = {};
                    ISRadialMedicineMenu.main["Cataplasm"].subMenu[s_bpUnbandaged].subMenu[k].arguments.item = v;
                    ISRadialMedicineMenu.main["Cataplasm"].subMenu[s_bpUnbandaged].subMenu[k].arguments.bodyPart = bpUnbandaged;
                end
                ISRadialMedicineMenu.main["Cataplasm"].subMenu[s_bpUnbandaged].subMenu["Back"] = {};
                ISRadialMedicineMenu.main["Cataplasm"].subMenu[s_bpUnbandaged].subMenu["Back"].name = getText("IGUI_Emote_Back");
                ISRadialMedicineMenu.main["Cataplasm"].subMenu[s_bpUnbandaged].subMenu["Back"].icon = getTexture("media/ui/emotes/back.png");
                ISRadialMedicineMenu.main["Cataplasm"].subMenu[s_bpUnbandaged].subMenu["Back"].functions = self.fillMenu;
                ISRadialMedicineMenu.main["Cataplasm"].subMenu[s_bpUnbandaged].subMenu["Back"].arguments = ISRadialMedicineMenu.main["Cataplasm"].subMenu;
                
            end
            ISRadialMedicineMenu.main["Cataplasm"].subMenu["Back"] = {};
            ISRadialMedicineMenu.main["Cataplasm"].subMenu["Back"].name = getText("IGUI_Emote_Back");
            ISRadialMedicineMenu.main["Cataplasm"].subMenu["Back"].icon = getTexture("media/ui/emotes/back.png");
            ISRadialMedicineMenu.main["Cataplasm"].subMenu["Back"].functions = self.fillMenu;
            ISRadialMedicineMenu.main["Cataplasm"].subMenu["Back"].arguments = ISRadialMedicineMenu.main;
        end
    end

    if ( #t_deepWoundedBodyParts > 0 and ( self.itemSutureNeedle or 
            (self.itemNeedle and self.itemThread) ) ) then

        ISRadialMedicineMenu.main["Stitch"] = {};
        ISRadialMedicineMenu.main["Stitch"].name = getText("ContextMenu_Stitch");
        ISRadialMedicineMenu.main["Stitch"].icon = getTexture("Item_SutureNeedle");
        ISRadialMedicineMenu.main["Stitch"].subMenu = {};

        for i = 1, #t_deepWoundedBodyParts do
            local bpDeepWounded = t_deepWoundedBodyParts[i];
            local s_bpDeepWounded = bpDeepWounded:getType():toString();

            ISRadialMedicineMenu.main["Stitch"].subMenu[s_bpDeepWounded] = {};
            ISRadialMedicineMenu.main["Stitch"].subMenu[s_bpDeepWounded].name = BodyPartType.getDisplayName(bpDeepWounded:getType());
            ISRadialMedicineMenu.main["Stitch"].subMenu[s_bpDeepWounded].icon = self:getBodyPartIcon(s_bpDeepWounded);
            ISRadialMedicineMenu.main["Stitch"].subMenu[s_bpDeepWounded].subMenu = {}

            if self.itemSutureNeedle then
                ISRadialMedicineMenu.main["Stitch"].subMenu[s_bpDeepWounded].subMenu[self.itemSutureNeedle:getType()] = {}
                ISRadialMedicineMenu.main["Stitch"].subMenu[s_bpDeepWounded].subMenu[self.itemSutureNeedle:getType()].name = self.itemSutureNeedle:getName();
                ISRadialMedicineMenu.main["Stitch"].subMenu[s_bpDeepWounded].subMenu[self.itemSutureNeedle:getType()].icon = self.itemSutureNeedle:getTexture();
                ISRadialMedicineMenu.main["Stitch"].subMenu[s_bpDeepWounded].subMenu[self.itemSutureNeedle:getType()].functions = self.surgeon;
                ISRadialMedicineMenu.main["Stitch"].subMenu[s_bpDeepWounded].subMenu[self.itemSutureNeedle:getType()].arguments = {}
                ISRadialMedicineMenu.main["Stitch"].subMenu[s_bpDeepWounded].subMenu[self.itemSutureNeedle:getType()].arguments.item = self.itemSutureNeedle;
                ISRadialMedicineMenu.main["Stitch"].subMenu[s_bpDeepWounded].subMenu[self.itemSutureNeedle:getType()].arguments.bodyPart = bpDeepWounded;
                ISRadialMedicineMenu.main["Stitch"].subMenu[s_bpDeepWounded].subMenu[self.itemSutureNeedle:getType()].arguments.action = "ContextMenu_Stitch";
            end
            if (self.itemNeedle and self.itemThread) then
                local items = ArrayList.new();
                items:add(self.itemThread);    items:add(self.itemNeedle);
                if self.itemSutureNeedleHolder then
                    items:add(self.itemSutureNeedleHolder);
                end
                ISRadialMedicineMenu.main["Stitch"].subMenu[s_bpDeepWounded].subMenu[self.itemNeedle:getType()] = {}
                ISRadialMedicineMenu.main["Stitch"].subMenu[s_bpDeepWounded].subMenu[self.itemNeedle:getType()].name = self.itemNeedle:getName();
                ISRadialMedicineMenu.main["Stitch"].subMenu[s_bpDeepWounded].subMenu[self.itemNeedle:getType()].icon = self.itemNeedle:getTexture();
                ISRadialMedicineMenu.main["Stitch"].subMenu[s_bpDeepWounded].subMenu[self.itemNeedle:getType()].functions = self.surgeon;
                ISRadialMedicineMenu.main["Stitch"].subMenu[s_bpDeepWounded].subMenu[self.itemNeedle:getType()].arguments = {}
                ISRadialMedicineMenu.main["Stitch"].subMenu[s_bpDeepWounded].subMenu[self.itemNeedle:getType()].arguments.item = items;
                ISRadialMedicineMenu.main["Stitch"].subMenu[s_bpDeepWounded].subMenu[self.itemNeedle:getType()].arguments.bodyPart = bpDeepWounded;
                ISRadialMedicineMenu.main["Stitch"].subMenu[s_bpDeepWounded].subMenu[self.itemNeedle:getType()].arguments.action = "ContextMenu_Stitch";
            end

            ISRadialMedicineMenu.main["Stitch"].subMenu[s_bpDeepWounded].subMenu["Back"] = {};
            ISRadialMedicineMenu.main["Stitch"].subMenu[s_bpDeepWounded].subMenu["Back"].name = getText("IGUI_Emote_Back");
            ISRadialMedicineMenu.main["Stitch"].subMenu[s_bpDeepWounded].subMenu["Back"].icon = getTexture("media/ui/emotes/back.png");
            ISRadialMedicineMenu.main["Stitch"].subMenu[s_bpDeepWounded].subMenu["Back"].functions = self.fillMenu;
            ISRadialMedicineMenu.main["Stitch"].subMenu[s_bpDeepWounded].subMenu["Back"].arguments = ISRadialMedicineMenu.main["Stitch"].subMenu;

        end
        
        ISRadialMedicineMenu.main["Stitch"].subMenu["Back"] = {};
        ISRadialMedicineMenu.main["Stitch"].subMenu["Back"].name = getText("IGUI_Emote_Back");
        ISRadialMedicineMenu.main["Stitch"].subMenu["Back"].icon = getTexture("media/ui/emotes/back.png");
        ISRadialMedicineMenu.main["Stitch"].subMenu["Back"].functions = self.fillMenu;
        ISRadialMedicineMenu.main["Stitch"].subMenu["Back"].arguments = ISRadialMedicineMenu.main;
    end

    if ( #t_fragileWoundedBodyParts > 0 and len(self.t_itemTweezers) > 0 ) then
        ISRadialMedicineMenu.main["Fragiles"] = {};
        ISRadialMedicineMenu.main["Fragiles"].name = getText("ContextMenu_Remove_Glass") .. "/\n" .. getText("ContextMenu_Remove_Bullet");
        ISRadialMedicineMenu.main["Fragiles"].icon = getTexture("Item_Tweezers");
        ISRadialMedicineMenu.main["Fragiles"].subMenu = {};

        for i = 1, #t_fragileWoundedBodyParts do
            local bpFragileWoundedBodyPart = t_fragileWoundedBodyParts[i];
            local s_bpFragileWoundedBodyPart = bpFragileWoundedBodyPart:getType():toString();

            ISRadialMedicineMenu.main["Fragiles"].subMenu[s_bpFragileWoundedBodyPart] = {};
            ISRadialMedicineMenu.main["Fragiles"].subMenu[s_bpFragileWoundedBodyPart].name = BodyPartType.getDisplayName(bpFragileWoundedBodyPart:getType());
            ISRadialMedicineMenu.main["Fragiles"].subMenu[s_bpFragileWoundedBodyPart].icon = self:getBodyPartIcon(s_bpFragileWoundedBodyPart);
            ISRadialMedicineMenu.main["Fragiles"].subMenu[s_bpFragileWoundedBodyPart].subMenu = {}

            for k, v in pairs(self.t_itemTweezers) do
                ISRadialMedicineMenu.main["Fragiles"].subMenu[s_bpFragileWoundedBodyPart].subMenu[k] = {}
                ISRadialMedicineMenu.main["Fragiles"].subMenu[s_bpFragileWoundedBodyPart].subMenu[k].name = v:getName();
                ISRadialMedicineMenu.main["Fragiles"].subMenu[s_bpFragileWoundedBodyPart].subMenu[k].icon = v:getTexture();
                ISRadialMedicineMenu.main["Fragiles"].subMenu[s_bpFragileWoundedBodyPart].subMenu[k].functions = self.surgeon;
                ISRadialMedicineMenu.main["Fragiles"].subMenu[s_bpFragileWoundedBodyPart].subMenu[k].arguments = {}
                ISRadialMedicineMenu.main["Fragiles"].subMenu[s_bpFragileWoundedBodyPart].subMenu[k].arguments.item = v;
                ISRadialMedicineMenu.main["Fragiles"].subMenu[s_bpFragileWoundedBodyPart].subMenu[k].arguments.bodyPart = bpFragileWoundedBodyPart;
                if bpFragileWoundedBodyPart:haveGlass() then
                    ISRadialMedicineMenu.main["Fragiles"].subMenu[s_bpFragileWoundedBodyPart].subMenu[k].arguments.action = "ContextMenu_Remove_Glass";
                else
                    ISRadialMedicineMenu.main["Fragiles"].subMenu[s_bpFragileWoundedBodyPart].subMenu[k].arguments.action = "ContextMenu_Remove_Bullet";
                end
            end

            if bpFragileWoundedBodyPart:haveGlass() then
                ISRadialMedicineMenu.main["Fragiles"].subMenu[s_bpFragileWoundedBodyPart].subMenu["Hands"] = {}
                ISRadialMedicineMenu.main["Fragiles"].subMenu[s_bpFragileWoundedBodyPart].subMenu["Hands"].name = getText("ContextMenu_Hand");
                ISRadialMedicineMenu.main["Fragiles"].subMenu[s_bpFragileWoundedBodyPart].subMenu["Hands"].icon = getTexture("media/ui/emotes/clap.png");
                ISRadialMedicineMenu.main["Fragiles"].subMenu[s_bpFragileWoundedBodyPart].subMenu["Hands"].functions = self.surgeon;
                ISRadialMedicineMenu.main["Fragiles"].subMenu[s_bpFragileWoundedBodyPart].subMenu["Hands"].arguments = {}
                ISRadialMedicineMenu.main["Fragiles"].subMenu[s_bpFragileWoundedBodyPart].subMenu["Hands"].arguments.item = "Hands";
                ISRadialMedicineMenu.main["Fragiles"].subMenu[s_bpFragileWoundedBodyPart].subMenu["Hands"].arguments.bodyPart = bpFragileWoundedBodyPart;
                ISRadialMedicineMenu.main["Fragiles"].subMenu[s_bpFragileWoundedBodyPart].subMenu["Hands"].arguments.action = "ContextMenu_Remove_Glass";
            end

            ISRadialMedicineMenu.main["Fragiles"].subMenu[s_bpFragileWoundedBodyPart].subMenu["Back"] = {};
            ISRadialMedicineMenu.main["Fragiles"].subMenu[s_bpFragileWoundedBodyPart].subMenu["Back"].name = getText("IGUI_Emote_Back");
            ISRadialMedicineMenu.main["Fragiles"].subMenu[s_bpFragileWoundedBodyPart].subMenu["Back"].icon = getTexture("media/ui/emotes/back.png");
            ISRadialMedicineMenu.main["Fragiles"].subMenu[s_bpFragileWoundedBodyPart].subMenu["Back"].functions = self.fillMenu;
            ISRadialMedicineMenu.main["Fragiles"].subMenu[s_bpFragileWoundedBodyPart].subMenu["Back"].arguments = ISRadialMedicineMenu.main["Fragiles"].subMenu;
        end
        ISRadialMedicineMenu.main["Fragiles"].subMenu["Back"] = {};
        ISRadialMedicineMenu.main["Fragiles"].subMenu["Back"].name = getText("IGUI_Emote_Back");
        ISRadialMedicineMenu.main["Fragiles"].subMenu["Back"].icon = getTexture("media/ui/emotes/back.png");
        ISRadialMedicineMenu.main["Fragiles"].subMenu["Back"].functions = self.fillMenu;
        ISRadialMedicineMenu.main["Fragiles"].subMenu["Back"].arguments = ISRadialMedicineMenu.main;
    end

    if ( #t_burntBodyParts > 0 and len(self.t_itemCleanBandages) > 0 ) then
        ISRadialMedicineMenu.main["Burnts"] = {};
        ISRadialMedicineMenu.main["Burnts"].name = getText("ContextMenu_Clean_Burn");
        ISRadialMedicineMenu.main["Burnts"].icon = getTexture("Item_Lighter");
        ISRadialMedicineMenu.main["Burnts"].subMenu = {};

        for i = 1, #t_burntBodyParts do
            local bpBurnt = t_burntBodyParts[i];
            local s_bpBurnt = bpBurnt:getType():toString();
            
            ISRadialMedicineMenu.main["Burnts"].subMenu[s_bpBurnt] = {};
            ISRadialMedicineMenu.main["Burnts"].subMenu[s_bpBurnt].name = BodyPartType.getDisplayName(bpBurnt:getType());
            ISRadialMedicineMenu.main["Burnts"].subMenu[s_bpBurnt].icon = self:getBodyPartIcon(s_bpBurnt);
            ISRadialMedicineMenu.main["Burnts"].subMenu[s_bpBurnt].subMenu = {}

            for k, v in pairs(self.t_itemCleanBandages) do
                
                ISRadialMedicineMenu.main["Burnts"].subMenu[s_bpBurnt].subMenu[k] = {}
                ISRadialMedicineMenu.main["Burnts"].subMenu[s_bpBurnt].subMenu[k].name = v:getName();
                ISRadialMedicineMenu.main["Burnts"].subMenu[s_bpBurnt].subMenu[k].icon = v:getTexture();
                ISRadialMedicineMenu.main["Burnts"].subMenu[s_bpBurnt].subMenu[k].functions = self.surgeon;
                ISRadialMedicineMenu.main["Burnts"].subMenu[s_bpBurnt].subMenu[k].arguments = {}
                ISRadialMedicineMenu.main["Burnts"].subMenu[s_bpBurnt].subMenu[k].arguments.item = v;
                ISRadialMedicineMenu.main["Burnts"].subMenu[s_bpBurnt].subMenu[k].arguments.bodyPart = bpBurnt;
                ISRadialMedicineMenu.main["Burnts"].subMenu[s_bpBurnt].subMenu[k].arguments.action = "ContextMenu_Clean_Burn";

            end

            ISRadialMedicineMenu.main["Burnts"].subMenu[s_bpBurnt].subMenu["Back"] = {};
            ISRadialMedicineMenu.main["Burnts"].subMenu[s_bpBurnt].subMenu["Back"].name = getText("IGUI_Emote_Back");
            ISRadialMedicineMenu.main["Burnts"].subMenu[s_bpBurnt].subMenu["Back"].icon = getTexture("media/ui/emotes/back.png");
            ISRadialMedicineMenu.main["Burnts"].subMenu[s_bpBurnt].subMenu["Back"].functions = self.fillMenu;
            ISRadialMedicineMenu.main["Burnts"].subMenu[s_bpBurnt].subMenu["Back"].arguments = ISRadialMedicineMenu.main;

        end
        ISRadialMedicineMenu.main["Burnts"].subMenu["Back"] = {};
        ISRadialMedicineMenu.main["Burnts"].subMenu["Back"].name = getText("IGUI_Emote_Back");
        ISRadialMedicineMenu.main["Burnts"].subMenu["Back"].icon = getTexture("media/ui/emotes/back.png");
        ISRadialMedicineMenu.main["Burnts"].subMenu["Back"].functions = self.fillMenu;
        ISRadialMedicineMenu.main["Burnts"].subMenu["Back"].arguments = ISRadialMedicineMenu.main;
    end

    if (#t_fracturedBodyParts > 0 and (self.itemSplint or (len(self.t_itemPlanks) > 0 and self.itemRag)) ) then
        ISRadialMedicineMenu.main["Fractures"] = {};
        ISRadialMedicineMenu.main["Fractures"].name = getText("ContextMenu_Splint");
        ISRadialMedicineMenu.main["Fractures"].icon = getTexture("Item_Splint");
        ISRadialMedicineMenu.main["Fractures"].subMenu = {};

        for i = 1, #t_fracturedBodyParts do
            local bpFractured = t_fracturedBodyParts[i];
            local s_bpFractured = bpFractured:getType():toString();
            
            ISRadialMedicineMenu.main["Fractures"].subMenu[s_bpFractured] = {};
            ISRadialMedicineMenu.main["Fractures"].subMenu[s_bpFractured].name = BodyPartType.getDisplayName(bpFractured:getType());
            ISRadialMedicineMenu.main["Fractures"].subMenu[s_bpFractured].icon = self:getBodyPartIcon(s_bpFractured);
            ISRadialMedicineMenu.main["Fractures"].subMenu[s_bpFractured].subMenu = {};
            
            if self.t_itemPlanks and self.itemRag then
                for k, v in pairs(self.t_itemPlanks) do
                    local items = ArrayList.new();
                    items:add(self.itemRag);    items:add(v);
                    ISRadialMedicineMenu.main["Fractures"].subMenu[s_bpFractured].subMenu[k] = {};
                    ISRadialMedicineMenu.main["Fractures"].subMenu[s_bpFractured].subMenu[k].name = v:getName();
                    ISRadialMedicineMenu.main["Fractures"].subMenu[s_bpFractured].subMenu[k].icon = v:getTexture();
                    ISRadialMedicineMenu.main["Fractures"].subMenu[s_bpFractured].subMenu[k].functions = self.splint;
                    ISRadialMedicineMenu.main["Fractures"].subMenu[s_bpFractured].subMenu[k].arguments = {};
                    ISRadialMedicineMenu.main["Fractures"].subMenu[s_bpFractured].subMenu[k].arguments.item = items;
                    ISRadialMedicineMenu.main["Fractures"].subMenu[s_bpFractured].subMenu[k].arguments.bodyPart = bpFractured;
                    ISRadialMedicineMenu.main["Fractures"].subMenu[s_bpFractured].subMenu[k].arguments.action = "ContextMenu_Splint";
                end
            end
            
            if self.itemSplint then
                ISRadialMedicineMenu.main["Fractures"].subMenu[s_bpFractured].subMenu["itemSplint"] = {};
                ISRadialMedicineMenu.main["Fractures"].subMenu[s_bpFractured].subMenu["itemSplint"].name = self.itemSplint:getName();
                ISRadialMedicineMenu.main["Fractures"].subMenu[s_bpFractured].subMenu["itemSplint"].icon = self.itemSplint:getTexture();
                ISRadialMedicineMenu.main["Fractures"].subMenu[s_bpFractured].subMenu["itemSplint"].functions = self.splint;
                ISRadialMedicineMenu.main["Fractures"].subMenu[s_bpFractured].subMenu["itemSplint"].arguments = {};
                ISRadialMedicineMenu.main["Fractures"].subMenu[s_bpFractured].subMenu["itemSplint"].arguments.item = self.itemSplint;
                ISRadialMedicineMenu.main["Fractures"].subMenu[s_bpFractured].subMenu["itemSplint"].arguments.bodyPart = bpFractured;
                ISRadialMedicineMenu.main["Fractures"].subMenu[s_bpFractured].subMenu["itemSplint"].arguments.action = "ContextMenu_Splint";
            end
        end

        ISRadialMedicineMenu.main["Fractures"].subMenu["Back"] = {};
        ISRadialMedicineMenu.main["Fractures"].subMenu["Back"].name = getText("IGUI_Emote_Back");
        ISRadialMedicineMenu.main["Fractures"].subMenu["Back"].icon = getTexture("media/ui/emotes/back.png");
        ISRadialMedicineMenu.main["Fractures"].subMenu["Back"].functions = self.fillMenu;
        ISRadialMedicineMenu.main["Fractures"].subMenu["Back"].arguments = ISRadialMedicineMenu.main;

    end

    if len(self.t_itemPills) > 0 then
        ISRadialMedicineMenu.main["Pills"] = {};
        ISRadialMedicineMenu.main["Pills"].name = getText("ContextMenu_Take_pills");
        ISRadialMedicineMenu.main["Pills"].icon = getTexture("Item_PillsAntidepressant");
        ISRadialMedicineMenu.main["Pills"].subMenu = {};

        for k, v in pairs(self.t_itemPills) do
            ISRadialMedicineMenu.main["Pills"].subMenu[k] = {}
            ISRadialMedicineMenu.main["Pills"].subMenu[k].name = v:getName();
            ISRadialMedicineMenu.main["Pills"].subMenu[k].icon = v:getTexture();
            ISRadialMedicineMenu.main["Pills"].subMenu[k].functions = self.takePills;
            ISRadialMedicineMenu.main["Pills"].subMenu[k].arguments = {};
            ISRadialMedicineMenu.main["Pills"].subMenu[k].arguments.category = "Pills";
            ISRadialMedicineMenu.main["Pills"].subMenu[k].arguments.item = v;
        end

        ISRadialMedicineMenu.main["Pills"].subMenu["Back"] = {};
        ISRadialMedicineMenu.main["Pills"].subMenu["Back"].name = getText("IGUI_Emote_Back");
        ISRadialMedicineMenu.main["Pills"].subMenu["Back"].icon =  getTexture("media/ui/emotes/back.png");
        ISRadialMedicineMenu.main["Pills"].subMenu["Back"].functions = self.fillMenu;
        ISRadialMedicineMenu.main["Pills"].subMenu["Back"].arguments = ISRadialMedicineMenu.main;
    
    end

end

function ISRadialMedicineMenu:new(character)
	local o = ISBaseObject.new(self);
	o.character = character;
	o.playerNum = character:getPlayerNum();
	return o;
end

function ISRadialMedicineMenu:display()
	local menu = getPlayerRadialMenu(self.playerNum);
	self:center();
	menu:addToUIManager();
	if JoypadState.players[self.playerNum+1] then
		menu:setHideWhenButtonReleased(Joypad.DPadDown);
		setJoypadFocus(self.playerNum, menu);
		self.character:setJoypadIgnoreAimUntilCentered(true);
	end
end

function ISRadialMedicineMenu:center()
	local menu = getPlayerRadialMenu(self.playerNum);
	
	local x = getPlayerScreenLeft(self.playerNum);
	local y = getPlayerScreenTop(self.playerNum);
	local w = getPlayerScreenWidth(self.playerNum);
	local h = getPlayerScreenHeight(self.playerNum);
	
	x = x + w / 2;
	y = y + h / 2;
	
	menu:setX(x - menu:getWidth() / 2);
	menu:setY(y - menu:getHeight() / 2);
end

function ISRadialMedicineMenu:fillMenu(submenu)
    local menu = getPlayerRadialMenu(self.playerNum);
    menu:clear();

    local icon = nil;
    if not submenu then
        submenu = self.main;
    end;
    for _, v in pairs(submenu) do
        if v.icon then
            icon = v.icon;
        else
            icon = nil;
        end

        if v.subMenu then
            menu:addSlice(v.name, icon, self.fillMenu, self, v.subMenu);
        else
            menu:addSlice(v.name, icon, v.functions, self, v.arguments);
        end
        
    end
    self:display();
end

--#region Key events

local STATE = {}
STATE[1] = {}
STATE[2] = {}
STATE[3] = {}
STATE[4] = {}

function ISRadialMedicineMenu.checkKey(key)
    if key ~= KEY_RMM.key then
        return false;
    end
    --if isGamePaused() then
    --    return false;
    --end
    local character = getSpecificPlayer(0);
    if not character or character:isDead() then
        return false;
    end;
    local queue = ISTimedActionQueue.queues[character]
	if queue and #queue.queue > 0 then
		return false
	end
    return true;
end

function ISRadialMedicineMenu.onKeyPressed(key)
    if not ISRadialMedicineMenu.checkKey(key) then
        return;
    end

	local radialMenu = getPlayerRadialMenu(0);
    if getCore():getOptionRadialMenuKeyToggle() and radialMenu:isReallyVisible() then
        STATE[1].radialWasVisible = true;
        radialMenu:removeFromUIManager();
        return;
    end
    STATE[1].keyPressedMS = getTimestampMs();
    STATE[1].radialWasVisible = false;
end

function ISRadialMedicineMenu.onKeyRepeat(key)
    if not ISRadialMedicineMenu.checkKey(key) then
        return;
    end
    if STATE[1].radialWasVisible then
        return;
    end
    if not STATE[1].keyPressedMS then
        return;
    end

    local radialMenu = getPlayerRadialMenu(0);
    local delay = 500;
    if (getTimestampMs() - STATE[1].keyPressedMS >= delay) and not radialMenu:isReallyVisible() then
        local menu = ISRadialMedicineMenu:new(getSpecificPlayer(0));
        menu:update();
        menu:fillMenu();
    end
end

function ISRadialMedicineMenu.onKeyReleased(key)
    if not ISRadialMedicineMenu.checkKey(key) then
		return;
	end
	if not STATE[1].keyPressedMS then
		return;
	end
	local radialMenu = getPlayerRadialMenu(0)
	if radialMenu:isReallyVisible() or STATE[1].radialWasVisible then
		if not getCore():getOptionRadialMenuKeyToggle() then
			radialMenu:removeFromUIManager();
		end
		return;
	end
	STATE[1].keyPressedMS = nil
end

--#endregion

local function OnGameStart()
	Events.OnKeyStartPressed.Add(ISRadialMedicineMenu.onKeyPressed);
	Events.OnKeyKeepPressed.Add(ISRadialMedicineMenu.onKeyRepeat);
	Events.OnKeyPressed.Add(ISRadialMedicineMenu.onKeyReleased);
end

Events.OnGameStart.Add(OnGameStart)