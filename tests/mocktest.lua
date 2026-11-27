-- Prüft die Logik des Addons mit einer nachgebauten WoW-API.
-- Aufruf aus dem Projektordner: luajit tests/mocktest.lua
local dir = arg[1] or "."

local function run(withBroker)
	local now, items, level, class = 100, {}, 60, "SHAMAN"
	local ammo = nil -- { id, count }
	local weapons = {} -- [16] / [17] = Item-ID der Waffe (oder des Schilds)
	local enchant = {} -- { main = Millisekunden, off = Millisekunden }; nil = kein Gift
	local instance = nil -- nil, "party", "raid", "pvp", "arena", "none"
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
	function GetInventoryItemID(_, slot)
		if slot == 0 then return ammo and ammo[1] end
		assert(slot == 16 or slot == 17); return weapons[slot]
	end
	function GetItemInfoInstant(id) return id, "x", "y", "z", 1, id == 2129 and 4 or 2 end -- 2129: Schild
	function GetWeaponEnchantInfo()
		return enchant.main ~= nil, enchant.main, 0, 0, enchant.off ~= nil, enchant.off, 0, 0
	end
	function GetInventoryItemCount(_, slot) assert(slot == 0); return ammo and ammo[2] or 0 end
	function UnitClass() return "x", class end
	function UnitLevel() return level end
	function UnitAffectingCombat() return false end
	function IsInInstance() return instance ~= nil and instance ~= "none", instance or "none" end
	function GetTime() return now end
	function GetCursorPosition() return 400, 500 end -- links von der Minimap: 180 Grad
	function IsShiftKeyDown() return shift end
	function PlaySound(id, ch) played[#played + 1] = id; channels[#channels + 1] = ch end
	function PlaySoundFile(p, ch) played[#played + 1] = p; channels[#channels + 1] = ch; return true end
	C_Timer = { After = function(_, f) timers[#timers + 1] = f end }
	local popup
	function StaticPopup_Show(which, arg) popup = { which = which, arg = arg } end
	StaticPopupDialogs = {} -- gibt es im Spiel immer
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

	-- feste Beispiel-Sounds statt Sounds.lua, damit der Test nicht vom Ordnerinhalt abhängt
	local ns = { sounds = {
		Allgemein = { "a1.ogg", "a2.ogg", 416 },
		Gift = { "g1.ogg" },
		Munition = { "m1.ogg", "m2.ogg" },
		Wasser = { "w1.ogg", "w2.ogg", "w3.ogg", "w4.ogg" },
	} }
	-- Globale Schreibzugriffe mitschneiden: jede Zuweisung an eine globale
	-- Variable von Blizzard verseucht sie (Taint) und führt zu
	-- "AddOn 'KaufAlarm' hat versucht die geschützte Funktion ... aufzurufen".
	local written = {}
	local env = setmetatable({}, {
		__index = _G,
		__newindex = function(_, k, v) written[k] = true; _G[k] = v end,
	})
	for _, file in ipairs({ "Minimap.lua", "KaufAlarm.lua", "Options.lua" }) do
		local chunk = assert(loadfile(dir .. "/" .. file))
		setfenv(chunk, env)("KaufAlarm", ns)
	end
	local function group(i) -- Gruppe des i-ten gespielten Sounds
		local p = played[i]
		if type(p) == "number" then return "Spiel" end
		return p:match("\\Sounds\\([^\\]+)\\")
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
	local OWN_GLOBALS = {
		KaufAlarmDB = true, SLASH_KAUFALARM1 = true, SLASH_KAUFALARM2 = true,
		KaufAlarm_OnAddonCompartmentClick = true, KaufAlarm_OnAddonCompartmentEnter = true,
		KaufAlarm_OnAddonCompartmentLeave = true,
	}
	for k in pairs(written) do
		check(OWN_GLOBALS[k], "schreibt keine fremde globale Variable: " .. k)
	end
	check(not written.StaticPopupDialogs, "StaticPopupDialogs wird nicht neu zugewiesen (Taint)")
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
	check(#KaufAlarmDB.watches == 4, "Standard: Wasser, Munition, Gift auf Waffe, Gifte")
	items[8766] = 39; runTimers(); tick()
	check(warn.shown and warnText() == "KAUF WASSER DU HUANSOHN!", "39 Trichterwindentau -> Wasser-Warnung")
	check(#played == 1 and channels[1] == "Master", "Sound sofort beim Erscheinen")
	now = now + 15; tick(); check(#played == 1, "nach 15 s noch kein zweiter Sound")
	now = now + 0.25; tick(); check(#played == 2 and played[1] ~= played[2], "nach 15,25 s anderer Sound")
	check(group(1) == "Wasser" and group(2) == "Wasser", "Wasser-Alarm spielt Wasser-Sounds")
	items[8766] = 20; items[8079] = 20; fire("BAG_UPDATE_DELAYED")
	check(not warn.shown, "20 Tau + 20 Magierwasser = 40 -> keine Warnung")
	fire("PLAYER_REGEN_DISABLED"); items[8079] = 0; fire("BAG_UPDATE_DELAYED")
	check(not warn.shown, "im Kampf versteckt")
	fire("PLAYER_REGEN_ENABLED"); check(warn.shown, "nach dem Kampf wieder da")
	for _, kind in ipairs({ "party", "raid", "pvp", "arena" }) do
		instance = kind; fire("ZONE_CHANGED_NEW_AREA")
		local n = #played; now = now + 100; tick()
		check(not warn.shown and #played == n, "in Instanz-Typ " .. kind .. " weder Text noch Sound")
	end
	instance = "none"; fire("ZONE_CHANGED_NEW_AREA"); check(warn.shown, "nach der Instanz wieder da")
	instance = "raid"; fire("ZONE_CHANGED_NEW_AREA")
	SlashCmdList.KAUFALARM("instanz"); check(KaufAlarmDB.showInInstances and warn.shown, "/ka instanz zeigt auch im Raid")
	SlashCmdList.KAUFALARM("instanz"); check(not KaufAlarmDB.showInInstances and not warn.shown, "/ka instanz wieder aus")
	instance = nil; fire("ZONE_CHANGED_NEW_AREA")

	-- Munition für Jäger
	check(not warnText():find("MUNITION"), "Schamane bekommt keine Munitions-Warnung")
	class = "HUNTER"; ammo = { 18042, 400 }; fire("UNIT_INVENTORY_CHANGED", "player")
	check(warnText() == "KAUF WASSER DU HUANSOHN!|KAUF MUNITION DU HUANSOHN!", "Jäger mit 400 Pfeilen: beide Warnungen")
	local before = #played
	now = now + 16; tick(); now = now + 16; tick()
	local g1, g2 = group(before + 1), group(before + 2)
	check(#played == before + 2 and g1 ~= g2 and (g1 == "Wasser" or g1 == "Munition") and (g2 == "Wasser" or g2 == "Munition"),
		"zwei Alarme: Wasser- und Munitions-Sounds abwechselnd")
	ammo = { 18042, 1600 }; items[8766] = 50; fire("BAG_UPDATE_DELAYED")
	check(not warn.shown, "Jäger mit 1600 Pfeilen und 50 Wasser: keine Warnung")
	ammo = nil; fire("UNIT_INVENTORY_CHANGED", "player")
	check(warnText() == "KAUF MUNITION DU HUANSOHN!", "keine Munition ausgerüstet -> Warnung")
	now = now + 16; tick(); check(group(#played) == "Munition", "nur Munition warnt -> Munitions-Sound")
	ammo = { 18042, 1600 }; class = "SHAMAN"; fire("BAG_UPDATE_DELAYED")

	-- Schurke: Gift auf den Waffen und Gifte im Gepäck
	class = "ROGUE"; weapons = { [16] = 12345, [17] = 12346 }; items[6947] = 20
	fire("UNIT_INVENTORY_CHANGED", "player")
	check(not warn.shown, "ohne Gift, aber außerhalb des Kampfes -> keine Warnung")
	fire("PLAYER_REGEN_DISABLED")
	check(warnText() == "VERGIFTE DEINE WAFFEN DU HUANSOHN!", "ohne Gift im Kampf -> Warnung")
	before = #played; now = now + 16; tick()
	check(group(#played) == "Gift", "Gift-Alarm spielt Gift-Sounds (Patapim)")
	enchant = { main = 30 * 60000 }; fire("UNIT_INVENTORY_CHANGED", "player")
	check(warn.shown, "nur die Waffenhand vergiftet -> weiter Warnung")
	local function hasLine(text)
		for _, f in ipairs(frames) do
			if f.parent == warn and f.shown and type(f.txt) == "string" and f.txt:find(text, 1, true) then return true end
		end
		return false
	end
	check(hasLine("Waffenhand: 30 min, Schildhand: kein Gift"), "Zeile nennt die Hand ohne Gift")
	enchant = { main = 30 * 60000, off = 30 * 60000 }; fire("UNIT_INVENTORY_CHANGED", "player")
	check(not warn.shown, "beide Waffen vergiftet -> keine Warnung")
	enchant = { main = 30 * 60000, off = 4 * 60000 + 59000 }; runTimers()
	check(warnText() == "VERGIFTE DEINE WAFFEN DU HUANSOHN!", "Gift läuft in unter 5 Minuten ab -> Warnung (ohne Event)")
	weapons[17] = 2129; fire("UNIT_INVENTORY_CHANGED", "player")
	check(not warn.shown, "Schild in der Schildhand zählt nicht")
	weapons = {}; enchant = {}; fire("UNIT_INVENTORY_CHANGED", "player")
	check(not warn.shown, "ohne Waffe keine Gift-Warnung")
	weapons = { [16] = 12345 }; level = 19; fire("BAG_UPDATE_DELAYED"); check(not warn.shown, "unter Stufe 20 keine Gift-Warnung")
	level = 60; fire("PLAYER_REGEN_ENABLED")
	check(not warn.shown, "nach dem Kampf ist die Gift-Warnung weg")
	enchant = { main = 60 * 60000 }; items[6947] = nil; items[8927] = 7
	fire("BAG_UPDATE_DELAYED")
	check(not warn.shown, "7 Sofort wirkendes Gift V -> keine Warnung (Grenze 5)")
	items[8927] = nil; items[6947] = 2; items[2892] = 2; fire("BAG_UPDATE_DELAYED")
	check(warnText() == "KAUF GIFTE DU HUANSOHN!", "4 Gifte im Gepäck (unter 5) -> Kauf-Warnung")
	items[2892] = 3; fire("BAG_UPDATE_DELAYED"); check(not warn.shown, "5 Gifte (verschiedene Sorten) -> keine Warnung")
	items[2892] = 2; fire("PLAYER_REGEN_DISABLED")
	check(not warn.shown, "Kauf-Warnung für Gifte bleibt im Kampf aus (wie eingestellt)")
	fire("PLAYER_REGEN_ENABLED"); items[2892] = 3
	class = "MAGE"; fire("BAG_UPDATE_DELAYED")
	check(not warnText():find("GIFT"), "Magier bekommt keine Gift-Warnung")
	weapons = {}; class = "SHAMAN"; items[6947] = nil; items[2892] = nil; fire("BAG_UPDATE_DELAYED")

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
		check(table.concat(tip.lines, "|"):find("Munition 300 / 600", 1, true), "Broker-Tooltip zeigt den Stand")
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
	local inst = find(pages.main, "Auch in Dungeons, Raids und Schlachtfeldern anzeigen")
	inst.checked = true; click(inst); check(KaufAlarmDB.showInInstances == true, "Haken für Instanzen setzt die Einstellung")
	inst.checked = false; click(inst); check(KaufAlarmDB.showInInstances == false, "Haken für Instanzen wieder aus")
	click(find(pages.main, "Alarme bearbeiten")); check(opened[#opened] == "Alarme", "Knopf springt zur Seite Alarme")
	local order = find(pages.main, "Reihenfolge: zufällig"); click(order)
	check(KaufAlarmDB.soundOrder == "sequence" and order.txt == "Reihenfolge: der Reihe nach", "Reihenfolge umschaltbar")
	local channel = find(pages.main, "Lautstärke-Regler: Gesamt"); click(channel)
	check(KaufAlarmDB.soundChannel == "SFX", "Lautstärke-Regler umschaltbar")
	local interval = find(pages.main, "Wiederholen alle: 15,25 Sekunden")
	interval:SetValue(30.1); check(KaufAlarmDB.soundInterval == 30, "Wiederholrate per Regler, auf Viertelsekunden gerundet")
	interval:SetValue(7.6); check(KaufAlarmDB.soundInterval == 7.5 and interval.caption.txt == "Wiederholen alle: 7,5 Sekunden", "Regler zeigt 7,5 Sekunden")
	pages.main.shown = false

	-- Sounds: Auswahl und Reihenfolge
	local sounds = pages.sounds
	sounds.shown = true; sounds.scripts.OnShow(sounds)
	click(find(sounds, "Alle aus"))
	check(not ns.PlayNextSound("Wasser"), "alle Sounds aus -> nichts spielt, auch nicht Allgemein")
	ns.SetSoundEnabled("Wasser", "w2.ogg", true); ns.SetSoundEnabled("Wasser", "w4.ogg", true)
	local seq = {}
	for _ = 1, 4 do ns.PlayNextSound("Wasser"); seq[#seq + 1] = played[#played] end
	local base = "Interface\\AddOns\\KaufAlarm\\Sounds\\Wasser\\"
	local a, b = base .. "w2.ogg", base .. "w4.ogg"
	check((seq[1] == a or seq[1] == b) and (seq[2] == a or seq[2] == b) and seq[1] ~= seq[2]
		and seq[3] == seq[1] and seq[4] == seq[2], "der Reihe nach, nur angehakte Sounds, abwechselnd")
	check(channels[#channels] == "SFX", "Sound läuft über den gewählten Regler")
	ns.SetSoundEnabled("Allgemein", 416, true)
	ns.PlayNextSound("Munition"); check(played[#played] == 416, "Gruppe ohne angehakte Sounds -> Allgemein")
	ns.PlayNextSound("Gibtsnicht"); check(played[#played] == 416, "unbekannte Gruppe -> Allgemein")
	local box
	for _, f in ipairs(frames) do if f.sound == "Munition/m1.ogg" then box = f end end
	box.checked = true; click(box)
	check(ns.IsSoundEnabled("Munition", "m1.ogg"), "Haken in der Sound-Liste")
	ns.PlayNextSound("Munition"); check(group(#played) == "Munition", "angehakter Munitions-Sound spielt")
	click(find(sounds, "Alle an"))
	click(find(sounds, "aus")) -- erste Gruppe: Allgemein
	check(not ns.IsSoundEnabled("Allgemein", "a1.ogg") and ns.IsSoundEnabled("Wasser", "w1.ogg"), "Gruppe einzeln abschaltbar")
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
	click(find(alarms, ">")); check(find(alarms, "Warnen unter").txt == "600", "zweiter Alarm: Munition")
	local kind = find(alarms, "Prüft: Items + ausgerüstete Munition")
	click(find(alarms, ">")); check(find(alarms, "Warnen unter (Min.)").txt == "5", "dritter Alarm: Gift auf Waffe, Grenze in Minuten")
	check(kind.txt == "Prüft: Gift auf den Waffen", "Art des Alarms wird angezeigt")
	local combat = find(alarms, "Kampf: nur im Kampf")
	click(combat); check(KaufAlarmDB.watches[3].combat == "always" and combat.txt == "Kampf: immer", "Kampf-Modus umschaltbar")
	click(combat); check(KaufAlarmDB.watches[3].combat == nil and combat.txt == "Kampf: wie Hauptseite", "Kampf-Modus: wie Hauptseite")
	click(combat); check(KaufAlarmDB.watches[3].combat == "only", "Kampf-Modus: wieder nur im Kampf")
	click(find(alarms, "<")); click(find(alarms, "<"))
	click(find(alarms, "Neuer Alarm"))
	check(#KaufAlarmDB.watches == 5, "neuer Alarm angelegt")
	local soundsButton = find(alarms, "Sounds: Allgemein")
	check(KaufAlarmDB.watches[5].soundGroup == "Allgemein", "neuer Alarm nutzt allgemeine Sounds")
	click(soundsButton)
	check(KaufAlarmDB.watches[5].soundGroup == "Gift" and soundsButton.txt == "Sounds: Gift", "Sound-Gruppe pro Alarm wählbar")
	type_(find(alarms, "Name"), "Seelensplitter")
	type_(find(alarms, "Warntext"), "NUR NOCH {anzahl} {name}, {fehlen} FEHLEN BIS {grenze}! {quatsch}")
	type_(find(alarms, "Warnen unter"), "5")
	click(find(alarms, "Nur Klassen mit Mana")) -- an
	local lock = find(alarms, "WARLOCK"); lock.checked = true; click(lock)
	local color = find(alarms, "Textfarbe: Rot"); click(color); click(color)
	check(KaufAlarmDB.watches[5].color == "yellow" and color.txt == "Textfarbe: Gelb", "Textfarbe umschaltbar")
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
	StaticPopupDialogs.KAUFALARM_DELETE.OnAccept(); check(#KaufAlarmDB.watches == 4, "Alarm gelöscht")
	alarms.shown = false

	-- Rest
	class = "WARRIOR"; fire("BAG_UPDATE_DELAYED"); check(not warn.shown, "Krieger wird nicht gewarnt")
	class = "MAGE"; level = 30; fire("BAG_UPDATE_DELAYED"); check(not warn.shown, "unter Stufe 45 keine Wasser-Warnung")
	SlashCmdList.KAUFALARM("move"); check(warn.shown, "/ka move zeigt Rahmen")
	warn.scripts.OnDragStop(warn); check(KaufAlarmDB.x == 5, "Position gespeichert")
	SlashCmdList.KAUFALARM("reset"); check(KaufAlarmDB.x == 0 and KaufAlarmDB.y == 160, "/ka reset")
	SlashCmdList.KAUFALARM("status")
	local log = table.concat(chat, "\n")
	check(log:find("Munition") and log:find("Gift auf Waffe: keine Waffe", 1, true), "/ka status listet die Alarme")
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
	assert(water.soundGroup == "Wasser" and KaufAlarmDB.watches[2].soundGroup == "Munition", "Sound-Gruppen der Standard-Alarme")
	assert(type(ns.sounds.Allgemein) == "table" and ns.sounds.Allgemein[#ns.sounds.Allgemein] == 416, "echte Sounds.lua hat Gruppen")
	print("ok   Migration aus Version 1.x")
end

-- Migration: alte Munitions-Voreinstellung 1000 wird 600, eigene Werte bleiben
do
	KaufAlarmDB = { watches = {
		{ name = "Munition", ammo = true, threshold = 1000, items = {} },
		{ name = "Pfeile Zweitchar", ammo = true, threshold = 800, items = {} },
	} }
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
	assert(KaufAlarmDB.watches[1].threshold == 600, "1000 -> 600")
	assert(KaufAlarmDB.watches[2].threshold == 800, "eigener Wert bleibt")
	assert(#KaufAlarmDB.watches == 4 and KaufAlarmDB.watches[3].weaponBuff and KaufAlarmDB.watches[4].name == "Gifte",
		"Schurken-Alarme kommen zu alten Einstellungen dazu")
	assert(KaufAlarmDB.watches[3].soundGroup == "Gift", "Gift-Alarme nutzen die Gift-Sounds")
	assert(KaufAlarmDB.watches[3].combat == "only", "Gift auf Waffe warnt nur im Kampf")
	KaufAlarmDB.watches[1].threshold = 1000 -- danach selbst wieder auf 1000 gestellt
	events.scripts.OnEvent(events, "ADDON_LOADED", "KaufAlarm")
	assert(KaufAlarmDB.watches[1].threshold == 1000, "Umstellung nur einmal")
	assert(#KaufAlarmDB.watches == 4, "Schurken-Alarme nur einmal dazu")
	assert(KaufAlarmDB.watches[4].threshold == 5, "neue Gifte-Grenze 5")
	KaufAlarmDB.schema = 3; KaufAlarmDB.watches[4].threshold = 10
	events.scripts.OnEvent(events, "ADDON_LOADED", "KaufAlarm")
	assert(KaufAlarmDB.watches[4].threshold == 5, "gespeicherte Gifte-Grenze 10 (aus 1.6.0) wird 5")
	KaufAlarmDB.watches[4].threshold = 10
	events.scripts.OnEvent(events, "ADDON_LOADED", "KaufAlarm")
	assert(KaufAlarmDB.watches[4].threshold == 10, "danach selbst gewählte 10 bleibt")
	KaufAlarmDB.schema = 4; KaufAlarmDB.watches[3].combat = nil
	events.scripts.OnEvent(events, "ADDON_LOADED", "KaufAlarm")
	assert(KaufAlarmDB.watches[3].combat == "only", "Gift auf Waffe aus 1.6.0 warnt danach nur im Kampf")
	KaufAlarmDB.watches[3].combat = "always"
	events.scripts.OnEvent(events, "ADDON_LOADED", "KaufAlarm")
	assert(KaufAlarmDB.watches[3].combat == "always", "selbst gewählter Kampf-Modus bleibt")
	print("ok   Munitions-Grenze 1000 -> 600, Gifte-Grenze 10 -> 5")
end
print("alle Checks ok")
