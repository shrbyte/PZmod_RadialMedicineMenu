require "TimedActions/ISBaseTimedAction"
require "ISUI/ISRadialMenu"

ISMedicalRadialMenu = ISBaseObject:derive("ISMedicalRadialMenu");

local function len(t)
    local n = 0

    for _ in pairs(t) do
        n = n + 1
    end
    return n
end

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

local bandageTypes = {
    "Bandage", "RippedSheets", "Bandaid"
}

local icons = {

}

--#region Utilities

local function getCharacterWounds()
    local character = getSpecificPlayer(0);
    local t_wounds = {};
    local bodyDamage = character:getBodyDamage();

    --print(bodyDamage:getHealth());

    for i = 0, bodyDamage:getBodyParts():size() - 1 do
        local bodyPart = bodyDamage:getBodyParts():get(i);
        if bodyPart:HasInjury() or (bodyPart:stitched() and not bodyPart:bandaged()) then
            --print(bodyPart:getType():toString())

            t_wounds[bodyPart:getType()] = {};
            t_wounds[bodyPart:getType()].health = bodyPart:getHealth();
            t_wounds[bodyPart:getType()].isBleeding = bodyPart:bleeding();
            t_wounds[bodyPart:getType()].isBandaged = bodyPart:bandaged();
            t_wounds[bodyPart:getType()].isBandageDirty = bodyPart:isBandageDirty();
            t_wounds[bodyPart:getType()].isDeepWounded = bodyPart:deepWounded();
        end

    end

    return t_wounds;
end

local function getBodyPartsForDressing(characterWounds)

    local bodyParts = {};

    for k, v in pairs(characterWounds) do
        if (v.isBleeding and not v.isBandaged) or v.isBandageDirty then
            bodyParts[k] = {};
            bodyParts[k].isBandaged = v.isBandaged;
            bodyParts[k].isBandageDirty = v.isBandageDirty;
        end
    end
    return bodyParts;
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
        if not v.isBandaged and v.isDeepWounded then
            table.insert(bodyParts, k)
        end
    end
    return bodyParts;
end

local function getAllAvailableStitchTools(args)
    args = args or nil;

    local character = getSpecificPlayer(0);
    local inventory = character:getInventory();
    local t_items = {};

    if inventory:contains("SutureNeedle") then
        t_items[inventory:getItemFromType("SutureNeedle")] = true;
    end
    if inventory:contains("Needle") and inventory:contains("Thread") then
        t_items[inventory:getItemFromType("Thread")] = true;
    end
    return t_items;
end

local function getAllAvailablePills(args)
    args = args or nil;

    local character = getSpecificPlayer(0);
    local inventory = character:getInventory();
    local t_pills = {};

    for i = 0, inventory:getItems():size() - 1 do
        local item = inventory:getItems():get(i);
        if string.match(item:getType(), "Pills") then
            t_pills[item] = true;
        end
    end
    return t_pills;
end

local function getAllAvailableDisinfectants(args)
    args = args or nil;

    local character = getSpecificPlayer(0);
    local inventory = character:getInventory();
    local items = {};

    for i = 0, inventory:getItems():size() - 1 do
        local item = inventory:getItems():get(i);
        if item:getAlcoholPower() > 0 and not item:isCanBandage() then
            items[item] = true;
        end
    end
    return items;
end

function ISMedicalRadialMenu:getAllAvailableBandages(args)
    args = args or nil;

    local character = getSpecificPlayer(0);
    local inventory = character:getInventory();
    local dressings = {};

    for i = 0, inventory:getItems():size() - 1 do
        local item = inventory:getItems():get(i);
        if item:isCanBandage() then
            dressings[item] = true;
        end
    end
    return dressings;
end

function ISMedicalRadialMenu:takePills(args)
    if args == nil then return end;
    local character = getSpecificPlayer(0);
    args.item:setJobDelta(0.0);
    ISTimedActionQueue.add(ISTakePillAction:new(character, args.item, 200));
end

function ISMedicalRadialMenu:useDisinfectant(args)
    if args == nil then return end;
    local character = getSpecificPlayer(0);
    local BP = character:getBodyDamage():getBodyPart(args.bodyPart);
    args.item:setJobDelta(0.0);
    ISTimedActionQueue.add(ISDisinfect:new(character, character, args.item, BP));
end

function ISMedicalRadialMenu:useBandages(args)
    if args == nil then return end;
    local character = getSpecificPlayer(0);
    local BP = character:getBodyDamage():getBodyPart(args.bodyPart);
    
    --print("RadialMED::" .. args.bodyPart:toString() .. " " .. args.action .. " " .. args.item:getType());

    if args.action == "apply" then
        ISTimedActionQueue.add(ISApplyBandage:new(character, character, args.item, BP, true));
        --BP:setBandaged(true, 4.0);
        return;
    end
    
    if args.action == "remove" then
        ISTimedActionQueue.add(ISApplyBandage:new(character, character, nil, BP, false));
        return;
    end
end

function ISMedicalRadialMenu:surgeon(args)
    if args == nil then return end;
    local character = getSpecificPlayer(0);
    local BP = character:getBodyDamage():getBodyPart(args.bodyPart);

    if args.action == "ContextMenu_Stitch" then
        ISTimedActionQueue.add(ISStitch:new(character, character, args.item, BP, true));
        return;
    elseif args.action == "ContextMenu_Remove_Stitch"  then
        ISTimedActionQueue.add(ISStitch:new(character, character, args.item, BP, false));
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

function ISMedicalRadialMenu:print(args)
    if args == nil then return end
    print("Done!")
end

function ISMedicalRadialMenu:fillMenu(submenu)
    local menu = getPlayerRadialMenu(self.playerNum);
    menu:clear();
    
    local t_wounds = getCharacterWounds();
    local t_unbandagedBodyParts = getUnbandagedBodyParts(t_wounds);
    local t_dirtyBandagedBodyParts = getDirtyBandagedBodyParts(t_wounds);
    local t_deepWoundedBodyParts = getDeepWoundedBodyParts(t_wounds);

    local t_pills = getAllAvailablePills(true);
    local t_disinfectants = getAllAvailableDisinfectants(true);
    local t_stitchTools = getAllAvailableStitchTools(true);
    local t_availableBandages = self.getAllAvailableBandages(self);

    ISMedicalRadialMenu.main = {}

    if #t_unbandagedBodyParts > 0 or #t_dirtyBandagedBodyParts > 0 then
        
        if len(t_availableBandages) > 0 or #t_dirtyBandagedBodyParts > 0 then
            ISMedicalRadialMenu.main["Dressing"] = {};
            ISMedicalRadialMenu.main["Dressing"].name = getText("Dressing");
            ISMedicalRadialMenu.main["Dressing"].icon = getTexture("media/ui/Bandage.png");
            ISMedicalRadialMenu.main["Dressing"].subMenu = {};
        end

        if #t_unbandagedBodyParts > 0 then

            if len(t_disinfectants) > 0 then
                ISMedicalRadialMenu.main["Disinfect"] = {};
                ISMedicalRadialMenu.main["Disinfect"].name = getText("Disinfect");
                ISMedicalRadialMenu.main["Disinfect"].icon = getTexture("Item_AlcoholWipes");
                ISMedicalRadialMenu.main["Disinfect"].subMenu = {};
            end
            
            for i = 1, #t_unbandagedBodyParts do
                local bpUnbandaged = t_unbandagedBodyParts[i];
                local s_bpUnbandaged = bpUnbandaged:toString();

                --#region Dressing
                if len(t_availableBandages) > 0 then
                    
                    ISMedicalRadialMenu.main["Dressing"].subMenu[s_bpUnbandaged] = {}
                    ISMedicalRadialMenu.main["Dressing"].subMenu[s_bpUnbandaged].name = BodyPartType.getDisplayName(bpUnbandaged);
                    ISMedicalRadialMenu.main["Dressing"].subMenu[s_bpUnbandaged].icon = getTexture(bodyPartIcons[s_bpUnbandaged]);
                    ISMedicalRadialMenu.main["Dressing"].subMenu[s_bpUnbandaged].subMenu = {};                
                    
                    for k, _ in pairs(t_availableBandages) do

                        ISMedicalRadialMenu.main["Dressing"].subMenu[s_bpUnbandaged].subMenu[k:getType()] = {};
                        ISMedicalRadialMenu.main["Dressing"].subMenu[s_bpUnbandaged].subMenu[k:getType()].name = k:getName();
                        ISMedicalRadialMenu.main["Dressing"].subMenu[s_bpUnbandaged].subMenu[k:getType()].icon = k:getTexture();
                        ISMedicalRadialMenu.main["Dressing"].subMenu[s_bpUnbandaged].subMenu[k:getType()].functions = self.useBandages;
                        ISMedicalRadialMenu.main["Dressing"].subMenu[s_bpUnbandaged].subMenu[k:getType()].arguments = {};
                        ISMedicalRadialMenu.main["Dressing"].subMenu[s_bpUnbandaged].subMenu[k:getType()].arguments.category = "Dressing";
                        ISMedicalRadialMenu.main["Dressing"].subMenu[s_bpUnbandaged].subMenu[k:getType()].arguments.item = k;
                        ISMedicalRadialMenu.main["Dressing"].subMenu[s_bpUnbandaged].subMenu[k:getType()].arguments.bodyPart = bpUnbandaged;
                        ISMedicalRadialMenu.main["Dressing"].subMenu[s_bpUnbandaged].subMenu[k:getType()].arguments.action = "apply";

                    end
 
                ISMedicalRadialMenu.main["Dressing"].subMenu[s_bpUnbandaged].subMenu["Back"] = {};
                ISMedicalRadialMenu.main["Dressing"].subMenu[s_bpUnbandaged].subMenu["Back"].name = getText("Back");
                ISMedicalRadialMenu.main["Dressing"].subMenu[s_bpUnbandaged].subMenu["Back"].icon = getTexture("media/ui/emotes/back.png");
                ISMedicalRadialMenu.main["Dressing"].subMenu[s_bpUnbandaged].subMenu["Back"].functions = self.fillMenu;
                ISMedicalRadialMenu.main["Dressing"].subMenu[s_bpUnbandaged].subMenu["Back"].arguments = ISMedicalRadialMenu.main["Dressing"].subMenu;

                end
                --#endregion

                --#region Disinfect
                if len(t_disinfectants) > 0 then
                    ISMedicalRadialMenu.main["Disinfect"].subMenu[s_bpUnbandaged] = {};
                    ISMedicalRadialMenu.main["Disinfect"].subMenu[s_bpUnbandaged].name = BodyPartType.getDisplayName(bpUnbandaged);
                    ISMedicalRadialMenu.main["Disinfect"].subMenu[s_bpUnbandaged].icon = getTexture(bodyPartIcons[s_bpUnbandaged]);
                    ISMedicalRadialMenu.main["Disinfect"].subMenu[s_bpUnbandaged].subMenu = {}
                    
                    for k, _ in pairs(t_disinfectants) do
                        ISMedicalRadialMenu.main["Disinfect"].subMenu[s_bpUnbandaged].subMenu[k:getType()] = {}
                        ISMedicalRadialMenu.main["Disinfect"].subMenu[s_bpUnbandaged].subMenu[k:getType()].name = k:getName();
                        ISMedicalRadialMenu.main["Disinfect"].subMenu[s_bpUnbandaged].subMenu[k:getType()].icon = k:getTexture();
                        print(k:getTexture())
                        ISMedicalRadialMenu.main["Disinfect"].subMenu[s_bpUnbandaged].subMenu[k:getType()].functions = self.useDisinfectant;
                        ISMedicalRadialMenu.main["Disinfect"].subMenu[s_bpUnbandaged].subMenu[k:getType()].arguments = {};
                        ISMedicalRadialMenu.main["Disinfect"].subMenu[s_bpUnbandaged].subMenu[k:getType()].arguments.item = k;
                        ISMedicalRadialMenu.main["Disinfect"].subMenu[s_bpUnbandaged].subMenu[k:getType()].arguments.bodyPart = bpUnbandaged;
                    end

                    --#region Back Button
                    ISMedicalRadialMenu.main["Disinfect"].subMenu[s_bpUnbandaged].subMenu["Back"] = {};
                    ISMedicalRadialMenu.main["Disinfect"].subMenu[s_bpUnbandaged].subMenu["Back"].name = getText("Back");
                    ISMedicalRadialMenu.main["Disinfect"].subMenu[s_bpUnbandaged].subMenu["Back"].icon = getTexture("media/ui/emotes/back.png");
                    ISMedicalRadialMenu.main["Disinfect"].subMenu[s_bpUnbandaged].subMenu["Back"].functions = self.fillMenu;
                    ISMedicalRadialMenu.main["Disinfect"].subMenu[s_bpUnbandaged].subMenu["Back"].arguments = ISMedicalRadialMenu.main["Disinfect"].subMenu;
                    
                    ISMedicalRadialMenu.main["Disinfect"].subMenu["Back"] = {};
                    ISMedicalRadialMenu.main["Disinfect"].subMenu["Back"].name = getText("Back");
                    ISMedicalRadialMenu.main["Disinfect"].subMenu["Back"].icon = getTexture("media/ui/emotes/back.png");
                    ISMedicalRadialMenu.main["Disinfect"].subMenu["Back"].functions = self.fillMenu;
                    ISMedicalRadialMenu.main["Disinfect"].subMenu["Back"].arguments = ISMedicalRadialMenu.main;
                    --#endregion
                end
                --#endregion
            end

        end

        if len(t_availableBandages) > 0 or #t_dirtyBandagedBodyParts > 0 then
            ISMedicalRadialMenu.main["Dressing"].subMenu["Back"] = {};
            ISMedicalRadialMenu.main["Dressing"].subMenu["Back"].name = getText("Back");
            ISMedicalRadialMenu.main["Dressing"].subMenu["Back"].icon = getTexture("media/ui/emotes/back.png");
            ISMedicalRadialMenu.main["Dressing"].subMenu["Back"].functions = self.fillMenu;
            ISMedicalRadialMenu.main["Dressing"].subMenu["Back"].arguments = ISMedicalRadialMenu.main;
        end
        
        if #t_dirtyBandagedBodyParts > 0 then
            ISMedicalRadialMenu.main["Dressing"].subMenu["Remove"] = {};
            ISMedicalRadialMenu.main["Dressing"].subMenu["Remove"].name = getText("Remove Bandage");
            
            ISMedicalRadialMenu.main["Dressing"].subMenu["Remove"].subMenu = {};
            for i = 1, #t_dirtyBandagedBodyParts do
                ISMedicalRadialMenu.main["Dressing"].subMenu["Remove"].subMenu[t_dirtyBandagedBodyParts[i]] = {};
                ISMedicalRadialMenu.main["Dressing"].subMenu["Remove"].subMenu[t_dirtyBandagedBodyParts[i]].name = BodyPartType.getDisplayName(t_dirtyBandagedBodyParts[i]);
                ISMedicalRadialMenu.main["Dressing"].subMenu["Remove"].subMenu[t_dirtyBandagedBodyParts[i]].icon = getTexture(bodyPartIcons[t_dirtyBandagedBodyParts[i]:toString()]);
                ISMedicalRadialMenu.main["Dressing"].subMenu["Remove"].subMenu[t_dirtyBandagedBodyParts[i]].functions = self.useBandages;
                ISMedicalRadialMenu.main["Dressing"].subMenu["Remove"].subMenu[t_dirtyBandagedBodyParts[i]].arguments = {};
                ISMedicalRadialMenu.main["Dressing"].subMenu["Remove"].subMenu[t_dirtyBandagedBodyParts[i]].arguments.category = "Dressing";
                ISMedicalRadialMenu.main["Dressing"].subMenu["Remove"].subMenu[t_dirtyBandagedBodyParts[i]].arguments.item = nil;
                ISMedicalRadialMenu.main["Dressing"].subMenu["Remove"].subMenu[t_dirtyBandagedBodyParts[i]].arguments.bodyPart = t_dirtyBandagedBodyParts[i];
                ISMedicalRadialMenu.main["Dressing"].subMenu["Remove"].subMenu[t_dirtyBandagedBodyParts[i]].arguments.action = "remove";
            end

            ISMedicalRadialMenu.main["Dressing"].subMenu["Remove"].subMenu["Back"] = {};
            ISMedicalRadialMenu.main["Dressing"].subMenu["Remove"].subMenu["Back"].name = getText("Back");
            ISMedicalRadialMenu.main["Dressing"].subMenu["Remove"].subMenu["Back"].functions = self.fillMenu;
            ISMedicalRadialMenu.main["Dressing"].subMenu["Remove"].subMenu["Back"].arguments = ISMedicalRadialMenu.main["Dressing"].subMenu;
        end

        if #t_deepWoundedBodyParts > 0 then
            if len(t_stitchTools) > 0 then
                ISMedicalRadialMenu.main["Surgeon"] = {};
                ISMedicalRadialMenu.main["Surgeon"].name = getText("Surgeon");
                ISMedicalRadialMenu.main["Surgeon"].icon = getTexture("Item_SutureNeedle");
                ISMedicalRadialMenu.main["Surgeon"].subMenu = {};

                for i = 1, #t_deepWoundedBodyParts do
                    local bpDeepWounded = t_deepWoundedBodyParts[i];
                    local s_bpDeepWounded = bpDeepWounded:toString();

                    ISMedicalRadialMenu.main["Surgeon"].subMenu[bpDeepWounded] = {};
                    ISMedicalRadialMenu.main["Surgeon"].subMenu[bpDeepWounded].name = BodyPartType.getDisplayName(bpDeepWounded);
                    ISMedicalRadialMenu.main["Surgeon"].subMenu[bpDeepWounded].icon = getTexture(bodyPartIcons[s_bpDeepWounded]);
                    ISMedicalRadialMenu.main["Surgeon"].subMenu[bpDeepWounded].subMenu = {}

                    for k, _ in pairs(t_stitchTools) do
                        ISMedicalRadialMenu.main["Surgeon"].subMenu[bpDeepWounded].subMenu[k:getType()] = {}
                        ISMedicalRadialMenu.main["Surgeon"].subMenu[bpDeepWounded].subMenu[k:getType()].name = k:getName();
                        ISMedicalRadialMenu.main["Surgeon"].subMenu[bpDeepWounded].subMenu[k:getType()].icon = k:getTexture();
                        ISMedicalRadialMenu.main["Surgeon"].subMenu[bpDeepWounded].subMenu[k:getType()].functions = self.surgeon;
                        ISMedicalRadialMenu.main["Surgeon"].subMenu[bpDeepWounded].subMenu[k:getType()].arguments = {}
                        ISMedicalRadialMenu.main["Surgeon"].subMenu[bpDeepWounded].subMenu[k:getType()].arguments.category = "Surgeon";
                        ISMedicalRadialMenu.main["Surgeon"].subMenu[bpDeepWounded].subMenu[k:getType()].arguments.item = k;
                        ISMedicalRadialMenu.main["Surgeon"].subMenu[bpDeepWounded].subMenu[k:getType()].arguments.bodyPart = t_deepWoundedBodyParts[i];
                        ISMedicalRadialMenu.main["Surgeon"].subMenu[bpDeepWounded].subMenu[k:getType()].arguments.action = "ContextMenu_Stitch";
                    end

                end
            end
        end


    end

    if len(t_pills) > 0 then
        ISMedicalRadialMenu.main["Pills"] = {};
        ISMedicalRadialMenu.main["Pills"].name = getText("Pills");
        ISMedicalRadialMenu.main["Pills"].icon = getTexture("Item_PillsAntidepressant");
        ISMedicalRadialMenu.main["Pills"].subMenu = {};

        for k, _ in pairs(t_pills) do
            ISMedicalRadialMenu.main["Pills"].subMenu[k:getType()] = {}
            ISMedicalRadialMenu.main["Pills"].subMenu[k:getType()].name = k:getName();
            ISMedicalRadialMenu.main["Pills"].subMenu[k:getType()].icon = k:getTexture();
            ISMedicalRadialMenu.main["Pills"].subMenu[k:getType()].functions = self.takePills;
            ISMedicalRadialMenu.main["Pills"].subMenu[k:getType()].arguments = {};
            ISMedicalRadialMenu.main["Pills"].subMenu[k:getType()].arguments.category = "Pills";
            ISMedicalRadialMenu.main["Pills"].subMenu[k:getType()].arguments.item = k;
        end

        ISMedicalRadialMenu.main["Pills"].subMenu["Back"] = {};
        ISMedicalRadialMenu.main["Pills"].subMenu["Back"].name = getText("Back");
        ISMedicalRadialMenu.main["Pills"].subMenu["Back"].icon =  getTexture("media/ui/emotes/back.png");
        ISMedicalRadialMenu.main["Pills"].subMenu["Back"].functions = self.fillMenu;
        ISMedicalRadialMenu.main["Pills"].subMenu["Back"].arguments = ISMedicalRadialMenu.main;
    end

    print(len(t_wounds))
    
    ISMedicalRadialMenu.main["Debug"] = {};
    ISMedicalRadialMenu.main["Debug"].name = getText("Debug");
    ISMedicalRadialMenu.main["Debug"].subMenu = {};
    ISMedicalRadialMenu.main["Debug"].subMenu["FindDressing"] = {};
    ISMedicalRadialMenu.main["Debug"].subMenu["FindDressing"].name = getText("FindDressing");
    ISMedicalRadialMenu.main["Debug"].subMenu["FindDressing"].functions = self.print;
    ISMedicalRadialMenu.main["Debug"].subMenu["FindDressing"].arguments = {};
    ISMedicalRadialMenu.main["Debug"].subMenu["FindDressing"].arguments.category = "Debug";
    ISMedicalRadialMenu.main["Debug"].subMenu["FindDressing"].arguments.action = "getAllAvailableBandages";
    
    local icon = nil;
    if not submenu then
        submenu = ISMedicalRadialMenu.main;
    end;
    for k, v in pairs(submenu) do
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

    local playerObj = getSpecificPlayer(0);
	local radialMenu = getPlayerRadialMenu(0);

    if getCore():getOptionRadialMenuKeyToggle() and radialMenu:isReallyVisible() then
        STATE[1].radialWasVisible = true;
        radialMenu:removeFromUIManager();
        return;
    end
    --print("That's right!");
    
    STATE[1].radialWasVisible = false
    local menu = ISMedicalRadialMenu:new(playerObj);
    menu:fillMenu(nil, nil);
end

function ISMedicalRadialMenu.onKeyRepeat(key)
end

function ISMedicalRadialMenu.onKeyReleased(key)
    if not ISMedicalRadialMenu.keyCheck(key) then
        return;
    end

    local playerObj = getSpecificPlayer(0);
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