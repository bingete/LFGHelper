-- =============================================================
--  UI CONSTRUCTION
-- =============================================================

-- Shared Backdrop Table
local backdrop = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
}

-- 1. MAIN FRAME
local mainFrame = CreateFrame("Frame", "LFGHelperFrame", UIParent)
mainFrame:SetWidth(620)
mainFrame:SetHeight(400)
mainFrame:SetPoint("CENTER", UIParent, "CENTER")
mainFrame:SetBackdrop(backdrop)
mainFrame:SetMovable(true)
mainFrame:SetResizable(true)
mainFrame:SetMinResize(500, 400)
mainFrame:EnableMouse(true)
mainFrame:SetClampedToScreen(true)
mainFrame:Hide()

-- Main Frame Scripts
mainFrame:RegisterForDrag("LeftButton")
mainFrame:SetScript("OnMouseDown", function()
    if arg1 == "LeftButton" then
        this:StartMoving()
    elseif arg1 == "RightButton" then
        this:StartSizing("BOTTOMRIGHT")
    end
end)
mainFrame:SetScript("OnMouseUp", function()
    this:StopMovingOrSizing()
end)
mainFrame:SetScript("OnShow", function()
    if LFGHelper_OnLoad then LFGHelper_OnLoad() end
    if InitializeVisibleInstance then InitializeVisibleInstance() end
    if UpdateMainFrame then UpdateMainFrame() end
end)

-- Main Frame Title
local mainTitle = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
mainTitle:SetPoint("TOP", mainFrame, "TOP", 0, -20)
mainTitle:SetText("LFG Helper")

-- 2. FILTER FRAME
local filterFrame = CreateFrame("Frame", "LFGHelperFilterFrame", UIParent)
filterFrame:SetFrameStrata("HIGH")
filterFrame:SetWidth(550) 
filterFrame:SetHeight(450)
filterFrame:SetPoint("CENTER", UIParent, "CENTER")
filterFrame:SetBackdrop(backdrop)
filterFrame:EnableMouse(true)
filterFrame:SetMovable(true)
filterFrame:Hide()

filterFrame:RegisterForDrag("LeftButton")
filterFrame:SetScript("OnMouseDown", function() if arg1 == "LeftButton" then this:StartMoving() end end)
filterFrame:SetScript("OnMouseUp", function() this:StopMovingOrSizing() end)
filterFrame:SetScript("OnShow", function() if RefreshInstanceCheckboxes then RefreshInstanceCheckboxes() end end)

local filterTitle = filterFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
filterTitle:SetPoint("TOP", filterFrame, "TOP", 0, -20)
filterTitle:SetText("Instances Filters")

local filterClose = CreateFrame("Button", nil, filterFrame, "UIPanelCloseButton")
filterClose:SetPoint("TOPRIGHT", filterFrame, "TOPRIGHT", -15, -15)

-- 3. OPTION FRAME
local optionFrame = CreateFrame("Frame", "LFGHelperOptionFrame", UIParent)
optionFrame:SetFrameStrata("HIGH")
optionFrame:SetWidth(550)
optionFrame:SetHeight(450)
optionFrame:SetPoint("CENTER", UIParent, "CENTER")
optionFrame:SetBackdrop(backdrop)
optionFrame:EnableMouse(true)
optionFrame:SetMovable(true)
optionFrame:Hide()

optionFrame:RegisterForDrag("LeftButton")
optionFrame:SetScript("OnMouseDown", function() if arg1 == "LeftButton" then this:StartMoving() end end)
optionFrame:SetScript("OnMouseUp", function() this:StopMovingOrSizing() end)
optionFrame:SetScript("OnShow", function() if LoadLFGHelperOptions then LoadLFGHelperOptions() end end)

local optionTitle = optionFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
optionTitle:SetPoint("TOP", optionFrame, "TOP", 0, -20)
optionTitle:SetText("Addon options")

local optionClose = CreateFrame("Button", nil, optionFrame, "UIPanelCloseButton")
optionClose:SetPoint("TOPRIGHT", optionFrame, "TOPRIGHT", -15, -15)

-- 4. MAIN FRAME CHILDREN (Buttons & Scroll)

-- Filter Button
local btnFilter = CreateFrame("Button", "LFGHelperFilterButton", mainFrame, "UIPanelButtonTemplate")
btnFilter:SetWidth(100)
btnFilter:SetHeight(22)
btnFilter:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 20, -50)
btnFilter:SetText("Filters...")
btnFilter:SetScript("OnClick", function()
    if filterFrame:IsVisible() then filterFrame:Hide() else filterFrame:Show() end
end)

-- Option Button
local btnOption = CreateFrame("Button", "LFGHelperOptionButton", mainFrame, "UIPanelButtonTemplate")
btnOption:SetWidth(100)
btnOption:SetHeight(22)
btnOption:SetPoint("LEFT", btnFilter, "RIGHT", 10, 0)
btnOption:SetText("Options...")
btnOption:SetScript("OnClick", function()
    if optionFrame:IsVisible() then optionFrame:Hide() else optionFrame:Show() end
end)

-- Main Close Button
local btnClose = CreateFrame("Button", "LFGHelperCloseButton", mainFrame, "UIPanelCloseButton")
btnClose:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -15, -15)

-- Scroll Frame
local scrollFrame = CreateFrame("ScrollFrame", "LFGHelperScroll", mainFrame, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 20, -80)
scrollFrame:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -45, 20)

-- Scroll Content
local scrollContent = CreateFrame("Frame", "LFGHelperScrollContent")
scrollContent:SetWidth(440)
scrollContent:SetHeight(1)
scrollFrame:SetScrollChild(scrollContent)


-- =============================================================
--  LOGIC & DATA
-- =============================================================

local db_version = 1180

-- Keywords to detect LFG/LFM
local keywords = {
  "lfg", "lfm", "lf", "lf1m", "lf2m", "lf3m", "lf4m", "lf5m", "lf6m", "lf7m", "lf8m", "lf9m", "lf10m"
}

-- Initialize Instance Checkboxes
local instanceCheckboxes = {}

-- === FIXED FUNCTION FOR FINDING TABS ===
local function GetOrCreateLFGChatFrame()
    -- Loop 1 to 7 to find existing tab using the correct API
    for i = 1, 7 do
        local name = GetChatWindowInfo(i) -- Returns name, fontSize, etc.
        if (name == "LFG Filter") then
            return getglobal("ChatFrame"..i)
        end
    end

    -- If not found, create new one
    local newFrame = FCF_OpenNewWindow("LFG Filter")
    if newFrame then
        ChatFrame_RemoveAllMessageGroups(newFrame)
        ChatFrame_RemoveAllChannels(newFrame) 
        return newFrame
    end
    return nil
end

local function extractDungeonName(text)
  text = string.lower(text)  
  for _, data in ipairs(LFGHelperInstancesDB) do
    if type(data.acronym) == "table" then
      for _, alias in ipairs(data.acronym) do
        local acronym = string.lower(alias)
        local pattern1 = "[^%a]" .. acronym .. "[^%a]"
        local pattern2 = "^" .. acronym .. "[^%a]"
        local pattern3 = "[^%a]" .. acronym .. "$"
        local pattern4 = "^" .. acronym .. "$"

        if string.find(text, pattern1) or string.find(text, pattern2)
            or string.find(text, pattern3) or string.find(text, pattern4) then
          return data.instanceName
        end
      end
    end
  end
  return nil
end

local function SanitizeInstanceName(name)
    name = string.lower(name)
    name = string.gsub(name, "%s+", "_")
    return name
end

local function CleanupOldEntries()
    local threshold = (LFGHelperSettings.cleanupMinutes or 15) * 60
    local count = table.getn(LFGHelperPostingDB)
    for i = count, 1, -1 do
        local data = LFGHelperPostingDB[i]
        if time() - data.timestamp > threshold then
            table.remove(LFGHelperPostingDB, i)
        end
    end
    UpdateMainFrame()
end

function UpdateMainFrame()
    local contentFrame = LFGHelperScrollContent

    -- Hide old rows
    if contentFrame.rows then
        for _, row in ipairs(contentFrame.rows) do
            row:Hide()
        end
    else
        contentFrame.rows = {}
    end

    -- Rebuild visible instances mapping
    for _, data in ipairs(LFGHelperInstancesDB) do
        local sanitizedName = SanitizeInstanceName(data.instanceName)
        LFGHelperVisibleInstances[sanitizedName] = (data.show == 1 or data.show == true)
    end

    local yOffset = -10
    local rowHeight = 30
    local currentY = -10
    local rowCount = 0
    contentFrame:SetWidth(640)

    -- Loop through visible instances
    for instanceName, isVisible in pairs(LFGHelperVisibleInstances) do
        if isVisible then
            for _, postingData in ipairs(LFGHelperPostingDB) do
                local sanitizedPostingInstance = SanitizeInstanceName(postingData.instance)
                if instanceName == sanitizedPostingInstance then
                    -- Create row frame
                    local rowFrame = CreateFrame("Frame", nil, contentFrame)
                    rowFrame:SetWidth(590)
                    rowFrame:SetHeight(rowHeight)
                    rowFrame:SetPoint("TOPLEFT", 0, currentY)
                    currentY = currentY - rowHeight - 5
                    rowCount = rowCount + 1

                    local senderWidth, instanceWidth, textWidth, timeWidth = 60, 100, 340, 60

                    -- Button (Invite or Whisper)
                    local button = CreateFrame("Button", nil, rowFrame, "UIPanelButtonTemplate")
                    button:SetWidth(60)
                    button:SetHeight(rowHeight)
                    button:SetPoint("LEFT", 0, 0)
                    
                    local senderName = postingData.sender
                    local lowerText = string.lower(postingData.text or "")
                    
                    if string.find(lowerText, "lfg") then
                        button:SetText("INVITE")
                        button:SetScript("OnClick", function()
                            if senderName then
                                InviteByName(senderName)
                            end
                        end)
                    else
                        -- WHISPER BUTTON LOGIC
                        button:SetText("WHISPER")
                        button:SetScript("OnClick", function()
                            if senderName then
                                local editBox = ChatFrame1EditBox
                                editBox:Show()
                                editBox:SetFocus()
                                editBox:SetText("/w " .. senderName .. " ")
                            end
                        end)
                    end

                    -- Sender column
                    local senderFont = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                    senderFont:SetText(senderName)
                    senderFont:SetWidth(senderWidth)
                    senderFont:SetJustifyH("LEFT")
                    senderFont:SetPoint("LEFT", button, "RIGHT", 10, 0)

                    -- Instance column
                    local instanceFont = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                    instanceFont:SetText(postingData.instance)
                    instanceFont:SetWidth(instanceWidth)
                    instanceFont:SetJustifyH("LEFT")
                    instanceFont:SetPoint("LEFT", senderFont, "RIGHT", 10, 0)

                    -- Message column
                    local messageFont = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    messageFont:SetText(postingData.text)
                    messageFont:SetWidth(textWidth)
                    messageFont:SetJustifyH("LEFT")
                    messageFont:SetPoint("LEFT", instanceFont, "RIGHT", 10, 0)

                    -- Time column
                    local timeFont = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    local timelapse = math.floor((time() - postingData.timestamp) / 60)
                    timeFont:SetText(timelapse .. " mins ago")
                    timeFont:SetWidth(timeWidth)
                    timeFont:SetJustifyH("LEFT")
                    timeFont:SetPoint("LEFT", messageFont, "RIGHT", 10, 0)

                    table.insert(contentFrame.rows, rowFrame)
                end
            end
        end
    end

    if rowCount == 0 then
        contentFrame:SetHeight(100)
    else
        contentFrame:SetHeight(math.abs(currentY) + 20)
    end

    LFGHelperScroll:UpdateScrollChildRect()
end

function senderAlreadyPosted(sender)
    for index, posting in ipairs(LFGHelperPostingDB) do
        if posting.sender == sender then
            return index
        end
    end
    return nil
end

function CreateOrUpdatePosting(sender, instance, sanitized_instance, msg, channelNumber, keyword)
    local index = senderAlreadyPosted(sender)
    CleanupOldEntries()
    if index then
        LFGHelperPostingDB[index].instance = instance
        LFGHelperPostingDB[index].sanitized_instance = sanitized_instance
        LFGHelperPostingDB[index].text = msg
        LFGHelperPostingDB[index].timestamp = time()
    else
        table.insert(LFGHelperPostingDB, {
            sender = sender,
            instance = instance,
            sanitized_instance = sanitized_instance,
            text = msg,
            lookingfor = keyword,
            timestamp = time()
        })
    end
end

function InitializeVisibleInstance()
  wipe(LFGHelperVisibleInstances)

  for _, data in ipairs(LFGHelperInstancesDB) do
    if data.show then
      local sanitizedName = SanitizeInstanceName(data.instanceName)
      LFGHelperVisibleInstances[sanitizedName] = true
    end
  end
end

function RefreshInstanceCheckboxes()
    for _, data in ipairs(LFGHelperInstancesDB) do
        local sanitizedName = SanitizeInstanceName(data.instanceName)
        local checkbox = instanceCheckboxes[sanitizedName]
        if checkbox then
            checkbox:SetChecked(data.show)
            if data.show then
                LFGHelperVisibleInstances[sanitizedName] = true
            else
                LFGHelperVisibleInstances[sanitizedName] = nil
            end
        end
    end
end

function CreateInstanceCheckboxes()
    local rowsPerColumnRaids = 3
    local rowsPerColumnDungeons = 13
    local xStart, xSpacing = 30, 180
    local yOffset = -20

    local function CreateSection(title, instanceType, rowsPerColumn, yStart)
        local titleFont = LFGHelperFilterFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        titleFont:SetText(title)
        titleFont:SetPoint("TOPLEFT", LFGHelperFilterFrame, "TOPLEFT", 25, yStart)

        local row, column = 0, 0
        local currentY = yStart - 20

        for _, data in ipairs(LFGHelperInstancesDB) do
            if data.type == instanceType then
                if row >= rowsPerColumn then
                    row = 0
                    column = column + 1
                end

                local sanitizedName = SanitizeInstanceName(data.instanceName)
                LFGHelperVisibleInstances[sanitizedName] = (data.show == 1 or data.show == true)

                if not instanceCheckboxes[sanitizedName] then
                    local checkbox = CreateFrame("CheckButton", "LFGInstanceCheckbox_"..sanitizedName, LFGHelperFilterFrame, "UICheckButtonTemplate")
                    checkbox:SetWidth(20)
                    checkbox:SetHeight(20)
                    checkbox.dataReference = data
                    getglobal(checkbox:GetName().."Text"):SetText(data.instanceName)
                    checkbox:SetPoint("TOPLEFT", xStart + (column*xSpacing), currentY + (row*yOffset))
                    checkbox:SetChecked(data.show == 1 or data.show == true)

                    checkbox:SetScript("OnClick", function()
                        local checked = this:GetChecked()
                        LFGHelperVisibleInstances[sanitizedName] = checked
                        this.dataReference.show = checked and 1 or 0
                        UpdateMainFrame()
                    end)

                    instanceCheckboxes[sanitizedName] = checkbox
                end

                row = row + 1
            end
        end

        return currentY + (row * yOffset) - 40
    end

    local nextSectionY = -40
    nextSectionY = CreateSection("Raids", "raid", rowsPerColumnRaids, nextSectionY)
    CreateSection("Dungeons", "dungeon", rowsPerColumnDungeons, nextSectionY)
end

function LoadLFGHelperOptions()
    local frame = LFGHelperOptionFrame
    local cleanupMinutes = LFGHelperSettings.cleanupMinutes or 15

    if not frame.cleanupSlider then
        local slider = CreateFrame("Slider", "LFGHelperCleanupSlider", frame, "OptionsSliderTemplate")
        slider:SetWidth(200)
        slider:SetHeight(20)
        slider:SetMinMaxValues(1, 60)
        slider:SetValueStep(1)
        slider:SetValue(cleanupMinutes)
        slider:SetPoint("TOP", 0, -60)

        getglobal(slider:GetName() .. 'Low'):SetText("1 min")
        getglobal(slider:GetName() .. 'High'):SetText("60 mins")
        getglobal(slider:GetName() .. 'Text'):SetText("Auto-Remove Postings After (mins)")

        local valueText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        valueText:SetPoint("TOP", slider, "BOTTOM", 0, -10)
        valueText:SetText(cleanupMinutes .. " minutes")

        slider:SetScript("OnValueChanged", function()
            local value = math.floor(slider:GetValue())
            valueText:SetText(value .. " minutes")
            LFGHelperSettings.cleanupMinutes = value
        end)
        frame.cleanupSlider = slider
        frame.cleanupSliderValueText = valueText
    else
        frame.cleanupSlider:SetValue(cleanupMinutes)
        frame.cleanupSliderValueText:SetText(cleanupMinutes .. " minutes")
    end

    if not frame.continueScanCheckbox then
        local check = CreateFrame("CheckButton", "LFGHelperContinueScanCheck", frame, "UICheckButtonTemplate")
        check:SetPoint("TOPLEFT", frame.cleanupSlider, "BOTTOMLEFT", 0, -40)

        local label = check:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("LEFT", check, "RIGHT", 5, 0)
        label:SetText("Continue scanning while window is closed")

        check:SetChecked(LFGHelperSettings.continueScanning or false)

        check:SetScript("OnClick", function()
        LFGHelperSettings.continueScanning = this:GetChecked() and true or false
        end)

        frame.continueScanCheckbox = check
    else
        frame.continueScanCheckbox:SetChecked(LFGHelperSettings.continueScanning or false)
    end
end

function CreateLFGHelperMinimapButton()
    local minimapButton = CreateFrame("Button", "LFGHelperMinimapButton", Minimap)
    minimapButton:SetFrameStrata("MEDIUM")
    minimapButton:SetWidth(32)
    minimapButton:SetHeight(32)
    minimapButton:SetMovable(true)
    minimapButton:EnableMouse(true)
    minimapButton:RegisterForDrag("LeftButton")
    minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp");
    minimapButton:SetPoint("TOPLEFT", Minimap, "BOTTOMLEFT", 0, 0)
    minimapButton:SetScript("OnEnter", function()
      GameTooltip:SetOwner(minimapButton, "ANCHOR_TOP")
      GameTooltip:AddLine("LFG Helper");
      GameTooltip:AddLine("Left-click to open/close the main window", 1, 1, 1);
      GameTooltip:AddLine("Right-click to open the options", 1, 1, 1);
      GameTooltip:Show()
    end)
    minimapButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    local texture = minimapButton:CreateTexture(nil, "BACKGROUND")
    texture:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
    texture:SetAllPoints(minimapButton)
    minimapButton.texture = texture
    minimapButton:SetScript("OnClick", function()
      local button = arg1 

      if button == "LeftButton" then
          if LFGHelperFrame:IsVisible() then
              LFGHelperFrame:Hide()
          else
              LFGHelperFrame:Show()
              UpdateMainFrame()
          end
      elseif button == "RightButton" then
          if LFGHelperOptionFrame:IsVisible() then
              LFGHelperOptionFrame:Hide()
          else
              LFGHelperOptionFrame:Show()
          end
      end
    end)
    minimapButton:SetScript("OnDragStart", function()
        this:StartMoving()
    end)
    minimapButton:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
    end)
end

-- On Addon Load
function LFGHelper_OnLoad()
    if not LFGHelperInstancesDB or not LFGHelperInstancesDBVersion or LFGHelperInstancesDBVersion < db_version then
        LFGHelperInstancesDBVersion = db_version
        LFGHelperInstancesDB = {
            { instanceName = "Ragefire Chasm", type = "dungeon", acronym = {"rfc", "ragefire"}, show = false },
            { instanceName = "The Deadmines", type = "dungeon", acronym = {"deadmines", "deadmine"}, show = false },
            { instanceName = "Wailing Caverns", type = "dungeon", acronym = {"wc", "wailing"}, show = false },
            { instanceName = "Shadowfang Keep", type = "dungeon", acronym = {"sfk"}, show = false },
            { instanceName = "Blackfathom Deeps", type = "dungeon", acronym = {"bfd"}, show = false },
            { instanceName = "The Stockade", type = "dungeon", acronym = {"stockade"}, show = false },
            { instanceName = "Dragonmaw Retreat", type = "dungeon", acronym = {"dragonmaw", "retreat"}, show = false },
            { instanceName = "Gnomeregan", type = "dungeon", acronym = {"gnome", "gnomeregan"}, show = false },
            { instanceName = "Razorfen Kraul", type = "dungeon", acronym = {"rfk", "kraul"}, show = false },
            { instanceName = "Scarlet Monastery Graveyard", type = "dungeon", acronym = {"sm grave", "smg", "graveyard"}, show = false },
            { instanceName = "Scarlet Monastery Library", type = "dungeon", acronym = {"sm lib", "library"}, show = false },
            { instanceName = "Stormwrought Castle", type = "dungeon", acronym = {"castle", "sr castle"}, show = false },
            { instanceName = "The Crescent Grove", type = "dungeon", acronym = {"crescent", "cg", "grove"}, show = false },
            { instanceName = "Scarlet Monastery Armory", type = "dungeon", acronym = {"sm arm", "armory"}, show = false },
            { instanceName = "Razorfen Down", type = "dungeon", acronym = {"rfd"}, show = false },
            { instanceName = "Stormwrought Descent", type = "dungeon", acronym = {"descent", "sr descent"}, show = false },
            { instanceName = "Scarlet Monastery Cathedral", type = "dungeon", acronym = {"sm cath", "cathedral", "cath"}, show = false },
            { instanceName = "Uldaman", type = "dungeon", acronym = {"uld", "uldaman"}, show = false },
            { instanceName = "Zul'Farrak", type = "dungeon", acronym = {"zf", "farrak"}, show = false },
            { instanceName = "Gilneas City", type = "dungeon", acronym = {"gc", "gilneas"}, show = false },
            { instanceName = "Maraudon", type = "dungeon", acronym = {"maraudon", "mar"}, show = false },
            { instanceName = "Maraudon Princess", type = "dungeon", acronym = {"princess"}, show = false },
            { instanceName = "Temple of Atal'Hakkar", type = "dungeon", acronym = {"sunken", "temple", "atal"}, show = false },
            { instanceName = "Blackrock Depths Arena", type = "dungeon", acronym = {"arena"}, show = false },
            { instanceName = "Hateforge Quarry", type = "dungeon", acronym = {"hq", "hateforge", "quarry"}, show = false },
            { instanceName = "Blackrock Depths", type = "dungeon", acronym = {"brd"}, show = false },
            { instanceName = "Blackrock Depths Emperor", type = "dungeon", acronym = {"emperor", "emp"}, show = false },
            { instanceName = "Lower Blackrock Spire", type = "dungeon", acronym = {"lbrs"}, show = false },
            { instanceName = "Dire Maul", type = "dungeon", acronym = {"dm", "dmw", "dme", "dmn"}, show = false },
            { instanceName = "Scholomance", type = "dungeon", acronym = {"scholo", "scholomance"}, show = false },
            { instanceName = "Stratholme", type = "dungeon", acronym = {"strat"}, show = false },
            { instanceName = "Karazhan Crypt", type = "dungeon", acronym = {"crypt"}, show = false },
            { instanceName = "Black Morass", type = "dungeon", acronym = {"morass", "black", "bm"}, show = false },
            { instanceName = "Stormwind Vault", type = "dungeon", acronym = {"vault"}, show = false },
            { instanceName = "Upper Blackrock Spire", type = "dungeon", acronym = {"ubrs"}, show = false },
            { instanceName = "Molten Core", type = "raid", acronym = {"mc", "molten", "molten core"}, show = false },
            { instanceName = "Blackwing Lair", type = "raid", acronym = {"bwl"}, show = false },
            { instanceName = "Emerald Sanctum", type = "raid", acronym = {"es", "emerald", "sanctum"}, show = false },
            { instanceName = "Karazhan", type = "raid", acronym = {"kara"}, show = false },
            { instanceName = "Onyxia", type = "raid", acronym = {"ony", "onyxia"}, show = false },
            { instanceName = "Zul'Gurub", type = "raid", acronym = {"zg", "gurub"}, show = false },
            { instanceName = "Naxxramas", type = "raid", acronym = {"naxx"}, show = false },
            { instanceName = "Ahn'Qiraj", type = "raid", acronym = {"aq", "ahn"}, show = false }
        }
    end

    if not LFGHelperPostingDB then
        LFGHelperPostingDB = {}
    end
    if not LFGHelperVisibleInstances then
        LFGHelperVisibleInstances = {}
    end
    if not LFGHelperSettings then
      LFGHelperSettings = {}
    end
    if not LFGHelperSettings.cleanupMinutes then
        LFGHelperSettings.cleanupMinutes = 15
    end
    if LFGHelperSettings.continueScanning == nil then
        LFGHelperSettings.continueScanning = false
    end
end

-- Create main event frame
local f = CreateFrame("Frame")
f:RegisterEvent("CHAT_MSG_CHANNEL")
f:RegisterEvent("VARIABLES_LOADED")
f:SetScript("OnEvent", function()
  if event == "VARIABLES_LOADED" then
    contentFrame = LFGHelperScrollContent
    LFGHelper_OnLoad()
    InitializeVisibleInstance()
    CreateLFGHelperMinimapButton()
    CreateInstanceCheckboxes()
    -- Register slash command once UI is loaded
    SLASH_LFGHELPER1 = "/lfghelper"
    SlashCmdList["LFGHELPER"] = function(msg)
        msg = string.lower(msg or "")

        if msg == "show" then
            LFGHelperFrame:Show()
            UpdateMainFrame()

        elseif msg == "hide" then
            LFGHelperFrame:Hide()

        elseif msg == "options" then
            if LFGHelperOptionFrame:IsVisible() then
                LFGHelperOptionFrame:Hide()
            else
                LFGHelperOptionFrame:Show()
            end

        else
            if LFGHelperFrame:IsVisible() then
                LFGHelperFrame:Hide()
            else
                LFGHelperFrame:Show()
                UpdateMainFrame()
            end
        end
    end

  elseif event == "CHAT_MSG_CHANNEL" and (LFGHelperFrame:IsVisible() or LFGHelperSettings.continueScanning) then
    local msg = arg1
    local sender = arg2
    local language = arg3
    local channelNumber = arg8
    
    -- Scans channels 2, 4, 5
    if (channelNumber == 2 or channelNumber == 4 or channelNumber == 5) then
      CleanupOldEntries()
      local lowerMsg = string.lower(msg)
        for i = 1, table.getn(keywords) do
          if string.find(lowerMsg, keywords[i]) then
            local dungeonName = extractDungeonName(lowerMsg)
            if dungeonName then
              local sanitizedName = SanitizeInstanceName(dungeonName)
              if LFGHelperVisibleInstances[sanitizedName] then
                
                CreateOrUpdatePosting(sender, dungeonName, sanitizedName, msg, channelNumber, keywords[i])
                
                if LFGHelperFrame:IsVisible() then
                    UpdateMainFrame()
                end
                
                -- PRINT TO CHAT TAB
                local targetFrame = GetOrCreateLFGChatFrame()
                if targetFrame then
                    local playerLink = "|Hplayer:" .. sender .. "|h|cff33ff99[" .. sender .. "]|r|h"
                    local instanceTag = "|cff00ccff[" .. dungeonName .. "]|r"
                    local formattedMsg = instanceTag .. " " .. playerLink .. ": " .. msg
                    targetFrame:AddMessage(formattedMsg)
                end
                
              end
            end
          end
        end
    end
  end
end)