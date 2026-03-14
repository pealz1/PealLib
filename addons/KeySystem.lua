-- KeySystem.lua  -  LinoriaLib-Mobile addon
-- Blocks script execution until key is verified (or service is keyless).
--
-- Usage (call BEFORE creating any Library windows):
--   local Library   = loadstring(game:HttpGet("...Library.lua"))()
--   local KeySystem = loadstring(game:HttpGet("...addons/KeySystem.lua"))()
--   KeySystem:SetLibrary(Library)
--   KeySystem:Authenticate({
--       Title      = "My Script",
--       Subtitle   = "Enter your key to continue",
--       Service    = "TCO EXPLOIT",
--       Identifier = "1025025",
--       Provider   = "Romazhub",
--   })
--   -- execution continues only after verification passes

local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local KeySystem = {}
KeySystem.Library = nil

function KeySystem:SetLibrary(lib)
    self.Library = lib
end

-- ── File-system helpers ─────────────────────────────────────────────────
local KEY_FILE = "verified_key.txt"

local function fsOk()
    return type(writefile) == "function"
        and type(readfile)  == "function"
        and type(isfile)    == "function"
end

local function saveKey(key)
    if not fsOk() then return end
    pcall(writefile, KEY_FILE, key)
end

local function loadKey()
    if not fsOk() then return nil end
    local ok, v = pcall(readfile, KEY_FILE)
    return (ok and v and v ~= "") and v or nil
end

local function clearKey()
    if not fsOk() then return end
    pcall(delfile, KEY_FILE)
end

-- ── Authenticate ─────────────────────────────────────────────────────────

function KeySystem:Authenticate(options)
    options = options or {}

    local Library = self.Library
    assert(Library, "[KeySystem] call SetLibrary(lib) before Authenticate()")

    -- Load Junkie SDK and configure
    local Junkie = loadstring(game:HttpGet("https://jnkie.com/sdk/library.lua"))()
    Junkie.service    = options.Service    or "SCRIPT"
    Junkie.identifier = options.Identifier or ""
    Junkie.provider   = options.Provider   or "Romazhub"

    -- ── Sizing ───────────────────────────────────────────────────────────
    local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
    local vp       = workspace.CurrentCamera.ViewportSize
    local DW       = isMobile and math.min(320, math.floor(vp.X * 0.88)) or 380
    local DH       = 195
    local PAD      = 8

    -- ── Backdrop (blocks clicks on UI behind) ────────────────────────────
    local Backdrop = Library:Create("Frame", {
        BackgroundColor3       = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.45,
        BorderSizePixel        = 0,
        Size                   = UDim2.new(1, 0, 1, 0),
        ZIndex                 = 200,
        Parent                 = Library.ScreenGui,
    })

    -- ── Dialog outer shell (1 px OutlineColor border) ────────────────────
    local DialogOuter = Library:Create("Frame", {
        AnchorPoint      = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Library.OutlineColor,
        BorderSizePixel  = 0,
        Position         = UDim2.new(0.5, 0, 0.5, 0),
        Size             = UDim2.fromOffset(DW, DH),
        ZIndex           = 201,
        Parent           = Backdrop,
    })
    Library:Create("UICorner", { CornerRadius = UDim.new(0, 6); Parent = DialogOuter })
    Library:AddToRegistry(DialogOuter, { BackgroundColor3 = "OutlineColor" })

    -- Drop shadow
    local _Shadow = Library:Create("Frame", {
        BackgroundColor3       = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.55,
        BorderSizePixel        = 0,
        Position               = UDim2.new(0, -2, 0, 3),
        Size                   = UDim2.new(1, 4, 1, 4),
        ZIndex                 = 200,
        Parent                 = DialogOuter,
    })
    Library:Create("UICorner", { CornerRadius = UDim.new(0, 8); Parent = _Shadow })

    -- ── Dialog inner panel (MainColor fill) ──────────────────────────────
    local DialogInner = Library:Create("Frame", {
        BackgroundColor3 = Library.MainColor,
        BorderSizePixel  = 0,
        Position         = UDim2.new(0, 1, 0, 1),
        Size             = UDim2.new(1, -2, 1, -2),
        ZIndex           = 202,
        Parent           = DialogOuter,
    })
    Library:Create("UICorner", { CornerRadius = UDim.new(0, 5); Parent = DialogInner })
    Library:AddToRegistry(DialogInner, { BackgroundColor3 = "MainColor" })

    -- Accent top bar (matches Library popout style)
    local AccentTop = Library:Create("Frame", {
        BackgroundColor3 = Library.AccentColor,
        BorderSizePixel  = 0,
        Size             = UDim2.new(1, 0, 0, 2),
        ZIndex           = 203,
        Parent           = DialogInner,
    })
    Library:Create("UICorner", { CornerRadius = UDim.new(0, 5); Parent = AccentTop })
    Library:AddToRegistry(AccentTop, { BackgroundColor3 = "AccentColor" })

    -- Title label
    Library:CreateLabel({
        Position       = UDim2.new(0, PAD, 0, 4),
        Size           = UDim2.new(1, -40, 0, 18),
        Text           = options.Title or "Key Verification",
        TextSize       = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex         = 204,
        Parent         = DialogInner,
    })

    -- Title divider
    Library:Create("Frame", {
        BackgroundColor3       = Library.OutlineColor,
        BackgroundTransparency = 0.4,
        BorderSizePixel        = 0,
        Position               = UDim2.new(0, 6, 0, 24),
        Size                   = UDim2.new(1, -12, 0, 1),
        ZIndex                 = 203,
        Parent                 = DialogInner,
    })

    -- Subtitle
    Library:CreateLabel({
        Position       = UDim2.new(0, PAD, 0, 28),
        Size           = UDim2.new(1, -PAD * 2, 0, 16),
        Text           = options.Subtitle or "Enter your key to continue",
        TextSize       = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex         = 204,
        Parent         = DialogInner,
    })

    -- ── Key input (OutlineColor outer, BackgroundColor inner) ─────────────
    local InputOuter = Library:Create("Frame", {
        BackgroundColor3 = Library.OutlineColor,
        BorderSizePixel  = 0,
        Position         = UDim2.new(0, PAD, 0, 50),
        Size             = UDim2.new(1, -PAD * 2, 0, 28),
        ZIndex           = 203,
        Parent           = DialogInner,
    })
    Library:Create("UICorner", { CornerRadius = UDim.new(0, 4); Parent = InputOuter })
    Library:AddToRegistry(InputOuter, { BackgroundColor3 = "OutlineColor" })

    local InputInner = Library:Create("Frame", {
        BackgroundColor3 = Library.BackgroundColor,
        BorderSizePixel  = 0,
        Position         = UDim2.new(0, 1, 0, 1),
        Size             = UDim2.new(1, -2, 1, -2),
        ZIndex           = 204,
        Parent           = InputOuter,
    })
    Library:Create("UICorner", { CornerRadius = UDim.new(0, 3); Parent = InputInner })
    Library:AddToRegistry(InputInner, { BackgroundColor3 = "BackgroundColor" })

    local KeyInput = Library:Create("TextBox", {
        BackgroundTransparency = 1,
        BorderSizePixel        = 0,
        ClearTextOnFocus       = false,
        Font                   = Library.Font,
        PlaceholderText        = "Enter verification key...",
        PlaceholderColor3      = Color3.fromRGB(80, 80, 80),
        Position               = UDim2.new(0, 6, 0, 0),
        Size                   = UDim2.new(1, -12, 1, 0),
        Text                   = "",
        TextColor3             = Library.FontColor,
        TextSize               = 12,
        TextXAlignment         = Enum.TextXAlignment.Left,
        ZIndex                 = 205,
        Parent                 = InputInner,
    })
    Library:AddToRegistry(KeyInput, { TextColor3 = "FontColor" })

    -- ── Status label ─────────────────────────────────────────────────────
    local StatusLabel = Library:CreateLabel({
        Position       = UDim2.new(0, PAD, 0, 86),
        Size           = UDim2.new(1, -PAD * 2, 0, 14),
        Text           = "",
        TextSize       = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex         = 204,
        Parent         = DialogInner,
    })

    -- ── Buttons ───────────────────────────────────────────────────────────
    local BTNW  = math.floor((DW - 18 - PAD * 3) / 2)
    local BTNH  = 26
    local BTN_Y = 106

    local function makeButton(label, xOff)
        local Outer = Library:Create("Frame", {
            BackgroundColor3 = Library.OutlineColor,
            BorderSizePixel  = 0,
            Position         = UDim2.fromOffset(xOff, BTN_Y),
            Size             = UDim2.fromOffset(BTNW, BTNH),
            ZIndex           = 203,
            Parent           = DialogInner,
        })
        Library:Create("UICorner", { CornerRadius = UDim.new(0, 4); Parent = Outer })
        Library:AddToRegistry(Outer, { BackgroundColor3 = "OutlineColor" })

        local Btn = Library:Create("TextButton", {
            AutoButtonColor  = false,
            BackgroundColor3 = Library.MainColor,
            BorderSizePixel  = 0,
            Font             = Library.Font,
            Position         = UDim2.new(0, 1, 0, 1),
            Size             = UDim2.new(1, -2, 1, -2),
            Text             = label,
            TextColor3       = Library.FontColor,
            TextSize         = 12,
            ZIndex           = 204,
            Parent           = Outer,
        })
        Library:Create("UICorner", { CornerRadius = UDim.new(0, 3); Parent = Btn })
        Library:AddToRegistry(Btn, { BackgroundColor3 = "MainColor"; TextColor3 = "FontColor" })
        Library:OnHighlight(Btn, Btn,
            { BackgroundColor3 = "AccentColor" },
            { BackgroundColor3 = "MainColor" }
        )
        return Btn
    end

    local GetLinkBtn = makeButton("Get Link",  PAD)
    local VerifyBtn  = makeButton("Verify Key", PAD + BTNW + PAD)

    -- Accent bottom bar
    Library:Create("Frame", {
        AnchorPoint            = Vector2.new(0, 1),
        BackgroundColor3       = Library.AccentColor,
        BackgroundTransparency = 0.75,
        BorderSizePixel        = 0,
        Position               = UDim2.new(0, 0, 1, 0),
        Size                   = UDim2.new(1, 0, 0, 1),
        ZIndex                 = 203,
        Parent                 = DialogInner,
    })

    -- Draggable by title-bar area (top 28 px)
    Library:MakeDraggable(DialogOuter, 28)

    -- Entrance scale tween
    local Scale  = Instance.new("UIScale")
    Scale.Scale  = 0.9
    Scale.Parent = DialogOuter
    TweenService:Create(Scale,
        TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Scale = 1 }
    ):Play()

    -- ── State ─────────────────────────────────────────────────────────────
    local RiskColor = Library.RiskColor or Color3.fromRGB(255, 50, 50)
    local GoodColor = Library.AccentColor

    local closed    = false
    local verifying = false

    local function setStatus(msg, color)
        StatusLabel.Text       = msg
        StatusLabel.TextColor3 = color or Library.FontColor
    end

    local function closeDialog()
        if closed then return end
        closed = true
        TweenService:Create(Scale,
            TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            { Scale = 0.9 }
        ):Play()
        task.delay(0.15, function()
            if Backdrop and Backdrop.Parent then
                Backdrop:Destroy()
            end
        end)
    end

    local function tryKey(key)
        if not key or key == "" then return false, nil end
        local result = Junkie.check_key(key)
        return (result and result.valid), result
    end

    -- ── Button logic ──────────────────────────────────────────────────────
    GetLinkBtn.MouseButton1Click:Connect(function()
        local link = Junkie.get_key_link and Junkie.get_key_link()
        if link then
            if setclipboard then
                setclipboard(link)
                setStatus("Link copied to clipboard!", GoodColor)
            else
                setStatus(link, GoodColor)
            end
        else
            setStatus("Could not retrieve link.", RiskColor)
        end
    end)

    local function doVerify()
        if verifying then return end
        local key = KeyInput.Text:gsub("%s+", "")
        if key == "" then
            setStatus("Please enter a key.", RiskColor)
            return
        end

        verifying      = true
        VerifyBtn.Text = "Verifying..."
        setStatus("Checking key...", Library.FontColor)

        task.spawn(function()
            local ok, result = tryKey(key)
            if ok then
                saveKey(key)
                getgenv().SCRIPT_KEY = key
                setStatus("Key verified! Loading...", GoodColor)
                task.wait(0.6)
                closeDialog()
            else
                setStatus("Invalid key. Please try again.", RiskColor)
                VerifyBtn.Text = "Verify Key"
                verifying      = false
            end
        end)
    end

    VerifyBtn.MouseButton1Click:Connect(doVerify)
    KeyInput.FocusLost:Connect(function(enter) if enter then doVerify() end end)

    -- ── Auto-check on open ────────────────────────────────────────────────
    task.spawn(function()
        setStatus("Checking credentials...", Library.FontColor)

        -- 1. Check if service is keyless (empty key returns KEYLESS)
        local keylessResult = Junkie.check_key("")
        if keylessResult and keylessResult.valid and keylessResult.message == "KEYLESS" then
            getgenv().SCRIPT_KEY = "KEYLESS"
            setStatus("Keyless mode active!", GoodColor)
            task.wait(0.4)
            closeDialog()
            return
        end

        -- 2. Try saved file key or globally cached key
        local cached = loadKey() or getgenv().SCRIPT_KEY
        if cached then
            local ok, result = tryKey(cached)
            if ok then
                if result.message == "KEYLESS" then
                    getgenv().SCRIPT_KEY = "KEYLESS"
                    setStatus("Keyless mode active!", GoodColor)
                else
                    saveKey(cached)
                    getgenv().SCRIPT_KEY = cached
                    setStatus("Saved key verified!", GoodColor)
                end
                task.wait(0.5)
                closeDialog()
                return
            else
                -- Saved key is no longer valid; discard it
                clearKey()
            end
        end

        -- 3. Prompt the user
        setStatus("Enter your key to continue.", Library.FontColor)
    end)

    -- Block until the dialog is dismissed
    while not closed do
        task.wait(0.05)
    end

    return getgenv().SCRIPT_KEY
end

return KeySystem
