-- ManaHelper Core Logic (Ace3 Integrated)
ManaHelper = LibStub("AceAddon-3.0"):NewAddon("ManaHelper", "AceEvent-3.0", "AceConsole-3.0", "AceTimer-3.0")

-- Fallback for Ambiguate in older WoW clients (like 3.3.5a) where it does not exist
local Ambiguate = Ambiguate or function(name, context)
    if not name then return nil end
    return name:match("([^%-]+)") or name
end

-- WoW 3.3.5a does not provide string.trim by default; ui.lua uses msg:trim().
if not string.trim then
    function string.trim(s)
        return (s and s:match("^%s*(.-)%s*$")) or ""
    end
end

-- Helper: checks if a class is a healer class
local function IsHealerClass(class)
    return class == "PRIEST" or class == "PALADIN" or class == "SHAMAN" or class == "DRUID"
end

-- Class colors for display (used by ui.lua)
ManaHelper.ClassColors = {
    PRIEST = "ffffff",
    PALADIN = "f58cba",
    SHAMAN = "0070de",
    DRUID = "ff7d0a",
}

-- Default Settings
local defaults = {
    profile = {
        threshold = 80,
        monitoredHealers = {},
        showWindow = true,
        alertsEnabled = true,
        backgroundMode = true,
        sendChatAlerts = true,
        width = 250,
        height = 400,
        framePosition = { point = "CENTER", x = 0, y = 0 },
        alertPosition = { point = "TOP", x = 0, y = -100 },
        alertInterval = 120,
        stepPercent = 10,
        selectedHealer = nil,
        alertSound = "Sound\\Interface\\RaidWarning.wav",
        minimap = {
            hide = false,
            minimapPos = 45,
        },
    }
}

-- Healer List Management
ManaHelper.Healers = {}

-- Mana Monitoring State
local lastAlerts = {}
local lastAlertPercent = {}
local lastManaCheck = {}

-- Consider a group user "active" only if we've seen a ping/pong recently.
local GROUPUSER_TTL = 15

function ManaHelper:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("ManaHelperDB", defaults, true)
end

function ManaHelper:OnEnable()
    self.GroupUsers = {}
    self.GroupUsersSeen = {}
    self.RemoteVersions = {}
    local pName = UnitName("player")
    if pName then
        self.GroupUsers[pName] = true
        self.GroupUsersSeen[pName] = GetTime()
    end

    self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateHealerList")
    self:RegisterEvent("RAID_ROSTER_UPDATE", "UpdateHealerList")
    self:RegisterEvent("PARTY_MEMBERS_CHANGED", "UpdateHealerList")
    self:RegisterEvent("UNIT_MANA", "CheckManaEvent")
    self:RegisterEvent("CHAT_MSG_ADDON", "ReceiveAddonMessage")
    
    -- 3.3.5a uses RegisterAddonMessagePrefix (RegisterAddonPrefix is not a thing there)
    if RegisterAddonMessagePrefix then
        RegisterAddonMessagePrefix("ManaHelper")
    end
    
    if self.OnEnableUI then self:OnEnableUI() end
    self:UpdateHealerList()
    self:SendPing()
    
    self:Print("ManaHelper Activado. Escribe /mh o usa el icono para ver la ventana.")
end

function ManaHelper:UpdateHealerList()
    self.Healers = {}
    local numRaid = GetNumRaidMembers()
    local numParty = GetNumPartyMembers()

    if numRaid > 0 then
        for i = 1, numRaid do
            local name, _, _, _, _, class = GetRaidRosterInfo(i)
            if IsHealerClass(class) then
                table.insert(self.Healers, { name = name, class = class, unit = "raid"..i })
            end
        end
    elseif numParty > 0 then
        -- Player
        local _, class = UnitClass("player")
        if IsHealerClass(class) then
            table.insert(self.Healers, { name = UnitName("player"), class = class, unit = "player" })
        end
        -- Party
        for i = 1, numParty do
            local unit = "party"..i
            local name = UnitName(unit)
            local _, class = UnitClass(unit)
            if IsHealerClass(class) then
                table.insert(self.Healers, { name = name, class = class, unit = unit })
            end
        end
    else
        -- Solo (testing)
        local _, class = UnitClass("player")
        table.insert(self.Healers, { name = UnitName("player"), class = class, unit = "player" })
    end

    -- Sort: monitored healers first, then by name
    table.sort(self.Healers, function(a, b)
        local monitored = ManaHelper.db.profile.monitoredHealers
        local aMon = monitored[a.name] and 1 or 0
        local bMon = monitored[b.name] and 1 or 0
        
        if aMon ~= bMon then
            return aMon > bMon
        end
        return a.name < b.name
    end)

    -- Clean up stale mana tracking entries for healers who left
    local validNames = {}
    for _, h in ipairs(self.Healers) do
        validNames[h.name] = true
    end
    for name in pairs(lastAlerts) do
        if not validNames[name] then lastAlerts[name] = nil end
    end
    for name in pairs(lastAlertPercent) do
        if not validNames[name] then lastAlertPercent[name] = nil end
    end
    for k in pairs(lastManaCheck) do
        lastManaCheck[k] = nil
    end

    if self.UI and self.UI.RefreshHealerList then
        self.UI:RefreshHealerList()
    end

    -- Clean up GroupUsers to keep only active group members
    local activeGroup = {}
    local pName = UnitName("player")
    if pName then activeGroup[pName] = true end
    
    if numRaid > 0 then
        for i = 1, numRaid do
            local name = GetRaidRosterInfo(i)
            if name then activeGroup[name] = true end
        end
    elseif numParty > 0 then
        for i = 1, numParty do
            local name = UnitName("party"..i)
            if name then activeGroup[name] = true end
        end
    end
    
    if not self.GroupUsers then self.GroupUsers = {} end
    if not self.GroupUsersSeen then self.GroupUsersSeen = {} end
    for user in pairs(self.GroupUsers) do
        if not activeGroup[user] then
            self.GroupUsers[user] = nil
            self.GroupUsersSeen[user] = nil
        end
    end

    if not self.RemoteVersions then self.RemoteVersions = {} end
    for user in pairs(self.RemoteVersions) do
        if not activeGroup[user] then
            self.RemoteVersions[user] = nil
        end
    end

    self:SendPing()
end

function ManaHelper:CleanupGroupUsers()
    if not self.GroupUsers or not self.GroupUsersSeen then return end
    local now = GetTime()
    for user in pairs(self.GroupUsers) do
        if user ~= UnitName("player") then
            local seen = self.GroupUsersSeen[user]
            if not seen or (now - seen) > GROUPUSER_TTL then
                self.GroupUsers[user] = nil
                self.GroupUsersSeen[user] = nil
            end
        end
    end
end

-- Addon Synchronization and Designated Sender Logic
function ManaHelper:SendPing()
    if not IsInInstance() and GetNumRaidMembers() == 0 and GetNumPartyMembers() == 0 then
        self.GroupUsers = {}
        self.GroupUsersSeen = {}
        self.RemoteVersions = {}
        local pName = UnitName("player")
        if pName then
            self.GroupUsers[pName] = true
            self.GroupUsersSeen[pName] = GetTime()
        end
        return
    end
    
    local channel = IsInRaid() and "RAID" or (GetNumPartyMembers() > 0 and "PARTY" or nil)
    if channel then
        local hasChat = self.db.profile.sendChatAlerts and "1" or "0"
        local version = GetAddOnMetadata("Manahelper", "Version") or "V2"
        SendAddonMessage("ManaHelper", "PING:" .. hasChat .. ":" .. version, channel)
    end

    self:CleanupGroupUsers()
end

function ManaHelper:PrintVersions()
    local myName = UnitName("player")
    local myVer = GetAddOnMetadata("Manahelper", "Version") or "V2"

    if GetNumRaidMembers() == 0 and GetNumPartyMembers() == 0 then
        print("|cff00ff00ManaHelper|r: Versión |cff00ffff" .. myVer .. "|r")
        return
    end

    -- Trigger a ping so others refresh RemoteVersions.
    self:SendPing()
    self:ScheduleTimer(function()
        local versions = {}
        versions[myName or "Jugador"] = myVer
        if self.RemoteVersions then
            for n, v in pairs(self.RemoteVersions) do
                versions[n] = v
            end
        end

        local names = {}
        for n in pairs(versions) do
            table.insert(names, n)
        end
        table.sort(names)

        print("|cff00ff00ManaHelper|r: Versiones detectadas:")
        for _, n in ipairs(names) do
            print("  " .. n .. ": |cff00ffff" .. tostring(versions[n] or "?") .. "|r")
        end
    end, 1.0)
end

function ManaHelper:ReceiveAddonMessage(event, prefix, msg, channel, sender)
    if prefix ~= "ManaHelper" then return end

    -- Only accept group traffic to avoid processing whispers/guild/etc.
    if channel ~= "RAID" and channel ~= "PARTY" then return end
     
    local name = Ambiguate(sender, "none")
    if name == UnitName("player") then return end
    
    local cmd, p1, p2 = msg:match("^([^:]+):([^:]+):([^:]+)$")
    if not cmd then
        cmd, p1 = msg:match("^([^:]+):([^:]+)$")
    end
    if not cmd then return end
    
    if not self.GroupUsers then self.GroupUsers = {} end
    if not self.GroupUsersSeen then self.GroupUsersSeen = {} end
    if not self.RemoteVersions then self.RemoteVersions = {} end
    
    local version = GetAddOnMetadata("Manahelper", "Version") or "V2"
    
    if cmd == "PING" then
        local hasChat = self.db.profile.sendChatAlerts and "1" or "0"
        SendAddonMessage("ManaHelper", "PONG:" .. hasChat .. ":" .. version, channel)
        if p1 == "1" then
            self.GroupUsers[name] = true
        else
            self.GroupUsers[name] = nil
        end
        self.GroupUsersSeen[name] = GetTime()
        if p2 and p2 ~= "" then
            self.RemoteVersions[name] = p2
        else
            self.RemoteVersions[name] = "V1"
        end
    elseif cmd == "PONG" then
        if p1 == "1" then
            self.GroupUsers[name] = true
        else
            self.GroupUsers[name] = nil
        end
        self.GroupUsersSeen[name] = GetTime()
        if p2 and p2 ~= "" then
            self.RemoteVersions[name] = p2
        else
            self.RemoteVersions[name] = "V1"
        end
    end
end

function ManaHelper:IsDesignatedSender()
    if not self.db.profile.sendChatAlerts then return false end
    if GetNumRaidMembers() == 0 and GetNumPartyMembers() == 0 then
        return true
    end

    self:CleanupGroupUsers()
    
    local list = {}
    if not self.GroupUsers then self.GroupUsers = {} end
    if not self.GroupUsersSeen then self.GroupUsersSeen = {} end
    local pName = UnitName("player")
    if pName then
        self.GroupUsers[pName] = true
        self.GroupUsersSeen[pName] = GetTime()
    end
    
    for user in pairs(self.GroupUsers) do
        table.insert(list, user)
    end
    
    if #list <= 1 then
        return true
    end
    
    -- Local helper to get the dynamic raid/party priority rank of any player (Leader = 2, Officer = 1, Member = 0)
    local function GetPlayerPriority(name)
        if name == pName then
            if IsInRaid() then
                for i = 1, GetNumRaidMembers() do
                    local r_n, rank = GetRaidRosterInfo(i)
                    if r_n == name then
                        return rank -- 2 = Leader, 1 = Officer, 0 = Normal
                    end
                end
            else
                if UnitIsPartyLeader("player") then
                    return 2
                end
            end
            return 0
        end
        
        if IsInRaid() then
            for i = 1, GetNumRaidMembers() do
                local r_n, rank = GetRaidRosterInfo(i)
                if r_n == name then
                    return rank
                end
            end
        elseif GetNumPartyMembers() > 0 then
            for i = 1, GetNumPartyMembers() do
                local unit = "party" .. i
                if UnitName(unit) == name then
                    if UnitIsPartyLeader(unit) then
                        return 2
                    end
                    break
                end
            end
        end
        return 0
    end
    
    -- Sort first by group rank priority (highest first) and alphabetically as secondary sort
    table.sort(list, function(a, b)
        local prioA = GetPlayerPriority(a)
        local prioB = GetPlayerPriority(b)
        if prioA ~= prioB then
            return prioA > prioB
        end
        return a < b
    end)
    
    return list[1] == pName
end

-- Mana Monitoring and Alert Logic

function ManaHelper:CheckManaEvent(event, unit)
    if not self.db or not self.UI or not self.UI.ShowVisualAlert then return end
    if not self.db.profile.alertsEnabled then return end
    if not self.db.profile.backgroundMode and not self.UI:IsShown() then return end

    local name = UnitName(unit)
    if not name or UnitIsDeadOrGhost(unit) or not UnitIsConnected(unit) then return end
    if self.db.profile.monitoredHealers[name] then
        -- UNIT_MANA can fire extremely frequently in 3.3.5a; throttle per unit.
        local now = GetTime()
        if lastManaCheck[unit] and (now - lastManaCheck[unit] < 0.25) then
            return
        end
        lastManaCheck[unit] = now

        -- UI refresh is relatively expensive; request a throttled refresh when visible.
        if self.UI.RequestRefresh and self.UI:IsShown() then
            self.UI:RequestRefresh()
        end
        -- 3.3.5a: use UnitMana/UnitManaMax (UnitPower was introduced later).
        local current = UnitMana(unit)
        local max = UnitManaMax(unit)
        
        if max > 0 then
            local percent = (current / max) * 100
            local step = self.db.profile.stepPercent or 10
            local threshold = self.db.profile.threshold or 80
            local cooldown = self.db.profile.alertInterval or 120

            -- Reset alert state if mana is above the threshold
            if percent > threshold then
                lastAlertPercent[name] = nil
            else
                -- Mana is <= threshold
                local timePassed = (not lastAlerts[name]) or (now - lastAlerts[name] >= cooldown)
                local shouldAlert = false

                if lastAlertPercent[name] == nil then
                    -- First alert when crossing the threshold
                    shouldAlert = true
                    lastAlertPercent[name] = threshold
                else
                    -- We have already alerted. Check if mana dropped by another full step
                    local nextAlertTarget = lastAlertPercent[name] - step
                    if percent <= nextAlertTarget then
                        shouldAlert = true
                        -- Update the alert percent to the new step reached
                        local droppedSteps = math.floor((lastAlertPercent[name] - percent) / step)
                        lastAlertPercent[name] = lastAlertPercent[name] - (droppedSteps * step)
                    elseif percent <= 20 and timePassed then
                        -- Critical periodic alert when under 20%
                        shouldAlert = true
                    end
                end

                -- If mana increased since the last alert (e.g. pot, innervate, passive regen),
                -- update lastAlertPercent upwards accordingly
                if lastAlertPercent[name] and percent > lastAlertPercent[name] then
                    local stepsUp = math.floor((percent - lastAlertPercent[name]) / step)
                    if stepsUp > 0 then
                        lastAlertPercent[name] = math.min(threshold, lastAlertPercent[name] + stepsUp * step)
                    end
                end

                if shouldAlert then
                    -- Visual Alert (siempre para el usuario)
                    local msg = string.format("|cffff0000%s|r bajo de mana! (%d%%)", name, math.floor(percent))
                    self.UI:ShowVisualAlert(msg)
                    PlaySoundFile(self.db.profile.alertSound)

                    -- Chat Alerts solo si está habilitado y corresponden
                    if self.db.profile.sendChatAlerts and self:IsDesignatedSender() then
                        local publicMsg = string.format("¡Atención! %s tiene poco mana! (%d%%)", name, math.floor(percent))
                        local channel = "SAY"

                        if IsInRaid() then
                            local canRW = false
                            for i = 1, GetNumRaidMembers() do
                                local r_n, rank = GetRaidRosterInfo(i)
                                if r_n == UnitName("player") and rank > 0 then canRW = true; break end
                            end
                            channel = canRW and "RAID_WARNING" or "RAID"
                        elseif GetNumPartyMembers() > 0 then
                            channel = "PARTY"
                        end

                        SendChatMessage(publicMsg, channel)
                    end

                    lastAlerts[name] = now
                end
            end
        end
    end
end
