-- ManaHelper UI Logic (Ace3 Integrated)
local LDB = LibStub("LibDataBroker-1.1", true)
local LDBIcon = LibStub("LibDBIcon-1.0", true)

ManaHelper.UI = CreateFrame("Frame", "ManaHelperMainFrame", UIParent)
local ui = ManaHelper.UI

-- Helper for easier DB access
local function db() return ManaHelper.db.profile end

function ui:CreateMainWindow()
    -- Sync dimensions with DB
    ui:SetSize(db().width, db().height)
    if db().framePosition then
        ui:SetPoint(db().framePosition.point, db().framePosition.x, db().framePosition.y)
    else
        ui:SetPoint("CENTER", 0, 0)
    end
    ui:SetMovable(true)
    ui:SetResizable(true)
    ui:EnableMouse(true)
    ui:RegisterForDrag("LeftButton")
    ui:SetScript("OnDragStart", ui.StartMoving)
    ui:SetScript("OnDragStop", function(self) 
        self:StopMovingOrSizing() 
        db().width, db().height = self:GetSize() 
        local pt, _, _, x, y = self:GetPoint()
        db().framePosition = { point = pt, x = x, y = y }
    end)
    ui:SetClampedToScreen(true)
    ui:SetMinResize(150, 100)
    ui:SetMaxResize(500, 1000)

    -- Resizing Handle
    ui.resize = CreateFrame("Button", nil, ui)
    ui.resize:SetSize(16, 16)
    ui.resize:SetPoint("BOTTOMRIGHT")
    ui.resize:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    ui.resize:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    ui.resize:SetScript("OnMouseDown", function() ui:StartSizing() end)
    ui.resize:SetScript("OnMouseUp", function() 
        ui:StopMovingOrSizing() 
        db().width, db().height = ui:GetSize() 
        local pt, _, _, x, y = ui:GetPoint()
        db().framePosition = { point = pt, x = x, y = y }
        ui:RequestRefresh()
    end)

    -- Backdrop
    ui:SetBackdrop(ManaHelperStyles.Window.Backdrop)
    ui:SetBackdropColor(0, 0, 0, 0.75)
    ui:SetBackdropBorderColor(0, 0, 0, 1)

    -- Header (Skada-style)
    ui.header = CreateFrame("Frame", nil, ui)
    ui.header:SetPoint("TOPLEFT", 0, 0)
    ui.header:SetPoint("TOPRIGHT", 0, 0)
    ui.header:SetHeight(20)
    ui.header:SetFrameLevel(ui:GetFrameLevel() + 5)
    ui.header:SetBackdrop(ManaHelperStyles.Window.Backdrop)
    ui.header:SetBackdropColor(0.5, 0, 0, 1) -- More visible red
    
    ui.title = ui.header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ui.title:SetPoint("LEFT", 5, 0)
    ui.title:SetText("ManaHelper")

    -- Move Alert Icon (Mini)
    ui.moveBtn = CreateFrame("Button", nil, ui.header)
    ui.moveBtn:SetSize(14, 14)
    ui.moveBtn:SetPoint("RIGHT", -22, 0)
    ui.moveBtn:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
    ui.moveBtn:SetScript("OnClick", function()
        if ManaHelper.Alert.isMoving then
            ManaHelper.Alert:Hide(); ManaHelper.Alert.isMoving = false
            ManaHelper.Alert:EnableMouse(false)
            ManaHelper.Alert.bg:Hide()
            local pt, _, _, x, y = ManaHelper.Alert:GetPoint()
            db().alertPosition = { point = pt, x = x, y = y }
        else
            ManaHelper.Alert:Show(); ManaHelper.Alert.isMoving = true
            ManaHelper.Alert:EnableMouse(true)
            ManaHelper.Alert.bg:Show()
            ManaHelper.Alert.text:SetText("Arrastra para mover la alerta")
        end
    end)

    -- Close Button
    ui.close = CreateFrame("Button", nil, ui.header, "UIPanelCloseButton")
    ui.close:SetPoint("RIGHT", 5, 0)
    ui.close:SetScale(0.5)
    ui.close:SetScript("OnClick", function() ui:Hide(); db().showWindow = false end)

    -- Global Toggles (Ultra Slim)
    ui.toggles = CreateFrame("Frame", nil, ui)
    ui.toggles:SetPoint("TOPLEFT", 0, -20)
    ui.toggles:SetPoint("TOPRIGHT", 0, -20)
    ui.toggles:SetHeight(20)

    ui.bgCheck = CreateFrame("CheckButton", "ManaHelperBGCheck", ui.toggles, "UICheckButtonTemplate")
    ui.bgCheck:SetPoint("LEFT", 3, 0)
    _G[ui.bgCheck:GetName().."Text"]:SetText("2do")
    ui.bgCheck:SetScript("OnClick", function(self) db().backgroundMode = not not self:GetChecked() end)

    ui.chatCheck = CreateFrame("CheckButton", "ManaHelperChatCheck", ui.toggles, "UICheckButtonTemplate")
    ui.chatCheck:SetPoint("LEFT", 55, 0)
    _G[ui.chatCheck:GetName().."Text"]:SetText("Chat")
    ui.chatCheck:SetScript("OnClick", function(self)
        local enabled = self:GetChecked()
        db().sendChatAlerts = not not enabled
        if ManaHelper.SendPing then ManaHelper:SendPing() end
        if enabled then
            local channel = IsInRaid() and "RAID" or (GetNumPartyMembers() > 0 and "PARTY" or nil)
            if channel then
                SendChatMessage("ManaHelper activado - Alertas de mana en banda.", channel)
            end
        end
        ui:RequestRefresh()
    end)

    ui.alertToggle = CreateFrame("CheckButton", "ManaHelperAlertToggle", ui.toggles, "UICheckButtonTemplate")
    ui.alertToggle:SetPoint("LEFT", 115, 0)
    _G[ui.alertToggle:GetName().."Text"]:SetText("Alerta")
    ui.alertToggle:SetScript("OnClick", function(self) db().alertsEnabled = not not self:GetChecked() end)

    -- Healer List Scroll Area (Skada-style with ScrollFrame)
    ui.listArea = CreateFrame("ScrollFrame", "ManaHelperListScrollFrame", ui, "UIPanelScrollFrameTemplate")
    ui.listArea:SetPoint("TOPLEFT", 0, -42)
    ui.listArea:SetPoint("BOTTOMRIGHT", -23, 75) -- Leave space for sliders and buttons
    
    ui.scrollChild = CreateFrame("Frame", "ManaHelperScrollChild", ui.listArea)
    ui.scrollChild:SetSize(ui.listArea:GetWidth(), 1) -- Height updated dynamically
    ui.listArea:SetScrollChild(ui.scrollChild)
    
    -- Mouse wheel support
    ui.listArea:EnableMouseWheel(true)
    ui.listArea:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local max = self:GetVerticalScrollRange()
        local step = 20
        if delta > 0 then
            self:SetVerticalScroll(math.max(0, cur - step))
        else
            self:SetVerticalScroll(math.min(max, cur + step))
        end
        ui:RequestRefresh()
    end)

    -- Healer Rows
    ui.healerRows = {}
    for i = 1, 50 do -- Generous upper bound for any raid size
        local row = CreateFrame("Button", nil, ui.scrollChild)
        row:SetHeight(16)
        row:SetPoint("TOPLEFT", 2, -(i-1)*17)
        row:SetPoint("TOPRIGHT", -2, -(i-1)*17)
        row:Hide()
        
        row.check = CreateFrame("CheckButton", "ManaHelperRowC"..i, row, "UICheckButtonTemplate")
        row.check:SetSize(20, 20)
        row.check:SetPoint("LEFT", 2, 0)
        row.check:SetScale(0.7)
        row.check:SetScript("OnClick", function(self)
            local h = ManaHelper.Healers[row:GetID()]
            if h then 
                db().monitoredHealers[h.name] = not not self:GetChecked()
                ManaHelper:UpdateHealerList()
            end
        end)

        row.bar = CreateFrame("StatusBar", nil, row)
        row.bar:SetPoint("TOPLEFT", 18, -1)
        row.bar:SetPoint("BOTTOMRIGHT", -2, 1)
        row.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        row.bar:SetMinMaxValues(0, 100)
        
        row.barBg = row.bar:CreateTexture(nil, "BACKGROUND")
        row.barBg:SetAllPoints()
        row.barBg:SetTexture(0, 0, 0, 0.4)

        row.text = row.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.text:SetPoint("LEFT", 3, 0)
        
        row.manaText = row.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.manaText:SetPoint("RIGHT", -3, 0)

        row:SetScript("OnClick", function()
            local h = ManaHelper.Healers[row:GetID()]
            if h then db().selectedHealer = h.name; ui:RefreshHealerList() end
        end)
        
        ui.healerRows[i] = row
    end

    -- Threshold Slider (Smaller)
    ui.slider = CreateFrame("Slider", "ManaHelperThresholdS", ui, "OptionsSliderTemplate")
    ui.slider:SetSize(100, 14)
    ui.slider:SetPoint("BOTTOMLEFT", 10, 52)
    ui.slider:SetScale(0.8)
    _G[ui.slider:GetName()..'Low']:SetText('10')
    _G[ui.slider:GetName()..'High']:SetText('100')
    ui.slider:SetMinMaxValues(10, 100)
    ui.slider:SetValueStep(5)
    ui.slider:SetScript("OnValueChanged", function(self, val)
        val = math.floor(val)
        _G[self:GetName()..'Text']:SetText("Inicio: "..val.."%")
        db().threshold = val
        ui:RequestRefresh()
    end)

    -- Step Slider (New)
    ui.stepSlider = CreateFrame("Slider", "ManaHelperStepS", ui, "OptionsSliderTemplate")
    ui.stepSlider:SetSize(100, 14)
    ui.stepSlider:SetPoint("BOTTOMRIGHT", -10, 52)
    ui.stepSlider:SetScale(0.8)
    _G[ui.stepSlider:GetName()..'Low']:SetText('5')
    _G[ui.stepSlider:GetName()..'High']:SetText('50')
    ui.stepSlider:SetMinMaxValues(5, 50)
    ui.stepSlider:SetValueStep(5)
    ui.stepSlider:SetScript("OnValueChanged", function(self, val)
        val = math.floor(val)
        _G[self:GetName()..'Text']:SetText("Paso: "..val.."%")
        db().stepPercent = val
        ui:RequestRefresh()
    end)

    -- Alert Interval Slider
    ui.intervalSlider = CreateFrame("Slider", "ManaHelperIntervalS", ui, "OptionsSliderTemplate")
    ui.intervalSlider:SetSize(100, 14)
    ui.intervalSlider:SetPoint("BOTTOMLEFT", 10, 30)
    ui.intervalSlider:SetScale(0.8)
    _G[ui.intervalSlider:GetName()..'Low']:SetText('5s')
    _G[ui.intervalSlider:GetName()..'High']:SetText('120s')
    ui.intervalSlider:SetMinMaxValues(5, 120)
    ui.intervalSlider:SetValueStep(5)
    ui.intervalSlider:SetScript("OnValueChanged", function(self, val)
        val = math.floor(val)
        _G[self:GetName()..'Text']:SetText("CD: "..val.."s")
        db().alertInterval = val
        ui:RequestRefresh()
    end)

    -- Bottom Buttons (Mini)
    ui.focusBtn = CreateFrame("Button", "ManaHelperFocusB", ui, "SecureActionButtonTemplate, UIPanelButtonTemplate")
    ui.focusBtn:SetSize(65, 18)
    ui.focusBtn:SetPoint("BOTTOMLEFT", 5, 5)
    ui.focusBtn:SetText("Focus")
    ui.focusBtn:SetScale(0.85)
    ui.focusBtn:SetAttribute("type", "macro")
    ui.focusBtn:SetScript("PreClick", function(self)
        if db().selectedHealer then self:SetAttribute("macrotext", "/focus "..db().selectedHealer) end
    end)

    ui.alertBtn = CreateFrame("Button", nil, ui, "UIPanelButtonTemplate")
    ui.alertBtn:SetSize(65, 18)
    ui.alertBtn:SetPoint("BOTTOMRIGHT", -5, 5)
    ui.alertBtn:SetText("Alerta")
    ui.alertBtn:SetScale(0.85)
    ui.alertBtn:SetScript("OnClick", function()
        if not ManaHelper.Healers then return end
        local alertedAny = false
        for i, h in ipairs(ManaHelper.Healers) do
            if db().monitoredHealers[h.name] and not UnitIsDeadOrGhost(h.unit) and UnitIsConnected(h.unit) then
                local cur, max = UnitMana(h.unit), UnitManaMax(h.unit)
                local pct = (max > 0) and (cur/max*100) or 0
                if pct <= db().threshold then
                    -- Visual alert + sound for the user
                    local visMsg = string.format("|cffff0000%s|r bajo de mana! (%d%%)", h.name, math.floor(pct))
                    if ui.ShowVisualAlert then ui:ShowVisualAlert(visMsg) end
                    PlaySoundFile(db().alertSound)

                    -- Chat alert
                    local chatMsg = string.format("¡Atención! %s necesita ayuda con el mana! (%d%%)", h.name, math.floor(pct))
                    local channel = "SAY"
                    if IsInRaid() then
                        local canRW = false
                        for idx = 1, GetNumRaidMembers() do
                            local r_n, rank = GetRaidRosterInfo(idx)
                            if r_n == UnitName("player") and rank > 0 then
                                canRW = true
                                break
                            end
                        end
                        channel = canRW and "RAID_WARNING" or "RAID"
                    elseif GetNumPartyMembers() > 0 then
                        channel = "PARTY"
                    end

                    SendChatMessage(chatMsg, channel)
                    alertedAny = true
                end
            end
        end
        if not alertedAny then
             print("|cff00ff00ManaHelper:|r Ningún sanador marcado está por debajo del "..db().threshold.."% de mana.")
        end
    end)

    -- Custom Alert UI (only create once)
    if not ManaHelper.Alert then
        ManaHelper.Alert = CreateFrame("Frame", "ManaHelperAlertOverlay", UIParent)
        local alert = ManaHelper.Alert
        alert:SetSize(400, 50)
        alert:SetMovable(true)
        alert:RegisterForDrag("LeftButton")
        alert:SetScript("OnDragStart", alert.StartMoving)
        alert:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            local pt, _, _, x, y = self:GetPoint()
            db().alertPosition = { point = pt, x = x, y = y }
        end)
        alert.bg = alert:CreateTexture(nil, "BACKGROUND")
        alert.bg:SetAllPoints()
        alert.bg:SetTexture(0, 0, 0, 0.5)
        alert.bg:Hide()
        alert.text = alert:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
        alert.text:SetPoint("CENTER")
        if db().alertPosition then alert:SetPoint(db().alertPosition.point, db().alertPosition.x, db().alertPosition.y)
        else alert:SetPoint("TOP", 0, -100) end
    end
end

function ui:RefreshHealerList()
    if not ui.healerRows or not ManaHelper.Healers or not ui.slider then return end
    
    local numHealers = #ManaHelper.Healers
    local scrollHeight = math.max(1, numHealers * 17)
    local scrollWidth = ui.listArea:GetWidth()
    
    if ui.scrollChild:GetHeight() ~= scrollHeight then
        ui.scrollChild:SetHeight(scrollHeight)
    end
    if ui.scrollChild:GetWidth() ~= scrollWidth then
        ui.scrollChild:SetWidth(scrollWidth)
    end
    
    -- Style the default scrollbar to be more subtle
    local sb = _G[ui.listArea:GetName().."ScrollBar"]
    if sb then
        sb:SetScale(0.8)
    end
    
    -- Only update visible rows to reduce UnitMana calls in raids.
    local rowHeight = 17
    local scrollY = ui.listArea:GetVerticalScroll() or 0
    local viewH = ui.listArea:GetHeight() or 0
    local firstIndex = math.floor(scrollY / rowHeight) + 1
    if firstIndex < 1 then firstIndex = 1 end
    local visibleRows = math.ceil(viewH / rowHeight) + 1
    local lastIndex = math.min(numHealers, firstIndex + visibleRows - 1)

    for i, row in ipairs(ui.healerRows) do
        local h = ManaHelper.Healers[i]
        if h and i >= firstIndex and i <= lastIndex then
            if not row:IsShown() then row:Show() end
            row:SetID(i)
            local unit = h.unit
            local cur, max = UnitMana(unit), UnitManaMax(unit)
            local pct = (max > 0) and (cur / max * 100) or 0

            row.check:SetChecked(db().monitoredHealers[h.name])
            local color = "|cff" .. (ManaHelper.ClassColors[h.class] or "ffffff")
            local selected = (db().selectedHealer == h.name)

            row.text:SetText(color .. h.name .. (selected and " |cff00ff00[S]|r" or ""))
            row.manaText:SetText(math.floor(pct) .. "%")
            row.bar:SetValue(pct)
            row.bar:SetStatusBarColor(selected and 0.2 or 0, selected and 0.8 or 0.6, selected and 0.2 or 1, 0.7)
        else
            if row:IsShown() then row:Hide() end
        end
    end
    -- Sync main toggles
    ui.bgCheck:SetChecked(db().backgroundMode)
    ui.chatCheck:SetChecked(db().sendChatAlerts)
    ui.alertToggle:SetChecked(db().alertsEnabled)
    ui.slider:SetValue(db().threshold)
    _G[ui.slider:GetName()..'Text']:SetText("Inicio: "..db().threshold.."%")
    ui.stepSlider:SetValue(db().stepPercent)
    _G[ui.stepSlider:GetName()..'Text']:SetText("Paso: "..db().stepPercent.."%")
    ui.intervalSlider:SetValue(db().alertInterval)
    _G[ui.intervalSlider:GetName()..'Text']:SetText("CD: "..db().alertInterval.."s")
end

-- Throttled refresh: avoid full list rebuild every frame.
function ui:RequestRefresh()
    if not ui:IsShown() or ui._refreshScheduled then return end
    ui._refreshScheduled = true
    ManaHelper:ScheduleTimer(function()
        ui._refreshScheduled = false
        if ui:IsShown() then
            ui:RefreshHealerList()
        end
    end, 0.25)
end

function ui:ShowVisualAlert(msg)
    if ManaHelper.Alert.isMoving then return end -- Don't interrupt moving mode
    ManaHelper.Alert:SetAlpha(1.0)
    ManaHelper.Alert.text:SetText(msg)
    ManaHelper.Alert.bg:Hide()
    ManaHelper.Alert:EnableMouse(false) -- Ensure clicks pass through during alerts
    ManaHelper.Alert:Show()
    UIFrameFadeOut(ManaHelper.Alert, 4.0, 1.0, 0.0)
end

-- Minimap Button with LibDBIcon
local function SetupMinimap()
    if not LDB or not LDBIcon then return end
    local MHobj = LDB:NewDataObject("ManaHelper", {
        type = "launcher",
        text = "ManaHelper",
        icon = "Interface\\AddOns\\Manahelper\\icon.tga",
        OnClick = function() 
            if ui:IsShown() then ui:Hide(); db().showWindow = false else ui:Show(); db().showWindow = true end 
        end,
        OnTooltipShow = function(tt)
            tt:AddLine("|cff00ff00ManaHelper|r")
            tt:AddLine("Clic: Mostrar/Ocultar ventana")
        end,
    })
    LDBIcon:Register("ManaHelper", MHobj, ManaHelper.db.profile.minimap)
end

-- Initialize UI through the Addon Object
function ManaHelper:OnEnableUI()
    ui:CreateMainWindow()
    SetupMinimap()
    ui:RefreshHealerList()
    if db().showWindow then ui:Show() else ui:Hide() end
end

-- Slash Command via AceConsole
function ManaHelper:SlashHandler(msg)
    msg = msg and msg:trim() or ""
    local lower = msg:lower()
    if lower == "help" or lower == "ayuda" then
        print("|cff00ff00ManaHelper - Ayuda y Comandos:|r")
        print("  |cff00ffff/mh|r o |cff00ffff/manahelper|r : Abre o cierra la ventana principal.")
        print("  |cff00ffff/mh help|r o |cff00ffffayuda|r : Muestra este mensaje de ayuda.")
        print("  |cff00ffff/mh test|r : Lanza una alerta visual de prueba.")
        print("  |cff00ffff/mh ver|r o |cff00ffffversion|r : Muestra las versiones de los miembros del grupo.")
        print("  |cff00ffff/mh sound <ruta>|r : Cambia el sonido de alerta. Ej: /mh sound Sound\\\\Interface\\\\RaidWarning.wav")
        print(" ")
        print("  |cff00ff00Configuración:|r")
        print("  - Usa la ventana principal para marcar qué healers monitorear.")
        print("  - |cff00ffffInicio|r: Umbral de maná para iniciar alertas.")
        print("  - |cff00ffffPaso|r: Porcentaje de caída requerido para siguientes alertas.")
        print("  - |cff00ffffCD|r: Tiempo mínimo entre alertas críticas.")
        print("  - Botón de |cff00ffffEngranaje|r: Permite arrastrar la alerta en pantalla.")
        print("  - |cff00ffff/mh sound <ruta>|r: Personaliza el sonido de alerta.")
        return
    elseif lower == "test" then
        if not self.UI or not self.UI.ShowVisualAlert then
            if self.OnEnableUI then self:OnEnableUI() end
        end
        if self.UI and self.UI.ShowVisualAlert then
            self.UI:ShowVisualAlert("|cff00ff00Prueba de ManaHelper:|r ¡Alerta en pantalla funcionando!")
            PlaySoundFile(db().alertSound)
        end
        return
    elseif lower == "ver" or lower == "version" then
        if ManaHelper.PrintVersions then
            ManaHelper:PrintVersions()
        end
        return
    elseif lower:match("^sound ") then
        local soundPath = msg:match("^[Ss][Oo][Uu][Nn][Dd] (.+)$")
        if soundPath and soundPath ~= "" then
            db().alertSound = soundPath
            print("|cff00ff00ManaHelper:|r Sonido de alerta cambiado a: " .. soundPath)
            PlaySoundFile(soundPath)
        else
            print("|cff00ff00ManaHelper:|r Uso: /mh sound <ruta>")
        end
        return
    end

    if ManaHelper.db then
        if ui:IsShown() then ui:Hide(); db().showWindow = false else ui:Show(); db().showWindow = true end
    end
end
ManaHelper:RegisterChatCommand("manahelper", "SlashHandler")
ManaHelper:RegisterChatCommand("manahelp", "SlashHandler")
ManaHelper:RegisterChatCommand("mh", "SlashHandler")

-- End of UI Logic
