local HttpService = game:GetService('HttpService')

-- ─────────────────────────────────────────────
--  SaveManager
--  Handles config saving, loading and autoload
--  for LinoriaLib-based scripts.
-- ─────────────────────────────────────────────

local SaveManager = {}

SaveManager.Folder  = 'LinoriaLibSettings'
SaveManager.Ignore  = {}
SaveManager.Library = nil

-- ── Helpers ───────────────────────────────────

--- Returns the full settings directory path.
local function settingsPath(self)
    return self.Folder .. '/settings'
end

--- Returns the full path for a named config file.
local function configPath(self, name)
    return settingsPath(self) .. '/' .. name .. '.json'
end

--- Returns the autoload pointer path.
local function autoloadPath(self)
    return settingsPath(self) .. '/autoload.txt'
end

--- Safely notify via the library if it is set.
local function notify(self, msg)
    if self.Library then
        self.Library:Notify(msg)
    end
end

-- ── Parsers ───────────────────────────────────

SaveManager.Parser = {
    Toggle = {
        Save = function(idx, object)
            return { type = 'Toggle', idx = idx, value = object.Value }
        end,
        Load = function(idx, data)
            if Toggles[idx] then
                Toggles[idx]:SetValue(data.value)
            end
        end,
    },

    Slider = {
        Save = function(idx, object)
            return { type = 'Slider', idx = idx, value = tostring(object.Value) }
        end,
        Load = function(idx, data)
            if Options[idx] then
                Options[idx]:SetValue(data.value)
            end
        end,
    },

    Dropdown = {
        Save = function(idx, object)
            -- Note: 'multi' was previously mistyped as 'mutli'.
            return { type = 'Dropdown', idx = idx, value = object.Value, multi = object.Multi }
        end,
        Load = function(idx, data)
            if Options[idx] then
                Options[idx]:SetValue(data.value)
            end
        end,
    },

    ColorPicker = {
        Save = function(idx, object)
            return { type = 'ColorPicker', idx = idx, value = object.Value:ToHex(), transparency = object.Transparency }
        end,
        Load = function(idx, data)
            if Options[idx] then
                Options[idx]:SetValueRGB(Color3.fromHex(data.value), data.transparency)
            end
        end,
    },

    KeyPicker = {
        Save = function(idx, object)
            return { type = 'KeyPicker', idx = idx, mode = object.Mode, key = object.Value }
        end,
        Load = function(idx, data)
            if Options[idx] then
                Options[idx]:SetValue({ data.key, data.mode })
            end
        end,
    },

    Input = {
        Save = function(idx, object)
            return { type = 'Input', idx = idx, text = object.Value }
        end,
        Load = function(idx, data)
            if Options[idx] and type(data.text) == 'string' then
                Options[idx]:SetValue(data.text)
            end
        end,
    },
}

-- ── Public API ────────────────────────────────

function SaveManager:SetIgnoreIndexes(list)
    for _, key in next, list do
        self.Ignore[key] = true
    end
end

function SaveManager:SetFolder(folder)
    self.Folder = folder
    self:BuildFolderTree()
end

function SaveManager:SetLibrary(library)
    self.Library = library
end

--- Persist the current UI state to a named config file.
function SaveManager:Save(name)
    if not name or name == '' then
        return false, 'no config name provided'
    end

    local data = { objects = {} }
    local objects = data.objects

    for idx, toggle in next, Toggles do
        if not self.Ignore[idx] then
            table.insert(objects, self.Parser[toggle.Type].Save(idx, toggle))
        end
    end

    for idx, option in next, Options do
        if self.Parser[option.Type] and not self.Ignore[idx] then
            table.insert(objects, self.Parser[option.Type].Save(idx, option))
        end
    end

    local ok, encoded = pcall(HttpService.JSONEncode, HttpService, data)
    if not ok then
        return false, 'failed to encode data'
    end

    local ok2, writeErr = pcall(writefile, configPath(self, name), encoded)
    if not ok2 then
        return false, 'failed to write file: ' .. tostring(writeErr)
    end

    return true
end

--- Load a named config file and apply it to the UI.
function SaveManager:Load(name)
    if not name or name == '' then
        return false, 'no config name provided'
    end

    local path = configPath(self, name)
    if not isfile(path) then
        return false, 'config file does not exist'
    end

    local ok, decoded = pcall(function()
        return HttpService:JSONDecode(readfile(path))
    end)

    if not ok then
        return false, 'failed to decode config (file may be corrupt)'
    end

    if type(decoded) ~= 'table' or type(decoded.objects) ~= 'table' then
        return false, 'config has an unexpected format'
    end

    for _, entry in next, decoded.objects do
        local parser = self.Parser[entry.type]
        if parser then
            -- task.spawn so a single bad entry cannot block the rest.
            task.spawn(parser.Load, entry.idx, entry)
        end
    end

    return true
end

--- Returns a list of config names present in the settings folder.
function SaveManager:RefreshConfigList()
    local files = listfiles(settingsPath(self))
    local out   = {}

    for _, file in next, files do
        -- Match anything after the last slash/backslash ending in .json
        local name = file:match('[/\\]?([^/\\]+)%.json$')
        if name then
            table.insert(out, name)
        end
    end

    return out
end

--- Ignore the standard theme-manager indexes so they are not saved per-config.
function SaveManager:IgnoreThemeSettings()
    self:SetIgnoreIndexes({
        'BackgroundColor', 'MainColor', 'AccentColor', 'OutlineColor', 'FontColor',
        'ThemeManager_ThemeList', 'ThemeManager_CustomThemeList', 'ThemeManager_CustomThemeName',
    })
end

--- Create the required folder structure on disk.
function SaveManager:BuildFolderTree()
    local paths = {
        self.Folder,
        self.Folder .. '/themes',
        settingsPath(self),
    }

    for _, path in next, paths do
        if not isfolder(path) then
            makefolder(path)
        end
    end
end

--- If an autoload pointer file exists, load the referenced config.
function SaveManager:LoadAutoloadConfig()
    local path = autoloadPath(self)
    if not isfile(path) then return end

    local name = readfile(path)
    if not name or name:gsub('%s+', '') == '' then return end

    local ok, err = self:Load(name)
    if not ok then
        notify(self, 'Failed to load autoload config: ' .. err)
        return
    end

    notify(self, string.format('Auto-loaded config "%s"', name))
end

--- Build the Configuration section inside the provided tab.
function SaveManager:BuildConfigSection(tab)
    assert(self.Library, 'SaveManager: Library must be set before calling BuildConfigSection')

    local section = tab:AddRightGroupbox('Configuration')

    section:AddInput('SaveManager_ConfigName', { Text = 'Config name' })
    section:AddDropdown('SaveManager_ConfigList', {
        Text      = 'Config list',
        Values    = self:RefreshConfigList(),
        AllowNull = true,
    })

    section:AddDivider()

    -- Save new config
    section:AddButton('Save config', function()
        local name = Options.SaveManager_ConfigName.Value

        -- Trim whitespace and block path traversal characters
        name = name:match('^%s*(.-)%s*$')
        if name == '' then
            return notify(self, 'Config name cannot be empty')
        end
        if name:find('[/\\%.%:]') then
            return notify(self, 'Config name contains invalid characters')
        end

        local ok, err = self:Save(name)
        if not ok then
            return notify(self, 'Failed to save config: ' .. err)
        end

        notify(self, string.format('Saved config "%s"', name))
        Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
        Options.SaveManager_ConfigList:SetValue(nil)
    end)

    -- Load selected config
    :AddButton('Load config', function()
        local name = Options.SaveManager_ConfigList.Value
        if not name or name == '' then
            return notify(self, 'No config selected')
        end

        local ok, err = self:Load(name)
        if not ok then
            return notify(self, 'Failed to load config: ' .. err)
        end

        notify(self, string.format('Loaded config "%s"', name))
    end)

    -- Overwrite selected config
    section:AddButton('Overwrite config', function()
        local name = Options.SaveManager_ConfigList.Value
        if not name or name == '' then
            return notify(self, 'No config selected to overwrite')
        end

        local ok, err = self:Save(name)
        if not ok then
            return notify(self, 'Failed to overwrite config: ' .. err)
        end

        notify(self, string.format('Overwrote config "%s"', name))
    end)

    -- Refresh dropdown values
    section:AddButton('Refresh list', function()
        Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
        Options.SaveManager_ConfigList:SetValue(nil)
    end)

    -- Set autoload pointer
    section:AddButton('Set as autoload', function()
        local name = Options.SaveManager_ConfigList.Value
        if not name or name == '' then
            return notify(self, 'No config selected to set as autoload')
        end

        local ok, err = pcall(writefile, autoloadPath(self), name)
        if not ok then
            return notify(self, 'Failed to write autoload file: ' .. tostring(err))
        end

        SaveManager.AutoloadLabel:SetText('Autoload config: ' .. name)
        notify(self, string.format('Set "%s" as autoload config', name))
    end)

    -- Autoload label
    local autoloadName = isfile(autoloadPath(self)) and readfile(autoloadPath(self)) or nil
    SaveManager.AutoloadLabel = section:AddLabel(
        autoloadName and ('Autoload config: ' .. autoloadName) or 'Autoload config: none',
        true
    )

    -- These UI controls should never be persisted in configs
    self:SetIgnoreIndexes({ 'SaveManager_ConfigList', 'SaveManager_ConfigName' })
end

SaveManager:BuildFolderTree()

return SaveManager
