StatScanner_bonuses = {};
StatScanner_currentset = "";
StatScanner_sets = {};
StatScanner_currentsetcount = "";
StatScanner_setcount = {};
StatScanner_setsproperty = {};
STATCOMPARE_SETPROPERTY_PATTERN = "^%((%d+)%) "..STATCOMPARE_SET_PREFIX;

local function _SaveValueToBonuses(effect, value)
	local i,e;
	if(type(effect) == "string") then
		if(StatScanner_bonuses[effect]) then
			StatScanner_bonuses[effect] = StatScanner_bonuses[effect] + value;
		else
			StatScanner_bonuses[effect] = value;
		end
	else 
	-- list of effects
		if(type(value) == "table") then
			for i,e in pairs(effect) do
				_SaveValueToBonuses(e, value[i]);
			end
		else
			for i,e in pairs(effect) do
				_SaveValueToBonuses(e, value);
			end
		end
	end
end;


-- Identifies simple tokens like "Intellect" and composite tokens like "Fire damage" and 
-- add the value to the respective bonus.
local function _SaveTokenToBonuses(token, value)
	local i, p, s1, s2;
	
	if(STATCOMPARE_TOKEN_EFFECT[token]) then
		_SaveValueToBonuses(STATCOMPARE_TOKEN_EFFECT[token], value);
		return true;
	else
		s1 = nil;
		s2 = nil;
		for i,p in pairs(STATCOMPARE_S1) do
			if(string.find(token,p.pattern,1,1)) then
				s1 = p.effect;
			end
		end	
		for i,p in pairs(STATCOMPARE_S2) do
			if(string.find(token,p.pattern,1,1)) then
				s2 = p.effect;
			end
		end	
		if(s1 and s2) then
			_SaveValueToBonuses(s1..s2, value);
			return true;
		end 
	end
	return false;
end

local function _SaveSetcount(link, statset)
	-- if set item, mark set as already scanned
	local sColor = nil;
	if(statset ~= "") then
		StatScanner_sets[statset] = 1;
		if (StatScanner_setcount[statset]) then
			StatScanner_setcount[statset].count = StatScanner_setcount[statset].count+1;
		else
			StatScanner_setcount[statset] = {};
			StatScanner_setcount[statset].count=1;
			if link ~= nil then
				_, _, sColor, _, _ = string.find(link, STATCOMPARE_ITEMLINK_PATTERN);
				StatScanner_setcount[statset].color=sColor;
			elseif SCObjectTooltipTextLeft1 ~= nil then
				local r,g,b,_ = SCObjectTooltipTextLeft1:GetTextColor();
				sColor = string.format("%2x", r*255)..string.format("%2x", g*255)..string.format("%2x", b*255);
			end
			StatScanner_setcount[statset].color=sColor;
			StatScanner_setcount[statset].total=StatScanner_currentsetcount;
		end
	end;
end


-- Scans generic bonuses like "+3 Intellect" or "Arcane Resistance +4"
local function _ScanForDiscreteGearBonuses(line)
	local value, token, pos, tmpStr, found;
	line = string.gsub( line, "^%s+", "" );
	-- split line at "/" for enchants with multiple effects
	found = false;

	while(string.len(line) > 0) do
		pos = string.find(line, "/", 1, true);
		if(pos) then
			tmpStr = string.sub(line,1,pos-1);
			line = string.sub(line,pos+1);
		else
			tmpStr = line;
			line = "";
		end

		-- trim line
		tmpStr = string.gsub( tmpStr, "^%s+", "" );
   		tmpStr = string.gsub( tmpStr, "%s+$", "" );
       		tmpStr = string.gsub( tmpStr, "%.$", "" );

		_, _, value, token = string.find(tmpStr, STATCOMPARE_PREFIX_PATTERN);
		if(not value) then
			_, _,  token, value = string.find(tmpStr, STATCOMPARE_SUFFIX_PATTERN);
		end

		if(token and value) then
			-- trim token
			token = string.gsub( token, "^%s+", "" );
    			token = string.gsub( token, "%s+$", "" );
	
			if(_SaveTokenToBonuses(token,value)) then
				found = true;
			end
		end
	end
	return found;
end

-- Scans last fallback for not generic enchants, like "Mana Regen x per 5 sec."
local function _ScanForMiscGearBonuses(line)
	local i, p, value, start, found;
	line = string.gsub( line, "^%s+", "" );
	found = false;
	for i,p in pairs(STATCOMPARE_OTHER_PATTERNS) do
		if (not p.apattern) then p.apattern = "^" .. p.pattern; end
		start, _, value = string.find(line, p.apattern);

		if(start) then
			if(p.value) then
				_SaveValueToBonuses(p.effect, p.value)
			elseif(value) then
				_SaveValueToBonuses(p.effect, value)
			end
			found = true;
			break;
		end
	end
	return found;
end


-- Scans passive bonuses like "Set: " and "Equip: "
local function _ScanForPassiveGearBonuses(line)
	local i, p, value, found, start;

	found = false;
	line = string.gsub( line, "^%s+", "" );
	for i,p in pairs(STATCOMPARE_EQUIP_PATTERNS) do
		if (not p.apattern) then p.apattern = "^" .. p.pattern; end
		start, _, value = string.find(line, p.apattern);
		if(start) then
			if(p.value) then
				_SaveValueToBonuses(p.effect, p.value);
			elseif(value) then
				if(value=="s1")then value=10; end -- cwow°þÆ¤µ¶·­Òë´íÎó
				_SaveValueToBonuses(p.effect, value);
			end
			found = true;
			break;
		end
	end
	if(not found) then
		found = _ScanForDiscreteGearBonuses(line);
	end
	return found;
end


local function _ScanLineForBonuses(line,ifScanSet)
	local tmpStr, found;
	found = false;

	-- Check for "Equip: "
	if(string.sub(line,0,string.len(STATCOMPARE_EQUIP_PREFIX)) == STATCOMPARE_EQUIP_PREFIX) then
		tmpStr = string.sub(line,string.len(STATCOMPARE_EQUIP_PREFIX)+1);
		found = _ScanForPassiveGearBonuses(tmpStr);

	-- Check for "Set: "
	elseif(string.sub(line,0,string.len(STATCOMPARE_SET_PREFIX)) == STATCOMPARE_SET_PREFIX
			and StatScanner_currentset ~= "" 
			and not StatScanner_sets[StatScanner_currentset]
			and ifScanSet==1) then

		tmpStr = string.sub(line,string.len(STATCOMPARE_SET_PREFIX)+1);
		found = _ScanForPassiveGearBonuses(tmpStr);

	-- any other line (standard stats, enchantment, set name, etc.)
	else
		-- Check for set name
		_, _, tmpStr,setcount = string.find(line, STATCOMPARE_SETNAME_PATTERN);
		if(tmpStr) then
			StatScanner_currentset = tmpStr;
			StatScanner_currentsetcount = setcount;
		else
			found = _ScanForDiscreteGearBonuses(line);
			if(not found) then
				found = _ScanForMiscGearBonuses(line);
			end;
		end
		-- Check for set property
		if(ifScanSet == 0 and not found) then
			found = StatScanner_ScanSetProperty(line);
		end
	end
	return found;
end;


local function _ScanSetPropertyAll()
	local found = false;
	for i,v in pairs(StatScanner_setcount) do
		for j=1, getn(StatScanner_setsproperty) do
			if(i == StatScanner_setsproperty[j].setsname) then
				if(v.count >= StatScanner_setsproperty[j].count) then
					found = _ScanForPassiveGearBonuses(StatScanner_setsproperty[j].line);
				end
			end
		end
	end
	return found;
end


-- Scans target(not self)'s set property generic bonuses 
-- like "(2) Set: +3 Intellect" or "(5) Set: Arcane Resistance +4"
function StatScanner_ScanSetProperty(line)
	local found = false;
	local tmpStr;

	if(StatScanner_currentset == "") then
		return found;
	end

	if(not line) then
		return found;
	end

	line = string.gsub( line, "^%s+", "" );
	local startpos, endpos, value = string.find(line, STATCOMPARE_SETPROPERTY_PATTERN);
	local count = getn(StatScanner_setsproperty);

	if(not value) then
		return found;
	end

	tmpStr = string.sub(line, endpos + 1);
	tmpStr = string.gsub( tmpStr, "^%s+", "" );
	for i = 1, count do
		if(StatScanner_setsproperty[i]) then
			if(StatScanner_setsproperty[i].setsname == StatScanner_currentset and
			   StatScanner_setsproperty[i].count == tonumber(value) and
			   StatScanner_setsproperty[i].line == tmpStr) then
				return found;
			end
		end
	end
	
	count = count + 1;
	StatScanner_setsproperty[count] = {};
	StatScanner_setsproperty[count].setsname = StatScanner_currentset;
	StatScanner_setsproperty[count].count = tonumber(value);
	StatScanner_setsproperty[count].line = tmpStr;
	found = true;

	return found;
end

local SC_AttackSpellId = nil;
function StatCompare_CharStats_GetCritChance()
	local critChance, iCritInfo;
	-- PERF: find the "Attack" spell once, then reuse its id (spellbook can change
	-- when learning spells, so verify the name and rescan only if it moved).
	local id = SC_AttackSpellId;
	if (not id or GetSpellName(id, BOOKTYPE_SPELL) ~= STATCOMPARE_ATTACKNAME) then
		id = 1;
		if (GetSpellName(1, BOOKTYPE_SPELL) ~= STATCOMPARE_ATTACKNAME) then
			local _, _, offset, numSpells = GetSpellTabInfo(1);
			for i=1, numSpells do
				if (GetSpellName(i,BOOKTYPE_SPELL) == STATCOMPARE_ATTACKNAME) then
					id = i;
					break;
				end
			end
		end
		SC_AttackSpellId = id;
	end
	-- PERF: use our private tooltip instead of GameTooltip, so other addons'
	-- GameTooltip hooks (pfUI, EnhTooltip, ...) don't run on every refresh.
	SCObjectTooltip:SetOwner(UIParent, "ANCHOR_NONE");
	SCObjectTooltip:ClearLines();
	SCObjectTooltip:SetSpell(id, BOOKTYPE_SPELL);
	local spellName = SCObjectTooltipTextLeft2:GetText();
	SCObjectTooltip:Hide();
	if (not spellName) then
		return nil;
	end
	iCritInfo = string.gsub(spellName, "(.*)%%.*", "%1");
	if(iCritInfo) then
		critChance = iCritInfo;
	else
		critChance = nil;
	end
	return critChance;
end

function StatScanner_ScanItem(link)
	StatScanner_bonuses = {};
	StatScanner_sets = {};
	StatScanner_setcount = {};
	StatScanner_currentset = "";
	StatScanner_currentsetcount = "";

	SCItemTooltip:SetOwner(DressUpFrame, "ANCHOR_NONE");
	SCItemTooltip:SetPoint("TOPLEFT", DressUpFrame:GetName(), "TOPRIGHT", -30, -12);
	SCItemTooltip.default=1;
	SCItemTooltip:ClearLines();

	SCItemTooltip:SetHyperlink(link);
	SCItemTooltip:Show();

	local itemName = SCItemTooltipTextLeft1:GetText();

	local tmpText, tmpStr, lines;
	lines = SCItemTooltip:NumLines();
	for i=2, lines, 1 do
		tmpText = getglobal("SCItemTooltipTextLeft"..i);
		val = nil;
		if (tmpText:GetText()) then
			tmpStr = tmpText:GetText();
			_ScanLineForBonuses(tmpStr,1);
		end
	end
end

-- PERF: gear scan cache. Scanning 19 items through a tooltip + ~80 patterns per line
-- is the expensive part of opening the character sheet. The result only depends on
-- the equipped item links, so we keep the last result per unit and reuse it
-- as long as the gear signature has not changed.
StatScanner_GearCache = {};

function StatScanner_GetGearSignature(unit)
	local sunit = unit and unit or "target";
	local parts = {};
	for i=1, 19 do
		parts[i] = GetInventoryItemLink(sunit, i) or "-";
	end
	return table.concat(parts, ";");
end

local function _CopyTable(t)
	local r = {};
	for k,v in pairs(t) do r[k] = v; end
	return r;
end

function StatScanner_ScanUnit(unit)
	--[[
	0 = ammo
	1 = head
	2 = neck
	3 = shoulder
	4 = shirt
	5 = chest
	6 = belt
	7 = legs
	8 = feet
	9 = wrist
	10 = gloves
	11 = finger 1
	12 = finger 2
	13 = trinket 1
	14 = trinket 2
	15 = back
	16 = main hand
	17 = off hand
	18 = ranged
	19 = tabard
	]]--
	
	local i, j;
	local sunit = unit and unit or "target";
	local ifScanSet = sunit == "player" and 1 or 0;
	local id, hasItem;
	local itemName, tmpText, tmpStr, tmpSet, lines, set;

	local sig = StatScanner_GetGearSignature(sunit);
	if (sunit == "target") then
		sig = (UnitName("target") or "?") .. "|" .. sig;
	end
	local cached = StatScanner_GearCache[sunit];
	if (cached and cached.sig == sig) then
		-- Copy bonuses: buff/char scanners add into this table afterwards.
		StatScanner_bonuses = _CopyTable(cached.bonuses);
		StatScanner_sets = _CopyTable(cached.sets);
		StatScanner_setcount = cached.setcount;
		StatScanner_setsproperty = cached.setsproperty;
		StatScanner_currentset = "";
		StatScanner_currentsetcount = "";
		return;
	end

	StatScanner_bonuses = {};
	StatScanner_sets = {};
	StatScanner_setcount = {};
	StatScanner_setsproperty = {};

	-- An item whose link is not available yet (inspect data still loading) makes
	-- the result incomplete, so we don't cache it.
	local incomplete = false;

	for i=1, 19 ,1 do
		StatScanner_currentset = "";
		StatScanner_currentsetcount = "";
		local link = GetInventoryItemLink(sunit, i);
		-- To parse an item's text we assign it to a tooltip, then loop through the lines of text.
		SCObjectTooltip:Hide()
		SCObjectTooltip:SetOwner(UIParent, "ANCHOR_NONE");
		if (link~=nil) then
			local item = gsub(link, ".*(item:%d+:%d+:%d+:%d+).*", "%1", 1);
			SCObjectTooltip:SetHyperlink(item);
		else
			SCObjectTooltip:SetInventoryItem(sunit, i);
		end
		itemName = SCObjectTooltipTextLeft1:GetText();
		lines = SCObjectTooltip:NumLines();
		if (link == nil and lines > 0 and itemName) then
			incomplete = true;
		end

		for j=2, lines, 1 do
			tmpText = getglobal("SCObjectTooltipTextLeft"..j);
			if (tmpText:GetText()) then
				tmpStr = tmpText:GetText();
				_ScanLineForBonuses(tmpStr,ifScanSet); -- Hydrate globals such as StatScanner_bonuses and StatScanner_currentset
			end
		end
		_SaveSetcount(link, StatScanner_currentset)
	end

	if(ifScanSet == 0) then
		found = _ScanSetPropertyAll();
	end

	SCObjectTooltip:Hide()

	if (not incomplete) then
		StatScanner_GearCache[sunit] = {
			sig = sig,
			bonuses = _CopyTable(StatScanner_bonuses),
			sets = _CopyTable(StatScanner_sets),
			setcount = StatScanner_setcount,
			setsproperty = StatScanner_setsproperty,
		};
	else
		StatScanner_GearCache[sunit] = nil;
	end
end
