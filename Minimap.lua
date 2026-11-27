-- KaufAlarm: Knopf an der Minimap und Eintrag in Broker-Leisten
--
-- Linksklick öffnet die Optionen, Rechtsklick schaltet den Sound an und aus.
--
-- Ist LibDataBroker geladen (Titan Panel, ChocolateBar, Bazooka, ElvUI und viele
-- andere bringen es mit), meldet sich das Addon dort an. Die Leisten zeigen dann
-- die Vorräte jedes Alarms, rot sobald einer unter der Grenze ist.
-- Ist außerdem LibDBIcon geladen, übernimmt es den Knopf an der Minimap; dann
-- sammeln ihn auch Minimap-Addons ein. Ohne LibDBIcon zeichnet das Addon einen
-- eigenen Knopf, der sich um die Minimap ziehen lässt.
local ADDON_NAME, ns = ...

local M = {}
ns.Minimap = M

local NAME = "KaufAlarm"
local ICON = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\icon"
local DEFAULT_ANGLE = 200

local settings -- db.minimap: hide, minimapPos (Winkel in Grad), wie bei LibDBIcon
local library -- LibDBIcon, falls vorhanden
local broker -- der Eintrag bei LibDataBroker, falls vorhanden
local button -- der eigene Knopf, falls nicht

local function icon()
	return ICON
end

local function version()
	local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
	if not get then return nil end
	local ok, value = pcall(get, ADDON_NAME, "Version")
	return ok and type(value) == "string" and value ~= "" and value or nil
end

-- "ownButton": Der Hinweis zum Ziehen gilt nur für den eigenen Knopf.
function M.FillTooltip(tooltip, ownButton)
	if not tooltip or not tooltip.AddLine or not ns.db then return end
	local number = version()
	tooltip:AddLine("|cff3fa9ffKauf|rAlarm" .. (number and (" |cff999999" .. number .. "|r") or ""))
	local any = false
	for _, entry in ipairs(ns.Status()) do
		if entry.eligible then
			any = true
			local r, g, b = 0.3, 1, 0.3
			if entry.low then r, g, b = 1, 0.2, 0.2 end
			local value = entry.watch.weaponBuff and (entry.detail ~= "" and entry.detail or "keine Waffe")
				or ("%d / %d"):format(entry.count, entry.watch.threshold)
			tooltip:AddDoubleLine(entry.watch.name, value, 1, 0.82, 0, r, g, b)
		end
	end
	if not any then
		tooltip:AddLine("Für diesen Charakter ist kein Alarm aktiv.", 0.7, 0.7, 0.7, true)
	end
	tooltip:AddDoubleLine("Sound", ns.db.sound and "an" or "aus", 1, 0.82, 0, 1, 1, 1)
	tooltip:AddLine(" ")
	tooltip:AddLine("Linksklick: Optionen", 1, 1, 1)
	tooltip:AddLine("Rechtsklick: Sound an/aus", 1, 1, 1)
	tooltip:AddLine("Shift-Klick: Warnung testen", 1, 1, 1)
	if ownButton == true then tooltip:AddLine("Ziehen: Knopf verschieben", 0.7, 0.7, 0.7) end
end

function M.OnClick(_, mouseButton)
	if IsShiftKeyDown and IsShiftKeyDown() then
		ns.RunTest()
	elseif mouseButton == "RightButton" then
		ns.ToggleSound()
	else
		ns.ToggleOptions()
	end
end

-- Stellt den eigenen Knopf auf seinen Winkel am Rand der Minimap.
local function place()
	local angle = math.rad(settings.minimapPos or DEFAULT_ANGLE)
	local x, y = math.cos(angle), math.sin(angle)
	local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
	if shape == "SQUARE" then
		-- bei einer eckigen Minimap am Rand des Quadrats entlang
		local scale = 1 / math.max(math.abs(x), math.abs(y), 0.01)
		x, y = x * scale, y * scale
	end
	local width = (Minimap:GetWidth() or 140) / 2 + 5
	local height = (Minimap:GetHeight() or 140) / 2 + 5
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", x * width, y * height)
end

-- Beim Ziehen folgt der Knopf dem Mauszeiger rund um die Minimap.
local function followCursor()
	local centerX, centerY = Minimap:GetCenter()
	local cursorX, cursorY = GetCursorPosition()
	local scale = Minimap:GetEffectiveScale() or 1
	if not centerX or not cursorX or scale == 0 then return end
	local angle = math.deg(math.atan2(cursorY / scale - centerY, cursorX / scale - centerX)) % 360
	settings.minimapPos = math.floor(angle + 0.5)
	place()
end

local function createButton()
	button = CreateFrame("Button", "KaufAlarmMinimapButton", Minimap)
	button:SetSize(31, 31)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(8)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:RegisterForDrag("LeftButton")
	button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	local background = button:CreateTexture(nil, "BACKGROUND")
	background:SetSize(20, 20)
	background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	background:SetPoint("TOPLEFT", button, "TOPLEFT", 7, -5)
	local texture = button:CreateTexture(nil, "ARTWORK")
	texture:SetSize(18, 18)
	texture:SetTexture(icon())
	texture:SetTexCoord(0.06, 0.94, 0.06, 0.94)
	texture:SetPoint("TOPLEFT", button, "TOPLEFT", 7, -6)
	button.icon = texture
	local border = button:CreateTexture(nil, "OVERLAY")
	border:SetSize(53, 53)
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
	button:SetScript("OnClick", M.OnClick)
	button:SetScript("OnDragStart", function(self)
		if GameTooltip then GameTooltip:Hide() end
		self:SetScript("OnUpdate", followCursor)
	end)
	button:SetScript("OnDragStop", function(self)
		self:SetScript("OnUpdate", nil)
		place()
	end)
	button:SetScript("OnEnter", function(self)
		if not GameTooltip then return end
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		M.FillTooltip(GameTooltip, true)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function()
		if GameTooltip then GameTooltip:Hide() end
	end)
	place()
end

-- Meldet das Addon bei LibDataBroker an. Broker-Leisten zeigen es dann
-- unabhängig vom Knopf an der Minimap.
local function registerBroker()
	if type(LibStub) ~= "table" and type(LibStub) ~= "function" then return false end
	local okBroker, ldb = pcall(LibStub, "LibDataBroker-1.1", true)
	if not (okBroker and ldb and ldb.NewDataObject) then return false end
	local ok, object = pcall(ldb.NewDataObject, ldb, NAME, {
		type = "data source",
		label = "KaufAlarm",
		text = "-",
		icon = icon(),
		OnClick = M.OnClick,
		OnTooltipShow = function(tooltip) M.FillTooltip(tooltip) end,
	})
	if not ok or not object then return false end
	broker = object
	return true
end

-- Meldet den Knopf bei LibDBIcon an. Schlägt das fehl, bleibt der eigene Weg.
local function registerWithLibrary()
	if not broker then return false end
	local okIcon, icons = pcall(LibStub, "LibDBIcon-1.0", true)
	if not (okIcon and icons and icons.Register) then return false end
	if not pcall(icons.Register, icons, NAME, broker, settings) then return false end
	library = icons
	return true
end

-- Aktualisiert die Zahlen in den Broker-Leisten, z. B. "37 · 1400".
function M.Refresh(status)
	if not broker then return end
	local parts = {}
	for _, entry in ipairs(status) do
		if entry.eligible then
			parts[#parts + 1] = (entry.low and "|cffff3333%d|r" or "%d"):format(entry.count)
		end
	end
	broker.text = #parts > 0 and table.concat(parts, " · ") or "-"
end

function M.IsShown()
	return settings ~= nil and not settings.hide
end

function M.SetShown(show)
	if not settings then return end
	settings.hide = not show
	if library then
		pcall(show and library.Show or library.Hide, library, NAME)
	else
		if show and not button and Minimap then createButton() end
		if button then button:SetShown(show) end
	end
end

-- Erst bei PLAYER_LOGIN aufrufen: Dann sind auch Addons geladen, die
-- LibDataBroker oder LibDBIcon mitbringen.
function M.Init()
	if settings or not ns.db then return end
	local db = ns.db
	db.minimap = type(db.minimap) == "table" and db.minimap or {}
	settings = db.minimap
	if type(settings.hide) ~= "boolean" then settings.hide = false end
	if type(settings.minimapPos) ~= "number" then settings.minimapPos = DEFAULT_ANGLE end
	registerBroker()
	if not registerWithLibrary() and not settings.hide and Minimap then createButton() end
end

-- für Tests
M.internals = {
	button = function() return button end,
	usesLibrary = function() return library ~= nil end,
	broker = function() return broker end,
}

-- Addon-Fach (das Menü unter dem Kalender bzw. an der Minimap)
function KaufAlarm_OnAddonCompartmentClick(_, mouseButton)
	M.OnClick(nil, mouseButton)
end

function KaufAlarm_OnAddonCompartmentEnter(_, anchor)
	if not GameTooltip then return end
	GameTooltip:SetOwner(type(anchor) == "table" and anchor or UIParent, "ANCHOR_LEFT")
	M.FillTooltip(GameTooltip)
	GameTooltip:Show()
end

function KaufAlarm_OnAddonCompartmentLeave()
	if GameTooltip then GameTooltip:Hide() end
end
