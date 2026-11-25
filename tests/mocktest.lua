-- Prüft die Logik des Addons mit einer nachgebauten WoW-API.
-- Aufruf aus dem Projektordner: luajit tests/mocktest.lua
local dir = arg[1] or "."

local function run(withBroker)
	local now, items, level, class = 100, {}, 60, "SHAMAN"
	local ammo = nil -- { id, count }
	local played, channels, timers, shift = {}, {}, {}, false

	local frames, named = {}, {}
	local function widget(parent)
		local w = { scripts = {}, shown = true, lines = {}, parent = parent }
		frames[#frames + 1] = w
		return setmetatable(w, { __index = function(_, k)
			if k == "SetScript" then return function(self, n, f) self.scripts[n] = f end end
			if k == "GetScript" then return function(self, n) return self.scripts[n] end end
			if k == "GetParent" then return function(self) return self.parent end end
			if k == "Show" then return function(self) self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end end
			if k == "Hide" then return function(self) self.shown = false end end
			if k == "SetShown" then return function(self, v) self.shown = v and true or false end end
			if k == "IsShown" or k == "IsVisible" then return function(self) return self.shown end end
			if k == "SetText" then return function(self, s) self.txt = s end end
			if k == "SetTextColor" then return function(self, r, g, b) self.rgb = r .. "," .. g .. "," .. b end end
			if k == "GetText" then return function(self) return self.txt end end
			if k == "SetFormattedText" then return function(self, f, ...) self.txt = f:format(...) end end
			if k == "HasFocus" then return function(self) return self.focus end end
			if k == "SetFocus" then return function(self) self.focus = true end end
			if k == "ClearFocus" then return function(self)
				local had = self.focus; self.focus = false
				if had and self.scripts.OnEditFocusLost then self.scripts.OnEditFocusLost(self) end
			end end
			if k == "AddLine" or k == "AddDoubleLine" then return function(self, a, b) self.lines[#self.lines + 1] = tostring(a) .. (b and (" " .. tostring(b)) or "") end end
			if k == "GetStringWidth" then return function() return 800 end end
			if k == "GetPoint" then return function() return "CENTER", nil, "CENTER", 5, 6 end end
			if k == "GetCenter" then return function() return 500, 500 end end
			if k == "GetEffectiveScale" then return function() return 1 end end
			if k == "SetChecked" then return function(self, v) self.checked = v end end
			if k == "GetChecked" then return function(self) return self.checked end end
			if k == "SetValue" then return function(self, v) self.value = v; if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, v) end end end
			if k:match("^Create") then return function(self) return widget(self) end end
			if k:match("^[A-Z]") then return function() end end
		end })
	end

	_G.KaufAlarmDB = nil
	function CreateFrame(kind, name, parent)
		local w = widget(parent); w.kind = kind
		if name then named[name] = w; _G[name] = w end
		return w
	end
	UIParent, Minimap, GameTooltip = widget(), widget(), widget()
	STANDARD_TEXT_FONT, SlashCmdList = "font", {}
	local chat = {}
	DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) chat[#chat + 1] = m end }
	function GetItemCount(id) return items[id] or 0 end
	function GetItemIcon() return 132794 end
	function GetItemInfo(id) if id == 8766 then return "Trichterwindentau" end end
	function GetInventoryItemID(_, slot) assert(slot == 0); return ammo and ammo[1] end
	function GetInventoryItemCount(_, slot) assert(slot == 0); return ammo and ammo[2] or 0 end
	function UnitClass() return "x", class end
	function UnitLevel() return level end
	function UnitAffectingCombat() return false end
	function GetTime() return now end
	function GetCursorPosition() return 400, 500 end -- links von der Minimap: 180 Grad
	function IsShiftKeyDown() return shift end
	function PlaySound(id, ch) played[#played + 1] = id; channels[#channels + 1] = ch end
	function PlaySoundFile(p, ch) played[#played + 1] = p; channels[#channels + 1] = ch; return true end
	C_Timer = { After = function(_, f) timers[#timers + 1] = f end }
	local popup
	function StaticPopup_Show(which, arg) popup = { which = which, arg = arg } end
	StaticPopupDialogs = nil
	local hooks = {}
	function ChatEdit_InsertLink() end
	function hooksecurefunc(name, f) hooks[name] = f end

	local opened = {}
	SettingsPanel = widget(); SettingsPanel.shown = false
	function HideUIPanel(f) f.shown = false end
	local nextId = 0
	local function category(page)
		nextId = nextId + 1
		local id = nextId
		return { page = page, GetID = function() return id end }
	end
	local categories = {}
	Settings = {
		RegisterCanvasLayoutCategory = function(page) local c = category(page); categories[c:GetID()] = c; return c end,
		RegisterCanvasLayoutSubcategory = function(_, page) local c = category(page); categories[c:GetID()] = c; return c end,
		RegisterAddOnCategory = function() end,
		OpenToCategory = function(id) opened[#opened + 1] = categories[id].page.name end,
	}

	local ldbObjects, iconRegistered = {}, nil
	if withBroker then
		local libs = {
			["LibDataBroker-1.1"] = { NewDataObject = function(_, name, obj) ldbObjects[name] = obj; return obj end },
			["LibDBIcon-1.0"] = {
				Register = function(_, name, obj, s) iconRegistered = { name = name, obj = obj, settings = s } end,
				Show = function() iconRegistered.settings.hide = false end,
				Hide = function() iconRegistered.settings.hide = true end,
			},
		}
		LibStub = setmetatable({}, { __call = function(_, name) return libs[name] end })
	else
		LibStub = nil
	end

	local ns = {}
	for _, file in ipairs({ "Sounds.lua", "Minimap.lua", "KaufAlarm.lua", "Options.lua" }) do
		assert(loadfile(dir .. "/" .. file))("KaufAlarm", ns)
	end

	local ev
	for _, f in ipairs(frames) do if f.scripts.OnEvent then ev = f end end
	local warn = named.KaufAlarmWarnung
	local function fire(e, a) ev.scripts.OnEvent(ev, e, a) end
	local function runTimers() local t = timers; timers = {}; for _, f in ipairs(t) do f() end end
	local function tick() if warn.shown then warn.scripts.OnUpdate(warn, 0.1) end end
	local function check(cond, msg)
		print((cond and "ok   " or "FAIL ") .. (withBroker and "[Broker] " or "[ohne]   ") .. msg)
		if not cond then os.exit(1) end
	end
	local function warnText()
		local parts = {}
		for _, f in ipairs(frames) do
			if f.parent == warn and f.shown and f.txt and f.txt:find("HUANSOHN") then parts[#parts + 1] = f.txt end
		end
		return table.concat(parts, "|")
	end
	-- Steuerelemente in einer Options-Seite über ihre Beschriftung finden
	local function find(page, label)
		for _, f in ipairs(frames) do
			local p = f
			while p and p ~= page do p = p.parent end
			if p == page and f.kind and (f.txt == label or (f.caption and f.caption.txt == label)) then return f end
		end
		error("nicht gefunden: " .. label)
	end
	local function click(f, mouse) f.scripts.OnClick(f, mouse or "LeftButton") end
	local function type_(box, text) box.focus = true; box.txt = text; box:ClearFocus() end

	fire("ADDON_LOADED", "KaufAlarm"); fire("PLAYER_LOGIN"); fire("PLAYER_ENTERING_WORLD")
	fire("BAG_UPDATE_DELAYED")
	check(not warn.shown, "vor dem Laden des Gepäcks keine Warnung")
	check(#KaufAlarmDB.watches == 2, "Standard: Alarme Wasser und Munition")
	items[8766] = 39; runTimers(); tick()
	check(warn.shown and warnText() == "KAUF WASSER DU HUANSOHN!", "39 Trichterwindentau -> Wasser-Warnung")
	check(#played == 1 and channels[1] == "Master", "Sound sofort beim Erscheinen")
	tick(); check(#played == 1, "kein zweiter Sound in derselben Minute")
	now = now + 61; tick(); check(#played == 2 and played[1] ~= played[2], "nach 60 s anderer Sound")
	items[8766] = 20; items[8079] = 20; fire("BAG_UPDATE_DELAYED")
	check(not warn.shown, "20 Tau + 20 Magierwasser = 40 -> keine Warnung")
	fire("PLAYER_REGEN_DISABLED"); items[8079] = 0; fire("BAG_UPDATE_DELAYED")
	check(not warn.shown, "im Kampf versteckt")
	fire("PLAYER_REGEN_ENABLED"); check(warn.shown, "nach dem Kampf wieder da")

	-- Munition für Jäger
	check(not warnText():find("MUNITION"), "Schamane bekommt keine Munitions-Warnung")
	class = "HUNTER"; ammo = { 18042, 400 }; fire("UNIT_INVENTORY_CHANGED", "player")
	check(warnText() == "KAUF WASSER DU HUANSOHN!|KAUF MUNITION DU HUANSOHN!", "Jäger mit 400 Pfeilen: beide Warnungen")
	ammo = { 18042, 1600 }; items[8766] = 50; fire("BAG_UPDATE_DELAYED")
	check(not warn.shown, "Jäger mit 1600 Pfeilen und 50 Wasser: keine Warnung")
	ammo = nil; fire("UNIT_INVENTORY_CHANGED", "player")
	check(warnText() == "KAUF MUNITION DU HUANSOHN!", "keine Munition ausgerüstet -> Warnung")
	ammo = { 18042, 1600 }; class = "SHAMAN"; fire("BAG_UPDATE_DELAYED")

	-- Minimap, Broker, Addon-Fach
	local button = ns.Minimap.internals.button()
	if withBroker then
		local obj = ldbObjects.KaufAlarm
		check(obj and obj.type == "data source", "Broker-Eintrag für Titan Panel & Co. angelegt")
		check(obj.icon == "Interface\\AddOns\\KaufAlarm\\Media\\icon", "eigenes Icon im Broker-Eintrag")
		check(obj.text == "50", "Broker zeigt den Wasser-Stand des Schamanen")
		class = "HUNTER"; ammo = { 18042, 300 }; fire("BAG_UPDATE_DELAYED")
		check(obj.text == "50 · |cffff3333300|r", "Broker beim Jäger: Wasser und Munition, Munition rot")
		local tip = widget(); obj.OnTooltipShow(tip)
		check(table.concat(tip.lines, "|"):find("Munition 300 / 1000", 1, true), "Broker-Tooltip zeigt den Stand")
		class = "SHAMAN"; fire("BAG_UPDATE_DELAYED")
		check(iconRegistered and iconRegistered.settings == KaufAlarmDB.minimap, "Knopf läuft über LibDBIcon")
		check(button == nil, "kein eigener Knopf neben LibDBIcon")
		obj.OnClick(nil, "LeftButton"); check(opened[#opened] == "KaufAlarm", "Broker-Linksklick öffnet Optionen")
		ns.Minimap.SetShown(false); check(KaufAlarmDB.minimap.hide == true, "Minimap-Knopf über LibDBIcon ausblendbar")
		ns.Minimap.SetShown(true)
	else
		check(button and button.shown, "eigener Minimap-Knopf ohne Bibliotheken")
		button.scripts.OnDragStart(button); button.scripts.OnUpdate(button)
		button.scripts.OnDragStop(button)
		check(KaufAlarmDB.minimap.minimapPos == 180, "Knopf lässt sich um die Minimap ziehen")
		button.scripts.OnEnter(button)
		check(table.concat(GameTooltip.lines, "|"):find("Wasser 50 / 40", 1, true), "Tooltip am Knopf zeigt Stand")
		button.scripts.OnClick(button, "LeftButton"); check(opened[#opened] == "KaufAlarm", "Linksklick öffnet Optionen")
		SlashCmdList.KAUFALARM("minimap"); check(not button.shown and KaufAlarmDB.minimap.hide, "/ka minimap blendet aus")
		SlashCmdList.KAUFALARM("minimap"); check(button.shown, "/ka minimap blendet wieder ein")
	end
	ns.Minimap.OnClick(nil, "RightButton"); check(KaufAlarmDB.sound == false, "Rechtsklick schaltet Sound aus")
	KaufAlarm_OnAddonCompartmentClick(nil, "RightButton"); check(KaufAlarmDB.sound == true, "Addon-Fach: Rechtsklick Sound an")
	KaufAlarm_OnAddonCompartmentEnter(nil, widget()); KaufAlarm_OnAddonCompartmentLeave()
	shift = true; local n = #played; ns.Minimap.OnClick(nil, "LeftButton"); shift = false
	check(#played == n + 1 and warn.shown, "Shift-Klick testet Warnung + Sound"); runTimers()
	check(not warn.shown, "Test endet wieder")

	-- Optionen: Hauptseite
	local pages = ns.optionPages
	check(not pages.main.shown and not pages.alarms.shown, "Options-Seiten starten versteckt")
	pages.main.shown = true; SettingsPanel.shown = true; pages.main.scripts.OnShow(pages.main)
	SlashCmdList.KAUFALARM(""); check(not SettingsPanel.shown, "/ka bei offenen Optionen schließt sie")
	pages.main.shown = false; SlashCmdList.KAUFALARM(""); check(opened[#opened] == "KaufAlarm", "/ka öffnet die Optionen")
	pages.main.shown = true
	click(find(pages.main, "Alarme bearbeiten")); check(opened[#opened] == "Alarme", "Knopf springt zur Seite Alarme")
	local order = find(pages.main, "Reihenfolge: zufällig"); click(order)
	check(KaufAlarmDB.soundOrder == "sequence" and order.txt == "Reihenfolge: der Reihe nach", "Reihenfolge umschaltbar")
	local channel = find(pages.main, "Lautstärke-Regler: Gesamt"); click(channel)
	check(KaufAlarmDB.soundChannel == "SFX", "Lautstärke-Regler umschaltbar")
	local interval = find(pages.main, "Wiederholen alle: 60 Sekunden")
	interval:SetValue(120); check(KaufAlarmDB.soundInterval == 120, "Wiederholrate per Regler")
	pages.main.shown = false

	-- Sounds: Auswahl und Reihenfolge
	local sounds = pages.sounds
	sounds.shown = true; sounds.scripts.OnShow(sounds)
	click(find(sounds, "Alle aus"))
	check(not ns.PlayNextSound(), "alle Sounds aus -> nichts spielt")
	for i, entry in ipairs(ns.sounds) do
		if i == 2 or i == 4 then ns.SetSoundEnabled(entry, true) end
	end
	local seq = {}
	for _ = 1, 4 do ns.PlayNextSound(); seq[#seq + 1] = played[#played] end
	local base = "Interface\\AddOns\\KaufAlarm\\Sounds\\"
	local a, b = base .. ns.sounds[2], base .. ns.sounds[4]
	check((seq[1] == a or seq[1] == b) and (seq[2] == a or seq[2] == b) and seq[1] ~= seq[2]
		and seq[3] == seq[1] and seq[4] == seq[2], "der Reihe nach, nur angehakte Sounds, abwechselnd")
	check(channels[#channels] == "SFX", "Sound läuft über den gewählten Regler")
	click(find(sounds, "Alle an")); sounds.shown = false

	-- Alarme bearbeiten
	local alarms = pages.alarms
	alarms.shown = true; alarms.scripts.OnShow(alarms)
	local threshold = find(alarms, "Warnen unter")
	check(threshold.txt == "40", "Seite zeigt Grenze des Wasser-Alarms")
	type_(threshold, "60"); check(KaufAlarmDB.watches[1].threshold == 60 and warn.shown, "Grenze 60 per Eingabe -> Warnung")
	local add = named.KaufAlarmItemEingabe
	add.focus = true; hooks.ChatEdit_InsertLink("|cffffffff|Hitem:1645::::|h[Mondbeerensaft]|h|r")
	check(add.txt:find("item:1645"), "Shift-Klick schreibt Item-Link ins Feld")
	add.scripts.OnEnterPressed(add)
	items[1645] = 20; fire("BAG_UPDATE_DELAYED")
	check(KaufAlarmDB.watches[1].items[1645] and not warn.shown, "Mondbeerensaft zählt mit (50 + 20 >= 60)")
	add.txt = "Trichterwindentau"; add.scripts.OnEnterPressed(add)
	check(KaufAlarmDB.watches[1].items[8766], "Item per Name aus dem Cache")
	-- Magierwasser entfernen
	local removed = false
	for _, f in ipairs(frames) do
		if f.txt == "Entfernen" and f.parent.id == 8079 and f.parent.shown then click(f); removed = true break end
	end
	check(removed and not KaufAlarmDB.watches[1].items[8079], "Item lässt sich entfernen")
	click(find(alarms, ">")); check(find(alarms, "Warnen unter").txt == "1000", "zweiter Alarm: Munition")
	click(find(alarms, "Neuer Alarm"))
	check(#KaufAlarmDB.watches == 3, "neuer Alarm angelegt")
	type_(find(alarms, "Name"), "Seelensplitter")
	type_(find(alarms, "Warntext"), "NUR NOCH {anzahl} {name}, {fehlen} FEHLEN BIS {grenze}! {quatsch}")
	type_(find(alarms, "Warnen unter"), "5")
	click(find(alarms, "Nur Klassen mit Mana")) -- an
	local lock = find(alarms, "WARLOCK"); lock.checked = true; click(lock)
	local color = find(alarms, "Textfarbe: Rot"); click(color); click(color)
	check(KaufAlarmDB.watches[3].color == "yellow" and color.txt == "Textfarbe: Gelb", "Textfarbe umschaltbar")
	add.txt = "6265"; add.scripts.OnEnterPressed(add)
	class = "WARLOCK"; items[6265] = 2; fire("BAG_UPDATE_DELAYED")
	local expected = "NUR NOCH 2 Seelensplitter, 3 FEHLEN BIS 5! {quatsch}"
	local line
	for _, f in ipairs(frames) do if f.parent == warn and f.shown and f.txt == expected then line = f end end
	check(line, "Platzhalter im Warntext werden ersetzt")
	check(line and line.rgb == "1,0.9,0.1", "Warntext in der gewählten Farbe")
	local previewOk = false
	for _, f in ipairs(frames) do if f.parent == alarms and f.txt == expected then previewOk = true end end
	check(previewOk, "Vorschau in den Optionen zeigt den fertigen Text")
	local function detailShown()
		for _, f in ipairs(frames) do
			if f.parent == warn and type(f.txt) == "string" and f.txt:find("Seelensplitter: 2 / 5", 1, true) then return true end
		end
		return false
	end
	check(detailShown(), "Zeile mit der Anzahl unter dem Warntext")
	KaufAlarmDB.showDetails = false; fire("BAG_UPDATE_DELAYED")
	check(not detailShown(), "Zeile mit der Anzahl lässt sich ausblenden")
	KaufAlarmDB.showDetails = true
	class = "MAGE"; fire("BAG_UPDATE_DELAYED")
	line = nil
	for _, f in ipairs(frames) do if f.parent == warn and f.shown and f.txt == expected then line = f end end
	check(not line, "Klassenauswahl: Magier bekommt den Alarm nicht")
	click(find(alarms, "Löschen")); check(popup and popup.arg == "Seelensplitter", "Löschen fragt nach")
	StaticPopupDialogs.KAUFALARM_DELETE.OnAccept(); check(#KaufAlarmDB.watches == 2, "Alarm gelöscht")
	alarms.shown = false

	-- Rest
	class = "WARRIOR"; fire("BAG_UPDATE_DELAYED"); check(not warn.shown, "Krieger wird nicht gewarnt")
	class = "MAGE"; level = 30; fire("BAG_UPDATE_DELAYED"); check(not warn.shown, "unter Stufe 45 keine Wasser-Warnung")
	SlashCmdList.KAUFALARM("move"); check(warn.shown, "/ka move zeigt Rahmen")
	warn.scripts.OnDragStop(warn); check(KaufAlarmDB.x == 5, "Position gespeichert")
	SlashCmdList.KAUFALARM("reset"); check(KaufAlarmDB.x == 0 and KaufAlarmDB.y == 160, "/ka reset")
	SlashCmdList.KAUFALARM("status"); check(chat[#chat]:find("Munition"), "/ka status listet die Alarme")
end

run(false)
run(true)

-- Migration: alte Werte landen im Wasser-Alarm
do
	KaufAlarmDB = { threshold = 25, extraItems = { [1645] = true }, sound = false }
	local ns = {}
	local events
	local orig = CreateFrame
	CreateFrame = function(kind, name, parent)
		local f = orig(kind, name, parent)
		if kind == "Frame" and not name and not parent then events = f end
		return f
	end
	for _, file in ipairs({ "Sounds.lua", "Minimap.lua", "KaufAlarm.lua", "Options.lua" }) do
		assert(loadfile(dir .. "/" .. file))("KaufAlarm", ns)
	end
	CreateFrame = orig
	events.scripts.OnEvent(events, "ADDON_LOADED", "KaufAlarm")
	local water = KaufAlarmDB.watches[1]
	assert(water.threshold == 25 and water.items[1645] and water.items[8766], "Migration")
	assert(KaufAlarmDB.threshold == nil and KaufAlarmDB.extraItems == nil and KaufAlarmDB.sound == false, "Migration räumt auf")
	print("ok   Migration aus Version 1.x")
end
print("alle Checks ok")
