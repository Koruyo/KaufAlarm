local ADDON_NAME, ns = ...

local WARN_TEXT = "KAUF WASSER DU HUANSOHN!"
local PREFIX = "|cff3fa9ffKaufWasser|r: "
local SOUND_PATH = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Sounds\\"
local FALLBACK_SOUND = 416 -- Murloc, falls eine Sounddatei fehlt

-- Trichterwindentau ist erst ab Stufe 45 trinkbar, darunter wird nicht gewarnt.
local MIN_LEVEL = 45

-- Das beste Wasser. Alles hier (plus per /kw add ergänzte Items) wird zusammengezählt.
local BEST_WATER = {
	[8766] = true, -- Trichterwindentau (Morning Glory Dew)
	[8079] = true, -- Herbeigezaubertes Kristallwasser (Magier, Rang 7)
	[8078] = true, -- Herbeigezaubertes Sprudelwasser (Magier, Rang 6, gleichwertig mit Trichterwindentau)
}

-- Klassen ohne Mana brauchen kein Wasser.
local NO_MANA = { WARRIOR = true, ROGUE = true, DEATHKNIGHT = true }

local DEFAULTS = {
	threshold = 40,
	fontSize = 64,
	showInCombat = false,
	sound = true,
	soundInterval = 60,
	point = "CENTER",
	relPoint = "CENTER",
	x = 0,
	y = 160,
	extraItems = {},
}

local GetItemCount = (C_Item and C_Item.GetItemCount) or GetItemCount

local db
local inCombat = false
local testMode = false
local unlocked = false
local alarmActive = false
local lastSound = -math.huge
local lastSoundIndex
local optionsPanel
local optionsCategory
local optionWidgets = {}

local function Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. msg)
end

--------------------------------------------------------------------------------
-- Zählen
--------------------------------------------------------------------------------

local function CountWater()
	local total = 0
	for id in pairs(BEST_WATER) do
		total = total + (GetItemCount(id) or 0)
	end
	for id in pairs(db.extraItems) do
		if not BEST_WATER[id] then
			total = total + (GetItemCount(id) or 0)
		end
	end
	return total
end
ns.CountWater = CountWater

local function IsEligible()
	local _, class = UnitClass("player")
	return not NO_MANA[class] and (UnitLevel("player") or 0) >= MIN_LEVEL
end
ns.IsEligible = IsEligible

--------------------------------------------------------------------------------
-- Sound
--------------------------------------------------------------------------------

local function PlayRandomSound()
	lastSound = GetTime()
	local list = ns.sounds or {}
	local n = #list
	if n == 0 then
		PlaySound(FALLBACK_SOUND, "Master")
		return
	end
	local index = math.random(n)
	if n > 1 and index == lastSoundIndex then
		index = index % n + 1 -- nie zweimal hintereinander derselbe
	end
	lastSoundIndex = index

	local entry = list[index]
	if type(entry) == "number" then
		PlaySound(entry, "Master")
	elseif not PlaySoundFile(SOUND_PATH .. entry, "Master") then
		PlaySound(FALLBACK_SOUND, "Master")
	end
end

--------------------------------------------------------------------------------
-- Warnung auf dem Bildschirm
--------------------------------------------------------------------------------

local warn = CreateFrame("Frame", "KaufWasserWarnung", UIParent)
warn:SetFrameStrata("HIGH")
warn:SetClampedToScreen(true)
warn:SetMovable(true)
warn:RegisterForDrag("LeftButton")
warn:Hide()

local dragBackground = warn:CreateTexture(nil, "BACKGROUND")
dragBackground:SetAllPoints()
dragBackground:SetColorTexture(0, 0.6, 1, 0.3)
dragBackground:Hide()

local text = warn:CreateFontString(nil, "OVERLAY")
text:SetFont(STANDARD_TEXT_FONT, DEFAULTS.fontSize, "THICKOUTLINE")
text:SetPoint("TOP", warn, "TOP", 0, 0)
text:SetTextColor(1, 0.1, 0.1)
text:SetText(WARN_TEXT)

local sub = warn:CreateFontString(nil, "OVERLAY")
sub:SetFont(STANDARD_TEXT_FONT, 20, "OUTLINE")
sub:SetPoint("TOP", text, "BOTTOM", 0, -6)
sub:SetTextColor(1, 0.85, 0.2)

local pulse = warn:CreateAnimationGroup()
pulse:SetLooping("BOUNCE")
local fade = pulse:CreateAnimation("Alpha")
fade:SetFromAlpha(1)
fade:SetToAlpha(0.3)
fade:SetDuration(0.5)
fade:SetSmoothing("IN_OUT")

warn:SetScript("OnShow", function() pulse:Play() end)
warn:SetScript("OnHide", function() pulse:Stop() end)

-- Läuft nur, solange die Warnung sichtbar ist.
warn:SetScript("OnUpdate", function()
	if alarmActive and db.sound and GetTime() - lastSound >= db.soundInterval then
		PlayRandomSound()
	end
end)

warn:SetScript("OnDragStart", function(self)
	if unlocked then self:StartMoving() end
end)
warn:SetScript("OnDragStop", function(self)
	self:StopMovingOrSizing()
	local point, _, relPoint, x, y = self:GetPoint()
	db.point, db.relPoint, db.x, db.y = point, relPoint, x, y
end)

local function ApplyLayout()
	local subSize = math.max(12, math.floor(db.fontSize / 3 + 0.5))
	text:SetFont(STANDARD_TEXT_FONT, db.fontSize, "THICKOUTLINE")
	text:SetText(WARN_TEXT)
	sub:SetFont(STANDARD_TEXT_FONT, subSize, "OUTLINE")
	warn:SetSize(math.max(200, text:GetStringWidth()), db.fontSize + subSize + 16)
	warn:ClearAllPoints()
	warn:SetPoint(db.point, UIParent, db.relPoint, db.x, db.y)
end

local RefreshOptions -- unten bei den Optionen

local function Update()
	if not db then return end
	local count = CountWater()
	local low = IsEligible() and count < db.threshold
	alarmActive = low and (db.showInCombat or not inCombat)

	if unlocked then
		sub:SetText("Ziehen zum Verschieben, /kw move zum Fixieren")
	else
		sub:SetFormattedText("Nur noch %d Wasser (Grenze: %d)", count, db.threshold)
	end
	dragBackground:SetShown(unlocked)
	warn:EnableMouse(unlocked)
	warn:SetShown(alarmActive or testMode or unlocked)

	if ns.Minimap then ns.Minimap.Refresh(count, low) end
	if optionsPanel and optionsPanel:IsShown() then RefreshOptions() end
end

local function RunTest()
	testMode = true
	Update()
	if db.sound then PlayRandomSound() end
	C_Timer.After(6, function()
		testMode = false
		Update()
	end)
end
ns.RunTest = RunTest

local function SetUnlocked(value)
	unlocked = value
	Update()
	Print(unlocked and "Position entsperrt, Text mit der Maus ziehen." or "Position fixiert.")
end

local function ResetPosition()
	db.point, db.relPoint, db.x, db.y = DEFAULTS.point, DEFAULTS.relPoint, DEFAULTS.x, DEFAULTS.y
	ApplyLayout()
	Print("Position zurückgesetzt.")
end

local function ToggleSound()
	db.sound = not db.sound
	Print("Sound " .. (db.sound and "an." or "aus."))
	Update()
end
ns.ToggleSound = ToggleSound

--------------------------------------------------------------------------------
-- Optionen
--------------------------------------------------------------------------------

function RefreshOptions()
	for _, widget in ipairs(optionWidgets) do
		widget:Refresh()
	end
end

local function AddHeader(panel, label, y)
	local header = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	header:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, y)
	header:SetText(label)
	local line = panel:CreateTexture(nil, "ARTWORK")
	line:SetColorTexture(1, 0.82, 0, 0.25)
	line:SetHeight(1)
	line:SetPoint("LEFT", header, "RIGHT", 8, 0)
	line:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
end

local function AddSlider(panel, key, label, x, y, minimum, maximum, step, suffix)
	local name = "KaufWasserSlider_" .. key
	local slider = CreateFrame("Slider", name, panel, "OptionsSliderTemplate")
	slider:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
	slider:SetSize(250, 17)
	slider:SetMinMaxValues(minimum, maximum)
	slider:SetValueStep(step)
	if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
	for _, part in ipairs({ "Low", "High", "Text" }) do
		local region = slider[part] or _G[name .. part]
		if type(region) == "table" and region.SetText then region:SetText("") end
	end

	local caption = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	caption:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 0, 4)
	local function show(value) caption:SetText(label .. ": " .. value .. (suffix or "")) end

	slider:SetScript("OnValueChanged", function(self, value)
		if self.refreshing then return end
		value = math.floor(value / step + 0.5) * step
		show(value)
		if value ~= db[key] then
			db[key] = value
			ApplyLayout()
			Update()
		end
	end)
	slider.Refresh = function(self)
		self.refreshing = true
		self:SetValue(db[key])
		self.refreshing = false
		show(db[key])
	end
	optionWidgets[#optionWidgets + 1] = slider
	return slider
end

local function AddCheckbox(panel, label, x, y, get, set)
	local box = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
	box:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
	box:SetSize(26, 26)
	local caption = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	caption:SetPoint("LEFT", box, "RIGHT", 4, 0)
	caption:SetText(label)
	box:SetScript("OnClick", function(self)
		set(self:GetChecked() and true or false)
		Update()
	end)
	box.Refresh = function(self) self:SetChecked(get()) end
	optionWidgets[#optionWidgets + 1] = box
	return box
end

local function AddDbCheckbox(panel, key, label, x, y)
	return AddCheckbox(panel, label, x, y,
		function() return db[key] end,
		function(value) db[key] = value end)
end

local function AddButton(panel, label, x, y, onClick)
	local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	button:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
	button:SetSize(170, 24)
	button:SetText(label)
	button:SetScript("OnClick", onClick)
	return button
end

local function BuildOptions()
	local panel = CreateFrame("Frame", "KaufWasserOptionen")
	panel:Hide() -- ohne Elternfenster gälte es sonst als sichtbar
	panel.name = "KaufWasser"
	optionsPanel = panel

	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText("|cff3fa9ffKauf|rWasser")

	local info = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	info:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
	info:SetText("Warnt, wenn weniger Trichterwindentau bzw. Magierwasser im Gepäck ist als die Grenze.")

	local status = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	status:SetPoint("TOPLEFT", info, "BOTTOMLEFT", 0, -8)
	status.Refresh = function(self)
		local count = CountWater()
		local color = count < db.threshold and "ff3333" or "4dff4d"
		local note = IsEligible() and "" or "  |cff999999(dieser Charakter wird nicht gewarnt)|r"
		self:SetText(("Im Gepäck: |cff%s%d Wasser|r%s"):format(color, count, note))
	end
	optionWidgets[#optionWidgets + 1] = status

	AddHeader(panel, "Warnung", -100)
	AddSlider(panel, "threshold", "Grenze", 22, -140, 1, 200, 1, " Wasser")
	AddSlider(panel, "fontSize", "Schriftgröße", 312, -140, 20, 120, 2)
	AddDbCheckbox(panel, "showInCombat", "Auch im Kampf anzeigen", 18, -168)

	AddHeader(panel, "Sound", -212)
	AddDbCheckbox(panel, "sound", "Sound abspielen, solange die Warnung sichtbar ist", 18, -230)
	AddSlider(panel, "soundInterval", "Sound alle", 22, -282, 10, 300, 10, " Sekunden")
	AddButton(panel, "Zufälligen Sound spielen", 312, -278, PlayRandomSound)

	AddHeader(panel, "Anzeige", -322)
	AddCheckbox(panel, "Knopf an der Minimap", 18, -340,
		function() return ns.Minimap.IsShown() end,
		function(value) ns.Minimap.SetShown(value) end)
	AddButton(panel, "Warnung testen", 20, -378, RunTest)
	AddButton(panel, "Verschieben an/aus", 200, -378, function() SetUnlocked(not unlocked) end)
	AddButton(panel, "Position zurücksetzen", 380, -378, ResetPosition)

	local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	hint:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -420)
	hint:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
	hint:SetJustifyH("LEFT")
	hint:SetText("Titan Panel, ChocolateBar, Bazooka, ElvUI und andere Broker-Leisten zeigen den Eintrag "
		.. "\"KaufWasser\" mit der Zahl deiner Wasser. Weitere Befehle: /kw help")

	panel:SetScript("OnShow", RefreshOptions)

	if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
		local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, panel, panel.name)
		if ok and category then
			pcall(Settings.RegisterAddOnCategory, category)
			optionsCategory = category
		end
	elseif InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(panel)
	end
end

local function ToggleOptions()
	local frame = SettingsPanel or InterfaceOptionsFrame
	if optionsPanel and optionsPanel:IsVisible() and frame and frame:IsShown() then
		if HideUIPanel then HideUIPanel(frame) else frame:Hide() end
		return
	end
	if optionsCategory and Settings and Settings.OpenToCategory then
		local id = optionsCategory.GetID and optionsCategory:GetID() or optionsCategory.ID
		if pcall(Settings.OpenToCategory, id) then return end
	end
	if InterfaceOptionsFrame_OpenToCategory and optionsPanel then
		-- zweimal: der erste Aufruf landet bei manchen Clients auf der falschen Seite
		InterfaceOptionsFrame_OpenToCategory(optionsPanel)
		InterfaceOptionsFrame_OpenToCategory(optionsPanel)
	end
end
ns.ToggleOptions = ToggleOptions

--------------------------------------------------------------------------------
-- Slash-Befehle
--------------------------------------------------------------------------------

local function PrintHelp()
	Print("Befehle:")
	Print("  /kw - Optionen öffnen")
	Print("  /kw 40 - Grenze setzen")
	Print("  /kw test - Warnung und Sound testen")
	Print("  /kw move - Position ent-/sperren, /kw reset - Position zurücksetzen")
	Print("  /kw size 64 - Schriftgröße")
	Print("  /kw sound - Sound an/aus")
	Print("  /kw combat - Anzeige im Kampf an/aus")
	Print("  /kw minimap - Knopf an der Minimap an/aus")
	Print("  /kw add [Item] / remove [Item] - weiteres Wasser mitzählen")
	Print("  /kw status - aktueller Stand")
end

local function ParseItemID(arg)
	return tonumber(arg:match("item:(%d+)") or arg:match("^(%d+)$"))
end

SLASH_KAUFWASSER1 = "/kw"
SLASH_KAUFWASSER2 = "/kaufwasser"
SlashCmdList.KAUFWASSER = function(msg)
	msg = (msg or ""):match("^%s*(.-)%s*$")
	local cmd, arg = msg:match("^(%S*)%s*(.*)$")
	cmd = cmd:lower()

	if cmd == "" or cmd == "options" or cmd == "config" then
		ToggleOptions()
	elseif tonumber(cmd) then
		db.threshold = math.max(1, math.floor(tonumber(cmd)))
		Print("Grenze: " .. db.threshold .. " Wasser.")
	elseif cmd == "test" then
		RunTest()
	elseif cmd == "move" or cmd == "lock" or cmd == "unlock" then
		SetUnlocked(not unlocked)
	elseif cmd == "reset" then
		ResetPosition()
	elseif cmd == "size" and tonumber(arg) then
		db.fontSize = math.min(120, math.max(20, math.floor(tonumber(arg))))
		ApplyLayout()
		Print("Schriftgröße: " .. db.fontSize)
	elseif cmd == "sound" then
		ToggleSound()
	elseif cmd == "combat" then
		db.showInCombat = not db.showInCombat
		Print("Anzeige im Kampf " .. (db.showInCombat and "an." or "aus."))
	elseif cmd == "minimap" then
		local show = not ns.Minimap.IsShown()
		ns.Minimap.SetShown(show)
		Print("Knopf an der Minimap " .. (show and "an." or "aus."))
	elseif cmd == "add" or cmd == "remove" then
		local id = ParseItemID(arg)
		if not id then
			Print("Item-Link (Shift-Klick) oder Item-ID angeben, z. B. /kw add 8766")
		elseif cmd == "add" then
			db.extraItems[id] = true
			Print("Item " .. id .. " wird mitgezählt.")
		elseif BEST_WATER[id] then
			Print("Item " .. id .. " ist fest eingebaut und bleibt.")
		else
			db.extraItems[id] = nil
			Print("Item " .. id .. " wird nicht mehr mitgezählt.")
		end
	elseif cmd == "status" then
		Print(("%d Wasser im Gepäck, Grenze %d."):format(CountWater(), db.threshold))
		if not IsEligible() then
			Print("Dieser Charakter wird nicht gewarnt (kein Mana oder unter Stufe " .. MIN_LEVEL .. ").")
		end
	else
		PrintHelp()
	end

	Update()
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("BAG_UPDATE_DELAYED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_LEVEL_UP")

events:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 ~= ADDON_NAME then return end
		KaufWasserDB = KaufWasserDB or {}
		db = KaufWasserDB
		ns.db = db
		for key, value in pairs(DEFAULTS) do
			if db[key] == nil then
				db[key] = type(value) == "table" and {} or value
			end
		end
		ApplyLayout()
		BuildOptions()
	elseif event == "PLAYER_LOGIN" then
		-- Jetzt sind auch Titan Panel & Co. geladen, die LibDataBroker mitbringen.
		ns.Minimap.Init()
	elseif event == "PLAYER_ENTERING_WORLD" then
		inCombat = UnitAffectingCombat("player") and true or false
		-- Das Gepäck ist direkt beim Einloggen noch nicht geladen, sonst gäbe es Fehlalarm.
		C_Timer.After(3, Update)
	elseif event == "PLAYER_REGEN_DISABLED" then
		inCombat = true
		Update()
	elseif event == "PLAYER_REGEN_ENABLED" then
		inCombat = false
		Update()
	elseif event == "PLAYER_LEVEL_UP" then
		C_Timer.After(1, Update)
	else
		Update()
	end
end)
