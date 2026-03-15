-- KeySystem.lua  -  LinoriaLib-Mobile addon  (v2.0 Enhanced)
--
-- Improvements over v1:
--   • Own ScreenGui with IgnoreGuiInset=true  → backdrop covers the full screen,
--     including the top Roblox buttons that the old version left exposed
--   • Tabbed interface  (Key Verification | Account Info | Support)
--   • Sound effects on every interaction  (click, success, error, open, close)
--   • Dynamic animations: spring entrance, tab slide, error shake, success flash,
--     pulsing accent line, loading dots, button press-scale, input glow on focus
--   • Account panel: username, display name, user ID, account age, current game
--   • Support panel: Discord link, Get Key card, Clear Saved Key card
--   • Paste-from-clipboard button, eye-toggle for key visibility
--   • Copy HWID button

local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local SoundService     = game:GetService("SoundService")
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local CoreGui          = game:GetService("CoreGui")
local Debris           = game:GetService("Debris")
local LocalPlayer      = Players.LocalPlayer

local KeySystem = {}
KeySystem.Library = nil

function KeySystem:SetLibrary(lib)
    self.Library = lib
end

-- ── File helpers ─────────────────────────────────────────────────────────────
local KEY_FILE = "romazdev_key.txt"

local function fsOk()
    return type(writefile) == "function"
        and type(readfile)  == "function"
        and type(isfile)    == "function"
end

local function saveKey(key)
    if fsOk() then pcall(writefile, KEY_FILE, key) end
end

local function loadSavedKey()
    if not fsOk() then return nil end
    local ok, v = pcall(readfile, KEY_FILE)
    return (ok and v and v ~= "") and v or nil
end

local function deleteSavedKey()
    if fsOk() then pcall(delfile, KEY_FILE) end
end

-- ── URL / clipboard helpers ───────────────────────────────────────────────────
local function openLink(url)
    if openurl then pcall(openurl, url); return true end
    if setclipboard then setclipboard(url) end
    return false
end

local function pasteClipboard()
    if getclipboard then
        local ok, txt = pcall(getclipboard)
        if ok and txt then return txt end
    end
    return nil
end

local function copyToClipboard(text)
    if setclipboard then pcall(setclipboard, text) end
end

-- ── Sound helpers ─────────────────────────────────────────────────────────────
-- All sounds wrapped in pcall so a missing asset never breaks auth flow
local function playSound(id, vol, pitch)
    pcall(function()
        local s = Instance.new("Sound")
        s.SoundId       = "rbxassetid://" .. tostring(id)
        s.Volume        = vol   or 0.35
        s.PlaybackSpeed = pitch or 1
        s.Parent        = SoundService
        s:Play()
        Debris:AddItem(s, 5)
    end)
end

-- Free Roblox UI sound assets
local SFX = {
    Click   = 6042053626,   -- soft UI tick
    Success = 4398046838,   -- bright chime
    Error   = 2578062379,   -- low buzz
    Open    = 4614590573,   -- whoosh up
    Close   = 4614590568,   -- whoosh down
    Tab     = 142082476,    -- subtle click
}

-- ── Tween helpers ─────────────────────────────────────────────────────────────
local function tw(obj, info, props)
    return TweenService:Create(obj, info, props)
end

local T_SPRING = TweenInfo.new(0.40, Enum.EasingStyle.Back,  Enum.EasingDirection.Out)
local T_EASE   = TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local T_IN     = TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
local T_QUICK  = TweenInfo.new(0.12, Enum.EasingStyle.Quad,  Enum.EasingDirection.Out)
local T_PULSE  = TweenInfo.new(1.6,  Enum.EasingStyle.Sine,  Enum.EasingDirection.InOut)

-- ── Authenticate ──────────────────────────────────────────────────────────────
function KeySystem:Authenticate(options)
    options = options or {}

    local Library = self.Library
    assert(Library, "[KeySystem] call SetLibrary(lib) before Authenticate()")

    -- Load Junkie SDK
    local Junkie = loadstring(game:HttpGet("https://jnkie.com/sdk/library.lua"))()
    Junkie.script_key = options.ScriptKey  or options.Identifier or ""
    Junkie.service    = options.Service    or "SCRIPT"
    Junkie.identifier = options.Identifier or ""
    Junkie.Provider   = options.Provider   or "Romazhub"

    -- ── Fast-path: re-use cached / env key ───────────────────────────────────
    local cached = loadSavedKey() or getgenv().SCRIPT_KEY
    if cached then
        local ok, result = pcall(Junkie.check_key, cached)
        if ok and result and result.valid then
            getgenv().SCRIPT_KEY = cached
            return cached
        else
            deleteSavedKey()
            getgenv().SCRIPT_KEY = nil
        end
    end

    -- ── Layout constants ─────────────────────────────────────────────────────
    local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
    local vp       = workspace.CurrentCamera.ViewportSize
    local DW       = isMobile and math.min(340, math.floor(vp.X * 0.92)) or 460
    local DH       = 320
    local PAD      = 12

    -- ── Build a dedicated ScreenGui with IgnoreGuiInset ──────────────────────
    -- This ensures the backdrop covers the ENTIRE screen, including the top area
    -- that the Roblox CoreGui buttons sit in (the inset region).
    local KeyGui = Instance.new("ScreenGui")
    KeyGui.Name           = "KeySystemGui"
    KeyGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    KeyGui.IgnoreGuiInset = true     -- ← fixes the "top not covered" issue
    KeyGui.ResetOnSpawn   = false;
    (protectgui or (syn and syn.protect_gui) or function() end)(KeyGui)
    KeyGui.Parent = CoreGui

    -- ── Full-screen animated backdrop ────────────────────────────────────────
    local Backdrop = Instance.new("Frame")
    Backdrop.Name                   = "Backdrop"
    Backdrop.BackgroundColor3       = Color3.fromRGB(4, 4, 8)
    Backdrop.BackgroundTransparency = 1          -- fades in
    Backdrop.BorderSizePixel        = 0
    Backdrop.Size                   = UDim2.new(1, 0, 1, 0)
    Backdrop.ZIndex                 = 200
    Backdrop.Parent                 = KeyGui

    local BdGrad = Instance.new("UIGradient")
    BdGrad.Color    = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(6, 6, 18)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
    })
    BdGrad.Rotation = 135
    BdGrad.Parent   = Backdrop

    -- Fade backdrop in
    tw(Backdrop, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { BackgroundTransparency = 0.42 }):Play()

    -- ── Outer glow ring ───────────────────────────────────────────────────────
    local GlowFrame = Instance.new("Frame")
    GlowFrame.AnchorPoint      = Vector2.new(0.5, 0.5)
    GlowFrame.BackgroundColor3 = Library.AccentColor
    GlowFrame.BackgroundTransparency = 0.75
    GlowFrame.BorderSizePixel  = 0
    GlowFrame.Position         = UDim2.new(0.5, 0, 0.5, 0)
    GlowFrame.Size             = UDim2.fromOffset(DW + 12, DH + 12)
    GlowFrame.ZIndex           = 200
    GlowFrame.Parent           = Backdrop
    Library:Create("UICorner", { CornerRadius = UDim.new(0, 12), Parent = GlowFrame })

    -- ── Dialog border frame ───────────────────────────────────────────────────
    local DialogOuter = Instance.new("Frame")
    DialogOuter.Name             = "DialogOuter"
    DialogOuter.AnchorPoint      = Vector2.new(0.5, 0.5)
    DialogOuter.BackgroundColor3 = Library.AccentColor
    DialogOuter.BorderSizePixel  = 0
    DialogOuter.Position         = UDim2.new(0.5, 0, 0.5, 0)
    DialogOuter.Size             = UDim2.fromOffset(DW, DH)
    DialogOuter.ZIndex           = 201
    DialogOuter.Parent           = Backdrop
    Library:Create("UICorner", { CornerRadius = UDim.new(0, 8), Parent = DialogOuter })
    Library:AddToRegistry(DialogOuter, { BackgroundColor3 = "AccentColor" })

    -- ── Dialog inner panel ────────────────────────────────────────────────────
    local Dialog = Instance.new("Frame")
    Dialog.Name             = "Dialog"
    Dialog.BackgroundColor3 = Library.MainColor
    Dialog.BorderSizePixel  = 0
    Dialog.Position         = UDim2.new(0, 1, 0, 1)
    Dialog.Size             = UDim2.new(1, -2, 1, -2)
    Dialog.ZIndex           = 202
    Dialog.Parent           = DialogOuter
    Library:Create("UICorner", { CornerRadius = UDim.new(0, 7), Parent = Dialog })
    Library:AddToRegistry(Dialog, { BackgroundColor3 = "MainColor" })

    -- ── Header bar ────────────────────────────────────────────────────────────
    local Header = Instance.new("Frame")
    Header.BackgroundColor3 = Library.BackgroundColor
    Header.BorderSizePixel  = 0
    Header.Size             = UDim2.new(1, 0, 0, 36)
    Header.ZIndex           = 203
    Header.Parent           = Dialog
    Library:Create("UICorner", { CornerRadius = UDim.new(0, 7), Parent = Header })
    Library:AddToRegistry(Header, { BackgroundColor3 = "BackgroundColor" })

    -- Square off the bottom corners of the header visually
    local HeaderFix = Instance.new("Frame")
    HeaderFix.BackgroundColor3 = Library.BackgroundColor
    HeaderFix.BorderSizePixel  = 0
    HeaderFix.Position         = UDim2.new(0, 0, 0.5, 0)
    HeaderFix.Size             = UDim2.new(1, 0, 0.5, 0)
    HeaderFix.ZIndex           = 202
    HeaderFix.Parent           = Header
    Library:AddToRegistry(HeaderFix, { BackgroundColor3 = "BackgroundColor" })

    local HGrad = Instance.new("UIGradient")
    HGrad.Color    = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 30, 44)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 20, 28)),
    })
    HGrad.Rotation = 90
    HGrad.Parent   = Header

    local LockIco = Instance.new("TextLabel")
    LockIco.BackgroundTransparency = 1
    LockIco.Font                   = Enum.Font.GothamBold
    LockIco.Position               = UDim2.new(0, 10, 0, 0)
    LockIco.Size                   = UDim2.new(0, 22, 1, 0)
    LockIco.Text                   = "🔐"
    LockIco.TextSize               = 14
    LockIco.ZIndex                 = 205
    LockIco.Parent                 = Header

    local TitleLbl = Instance.new("TextLabel")
    TitleLbl.BackgroundTransparency = 1
    TitleLbl.Font                   = Enum.Font.GothamBold
    TitleLbl.Position               = UDim2.new(0, 36, 0, 0)
    TitleLbl.Size                   = UDim2.new(1, -96, 1, 0)
    TitleLbl.Text                   = options.Title or "Key Verification"
    TitleLbl.TextColor3             = Library.FontColor
    TitleLbl.TextSize               = 13
    TitleLbl.TextXAlignment         = Enum.TextXAlignment.Left
    TitleLbl.ZIndex                 = 205
    TitleLbl.Parent                 = Header
    Library:AddToRegistry(TitleLbl, { TextColor3 = "FontColor" })

    local VerLbl = Instance.new("TextLabel")
    VerLbl.BackgroundTransparency = 1
    VerLbl.Font                   = Enum.Font.Code
    VerLbl.AnchorPoint            = Vector2.new(1, 0)
    VerLbl.Position               = UDim2.new(1, -8, 0, 0)
    VerLbl.Size                   = UDim2.new(0, 70, 1, 0)
    VerLbl.Text                   = options.Version or "v2.0"
    VerLbl.TextColor3             = Color3.fromRGB(80, 80, 110)
    VerLbl.TextSize               = 10
    VerLbl.TextXAlignment         = Enum.TextXAlignment.Right
    VerLbl.ZIndex                 = 205
    VerLbl.Parent                 = Header

    -- ── Animated accent line ──────────────────────────────────────────────────
    local AccentLine = Instance.new("Frame")
    AccentLine.BackgroundColor3 = Library.AccentColor
    AccentLine.BorderSizePixel  = 0
    AccentLine.Position         = UDim2.new(0, 0, 0, 36)
    AccentLine.Size             = UDim2.new(0, 0, 0, 2)   -- width animates in
    AccentLine.ZIndex           = 204
    AccentLine.Parent           = Dialog
    Library:AddToRegistry(AccentLine, { BackgroundColor3 = "AccentColor" })

    -- ── Tab bar ───────────────────────────────────────────────────────────────
    local TabBar = Instance.new("Frame")
    TabBar.BackgroundColor3 = Library.BackgroundColor
    TabBar.BorderSizePixel  = 0
    TabBar.Position         = UDim2.new(0, 0, 0, 40)
    TabBar.Size             = UDim2.new(1, 0, 0, 28)
    TabBar.ZIndex           = 203
    TabBar.Parent           = Dialog
    Library:AddToRegistry(TabBar, { BackgroundColor3 = "BackgroundColor" })

    local TabList = Instance.new("UIListLayout")
    TabList.FillDirection = Enum.FillDirection.Horizontal
    TabList.SortOrder     = Enum.SortOrder.LayoutOrder
    TabList.Parent        = TabBar

    -- ── Content area ──────────────────────────────────────────────────────────
    -- sits between tab bar (y=68) and status bar (22px from bottom)
    local ContentTop = 70
    local StatusH    = 24
    local ContentH   = DH - ContentTop - StatusH - 2   -- 2px = border

    local ContentArea = Instance.new("Frame")
    ContentArea.BackgroundTransparency = 1
    ContentArea.BorderSizePixel        = 0
    ContentArea.ClipsDescendants       = true
    ContentArea.Position               = UDim2.new(0, 0, 0, ContentTop)
    ContentArea.Size                   = UDim2.new(1, 0, 0, ContentH)
    ContentArea.ZIndex                 = 203
    ContentArea.Parent                 = Dialog

    -- ── Status bar ────────────────────────────────────────────────────────────
    local StatusBar = Instance.new("Frame")
    StatusBar.AnchorPoint      = Vector2.new(0, 1)
    StatusBar.BackgroundColor3 = Library.BackgroundColor
    StatusBar.BorderSizePixel  = 0
    StatusBar.Position         = UDim2.new(0, 0, 1, 0)
    StatusBar.Size             = UDim2.new(1, 0, 0, StatusH)
    StatusBar.ZIndex           = 203
    StatusBar.Parent           = Dialog
    Library:Create("UICorner", { CornerRadius = UDim.new(0, 7), Parent = StatusBar })
    Library:AddToRegistry(StatusBar, { BackgroundColor3 = "BackgroundColor" })

    local SBFix = Instance.new("Frame")   -- square the top corners
    SBFix.BackgroundColor3 = Library.BackgroundColor
    SBFix.BorderSizePixel  = 0
    SBFix.Position         = UDim2.new(0, 0, 0, 0)
    SBFix.Size             = UDim2.new(1, 0, 0.5, 0)
    SBFix.ZIndex           = 202
    SBFix.Parent           = StatusBar
    Library:AddToRegistry(SBFix, { BackgroundColor3 = "BackgroundColor" })

    local SBDot = Instance.new("Frame")
    SBDot.BackgroundColor3 = Library.AccentColor
    SBDot.BorderSizePixel  = 0
    SBDot.Position         = UDim2.new(0, 8, 0.5, -3)
    SBDot.Size             = UDim2.fromOffset(6, 6)
    SBDot.ZIndex           = 205
    SBDot.Parent           = StatusBar
    Library:Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = SBDot })
    Library:AddToRegistry(SBDot, { BackgroundColor3 = "AccentColor" })

    local SBText = Instance.new("TextLabel")
    SBText.BackgroundTransparency = 1
    SBText.Font                   = Enum.Font.Code
    SBText.Position               = UDim2.new(0, 20, 0, 0)
    SBText.Size                   = UDim2.new(1, -24, 1, 0)
    SBText.Text                   = "Ready"
    SBText.TextColor3             = Color3.fromRGB(110, 110, 135)
    SBText.TextSize               = 10
    SBText.TextXAlignment         = Enum.TextXAlignment.Left
    SBText.ZIndex                 = 205
    SBText.Parent                 = StatusBar

    local function setStatusBar(msg, col)
        SBText.Text            = msg or ""
        SBDot.BackgroundColor3 = col  or Library.AccentColor
    end

    -- ═══════════════════════════════ TAB SYSTEM ═══════════════════════════════
    local activeTab = nil

    local function createTab(name, icon, order)
        -- Tab button
        local TabBtn = Instance.new("TextButton")
        TabBtn.AutoButtonColor  = false
        TabBtn.BackgroundColor3 = Library.BackgroundColor
        TabBtn.BorderSizePixel  = 0
        TabBtn.Font             = Library.Font
        TabBtn.LayoutOrder      = order
        TabBtn.Size             = UDim2.new(0, 90, 1, 0)
        TabBtn.Text             = icon .. "  " .. name
        TabBtn.TextColor3       = Color3.fromRGB(110, 110, 135)
        TabBtn.TextSize         = 11
        TabBtn.ZIndex           = 205
        TabBtn.Parent           = TabBar
        Library:AddToRegistry(TabBtn, { BackgroundColor3 = "BackgroundColor" })

        -- Active-tab underline
        local Indicator = Instance.new("Frame")
        Indicator.AnchorPoint            = Vector2.new(0, 1)
        Indicator.BackgroundColor3       = Library.AccentColor
        Indicator.BackgroundTransparency = 1
        Indicator.BorderSizePixel        = 0
        Indicator.Position               = UDim2.new(0, 0, 1, 0)
        Indicator.Size                   = UDim2.new(1, 0, 0, 2)
        Indicator.ZIndex                 = 206
        Indicator.Parent                 = TabBtn
        Library:AddToRegistry(Indicator, { BackgroundColor3 = "AccentColor" })

        -- Content frame (slides in from right)
        local Content = Instance.new("Frame")
        Content.BackgroundTransparency = 1
        Content.BorderSizePixel        = 0
        Content.ClipsDescendants       = false
        Content.Position               = UDim2.new(1, 0, 0, 0)  -- off-screen right
        Content.Size                   = UDim2.new(1, 0, 1, 0)
        Content.ZIndex                 = 203
        Content.Parent                 = ContentArea

        local tab = { Button = TabBtn, Indicator = Indicator, Content = Content }

        TabBtn.MouseButton1Click:Connect(function()
            if activeTab == tab then return end
            playSound(SFX.Tab, 0.2, 1.15)

            -- Deactivate previous
            if activeTab then
                tw(activeTab.Indicator, T_QUICK, { BackgroundTransparency = 1 }):Play()
                tw(activeTab.Button, T_QUICK, { TextColor3 = Color3.fromRGB(110, 110, 135) }):Play()
                tw(activeTab.Content, T_QUICK, { Position = UDim2.new(-1, 0, 0, 0) }):Play()
            end

            -- Activate new
            tw(Indicator, T_QUICK, { BackgroundTransparency = 0 }):Play()
            tw(TabBtn, T_QUICK, { TextColor3 = Library.FontColor }):Play()
            Content.Position = UDim2.new(1, 0, 0, 0)
            tw(Content, T_EASE, { Position = UDim2.new(0, 0, 0, 0) }):Play()
            activeTab = tab
        end)

        return tab
    end

    local KeyTab     = createTab("Key",     "🔑", 1)
    local AccountTab = createTab("Account", "👤", 2)
    local SupportTab = createTab("Support", "💬", 3)

    -- Start on Key tab (no slide)
    KeyTab.Indicator.BackgroundTransparency = 0
    KeyTab.Button.TextColor3               = Library.FontColor
    KeyTab.Content.Position                = UDim2.new(0, 0, 0, 0)
    activeTab = KeyTab

    -- ══════════════════════════ KEY VERIFICATION TAB ══════════════════════════
    local KC   = KeyTab.Content
    local BTNW = math.floor((DW - 2 - PAD * 3) / 2)
    local BTNH = 28

    -- Helper: styled button with press-scale and hover effects
    local function makeBtn(text, x, y, isAccent, parent)
        local Outer = Instance.new("Frame")
        Outer.BackgroundColor3 = Library.OutlineColor
        Outer.BorderSizePixel  = 0
        Outer.Position         = UDim2.fromOffset(x, y)
        Outer.Size             = UDim2.fromOffset(BTNW, BTNH)
        Outer.ZIndex           = 204
        Outer.Parent           = parent or KC
        Library:Create("UICorner", { CornerRadius = UDim.new(0, 4), Parent = Outer })
        Library:AddToRegistry(Outer, { BackgroundColor3 = "OutlineColor" })

        local Scale = Instance.new("UIScale")
        Scale.Parent = Outer

        local Btn = Instance.new("TextButton")
        Btn.AutoButtonColor  = false
        Btn.BackgroundColor3 = isAccent and Library.AccentColor or Library.MainColor
        Btn.BorderSizePixel  = 0
        Btn.Font             = Library.Font
        Btn.Position         = UDim2.new(0, 1, 0, 1)
        Btn.Size             = UDim2.new(1, -2, 1, -2)
        Btn.Text             = text
        Btn.TextColor3       = Library.FontColor
        Btn.TextSize         = 12
        Btn.ZIndex           = 205
        Btn.Parent           = Outer
        Library:Create("UICorner", { CornerRadius = UDim.new(0, 3), Parent = Btn })

        if isAccent then
            Library:AddToRegistry(Btn, { BackgroundColor3 = "AccentColor", TextColor3 = "FontColor" })
        else
            Library:AddToRegistry(Btn, { BackgroundColor3 = "MainColor",   TextColor3 = "FontColor" })
        end

        -- Press: scale down
        Btn.MouseButton1Down:Connect(function()
            playSound(SFX.Click, 0.25, 1)
            tw(Scale, T_QUICK, { Scale = 0.93 }):Play()
        end)
        Btn.MouseButton1Up:Connect(function()
            tw(Scale, T_SPRING, { Scale = 1 }):Play()
        end)

        -- Hover glow on non-accent buttons
        if not isAccent then
            Btn.MouseEnter:Connect(function()
                tw(Btn, T_QUICK, { BackgroundColor3 = Color3.fromRGB(38, 38, 52) }):Play()
            end)
            Btn.MouseLeave:Connect(function()
                tw(Btn, T_QUICK, { BackgroundColor3 = Library.MainColor }):Play()
            end)
        end

        return Btn
    end

    -- Subtitle
    local SubLbl = Instance.new("TextLabel")
    SubLbl.BackgroundTransparency = 1
    SubLbl.Font                   = Library.Font
    SubLbl.Position               = UDim2.new(0, PAD, 0, PAD)
    SubLbl.Size                   = UDim2.new(1, -PAD * 2, 0, 14)
    SubLbl.Text                   = options.Subtitle or "Enter your key to continue. Click 'Get Key' to obtain one."
    SubLbl.TextColor3             = Color3.fromRGB(140, 140, 165)
    SubLbl.TextSize               = 10
    SubLbl.TextWrapped            = true
    SubLbl.TextXAlignment         = Enum.TextXAlignment.Left
    SubLbl.ZIndex                 = 204
    SubLbl.Parent                 = KC

    -- Key input area
    local InputOuter = Instance.new("Frame")
    InputOuter.BackgroundColor3 = Library.OutlineColor
    InputOuter.BorderSizePixel  = 0
    InputOuter.Position         = UDim2.new(0, PAD, 0, 30)
    InputOuter.Size             = UDim2.new(1, -PAD * 2, 0, 34)
    InputOuter.ZIndex           = 204
    InputOuter.Parent           = KC
    Library:Create("UICorner", { CornerRadius = UDim.new(0, 5), Parent = InputOuter })
    Library:AddToRegistry(InputOuter, { BackgroundColor3 = "OutlineColor" })

    local InputInner = Instance.new("Frame")
    InputInner.BackgroundColor3 = Library.BackgroundColor
    InputInner.BorderSizePixel  = 0
    InputInner.Position         = UDim2.new(0, 1, 0, 1)
    InputInner.Size             = UDim2.new(1, -2, 1, -2)
    InputInner.ZIndex           = 205
    InputInner.Parent           = InputOuter
    Library:Create("UICorner", { CornerRadius = UDim.new(0, 4), Parent = InputInner })
    Library:AddToRegistry(InputInner, { BackgroundColor3 = "BackgroundColor" })

    local KeyInput = Instance.new("TextBox")
    KeyInput.BackgroundTransparency = 1
    KeyInput.BorderSizePixel        = 0
    KeyInput.ClearTextOnFocus       = false
    KeyInput.Font                   = Library.Font
    KeyInput.PlaceholderText        = "Paste your key here..."
    KeyInput.PlaceholderColor3      = Color3.fromRGB(65, 65, 88)
    KeyInput.Position               = UDim2.new(0, 10, 0, 0)
    KeyInput.Size                   = UDim2.new(1, -44, 1, 0)
    KeyInput.Text                   = ""
    KeyInput.TextColor3             = Library.FontColor
    KeyInput.TextSize               = 12
    KeyInput.TextXAlignment         = Enum.TextXAlignment.Left
    KeyInput.ZIndex                 = 206
    KeyInput.Parent                 = InputInner
    Library:AddToRegistry(KeyInput, { TextColor3 = "FontColor" })

    -- Eye / visibility toggle
    local EyeBtn = Instance.new("TextButton")
    EyeBtn.AutoButtonColor      = false
    EyeBtn.BackgroundTransparency = 1
    EyeBtn.AnchorPoint          = Vector2.new(1, 0.5)
    EyeBtn.Position             = UDim2.new(1, -4, 0.5, 0)
    EyeBtn.Size                 = UDim2.fromOffset(30, 30)
    EyeBtn.Text                 = "👁"
    EyeBtn.TextSize             = 14
    EyeBtn.ZIndex               = 207
    EyeBtn.Parent               = InputInner

    local keyMasked = false
    local realKey   = ""

    EyeBtn.MouseButton1Click:Connect(function()
        playSound(SFX.Click, 0.15, 1.4)
        keyMasked = not keyMasked
        if keyMasked then
            realKey        = KeyInput.Text
            KeyInput.Text  = string.rep("•", #realKey)
            EyeBtn.Text    = "🚫"
        else
            KeyInput.Text = realKey
            EyeBtn.Text   = "👁"
        end
    end)

    -- Input focus glow
    KeyInput.Focused:Connect(function()
        tw(InputOuter, T_QUICK, { BackgroundColor3 = Library.AccentColor }):Play()
    end)

    -- Status label
    local StatusLbl = Instance.new("TextLabel")
    StatusLbl.BackgroundTransparency = 1
    StatusLbl.Font                   = Library.Font
    StatusLbl.Position               = UDim2.new(0, PAD, 0, 70)
    StatusLbl.Size                   = UDim2.new(1, -PAD * 2, 0, 14)
    StatusLbl.Text                   = "Click 'Get Key' to open the verification link."
    StatusLbl.TextColor3             = Color3.fromRGB(130, 130, 155)
    StatusLbl.TextSize               = 10
    StatusLbl.TextXAlignment         = Enum.TextXAlignment.Left
    StatusLbl.ZIndex                 = 204
    StatusLbl.Parent                 = KC

    -- Buttons: row 1
    local GetKeyBtn  = makeBtn("🔗  Get Key",  PAD,          90, false)
    local PasteBtn   = makeBtn("📋  Paste",    PAD*2+BTNW,   90, false)
    -- Buttons: row 2
    local VerifyBtn  = makeBtn("✔  Verify Key", PAD,         124, true)
    local HwidBtn    = makeBtn("📎  Copy HWID", PAD*2+BTNW,  124, false)

    -- Loading dots
    local LoadRow = Instance.new("Frame")
    LoadRow.BackgroundTransparency = 1
    LoadRow.Position               = UDim2.new(0, PAD, 0, 158)
    LoadRow.Size                   = UDim2.new(1, -PAD*2, 0, 14)
    LoadRow.ZIndex                 = 204
    LoadRow.Visible                = false
    LoadRow.Parent                 = KC

    local dots = {}
    for i = 1, 5 do
        local d = Instance.new("Frame")
        d.BackgroundColor3 = Library.AccentColor
        d.BorderSizePixel  = 0
        d.AnchorPoint      = Vector2.new(0.5, 0.5)
        d.Position         = UDim2.new(0, (i-1)*18 + 7, 0.5, 0)
        d.Size             = UDim2.fromOffset(6, 6)
        d.ZIndex           = 205
        d.Parent           = LoadRow
        Library:Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = d })
        Library:AddToRegistry(d, { BackgroundColor3 = "AccentColor" })
        dots[i] = d
    end

    local loadConn
    local function startLoading()
        LoadRow.Visible = true
        local t = 0
        loadConn = RunService.Heartbeat:Connect(function(dt)
            t = t + dt
            for i, d in ipairs(dots) do
                local a = math.abs(math.sin(t * 3.5 + (i - 1) * 0.6))
                d.BackgroundTransparency = 1 - a * 0.9
                local sz = 4 + a * 4
                d.Size = UDim2.fromOffset(sz, sz)
            end
        end)
    end

    local function stopLoading()
        if loadConn then loadConn:Disconnect(); loadConn = nil end
        LoadRow.Visible = false
    end

    -- ═══════════════════════════ ACCOUNT INFO TAB ═════════════════════════════
    local AC = AccountTab.Content

    local AcctHeader = Instance.new("TextLabel")
    AcctHeader.BackgroundTransparency = 1
    AcctHeader.Font                   = Enum.Font.GothamBold
    AcctHeader.Position               = UDim2.new(0, PAD, 0, PAD)
    AcctHeader.Size                   = UDim2.new(1, -PAD*2, 0, 16)
    AcctHeader.Text                   = "👤  Account Information"
    AcctHeader.TextColor3             = Library.FontColor
    AcctHeader.TextSize               = 12
    AcctHeader.TextXAlignment         = Enum.TextXAlignment.Left
    AcctHeader.ZIndex                 = 204
    AcctHeader.Parent                 = AC
    Library:AddToRegistry(AcctHeader, { TextColor3 = "FontColor" })

    local function makeInfoRow(labelTxt, valueTxt, y)
        local Row = Instance.new("Frame")
        Row.BackgroundColor3 = Library.BackgroundColor
        Row.BorderSizePixel  = 0
        Row.Position         = UDim2.new(0, PAD, 0, y)
        Row.Size             = UDim2.new(1, -PAD*2, 0, 28)
        Row.ZIndex           = 204
        Row.Parent           = AC
        Library:Create("UICorner", { CornerRadius = UDim.new(0, 4), Parent = Row })
        Library:AddToRegistry(Row, { BackgroundColor3 = "BackgroundColor" })

        local LL = Instance.new("TextLabel")
        LL.BackgroundTransparency = 1
        LL.Font                   = Library.Font
        LL.Position               = UDim2.new(0, 10, 0, 0)
        LL.Size                   = UDim2.new(0.45, 0, 1, 0)
        LL.Text                   = labelTxt
        LL.TextColor3             = Color3.fromRGB(115, 115, 145)
        LL.TextSize               = 10
        LL.TextXAlignment         = Enum.TextXAlignment.Left
        LL.ZIndex                 = 205
        LL.Parent                 = Row

        local VL = Instance.new("TextLabel")
        VL.BackgroundTransparency = 1
        VL.Font                   = Library.Font
        VL.Position               = UDim2.new(0.45, 0, 0, 0)
        VL.Size                   = UDim2.new(0.55, -10, 1, 0)
        VL.Text                   = valueTxt
        VL.TextColor3             = Library.FontColor
        VL.TextSize               = 10
        VL.TextTruncate           = Enum.TextTruncate.AtEnd
        VL.TextXAlignment         = Enum.TextXAlignment.Right
        VL.ZIndex                 = 205
        VL.Parent                 = Row
        Library:AddToRegistry(VL, { TextColor3 = "FontColor" })

        return VL
    end

    local plr      = LocalPlayer
    local accAge   = plr.AccountAge
    local ageStr   = math.floor(accAge / 365) > 0
        and (math.floor(accAge / 365) .. "y " .. (accAge % 365) .. "d")
        or  (accAge .. " days")
    local gameName = pcall(function() return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name end)
        and game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name
        or  tostring(game.Name or "Unknown")

    makeInfoRow("Username",     "@" .. plr.Name,              34)
    makeInfoRow("Display Name", plr.DisplayName,              68)
    makeInfoRow("User ID",      tostring(plr.UserId),        102)
    makeInfoRow("Account Age",  ageStr,                      136)
    makeInfoRow("Current Game", gameName,                    170)

    -- Key status row
    local KeyStatusRow = makeInfoRow("Key Saved?",
        loadSavedKey() and "✔ Yes" or "✘ No", 204)

    -- ═══════════════════════════ SUPPORT TAB ══════════════════════════════════
    local SC = SupportTab.Content

    local function makeSupportCard(icon, title, sub, y, onClick)
        local Card = Instance.new("Frame")
        Card.BackgroundColor3 = Library.BackgroundColor
        Card.BorderSizePixel  = 0
        Card.Position         = UDim2.new(0, PAD, 0, y)
        Card.Size             = UDim2.new(1, -PAD*2, 0, 44)
        Card.ZIndex           = 204
        Card.Parent           = SC
        Library:Create("UICorner", { CornerRadius = UDim.new(0, 5), Parent = Card })
        Library:AddToRegistry(Card, { BackgroundColor3 = "BackgroundColor" })

        local CardScale = Instance.new("UIScale")
        CardScale.Parent = Card

        -- Left accent stripe
        local Stripe = Instance.new("Frame")
        Stripe.BackgroundColor3 = Library.AccentColor
        Stripe.BorderSizePixel  = 0
        Stripe.Position         = UDim2.new(0, 0, 0.15, 0)
        Stripe.Size             = UDim2.new(0, 3, 0.7, 0)
        Stripe.ZIndex           = 205
        Stripe.Parent           = Card
        Library:Create("UICorner", { CornerRadius = UDim.new(0, 2), Parent = Stripe })
        Library:AddToRegistry(Stripe, { BackgroundColor3 = "AccentColor" })

        local Ico = Instance.new("TextLabel")
        Ico.BackgroundTransparency = 1
        Ico.Font                   = Enum.Font.GothamBold
        Ico.Position               = UDim2.new(0, 12, 0.5, -10)
        Ico.Size                   = UDim2.fromOffset(20, 20)
        Ico.Text                   = icon
        Ico.TextSize               = 16
        Ico.ZIndex                 = 205
        Ico.Parent                 = Card

        local T1 = Instance.new("TextLabel")
        T1.BackgroundTransparency = 1
        T1.Font                   = Enum.Font.GothamBold
        T1.Position               = UDim2.new(0, 40, 0, 5)
        T1.Size                   = UDim2.new(1, -50, 0, 18)
        T1.Text                   = title
        T1.TextColor3             = Library.FontColor
        T1.TextSize               = 12
        T1.TextXAlignment         = Enum.TextXAlignment.Left
        T1.ZIndex                 = 205
        T1.Parent                 = Card
        Library:AddToRegistry(T1, { TextColor3 = "FontColor" })

        local T2 = Instance.new("TextLabel")
        T2.BackgroundTransparency = 1
        T2.Font                   = Library.Font
        T2.Position               = UDim2.new(0, 40, 0, 22)
        T2.Size                   = UDim2.new(1, -50, 0, 14)
        T2.Text                   = sub
        T2.TextColor3             = Color3.fromRGB(115, 115, 145)
        T2.TextSize               = 10
        T2.TextXAlignment         = Enum.TextXAlignment.Left
        T2.ZIndex                 = 205
        T2.Parent                 = Card

        local Hitbox = Instance.new("TextButton")
        Hitbox.AutoButtonColor      = false
        Hitbox.BackgroundTransparency = 1
        Hitbox.BorderSizePixel      = 0
        Hitbox.Size                 = UDim2.new(1, 0, 1, 0)
        Hitbox.Text                 = ""
        Hitbox.ZIndex               = 206
        Hitbox.Parent               = Card

        Hitbox.MouseButton1Down:Connect(function()
            playSound(SFX.Click, 0.3, 1)
            tw(CardScale, T_QUICK, { Scale = 0.96 }):Play()
        end)
        Hitbox.MouseButton1Up:Connect(function()
            tw(CardScale, T_SPRING, { Scale = 1 }):Play()
        end)
        Hitbox.MouseButton1Click:Connect(function()
            if onClick then onClick() end
        end)
        Hitbox.MouseEnter:Connect(function()
            tw(Card, T_QUICK, { BackgroundColor3 = Color3.fromRGB(30, 30, 44) }):Play()
        end)
        Hitbox.MouseLeave:Connect(function()
            tw(Card, T_QUICK, { BackgroundColor3 = Library.BackgroundColor }):Play()
        end)
    end

    local discordLink = options.DiscordLink or "discord.gg/romazhub"

    makeSupportCard("💬", "Discord Server", "Join our server for support & updates", PAD, function()
        local url    = discordLink:find("https?://") and discordLink or ("https://" .. discordLink)
        local opened = openLink(url)
        setStatusBar(opened and "Discord opened in browser!" or "Discord link copied to clipboard", Library.AccentColor)
    end)

    makeSupportCard("🔗", "Get Key", "Open the Junkie checkpoint in your browser", PAD + 52, function()
        local ok, link = pcall(Junkie.get_key_link)
        if ok and link and link ~= "" then
            local opened = openLink(link)
            setStatusBar(opened and "Key link opened!" or "Key link copied to clipboard", Library.AccentColor)
        else
            setStatusBar("Could not fetch key link — try again", Library.RiskColor)
        end
    end)

    makeSupportCard("🗑", "Clear Saved Key", "Force re-verification on next launch", PAD + 104, function()
        deleteSavedKey()
        getgenv().SCRIPT_KEY = nil
        KeyStatusRow.Text   = "✘ No"
        setStatusBar("Saved key cleared", Library.RiskColor)
    end)

    makeSupportCard("📋", "Copy Key Link", "Copy the raw key URL to clipboard", PAD + 156, function()
        local ok, link = pcall(Junkie.get_key_link)
        if ok and link and link ~= "" then
            copyToClipboard(link)
            setStatusBar("Key link copied!", Library.AccentColor)
        else
            setStatusBar("Could not get key link", Library.RiskColor)
        end
    end)

    local FooterLbl = Instance.new("TextLabel")
    FooterLbl.BackgroundTransparency = 1
    FooterLbl.Font                   = Library.Font
    FooterLbl.AnchorPoint            = Vector2.new(0.5, 1)
    FooterLbl.Position               = UDim2.new(0.5, 0, 1, -4)
    FooterLbl.Size                   = UDim2.new(1, -PAD*2, 0, 12)
    FooterLbl.Text                   = (options.Title or "Script") .. "  ·  " .. (options.Version or "v2.0") .. "  ·  Powered by LinoriaLib"
    FooterLbl.TextColor3             = Color3.fromRGB(70, 70, 95)
    FooterLbl.TextSize               = 9
    FooterLbl.TextXAlignment         = Enum.TextXAlignment.Center
    FooterLbl.ZIndex                 = 204
    FooterLbl.Parent                 = SC

    -- ═══════════════════════════ DRAGGABLE ════════════════════════════════════
    Library:MakeDraggable(DialogOuter, 36)

    -- ═══════════════════════════ ENTRANCE ANIMATION ═══════════════════════════
    local EntryScale = Instance.new("UIScale")
    EntryScale.Scale  = 0.82
    EntryScale.Parent = DialogOuter

    DialogOuter.BackgroundTransparency = 1

    task.spawn(function()
        playSound(SFX.Open, 0.4, 1)
        tw(EntryScale, T_SPRING, { Scale = 1 }):Play()
        tw(DialogOuter, T_EASE,  { BackgroundTransparency = 0 }):Play()
        tw(Backdrop,    TweenInfo.new(0.3, Enum.EasingStyle.Quad), { BackgroundTransparency = 0.42 }):Play()

        task.wait(0.2)
        -- Accent line sweeps in
        tw(AccentLine, TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
            { Size = UDim2.new(1, 0, 0, 2) }):Play()
    end)

    -- Pulsing accent line (breathing effect)
    task.spawn(function()
        while DialogOuter and DialogOuter.Parent do
            tw(AccentLine, T_PULSE, { BackgroundTransparency = 0.5 }):Play()
            task.wait(1.6)
            tw(AccentLine, T_PULSE, { BackgroundTransparency = 0 }):Play()
            task.wait(1.6)
        end
    end)

    -- Glow ring pulse
    task.spawn(function()
        while GlowFrame and GlowFrame.Parent do
            tw(GlowFrame, T_PULSE, { BackgroundTransparency = 0.85 }):Play()
            task.wait(1.6)
            tw(GlowFrame, T_PULSE, { BackgroundTransparency = 0.65 }):Play()
            task.wait(1.6)
        end
    end)

    -- ═══════════════════════════ CORE LOGIC ═══════════════════════════════════
    local ErrColor  = Library.RiskColor or Color3.fromRGB(255, 60, 60)
    local OkColor   = Library.AccentColor
    local InfoColor = Color3.fromRGB(130, 130, 155)

    local closed    = false
    local verifying = false

    local function setStatus(msg, col)
        StatusLbl.Text       = msg
        StatusLbl.TextColor3 = col or InfoColor
        setStatusBar(msg, col or Library.AccentColor)
    end

    local function shakeDialog()
        local orig = DialogOuter.Position
        task.spawn(function()
            for _, dx in ipairs({ 9, -9, 7, -7, 5, -5, 3, -3, 1, -1, 0 }) do
                DialogOuter.Position = UDim2.new(orig.X.Scale, dx, orig.Y.Scale, orig.Y.Offset)
                task.wait(0.035)
            end
            DialogOuter.Position = orig
        end)
    end

    local function closeDialog()
        if closed then return end
        closed = true
        stopLoading()
        playSound(SFX.Close, 0.3, 0.85)
        tw(EntryScale,   T_IN,   { Scale = 0.88 }):Play()
        tw(DialogOuter,  T_IN,   { BackgroundTransparency = 1 }):Play()
        tw(Backdrop, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
        task.delay(0.22, function()
            if KeyGui and KeyGui.Parent then KeyGui:Destroy() end
        end)
    end

    -- Forward-declare doVerify so FocusLost can reference it
    local doVerify

    -- Get Key
    GetKeyBtn.MouseButton1Click:Connect(function()
        local ok, link = pcall(Junkie.get_key_link)
        if ok and link and link ~= "" then
            local opened = openLink(link)
            setStatus(opened and "Browser opened! Complete steps and paste your key." or "Link copied to clipboard!", OkColor)
        else
            setStatus("Could not retrieve key link. Please try again.", ErrColor)
        end
    end)

    -- Paste from clipboard
    PasteBtn.MouseButton1Click:Connect(function()
        local txt = pasteClipboard()
        if txt and txt:match("%S") then
            local key = txt:match("^%s*(.-)%s*$")
            KeyInput.Text = key
            if keyMasked then realKey = key end
            setStatus("Pasted from clipboard!", OkColor)
        else
            setStatus("Clipboard is empty or not accessible.", ErrColor)
        end
    end)

    -- Copy HWID
    HwidBtn.MouseButton1Click:Connect(function()
        local hwid = ""
        pcall(function()
            hwid = tostring(game:GetService("RbxAnalyticsService"):GetClientId())
        end)
        if hwid == "" then
            hwid = "UID:" .. tostring(plr.UserId) .. "_PID:" .. tostring(game.PlaceId)
        end
        copyToClipboard(hwid)
        setStatus("HWID copied to clipboard!", OkColor)
    end)

    -- Input unfocus  (glow reset, enter-to-verify handled below)
    KeyInput.FocusLost:Connect(function(enter)
        tw(InputOuter, T_QUICK, { BackgroundColor3 = Library.OutlineColor }):Play()
        if enter and doVerify then doVerify() end
    end)

    -- Verify key
    doVerify = function()
        if verifying then return end

        -- Get raw key (unmask if needed)
        local key = (keyMasked and realKey or KeyInput.Text):match("^%s*(.-)%s*$")

        if key == "" then
            playSound(SFX.Error, 0.35, 1)
            setStatus("Please paste your key before verifying.", ErrColor)
            shakeDialog()
            return
        end

        verifying      = true
        VerifyBtn.Text = "Checking..."
        setStatus("Validating key — please wait...", InfoColor)
        startLoading()

        task.spawn(function()
            local ok, result = pcall(Junkie.check_key, key)
            stopLoading()

            if ok and result and result.valid then
                saveKey(key)
                getgenv().SCRIPT_KEY = key
                KeyStatusRow.Text    = "✔ Yes"

                playSound(SFX.Success, 0.55, 1)
                setStatus("Key accepted! Loading script...", OkColor)

                -- Green success flash
                tw(AccentLine,  T_QUICK, { BackgroundColor3 = Color3.fromRGB(50, 215, 100) }):Play()
                tw(DialogOuter, T_QUICK, { BackgroundColor3 = Color3.fromRGB(50, 215, 100) }):Play()
                task.wait(0.55)
                tw(DialogOuter, T_EASE,  { BackgroundColor3 = Library.AccentColor }):Play()
                tw(AccentLine,  T_EASE,  { BackgroundColor3 = Library.AccentColor }):Play()
                task.wait(0.25)
                closeDialog()
            else
                playSound(SFX.Error, 0.4, 1)
                shakeDialog()

                local msg = (type(result) == "table" and result.message) or "Invalid key"
                if msg == "KEY_EXPIRED" then
                    setStatus("Key expired — please get a new one.", ErrColor)
                    deleteSavedKey()
                elseif msg == "HWID_BANNED" then
                    setStatus("This device is hardware-banned.", ErrColor)
                    task.wait(1.5)
                    plr:Kick("Hardware banned.")
                    return
                elseif msg == "HWID_MISMATCH" then
                    setStatus("Key is linked to a different device.", ErrColor)
                elseif msg == "SERVICE_MISMATCH" then
                    setStatus("Key belongs to a different script.", ErrColor)
                else
                    setStatus("Invalid key. Please try again.", ErrColor)
                end

                VerifyBtn.Text = "✔  Verify Key"
                verifying      = false
            end
        end)
    end

    VerifyBtn.MouseButton1Click:Connect(doVerify)

    -- ── Block caller until dialog is dismissed ────────────────────────────────
    while not closed do task.wait(0.05) end
    return getgenv().SCRIPT_KEY
end

return KeySystem
