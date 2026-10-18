--[[
  Buffer Stats helper by LastHime
]]

-- Global var
SC_BuffScanner_bonuses = {};
SC_Buffer_King = 0;

function SC_BuffScanner_ScanAllInspect( bonus, unit )
	local i = 1;
	local j, lines;
	local tmpText, tmpStr, val;

	local showBuffBonus = StatCompare_GetSetting("ShowBuffBonus");
	SC_BuffScanner_bonuses = {};
	if(showBuffBonus == 0) then
		return nil;
	end

	if(not unit) then
		unit = "player";
	end

	SC_Buffer_King = 0;
	while UnitBuff( unit, i ) do
		SCObjectTooltip:Hide()
		SCObjectTooltip:SetOwner(UIParent, "ANCHOR_NONE");
		SCObjectTooltip:SetUnitBuff( unit, i );
		lines = SCObjectTooltip:NumLines();

		for j=2, lines, 1 do
			tmpText = getglobal("SCObjectTooltipTextLeft"..j);
			val = nil;
			if (tmpText:GetText()) then
				tmpStr = tmpText:GetText();
				found = SC_BuffScanner_ScanLine(tmpStr);
			end
		end
		
		i = i + 1;
	end

	for i,e in pairs(STATCOMPARE_EFFECTS) do
		if(SC_BuffScanner_bonuses[e.effect]) then
			if(bonus[e.effect]) then
				bonus[e.effect] = bonus[e.effect] + SC_BuffScanner_bonuses[e.effect];
			else
				bonus[e.effect] = SC_BuffScanner_bonuses[e.effect];
			end
		end
	end

	return nil;
end

-- PERF: buff tooltip lines repeat constantly, so remember which pattern (if any)
-- matched a given line and its captures instead of re-running every pattern.
local SC_BuffLineCache = {};
local SC_BuffLineCacheSize = 0;

function SC_BuffScanner_ScanLine(line)
	local i, p, value, start, v1, v2, v3, v4;

	local hit = SC_BuffLineCache[line];
	if (hit == nil) then
		local trimmed = string.gsub( line, "^%s+", "" );
		hit = false;
		for i,p in pairs(STATCOMPARE_BUFF_PATTERNS) do
			if (not p.apattern) then p.apattern = "^" .. p.pattern; end
			start, _, value, v1, v2, v3, v4 = string.find(trimmed, p.apattern);
			if(start) then
				hit = { p = p, value = value, v1 = v1, v2 = v2, v3 = v3, v4 = v4 };
				break;
			end
		end
		if (SC_BuffLineCacheSize > 500) then
			SC_BuffLineCache = {};
			SC_BuffLineCacheSize = 0;
		end
		SC_BuffLineCache[line] = hit;
		SC_BuffLineCacheSize = SC_BuffLineCacheSize + 1;
	end

	if (not hit) then
		return false;
	end

	p = hit.p;
	if(p.king) then
		SC_Buffer_King = 1;
	elseif(p.value) then
		SC_BuffScanner_AddValue(p.effect, p.value);
	elseif(hit.value) then
		SC_BuffScanner_AddValue(p.effect, hit.value, hit.v1, hit.v2, hit.v3, hit.v4);
	end
	return true;
end;

function SC_BuffScanner_AddValue(effect, value, v1, v2, v3, v4)
	local i,e;
	if(type(effect) == "string") then
		if(SC_BuffScanner_bonuses[effect]) then
			SC_BuffScanner_bonuses[effect] = SC_BuffScanner_bonuses[effect] + value;
		else
			SC_BuffScanner_bonuses[effect] = value;
		end
	else 
	-- list of effects
		if(type(value) == "table") then
			for i,e in pairs(effect) do
				SC_BuffScanner_AddValue(e, value[i]);
			end
		else
			for i,e in pairs(effect) do
				if(i == 2 and v1) then
					SC_BuffScanner_AddValue(e, v1);
				elseif(i == 3 and v2) then
					SC_BuffScanner_AddValue(e, v2);
				elseif(i == 4 and v3) then
					SC_BuffScanner_AddValue(e, v3);
				elseif(i == 5 and v4) then
					SC_BuffScanner_AddValue(e, v4);
				else
					SC_BuffScanner_AddValue(e, value);
				end

			end
		end
	end
end;
