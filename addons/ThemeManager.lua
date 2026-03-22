local HttpService = game:GetService('HttpService')

-- ─────────────────────────────────────────────
--  ThemeManager
--  Handles built-in and custom themes for
--  LinoriaLib-based scripts.
-- ─────────────────────────────────────────────

local ThemeManager = {}

ThemeManager.Folder    = 'LinoriaLibSettings'
ThemeManager.Library   = nil
ThemeManager.DefaultTheme = 'Default'

-- ── Built-in themes ───────────────────────────
-- Format: [name] = { sortIndex, colorTable }

ThemeManager.BuiltInThemes = {
    ['Default']     = { 1, HttpService:JSONDecode('{"FontColor":"ffffff","MainColor":"1c1c1c","AccentColor":"0055ff","BackgroundColor":"141414","OutlineColor":"323232"}') },
    ['BBot']        = { 2, HttpService:JSONDecode('{"FontColor":"ffffff","MainColor":"1e1e1e","AccentColor":"7e48a3","BackgroundColor":"232323","OutlineColor":"141414"}') },
    ['Fatality']    = { 3, HttpService:JSONDecode('{"FontColor":"ffffff","MainColor":"1e1842","AccentColor":"c50754","BackgroundColor":"191335","OutlineColor":"3c355d"}') },
    ['Jester']      = { 4, HttpService:JSONDecode('{"FontColor":"ffffff","MainColor":"242424","AccentColor":"db4467","BackgroundColor":"1c1c1c","OutlineColor":"373737"}') },
    ['Mint']        = { 5, HttpService:JSONDecode('{"FontColor":"ffffff","MainColor":"242424","AccentColor":"3db488","BackgroundColor":"1c1c1c","OutlineColor":"373737"}') },
    ['Tokyo Night'] = { 6, HttpService:JSONDecode('{"FontColor":"ffffff","MainColor":"191925","AccentColor":"6759b3","BackgroundColor":"16161f","OutlineColor":"323232"}') },
    ['Ubuntu']      = { 7, HttpService:JSONDecode('{"FontColor":"ffffff","MainColor":"3e3e3e","AccentColor":"e2581e","BackgroundColor":"323232","OutlineColor":"191919"}') },
    ['Quartz']      = { 8, HttpService:JSONDecode('{"FontColor":"ffffff","MainColor":"232330","AccentColor":"426e87","BackgroundColor":"1d1b26","OutlineColor":"27232f"}') },
}

-- The five color fields every theme must supply.
local COLOR_FIELDS = { 'FontColor', 'MainColor', 'AccentColor', 'BackgroundColor', 'OutlineColor' }

-- ── Helpers ───────────────────────────────────

local function themesPath(self)
    return self.Folder .. '/themes'
end

local function defaultFilePath(self)
    return themesPath(self) .. '/default.txt'
end

local function customThemeFilePath(self, name)
    -- Names are stored WITHOUT the .json extension internally.
    return themesPath(self) .. '/' .. name .. '.json'
end

--- Safely notify via the library if it is set.
local function notify(self, msg)
    if self.Library then
        self.Library:Notify(msg)
    end
end

-- ── Public API ────────────────────────────────

function ThemeManager:SetLibrary(lib)
    self.Library = lib
end

function ThemeManager:SetFolder(folder)
    self.Folder = folder
    self:BuildFolderTree()
end

--- Apply a theme by name (built-in or custom).
function ThemeManager:ApplyTheme(name)
    if not name or name == '' then return end

    local customData = self:GetCustomTheme(name)
    local builtIn    = self.BuiltInThemes[name]

    if not customData and not builtIn then return end

    -- Custom themes are plain dicts; built-ins are { index, dict }.
    local scheme = customData or builtIn[2]

    for field, hex in next, scheme do
        local color = Color3.fromHex(hex)
        self.Library[field] = color
        if Options[field] then
            Options[field]:SetValueRGB(color)
        end
    end

    self:ThemeUpdate()
end

--- Push current color option values into the library and refresh the UI.
function ThemeManager:ThemeUpdate()
    for _, field in next, COLOR_FIELDS do
        if Options and Options[field] then
            self.Library[field] = Options[field].Value
        end
    end

    self.Library.AccentColorDark = self.Library:GetDarkerColor(self.Library.AccentColor)
    self.Library:UpdateColorsUsingRegistry()
end

--- Load and apply the last saved default theme on startup.
function ThemeManager:LoadDefault()
    local path    = defaultFilePath(self)
    local content = isfile(path) and readfile(path) or nil
    local theme   = 'Default'
    local isBuiltIn = true

    if content and content ~= '' then
        content = content:match('^%s*(.-)%s*$') -- trim whitespace
        if self.BuiltInThemes[content] then
            theme = content
        elseif self:GetCustomTheme(content) then
            theme     = content
            isBuiltIn = false
        end
    elseif self.BuiltInThemes[self.DefaultTheme] then
        theme = self.DefaultTheme
    end

    if isBuiltIn then
        -- SetValue triggers OnChanged which calls ApplyTheme.
        Options.ThemeManager_ThemeList:SetValue(theme)
    else
        self:ApplyTheme(theme)
    end
end

--- Persist the current default theme pointer.
function ThemeManager:SaveDefault(name)
    local ok, err = pcall(writefile, defaultFilePath(self), name)
    if not ok then
        notify(self, 'Failed to save default theme: ' .. tostring(err))
    end
end

--- Return the decoded color table for a custom theme, or nil if not found / corrupt.
function ThemeManager:GetCustomTheme(name)
    local path = customThemeFilePath(self, name)
    if not isfile(path) then return nil end

    local ok, decoded = pcall(function()
        return HttpService:JSONDecode(readfile(path))
    end)

    return ok and decoded or nil
end

--- Save the current color pickers as a named custom theme.
function ThemeManager:SaveCustomTheme(name)
    name = name:match('^%s*(.-)%s*$') -- trim whitespace

    if name == '' then
        return notify(self, 'Theme name cannot be empty')
    end
    if name:find('[/\\%.%:]') then
        return notify(self, 'Theme name contains invalid characters')
    end

    local theme = {}
    for _, field in next, COLOR_FIELDS do
        theme[field] = Options[field].Value:ToHex()
    end

    local ok, encoded = pcall(HttpService.JSONEncode, HttpService, theme)
    if not ok then
        return notify(self, 'Failed to encode theme data')
    end

    local writeOk, writeErr = pcall(writefile, customThemeFilePath(self, name), encoded)
    if not writeOk then
        return notify(self, 'Failed to write theme file: ' .. tostring(writeErr))
    end

    notify(self, string.format('Saved custom theme "%s"', name))
end

--- Delete a named custom theme file from disk.
function ThemeManager:DeleteCustomTheme(name)
    if not name or name == '' then
        return notify(self, 'No theme selected to delete')
    end

    local path = customThemeFilePath(self, name)
    if not isfile(path) then
        return notify(self, string.format('Theme "%s" does not exist', name))
    end

    local ok, err = pcall(delfile, path)
    if not ok then
        return notify(self, 'Failed to delete theme: ' .. tostring(err))
    end

    notify(self, string.format('Deleted custom theme "%s"', name))
end

--- Returns a sorted list of custom theme names (without .json extension).
function ThemeManager:ReloadCustomThemes()
    local files = listfiles(themesPath(self))
    local out   = {}

    for _, file in next, files do
        -- Strip extension and path prefix, return just the bare name.
        local name = file:match('[/\\]?([^/\\]+)%.json$')
        if name then
            table.insert(out, name)
        end
    end

    table.sort(out)
    return out
end

--- Build the required folder structure on disk.
function ThemeManager:BuildFolderTree()
    -- Split the folder path so nested dirs (e.g. "hub/game") are made safely.
    local parts = self.Folder:split('/')
    local paths = {}

    for i = 1, #parts do
        paths[#paths + 1] = table.concat(parts, '/', 1, i)
    end

    table.insert(paths, themesPath(self))
    table.insert(paths, self.Folder .. '/settings')

    for _, path in next, paths do
        if not isfolder(path) then
            makefolder(path)
        end
    end
end

--- Construct the sorted built-in themes array for the dropdown.
local function buildThemesArray(self)
    local arr = {}
    for name in next, self.BuiltInThemes do
        table.insert(arr, name)
    end
    table.sort(arr, function(a, b)
        return self.BuiltInThemes[a][1] < self.BuiltInThemes[b][1]
    end)
    return arr
end

--- Internal: wire up all theme UI controls inside a groupbox.
function ThemeManager:CreateThemeManager(groupbox)

    -- ── Color pickers ─────────────────────────
    groupbox:AddLabel('Background color'):AddColorPicker('BackgroundColor', { Default = self.Library.BackgroundColor })
    groupbox:AddLabel('Main color')      :AddColorPicker('MainColor',       { Default = self.Library.MainColor })
    groupbox:AddLabel('Accent color')    :AddColorPicker('AccentColor',     { Default = self.Library.AccentColor })
    groupbox:AddLabel('Outline color')   :AddColorPicker('OutlineColor',    { Default = self.Library.OutlineColor })
    groupbox:AddLabel('Font color')      :AddColorPicker('FontColor',       { Default = self.Library.FontColor })

    -- ── Built-in theme picker ─────────────────
    groupbox:AddDivider()
    groupbox:AddDropdown('ThemeManager_ThemeList', {
        Text    = 'Theme list',
        Values  = buildThemesArray(self),
        Default = 1,
    })
    groupbox:AddButton('Set as default', function()
        local name = Options.ThemeManager_ThemeList.Value
        self:SaveDefault(name)
        notify(self, string.format('Set default theme to "%s"', name))
    end)

    Options.ThemeManager_ThemeList:OnChanged(function()
        self:ApplyTheme(Options.ThemeManager_ThemeList.Value)
    end)

    -- ── Custom theme manager ──────────────────
    groupbox:AddDivider()
    groupbox:AddInput('ThemeManager_CustomThemeName', { Text = 'Custom theme name' })
    groupbox:AddDropdown('ThemeManager_CustomThemeList', {
        Text      = 'Custom themes',
        Values    = self:ReloadCustomThemes(),
        AllowNull = true,
        Default   = 1,
    })
    groupbox:AddDivider()

    groupbox:AddButton('Save theme', function()
        self:SaveCustomTheme(Options.ThemeManager_CustomThemeName.Value)
        Options.ThemeManager_CustomThemeList:SetValues(self:ReloadCustomThemes())
        Options.ThemeManager_CustomThemeList:SetValue(nil)
    end)
    :AddButton('Load theme', function()
        local name = Options.ThemeManager_CustomThemeList.Value
        if not name or name == '' then
            return notify(self, 'No custom theme selected')
        end
        self:ApplyTheme(name)
        notify(self, string.format('Loaded theme "%s"', name))
    end)

    groupbox:AddButton('Delete theme', function()
        local name = Options.ThemeManager_CustomThemeList.Value
        self:DeleteCustomTheme(name)
        Options.ThemeManager_CustomThemeList:SetValues(self:ReloadCustomThemes())
        Options.ThemeManager_CustomThemeList:SetValue(nil)
    end)

    groupbox:AddButton('Refresh list', function()
        Options.ThemeManager_CustomThemeList:SetValues(self:ReloadCustomThemes())
        Options.ThemeManager_CustomThemeList:SetValue(nil)
    end)

    groupbox:AddButton('Set as default', function()
        local name = Options.ThemeManager_CustomThemeList.Value
        if not name or name == '' then
            return notify(self, 'No custom theme selected')
        end
        self:SaveDefault(name)
        notify(self, string.format('Set default theme to "%s"', name))
    end)

    -- ── Live color picker callbacks ───────────
    local function onColorChanged()
        self:ThemeUpdate()
    end

    for _, field in next, COLOR_FIELDS do
        Options[field]:OnChanged(onColorChanged)
    end

    -- Apply default theme on init.
    ThemeManager:LoadDefault()
end

-- ── Groupbox / tab helpers ────────────────────

function ThemeManager:CreateGroupBox(tab)
    assert(self.Library, 'ThemeManager: Library must be set before calling CreateGroupBox')
    return tab:AddLeftGroupbox('Themes')
end

function ThemeManager:ApplyToTab(tab)
    assert(self.Library, 'ThemeManager: Library must be set before calling ApplyToTab')
    self:CreateThemeManager(self:CreateGroupBox(tab))
end

function ThemeManager:ApplyToGroupbox(groupbox)
    assert(self.Library, 'ThemeManager: Library must be set before calling ApplyToGroupbox')
    self:CreateThemeManager(groupbox)
end

-- ── Init ──────────────────────────────────────

ThemeManager:BuildFolderTree()

return ThemeManager
