-- =============================================================
-- MyQuestLog - Enhanced Default Quest Log for WoW Forever
-- =============================================================
local ADDON_NAME, MQS = ...
_G["MyQuestLog"] = MQS

local ADDON_PREFIX = "MYQUESTLOG"
local LEGACY_PREFIX = "MQS"

MQS.queue = {}
MQS.isProcessingQueue = false
MQS.originalSelection = nil
MQS.matchingQuests = {}
MQS.groupAccepted = {}
MQS.groupShared = {}
MQS.lastSharedZone = nil
MQS.peerQuests = {}
MQS.peerVersions = {}
MQS.currentFilter = nil

local defaultSettings = {
    autoShare = true,
    smartShare = true,
    silentShare = false,
    showLevels = true,
}

-- -------------------------------------------------------------
-- Strict Dungeon to Quest Header Mapping (Dungeon category only)
-- -------------------------------------------------------------
MQS.DUNGEON_TO_QUEST_HEADERS = {
    -- Classic Era Dungeons
    ["Ragefire Chasm"] = { "Ragefire Chasm" },
    ["The Deadmines"] = { "Deadmines", "The Deadmines" },
    ["Deadmines"] = { "Deadmines", "The Deadmines" },
    ["Wailing Caverns"] = { "Wailing Caverns" },
    ["Shadowfang Keep"] = { "Shadowfang Keep" },
    ["Blackfathom Deeps"] = { "Blackfathom Deeps" },
    ["The Stockade"] = { "The Stockade", "Stockade" },
    ["Stockade"] = { "The Stockade", "Stockade" },
    ["Gnomeregan"] = { "Gnomeregan" },
    ["Razorfen Kraul"] = { "Razorfen Kraul" },
    ["Razorfen Downs"] = { "Razorfen Downs" },
    ["Scarlet Monastery"] = { "Scarlet Monastery" },
    ["Uldaman"] = { "Uldaman" },
    ["Zul'Farrak"] = { "Zul'Farrak" },
    ["Maraudon"] = { "Maraudon" },
    ["The Temple of Atal'Hakkar"] = { "Sunken Temple", "The Temple of Atal'Hakkar" },
    ["Sunken Temple"] = { "Sunken Temple", "The Temple of Atal'Hakkar" },
    ["Blackrock Depths"] = { "Blackrock Depths" },
    ["Lower Blackrock Spire"] = { "Blackrock Spire", "Lower Blackrock Spire" },
    ["Upper Blackrock Spire"] = { "Blackrock Spire", "Upper Blackrock Spire" },
    ["Blackrock Spire"] = { "Blackrock Spire" },
    ["Scholomance"] = { "Scholomance" },
    ["Stratholme"] = { "Stratholme" },
    ["Dire Maul"] = { "Dire Maul" },
    
    -- Classic Era Raids
    ["Molten Core"] = { "Molten Core" },
    ["Onyxia's Lair"] = { "Onyxia's Lair" },
    ["Blackwing Lair"] = { "Blackwing Lair" },
    ["Zul'Gurub"] = { "Zul'Gurub" },
    ["Ruins of Ahn'Qiraj"] = { "Ahn'Qiraj", "Ruins of Ahn'Qiraj" },
    ["Temple of Ahn'Qiraj"] = { "Ahn'Qiraj", "Temple of Ahn'Qiraj" },
    ["Naxxramas"] = { "Naxxramas" },

    -- TBC Dungeons & Raids
    ["Hellfire Ramparts"] = { "Hellfire Ramparts" },
    ["The Blood Furnace"] = { "Blood Furnace", "The Blood Furnace" },
    ["The Shattered Halls"] = { "Shattered Halls", "The Shattered Halls" },
    ["Magtheridon's Lair"] = { "Magtheridon's Lair" },
    ["The Slave Pens"] = { "Slave Pens", "The Slave Pens" },
    ["The Underbog"] = { "Underbog", "The Underbog" },
    ["The Steamvault"] = { "Steamvault", "The Steamvault" },
    ["Serpentshrine Cavern"] = { "Serpentshrine Cavern", "Serpentshrine" },
    ["Mana-Tombs"] = { "Mana-Tombs", "Mana Tombs" },
    ["Auchenai Crypts"] = { "Auchenai Crypts" },
    ["Sethekk Halls"] = { "Sethekk Halls" },
    ["Shadow Labyrinth"] = { "Shadow Labyrinth" },
    ["The Botanica"] = { "The Botanica", "Botanica" },
    ["The Mechanar"] = { "The Mechanar", "Mechanar" },
    ["The Arcatraz"] = { "The Arcatraz", "Arcatraz" },
    ["The Eye"] = { "The Eye", "Tempest Keep" },
    ["Escape from Durnholde Keep"] = { "Old Hillsbrad", "Durnholde", "Escape from Durnholde Keep" },
    ["Old Hillsbrad Foothills"] = { "Old Hillsbrad", "Old Hillsbrad Foothills" },
    ["The Black Morass"] = { "Black Morass", "The Black Morass" },
    ["Opening of the Dark Portal"] = { "Black Morass", "Opening of the Dark Portal" },
    ["Battle for Mount Hyjal"] = { "Mount Hyjal", "Hyjal", "Battle for Mount Hyjal" },
    ["Hyjal Summit"] = { "Mount Hyjal", "Hyjal Summit" },
    ["Black Temple"] = { "Black Temple" },
    ["Gruul's Lair"] = { "Gruul's Lair" },
    ["Sunwell Plateau"] = { "Sunwell Plateau", "Sunwell" },
    ["Magisters' Terrace"] = { "Magisters' Terrace" },
}

-- -------------------------------------------------------------
-- Secret Value Protection & Safe Wrappers (WoW Forever / 11.0+)
-- -------------------------------------------------------------
local function IsSecret(v)
    return (issecretvalue and issecretvalue(v)) or false
end

local function SafeCall(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a = pcall(fn, ...)
    if not ok then return nil end
    if IsSecret(a) then
        return nil
    end
    return a
end

-- -------------------------------------------------------------
-- Compatibility Layer for Classic & Modern API
-- -------------------------------------------------------------
function MQS:GetNumEntries()
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries then
        return C_QuestLog.GetNumQuestLogEntries()
    elseif GetNumQuestLogEntries then
        return GetNumQuestLogEntries()
    end
    return 0
end
local GetNumEntries = function() return MQS:GetNumEntries() end

function MQS:GetQuestInfo(index)
    if C_QuestLog and C_QuestLog.GetInfo then
        local info = C_QuestLog.GetInfo(index)
        if info then
            local isHeader = info.isHeader
            if isHeader == nil then
                isHeader = (info.questID == 0 or info.questID == nil)
            end
            local isCollapsed = info.isCollapsed or false
            local isComplete = false
            if info.questID then
                isComplete = (C_QuestLog.IsComplete and C_QuestLog.IsComplete(info.questID)) or (info.isComplete == 1 or info.isComplete == true)
            end
            local level = info.level or 0
            return info.title, isHeader, info.questID, isCollapsed, isComplete, level
        end
    elseif GetQuestLogTitle then
        local title, level, questTag, isHeader, isCollapsed, isComplete, frequency, questID = GetQuestLogTitle(index)
        local complete = (isComplete == 1 or isComplete == true)
        return title, isHeader, questID, isCollapsed, complete, level or 0
    end
    return nil, nil, nil, false, false, 0
end
local GetQuestInfo = function(index) return MQS:GetQuestInfo(index) end

function MQS:GetDifficultyColorHex(level)
    if not level or level == 0 then return "|cFFFFFFFF" end
    local color = GetQuestDifficultyColor and GetQuestDifficultyColor(level)
    if color then
        local rHex = string.format("%02x", math.floor(color.r * 255))
        local gHex = string.format("%02x", math.floor(color.g * 255))
        local bHex = string.format("%02x", math.floor(color.b * 255))
        return "|cFF" .. rHex .. gHex .. bHex
    end
    return "|cFFFFFFFF"
end
local GetDifficultyColorHex = function(level) return MQS:GetDifficultyColorHex(level) end

local function IsQuestShareable(index, questID)
    if not questID and index and C_QuestLog and C_QuestLog.GetInfo then
        local info = C_QuestLog.GetInfo(index)
        if info then questID = info.questID end
    end
    
    if questID and C_QuestLog and C_QuestLog.IsPushableQuest then
        local pushable = C_QuestLog.IsPushableQuest(questID)
        if pushable ~= nil then
            return pushable == true or pushable == 1
        end
    end
    
    local logIndex = index
    if questID and C_QuestLog and C_QuestLog.GetLogIndexForQuestID then
        local fetched = C_QuestLog.GetLogIndexForQuestID(questID)
        if fetched and fetched > 0 then logIndex = fetched end
    end
    
    if GetQuestLogPushable then
        if logIndex and SelectQuestLogEntry then
            local cur = GetQuestLogSelection and GetQuestLogSelection()
            SelectQuestLogEntry(logIndex)
            local pushable = GetQuestLogPushable()
            if cur then SelectQuestLogEntry(cur) end
            if pushable ~= nil then return pushable == true or pushable == 1 end
        end
        if questID and C_QuestLog and C_QuestLog.SetSelectedQuest then
            local cur = C_QuestLog.GetSelectedQuest and C_QuestLog.GetSelectedQuest()
            C_QuestLog.SetSelectedQuest(questID)
            local pushable = GetQuestLogPushable()
            if cur then C_QuestLog.SetSelectedQuest(cur) end
            if pushable ~= nil then return pushable == true or pushable == 1 end
        end
    end
    return true
end

local function GetSelectedQuestIndexOrID()
    if C_QuestLog and C_QuestLog.GetSelectedQuest then
        return C_QuestLog.GetSelectedQuest()
    elseif GetQuestLogSelection then
        return GetQuestLogSelection()
    end
    return nil
end

local function RestoreSelectedQuest(saved)
    if not saved then return end
    if C_QuestLog and C_QuestLog.SetSelectedQuest then
        pcall(C_QuestLog.SetSelectedQuest, saved)
    elseif SelectQuestLogEntry then
        pcall(SelectQuestLogEntry, saved)
    end
end

local function PushQuestToGroup(index, questID)
    if not questID and index and C_QuestLog and C_QuestLog.GetInfo then
        local info = C_QuestLog.GetInfo(index)
        if info and info.questID and info.questID > 0 then
            questID = info.questID
        end
    end
    
    local logIndex = index
    if questID and type(questID) == "number" and questID > 0 and C_QuestLog and C_QuestLog.GetLogIndexForQuestID then
        local fetched = C_QuestLog.GetLogIndexForQuestID(questID)
        if fetched and fetched > 0 then
            logIndex = fetched
        end
    end
    
    -- 1. Select the quest in the quest log across all modern and classic API generations
    if questID and type(questID) == "number" and questID > 0 and C_QuestLog and C_QuestLog.SetSelectedQuest then
        pcall(C_QuestLog.SetSelectedQuest, questID)
    end
    if logIndex and type(logIndex) == "number" and logIndex > 0 and SelectQuestLogEntry then
        pcall(SelectQuestLogEntry, logIndex)
    end
    
    -- 2. Call Blizzard's modern QuestMapFrame helper if present
    if questID and type(questID) == "number" and questID > 0 and QuestMapQuestOptions_ShareQuest then
        pcall(QuestMapQuestOptions_ShareQuest, questID)
    end
    
    -- 3. Call QuestLogPushQuest with logIndex (modern FrameXML pattern) or fallback
    if QuestLogPushQuest then
        if logIndex and type(logIndex) == "number" and logIndex > 0 then
            pcall(QuestLogPushQuest, logIndex)
        end
        if questID and type(questID) == "number" and questID > 0 and questID ~= logIndex then
            pcall(QuestLogPushQuest, questID)
        end
        pcall(QuestLogPushQuest)
    end
end

local function SendAddonMsg(prefix, msg, target)
    if not C_ChatInfo or not C_ChatInfo.SendAddOnMessage then
        if SendAddonMessage then
            if target then
                SendAddonMessage(prefix, msg, "WHISPER", target)
            elseif IsInRaid() then
                SendAddonMessage(prefix, msg, "RAID")
            elseif IsInGroup() then
                SendAddonMessage(prefix, msg, "PARTY")
            end
        end
        return
    end
    
    if target then
        C_ChatInfo.SendAddOnMessage(prefix, msg, "WHISPER", target)
    elseif IsInRaid() then
        C_ChatInfo.SendAddOnMessage(prefix, msg, "RAID")
    elseif IsInGroup() then
        C_ChatInfo.SendAddOnMessage(prefix, msg, "PARTY")
    end
end

local function RegisterPrefix(prefix)
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(prefix)
    elseif RegisterAddonMessagePrefix then
        RegisterAddonMessagePrefix(prefix)
    end
end

local function GetShortName(fullName)
    if not fullName or IsSecret(fullName) or type(fullName) ~= "string" then return nil end
    local name = string.match(fullName, "^([^-]+)")
    return name or fullName
end

-- -------------------------------------------------------------
-- Quest Tag Helper
-- -------------------------------------------------------------
local function GetQuestTag(index, questID, parentHeader)
    local tag = ""
    
    if GetQuestLogTitle and index then
        local title, level, questTag = GetQuestLogTitle(index)
        if questTag and type(questTag) == "string" then
            if questTag == "Elite" or questTag == "+" or questTag == "+ " then
                tag = "+"
            elseif questTag == "Dungeon" then
                tag = "D"
            elseif questTag == "Raid" then
                tag = "R"
            elseif questTag == "PvP" then
                tag = "P"
            end
        elseif type(questTag) == "number" and questTag > 0 then
            tag = "+"
        end
    end
    
    if tag == "" and C_QuestLog and C_QuestLog.GetQuestTagInfo and questID then
        local tagInfo = C_QuestLog.GetQuestTagInfo(questID)
        if tagInfo and tagInfo.tagName then
            if tagInfo.tagName == "Elite" or tagInfo.isElite then
                tag = "+"
            elseif tagInfo.tagName == "Dungeon" then
                tag = "D"
            elseif tagInfo.tagName == "Raid" then
                tag = "R"
            elseif tagInfo.tagName == "PvP" then
                tag = "P"
            end
        end
    end
    
    if tag == "" and parentHeader then
        local pLower = string.lower(parentHeader)
        if pLower:find("dungeon") or MQS.DUNGEON_TO_QUEST_HEADERS[parentHeader] then
            tag = "D"
        elseif pLower:find("raid") then
            tag = "R"
        end
    end
    
    return tag
end

-- -------------------------------------------------------------
-- Proximity and Group Cache Helpers
-- -------------------------------------------------------------
local function IsAnyGroupMemberNearby()
    if not IsInGroup() then return false end
    
    local numMembers = GetNumGroupMembers() or 0
    if numMembers <= 1 then return false end
    
    local isRaid = IsInRaid()
    local prefix = isRaid and "raid" or "party"
    local limit = isRaid and numMembers or (numMembers - 1)
    local playerName = UnitName("player")
    
    for i = 1, limit do
        local unit = prefix .. i
        local rawName = UnitName(unit)
        if rawName and rawName ~= "" and rawName ~= playerName then
            local isConn = SafeCall(UnitIsConnected, unit)
            if isConn ~= false then
                return true
            end
        end
    end
    
    return false
end

local function HasEveryoneAccepted(questTitle)
    if not questTitle or not IsInGroup() then return false end
    local accepted = MQS.groupAccepted[questTitle]
    if not accepted then return false end
    
    local numMembers = GetNumGroupMembers() or 0
    if numMembers <= 1 then return false end
    
    local isRaid = IsInRaid()
    local prefix = isRaid and "raid" or "party"
    local limit = isRaid and numMembers or (numMembers - 1)
    local playerName = UnitName("player")
    
    local connectedCount = 0
    local acceptedCount = 0
    
    for i = 1, limit do
        local unit = prefix .. i
        local rawName = UnitName(unit)
        if rawName and rawName ~= "" and rawName ~= playerName then
            local isConn = SafeCall(UnitIsConnected, unit)
            if isConn ~= false then
                connectedCount = connectedCount + 1
                local name = GetShortName(rawName)
                if name and accepted[name] then
                    acceptedCount = acceptedCount + 1
                end
            end
        end
    end
    
    return connectedCount > 0 and acceptedCount >= connectedCount
end

local function HasEveryoneOrPeerGotQuest(questID, questTitle)
    if HasEveryoneAccepted(questTitle) then
        return true
    end
    
    if not IsInGroup() or not questID then
        return false
    end
    
    local numMembers = GetNumGroupMembers() or 0
    if numMembers <= 1 then return false end
    
    local isRaid = IsInRaid()
    local prefix = isRaid and "raid" or "party"
    local limit = isRaid and numMembers or (numMembers - 1)
    local playerName = UnitName("player")
    
    local peersWithData = 0
    local peersHaveIt = 0
    
    for i = 1, limit do
        local unit = prefix .. i
        local rawName = UnitName(unit)
        if rawName and rawName ~= "" and rawName ~= playerName then
            local isConn = SafeCall(UnitIsConnected, unit)
            if isConn ~= false then
                local name = GetShortName(rawName)
                if name and MQS.peerQuests[name] then
                    peersWithData = peersWithData + 1
                    if MQS.peerQuests[name][questID] then
                        peersHaveIt = peersHaveIt + 1
                    end
                end
            end
        end
    end
    
    return peersWithData > 0 and peersHaveIt >= peersWithData
end

function MQS:CleanGroupAcceptedCache()
    if not IsInGroup() then
        MQS.groupAccepted = {}
        MQS.peerQuests = {}
        MQS.peerVersions = {}
        return
    end
    
    local currentMembers = {}
    local numMembers = GetNumGroupMembers() or 0
    local isRaid = IsInRaid()
    local prefix = isRaid and "raid" or "party"
    local limit = isRaid and numMembers or (numMembers - 1)
    
    for i = 1, limit do
        local unit = prefix .. i
        local rawName = UnitName(unit)
        if rawName and rawName ~= "" then
            local name = GetShortName(rawName)
            if name then
                currentMembers[name] = true
            end
        end
    end
    
    for questTitle, members in pairs(MQS.groupAccepted) do
        for memberName in pairs(members) do
            if not currentMembers[memberName] then
                members[memberName] = nil
            end
        end
    end
    
    for peerName in pairs(MQS.peerQuests) do
        if not currentMembers[peerName] then
            MQS.peerQuests[peerName] = nil
            MQS.peerVersions[peerName] = nil
        end
    end
end

-- -------------------------------------------------------------
-- Zone & Header Matching
-- -------------------------------------------------------------
function MQS.IsHeaderMatchingZone(headerName, currentZone)
    if not headerName or not currentZone then return false end
    if IsSecret(headerName) or IsSecret(currentZone) then return false end
    if type(headerName) ~= "string" or type(currentZone) ~= "string" or headerName == "" or currentZone == "" then
        return false
    end
    
    local headerLower = headerName:gsub("^%s*(.-)%s*$", "%1"):lower()
    local zoneLower = currentZone:gsub("^%s*(.-)%s*$", "%1"):lower()
    
    if headerLower == zoneLower then
        return true
    end
    
    local headerClean = headerLower:gsub("^the%s+", "")
    local zoneClean = zoneLower:gsub("^the%s+", "")
    if headerClean == zoneClean then
        return true
    end
    
    local mappings = MQS.DUNGEON_TO_QUEST_HEADERS[currentZone]
    if not mappings then
        for dzName, mapList in pairs(MQS.DUNGEON_TO_QUEST_HEADERS) do
            local dzClean = dzName:gsub("^the%s+", ""):lower()
            if dzClean == zoneClean then
                mappings = mapList
                break
            end
        end
    end
    
    if mappings then
        for _, mappedHeader in ipairs(mappings) do
            local mappedClean = mappedHeader:gsub("^%s*(.-)%s*$", "%1"):gsub("^the%s+", ""):lower()
            if headerClean == mappedClean then
                return true
            end
        end
    end
    
    return false
end

local function GetCurrentZoneQuests()
    local quests = {}
    local numEntries = GetNumEntries()
    local currentZone = GetRealZoneText()
    if not currentZone or IsSecret(currentZone) or type(currentZone) ~= "string" or currentZone == "" then
        return quests
    end
    
    local currentHeader = ""
    for i = 1, numEntries do
        local title, isHeader, questID, isCollapsed, isComplete, level = GetQuestInfo(i)
        if title then
            if isHeader then
                currentHeader = title
            else
                if MQS.IsHeaderMatchingZone(currentHeader, currentZone) then
                    local tag = GetQuestTag(i, questID, currentHeader)
                    table.insert(quests, {
                        index = i,
                        questID = questID,
                        title = title,
                        level = level,
                        tag = tag,
                        isComplete = isComplete,
                        isShareable = IsQuestShareable(i, questID),
                    })
                end
            end
        end
    end
    return quests
end

local function GetQuestsForHeader(targetHeaderName, targetHeaderIndex)
    local quests = {}
    if not targetHeaderName or IsSecret(targetHeaderName) or type(targetHeaderName) ~= "string" or targetHeaderName == "" then
        return quests
    end
    
    local targetLower = targetHeaderName:gsub("^%s*(.-)%s*$", "%1"):lower()
    if targetLower == "" then
        return quests
    end
    
    local function ScanHeaderQuests()
        local found = {}
        local numEntries = GetNumEntries()
        local currentHeader = ""
        for i = 1, numEntries do
            local title, isHeader, questID, isCollapsed, isComplete, level = GetQuestInfo(i)
            if title and not IsSecret(title) and type(title) == "string" then
                if isHeader then
                    currentHeader = title
                else
                    local headerLower = currentHeader:gsub("^%s*(.-)%s*$", "%1"):lower()
                    if headerLower == targetLower then
                        local tag = GetQuestTag(i, questID, currentHeader)
                        table.insert(found, {
                            index = i,
                            questID = questID,
                            title = title,
                            level = level,
                            tag = tag,
                            isComplete = isComplete,
                            isShareable = IsQuestShareable(i, questID),
                        })
                    end
                end
            end
        end
        return found
    end
    
    quests = ScanHeaderQuests()
    
    -- Classic fallback when a header is collapsed and GetQuestLogTitle hides child entries
    if #quests == 0 and not (C_QuestLog and C_QuestLog.GetInfo) and type(targetHeaderIndex) == "number" and targetHeaderIndex > 0 then
        if ExpandQuestHeader and CollapseQuestHeader and not (InCombatLockdown and InCombatLockdown()) then
            local _, _, _, isHeader, isCollapsed = GetQuestLogTitle(targetHeaderIndex)
            if isHeader and isCollapsed then
                pcall(ExpandQuestHeader, targetHeaderIndex)
                quests = ScanHeaderQuests()
                pcall(CollapseQuestHeader, targetHeaderIndex)
            end
        end
    end
    
    return quests
end

-- -------------------------------------------------------------
-- Sharing Queue Engine
-- -------------------------------------------------------------
local ProcessQueue

function MQS:ProceedSharingQueue()
    MQS.currentlySharingQuest = nil
    if MQS.shareTimeoutTimer then
        MQS.shareTimeoutTimer:Cancel()
        MQS.shareTimeoutTimer = nil
    end
    ProcessQueue()
end

ProcessQueue = function()
    if #MQS.queue == 0 then
        MQS.isProcessingQueue = false
        if MQS.originalSelection then
            RestoreSelectedQuest(MQS.originalSelection)
            MQS.originalSelection = nil
        end
        if not MyQuestLogSettings.silentShare then
            print("|cFF00FF00[MyQuestLog]|r Completed sharing quests.")
        end
        return
    end
    
    if not IsAnyGroupMemberNearby() then
        MQS.isProcessingQueue = false
        MQS.queue = {}
        if MQS.originalSelection then
            RestoreSelectedQuest(MQS.originalSelection)
            MQS.originalSelection = nil
        end
        print("|cFFFF0000[MyQuestLog] Error: Group members left range. Sharing queue cancelled.|r")
        return
    end
    
    local quest = table.remove(MQS.queue, 1)
    MQS.isProcessingQueue = true
    MQS.currentlySharingQuest = quest.title
    
    if not MyQuestLogSettings.silentShare then
        print(string.format("|cFF00FF00[MyQuestLog]|r Sharing: |cFFFFD100%s|r (%d remaining)", quest.title, #MQS.queue))
    end
    
    PushQuestToGroup(quest.index, quest.questID)
    MQS.groupShared[quest.title] = true
    
    -- 1.0 second delay between quest shares so the WoW server accepts and dispatches each one cleanly without throttling
    C_Timer.After(1.0, function()
        if MQS.currentlySharingQuest == quest.title then
            MQS:ProceedSharingQueue()
        end
    end)
end

local function ShareQuests(quests, zoneLabel)
    if not IsInGroup() then
        print("|cFFFF0000[MyQuestLog] Error: You must be in a party or raid to share quests.|r")
        return
    end
    
    if not IsAnyGroupMemberNearby() then
        print("|cFFFF0000[MyQuestLog] Error: No group members are nearby to receive quests.|r")
        return
    end
    
    local currentZone = GetRealZoneText()
    if not currentZone or IsSecret(currentZone) or type(currentZone) ~= "string" or currentZone == "" then
        currentZone = "this zone"
    end
    local displayZone = (zoneLabel and not IsSecret(zoneLabel) and type(zoneLabel) == "string" and zoneLabel ~= "") and zoneLabel or currentZone
    
    local shareable = {}
    for _, q in ipairs(quests) do
        if q.isShareable or IsQuestShareable(q.index, q.questID) then
            table.insert(shareable, q)
        end
    end
    
    if #shareable == 0 then
        if not MyQuestLogSettings.silentShare then
            print(string.format("|cFFFFD100[MyQuestLog]|r No shareable quests found for |cFFFFFFFF%s|r.", displayZone))
        end
        return
    end
    
    if zoneLabel == nil then
        MQS.lastSharedZone = currentZone
    end
    
    local toShare = {}
    local skippedCount = 0
    
    if MyQuestLogSettings.smartShare ~= false then
        for _, q in ipairs(shareable) do
            if HasEveryoneOrPeerGotQuest(q.questID, q.title) then
                skippedCount = skippedCount + 1
            else
                table.insert(toShare, q)
            end
        end
        
        if #toShare == 0 and skippedCount > 0 then
            if not MyQuestLogSettings.silentShare then
                print(string.format("|cFF00FF00[MyQuestLog]|r Smart Share: All nearby party members already have quests for |cFFFFD100%s|r!", displayZone))
            end
            return
        end
    else
        toShare = shareable
    end
    
    for _, q in ipairs(toShare) do
        table.insert(MQS.queue, q)
    end
    
    if not MQS.isProcessingQueue then
        MQS.originalSelection = GetSelectedQuestIndexOrID()
        ProcessQueue()
    end
end

-- -------------------------------------------------------------
-- Inter-Addon Sync & Questie Bridge
-- -------------------------------------------------------------
function MQS:SendPing()
    if IsInGroup() then
        SendAddonMsg(ADDON_PREFIX, "PING:1.0.0")
    end
end

function MQS:SendQuestSync()
    if not IsInGroup() then return end
    local syncList = {}
    local numEntries = GetNumEntries()
    for i = 1, numEntries do
        local title, isHeader, questID, _, isComplete = GetQuestInfo(i)
        if title and not isHeader and questID and questID > 0 then
            table.insert(syncList, string.format("%d=%d", questID, isComplete and 1 or 0))
        end
    end
    if #syncList > 0 then
        local packet = table.concat(syncList, ";")
        SendAddonMsg(ADDON_PREFIX, "SYNC:" .. packet)
    end
end

function MQS:RequestQuestSync()
    if IsInGroup() then
        MQS:SendQuestSync()
    end
end

function MQS:AutoSyncQuestie()
    if not IsInGroup() then return end
    SendAddonMsg("Questie", "QC:request_log")
    SendAddonMsg("questie", "QC:request_log")
end

function MQS:RequestQuestieShare()
    if not IsInGroup() then
        print("|cFFFF0000[MyQuestLog] Error: You must be in a party or raid to request Questie sharing.|r")
        return
    end
    
    local zoneText = GetRealZoneText()
    if not zoneText or IsSecret(zoneText) or type(zoneText) ~= "string" or zoneText == "" then
        zoneText = "Current Zone"
    end
    
    -- Request sharing from MyQuestLog peers
    SendAddonMsg(ADDON_PREFIX, "REQ_SHARE:" .. zoneText)
    
    -- Trigger Questie's own full quest-list sync if Questie is loaded
    if _G.Questie and _G.Questie.SendMessage then
        pcall(_G.Questie.SendMessage, _G.Questie, "QC_ID_REQUEST_FULL_QUESTLIST")
    end
    
    -- Send a single polite group chat message only upon explicit user confirmation
    if not MyQuestLogSettings.silentShare and SendChatMessage then
        local chatType = IsInRaid() and "RAID" or "PARTY"
        pcall(SendChatMessage, "[MyQuestLog] Could someone with Questie please share quests for " .. zoneText .. "?", chatType)
    end
    
    print(string.format("|cFF00FF00[MyQuestLog]|r Sent Questie share request to group for |cFFFFD100%s|r.", zoneText))
end

function MQS:RequestMQSShare()
    if not IsInGroup() then
        print("|cFFFF0000[MyQuestLog] Error: You must be in a party or raid to request sharing.|r")
        return
    end
    local zoneText = GetRealZoneText() or ""
    if IsSecret(zoneText) or type(zoneText) ~= "string" then
        zoneText = ""
    end
    SendAddonMsg(ADDON_PREFIX, "REQ_SHARE:" .. zoneText)
    print(string.format("|cFF00FF00[MyQuestLog]|r Requested quest share from party members for |cFFFFD100%s|r.", zoneText))
end

StaticPopupDialogs["MQS_CONFIRM_QUESTIE_REQ"] = {
    text = "|cFFFFD100[MyQuestLog]|r Request Questie Share\n\nAsk party members running Questie or MyQuestLog to share their quests for |cFFFFD100%s|r?",
    button1 = "Request",
    button2 = "Cancel",
    OnAccept = function(self, data)
        MQS:RequestQuestieShare()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["MQS_CONFIRM_MQS_REQ"] = {
    text = "|cFFFFD100[MyQuestLog]|r Request AddOn Share\n\nSend quest share request to party members running MyQuestLog for |cFFFFD100%s|r?",
    button1 = "Request",
    button2 = "Cancel",
    OnAccept = function(self, data)
        MQS:RequestMQSShare()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- =============================================================
-- Native Blizzard QuestLog & WorldMapFrame Enhancements
-- =============================================================
local shareZoneBtn = nil
local shareAllBtn = nil
local reqQuestieBtn = nil
local cbAutoShare = nil
local searchBox = nil
local expandAllBtn = nil
local collapseAllBtn = nil
local EnsureQuestMapUI = nil
local UpdateQuestMapHeaderShareButtons = nil
local questMapHeaderShareButtons = setmetatable({}, { __mode = "k" })
local classicHeaderShareButtons = setmetatable({}, { __mode = "k" })
local questMapHeaderHooksInstalled = false

local function UpdateBottomButtons()
    if EnsureQuestMapUI then
        EnsureQuestMapUI()
    end
    
    local currentZone = GetRealZoneText()
    if not currentZone or IsSecret(currentZone) or type(currentZone) ~= "string" then
        currentZone = "Current Zone"
    end
    local isDungeon = MQS.DUNGEON_TO_QUEST_HEADERS[currentZone] ~= nil
    
    MQS.matchingQuests = GetCurrentZoneQuests()
    local count = #MQS.matchingQuests
    local zoneType = isDungeon and "Dungeon" or "Zone"
    local btnText = string.format("Share %s (%d)", zoneType, count)
    
    if shareZoneBtn then
        shareZoneBtn:SetText(btnText)
    end
    if MQS.qmShareZoneBtn then
        MQS.qmShareZoneBtn:SetText(btnText)
    end
    if MQS.qmCbAuto and MyQuestLogSettings then
        MQS.qmCbAuto:SetChecked(MyQuestLogSettings.autoShare)
    end
    if cbAutoShare and MyQuestLogSettings then
        cbAutoShare:SetChecked(MyQuestLogSettings.autoShare)
    end
    if UpdateQuestMapHeaderShareButtons then
        UpdateQuestMapHeaderShareButtons()
    end
end

-- -------------------------------------------------------------
-- Window Unlocking & Dragging (WorldMapFrame & QuestLogFrame)
-- -------------------------------------------------------------
local function SaveMapPosition()
    if InCombatLockdown and InCombatLockdown() then return end
    if not WorldMapFrame then return end
    if WorldMapFrame.IsMaximized and WorldMapFrame:IsMaximized() then return end
    
    local left = WorldMapFrame:GetLeft()
    local top = WorldMapFrame:GetTop()
    local scale = WorldMapFrame:GetEffectiveScale()
    local uiScale = UIParent:GetEffectiveScale()
    local screenTop = UIParent:GetTop()
    
    if issecretvalue and (issecretvalue(left) or issecretvalue(top)) then return end
    if not left or not top or not scale or scale <= 0 or not screenTop or not uiScale then return end
    
    local x = left
    local y = top - (screenTop * uiScale / scale)
    
    if not MyQuestLogSettings then MyQuestLogSettings = {} end
    MyQuestLogSettings.mapPosition = { a = "TOPLEFT", r = "TOPLEFT", x = x, y = y }
    
    -- Sync with Leatrix_Maps if present
    if LeaMapsLC then
        LeaMapsLC["MapPosA"] = "TOPLEFT"
        LeaMapsLC["MapPosR"] = "TOPLEFT"
        LeaMapsLC["MapPosX"] = x
        LeaMapsLC["MapPosY"] = y
        if LeaMapsDB then
            LeaMapsDB["MapPosA"] = "TOPLEFT"
            LeaMapsDB["MapPosR"] = "TOPLEFT"
            LeaMapsDB["MapPosX"] = x
            LeaMapsDB["MapPosY"] = y
        end
    end
end

local function RestoreMapPosition()
    if InCombatLockdown and InCombatLockdown() then return end
    if not WorldMapFrame or not WorldMapFrame:IsShown() then return end
    if WorldMapFrame.IsMaximized and WorldMapFrame:IsMaximized() then return end
    
    local pos = MyQuestLogSettings and MyQuestLogSettings.mapPosition
    if pos and pos.x and pos.y then
        WorldMapFrame:ClearAllPoints()
        WorldMapFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", pos.x, pos.y)
    end
end

local function MakeWorldMapMovable()
    if not WorldMapFrame or WorldMapFrame._mqsMovableInit then return end
    WorldMapFrame._mqsMovableInit = true
    
    WorldMapFrame:SetMovable(true)
    WorldMapFrame:SetClampedToScreen(true)
    
    local function StartDrag()
        if InCombatLockdown and InCombatLockdown() then return end
        if WorldMapFrame.IsMaximized and WorldMapFrame:IsMaximized() then return end
        WorldMapFrame:StartMoving()
    end
    
    local function StopDrag()
        WorldMapFrame:StopMovingOrSizing()
        WorldMapFrame:SetUserPlaced(false)
        SaveMapPosition()
    end
    
    local function HookDragOnFrame(frame)
        if not frame or frame._mqsDraggable then return end
        frame._mqsDraggable = true
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:HookScript("OnDragStart", StartDrag)
        frame:HookScript("OnDragStop", StopDrag)
    end
    
    HookDragOnFrame(WorldMapFrame)
    if WorldMapTitleButton then HookDragOnFrame(WorldMapTitleButton) end
    if WorldMapFrame.BorderFrame and WorldMapFrame.BorderFrame.TitleContainer then
        HookDragOnFrame(WorldMapFrame.BorderFrame.TitleContainer)
    end
    if WorldMapFrame.TitleCanvas then
        HookDragOnFrame(WorldMapFrame.TitleCanvas)
    end
    if LeaMapsCB and LeaMapsCB["MapTitleFrame"] then
        HookDragOnFrame(LeaMapsCB["MapTitleFrame"])
    end
    
    -- Dedicated top-bar drag grip
    local topDragBar = CreateFrame("Frame", "MQS_WorldMapTopDragBar", WorldMapFrame)
    topDragBar:SetHeight(26)
    topDragBar:SetPoint("TOPLEFT", WorldMapFrame, "TOPLEFT", 10, 0)
    topDragBar:SetPoint("TOPRIGHT", WorldMapFrame, "TOPRIGHT", -90, 0)
    topDragBar:SetFrameLevel((WorldMapFrame:GetFrameLevel() or 10) + 12)
    topDragBar:EnableMouse(true)
    topDragBar:RegisterForDrag("LeftButton")
    topDragBar:SetScript("OnDragStart", StartDrag)
    topDragBar:SetScript("OnDragStop", StopDrag)
    
    if WorldMapFrame.SynchronizeDisplayState then
        hooksecurefunc(WorldMapFrame, "SynchronizeDisplayState", RestoreMapPosition)
    end
    WorldMapFrame:HookScript("OnShow", RestoreMapPosition)
end

local function MakeQuestLogMovable()
    if not QuestLogFrame or QuestLogFrame._mqsMovableInit then return end
    QuestLogFrame._mqsMovableInit = true
    
    QuestLogFrame:SetMovable(true)
    QuestLogFrame:SetClampedToScreen(true)
    QuestLogFrame:EnableMouse(true)
    QuestLogFrame:RegisterForDrag("LeftButton")
    QuestLogFrame:HookScript("OnDragStart", function()
        if not InCombatLockdown or not InCombatLockdown() then
            QuestLogFrame:StartMoving()
        end
    end)
    QuestLogFrame:HookScript("OnDragStop", function()
        QuestLogFrame:StopMovingOrSizing()
        local pt, rel, relPt, x, y = QuestLogFrame:GetPoint()
        if not MyQuestLogSettings then MyQuestLogSettings = {} end
        MyQuestLogSettings.questLogPosition = { pt = pt, relPt = relPt, x = x, y = y }
    end)
    QuestLogFrame:HookScript("OnShow", function()
        local pos = MyQuestLogSettings and MyQuestLogSettings.questLogPosition
        if pos and pos.x and pos.y then
            QuestLogFrame:ClearAllPoints()
            QuestLogFrame:SetPoint(pos.pt or "CENTER", UIParent, pos.relPt or "CENTER", pos.x, pos.y)
        end
    end)
end

-- -------------------------------------------------------------
-- Build QuestMapFrame UI (WoW Forever Modern Map & Quest Log)
-- -------------------------------------------------------------
local isAdjustingPoints = false
local function AdjustQuestScrollBottom()
    if not QuestScrollFrame or not QuestScrollFrame:GetParent() then return end
    if isAdjustingPoints then return end
    isAdjustingPoints = true
    QuestScrollFrame:SetPoint("BOTTOMRIGHT", QuestScrollFrame:GetParent(), "BOTTOMRIGHT", 0, 56)
    isAdjustingPoints = false
end

local function GetOrCreateZoneHeaderShareButton(headerFrame, buttonMap, width, height)
    if buttonMap[headerFrame] then
        return buttonMap[headerFrame]
    end
    
    local btn = CreateFrame("Button", nil, headerFrame, "UIPanelButtonTemplate")
    btn:SetSize(width, height)
    btn:SetText("Share")
    local fs = btn:GetFontString()
    if fs then
        fs:SetFontObject("GameFontHighlightSmall")
    end
    btn:EnableMouse(true)
    btn:RegisterForClicks("LeftButtonUp")
    btn:SetFrameLevel((headerFrame:GetFrameLevel() or 10) + 5)
    
    btn:SetScript("OnClick", function(self)
        local hdrName = self._mqsHeaderName
        local hdrIndex = self._mqsHeaderIndex
        if not hdrName then return end
        
        local quests = GetQuestsForHeader(hdrName, hdrIndex)
        if #quests == 0 then
            print("|cFFFFD100[MyQuestLog]|r No quests found under |cFFFFFFFF" .. hdrName .. "|r.")
            return
        end
        ShareQuests(quests, hdrName)
    end)
    
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local hdrName = self._mqsHeaderName or "Zone"
        GameTooltip:AddLine("Share " .. hdrName .. " Quests", 1, 0.82, 0)
        local quests = GetQuestsForHeader(hdrName, self._mqsHeaderIndex)
        if #quests == 0 then
            GameTooltip:AddLine("  (No quests visible - expand header)", 0.6, 0.6, 0.6)
        else
            for _, q in ipairs(quests) do
                local status = q.isShareable and "|cFF00FF00(Shareable)|r" or "|cFFFF0000(Solo)|r"
                GameTooltip:AddLine(string.format("  • [%s] %s %s", q.level or "?", q.title, status), 0.9, 0.9, 0.9)
            end
        end
        GameTooltip:AddLine(" ")
        if IsInGroup() then
            GameTooltip:AddLine("Click to share quests for this zone.", 0.2, 1, 0.2, true)
        else
            GameTooltip:AddLine("Join a party or raid to share.", 1, 0.5, 0, true)
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    
    buttonMap[headerFrame] = btn
    return btn
end

local function BuildQuestMapUI()
    if not QuestMapFrame then return end
    if _G["MQS_QuestMapBottomBar"] then return end
    
    -- Dedicated bottom control bar for QuestMapFrame
    local bottomBar = CreateFrame("Frame", "MQS_QuestMapBottomBar", QuestMapFrame)
    bottomBar:SetHeight(52)
    bottomBar:SetPoint("BOTTOMLEFT", QuestMapFrame, "BOTTOMLEFT", 4, 3)
    bottomBar:SetPoint("BOTTOMRIGHT", QuestMapFrame, "BOTTOMRIGHT", -4, 3)
    bottomBar:SetFrameStrata("HIGH")
    bottomBar:SetFrameLevel(50)
    
    local bg = bottomBar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.04, 0.04, 0.04, 0.92)
    
    local topBorder = bottomBar:CreateTexture(nil, "ARTWORK")
    topBorder:SetHeight(1)
    topBorder:SetPoint("TOPLEFT", bottomBar, "TOPLEFT", 0, 0)
    topBorder:SetPoint("TOPRIGHT", bottomBar, "TOPRIGHT", 0, 0)
    topBorder:SetColorTexture(0.45, 0.38, 0.18, 0.95) -- Clean gold separator
    
    -- Row 1, Left: Share Zone / Share Dungeon Button
    local qmShareZoneBtn = CreateFrame("Button", "MQS_QMShareZoneBtn", bottomBar, "UIPanelButtonTemplate")
    qmShareZoneBtn:SetSize(116, 22)
    qmShareZoneBtn:SetPoint("TOPLEFT", bottomBar, "TOPLEFT", 6, -4)
    qmShareZoneBtn:SetText("Share Zone (0)")
    local font1 = qmShareZoneBtn:GetFontString()
    if font1 then font1:SetFontObject("GameFontHighlightSmall") end
    
    qmShareZoneBtn:SetScript("OnClick", function()
        ShareQuests(MQS.matchingQuests)
    end)
    qmShareZoneBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        local currentZone = GetRealZoneText() or "Current Zone"
        local isDungeon = MQS.DUNGEON_TO_QUEST_HEADERS[currentZone] ~= nil
        GameTooltip:AddLine(isDungeon and "Share Dungeon Quests" or "Share Zone Quests", 1, 0.82, 0)
        GameTooltip:AddLine("Matching for |cFFFFFFFF" .. currentZone .. "|r:", 1, 1, 1)
        if #MQS.matchingQuests == 0 then
            GameTooltip:AddLine("  (No matching quests in log)", 0.6, 0.6, 0.6)
        else
            for _, q in ipairs(MQS.matchingQuests) do
                local status = q.isShareable and "|cFF00FF00(Shareable)|r" or "|cFFFF0000(Solo)|r"
                GameTooltip:AddLine(string.format("  • [%s] %s %s", q.level, q.title, status), 0.9, 0.9, 0.9)
            end
        end
        GameTooltip:AddLine(" ")
        if IsInGroup() then
            local count = GetNumGroupMembers() or 1
            GameTooltip:AddLine(string.format("|cFF00FF00In Group:|r %d members", count), 0.2, 1, 0.2)
            GameTooltip:AddLine("Click to share matching quests with group.", 1, 1, 1, true)
        else
            GameTooltip:AddLine("|cFFFF8800In Group:|r Solo (Join a party to share)", 1, 0.5, 0)
        end
        GameTooltip:Show()
    end)
    qmShareZoneBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    
    -- Row 1, Right: Req Questie Button
    local qmReqQuestieBtn = CreateFrame("Button", "MQS_QMReqQuestieBtn", bottomBar, "UIPanelButtonTemplate")
    qmReqQuestieBtn:SetSize(84, 22)
    qmReqQuestieBtn:SetPoint("TOPRIGHT", bottomBar, "TOPRIGHT", -6, -4)
    qmReqQuestieBtn:SetText("Req Questie")
    local fontReq = qmReqQuestieBtn:GetFontString()
    if fontReq then fontReq:SetFontObject("GameFontHighlightSmall") end
    
    qmReqQuestieBtn:SetScript("OnClick", function()
        if not IsInGroup() then
            print("|cFFFF0000[MyQuestLog] Error: You must be in a party or raid to request Questie sharing.|r")
            return
        end
        local zoneText = GetRealZoneText()
        if not zoneText or IsSecret(zoneText) or type(zoneText) ~= "string" or zoneText == "" then
            zoneText = "Current Zone"
        end
        StaticPopup_Show("MQS_CONFIRM_QUESTIE_REQ", zoneText)
    end)
    qmReqQuestieBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Request Questie Share", 1, 0.82, 0)
        GameTooltip:AddLine("Opens a confirmation dialog to ask group members running Questie or MyQuestLog to share quests for the current zone or dungeon.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    qmReqQuestieBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    
    -- Row 1, Middle: Share All Button (stretches between Share Zone and Req Questie)
    local qmShareAllBtn = CreateFrame("Button", "MQS_QMShareAllBtn", bottomBar, "UIPanelButtonTemplate")
    qmShareAllBtn:SetHeight(22)
    qmShareAllBtn:SetPoint("LEFT", qmShareZoneBtn, "RIGHT", 4, 0)
    qmShareAllBtn:SetPoint("RIGHT", qmReqQuestieBtn, "LEFT", -4, 0)
    qmShareAllBtn:SetText("Share All")
    local font2 = qmShareAllBtn:GetFontString()
    if font2 then font2:SetFontObject("GameFontHighlightSmall") end
    
    qmShareAllBtn:SetScript("OnClick", function()
        local allQuests = {}
        local num = GetNumEntries()
        for i = 1, num do
            local qTitle, isHeader, qID, _, isComplete, qLevel = GetQuestInfo(i)
            if qTitle and not isHeader then
                table.insert(allQuests, { index = i, questID = qID, title = qTitle, level = qLevel, isComplete = isComplete })
            end
        end
        ShareQuests(allQuests, "your quest log")
    end)
    qmShareAllBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Share All Quests", 1, 0.82, 0)
        GameTooltip:AddLine("Pushes all eligible quests currently in your quest log to group members.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    qmShareAllBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    
    -- Row 2, Left: Auto-Share Checkbox
    local qmCbAuto = CreateFrame("CheckButton", "MQS_QMCbAuto", bottomBar, "UICheckButtonTemplate")
    qmCbAuto:SetSize(20, 20)
    qmCbAuto:SetPoint("TOPLEFT", bottomBar, "TOPLEFT", 6, -28)
    local cbText = qmCbAuto:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cbText:SetPoint("LEFT", qmCbAuto, "RIGHT", 4, 0)
    cbText:SetText("Auto-share when zoning")
    qmCbAuto:SetScript("OnClick", function(self)
        MyQuestLogSettings.autoShare = self:GetChecked()
        print("|cFF00FF00[MyQuestLog]|r Auto-share is now: " .. (MyQuestLogSettings.autoShare and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"))
    end)
    qmCbAuto:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Auto-Share Quests", 1, 0.82, 0)
        GameTooltip:AddLine("Automatically shares matching dungeon or zone quests with group members upon zoning into a new area.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    qmCbAuto:SetScript("OnLeave", function() GameTooltip:Hide() end)
    qmCbAuto:SetChecked(MyQuestLogSettings.autoShare)
    
    -- Row 2, Right: Reset Map Position Button
    local qmResetPosBtn = CreateFrame("Button", "MQS_QMResetPosBtn", bottomBar, "UIPanelButtonTemplate")
    qmResetPosBtn:SetSize(84, 20)
    qmResetPosBtn:SetPoint("TOPRIGHT", bottomBar, "TOPRIGHT", -6, -28)
    qmResetPosBtn:SetText("Reset Pos")
    local font3 = qmResetPosBtn:GetFontString()
    if font3 then font3:SetFontObject("GameFontHighlightSmall") end
    qmResetPosBtn:SetScript("OnClick", function()
        if WorldMapFrame then
            WorldMapFrame:ClearAllPoints()
            WorldMapFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            MyQuestLogSettings.mapPosition = nil
            print("|cFF00FF00[MyQuestLog]|r Map position reset to center.")
        end
    end)
    qmResetPosBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Reset Map Position", 1, 0.82, 0)
        GameTooltip:AddLine("Re-centers the World Map window to the middle of the screen.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    qmResetPosBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    
    -- Ensure QuestScrollFrame bottom terminates above the 52px bottom bar
    if QuestScrollFrame and not QuestScrollFrame._mqsScrollHooked then
        QuestScrollFrame._mqsScrollHooked = true
        hooksecurefunc(QuestScrollFrame, "SetPoint", function(self, point, relTo, relPoint, x, y)
            if isAdjustingPoints then return end
            if point == "BOTTOMRIGHT" and (y == nil or y < 56) then
                AdjustQuestScrollBottom()
            end
        end)
    end
    AdjustQuestScrollBottom()
    
    -- Hide bottomBar when DetailsFrame is shown (viewing specific quest details), show when returning to list
    if QuestMapFrame.DetailsFrame then
        QuestMapFrame.DetailsFrame:HookScript("OnShow", function()
            bottomBar:Hide()
        end)
        QuestMapFrame.DetailsFrame:HookScript("OnHide", function()
            bottomBar:Show()
            AdjustQuestScrollBottom()
            UpdateBottomButtons()
        end)
    end
    
    MQS.qmShareZoneBtn = qmShareZoneBtn
    MQS.qmReqQuestieBtn = qmReqQuestieBtn
    MQS.qmCbAuto = qmCbAuto
end

UpdateQuestMapHeaderShareButtons = function()
    if not QuestScrollFrame or not QuestMapFrame or not QuestMapFrame:IsShown() then
        return
    end
    
    local validHeaders = {}
    local numEntries = GetNumEntries()
    for i = 1, numEntries do
        local title, isHeader = GetQuestInfo(i)
        if isHeader and title and not IsSecret(title) and type(title) == "string" and title ~= "" then
            local key = title:gsub("^%s*(.-)%s*$", "%1"):lower()
            if key ~= "" then
                validHeaders[key] = { title = title, index = i }
            end
        end
    end
    
    local activeHeaderFrames = {}
    
    local function ResolveHeaderInfo(frame)
        if not frame or not frame:IsShown() then return nil, nil end
        if type(frame.questID) == "number" and frame.questID > 0 then
            return nil, nil
        end
        
        if type(frame.questLogIndex) == "number" and frame.questLogIndex > 0 then
            local title, isHeader = GetQuestInfo(frame.questLogIndex)
            if isHeader and title and not IsSecret(title) and type(title) == "string" and title ~= "" then
                return title, frame.questLogIndex
            end
        end
        
        if frame.GetID then
            local id = frame:GetID()
            if type(id) == "number" and id > 0 then
                local title, isHeader = GetQuestInfo(id)
                if isHeader and title and not IsSecret(title) and type(title) == "string" and title ~= "" then
                    return title, id
                end
            end
        end
        
        local txt = nil
        if frame.ButtonText and frame.ButtonText.GetText then
            txt = frame.ButtonText:GetText()
        elseif frame.Text and frame.Text.GetText then
            txt = frame.Text:GetText()
        elseif frame.GetText then
            txt = frame:GetText()
        end
        if txt and not IsSecret(txt) and type(txt) == "string" and txt ~= "" then
            local key = txt:gsub("^%s*(.-)%s*$", "%1"):lower()
            local entry = validHeaders[key]
            if entry then
                return entry.title, entry.index
            end
        end
        
        return nil, nil
    end
    
    local function AttachToHeader(header)
        if not header or activeHeaderFrames[header] then return end
        local hdrTitle, hdrIndex = ResolveHeaderInfo(header)
        if not hdrTitle then return end
        
        activeHeaderFrames[header] = true
        local btn = GetOrCreateZoneHeaderShareButton(header, questMapHeaderShareButtons, 44, 18)
        btn._mqsHeaderName = hdrTitle
        btn._mqsHeaderIndex = hdrIndex
        btn:SetFrameLevel((header:GetFrameLevel() or 10) + 5)
        
        btn:ClearAllPoints()
        if header.CollapseButton and header.CollapseButton:IsShown() then
            local cbLeft = header.CollapseButton:GetLeft()
            local hdrLeft = header:GetLeft()
            local hdrWidth = header:GetWidth()
            if cbLeft and hdrLeft and hdrWidth and cbLeft < (hdrLeft + hdrWidth * 0.5) then
                btn:SetPoint("RIGHT", header, "RIGHT", -6, 0)
            else
                btn:SetPoint("RIGHT", header.CollapseButton, "LEFT", -4, 0)
            end
        else
            btn:SetPoint("RIGHT", header, "RIGHT", -24, 0)
        end
        btn:Show()
    end
    
    local pools = {
        QuestScrollFrame.headerFramePool,
        QuestScrollFrame.campaignHeaderFramePool,
        QuestScrollFrame.campaignHeaderMinimalFramePool,
    }
    for _, pool in pairs(pools) do
        if pool and pool.EnumerateActive then
            for hdr in pool:EnumerateActive() do
                AttachToHeader(hdr)
            end
        end
    end
    
    local containers = {}
    if QuestScrollFrame.Contents then
        table.insert(containers, QuestScrollFrame.Contents)
    end
    if QuestScrollFrame.GetScrollChild then
        local scrollChild = QuestScrollFrame:GetScrollChild()
        if scrollChild and scrollChild ~= QuestScrollFrame.Contents then
            table.insert(containers, scrollChild)
        end
    end
    for _, container in ipairs(containers) do
        for _, child in ipairs({ container:GetChildren() }) do
            if not activeHeaderFrames[child] then
                AttachToHeader(child)
            end
        end
    end
    
    for hdr, btn in pairs(questMapHeaderShareButtons) do
        if not activeHeaderFrames[hdr] then
            btn:Hide()
        end
    end
end

EnsureQuestMapUI = function()
    if QuestMapFrame and not _G["MQS_QuestMapBottomBar"] then
        BuildQuestMapUI()
    end
    
    if not questMapHeaderHooksInstalled then
        if QuestLogQuests_Update then
            hooksecurefunc("QuestLogQuests_Update", function()
                if UpdateQuestMapHeaderShareButtons then
                    UpdateQuestMapHeaderShareButtons()
                end
            end)
            questMapHeaderHooksInstalled = true
        end
        if QuestMapFrame_UpdateAll then
            hooksecurefunc("QuestMapFrame_UpdateAll", function()
                if UpdateQuestMapHeaderShareButtons then
                    UpdateQuestMapHeaderShareButtons()
                end
            end)
            questMapHeaderHooksInstalled = true
        end
    end
    
    if QuestScrollFrame and not QuestScrollFrame._mqsHeaderShowHooked then
        QuestScrollFrame._mqsHeaderShowHooked = true
        QuestScrollFrame:HookScript("OnShow", function()
            C_Timer.After(0, function()
                if UpdateQuestMapHeaderShareButtons then
                    UpdateQuestMapHeaderShareButtons()
                end
            end)
        end)
    end
end

-- -------------------------------------------------------------
-- Hook QuestLog_Update to inject Level & Difficulty Tags (Classic)
-- -------------------------------------------------------------
local function EnhanceQuestLogTitles()
    if not QuestLogFrame or not QuestLogFrame:IsShown() then return end
    
    local scrollOffset = FauxScrollFrame_GetOffset and FauxScrollFrame_GetOffset(QuestLogListScrollFrame) or 0
    local numEntries = GetNumEntries()
    local filter = MQS.currentFilter
    
    for i = 1, 25 do
        local btn = _G["QuestLogTitle" .. i]
        if not btn then break end
        
        local questIndex = scrollOffset + i
        if questIndex <= numEntries and btn:IsShown() then
            local title, level, questTag, isHeader, isCollapsed, isComplete = GetQuestLogTitle(questIndex)
            if isHeader and title and not IsSecret(title) and type(title) == "string" and title ~= "" then
                local sBtn = GetOrCreateZoneHeaderShareButton(btn, classicHeaderShareButtons, 40, 15)
                sBtn._mqsHeaderName = title
                sBtn._mqsHeaderIndex = questIndex
                sBtn:ClearAllPoints()
                sBtn:SetPoint("RIGHT", btn, "RIGHT", -6, 0)
                sBtn:SetFrameLevel((btn:GetFrameLevel() or 5) + 5)
                sBtn:Show()
            else
                if classicHeaderShareButtons[btn] then
                    classicHeaderShareButtons[btn]:Hide()
                end
                if MyQuestLogSettings.showLevels ~= false and title and not isHeader and not IsSecret(title) then
                    local tag = GetQuestTag(questIndex)
                    local tagStr = (tag ~= "") and ("[" .. level .. tag .. "] ") or ("[" .. level .. "] ")
                    local color = GetQuestDifficultyColor(level)
                    
                    local isMatch = true
                    if filter and filter ~= "" then
                        local lowerTitle = string.lower(title)
                        isMatch = string.find(lowerTitle, filter, 1, true) ~= nil or tostring(level) == filter
                    end
                    
                    local displayTitle = tagStr .. title
                    if isComplete then
                        displayTitle = displayTitle .. " (Complete)"
                    end
                    
                    btn:SetText(displayTitle)
                    
                    local fontString = btn:GetFontString()
                    if fontString then
                        if isMatch then
                            fontString:SetTextColor(color.r, color.g, color.b)
                        else
                            fontString:SetTextColor(0.4, 0.4, 0.4)
                        end
                    end
                end
            end
        else
            if classicHeaderShareButtons[btn] then
                classicHeaderShareButtons[btn]:Hide()
            end
        end
    end
    
    if MyQuestLogSettings.showLevels ~= false then
        local numQuests = 0
        for idx = 1, numEntries do
            local _, _, _, isHeader = GetQuestLogTitle(idx)
            if not isHeader then
                numQuests = numQuests + 1
            end
        end
        if QuestLogTitleText then
            QuestLogTitleText:SetText(string.format("Quest Log (%d/25)", numQuests))
        end
    end
    
    UpdateBottomButtons()
end

-- -------------------------------------------------------------
-- Build Classic In-Frame UI Elements (QuestLogFrame Fallback)
-- -------------------------------------------------------------
local function BuildMQSUI()
    if not QuestLogFrame then return end
    if shareZoneBtn then return end
    
    -- Share Zone / Share Dungeon Button
    shareZoneBtn = CreateFrame("Button", "MQS_InFrameShareZoneBtn", QuestLogFrame, "UIPanelButtonTemplate")
    shareZoneBtn:SetSize(106, 22)
    shareZoneBtn:SetPoint("BOTTOMLEFT", QuestLogFrame, "BOTTOMLEFT", 18, 38)
    shareZoneBtn:SetText("Share Zone (0)")
    local fontSz = shareZoneBtn:GetFontString()
    if fontSz then fontSz:SetFontObject("GameFontHighlightSmall") end
    shareZoneBtn:SetScript("OnClick", function()
        ShareQuests(MQS.matchingQuests)
    end)
    shareZoneBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        local currentZone = GetRealZoneText() or "Current Zone"
        local isDungeon = MQS.DUNGEON_TO_QUEST_HEADERS[currentZone] ~= nil
        GameTooltip:AddLine(isDungeon and "Share Dungeon Quests" or "Share Zone Quests", 1, 0.82, 0)
        GameTooltip:AddLine("Matching for |cFFFFFFFF" .. currentZone .. "|r:", 1, 1, 1)
        if #MQS.matchingQuests == 0 then
            GameTooltip:AddLine("  (No matching quests in log)", 0.6, 0.6, 0.6)
        else
            for _, q in ipairs(MQS.matchingQuests) do
                local status = q.isShareable and "|cFF00FF00(Shareable)|r" or "|cFFFF0000(Solo)|r"
                GameTooltip:AddLine(string.format("  • [%s] %s %s", q.level, q.title, status), 0.9, 0.9, 0.9)
            end
        end
        GameTooltip:AddLine("Click to share matching quests with group.", 0.2, 1, 0.2, true)
        GameTooltip:Show()
    end)
    shareZoneBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    
    -- Share All Button
    shareAllBtn = CreateFrame("Button", "MQS_InFrameShareAllBtn", QuestLogFrame, "UIPanelButtonTemplate")
    shareAllBtn:SetSize(62, 22)
    shareAllBtn:SetPoint("LEFT", shareZoneBtn, "RIGHT", 3, 0)
    shareAllBtn:SetText("Share All")
    local fontSa = shareAllBtn:GetFontString()
    if fontSa then fontSa:SetFontObject("GameFontHighlightSmall") end
    shareAllBtn:SetScript("OnClick", function()
        local allQuests = {}
        local num = GetNumEntries()
        for i = 1, num do
            local qTitle, isHeader, qID, _, isComplete, qLevel = GetQuestInfo(i)
            if qTitle and not isHeader then
                table.insert(allQuests, { index = i, questID = qID, title = qTitle, level = qLevel, isComplete = isComplete })
            end
        end
        ShareQuests(allQuests, "your quest log")
    end)
    shareAllBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Share All Quests", 1, 0.82, 0)
        GameTooltip:AddLine("Pushes all eligible quests in your log to group members.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    shareAllBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    
    -- Req Questie Button
    reqQuestieBtn = CreateFrame("Button", "MQS_InFrameReqQuestieBtn", QuestLogFrame, "UIPanelButtonTemplate")
    reqQuestieBtn:SetSize(76, 22)
    reqQuestieBtn:SetPoint("LEFT", shareAllBtn, "RIGHT", 3, 0)
    reqQuestieBtn:SetText("Req Questie")
    local fontRq = reqQuestieBtn:GetFontString()
    if fontRq then fontRq:SetFontObject("GameFontHighlightSmall") end
    reqQuestieBtn:SetScript("OnClick", function()
        if not IsInGroup() then
            print("|cFFFF0000[MyQuestLog] Error: You must be in a party or raid to request Questie sharing.|r")
            return
        end
        local zoneText = GetRealZoneText()
        if not zoneText or IsSecret(zoneText) or type(zoneText) ~= "string" or zoneText == "" then
            zoneText = "Current Zone"
        end
        StaticPopup_Show("MQS_CONFIRM_QUESTIE_REQ", zoneText)
    end)
    reqQuestieBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Request Questie Share", 1, 0.82, 0)
        GameTooltip:AddLine("Opens a confirmation dialog to ask group members running Questie or MyQuestLog to share quests for the current zone or dungeon.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    reqQuestieBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    
    -- Auto-Share Checkbox
    cbAutoShare = CreateFrame("CheckButton", "MQS_InFrameAutoShareCB", QuestLogFrame, "UICheckButtonTemplate")
    cbAutoShare:SetSize(18, 18)
    cbAutoShare:SetPoint("LEFT", reqQuestieBtn, "RIGHT", 3, 0)
    local cbText = cbAutoShare:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cbText:SetPoint("LEFT", cbAutoShare, "RIGHT", 1, 0)
    cbText:SetText("Auto")
    cbAutoShare:SetScript("OnClick", function(self)
        MyQuestLogSettings.autoShare = self:GetChecked()
        print("|cFF00FF00[MyQuestLog]|r Auto-share is now: " .. (MyQuestLogSettings.autoShare and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"))
    end)
    cbAutoShare:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Auto-Share on Zone/Dungeon Change", 1, 0.82, 0)
        GameTooltip:AddLine("Automatically shares matching dungeon or zone quests when zoning with a group.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    cbAutoShare:SetScript("OnLeave", function() GameTooltip:Hide() end)
    cbAutoShare:SetChecked(MyQuestLogSettings.autoShare)
    
    -- Header Controls: Expand All, Collapse All & Search
    expandAllBtn = CreateFrame("Button", "MQS_InFrameExpandBtn", QuestLogFrame, "UIPanelButtonTemplate")
    expandAllBtn:SetSize(18, 18)
    expandAllBtn:SetPoint("TOPLEFT", QuestLogFrame, "TOPLEFT", 18, -40)
    expandAllBtn:SetText("+")
    expandAllBtn:SetScript("OnClick", function()
        ExpandQuestHeader(0)
        if QuestLog_Update then QuestLog_Update() end
    end)
    expandAllBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Expand All", 1, 0.82, 0)
        GameTooltip:AddLine("Expand all quest zone headers.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    expandAllBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    
    collapseAllBtn = CreateFrame("Button", "MQS_InFrameCollapseBtn", QuestLogFrame, "UIPanelButtonTemplate")
    collapseAllBtn:SetSize(18, 18)
    collapseAllBtn:SetPoint("LEFT", expandAllBtn, "RIGHT", 2, 0)
    collapseAllBtn:SetText("-")
    collapseAllBtn:SetScript("OnClick", function()
        CollapseQuestHeader(0)
        if QuestLog_Update then QuestLog_Update() end
    end)
    collapseAllBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Collapse All", 1, 0.82, 0)
        GameTooltip:AddLine("Collapse all quest zone headers.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    collapseAllBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    
    searchBox = CreateFrame("EditBox", "MQS_InFrameSearchBox", QuestLogFrame, "InputBoxTemplate")
    searchBox:SetSize(140, 18)
    searchBox:SetPoint("LEFT", collapseAllBtn, "RIGHT", 12, 0)
    searchBox:SetAutoFocus(false)
    searchBox:SetFontObject("GameFontHighlightSmall")
    
    local searchPlaceholder = searchBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    searchPlaceholder:SetPoint("LEFT", searchBox, "LEFT", 2, 0)
    searchPlaceholder:SetText("Search quests...")
    
    local searchClearBtn = CreateFrame("Button", nil, searchBox)
    searchClearBtn:SetSize(14, 14)
    searchClearBtn:SetPoint("RIGHT", searchBox, "RIGHT", 0, 0)
    local clearText = searchClearBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    clearText:SetPoint("CENTER")
    clearText:SetText("|cFF888888x|r")
    searchClearBtn:Hide()
    
    searchClearBtn:SetScript("OnClick", function()
        searchBox:SetText("")
        searchBox:ClearFocus()
        MQS.currentFilter = nil
        searchPlaceholder:Show()
        searchClearBtn:Hide()
        if QuestLog_Update then QuestLog_Update() end
    end)
    
    searchBox:SetScript("OnTextChanged", function(self)
        local text = self:GetText() or ""
        local trimmed = string.lower(text:gsub("^%s*(.-)%s*$", "%1"))
        if trimmed ~= "" then
            searchPlaceholder:Hide()
            searchClearBtn:Show()
            MQS.currentFilter = trimmed
        else
            searchPlaceholder:Show()
            searchClearBtn:Hide()
            MQS.currentFilter = nil
        end
        if QuestLog_Update then QuestLog_Update() end
    end)
    
    searchBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
        MQS.currentFilter = nil
        searchPlaceholder:Show()
        searchClearBtn:Hide()
        if QuestLog_Update then QuestLog_Update() end
    end)
    
    if QuestLog_Update then
        hooksecurefunc("QuestLog_Update", EnhanceQuestLogTitles)
    end
    
    QuestLogFrame:HookScript("OnShow", function()
        UpdateBottomButtons()
        EnhanceQuestLogTitles()
    end)
end

-- =============================================================
-- Event Handlers
-- =============================================================
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("QUEST_LOG_UPDATE")
eventFrame:RegisterEvent("CHAT_MSG_SYSTEM")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")
eventFrame:RegisterEvent("QUEST_ACCEPTED")

local function InitAddon()
    if not MyQuestLogSettings then
        MyQuestLogSettings = {}
    end
    for k, v in pairs(defaultSettings) do
        if MyQuestLogSettings[k] == nil then
            MyQuestLogSettings[k] = v
        end
    end
    
    RegisterPrefix(ADDON_PREFIX)
    RegisterPrefix(LEGACY_PREFIX)
    RegisterPrefix("Questie")
    RegisterPrefix("questie")
    
    MakeWorldMapMovable()
    MakeQuestLogMovable()
    EnsureQuestMapUI()
    BuildMQSUI()
    RestoreMapPosition()
    UpdateBottomButtons()
    
    if WorldMapFrame and not WorldMapFrame._mqsShowHooked then
        WorldMapFrame._mqsShowHooked = true
        WorldMapFrame:HookScript("OnShow", function()
            EnsureQuestMapUI()
            UpdateBottomButtons()
            C_Timer.After(0, function()
                if UpdateQuestMapHeaderShareButtons then
                    UpdateQuestMapHeaderShareButtons()
                end
            end)
        end)
    end
end

eventFrame:SetScript("OnEvent", function(self, event, arg1, arg2, arg3, arg4)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then
            InitAddon()
        else
            EnsureQuestMapUI()
            UpdateBottomButtons()
        end
        
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        InitAddon()
        
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        local currentZone = GetRealZoneText()
        if not currentZone or IsSecret(currentZone) or type(currentZone) ~= "string" or currentZone == "" then return end
        
        if currentZone ~= MQS.lastSharedZone then
            MQS.lastSharedZone = currentZone
            
            if MyQuestLogSettings.autoShare and IsInGroup() then
                C_Timer.After(3.0, function()
                    local delayedZone = GetRealZoneText()
                    if not delayedZone or IsSecret(delayedZone) or type(delayedZone) ~= "string" then return end
                    if IsInGroup() then
                        local currentQuests = GetCurrentZoneQuests()
                        local shareList = {}
                        for _, q in ipairs(currentQuests) do
                            if not HasEveryoneAccepted(q.title) and not MQS.groupShared[q.title] then
                                table.insert(shareList, q)
                            end
                        end
                        
                        if #shareList > 0 and IsAnyGroupMemberNearby() then
                            if not MyQuestLogSettings.silentShare then
                                print("|cFF00FF00[MyQuestLog]|r Auto-sharing quests for " .. delayedZone .. "...")
                            end
                            ShareQuests(shareList)
                        end
                    end
                end)
            end
        end
        
        UpdateBottomButtons()
        
    elseif event == "GROUP_ROSTER_UPDATE" then
        if not IsInGroup() then
            MQS.lastSharedZone = nil
            MQS.groupAccepted = {}
            MQS.groupShared = {}
            MQS.peerQuests = {}
            MQS.peerVersions = {}
        else
            MQS:CleanGroupAcceptedCache()
        end
        UpdateBottomButtons()
        
    elseif event == "QUEST_LOG_UPDATE" then
        UpdateBottomButtons()
        
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, text, channel, sender = arg1, arg2, arg3, arg4
        if IsSecret(prefix) or IsSecret(text) or IsSecret(sender) then return end
        if (prefix == ADDON_PREFIX or prefix == LEGACY_PREFIX) and type(text) == "string" then
            local playerName = UnitName("player")
            local shortSender = GetShortName(sender)
            local shortPlayer = GetShortName(playerName)
            
            if shortSender and shortSender ~= shortPlayer then
                local cmd, data = string.match(text, "^([^:]+):?(.*)$")
                if cmd == "PING" then
                    MQS.peerVersions[shortSender] = data or "1.0.0"
                    SendAddonMsg(ADDON_PREFIX, "PONG:1.0.0")
                    MQS:SendQuestSync()
                elseif cmd == "PONG" then
                    MQS.peerVersions[shortSender] = data or "1.0.0"
                    MQS:SendQuestSync()
                elseif cmd == "SYNC" then
                    MQS.peerQuests[shortSender] = {}
                    if data and data ~= "" and not IsSecret(data) then
                        for pair in string.gmatch(data, "([^;]+)") do
                            local qIDStr, statusStr = string.match(pair, "^(%d+)=(%d+)$")
                            if qIDStr and statusStr then
                                local qID = tonumber(qIDStr)
                                local status = tonumber(statusStr)
                                MQS.peerQuests[shortSender][qID] = { status = status }
                            end
                        end
                    end
                elseif cmd == "REQ_SHARE" then
                    local requestedZone = (data and data ~= "" and not IsSecret(data)) and data or GetRealZoneText()
                    local currentQuests = GetCurrentZoneQuests()
                    local shareList = {}
                    for _, q in ipairs(currentQuests) do
                        if not HasEveryoneAccepted(q.title) and not MQS.groupShared[q.title] then
                            table.insert(shareList, q)
                        end
                    end
                    if #shareList > 0 and IsAnyGroupMemberNearby() then
                        if not MyQuestLogSettings.silentShare and not IsSecret(requestedZone) then
                            print("|cFF00FF00[MyQuestLog]|r Auto-responding to quest share request for " .. tostring(requestedZone) .. "...")
                        end
                        ShareQuests(shareList)
                    end
                end
            end
        end
        
    elseif event == "CHAT_MSG_SYSTEM" then
        local msg = arg1
        if not msg or IsSecret(msg) or type(msg) ~= "string" then return end
        
        if ERR_QUEST_ACCEPTED_S and not IsSecret(ERR_QUEST_ACCEPTED_S) then
            local acceptedPattern = ERR_QUEST_ACCEPTED_S:gsub("%%s", "(.+)")
            local ok, name, quest = pcall(string.match, msg, acceptedPattern)
            if ok and name and quest and not IsSecret(name) and not IsSecret(quest) then
                name = name:gsub("^%s*(.-)%s*$", "%1")
                quest = quest:gsub("^%s*(.-)%s*$", "%1")
                local shortName = GetShortName(name)
                if not MQS.groupAccepted[quest] then
                    MQS.groupAccepted[quest] = {}
                end
                MQS.groupAccepted[quest][shortName] = true
            end
        end
        
        if ERR_QUEST_ALREADY_DONE_S and not IsSecret(ERR_QUEST_ALREADY_DONE_S) then
            local donePattern = ERR_QUEST_ALREADY_DONE_S:gsub("%%s", "(.+)")
            local ok, name = pcall(string.match, msg, donePattern)
            if ok and name and not IsSecret(name) and MQS.currentlySharingQuest then
                local shortName = GetShortName(name:gsub("^%s*(.-)%s*$", "%1"))
                if not MQS.groupAccepted[MQS.currentlySharingQuest] then
                    MQS.groupAccepted[MQS.currentlySharingQuest] = {}
                end
                MQS.groupAccepted[MQS.currentlySharingQuest][shortName] = true
            end
        end
        
    elseif event == "QUEST_ACCEPTED" then
        local questIndex, questID = arg1, arg2
        if IsSecret(questIndex) or IsSecret(questID) then return end
        if questIndex and questIndex > 0 then
            local title, _, qID, _, _, level = GetQuestInfo(questIndex)
            if title and not IsSecret(title) then
                local colorHex = GetDifficultyColorHex(level)
                print(string.format("|cFF00FF00[MyQuestLog]|r Quest Accepted: %s[%s] %s|r", colorHex, tostring(level or "?"), title))
            end
        end
    end
end)

-- =============================================================
-- Slash Commands
-- =============================================================
SLASH_MYQUESTLOG1 = "/mql"
SLASH_MYQUESTLOG2 = "/myquestlog"
SLASH_MYQUESTLOG3 = "/mqs"
SLASH_MYQUESTLOG4 = "/myquestshare"
SlashCmdList["MYQUESTLOG"] = function(msg)
    local cmd = string.lower(string.match(msg or "", "^%s*(%S*)") or "")
    if cmd == "share" then
        local quests = GetCurrentZoneQuests()
        ShareQuests(quests)
    elseif cmd == "all" then
        local allQuests = {}
        local num = GetNumEntries()
        for i = 1, num do
            local qTitle, isHeader, qID, _, isComplete, qLevel = GetQuestInfo(i)
            if qTitle and not isHeader then
                table.insert(allQuests, { index = i, questID = qID, title = qTitle, level = qLevel, isComplete = isComplete })
            end
        end
        ShareQuests(allQuests, "your quest log")
    elseif cmd == "questie" or cmd == "reqquestie" then
        MQS:RequestQuestieShare()
    elseif cmd == "req" or cmd == "reqmql" or cmd == "reqmqs" or cmd == "mqlshare" then
        MQS:RequestMQSShare()
    elseif cmd == "auto" then
        MyQuestLogSettings.autoShare = not MyQuestLogSettings.autoShare
        print("|cFF00FF00[MyQuestLog]|r Auto-share is now: " .. (MyQuestLogSettings.autoShare and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"))
        if cbAutoShare then
            cbAutoShare:SetChecked(MyQuestLogSettings.autoShare)
        end
        if MQS.qmCbAuto then
            MQS.qmCbAuto:SetChecked(MyQuestLogSettings.autoShare)
        end
    elseif cmd == "levels" then
        MyQuestLogSettings.showLevels = not MyQuestLogSettings.showLevels
        print("|cFF00FF00[MyQuestLog]|r Quest level tags are now: " .. (MyQuestLogSettings.showLevels and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"))
        if QuestLog_Update then QuestLog_Update() end
    elseif cmd == "resetmap" or cmd == "reset" then
        if WorldMapFrame then
            WorldMapFrame:ClearAllPoints()
            WorldMapFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            if MyQuestLogSettings then
                MyQuestLogSettings.mapPosition = nil
            end
            print("|cFF00FF00[MyQuestLog]|r Quest & Map window position reset to screen center.|r")
        end
    elseif cmd == "status" then
        local zone = GetRealZoneText() or "Unknown"
        local matching = GetCurrentZoneQuests()
        print("|cFFFFD100[MyQuestLog Status]|r")
        print("  Current Zone: |cFFFFFFFF" .. zone .. "|r")
        print("  Matching Quests: |cFFFFFFFF" .. #matching .. "|r")
        print("  Auto-Share: " .. (MyQuestLogSettings.autoShare and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"))
        print("  Smart-Share: " .. (MyQuestLogSettings.smartShare and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"))
        print("  In Group: " .. (IsInGroup() and "|cFF00FF00Yes|r" or "|cFFFF0000No|r"))
    else
        print("|cFFFFD100[MyQuestLog Commands]|r |cFFAAAAAA(aliases: /myquestlog, /mqs)|r")
        print("  |cFFFFFFFF/mql share|r - Share current zone/dungeon quests with group")
        print("  |cFFFFFFFF/mql all|r - Share all shareable quests in log")
        print("  |cFFFFFFFF/mql auto|r - Toggle automatic sharing on zone change")
        print("  |cFFFFFFFF/mql resetmap|r - Reset quest/map window position to center")
        print("  |cFFFFFFFF/mql levels|r - Toggle quest levels & difficulty tags")
        print("  |cFFFFFFFF/mql questie|r - Request quest shares from Questie users")
        print("  |cFFFFFFFF/mql req|r - Request quest shares from MyQuestLog users")
        print("  |cFFFFFFFF/mql status|r - Display current zone matching status")
    end
end
