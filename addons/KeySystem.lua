-- KeySystem.lua  -  PealLib addon
-- Flow:
--   1. Check if a saved key exists -> validate it -> if valid, skip GUI entirely
--   2. If no valid saved key -> show GUI
--   3. GUI: "Get Key" opens the Junkie checkpoint link in browser
--   4. User completes steps, gets a key, pastes it into the input box
--   5. "Continue" validates the key -> if valid, saves it and lets user in

local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local KeySystem = {}
KeySystem.Library = nil

function KeySystem:SetLibrary(lib)
    self.Library = lib
end

-- File helpers
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

local function openLink(url)
    if openurl then
        pcall(openurl, url)
        return true
    end
    if setclipboard then
        setclipboard(url)
    end
    return false
end

function KeySystem:Authenticate(options)
    options = options or {}

    local Library = self.Library
    assert(Library, "[KeySystem] call SetLibrary(lib) before Authenticate()")

    local Junkie = loadstring(game:HttpGet("https://jnkie.com/sdk/library.lua"))()
    Junkie.script_key = options.ScriptKey or options.Identifier or ""
    Junkie.service    = options.Service    or "SCRIPT"
    Junkie.identifier = options.Identifier or ""
    Junkie.provider   = options.Provider   or "Romazhub"

    local MAX_RETRIES = 3
    local RETRY_DELAY = 1

    local function tryCheckKey(key, retries)
        retries = retries or MAX_RETRIES
        local ok, result
        for attempt = 1, retries do
            ok, result = pcall(Junkie.check_key, key)
            if ok then break end
            if attempt < retries then
                task.wait(RETRY_DELAY)
            end
        end
        return ok, result
    end

    local function isAlreadyRedeemedHere(result)
        if not result then return false end
        local msg = result.message or result.error or ""
        return msg == "KEY_ALREADY_USED"
            or msg == "KEY_ALREADY_REDEEMED"
            or msg:find("already") ~= nil
    end

    local function isDefinitivelyInvalid(result)
        if not result then return false end
        local msg = result.message or result.error or ""
        return msg == "KEY_EXPIRED"
            or msg == "INVALID_KEY"
            or msg == "KEY_NOT_FOUND"
            or msg == "HWID_MISMATCH"
            or msg == "SERVICE_MISMATCH"
            or msg == "HWID_BANNED"
    end

    local cached = loadSavedKey() or getgenv().SCRIPT_KEY
    if cached then
        local ok, result = tryCheckKey(cached)

        if ok and result and result.valid then
            getgenv().SCRIPT_KEY = cached
            return cached

        elseif ok and isAlreadyRedeemedHere(result) then
            getgenv().SCRIPT_KEY = cached
            saveKey(cached)
            return cached

        elseif not ok then
            getgenv().SCRIPT_KEY = nil

        elseif ok and isDefinitivelyInvalid(result) then
            deleteSavedKey()
            getgenv().SCRIPT_KEY = nil

        else
            getgenv().SCRIPT_KEY = nil
        end
    end

    local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
    local vp       = workspace.CurrentCamera.ViewportSize
    local DW       = isMobile and math.min(320, math.floor(vp.X * 0.88)) or 390
    local DH       = 210
    local PAD      = 10

    local Backdrop = Library:Create("Frame", {
        BackgroundColor3       = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.5,
        BorderSizePixel        = 0,
        Size                   = UDim2.new(1, 0, 1, 0),
        ZIndex                 = 200,
        Parent                 = Library.ScreenGui,
    })

    local DialogOuter = Library:Create("Frame", {
        AnchorPoint      = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Library.OutlineColor,
        BorderSizePixel  = 0,
        Position         = UDim2.new(0.5, 0, 0.5, 0),
        Size             = UDim2.fromOffset(DW, DH),
        ZIndex           = 201,
        Parent           = Backdrop,
    })
    Library:Create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = DialogOuter })
    Library:AddToRegistry(DialogOuter, { BackgroundColor3 = "OutlineColor" })

    local Dialog = Library:Create("Frame", {
        BackgroundColor3 = Library.MainColor,
        BorderSizePixel  = 0,
        Position         = UDim2.new(0, 1, 0, 1),
        Size             = UDim2.new(1, -2, 1, -2),
        ZIndex           = 202,
        Parent           = DialogOuter,
    })
    Library:Create("UICorner", { CornerRadius = UDim.new(0, 5), Parent = Dialog })
    Library:AddToRegistry(Dialog, { BackgroundColor3 = "MainColor" })

    local AccentBar = Library:Create("Frame", {
        BackgroundColor3 = Library.AccentColor,
        BorderSizePixel  = 0,
        Size             = UDim2.new(1, 0, 0, 2),
        ZIndex           = 203,
        Parent           = Dialog,
    })
    Library:Create("UICorner", { CornerRadius = UDim.new(0, 5), Parent = AccentBar })
    Library:AddToRegistry(AccentBar, { BackgroundColor3 = "AccentColor" })

    Library:CreateLabel({
        Position       = UDim2.new(0, PAD, 0, 6),
        Size           = UDim2.new(1, -PAD * 2, 0, 18),
        Text           = options.Title or "Key Verification",
        TextSize       = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex         = 204,
        Parent         = Dialog,
    })

    Library:Create("Frame", {
        BackgroundColor3       = Library.OutlineColor,
        BackgroundTransparency = 0.4,
        BorderSizePixel        = 0,
        Position               = UDim2.new(0, 6, 0, 26),
        Size                   = UDim2.new(1, -12, 0, 1),
        ZIndex                 = 203,
        Parent                 = Dialog,
    })

    Library:CreateLabel({
        Position       = UDim2.new(0, PAD, 0, 31),
        Size           = UDim2.new(1, -PAD * 2, 0, 14),
        Text           = options.Subtitle or "Get a key then paste it below",
        TextSize       = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex         = 204,
        Parent         = Dialog,
    })

    local InputOuter = Library:Create("Frame", {
        BackgroundColor3 = Library.OutlineColor,
        BorderSizePixel  = 0,
        Position         = UDim2.new(0, PAD, 0, 52),
        Size             = UDim2.new(1, -PAD * 2, 0, 30),
        ZIndex           = 203,
        Parent           = Dialog,
    })
    Library:Create("UICorner", { CornerRadius = UDim.new(0, 4), Parent = InputOuter })
    Library:AddToRegistry(InputOuter, { BackgroundColor3 = "OutlineColor" })

    local InputInner = Library:Create("Frame", {
        BackgroundColor3 = Library.BackgroundColor,
        BorderSizePixel  = 0,
        Position         = UDim2.new(0, 1, 0, 1),
        Size             = UDim2.new(1, -2, 1, -2),
        ZIndex           = 204,
        Parent           = InputOuter,
    })
    Library:Create("UICorner", { CornerRadius = UDim.new(0, 3), Parent = InputInner })
    Library:AddToRegistry(InputInner, { BackgroundColor3 = "BackgroundColor" })

    local KeyInput = Library:Create("TextBox", {
        BackgroundTransparency = 1,
        BorderSizePixel        = 0,
        ClearTextOnFocus       = false,
        Font                   = Library.Font,
        PlaceholderText        = "Paste your key here...",
        PlaceholderColor3      = Color3.fromRGB(80, 80, 80),
        Position               = UDim2.new(0, 8, 0, 0),
        Size                   = UDim2.new(1, -16, 1, 0),
        Text                   = "",
        TextColor3             = Library.FontColor,
        TextSize               = 12,
        TextXAlignment         = Enum.TextXAlignment.Left,
        ZIndex                 = 205,
        Parent                 = InputInner,
    })
    Library:AddToRegistry(KeyInput, { TextColor3 = "FontColor" })

    if cached and cached ~= "" then
        KeyInput.Text = cached
    end

    local StatusLabel = Library:CreateLabel({
        Position       = UDim2.new(0, PAD, 0, 90),
        Size           = UDim2.new(1, -PAD * 2, 0, 14),
        Text           = "Click Get Key to open the key link in your browser.",
        TextSize       = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex         = 204,
        Parent         = Dialog,
    })

    local BTNW  = math.floor((DW - 2 - PAD * 3) / 2)
    local BTNH  = 28
    local BTN_Y = 110

    local function makeButton(label, xOff, accent)
        local Outer = Library:Create("Frame", {
            BackgroundColor3 = Library.OutlineColor,
            BorderSizePixel  = 0,
            Position         = UDim2.fromOffset(xOff, BTN_Y),
            Size             = UDim2.fromOffset(BTNW, BTNH),
            ZIndex           = 203,
            Parent           = Dialog,
        })
        Library:Create("UICorner", { CornerRadius = UDim.new(0, 4), Parent = Outer })
        Library:AddToRegistry(Outer, { BackgroundColor3 = "OutlineColor" })

        local Btn = Library:Create("TextButton", {
            AutoButtonColor  = false,
            BackgroundColor3 = accent and Library.AccentColor or Library.MainColor,
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
        Library:Create("UICorner", { CornerRadius = UDim.new(0, 3), Parent = Btn })

        if accent then
            Library:AddToRegistry(Btn, { BackgroundColor3 = "AccentColor", TextColor3 = "FontColor" })
            Library:OnHighlight(Btn, Btn,
                { BackgroundColor3 = Library.AccentColor },
                { BackgroundColor3 = Library.AccentColor }
            )
        else
            Library:AddToRegistry(Btn, { BackgroundColor3 = "MainColor", TextColor3 = "FontColor" })
            Library:OnHighlight(Btn, Btn,
                { BackgroundColor3 = "AccentColor" },
                { BackgroundColor3 = "MainColor" }
            )
        end

        return Btn
    end

    local GetKeyBtn   = makeButton("Get Key",  PAD,              false)
    local ContinueBtn = makeButton("Continue", PAD + BTNW + PAD, true)

    Library:Create("Frame", {
        AnchorPoint            = Vector2.new(0, 1),
        BackgroundColor3       = Library.AccentColor,
        BackgroundTransparency = 0.75,
        BorderSizePixel        = 0,
        Position               = UDim2.new(0, 0, 1, 0),
        Size                   = UDim2.new(1, 0, 0, 1),
        ZIndex                 = 203,
        Parent                 = Dialog,
    })

    Library:MakeDraggable(DialogOuter, 28)

    local Scale = Instance.new("UIScale")
    Scale.Scale  = 0.9
    Scale.Parent = DialogOuter
    TweenService:Create(Scale,
        TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Scale = 1 }
    ):Play()

    local ErrColor  = Library.RiskColor or Color3.fromRGB(255, 60, 60)
    local OkColor   = Library.AccentColor
    local InfoColor = Library.FontColor

    local closed    = false
    local verifying = false

    local function setStatus(msg, color)
        StatusLabel.Text       = msg
        StatusLabel.TextColor3 = color or InfoColor
    end

    local function closeDialog()
        if closed then return end
        closed = true
        TweenService:Create(Scale,
            TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            { Scale = 0.9 }
        ):Play()
        task.delay(0.15, function()
            if Backdrop and Backdrop.Parent then Backdrop:Destroy() end
        end)
    end

    GetKeyBtn.MouseButton1Click:Connect(function()
        local ok, link = pcall(Junkie.get_key_link)
        if ok and link and link ~= "" then
            local opened = openLink(link)
            if opened then
                setStatus("Browser opened! Complete the steps then paste your key.", OkColor)
            else
                setStatus("Link copied to clipboard! Paste in your browser.", OkColor)
            end
        else
            setStatus("Could not get key link. Try again in a moment.", ErrColor)
        end
    end)

    local function doVerify()
        if verifying then return end
        local key = KeyInput.Text:match("^%s*(.-)\%s*$")
        if key == "" then
            setStatus("Please paste your key first.", ErrColor)
            return
        end

        verifying        = true
        ContinueBtn.Text = "Checking..."
        setStatus("Validating key...", InfoColor)

        task.spawn(function()
            local ok, result = tryCheckKey(key)

            if ok and result and result.valid then
                saveKey(key)
                getgenv().SCRIPT_KEY = key
                setStatus("Key accepted! Loading script...", OkColor)
                task.wait(0.7)
                closeDialog()
                return
            end

            if ok and isAlreadyRedeemedHere(result) then
                saveKey(key)
                getgenv().SCRIPT_KEY = key
                setStatus("Key recognised (already linked). Loading...", OkColor)
                task.wait(0.7)
                closeDialog()
                return
            end

            if not ok then
                setStatus("Network error -- check your connection and retry.", ErrColor)
                ContinueBtn.Text = "Continue"
                verifying        = false
                return
            end

            local msg = (result and (result.message or result.error)) or "Invalid key"

            if msg == "KEY_EXPIRED" then
                setStatus("Key expired -- get a new one.", ErrColor)
                deleteSavedKey()
            elseif msg == "HWID_BANNED" then
                setStatus("You are hardware banned.", ErrColor)
                task.wait(1)
                game.Players.LocalPlayer:Kick("Hardware banned.")
                return
            elseif msg == "HWID_MISMATCH" then
                setStatus("Key is linked to a different device.", ErrColor)
            elseif msg == "SERVICE_MISMATCH" then
                setStatus("Key is for a different script.", ErrColor)
            elseif msg == "INVALID_KEY" or msg == "KEY_NOT_FOUND" then
                setStatus("Invalid key. Double-check and try again.", ErrColor)
                deleteSavedKey()
            else
                setStatus("Validation failed: " .. tostring(msg), ErrColor)
            end

            ContinueBtn.Text = "Continue"
            verifying        = false
        end)
    end

    ContinueBtn.MouseButton1Click:Connect(doVerify)
    KeyInput.FocusLost:Connect(function(enter) if enter then doVerify() end end)

    while not closed do
        task.wait(0.05)
    end

    return getgenv().SCRIPT_KEY
end

return KeySystem
