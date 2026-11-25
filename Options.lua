-- KaufWasser: Optionen unter Einstellungen -> AddOns -> KaufWasser
--
-- Drei Seiten: Allgemein (Anzeige, Sound), Alarme (was gezählt wird) und Sounds
-- (welche Sounds abgespielt werden).
local _, ns = ...

local widgets = {} -- alles mit :Refresh(), je mit .page
local pages = {}
local mainCategory, alarmsCategory, soundsCategory
local selected = 1 -- gerade bearbeiteter Alarm

local function Watch()
	local watches = ns.db.watches
	selected = math.max(1, math.min(selected, #watches))
	return watches[selected]
end

local function Register(page, widget)
	widget.page = page
	widgets[#widgets + 1] = widget
	return widget
end

local function RefreshPage(page)
	for _, widget in ipairs(widgets) do
		if widget.page == page then widget:Refresh() end
	end
end

function ns.RefreshOptions()
	for _, page in ipairs(pages) do
		if page:IsVisible() then RefreshPage(page) end
	end
end

local function Changed()
	ns.Update() -- aktualisiert auch die sichtbaren Optionen
end

--------------------------------------------------------------------------------
-- Bausteine
--------------------------------------------------------------------------------

local function NewPage(name, title, info)
	local page = CreateFrame("Frame", name)
	page:Hide() -- ohne Elternfenster gälte es sonst als sichtbar
	page:SetScript("OnShow", RefreshPage)
	pages[#pages + 1] = page

	local heading = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	heading:SetPoint("TOPLEFT", 16, -16)
	heading:SetText(title)
	if info then
		local text = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		text:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -6)
		text:SetPoint("RIGHT", page, "RIGHT", -16, 0)
		text:SetJustifyH("LEFT")
		text:SetText(info)
	end
	return page
end

local function Header(page, label, y)
	local header = page:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	header:SetPoint("TOPLEFT", page, "TOPLEFT", 16, y)
	header:SetText(label)
	local line = page:CreateTexture(nil, "ARTWORK")
	line:SetColorTexture(1, 0.82, 0, 0.25)
	line:SetHeight(1)
	line:SetPoint("LEFT", header, "RIGHT", 8, 0)
	line:SetPoint("RIGHT", page, "RIGHT", -16, 0)
end

local sliderCount = 0
local function Slider(page, label, x, y, minimum, maximum, step, suffix, get, set)
	sliderCount = sliderCount + 1
	local name = "KaufWasserSlider" .. sliderCount
	local slider = CreateFrame("Slider", name, page, "OptionsSliderTemplate")
	slider:SetPoint("TOPLEFT", page, "TOPLEFT", x, y)
	slider:SetSize(250, 17)
	slider:SetMinMaxValues(minimum, maximum)
	slider:SetValueStep(step)
	if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
	for _, part in ipairs({ "Low", "High", "Text" }) do
		local region = slider[part] or _G[name .. part]
		if type(region) == "table" and region.SetText then region:SetText("") end
	end
	local caption = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	caption:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 0, 4)
	slider.caption = caption
	local function show(value) caption:SetText(label .. ": " .. value .. (suffix or "")) end

	slider:SetScript("OnValueChanged", function(self, value)
		if self.refreshing then return end
		value = math.floor(value / step + 0.5) * step
		show(value)
		if value ~= get() then
			set(value)
			Changed()
		end
	end)
	slider.Refresh = function(self)
		self.refreshing = true
		self:SetValue(get())
		self.refreshing = false
		show(get())
	end
	return Register(page, slider)
end

local function Check(page, label, x, y, get, set)
	local box = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
	box:SetPoint("TOPLEFT", page, "TOPLEFT", x, y)
	box:SetSize(26, 26)
	local caption = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	caption:SetPoint("LEFT", box, "RIGHT", 4, 0)
	caption:SetText(label)
	box.caption = caption
	box:SetScript("OnClick", function(self)
		set(self:GetChecked() and true or false)
		Changed()
	end)
	box.Refresh = function(self) self:SetChecked(get() and true or false) end
	return Register(page, box)
end

local function Button(page, label, x, y, width, onClick)
	local button = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
	button:SetPoint("TOPLEFT", page, "TOPLEFT", x, y)
	button:SetSize(width, 24)
	button:SetText(label)
	button:SetScript("OnClick", onClick)
	return button
end

-- Knopf, der bei jedem Klick den nächsten Wert durchschaltet.
local function Cycle(page, x, y, width, getText, onClick)
	local button = Button(page, "", x, y, width, function()
		onClick()
		Changed()
	end)
	button.Refresh = function(self) self:SetText(getText()) end
	return Register(page, button)
end

local function Edit(page, label, x, y, width, numeric, get, set)
	local box = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
	box:SetPoint("TOPLEFT", page, "TOPLEFT", x + 6, y)
	box:SetSize(width, 20)
	box:SetAutoFocus(false)
	if numeric then box:SetNumeric(true) end
	local caption = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	caption:SetPoint("BOTTOMLEFT", box, "TOPLEFT", -4, 4)
	caption:SetText(label)
	box.caption = caption

	local function commit(self)
		local value = self:GetText() or ""
		if numeric then value = tonumber(value) end
		if value ~= nil and value ~= "" and value ~= get() then
			set(value)
			Changed()
		end
		self:Refresh()
	end
	box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	box:SetScript("OnEscapePressed", function(self)
		self.cancel = true
		self:ClearFocus()
	end)
	box:SetScript("OnEditFocusLost", function(self)
		if self.cancel then
			self.cancel = nil
			self:Refresh()
		else
			commit(self)
		end
	end)
	box.Refresh = function(self)
		if self:HasFocus() then return end -- nicht beim Tippen überschreiben
		self:SetText(tostring(get() or ""))
		self:SetCursorPosition(0)
	end
	return Register(page, box)
end

local function ScrollList(page, name, y, height)
	local scroll = CreateFrame("ScrollFrame", name, page, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", page, "TOPLEFT", 16, y)
	scroll:SetPoint("RIGHT", page, "RIGHT", -34, 0)
	scroll:SetHeight(height)
	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(540, 1)
	scroll:SetScrollChild(content)
	return content
end

local function ItemName(id)
	local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
	if not name and GetItemInfo then name = GetItemInfo(id) end
	return name or ("Item " .. id)
end

local function ItemIcon(id)
	local get = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
	return get and get(id) or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function ParseItem(text)
	text = (text or ""):match("^%s*(.-)%s*$")
	local id = tonumber(text:match("item:(%d+)") or text:match("^(%d+)$"))
	if not id and text ~= "" and GetItemInfo then
		local _, link = GetItemInfo(text) -- klappt mit Namen von Items, die schon im Cache sind
		id = link and tonumber(link:match("item:(%d+)"))
	end
	return id
end

--------------------------------------------------------------------------------
-- Seite 1: Allgemein
--------------------------------------------------------------------------------

local function OpenCategory(category)
	if category and Settings and Settings.OpenToCategory then
		local id = category.GetID and category:GetID() or category.ID
		return pcall(Settings.OpenToCategory, id)
	end
	return false
end

local function BuildMain()
	local page = NewPage("KaufWasserOptionen", "|cff3fa9ffKauf|rWasser",
		"Große Warnung, wenn Wasser, Munition oder anderes knapp wird. Was gezählt wird, stellst du unter \"Alarme\" ein.")
	page.name = "KaufWasser"

	local status = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	status:SetPoint("TOPLEFT", page, "TOPLEFT", 18, -66)
	status:SetJustifyH("LEFT")
	status.Refresh = function(self)
		local parts = {}
		for _, entry in ipairs(ns.Status()) do
			local color = not entry.eligible and "999999" or entry.low and "ff3333" or "4dff4d"
			parts[#parts + 1] = ("|cff%s%s: %d / %d|r"):format(color, entry.watch.name, entry.count, entry.watch.threshold)
		end
		self:SetText("Im Gepäck:  " .. table.concat(parts, "     "))
	end
	Register(page, status)

	Button(page, "Alarme bearbeiten", 18, -92, 170, function() OpenCategory(alarmsCategory) end)
	Button(page, "Sounds auswählen", 198, -92, 170, function() OpenCategory(soundsCategory) end)

	local db = ns.db
	Header(page, "Anzeige", -135)
	Slider(page, "Schriftgröße", 22, -175, 20, 120, 2, nil,
		function() return db.fontSize end, function(v) db.fontSize = v end)
	Check(page, "Auch im Kampf anzeigen", 18, -200,
		function() return db.showInCombat end, function(v) db.showInCombat = v end)
	Check(page, "Knopf an der Minimap", 18, -225,
		function() return ns.Minimap.IsShown() end, function(v) ns.Minimap.SetShown(v) end)
	Button(page, "Warnung testen", 20, -260, 170, ns.RunTest)
	Button(page, "Verschieben an/aus", 200, -260, 170, ns.ToggleUnlocked)
	Button(page, "Position zurücksetzen", 380, -260, 170, ns.ResetPosition)

	Header(page, "Sound", -305)
	Check(page, "Sound abspielen, solange die Warnung sichtbar ist", 18, -323,
		function() return db.sound end, function(v) db.sound = v end)
	Slider(page, "Wiederholen alle", 22, -375, 10, 300, 10, " Sekunden",
		function() return db.soundInterval end, function(v) db.soundInterval = v end)
	Button(page, "Nächsten Sound spielen", 312, -371, 200, function()
		if not ns.PlayNextSound() then ns.Print("Kein Sound angehakt (Seite \"Sounds\").") end
	end)
	Cycle(page, 20, -410, 240,
		function() return "Reihenfolge: " .. ns.ORDER_NAMES[db.soundOrder] end,
		function() db.soundOrder = db.soundOrder == "random" and "sequence" or "random" end)
	Cycle(page, 270, -410, 240,
		function() return "Lautstärke-Regler: " .. (ns.CHANNEL_NAMES[db.soundChannel] or db.soundChannel) end,
		function()
			local next = 1
			for i, channel in ipairs(ns.CHANNELS) do
				if channel == db.soundChannel then next = i % #ns.CHANNELS + 1 end
			end
			db.soundChannel = ns.CHANNELS[next]
		end)

	local hint = page:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	hint:SetPoint("TOPLEFT", page, "TOPLEFT", 18, -450)
	hint:SetPoint("RIGHT", page, "RIGHT", -16, 0)
	hint:SetJustifyH("LEFT")
	hint:SetText("Titan Panel, ChocolateBar, Bazooka, ElvUI und andere Broker-Leisten zeigen den Eintrag "
		.. "\"KaufWasser\" mit deinen Vorräten. Befehle: /kw help")
	return page
end

--------------------------------------------------------------------------------
-- Seite 2: Alarme
--------------------------------------------------------------------------------

StaticPopupDialogs = StaticPopupDialogs or {}
StaticPopupDialogs.KAUFWASSER_DELETE = {
	text = "Alarm \"%s\" löschen?",
	button1 = YES or "Ja",
	button2 = NO or "Nein",
	OnAccept = function()
		table.remove(ns.db.watches, selected)
		Changed()
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

local function BuildAlarms()
	local page = NewPage("KaufWasserOptionenAlarme", "Alarme",
		"Jeder Alarm zählt seine Items zusammen und warnt unter der Grenze.")
	page.name = "Alarme"
	page.parent = "KaufWasser"

	Button(page, "<", 16, -56, 28, function()
		selected = selected > 1 and selected - 1 or #ns.db.watches
		Changed()
	end)
	local title = page:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	title:SetPoint("TOPLEFT", page, "TOPLEFT", 50, -62)
	title:SetWidth(200)
	title.Refresh = function(self)
		local watch = Watch()
		self:SetText(("%s  |cff999999(%d von %d)|r"):format(watch.name, selected, #ns.db.watches))
	end
	Register(page, title)
	Button(page, ">", 254, -56, 28, function()
		selected = selected < #ns.db.watches and selected + 1 or 1
		Changed()
	end)
	Button(page, "Neuer Alarm", 300, -56, 120, function()
		table.insert(ns.db.watches, ns.NewWatch())
		selected = #ns.db.watches
		Changed()
	end)
	Button(page, "Löschen", 426, -56, 100, function()
		if #ns.db.watches <= 1 then
			ns.Print("Der letzte Alarm bleibt. Schalte ihn stattdessen aus.")
		else
			StaticPopup_Show("KAUFWASSER_DELETE", Watch().name)
		end
	end)

	Check(page, "Alarm aktiv", 18, -88,
		function() return Watch().enabled end, function(v) Watch().enabled = v end)
	Edit(page, "Name", 22, -135, 170, false,
		function() return Watch().name end, function(v) Watch().name = v end)
	Edit(page, "Warntext", 214, -135, 330, false,
		function() return Watch().text end, function(v) Watch().text = v end)
	Edit(page, "Warnen unter", 22, -180, 70, true,
		function() return Watch().threshold end, function(v) Watch().threshold = math.max(1, v) end)
	Edit(page, "Ab Stufe", 114, -180, 40, true,
		function() return Watch().minLevel end, function(v) Watch().minLevel = math.max(1, v) end)
	Check(page, "Nur Klassen mit Mana", 210, -166,
		function() return Watch().manaOnly end, function(v) Watch().manaOnly = v or nil end)
	Check(page, "Ausgerüstete Munition mitzählen (Jäger)", 210, -190,
		function() return Watch().ammo end, function(v) Watch().ammo = v or nil end)

	local classLabel = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	classLabel:SetPoint("TOPLEFT", page, "TOPLEFT", 18, -225)
	classLabel:SetText("Nur für diese Klassen (keine angehakt = alle Klassen):")
	for i, class in ipairs(ns.CLASSES) do
		local column, row = (i - 1) % 5, math.floor((i - 1) / 5)
		local name = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class] or class
		local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
		if color and color.colorStr then name = "|c" .. color.colorStr .. name .. "|r" end
		Check(page, name, 18 + column * 112, -240 - row * 24,
			function() return Watch().classes and Watch().classes[class] end,
			function(v)
				local watch = Watch()
				watch.classes = watch.classes or {}
				watch.classes[class] = v or nil
			end)
	end

	Header(page, "Items", -300)
	local addBox = CreateFrame("EditBox", "KaufWasserItemEingabe", page, "InputBoxTemplate")
	addBox:SetPoint("TOPLEFT", page, "TOPLEFT", 28, -335)
	addBox:SetSize(300, 20)
	addBox:SetAutoFocus(false)
	local addLabel = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	addLabel:SetPoint("BOTTOMLEFT", addBox, "TOPLEFT", -4, 4)
	addLabel:SetText("Item hinzufügen: hier klicken, dann Shift-Klick auf ein Item (oder Item-ID)")
	local function addItem()
		local id = ParseItem(addBox:GetText())
		addBox:SetText("")
		addBox:ClearFocus()
		if not id then
			ns.Print("Item nicht erkannt. Shift-Klick auf ein Item oder die Item-ID eingeben.")
			return
		end
		Watch().items[id] = true
		ns.Print(ItemName(id) .. " zählt jetzt bei \"" .. Watch().name .. "\".")
		Changed()
	end
	addBox:SetScript("OnEnterPressed", addItem)
	addBox:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
	Button(page, "Hinzufügen", 340, -333, 110, addItem)
	-- Shift-Klick auf ein Item schreibt den Link in das Feld, solange es aktiv ist.
	if hooksecurefunc and ChatEdit_InsertLink then
		hooksecurefunc("ChatEdit_InsertLink", function(link)
			if addBox:HasFocus() and type(link) == "string" then addBox:SetText(link) end
		end)
	end

	local list = ScrollList(page, "KaufWasserItemListe", -365, 150)
	local rows = {}
	local empty = list:CreateFontString(nil, "ARTWORK", "GameFontDisable")
	empty:SetPoint("TOPLEFT", 6, -6)
	empty:SetJustifyH("LEFT")
	list.Refresh = function()
		local watch = Watch()
		local ids = {}
		for id in pairs(watch.items) do ids[#ids + 1] = id end
		table.sort(ids)
		for i, id in ipairs(ids) do
			local row = rows[i]
			if not row then
				row = CreateFrame("Frame", nil, list)
				row:SetSize(530, 24)
				row:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -(i - 1) * 24)
				row:EnableMouse(true)
				row.icon = row:CreateTexture(nil, "ARTWORK")
				row.icon:SetSize(20, 20)
				row.icon:SetPoint("LEFT", 2, 0)
				row.name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
				row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
				row.name:SetWidth(300)
				row.name:SetJustifyH("LEFT")
				row.count = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
				row.count:SetPoint("LEFT", row.name, "RIGHT", 6, 0)
				row.remove = Button(row, "Entfernen", 440, -1, 85, function(self)
					Watch().items[self:GetParent().id] = nil
					Changed()
				end)
				row:SetScript("OnEnter", function(self)
					if GameTooltip and GameTooltip.SetItemByID then
						GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
						GameTooltip:SetItemByID(self.id)
						GameTooltip:Show()
					end
				end)
				row:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
				rows[i] = row
			end
			row.id = id
			row.icon:SetTexture(ItemIcon(id))
			row.name:SetText(ItemName(id))
			row.count:SetText(("im Gepäck: %d"):format((C_Item and C_Item.GetItemCount or GetItemCount)(id) or 0))
			row:Show()
		end
		for i = #ids + 1, #rows do rows[i]:Hide() end
		list:SetHeight(math.max(1, #ids * 24))
		empty:SetShown(#ids == 0)
		empty:SetText(watch.ammo and "Keine Items. Gezählt wird die ausgerüstete Munition." or "Noch keine Items.")
	end
	Register(page, list)
	return page
end

--------------------------------------------------------------------------------
-- Seite 3: Sounds
--------------------------------------------------------------------------------

local function BuildSounds()
	local page = NewPage("KaufWasserOptionenSounds", "Sounds",
		"Angehakte Sounds werden abgespielt (zufällig oder der Reihe nach, siehe Hauptseite). "
		.. "Eigene Sounds: Dateien in den Ordner Sounds legen, tools/update-sounds.sh ausführen, WoW neu starten.")
	page.name = "Sounds"
	page.parent = "KaufWasser"

	local function setAll(value)
		for _, entry in ipairs(ns.sounds or {}) do ns.SetSoundEnabled(entry, value) end
		Changed()
	end
	Button(page, "Alle an", 18, -70, 110, function() setAll(true) end)
	Button(page, "Alle aus", 134, -70, 110, function() setAll(false) end)
	Button(page, "Nächsten Sound spielen", 250, -70, 200, function()
		if not ns.PlayNextSound() then ns.Print("Kein Sound angehakt.") end
	end)

	local list = ScrollList(page, "KaufWasserSoundListe", -104, 440)
	for i, entry in ipairs(ns.sounds or {}) do
		local row = CreateFrame("Frame", nil, list)
		row:SetSize(530, 26)
		row:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -(i - 1) * 26)
		local box = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
		box:SetPoint("LEFT", 0, 0)
		box:SetSize(24, 24)
		box:SetScript("OnClick", function(self)
			ns.SetSoundEnabled(entry, self:GetChecked() and true or false)
			Changed()
		end)
		box.Refresh = function(self) self:SetChecked(ns.IsSoundEnabled(entry)) end
		Register(page, box)
		local label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		label:SetPoint("LEFT", box, "RIGHT", 4, 0)
		label:SetWidth(380)
		label:SetJustifyH("LEFT")
		label:SetText(ns.SoundLabel(entry))
		Button(row, "Abspielen", 440, -1, 85, function() ns.PlayEntry(entry) end)
	end
	list:SetHeight(math.max(1, #(ns.sounds or {}) * 26))
	return page
end

--------------------------------------------------------------------------------
-- Anmelden und öffnen
--------------------------------------------------------------------------------

function ns.BuildOptions()
	local main, alarms, sounds = BuildMain(), BuildAlarms(), BuildSounds()

	if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
		local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, main, main.name)
		if ok and category then
			mainCategory = category
			if Settings.RegisterCanvasLayoutSubcategory then
				local okA, a = pcall(Settings.RegisterCanvasLayoutSubcategory, category, alarms, alarms.name)
				local okS, s = pcall(Settings.RegisterCanvasLayoutSubcategory, category, sounds, sounds.name)
				alarmsCategory = okA and a or nil
				soundsCategory = okS and s or nil
			end
			pcall(Settings.RegisterAddOnCategory, category)
		end
	elseif InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(main)
		InterfaceOptions_AddCategory(alarms)
		InterfaceOptions_AddCategory(sounds)
	end
	ns.optionPages = { main = main, alarms = alarms, sounds = sounds }
end

function ns.ToggleOptions()
	local frame = SettingsPanel or InterfaceOptionsFrame
	if frame and frame:IsShown() then
		for _, page in ipairs(pages) do
			if page:IsVisible() then
				if HideUIPanel then HideUIPanel(frame) else frame:Hide() end
				return
			end
		end
	end
	if OpenCategory(mainCategory) then return end
	if InterfaceOptionsFrame_OpenToCategory then
		-- zweimal: der erste Aufruf landet bei manchen Clients auf der falschen Seite
		InterfaceOptionsFrame_OpenToCategory(ns.optionPages.main)
		InterfaceOptionsFrame_OpenToCategory(ns.optionPages.main)
	end
end
