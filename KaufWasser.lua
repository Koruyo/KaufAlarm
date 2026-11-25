-- KaufWasser: Logik, Warnung auf dem Bildschirm, Sounds, Slash-Befehle
--
-- Jeder Alarm ("watch") zählt eine Liste von Items (und auf Wunsch die
-- ausgerüstete Munition) und warnt, sobald weniger als die Grenze im Gepäck ist.
local ADDON_NAME, ns = ...

local PREFIX = "|cff3fa9ffKaufWasser|r: "
local SOUND_PATH = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Sounds\\"
local FALLBACK_SOUND = 416 -- Murloc, falls eine Sounddatei fehlt
local AMMO_SLOT = INVSLOT_AMMO or 0

ns.CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local NO_MANA = { WARRIOR = true, ROGUE = true, DEATHKNIGHT = true }

-- Voreingestellte Alarme. Alles davon lässt sich in den Optionen ändern.
local function DefaultWatches()
	return {
		{
			name = "Wasser",
			enabled = true,
			text = "KAUF WASSER DU HUANSOHN!",
			threshold = 40,
			minLevel = 45, -- Trichterwindentau ist erst ab Stufe 45 trinkbar
			manaOnly = true,
			items = {
				[8766] = true, -- Trichterwindentau (Morning Glory Dew)
				[8079] = true, -- Herbeigezaubertes Kristallwasser (Magier, Rang 7)
				[8078] = true, -- Herbeigezaubertes Sprudelwasser (Magier, Rang 6)
			},
		},
		{
			name = "Munition",
			enabled = true,
			text = "KAUF MUNITION DU HUANSOHN!",
			threshold = 1000,
			minLevel = 10,
			ammo = true, -- zählt die ausgerüstete Munition, egal welche Sorte
			classes = { HUNTER = true },
			items = {},
		},
	}
end

function ns.NewWatch()
	return { name = "Neuer Alarm", enabled = true, text = "KAUF NACHSCHUB DU HUANSOHN!", threshold = 20, minLevel = 1, items = {} }
end

local DEFAULTS = {
	fontSize = 64,
	showInCombat = false,
	showDetails = true, -- kleine Zeile mit der Anzahl unter dem Warntext
	sound = true,
	soundInterval = 60,
	soundOrder = "random", -- "random" oder "sequence"
	soundChannel = "Master",
	disabledSounds = {}, -- abgewählte Sounds; neue Dateien sind so automatisch an
	point = "CENTER",
	relPoint = "CENTER",
	x = 0,
	y = 160,
}

local GetItemCount = (C_Item and C_Item.GetItemCount) or GetItemCount

local db
local inCombat = false
local testMode = false
local unlocked = false
local alarmActive = false
local lastSound = -math.huge
local lastSoundIndex

local function Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. msg)
end
ns.Print = Print

--------------------------------------------------------------------------------
-- Gespeicherte Einstellungen
--------------------------------------------------------------------------------

local function SetupDB()
	KaufWasserDB = type(KaufWasserDB) == "table" and KaufWasserDB or {}
	db = KaufWasserDB
	ns.db = db
	for key, value in pairs(DEFAULTS) do
		if db[key] == nil then
			db[key] = type(value) == "table" and {} or value
		end
	end
	if type(db.watches) ~= "table" then
		db.watches = DefaultWatches()
		-- Einstellungen aus Version 1.x übernehmen
		local water = db.watches[1]
		if type(db.threshold) == "number" then water.threshold = db.threshold end
		if type(db.extraItems) == "table" then
			for id in pairs(db.extraItems) do water.items[id] = true end
		end
	end
	db.threshold, db.extraItems = nil, nil
	for _, watch in ipairs(db.watches) do
		watch.items = type(watch.items) == "table" and watch.items or {}
		watch.threshold = tonumber(watch.threshold) or 1
		watch.minLevel = tonumber(watch.minLevel) or 1
	end
end

--------------------------------------------------------------------------------
-- Zählen
--------------------------------------------------------------------------------

local function CountWatch(watch)
	local total = 0
	for id in pairs(watch.items) do
		total = total + (GetItemCount(id) or 0)
	end
	if watch.ammo and GetInventoryItemID and GetInventoryItemID("player", AMMO_SLOT) then
		total = total + (GetInventoryItemCount("player", AMMO_SLOT) or 0)
	end
	return total
end
ns.CountWatch = CountWatch

-- Gilt der Alarm für diesen Charakter (Klasse, Stufe, aktiv)?
local function IsWatchEligible(watch)
	if not watch.enabled then return false end
	local _, class = UnitClass("player")
	if watch.manaOnly and NO_MANA[class] then return false end
	if type(watch.classes) == "table" and next(watch.classes) and not watch.classes[class] then return false end
	return (UnitLevel("player") or 0) >= (watch.minLevel or 1)
end
ns.IsWatchEligible = IsWatchEligible

-- Stand aller Alarme: { watch, count, eligible, low }
local function Status()
	local list = {}
	for _, watch in ipairs(db.watches) do
		local count = CountWatch(watch)
		local eligible = IsWatchEligible(watch)
		list[#list + 1] = { watch = watch, count = count, eligible = eligible, low = eligible and count < watch.threshold }
	end
	return list
end
ns.Status = Status

--------------------------------------------------------------------------------
-- Sound
--------------------------------------------------------------------------------

ns.CHANNELS = { "Master", "SFX", "Dialog", "Ambience", "Music" }
ns.CHANNEL_NAMES = { Master = "Gesamt", SFX = "Effekte", Dialog = "Dialog", Ambience = "Umgebung", Music = "Musik" }
ns.ORDER_NAMES = { random = "zufällig", sequence = "der Reihe nach" }

local function SoundKey(entry)
	return tostring(entry)
end

function ns.SoundLabel(entry)
	if type(entry) == "number" then
		return entry == 416 and "Murloc-Gurgeln (aus dem Spiel)" or ("Spiel-Sound " .. entry)
	end
	return (entry:gsub("%.[^.]+$", ""):gsub("[-_]+", " "))
end

function ns.IsSoundEnabled(entry)
	return not db.disabledSounds[SoundKey(entry)]
end

function ns.SetSoundEnabled(entry, enabled)
	db.disabledSounds[SoundKey(entry)] = (not enabled) or nil
end

local function PlayEntry(entry)
	local channel = db.soundChannel
	if type(entry) == "number" then
		PlaySound(entry, channel)
	elseif not PlaySoundFile(SOUND_PATH .. entry, channel) then
		PlaySound(FALLBACK_SOUND, channel)
	end
end
ns.PlayEntry = PlayEntry

-- Spielt einen der angehakten Sounds, zufällig oder der Reihe nach.
-- Gibt false zurück, wenn kein Sound angehakt ist.
local function PlayNextSound()
	lastSound = GetTime()
	local pool = {}
	for index, entry in ipairs(ns.sounds or {}) do
		if ns.IsSoundEnabled(entry) then pool[#pool + 1] = index end
	end
	local n = #pool
	if n == 0 then return false end

	local pick
	if db.soundOrder == "sequence" then
		pick = 1
		for i, index in ipairs(pool) do
			if lastSoundIndex and index > lastSoundIndex then pick = i break end
		end
	else
		pick = math.random(n)
		if n > 1 and pool[pick] == lastSoundIndex then
			pick = pick % n + 1 -- nie zweimal hintereinander derselbe
		end
	end
	lastSoundIndex = pool[pick]
	PlayEntry(ns.sounds[lastSoundIndex])
	return true
end
ns.PlayNextSound = PlayNextSound

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

local lines = {} -- eine große Zeile je Alarm, der gerade warnt
local sub = warn:CreateFontString(nil, "OVERLAY")
sub:SetTextColor(1, 0.85, 0.2)

local function Line(index)
	local line = lines[index]
	if not line then
		line = warn:CreateFontString(nil, "OVERLAY")
		line:SetTextColor(1, 0.1, 0.1)
		line:SetPoint("TOP", index == 1 and warn or lines[index - 1], index == 1 and "TOP" or "BOTTOM", 0, index == 1 and 0 or -4)
		lines[index] = line
	end
	line:SetFont(STANDARD_TEXT_FONT, db.fontSize, "THICKOUTLINE")
	return line
end

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
		PlayNextSound()
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

local function Position()
	warn:ClearAllPoints()
	warn:SetPoint(db.point, UIParent, db.relPoint, db.x, db.y)
end

-- Farben für den Warntext, in den Optionen durchschaltbar.
ns.COLORS = {
	{ key = "red", name = "Rot", r = 1, g = 0.1, b = 0.1 },
	{ key = "orange", name = "Orange", r = 1, g = 0.5, b = 0 },
	{ key = "yellow", name = "Gelb", r = 1, g = 0.9, b = 0.1 },
	{ key = "green", name = "Grün", r = 0.2, g = 1, b = 0.2 },
	{ key = "cyan", name = "Türkis", r = 0.2, g = 0.9, b = 1 },
	{ key = "blue", name = "Blau", r = 0.3, g = 0.5, b = 1 },
	{ key = "purple", name = "Lila", r = 0.8, g = 0.4, b = 1 },
	{ key = "pink", name = "Pink", r = 1, g = 0.4, b = 0.8 },
	{ key = "white", name = "Weiß", r = 1, g = 1, b = 1 },
}

function ns.WatchColor(watch)
	for _, color in ipairs(ns.COLORS) do
		if color.key == watch.color then return color end
	end
	return ns.COLORS[1]
end

-- Ersetzt {anzahl}, {grenze}, {fehlen} und {name} im Warntext.
function ns.FormatWarnText(watch, count)
	local values = {
		anzahl = count,
		grenze = watch.threshold,
		fehlen = math.max(0, watch.threshold - count),
		name = watch.name,
	}
	return ((watch.text or ""):gsub("{(%a+)}", function(key)
		local value = values[key:lower()]
		return value ~= nil and tostring(value) or nil
	end))
end

-- Füllt die Warnung mit den Texten der Alarme in "shown".
local function Render(shown, subText)
	local width = 200
	for i, entry in ipairs(shown) do
		local line = Line(i)
		local color = ns.WatchColor(entry.watch)
		line:SetTextColor(color.r, color.g, color.b)
		line:SetText(ns.FormatWarnText(entry.watch, entry.count))
		line:Show()
		width = math.max(width, line:GetStringWidth() or 0)
	end
	for i = #shown + 1, #lines do lines[i]:Hide() end

	local subSize = math.max(12, math.floor(db.fontSize / 3 + 0.5))
	sub:SetFont(STANDARD_TEXT_FONT, subSize, "OUTLINE")
	sub:ClearAllPoints()
	sub:SetPoint("TOP", lines[#shown] or warn, #shown > 0 and "BOTTOM" or "TOP", 0, -6)
	sub:SetText(subText)
	local subHeight = subText ~= "" and subSize + 6 or 0
	warn:SetSize(width, math.max(1, #shown) * (db.fontSize + 4) + subHeight + 10)
end

local function Update()
	if not db then return end
	local status = Status()
	local low = {}
	for _, entry in ipairs(status) do
		if entry.low then low[#low + 1] = entry end
	end
	alarmActive = #low > 0 and (db.showInCombat or not inCombat)

	local shown = alarmActive and low or {}
	if (testMode or unlocked) and #shown == 0 then
		for _, entry in ipairs(status) do
			if entry.watch.enabled then shown[#shown + 1] = entry end
		end
		if #shown == 0 and status[1] then shown[1] = status[1] end
	end

	local subText
	if unlocked then
		subText = "Ziehen zum Verschieben, /kw move zum Fixieren"
	elseif not db.showDetails then
		subText = ""
	else
		local parts = {}
		for _, entry in ipairs(shown) do
			parts[#parts + 1] = ("%s: %d / %d"):format(entry.watch.name, entry.count, entry.watch.threshold)
		end
		subText = table.concat(parts, "   ·   ")
	end

	Render(shown, subText)
	dragBackground:SetShown(unlocked)
	warn:EnableMouse(unlocked)
	warn:SetShown(alarmActive or testMode or unlocked)

	if ns.Minimap then ns.Minimap.Refresh(status) end
	if ns.RefreshOptions then ns.RefreshOptions() end
end
ns.Update = Update

function ns.ApplyLayout()
	Position()
	Update()
end

function ns.RunTest()
	testMode = true
	Update()
	if db.sound then PlayNextSound() end
	C_Timer.After(6, function()
		testMode = false
		Update()
	end)
end

function ns.ToggleUnlocked()
	unlocked = not unlocked
	Update()
	Print(unlocked and "Position entsperrt, Text mit der Maus ziehen." or "Position fixiert.")
end

function ns.ResetPosition()
	db.point, db.relPoint, db.x, db.y = DEFAULTS.point, DEFAULTS.relPoint, DEFAULTS.x, DEFAULTS.y
	Position()
	Print("Position zurückgesetzt.")
end

function ns.ToggleSound()
	db.sound = not db.sound
	Print("Sound " .. (db.sound and "an." or "aus."))
	Update()
end

--------------------------------------------------------------------------------
-- Slash-Befehle
--------------------------------------------------------------------------------

local function PrintHelp()
	Print("Befehle:")
	Print("  /kw - Optionen öffnen (Alarme, Items, Sounds)")
	Print("  /kw test - Warnung und Sound testen")
	Print("  /kw move - Position ent-/sperren, /kw reset - Position zurücksetzen")
	Print("  /kw sound - Sound an/aus")
	Print("  /kw combat - Anzeige im Kampf an/aus")
	Print("  /kw minimap - Knopf an der Minimap an/aus")
	Print("  /kw status - Stand aller Alarme")
end

SLASH_KAUFWASSER1 = "/kw"
SLASH_KAUFWASSER2 = "/kaufwasser"
SlashCmdList.KAUFWASSER = function(msg)
	local cmd = ((msg or ""):match("^%s*(%S*)") or ""):lower()

	if cmd == "" or cmd == "options" or cmd == "config" then
		ns.ToggleOptions()
	elseif cmd == "test" then
		ns.RunTest()
	elseif cmd == "move" or cmd == "lock" or cmd == "unlock" then
		ns.ToggleUnlocked()
	elseif cmd == "reset" then
		ns.ResetPosition()
	elseif cmd == "sound" then
		ns.ToggleSound()
	elseif cmd == "combat" then
		db.showInCombat = not db.showInCombat
		Print("Anzeige im Kampf " .. (db.showInCombat and "an." or "aus."))
	elseif cmd == "minimap" then
		local show = not ns.Minimap.IsShown()
		ns.Minimap.SetShown(show)
		Print("Knopf an der Minimap " .. (show and "an." or "aus."))
	elseif cmd == "status" then
		for _, entry in ipairs(Status()) do
			local note = entry.eligible and "" or " (gilt nicht für diesen Charakter)"
			Print(("%s: %d / %d%s"):format(entry.watch.name, entry.count, entry.watch.threshold, note))
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
events:RegisterEvent("UNIT_INVENTORY_CHANGED")
events:RegisterEvent("GET_ITEM_INFO_RECEIVED")

local ready = false -- erst nach dem Laden des Gepäcks zählen, sonst gäbe es Fehlalarm

events:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 ~= ADDON_NAME then return end
		SetupDB()
		Position()
		ns.BuildOptions()
	elseif event == "PLAYER_LOGIN" then
		-- Jetzt sind auch Titan Panel & Co. geladen, die LibDataBroker mitbringen.
		ns.Minimap.Init()
	elseif event == "PLAYER_ENTERING_WORLD" then
		inCombat = UnitAffectingCombat("player") and true or false
		C_Timer.After(3, function()
			ready = true
			Update()
		end)
	elseif not ready then
		return
	elseif event == "PLAYER_REGEN_DISABLED" then
		inCombat = true
		Update()
	elseif event == "PLAYER_REGEN_ENABLED" then
		inCombat = false
		Update()
	elseif event == "PLAYER_LEVEL_UP" then
		C_Timer.After(1, Update)
	elseif event == "UNIT_INVENTORY_CHANGED" then
		if arg1 == "player" then Update() end
	else
		Update()
	end
end)
