-- Prüft die Logik des Addons mit einer nachgebauten WoW-API.
-- Aufruf aus dem Projektordner: luajit tests/mocktest.lua
local dir = arg[1] or "."

local function run(withBroker)
	local now, items, level, class = 100, {}, 60, "SHAMAN"
	local played, timers, shift = {}, {}, false

	local function widget()
		local w = { scripts = {}, shown = true, lines = {} }
		return setmetatable(w, { __index = function(_, k)
			if k == "SetScript" then return function(self, n, f) self.scripts[n] = f end end
			if k == "GetScript" then return function(self, n) return self.scripts[n] end end
			if k == "Show" then return function(self) self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end end
			if k == "Hide" then return function(self) self.shown = false end end
			if k == "SetShown" then return function(self, v) self.shown = v and true or false end end
			if k == "IsShown" or k == "IsVisible" then return function(self) return self.shown end end
			if k == "SetText" then return function(self, s) self.txt = s end end
			if k == "SetFormattedText" then return function(self, f, ...) self.txt = f:format(...) end end
			if k == "AddLine" or k == "AddDoubleLine" then return function(self, a, b) self.lines[#self.lines + 1] = tostring(a) .. (type(b) ~= "number" and "" or (" " .. b)) end end
			if k == "GetStringWidth" then return function() return 800 end end
			if k == "GetPoint" then return function() return "CENTER", nil, "CENTER", 5, 6 end end
			if k == "GetCenter" then return function() return 500, 500 end end
			if k == "GetEffectiveScale" then return function() return 1 end end
			if k == "SetChecked" then return function(self, v) self.checked = v end end
			if k == "GetChecked" then return function(self) return self.checked end end
			if k == "SetValue" then return function(self, v) self.value = v; if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, v) end end end
			if k:match("^Create") then return function() return widget() end end
			if k:match("^[A-Z]") then return function() end end
		end })
	end

	_G.KaufWasserDB = nil
	local frames, named = {}, {}
	function CreateFrame(kind, name)
		local w = widget(); w.kind = kind
		frames[#frames + 1] = w
		if name then named[name] = w; _G[name] = w end
		return w
	end
	UIParent, Minimap, GameTooltip = widget(), widget(), widget()
	STANDARD_TEXT_FONT, SlashCmdList = "font", {}
	DEFAULT_CHAT_FRAME = { AddMessage = function() end }
	function GetItemCount(id) return items[id] or 0 end
	function GetItemIcon() return 132794 end
	function UnitClass() return "x", class end
	function UnitLevel() return level end
	function UnitAffectingCombat() return false end
	function GetTime() return now end
	function GetCursorPosition() return 400, 500 end -- links von der Minimap: 180 Grad
	function IsShiftKeyDown() return shift end
	function PlaySound(id) played[#played + 1] = id end
	function PlaySoundFile(p) played[#played + 1] = p; return true end
	C_Timer = { After = function(_, f) timers[#timers + 1] = f end }

	local opened = 0
	SettingsPanel = widget(); SettingsPanel.shown = false
	Settings = {
		RegisterCanvasLayoutCategory = function() return { GetID = function() return 7 end } end,
		RegisterAddOnCategory = function() end,
		OpenToCategory = function(id) assert(id == 7); opened = opened + 1 end,
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
	for _, file in ipairs({ "Sounds.lua", "Minimap.lua", "KaufWasser.lua" }) do
		assert(loadfile(dir .. "/" .. file))("KaufWasser", ns)
	end

	local ev
	for _, f in ipairs(frames) do if f.scripts.OnEvent then ev = f end end
	local warn = named.KaufWasserWarnung
	local function fire(e, a) ev.scripts.OnEvent(ev, e, a) end
	local function runTimers() local t = timers; timers = {}; for _, f in ipairs(t) do f() end end
	local function tick() if warn.shown then warn.scripts.OnUpdate(warn, 0.1) end end
	local function check(cond, msg)
		print((cond and "ok   " or "FAIL ") .. (withBroker and "[Broker] " or "[ohne]   ") .. msg)
		if not cond then os.exit(1) end
	end

	fire("ADDON_LOADED", "KaufWasser"); fire("PLAYER_LOGIN"); fire("PLAYER_ENTERING_WORLD")
	check(not warn.shown, "vor dem Laden des Gepäcks keine Warnung")
	items[8766] = 39; runTimers(); tick()
	check(warn.shown, "39 Trichterwindentau -> Warnung")
	check(#played == 1, "Sound sofort beim Erscheinen")
	tick(); check(#played == 1, "kein zweiter Sound in derselben Minute")
	now = now + 61; tick(); check(#played == 2 and played[1] ~= played[2], "nach 60 s anderer Sound")
	items[8766] = 20; items[8079] = 20; fire("BAG_UPDATE_DELAYED")
	check(not warn.shown, "20 Tau + 20 Magierwasser = 40 -> keine Warnung")
	SlashCmdList.KAUFWASSER("60"); check(warn.shown and KaufWasserDB.threshold == 60, "/kw 60 -> Grenze 60, Warnung")
	fire("PLAYER_REGEN_DISABLED"); check(not warn.shown, "im Kampf versteckt")
	fire("PLAYER_REGEN_ENABLED"); check(warn.shown, "nach dem Kampf wieder da")

	-- Minimap, Broker, Addon-Fach
	local button = ns.Minimap.internals.button()
	if withBroker then
		local obj = ldbObjects.KaufWasser
		check(obj and obj.type == "data source", "Broker-Eintrag für Titan Panel & Co. angelegt")
		check(obj.text == "|cffff333340|r", "Broker zeigt 40 rot (unter Grenze 60)")
		check(iconRegistered and iconRegistered.settings == KaufWasserDB.minimap, "Knopf läuft über LibDBIcon")
		check(button == nil, "kein eigener Knopf neben LibDBIcon")
		local tip = widget(); obj.OnTooltipShow(tip)
		check(table.concat(tip.lines, "|"):find("Wasser im Gepäck 40", 1, true), "Broker-Tooltip zeigt den Stand")
		obj.OnClick(nil, "LeftButton"); check(opened == 1, "Broker-Linksklick öffnet Optionen")
		ns.Minimap.SetShown(false); check(KaufWasserDB.minimap.hide == true, "Minimap-Knopf über LibDBIcon ausblendbar")
		ns.Minimap.SetShown(true)
	else
		check(button and button.shown, "eigener Minimap-Knopf ohne Bibliotheken")
		button.scripts.OnDragStart(button); button.scripts.OnUpdate(button)
		button.scripts.OnDragStop(button)
		check(KaufWasserDB.minimap.minimapPos == 180, "Knopf lässt sich um die Minimap ziehen")
		button.scripts.OnEnter(button)
		check(table.concat(GameTooltip.lines, "|"):find("Linksklick: Optionen", 1, true), "Tooltip am Knopf")
		button.scripts.OnClick(button, "LeftButton"); check(opened == 1, "Linksklick öffnet Optionen")
		SlashCmdList.KAUFWASSER("minimap"); check(not button.shown and KaufWasserDB.minimap.hide, "/kw minimap blendet aus")
		SlashCmdList.KAUFWASSER("minimap"); check(button.shown, "/kw minimap blendet wieder ein")
	end
	ns.Minimap.OnClick(nil, "RightButton"); check(KaufWasserDB.sound == false, "Rechtsklick schaltet Sound aus")
	local n = #played; now = now + 120; tick(); check(#played == n, "ohne Sound kein Abspielen")
	KaufWasser_OnAddonCompartmentClick(nil, "RightButton"); check(KaufWasserDB.sound == true, "Addon-Fach: Rechtsklick Sound an")
	KaufWasser_OnAddonCompartmentEnter(nil, widget()); KaufWasser_OnAddonCompartmentLeave()
	shift = true; n = #played; ns.Minimap.OnClick(nil, "LeftButton"); shift = false
	check(#played == n + 1, "Shift-Klick testet Warnung + Sound"); runTimers()

	-- Optionen
	local panel = named.KaufWasserOptionen
	check(not panel.shown, "Options-Panel startet versteckt")
	panel.shown = true; SettingsPanel.shown = true; panel.scripts.OnShow(panel)
	function HideUIPanel(f) f.shown = false end
	SlashCmdList.KAUFWASSER(""); check(opened == 1 and not SettingsPanel.shown, "/kw bei offenen Optionen schließt sie wieder")
	panel.shown = false; SlashCmdList.KAUFWASSER(""); check(opened == 2, "/kw öffnet die Optionen")
	local slider = named.KaufWasserSlider_threshold
	slider:SetValue(25); check(KaufWasserDB.threshold == 25 and not warn.shown, "Regler setzt Grenze auf 25")

	SlashCmdList.KAUFWASSER("add |cffffffff|Hitem:12345::::|h[X]|h|r"); items = { [12345] = 30 }; fire("BAG_UPDATE_DELAYED")
	check(not warn.shown, "/kw add zählt weiteres Item mit")
	items = {}; class = "WARRIOR"; fire("BAG_UPDATE_DELAYED"); check(not warn.shown, "Krieger wird nicht gewarnt")
	class = "MAGE"; level = 30; fire("BAG_UPDATE_DELAYED"); check(not warn.shown, "unter Stufe 45 keine Warnung")
	SlashCmdList.KAUFWASSER("move"); check(warn.shown, "/kw move zeigt Rahmen")
	warn.scripts.OnDragStop(warn); check(KaufWasserDB.x == 5, "Position gespeichert")
	SlashCmdList.KAUFWASSER("reset"); check(KaufWasserDB.x == 0 and KaufWasserDB.y == 160, "/kw reset")
end

run(false)
run(true)
print("alle Checks ok")
