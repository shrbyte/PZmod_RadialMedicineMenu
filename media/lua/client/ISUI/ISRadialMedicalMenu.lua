require "TimedActions/ISBaseTimedAction"
require "ISUI/ISRadialMenu"

ISMedicalRadialMenu = ISBaseObject:derive("ISMedicalRadialMenu");

local bodyPartIcons = {
    ["Back"] = "media/ui/emotes/gears.png",
    ["Foot_L"] = "media/ui/emotes/gears.png",
    ["Foot_R"] = "media/ui/emotes/gears.png",
    ["ForeArm_L"] = "media/ui/emotes/wavebye.png",
    ["ForeArm_R"] = "media/ui/emotes/wavehello.png",
    ["Groin"] = "media/ui/emotes/gears.png", 
    ["Hand_L"] = "media/ui/emotes/wavebye.png",
    ["Hand_R"] = "media/ui/emotes/wavehello.png", 
    ["Head"] = "media/ui/emotes/gears.png", 
    ["LowerLeg_L"] = "media/ui/emotes/gears.png", 
    ["LowerLeg_R"] = "media/ui/emotes/gears.png", 
    ["Neck"] = "media/ui/emotes/gears.png", 
    ["Torso_Lower"] = "media/ui/emotes/gears.png", 
    ["Torso_Upper"] = "media/ui/emotes/gears.png", 
    ["UpperArm_L"] = "media/ui/emotes/gears.png", 
    ["UpperArm_R"] = "media/ui/emotes/gears.png", 
    ["UpperLeg_L"] = "media/ui/emotes/gears.png", 
    ["UpperLeg_R"] = "media/ui/emotes/gears.png"
};

--#region Utilities

local function len(t)
    local n = 0

    for _ in pairs(t) do
        n = n + 1
    end
    return n
end

local function getContainers(character)
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

local function getCharacterWounds()
    local character = getSpecificPlayer(0);
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

local function getUnbandagedBodyParts(characterWounds)
    local bodyParts = {};

    for k, v in pairs(characterWounds) do
        if not v.isBandaged then
            table.insert(bodyParts, k)
        end
    end
    return bodyParts;
end

local function getDirtyBandagedBodyParts(characterWounds)
    local bodyParts = {};

    for k, v in pairs(characterWounds) do
        if v.isBandaged and v.isBandageDirty then
            table.insert(bodyParts, k)
        end
    end
    return bodyParts;
end

local function getDeepWoundedBodyParts(characterWounds)
    local bodyParts = {};

    for k, v in pairs(characterWounds) do
        if (not v.isBandaged and v.isDeepWounded and not v.haveGlass) then
            table.insert(bodyParts, k)
        end
    end
    return bodyParts;
end

local function getSpecificWoundedBodyParts(characterWounds)
    local bodyParts = {};

    for k, v in pairs(characterWounds) do
        if not v.isBandaged and (v.haveGlass or v.haveBullet) then
            bodyParts[k] = v;
        end
    end
    return bodyParts;
end

local function getBurntBodyParts(characterWounds)
    local bodyParts = {};

    for k, v in pairs(characterWounds) do
        if not v.isBandaged and (v.isBurnt and v.isNeedBurnWash) then
            table.insert(bodyParts, k)
        end
    end
    return bodyParts;
end

local function getFracturedBodyParts(characterWounds)
    local bodyParts = {};

    for k, v in pairs(characterWounds) do
        if not v.isSplint and v.fractureTime > 0 then
            table.insert(bodyParts, k);
        end
    end
    return bodyParts;
end

local function getBodyPartsWithoutCataplasm(characterWounds)
    local bodyParts = {};

    for k, v in pairs(characterWounds) do
        if not v.isBandaged and k:getGarlicFactor() == 0 and k:getPlantainFactor() == 0 and k:getComfreyFactor() == 0 then
            table.insert(bodyParts, k);
        end
    end
    return bodyParts;
end

local function isItemTypeInTable(table, item)
    if not table[item:getType()] then return false end;
    if table[item:getType()]:getType() == item:getType() then
        return true;
    end
    return false;
end

function ISMedicalRadialMenu:startWith(String, Start)
	return string.sub(String, 1, string.len(Start)) == Start;
end

function ISMedicalRadialMenu:findAllBestMedicine(character)
    local inventory = character:getInventory();
    local all_containers = getContainers(character);

    self.t_bandages = {};
    self.t_cleanBandages = {}; -- for burnts
    self.t_disinfectants = {};
    self.t_pills = {};
    self.t_tweezers = {};
    self.t_needles = {};
    self.t_cataplasms = {}
    self.thread = nil;
    self.splint = nil;

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
                if isItemTypeInTable(self.t_bandages, item) then
                    if inventory:contains(item, false) then
                        self.t_bandages[item:getType()] = item;
                    end
                else
                    self.t_bandages[item:getType()] = item;
                end

                --- for burnts
                if not string.match(item:getType(), "Dirty") then
                    if isItemTypeInTable(self.t_cleanBandages, item) then
                        if inventory:contains(item, false) then
                            self.t_cleanBandages[item:getType()] = item;
                        end
                    else
                        self.t_cleanBandages[item:getType()] = item;
                    end
                end
            end

            --- Looking for disinfectants
            if item:getAlcoholPower() > 0 and not item:isCanBandage() then
                if isItemTypeInTable(self.t_disinfectants, item) then
                    if inventory:contains(item, false) then
                        self.t_disinfectants[item:getType()] = item;
                    end
                else
                    self.t_disinfectants[item:getType()] = item;
                end
            end
            
            --- Looking for pills
            if self:startWith(item:getType(), "Pills") then
                if isItemTypeInTable(self.t_pills, item) then
                    if inventory:contains(item, false) then
                        self.t_pills[item:getType()] = item;
                    end
                else
                    self.t_pills[item:getType()] = item;
                end
            end

            --- Looking for tweezers or SutureNeedleHolder
            if item:getType() == "Tweezers" or item:getType() == "SutureNeedleHolder" then
                if isItemTypeInTable(self.t_tweezers, item) then
                    if inventory:contains(item, false) then
                        self.t_tweezers[item:getType()] = item;
                    end
                else
                    self.t_tweezers[item:getType()] = item;
                end
            end
            
            --- Looking for needles
            if item:getType() == "SutureNeedle" or item:getType() == "Needle" then
                if isItemTypeInTable(self.t_needles, item) then
                    if inventory:contains(item, false) then
                        self.t_needles[item:getType()] = item;
                    end
                else
                    self.t_needles[item:getType()] = item;
                end
            end

            --- Looking for threads
            if item:getType() == "Thread" then
                if self.thread then
                    if inventory:contains(item, false) then
                        self.thread = item;
                    end
                else
                    self.thread = item;
                end
            end

            --- Looking for splint
            if item:getType() == "Splint" then
                if self.splint then
                    if inventory:contains(item, false) then
                        self.splint = item;
                    end
                else
                    self.splint = item;
                end
            end

            --- Looking for cataplasm
            if string.match(item:getType(), "Cataplasm") then
                if isItemTypeInTable(self.t_cataplasms, item) then
                    if inventory:contains(item, false) then
                        self.t_cataplasms[item:getType()] = item;
                    end
                else
                    self.t_cataplasms[item:getType()] = item;
                end
            end   
        end
    end
end

function ISMedicalRadialMenu:transferIfNeeded(character, item)
    if instanceof(item, "InventoryItem") then
        if luautils.haveToBeTransfered(character, item) then
            ISTimedActionQueue.add(ISInventoryTransferAction:new(character, item, item:getContainer(), character:getInventory()));
        end
    elseif instanceof(item, "ArrayList") then
        local items = item
        for i=1,items:size() do
            local item = items:get(i-1)
            if luautils.haveToBeTransfered(character, item) then
                ISTimedActionQueue.add(ISInventoryTransferAction:new(character, item, item:getContainer(), character:getInventory()));
            end
        end
    end
end

function ISMedicalRadialMenu:takePills(args)
    if args == nil then return end;
    local character = getSpecificPlayer(0);
    self:transferIfNeeded(character, args.item);
    ISTimedActionQueue.add(ISTakePillAction:new(character, args.item, 165));
end

function ISMedicalRadialMenu:useDisinfectant(args)
    if args == nil then return end;
    local character = getSpecificPlayer(0);
    self:transferIfNeeded(character, args.item);
    ISTimedActionQueue.add(ISDisinfect:new(character, character, args.item, args.bodyPart));
end

function ISMedicalRadialMenu:useBandages(args)
    if args == nil then return end;
    local character = getSpecificPlayer(0);

    if args.action == "apply" then
        self:transferIfNeeded(character, args.item);
        ISTimedActionQueue.add(ISApplyBandage:new(character, character, args.item, args.bodyPart, true));
        return;
    end
    
    if args.action == "remove" then
        ISTimedActionQueue.add(ISApplyBandage:new(character, character, nil, args.bodyPart));
        return;
    end
end

function ISMedicalRadialMenu:surgeon(args)
    if args == nil then return end;
    local character = getSpecificPlayer(0);
    --local BP = character:getBodyDamage():getBodyPart(args.bodyPart);

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
    elseif args.action == "ContextMenu_Splint" then
        self:transferIfNeeded(character, args.item);
        ISTimedActionQueue.add(ISSplint:new(character, character, nil, args.item, args.bodyPart, true));
        return;
    elseif args.action == "ContextMenu_Splint_Remove" then
        ISTimedActionQueue.add(ISSplint:new(character, character, nil, nil, args.bodyPart));
    end

end

function ISMedicalRadialMenu:applyCataplasm(args)
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

function ISMedicalRadialMenu:update()
end
function ISMedicalRadialMenu:collectUnbandaged()
end
function ISMedicalRadialMenu:collectDirtyBandaged()
end
function ISMedicalRadialMenu:collectToDisinfect()
end

--#endregion

--#region Radial Menu logic

function ISMedicalRadialMenu:init()
    ISMedicalRadialMenu.defaultMenu = {};

    ISMedicalRadialMenu.main = ISMedicalRadialMenu.defaultMenu;
end

function ISMedicalRadialMenu:new(character)
	local o = ISBaseObject.new(self);
	o.character = character;
	o.playerNum = character:getPlayerNum();
	return o;
end

function ISMedicalRadialMenu:display()
	local menu = getPlayerRadialMenu(self.playerNum);
	self:center();
	menu:addToUIManager();
	if JoypadState.players[self.playerNum+1] then
		menu:setHideWhenButtonReleased(Joypad.DPadDown);
		setJoypadFocus(self.playerNum, menu);
		self.character:setJoypadIgnoreAimUntilCentered(true);
	end
end

function ISMedicalRadialMenu:center()
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

function ISMedicalRadialMenu:fillMenu(submenu)
    local menu = getPlayerRadialMenu(self.playerNum);
    menu:clear();

    local t_wounds = getCharacterWounds();
    local t_unbandagedBodyParts = getUnbandagedBodyParts(t_wounds);
    local t_dirtyBandagedBodyParts = getDirtyBandagedBodyParts(t_wounds);
    local t_deepWoundedBodyParts = getDeepWoundedBodyParts(t_wounds);
    local t_specificWoundedBodyParts = getSpecificWoundedBodyParts(t_wounds);
    local t_burntBodyParts = getBurntBodyParts(t_wounds);
    local t_fracturedBodyParts = getFracturedBodyParts(t_wounds);
    local t_bodyPartsWithoutCataplasm = getBodyPartsWithoutCataplasm(t_wounds)

    self:findAllBestMedicine(getSpecificPlayer(0));

    ISMedicalRadialMenu.main = {}

    if ( #t_unbandagedBodyParts > 0 and len(self.t_bandages) > 0 )
        or #t_dirtyBandagedBodyParts > 0 then
        
        ISMedicalRadialMenu.main["Dressing"] = {};
        ISMedicalRadialMenu.main["Dressing"].name = getText("ContextMenu_Bandage");
        ISMedicalRadialMenu.main["Dressing"].icon = getTexture("Item_Bandage");
        ISMedicalRadialMenu.main["Dressing"].subMenu = {};

        if #t_unbandagedBodyParts > 0 then
            
            if len(self.t_bandages) > 0 then
                for i = 1, #t_unbandagedBodyParts do
                    local bpUnbandaged = t_unbandagedBodyParts[i];
                    local s_bpUnbandaged = bpUnbandaged:getType():toString();

                    ISMedicalRadialMenu.main["Dressing"].subMenu[s_bpUnbandaged] = {}
                    ISMedicalRadialMenu.main["Dressing"].subMenu[s_bpUnbandaged].name = BodyPartType.getDisplayName(bpUnbandaged:getType());
                    ISMedicalRadialMenu.main["Dressing"].subMenu[s_bpUnbandaged].icon = getTexture(bodyPartIcons[s_bpUnbandaged]);
                    ISMedicalRadialMenu.main["Dressing"].subMenu[s_bpUnbandaged].subMenu = {};                
                    
                    for _, v in pairs(self.t_bandages) do

                        ISMedicalRadialMenu.main["Dressing"].subMenu[s_bpUnbandaged].subMenu[v:getType()] = {};
                        ISMedicalRadialMenu.main["Dressing"].subMenu[s_bpUnbandaged].subMenu[v:getType()].name = v:getName();
                        ISMedicalRadialMenu.main["Dressing"].subMenu[s_bpUnbandaged].subMenu[v:getType()].icon = v:getTexture();
                        ISMedicalRadialMenu.main["Dressing"].subMenu[s_bpUnbandaged].subMenu[v:getType()].functions = self.useBandages;
                        ISMedicalRadialMenu.main["Dressing"].subMenu[s_bpUnbandaged].subMenu[v:getType()].arguments = {};
                        ISMedicalRadialMenu.main["Dressing"].subMenu[s_bpUnbandaged].subMenu[v:getType()].arguments.category = "Dressing";
                        ISMedicalRadialMenu.main["Dressing"].subMenu[s_bpUnbandaged].subMenu[v:getType()].arguments.item = v;
                        ISMedicalRadialMenu.main["Dressing"].subMenu[s_bpUnbandaged].subMenu[v:getType()].arguments.bodyPart = bpUnbandaged;
                        ISMedicalRadialMenu.main["Dressing"].subMenu[s_bpUnbandaged].subMenu[v:getType()].arguments.action = "apply";

                    end
    
                    ISMedicalRadialMenu.main["Dressing"].subMenu[s_bpUnbandaged].subMenu["Back"] = {};
                    ISMedicalRadialMenu.main["Dressing"].subMenu[s_bpUnbandaged].subMenu["Back"].name = getText("IGUI_Emote_Back");
                    ISMedicalRadialMenu.main["Dressing"].subMenu[s_bpUnbandaged].subMenu["Back"].icon = getTexture("media/ui/emotes/back.png");
                    ISMedicalRadialMenu.main["Dressing"].subMenu[s_bpUnbandaged].subMenu["Back"].functions = self.fillMenu;
                    ISMedicalRadialMenu.main["Dressing"].subMenu[s_bpUnbandaged].subMenu["Back"].arguments = ISMedicalRadialMenu.main["Dressing"].subMenu;

                end
            end

        end

        if #t_dirtyBandagedBodyParts > 0 then
            ISMedicalRadialMenu.main["Dressing"].subMenu["Remove"] = {};
            ISMedicalRadialMenu.main["Dressing"].subMenu["Remove"].name = getText("ContextMenu_Remove_Bandage");
            ISMedicalRadialMenu.main["Dressing"].subMenu["Remove"].icon = getTexture("media/ui/emotes/no.png");
            ISMedicalRadialMenu.main["Dressing"].subMenu["Remove"].subMenu = {};
            for i = 1, #t_dirtyBandagedBodyParts do
                local bpdirtyBandaged = t_dirtyBandagedBodyParts[i];
                local s_bpdirtyBandaged = bpdirtyBandaged:getType():toString();

                ISMedicalRadialMenu.main["Dressing"].subMenu["Remove"].subMenu[s_bpdirtyBandaged] = {};
                ISMedicalRadialMenu.main["Dressing"].subMenu["Remove"].subMenu[s_bpdirtyBandaged].name = BodyPartType.getDisplayName(bpdirtyBandaged:getType());
                ISMedicalRadialMenu.main["Dressing"].subMenu["Remove"].subMenu[s_bpdirtyBandaged].icon = getTexture(bodyPartIcons[s_bpdirtyBandaged]);
                ISMedicalRadialMenu.main["Dressing"].subMenu["Remove"].subMenu[s_bpdirtyBandaged].functions = self.useBandages;
                ISMedicalRadialMenu.main["Dressing"].subMenu["Remove"].subMenu[s_bpdirtyBandaged].arguments = {};
                ISMedicalRadialMenu.main["Dressing"].subMenu["Remove"].subMenu[s_bpdirtyBandaged].arguments.category = "Dressing";
                ISMedicalRadialMenu.main["Dressing"].subMenu["Remove"].subMenu[s_bpdirtyBandaged].arguments.item = bpdirtyBandaged:getBandageType();
                ISMedicalRadialMenu.main["Dressing"].subMenu["Remove"].subMenu[s_bpdirtyBandaged].arguments.bodyPart = bpdirtyBandaged;
                ISMedicalRadialMenu.main["Dressing"].subMenu["Remove"].subMenu[s_bpdirtyBandaged].arguments.action = "remove";
            end

            ISMedicalRadialMenu.main["Dressing"].subMenu["Remove"].subMenu["Back"] = {};
            ISMedicalRadialMenu.main["Dressing"].subMenu["Remove"].subMenu["Back"].name = getText("IGUI_Emote_Back");
            ISMedicalRadialMenu.main["Dressing"].subMenu["Remove"].subMenu["Back"].icon = getTexture("media/ui/emotes/back.png");
            ISMedicalRadialMenu.main["Dressing"].subMenu["Remove"].subMenu["Back"].functions = self.fillMenu;
            ISMedicalRadialMenu.main["Dressing"].subMenu["Remove"].subMenu["Back"].arguments = ISMedicalRadialMenu.main["Dressing"].subMenu;
        end

        ISMedicalRadialMenu.main["Dressing"].subMenu["Back"] = {};
        ISMedicalRadialMenu.main["Dressing"].subMenu["Back"].name = getText("IGUI_Emote_Back");
        ISMedicalRadialMenu.main["Dressing"].subMenu["Back"].icon = getTexture("media/ui/emotes/back.png");
        ISMedicalRadialMenu.main["Dressing"].subMenu["Back"].functions = self.fillMenu;
        ISMedicalRadialMenu.main["Dressing"].subMenu["Back"].arguments = ISMedicalRadialMenu.main;

    end
 
    if len(self.t_disinfectants) > 0 then
        if #t_unbandagedBodyParts > 0 then
            ISMedicalRadialMenu.main["Disinfect"] = {};
            ISMedicalRadialMenu.main["Disinfect"].name = getText("ContextMenu_Disinfect");
            ISMedicalRadialMenu.main["Disinfect"].icon = getTexture("Item_AlcoholWipes");
            ISMedicalRadialMenu.main["Disinfect"].subMenu = {};

            for i = 1, #t_unbandagedBodyParts do
                local bpUnbandaged = t_unbandagedBodyParts[i];
                local s_bpUnbandaged = bpUnbandaged:getType():toString();

                ISMedicalRadialMenu.main["Disinfect"].subMenu[s_bpUnbandaged] = {};
                ISMedicalRadialMenu.main["Disinfect"].subMenu[s_bpUnbandaged].name = BodyPartType.getDisplayName(bpUnbandaged:getType());
                ISMedicalRadialMenu.main["Disinfect"].subMenu[s_bpUnbandaged].icon = getTexture(bodyPartIcons[s_bpUnbandaged]);
                ISMedicalRadialMenu.main["Disinfect"].subMenu[s_bpUnbandaged].subMenu = {}

                for _, v in pairs(self.t_disinfectants) do
                    ISMedicalRadialMenu.main["Disinfect"].subMenu[s_bpUnbandaged].subMenu[v:getType()] = {}
                    ISMedicalRadialMenu.main["Disinfect"].subMenu[s_bpUnbandaged].subMenu[v:getType()].name = v:getName();
                    ISMedicalRadialMenu.main["Disinfect"].subMenu[s_bpUnbandaged].subMenu[v:getType()].icon = v:getTexture();
                    ISMedicalRadialMenu.main["Disinfect"].subMenu[s_bpUnbandaged].subMenu[v:getType()].functions = self.useDisinfectant;
                    ISMedicalRadialMenu.main["Disinfect"].subMenu[s_bpUnbandaged].subMenu[v:getType()].arguments = {};
                    ISMedicalRadialMenu.main["Disinfect"].subMenu[s_bpUnbandaged].subMenu[v:getType()].arguments.item = v;
                    ISMedicalRadialMenu.main["Disinfect"].subMenu[s_bpUnbandaged].subMenu[v:getType()].arguments.bodyPart = bpUnbandaged;
                end

                ISMedicalRadialMenu.main["Disinfect"].subMenu[s_bpUnbandaged].subMenu["Back"] = {};
                ISMedicalRadialMenu.main["Disinfect"].subMenu[s_bpUnbandaged].subMenu["Back"].name = getText("IGUI_Emote_Back");
                ISMedicalRadialMenu.main["Disinfect"].subMenu[s_bpUnbandaged].subMenu["Back"].icon = getTexture("media/ui/emotes/back.png");
                ISMedicalRadialMenu.main["Disinfect"].subMenu[s_bpUnbandaged].subMenu["Back"].functions = self.fillMenu;
                ISMedicalRadialMenu.main["Disinfect"].subMenu[s_bpUnbandaged].subMenu["Back"].arguments = ISMedicalRadialMenu.main["Disinfect"].subMenu;
                
            end
            ISMedicalRadialMenu.main["Disinfect"].subMenu["Back"] = {};
            ISMedicalRadialMenu.main["Disinfect"].subMenu["Back"].name = getText("IGUI_Emote_Back");
            ISMedicalRadialMenu.main["Disinfect"].subMenu["Back"].icon = getTexture("media/ui/emotes/back.png");
            ISMedicalRadialMenu.main["Disinfect"].subMenu["Back"].functions = self.fillMenu;
            ISMedicalRadialMenu.main["Disinfect"].subMenu["Back"].arguments = ISMedicalRadialMenu.main;
        end
    end

    if len(self.t_cataplasms) > 0 then
        if #t_bodyPartsWithoutCataplasm > 0 then
            ISMedicalRadialMenu.main["Cataplasm"] = {};
            ISMedicalRadialMenu.main["Cataplasm"].name = getText("ContextMenu_Bandage");
            ISMedicalRadialMenu.main["Cataplasm"].icon = getTexture("Item_MashedHerbs");
            ISMedicalRadialMenu.main["Cataplasm"].subMenu = {};

            for i = 1, #t_bodyPartsWithoutCataplasm do
                local bpUnbandaged = t_bodyPartsWithoutCataplasm[i];
                local s_bpUnbandaged = bpUnbandaged:getType():toString();

                ISMedicalRadialMenu.main["Cataplasm"].subMenu[s_bpUnbandaged] = {};
                ISMedicalRadialMenu.main["Cataplasm"].subMenu[s_bpUnbandaged].name = BodyPartType.getDisplayName(bpUnbandaged:getType());
                ISMedicalRadialMenu.main["Cataplasm"].subMenu[s_bpUnbandaged].icon = getTexture(bodyPartIcons[s_bpUnbandaged]);
                ISMedicalRadialMenu.main["Cataplasm"].subMenu[s_bpUnbandaged].subMenu = {}

                for _, v in pairs(self.t_cataplasms) do
                    local icon = v:getTexture();
                    if v:getType() == "PlantainCataplasm" then
                        icon = getTexture("Item_PlantainPlantago");
                    elseif v:getType() == "WildGarlicCataplasm" then
                        icon = getTexture("Item_WildGarlic");
                    elseif v:getType() == "ComfreyCataplasm" then
                        icon = getTexture("Item_Comfrey");
                    end
                    ISMedicalRadialMenu.main["Cataplasm"].subMenu[s_bpUnbandaged].subMenu[v:getType()] = {}
                    ISMedicalRadialMenu.main["Cataplasm"].subMenu[s_bpUnbandaged].subMenu[v:getType()].name = v:getName();
                    ISMedicalRadialMenu.main["Cataplasm"].subMenu[s_bpUnbandaged].subMenu[v:getType()].icon = icon;
                    ISMedicalRadialMenu.main["Cataplasm"].subMenu[s_bpUnbandaged].subMenu[v:getType()].functions = self.applyCataplasm;
                    ISMedicalRadialMenu.main["Cataplasm"].subMenu[s_bpUnbandaged].subMenu[v:getType()].arguments = {};
                    ISMedicalRadialMenu.main["Cataplasm"].subMenu[s_bpUnbandaged].subMenu[v:getType()].arguments.item = v;
                    ISMedicalRadialMenu.main["Cataplasm"].subMenu[s_bpUnbandaged].subMenu[v:getType()].arguments.bodyPart = bpUnbandaged;
                end
                ISMedicalRadialMenu.main["Cataplasm"].subMenu[s_bpUnbandaged].subMenu["Back"] = {};
                ISMedicalRadialMenu.main["Cataplasm"].subMenu[s_bpUnbandaged].subMenu["Back"].name = getText("IGUI_Emote_Back");
                ISMedicalRadialMenu.main["Cataplasm"].subMenu[s_bpUnbandaged].subMenu["Back"].icon = getTexture("media/ui/emotes/back.png");
                ISMedicalRadialMenu.main["Cataplasm"].subMenu[s_bpUnbandaged].subMenu["Back"].functions = self.fillMenu;
                ISMedicalRadialMenu.main["Cataplasm"].subMenu[s_bpUnbandaged].subMenu["Back"].arguments = ISMedicalRadialMenu.main["Cataplasm"].subMenu;
                
            end
            ISMedicalRadialMenu.main["Cataplasm"].subMenu["Back"] = {};
            ISMedicalRadialMenu.main["Cataplasm"].subMenu["Back"].name = getText("IGUI_Emote_Back");
            ISMedicalRadialMenu.main["Cataplasm"].subMenu["Back"].icon = getTexture("media/ui/emotes/back.png");
            ISMedicalRadialMenu.main["Cataplasm"].subMenu["Back"].functions = self.fillMenu;
            ISMedicalRadialMenu.main["Cataplasm"].subMenu["Back"].arguments = ISMedicalRadialMenu.main;
        end
    end

    if ( #t_deepWoundedBodyParts > 0 and len(self.t_needles) > 0 )
        or ( len(t_specificWoundedBodyParts) > 0 and len(self.t_tweezers) > 0 )
            or ( #t_burntBodyParts > 0 and len(self.t_cleanBandages) > 0 ) then

        ISMedicalRadialMenu.main["Surgeon"] = {};
        ISMedicalRadialMenu.main["Surgeon"].name = getText("Surgeon");
        ISMedicalRadialMenu.main["Surgeon"].icon = getTexture("Item_SutureNeedle");
        ISMedicalRadialMenu.main["Surgeon"].subMenu = {};

        if #t_deepWoundedBodyParts > 0 and len(self.t_needles) > 0 then

            for i = 1, #t_deepWoundedBodyParts do
                local bpDeepWounded = t_deepWoundedBodyParts[i];
                local s_bpDeepWounded = bpDeepWounded:getType():toString();

                ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpDeepWounded] = {};
                ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpDeepWounded].name = BodyPartType.getDisplayName(bpDeepWounded:getType());
                ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpDeepWounded].icon = getTexture(bodyPartIcons[s_bpDeepWounded]);
                ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpDeepWounded].subMenu = {}

                for _, v in pairs(self.t_needles) do
                    if v:getType() == "SutureNeedle" then
                        ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpDeepWounded].subMenu[v:getType()] = {}
                        ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpDeepWounded].subMenu[v:getType()].name = v:getName();
                        ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpDeepWounded].subMenu[v:getType()].icon = v:getTexture();
                        ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpDeepWounded].subMenu[v:getType()].functions = self.surgeon;
                        ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpDeepWounded].subMenu[v:getType()].arguments = {}
                        ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpDeepWounded].subMenu[v:getType()].arguments.category = "Surgeon";
                        ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpDeepWounded].subMenu[v:getType()].arguments.item = v;
                        ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpDeepWounded].subMenu[v:getType()].arguments.bodyPart = bpDeepWounded;
                        ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpDeepWounded].subMenu[v:getType()].arguments.action = "ContextMenu_Stitch";
                    elseif v:getType() == "Needle" and self.thread then
                        local items = ArrayList.new();
                        items:add(self.thread);    items:add(v);
                        ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpDeepWounded].subMenu[v:getType()] = {}
                        ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpDeepWounded].subMenu[v:getType()].name = v:getName();
                        ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpDeepWounded].subMenu[v:getType()].icon = v:getTexture();
                        ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpDeepWounded].subMenu[v:getType()].functions = self.surgeon;
                        ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpDeepWounded].subMenu[v:getType()].arguments = {}
                        ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpDeepWounded].subMenu[v:getType()].arguments.category = "Surgeon";
                        ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpDeepWounded].subMenu[v:getType()].arguments.item = items;
                        ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpDeepWounded].subMenu[v:getType()].arguments.bodyPart = bpDeepWounded;
                        ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpDeepWounded].subMenu[v:getType()].arguments.action = "ContextMenu_Stitch";
                    end
                end

                ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpDeepWounded].subMenu["Back"] = {};
                ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpDeepWounded].subMenu["Back"].name = getText("IGUI_Emote_Back");
                ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpDeepWounded].subMenu["Back"].icon = getTexture("media/ui/emotes/back.png");
                ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpDeepWounded].subMenu["Back"].functions = self.fillMenu;
                ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpDeepWounded].subMenu["Back"].arguments = ISMedicalRadialMenu.main["Surgeon"].subMenu;

            end
        end
        
        if len(t_specificWoundedBodyParts) > 0 and len(self.t_tweezers) > 0 then

            for k, v in pairs(t_specificWoundedBodyParts) do
                local bpSpecificWounded = k;
                local s_bpSpecificWounded = bpSpecificWounded:getType():toString();

                ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpSpecificWounded] = {};
                ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpSpecificWounded].name = BodyPartType.getDisplayName(bpSpecificWounded:getType());
                ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpSpecificWounded].icon = getTexture(bodyPartIcons[s_bpSpecificWounded]);
                ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpSpecificWounded].subMenu = {}

                if v.haveGlass or v.haveBullet then
                    for _, iv in pairs(self.t_tweezers) do
                        ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpSpecificWounded].subMenu[iv:getType()] = {}
                        ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpSpecificWounded].subMenu[iv:getType()].name = iv:getName();
                        ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpSpecificWounded].subMenu[iv:getType()].icon = iv:getTexture();
                        ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpSpecificWounded].subMenu[iv:getType()].functions = self.surgeon;
                        ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpSpecificWounded].subMenu[iv:getType()].arguments = {}
                        ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpSpecificWounded].subMenu[iv:getType()].arguments.category = "Surgeon";
                        ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpSpecificWounded].subMenu[iv:getType()].arguments.item = iv;
                        ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpSpecificWounded].subMenu[iv:getType()].arguments.bodyPart = bpSpecificWounded;
                        if v.haveGlass then
                            ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpSpecificWounded].subMenu[iv:getType()].arguments.action = "ContextMenu_Remove_Glass";
                        else
                            ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpSpecificWounded].subMenu[iv:getType()].arguments.action = "ContextMenu_Remove_Bullet";
                        end
                    end

                    if v.haveGlass then
                        ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpSpecificWounded].subMenu["Hands"] = {}
                        ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpSpecificWounded].subMenu["Hands"].name = "Hands";
                        ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpSpecificWounded].subMenu["Hands"].icon = getTexture("media/ui/emotes/clap.png");
                        ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpSpecificWounded].subMenu["Hands"].functions = self.surgeon;
                        ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpSpecificWounded].subMenu["Hands"].arguments = {}
                        ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpSpecificWounded].subMenu["Hands"].arguments.category = "Surgeon";
                        ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpSpecificWounded].subMenu["Hands"].arguments.item = "Hands";
                        ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpSpecificWounded].subMenu["Hands"].arguments.bodyPart = bpSpecificWounded;
                        ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpSpecificWounded].subMenu["Hands"].arguments.action = "ContextMenu_Remove_Glass";
                    end

                    ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpSpecificWounded].subMenu["Back"] = {};
                    ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpSpecificWounded].subMenu["Back"].name = getText("IGUI_Emote_Back");
                    ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpSpecificWounded].subMenu["Back"].icon = getTexture("media/ui/emotes/back.png");
                    ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpSpecificWounded].subMenu["Back"].functions = self.fillMenu;
                    ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpSpecificWounded].subMenu["Back"].arguments = ISMedicalRadialMenu.main["Surgeon"].subMenu;

                end
                
            end
        end
        
        if #t_burntBodyParts > 0 and len(self.t_cleanBandages) > 0 then
            for i = 1, #t_burntBodyParts do
                local bpBurnt = t_burntBodyParts[i];
                local s_bpBurnt = bpBurnt:getType():toString();
                
                ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpBurnt] = {};
                ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpBurnt].name = BodyPartType.getDisplayName(bpBurnt:getType());
                ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpBurnt].icon = getTexture(bodyPartIcons[s_bpBurnt]);
                ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpBurnt].subMenu = {}

                for _, v in pairs(self.t_cleanBandages) do
                    
                    ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpBurnt].subMenu[v:getType()] = {}
                    ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpBurnt].subMenu[v:getType()].name = v:getName();
                    ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpBurnt].subMenu[v:getType()].icon = v:getTexture();
                    ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpBurnt].subMenu[v:getType()].functions = self.surgeon;
                    ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpBurnt].subMenu[v:getType()].arguments = {}
                    ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpBurnt].subMenu[v:getType()].arguments.category = "Surgeon";
                    ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpBurnt].subMenu[v:getType()].arguments.item = v;
                    ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpBurnt].subMenu[v:getType()].arguments.bodyPart = bpBurnt;
                    ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpBurnt].subMenu[v:getType()].arguments.action = "ContextMenu_Clean_Burn";

                end

                ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpBurnt].subMenu["Back"] = {};
                ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpBurnt].subMenu["Back"].name = getText("IGUI_Emote_Back");
                ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpBurnt].subMenu["Back"].icon = getTexture("media/ui/emotes/back.png");
                ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpBurnt].subMenu["Back"].functions = self.fillMenu;
                ISMedicalRadialMenu.main["Surgeon"].subMenu[s_bpBurnt].subMenu["Back"].arguments = ISMedicalRadialMenu.main["Surgeon"].subMenu;

            end
        end

        ISMedicalRadialMenu.main["Surgeon"].subMenu["Back"] = {};
        ISMedicalRadialMenu.main["Surgeon"].subMenu["Back"].name = getText("IGUI_Emote_Back");
        ISMedicalRadialMenu.main["Surgeon"].subMenu["Back"].icon = getTexture("media/ui/emotes/back.png");
        ISMedicalRadialMenu.main["Surgeon"].subMenu["Back"].functions = self.fillMenu;
        ISMedicalRadialMenu.main["Surgeon"].subMenu["Back"].arguments = ISMedicalRadialMenu.main;
    end

    if (#t_fracturedBodyParts > 0 and self.splint) then
        ISMedicalRadialMenu.main["Fractures"] = {};
        ISMedicalRadialMenu.main["Fractures"].name = getText("ContextMenu_Splint");
        ISMedicalRadialMenu.main["Fractures"].icon = self.splint:getTexture();
        ISMedicalRadialMenu.main["Fractures"].subMenu = {};

        for i = 1, #t_fracturedBodyParts do
            local bpFractured = t_fracturedBodyParts[i];
            local s_bpFractured = bpFractured:getType():toString();

            ISMedicalRadialMenu.main["Fractures"].subMenu[s_bpFractured] = {};
            ISMedicalRadialMenu.main["Fractures"].subMenu[s_bpFractured].name = BodyPartType.getDisplayName(bpFractured:getType());
            ISMedicalRadialMenu.main["Fractures"].subMenu[s_bpFractured].icon = getTexture(bodyPartIcons[s_bpFractured]);
            ISMedicalRadialMenu.main["Fractures"].subMenu[s_bpFractured].functions = self.surgeon;
            ISMedicalRadialMenu.main["Fractures"].subMenu[s_bpFractured].arguments = {};
            ISMedicalRadialMenu.main["Fractures"].subMenu[s_bpFractured].arguments.category = "Fractures";
            ISMedicalRadialMenu.main["Fractures"].subMenu[s_bpFractured].arguments.item = self.splint;
            ISMedicalRadialMenu.main["Fractures"].subMenu[s_bpFractured].arguments.bodyPart = bpFractured;
            ISMedicalRadialMenu.main["Fractures"].subMenu[s_bpFractured].arguments.action = "ContextMenu_Splint";
        end

        ISMedicalRadialMenu.main["Fractures"].subMenu["Back"] = {};
        ISMedicalRadialMenu.main["Fractures"].subMenu["Back"].name = getText("IGUI_Emote_Back");
        ISMedicalRadialMenu.main["Fractures"].subMenu["Back"].icon = getTexture("media/ui/emotes/back.png");
        ISMedicalRadialMenu.main["Fractures"].subMenu["Back"].functions = self.fillMenu;
        ISMedicalRadialMenu.main["Fractures"].subMenu["Back"].arguments = ISMedicalRadialMenu.main;

    end

    if len(self.t_pills) > 0 then
        ISMedicalRadialMenu.main["Pills"] = {};
        ISMedicalRadialMenu.main["Pills"].name = getText("ContextMenu_Take_pills");
        ISMedicalRadialMenu.main["Pills"].icon = getTexture("Item_PillsAntidepressant");
        ISMedicalRadialMenu.main["Pills"].subMenu = {};

        for _, v in pairs(self.t_pills) do
            ISMedicalRadialMenu.main["Pills"].subMenu[v:getType()] = {}
            ISMedicalRadialMenu.main["Pills"].subMenu[v:getType()].name = v:getName();
            ISMedicalRadialMenu.main["Pills"].subMenu[v:getType()].icon = v:getTexture();
            ISMedicalRadialMenu.main["Pills"].subMenu[v:getType()].functions = self.takePills;
            ISMedicalRadialMenu.main["Pills"].subMenu[v:getType()].arguments = {};
            ISMedicalRadialMenu.main["Pills"].subMenu[v:getType()].arguments.category = "Pills";
            ISMedicalRadialMenu.main["Pills"].subMenu[v:getType()].arguments.item = v;
        end

        ISMedicalRadialMenu.main["Pills"].subMenu["Back"] = {};
        ISMedicalRadialMenu.main["Pills"].subMenu["Back"].name = getText("IGUI_Emote_Back");
        ISMedicalRadialMenu.main["Pills"].subMenu["Back"].icon =  getTexture("media/ui/emotes/back.png");
        ISMedicalRadialMenu.main["Pills"].subMenu["Back"].functions = self.fillMenu;
        ISMedicalRadialMenu.main["Pills"].subMenu["Back"].arguments = ISMedicalRadialMenu.main;
    
    end

    local icon = nil;
    if not submenu then
        submenu = ISMedicalRadialMenu.main;
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

function ISMedicalRadialMenu.keyCheck(key)
    if (key == 44) then
        return true;
    else 
        return false;
    end
end

local STATE = {}
STATE[1] = {}

function ISMedicalRadialMenu.onKeyPressed(key)
    if not ISMedicalRadialMenu.keyCheck(key) then
        return;
    end

    local character = getSpecificPlayer(0);
	local radialMenu = getPlayerRadialMenu(0);

    if getCore():getOptionRadialMenuKeyToggle() and radialMenu:isReallyVisible() then
        STATE[1].radialWasVisible = true;
        radialMenu:removeFromUIManager();
        return;
    end
    
    STATE[1].radialWasVisible = false
    local menu = ISMedicalRadialMenu:new(character);
    menu:fillMenu();
end

function ISMedicalRadialMenu.onKeyRepeat(key)
end

function ISMedicalRadialMenu.onKeyReleased(key)
    if not ISMedicalRadialMenu.keyCheck(key) then
        return;
    end

    local character = getSpecificPlayer(0);
	local radialMenu = getPlayerRadialMenu(0);
	if radialMenu:isReallyVisible() or STATE[1].radialWasVisible then
		if not getCore():getOptionRadialMenuKeyToggle() then
			radialMenu:removeFromUIManager();
		end
		return
	end
end

--#endregion

local function OnGameStart()
	Events.OnKeyStartPressed.Add(ISMedicalRadialMenu.onKeyPressed);
	Events.OnKeyKeepPressed.Add(ISMedicalRadialMenu.onKeyRepeat);
	Events.OnKeyPressed.Add(ISMedicalRadialMenu.onKeyReleased);
end

Events.OnGameStart.Add(OnGameStart)