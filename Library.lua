local InputService = game:GetService('UserInputService');
local TextService = game:GetService('TextService');
local CoreGui = game:GetService('CoreGui');
local Teams = game:GetService('Teams');
local Players = game:GetService('Players');
local RunService = game:GetService('RunService')
local TweenService = game:GetService('TweenService');
local RenderStepped = RunService.RenderStepped;
local LocalPlayer = Players.LocalPlayer;
local Mouse = LocalPlayer:GetMouse();

local Toggled = false;
local _lastTouchX, _lastTouchY = 0, 0;

-- Track touch position globally so GetMousePosition always has a fresh value
InputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch then
		_lastTouchX, _lastTouchY = input.Position.X, input.Position.Y;
	end;
end);
InputService.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch then
		_lastTouchX, _lastTouchY = input.Position.X, input.Position.Y;
	end;
end);

local ProtectGui = protectgui or (syn and syn.protect_gui) or (function() end);

local ScreenGui = Instance.new('ScreenGui');
ProtectGui(ScreenGui);

ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global;
ScreenGui.Parent = CoreGui;

local Toggles = {};
local Options = {};

getgenv().Toggles = Toggles;
getgenv().Options = Options;

local Library = {
	Registry = {};
	RegistryMap = {};

	HudRegistry = {};

	FontColor = Color3.fromRGB(255, 255, 255);
	MainColor = Color3.fromRGB(28, 28, 28);
	BackgroundColor = Color3.fromRGB(20, 20, 20);
	AccentColor = Color3.fromRGB(0, 85, 255);
	OutlineColor = Color3.fromRGB(50, 50, 50);
	RiskColor = Color3.fromRGB(255, 50, 50),

	Black = Color3.new(0, 0, 0);
	Font = Enum.Font.Code,

	OpenedFrames = {};
	DependencyBoxes = {};

	Signals = {};
	ScreenGui = ScreenGui;
};

local RainbowStep = 0
local Hue = 0

table.insert(Library.Signals, RenderStepped:Connect(function(Delta)
	RainbowStep = RainbowStep + Delta

	if RainbowStep >= (1 / 60) then
		RainbowStep = 0

		Hue = Hue + (1 / 400);

		if Hue > 1 then
			Hue = 0;
		end;

		Library.CurrentRainbowHue = Hue;
		Library.CurrentRainbowColor = Color3.fromHSV(Hue, 0.8, 1);
	end
end))

local function GetPlayersString()
	local PlayerList = Players:GetPlayers();

	for i = 1, #PlayerList do
		PlayerList[i] = PlayerList[i].Name;
	end;

	table.sort(PlayerList, function(str1, str2) return str1 < str2 end);

	return PlayerList;
end;

local function GetTeamsString()
	local TeamList = Teams:GetTeams();

	for i = 1, #TeamList do
		TeamList[i] = TeamList[i].Name;
	end;

	table.sort(TeamList, function(str1, str2) return str1 < str2 end);

	return TeamList;
end;

function Library:SafeCallback(f, ...)
	if (not f) then
		return;
	end;

	if not Library.NotifyOnError then
		return f(...);
	end;

	local success, event = pcall(f, ...);

	if not success then
		local _, i = event:find(":%d+: ");

		if not i then
			return Library:Notify(event);
		end;

		return Library:Notify(event:sub(i + 1), 3);
	end;
end;

function Library:AttemptSave()
	if Library.SaveManager then
		Library.SaveManager:Save();
	end;
end;

function Library:Create(Class, Properties)
	local _Instance = Class;

	if type(Class) == 'string' then
		_Instance = Instance.new(Class);
	end;

	for Property, Value in next, Properties do
		_Instance[Property] = Value;
	end;

	return _Instance;
end;

function Library:ApplyTextStroke(Inst)
	Inst.TextStrokeTransparency = 1;

	Library:Create('UIStroke', {
		Color = Color3.new(0, 0, 0);
		Thickness = 1;
		LineJoinMode = Enum.LineJoinMode.Miter;
		Parent = Inst;
	});
end;

function Library:CreateLabel(Properties, IsHud)
	local _Instance = Library:Create('TextLabel', {
		BackgroundTransparency = 1;
		Font = Library.Font;
		TextColor3 = Library.FontColor;
		TextSize = 16;
		TextStrokeTransparency = 0;
		TextTruncate = Enum.TextTruncate.AtEnd;
		ClipsDescendants = true;
	});

	Library:ApplyTextStroke(_Instance);

	Library:AddToRegistry(_Instance, {
		TextColor3 = 'FontColor';
	}, IsHud);

	return Library:Create(_Instance, Properties);
end;

function Library:MakeDraggable(Instance, Cutoff)
	Instance.Active = true;

	Instance.InputBegan:Connect(function(Input)
		if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
			local startX, startY = Input.Position.X, Input.Position.Y;
			local ObjPos = Vector2.new(
				startX - Instance.AbsolutePosition.X,
				startY - Instance.AbsolutePosition.Y
			);

			if ObjPos.Y > (Cutoff or 40) then
				return;
			end;

			local dragging = true;
			local lastPos = Vector2.new(startX, startY);

			local moveConn = InputService.InputChanged:Connect(function(changed)
				if changed.UserInputType == Enum.UserInputType.MouseMovement or changed.UserInputType == Enum.UserInputType.Touch then
					lastPos = Vector2.new(changed.Position.X, changed.Position.Y);
				end;
			end);

			local endConn = InputService.InputEnded:Connect(function(endInput)
				if endInput == Input then
					dragging = false;
				end;
			end);

			while dragging do
				Instance.Position = UDim2.new(
					0,
					lastPos.X - ObjPos.X + (Instance.AbsoluteSize.X * Instance.AnchorPoint.X),
					0,
					lastPos.Y - ObjPos.Y + (Instance.AbsoluteSize.Y * Instance.AnchorPoint.Y)
				);

				RenderStepped:Wait();
			end;

			moveConn:Disconnect();
			endConn:Disconnect();
		end;
	end)
end;

function Library:AddToolTip(InfoStr, HoverInstance)
	local X, Y = Library:GetTextBounds(InfoStr, Library.Font, 14);
	local Tooltip = Library:Create('Frame', {
		BackgroundColor3 = Library.MainColor,
		BorderColor3 = Library.OutlineColor,

		Size = UDim2.fromOffset(X + 5, Y + 4),
		ZIndex = 100,
		Parent = Library.ScreenGui,

		Visible = false,
	})

	local Label = Library:CreateLabel({
		Position = UDim2.fromOffset(3, 1),
		Size = UDim2.fromOffset(X, Y);
		TextSize = 14;
		Text = InfoStr,
		TextColor3 = Library.FontColor,
		TextXAlignment = Enum.TextXAlignment.Left;
		ZIndex = Tooltip.ZIndex + 1,

		Parent = Tooltip;
	});

	Library:AddToRegistry(Tooltip, {
		BackgroundColor3 = 'MainColor';
		BorderColor3 = 'OutlineColor';
	});

	Library:AddToRegistry(Label, {
		TextColor3 = 'FontColor',
	});

	local IsHovering = false

	HoverInstance.MouseEnter:Connect(function()
		if Library:MouseIsOverOpenedFrame() then
			return
		end

		IsHovering = true

		local mx, my = Library:GetMousePosition()
		Tooltip.Position = UDim2.fromOffset(mx + 15, my + 12)
		Tooltip.Visible = true

		while IsHovering do
			RunService.Heartbeat:Wait()
			mx, my = Library:GetMousePosition()
			Tooltip.Position = UDim2.fromOffset(mx + 15, my + 12)
		end
	end)

	HoverInstance.MouseLeave:Connect(function()
		IsHovering = false
		Tooltip.Visible = false
	end)
end

function Library:OnHighlight(HighlightInstance, Instance, Properties, PropertiesDefault)
	HighlightInstance.MouseEnter:Connect(function()
		local Reg = Library.RegistryMap[Instance];

		for Property, ColorIdx in next, Properties do
			Instance[Property] = Library[ColorIdx] or ColorIdx;

			if Reg and Reg.Properties[Property] then
				Reg.Properties[Property] = ColorIdx;
			end;
		end;
	end)

	HighlightInstance.MouseLeave:Connect(function()
		local Reg = Library.RegistryMap[Instance];

		for Property, ColorIdx in next, PropertiesDefault do
			Instance[Property] = Library[ColorIdx] or ColorIdx;

			if Reg and Reg.Properties[Property] then
				Reg.Properties[Property] = ColorIdx;
			end;
		end;
	end)
end;

function Library:GetMousePosition()
	local ok, lastType = pcall(function() return InputService:GetLastInputType() end);
	if ok and lastType == Enum.UserInputType.Touch then
		if _lastTouchX ~= 0 or _lastTouchY ~= 0 then
			return _lastTouchX, _lastTouchY;
		end;
	end;
	return Mouse.X, Mouse.Y;
end;

function Library:MouseIsOverOpenedFrame()
	local mx, my = Library:GetMousePosition();
	for Frame, _ in next, Library.OpenedFrames do
		local AbsPos, AbsSize = Frame.AbsolutePosition, Frame.AbsoluteSize;

		if mx >= AbsPos.X and mx <= AbsPos.X + AbsSize.X
			and my >= AbsPos.Y and my <= AbsPos.Y + AbsSize.Y then

			return true;
		end;
	end;
end;

function Library:IsMouseOverFrame(Frame)
	local mx, my = Library:GetMousePosition();
	local AbsPos, AbsSize = Frame.AbsolutePosition, Frame.AbsoluteSize;

	if mx >= AbsPos.X and mx <= AbsPos.X + AbsSize.X
		and my >= AbsPos.Y and my <= AbsPos.Y + AbsSize.Y then

		return true;
	end;
end;

function Library:UpdateDependencyBoxes()
	for _, Depbox in next, Library.DependencyBoxes do
		Depbox:Update();
	end;
end;

function Library:MapValue(Value, MinA, MaxA, MinB, MaxB)
	return (1 - ((Value - MinA) / (MaxA - MinA))) * MinB + ((Value - MinA) / (MaxA - MinA)) * MaxB;
end;

function Library:GetTextBounds(Text, Font, Size, Resolution)
	local Bounds = TextService:GetTextSize(Text, Size, Font, Resolution or Vector2.new(1920, 1080))
	return Bounds.X, Bounds.Y
end;

function Library:GetDarkerColor(Color)
	local H, S, V = Color3.toHSV(Color);
	return Color3.fromHSV(H, S, V / 1.5);
end;
Library.AccentColorDark = Library:GetDarkerColor(Library.AccentColor);

function Library:AddToRegistry(Instance, Properties, IsHud)
	local Idx = #Library.Registry + 1;
	local Data = {
		Instance = Instance;
		Properties = Properties;
		Idx = Idx;
	};

	table.insert(Library.Registry, Data);
	Library.RegistryMap[Instance] = Data;

	if IsHud then
		table.insert(Library.HudRegistry, Data);
	end;
end;

function Library:RemoveFromRegistry(Instance)
	local Data = Library.RegistryMap[Instance];

	if Data then
		for Idx = #Library.Registry, 1, -1 do
			if Library.Registry[Idx] == Data then
				table.remove(Library.Registry, Idx);
			end;
		end;

		for Idx = #Library.HudRegistry, 1, -1 do
			if Library.HudRegistry[Idx] == Data then
				table.remove(Library.HudRegistry, Idx);
			end;
		end;

		Library.RegistryMap[Instance] = nil;
	end;
end;

function Library:UpdateColorsUsingRegistry()
	for Idx, Object in next, Library.Registry do
		for Property, ColorIdx in next, Object.Properties do
			if type(ColorIdx) == 'string' then
				Object.Instance[Property] = Library[ColorIdx];
			elseif type(ColorIdx) == 'function' then
				Object.Instance[Property] = ColorIdx()
			end
		end;
	end;
end;

function Library:GiveSignal(Signal)
	table.insert(Library.Signals, Signal)
end

function Library:Unload()
	for Idx = #Library.Signals, 1, -1 do
		local Connection = table.remove(Library.Signals, Idx)
		Connection:Disconnect()
	end

	if Library.OnUnload then
		Library.OnUnload()
	end

	ScreenGui:Destroy()
end

function Library:OnUnload(Callback)
	Library.OnUnload = Callback
end

Library:GiveSignal(ScreenGui.DescendantRemoving:Connect(function(Instance)
	if Library.RegistryMap[Instance] then
		Library:RemoveFromRegistry(Instance);
	end;
end))

local BaseAddons = {};

do
	local Funcs = {};

	function Funcs:AddColorPicker(Idx, Info)
		local ToggleLabel = self.TextLabel;

		assert(Info.Default, 'AddColorPicker: Missing default value.');

		local ColorPicker = {
			Value = Info.Default;
			Transparency = Info.Transparency or 0;
			Type = 'ColorPicker';
			Title = type(Info.Title) == 'string' and Info.Title or 'Color picker',
			Callback = Info.Callback or function(Color) end;
		};

		function ColorPicker:SetHSVFromRGB(Color)
			local H, S, V = Color3.toHSV(Color);

			ColorPicker.Hue = H;
			ColorPicker.Sat = S;
			ColorPicker.Vib = V;
		end;

		ColorPicker:SetHSVFromRGB(ColorPicker.Value);

		local DisplayFrame = Library:Create('Frame', {
			BackgroundColor3 = ColorPicker.Value;
			BorderColor3 = Library:GetDarkerColor(ColorPicker.Value);
			BorderMode = Enum.BorderMode.Inset;
			Size = UDim2.new(0, 28, 0, 14);
			ZIndex = 6;
			Parent = ToggleLabel;
		});

		local CheckerFrame = Library:Create('ImageLabel', {
			BorderSizePixel = 0;
			Size = UDim2.new(0, 27, 0, 13);
			ZIndex = 5;
			Image = 'http://www.roblox.com/asset/?id=12977615774';
			Visible = not not Info.Transparency;
			Parent = DisplayFrame;
		});

		local PickerFrameOuter = Library:Create('Frame', {
			Name = 'Color';
			BackgroundColor3 = Color3.new(1, 1, 1);
			BorderColor3 = Color3.new(0, 0, 0);
			Position = UDim2.fromOffset(DisplayFrame.AbsolutePosition.X, DisplayFrame.AbsolutePosition.Y + 18),
			Size = UDim2.fromOffset(230, Info.Transparency and 271 or 253);
			Visible = false;
			ZIndex = 15;
			Parent = ScreenGui,
		});

		DisplayFrame:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
			PickerFrameOuter.Position = UDim2.fromOffset(DisplayFrame.AbsolutePosition.X, DisplayFrame.AbsolutePosition.Y + 18);
		end)

		local PickerFrameInner = Library:Create('Frame', {
			BackgroundColor3 = Library.BackgroundColor;
			BorderColor3 = Library.OutlineColor;
			BorderMode = Enum.BorderMode.Inset;
			Size = UDim2.new(1, 0, 1, 0);
			ZIndex = 16;
			Parent = PickerFrameOuter;
		});

		local Highlight = Library:Create('Frame', {
			BackgroundColor3 = Library.AccentColor;
			BorderSizePixel = 0;
			Size = UDim2.new(1, 0, 0, 2);
			ZIndex = 17;
			Parent = PickerFrameInner;
		});

		local SatVibMapOuter = Library:Create('Frame', {
			BorderColor3 = Color3.new(0, 0, 0);
			Position = UDim2.new(0, 4, 0, 25);
			Size = UDim2.new(0, 200, 0, 200);
			ZIndex = 17;
			Parent = PickerFrameInner;
		});

		local SatVibMapInner = Library:Create('Frame', {
			BackgroundColor3 = Library.BackgroundColor;
			BorderColor3 = Library.OutlineColor;
			BorderMode = Enum.BorderMode.Inset;
			Size = UDim2.new(1, 0, 1, 0);
			ZIndex = 18;
			Parent = SatVibMapOuter;
		});

		local SatVibMap = Library:Create('ImageLabel', {
			BorderSizePixel = 0;
			Size = UDim2.new(1, 0, 1, 0);
			ZIndex = 18;
			Image = 'rbxassetid://4155801252';
			Parent = SatVibMapInner;
		});

		local CursorOuter = Library:Create('ImageLabel', {
			AnchorPoint = Vector2.new(0.5, 0.5);
			Size = UDim2.new(0, 6, 0, 6);
			BackgroundTransparency = 1;
			Image = 'http://www.roblox.com/asset/?id=9619665977';
			ImageColor3 = Color3.new(0, 0, 0);
			ZIndex = 19;
			Parent = SatVibMap;
		});

		local CursorInner = Library:Create('ImageLabel', {
			Size = UDim2.new(0, CursorOuter.Size.X.Offset - 2, 0, CursorOuter.Size.Y.Offset - 2);
			Position = UDim2.new(0, 1, 0, 1);
			BackgroundTransparency = 1;
			Image = 'http://www.roblox.com/asset/?id=9619665977';
			ZIndex = 20;
			Parent = CursorOuter;
		})

		local HueSelectorOuter = Library:Create('Frame', {
			BorderColor3 = Color3.new(0, 0, 0);
			Position = UDim2.new(0, 208, 0, 25);
			Size = UDim2.new(0, 15, 0, 200);
			ZIndex = 17;
			Parent = PickerFrameInner;
		});

		local HueSelectorInner = Library:Create('Frame', {
			BackgroundColor3 = Color3.new(1, 1, 1);
			BorderSizePixel = 0;
			Size = UDim2.new(1, 0, 1, 0);
			ZIndex = 18;
			Parent = HueSelectorOuter;
		});

		local HueCursor = Library:Create('Frame', { 
			BackgroundColor3 = Color3.new(1, 1, 1);
			AnchorPoint = Vector2.new(0, 0.5);
			BorderColor3 = Color3.new(0, 0, 0);
			Size = UDim2.new(1, 0, 0, 1);
			ZIndex = 18;
			Parent = HueSelectorInner;
		});

		local HueBoxOuter = Library:Create('Frame', {
			BorderColor3 = Color3.new(0, 0, 0);
			Position = UDim2.fromOffset(4, 228),
			Size = UDim2.new(0.5, -6, 0, 20),
			ZIndex = 18,
			Parent = PickerFrameInner;
		});

		local HueBoxInner = Library:Create('Frame', {
			BackgroundColor3 = Library.MainColor;
			BorderColor3 = Library.OutlineColor;
			BorderMode = Enum.BorderMode.Inset;
			Size = UDim2.new(1, 0, 1, 0);
			ZIndex = 18,
			Parent = HueBoxOuter;
		});

		Library:Create('UIGradient', {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
			});
			Rotation = 90;
			Parent = HueBoxInner;
		});

		local HueBox = Library:Create('TextBox', {
			BackgroundTransparency = 1;
			Position = UDim2.new(0, 5, 0, 0);
			Size = UDim2.new(1, -5, 1, 0);
			Font = Library.Font;
			PlaceholderColor3 = Color3.fromRGB(190, 190, 190);
			PlaceholderText = 'Hex color',
			Text = '#FFFFFF',
			TextColor3 = Library.FontColor;
			TextSize = 14;
			TextStrokeTransparency = 0;
			TextXAlignment = Enum.TextXAlignment.Left;
			ZIndex = 20,
			Parent = HueBoxInner;
		});

		Library:ApplyTextStroke(HueBox);

		local RgbBoxBase = Library:Create(HueBoxOuter:Clone(), {
			Position = UDim2.new(0.5, 2, 0, 228),
			Size = UDim2.new(0.5, -6, 0, 20),
			Parent = PickerFrameInner
		});

		local RgbBox = Library:Create(RgbBoxBase.Frame:FindFirstChild('TextBox'), {
			Text = '255, 255, 255',
			PlaceholderText = 'RGB color',
			TextColor3 = Library.FontColor
		});

		local TransparencyBoxOuter, TransparencyBoxInner, TransparencyCursor;

		if Info.Transparency then 
			TransparencyBoxOuter = Library:Create('Frame', {
				BorderColor3 = Color3.new(0, 0, 0);
				Position = UDim2.fromOffset(4, 251);
				Size = UDim2.new(1, -8, 0, 15);
				ZIndex = 19;
				Parent = PickerFrameInner;
			});

			TransparencyBoxInner = Library:Create('Frame', {
				BackgroundColor3 = ColorPicker.Value;
				BorderColor3 = Library.OutlineColor;
				BorderMode = Enum.BorderMode.Inset;
				Size = UDim2.new(1, 0, 1, 0);
				ZIndex = 19;
				Parent = TransparencyBoxOuter;
			});

			Library:AddToRegistry(TransparencyBoxInner, { BorderColor3 = 'OutlineColor' });

			Library:Create('ImageLabel', {
				BackgroundTransparency = 1;
				Size = UDim2.new(1, 0, 1, 0);
				Image = 'http://www.roblox.com/asset/?id=12978095818';
				ZIndex = 20;
				Parent = TransparencyBoxInner;
			});

			TransparencyCursor = Library:Create('Frame', { 
				BackgroundColor3 = Color3.new(1, 1, 1);
				AnchorPoint = Vector2.new(0.5, 0);
				BorderColor3 = Color3.new(0, 0, 0);
				Size = UDim2.new(0, 1, 1, 0);
				ZIndex = 21;
				Parent = TransparencyBoxInner;
			});
		end;

		local DisplayLabel = Library:CreateLabel({
			Size = UDim2.new(1, 0, 0, 14);
			Position = UDim2.fromOffset(5, 5);
			TextXAlignment = Enum.TextXAlignment.Left;
			TextSize = 14;
			Text = ColorPicker.Title,
			TextWrapped = false;
			ZIndex = 16;
			Parent = PickerFrameInner;
		});


		local ContextMenu = {}
		do
			ContextMenu.Options = {}
			ContextMenu.Container = Library:Create('Frame', {
				BorderColor3 = Color3.new(),
				ZIndex = 14,

				Visible = false,
				Parent = ScreenGui
			})

			ContextMenu.Inner = Library:Create('Frame', {
				BackgroundColor3 = Library.BackgroundColor;
				BorderColor3 = Library.OutlineColor;
				BorderMode = Enum.BorderMode.Inset;
				Size = UDim2.fromScale(1, 1);
				ZIndex = 15;
				Parent = ContextMenu.Container;
			});

			Library:Create('UIListLayout', {
				Name = 'Layout',
				FillDirection = Enum.FillDirection.Vertical;
				SortOrder = Enum.SortOrder.LayoutOrder;
				Parent = ContextMenu.Inner;
			});

			Library:Create('UIPadding', {
				Name = 'Padding',
				PaddingLeft = UDim.new(0, 4),
				Parent = ContextMenu.Inner,
			});

			local function updateMenuPosition()
				ContextMenu.Container.Position = UDim2.fromOffset(
					(DisplayFrame.AbsolutePosition.X + DisplayFrame.AbsoluteSize.X) + 4,
					DisplayFrame.AbsolutePosition.Y + 1
				)
			end

			local function updateMenuSize()
				local menuWidth = 60
				for i, label in next, ContextMenu.Inner:GetChildren() do
					if label:IsA('TextLabel') then
						menuWidth = math.max(menuWidth, label.TextBounds.X)
					end
				end

				ContextMenu.Container.Size = UDim2.fromOffset(
					menuWidth + 8,
					ContextMenu.Inner.Layout.AbsoluteContentSize.Y + 4
				)
			end

			DisplayFrame:GetPropertyChangedSignal('AbsolutePosition'):Connect(updateMenuPosition)
			ContextMenu.Inner.Layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(updateMenuSize)

			task.spawn(updateMenuPosition)
			task.spawn(updateMenuSize)

			Library:AddToRegistry(ContextMenu.Inner, {
				BackgroundColor3 = 'BackgroundColor';
				BorderColor3 = 'OutlineColor';
			});

			function ContextMenu:Show()
				self.Container.Visible = true
			end

			function ContextMenu:Hide()
				self.Container.Visible = false
			end

			function ContextMenu:AddOption(Str, Callback)
				if type(Callback) ~= 'function' then
					Callback = function() end
				end

				local Button = Library:CreateLabel({
					Active = true;
					Size = UDim2.new(1, 0, 0, 15);
					TextSize = 13;
					Text = Str;
					ZIndex = 16;
					Parent = self.Inner;
					TextXAlignment = Enum.TextXAlignment.Left,
				});

				Library:OnHighlight(Button, Button, 
					{ TextColor3 = 'AccentColor' },
					{ TextColor3 = 'FontColor' }
				);

				Button.InputBegan:Connect(function(Input)
					if Input.UserInputType ~= Enum.UserInputType.MouseButton1 and Input.UserInputType ~= Enum.UserInputType.Touch then
						return
					end

					Callback()
				end)
			end

			ContextMenu:AddOption('Copy color', function()
				Library.ColorClipboard = ColorPicker.Value
				Library:Notify('Copied color!', 2)
			end)

			ContextMenu:AddOption('Paste color', function()
				if not Library.ColorClipboard then
					return Library:Notify('You have not copied a color!', 2)
				end
				ColorPicker:SetValueRGB(Library.ColorClipboard)
			end)


			ContextMenu:AddOption('Copy HEX', function()
				pcall(setclipboard, ColorPicker.Value:ToHex())
				Library:Notify('Copied hex code to clipboard!', 2)
			end)

			ContextMenu:AddOption('Copy RGB', function()
				pcall(setclipboard, table.concat({ math.floor(ColorPicker.Value.R * 255), math.floor(ColorPicker.Value.G * 255), math.floor(ColorPicker.Value.B * 255) }, ', '))
				Library:Notify('Copied RGB values to clipboard!', 2)
			end)

		end

		Library:AddToRegistry(PickerFrameInner, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; });
		Library:AddToRegistry(Highlight, { BackgroundColor3 = 'AccentColor'; });
		Library:AddToRegistry(SatVibMapInner, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; });

		Library:AddToRegistry(HueBoxInner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });
		Library:AddToRegistry(RgbBoxBase.Frame, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });
		Library:AddToRegistry(RgbBox, { TextColor3 = 'FontColor', });
		Library:AddToRegistry(HueBox, { TextColor3 = 'FontColor', });

		local SequenceTable = {};

		for Hue = 0, 1, 0.1 do
			table.insert(SequenceTable, ColorSequenceKeypoint.new(Hue, Color3.fromHSV(Hue, 1, 1)));
		end;

		local HueSelectorGradient = Library:Create('UIGradient', {
			Color = ColorSequence.new(SequenceTable);
			Rotation = 90;
			Parent = HueSelectorInner;
		});

		HueBox.FocusLost:Connect(function(enter)
			if enter then
				local success, result = pcall(Color3.fromHex, HueBox.Text)
				if success and typeof(result) == 'Color3' then
					ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = Color3.toHSV(result)
				end
			end

			ColorPicker:Display()
		end)

		RgbBox.FocusLost:Connect(function(enter)
			if enter then
				local r, g, b = RgbBox.Text:match('(%d+),%s*(%d+),%s*(%d+)')
				if r and g and b then
					ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = Color3.toHSV(Color3.fromRGB(r, g, b))
				end
			end

			ColorPicker:Display()
		end)

		function ColorPicker:Display()
			ColorPicker.Value = Color3.fromHSV(ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib);
			SatVibMap.BackgroundColor3 = Color3.fromHSV(ColorPicker.Hue, 1, 1);

			Library:Create(DisplayFrame, {
				BackgroundColor3 = ColorPicker.Value;
				BackgroundTransparency = ColorPicker.Transparency;
				BorderColor3 = Library:GetDarkerColor(ColorPicker.Value);
			});

			if TransparencyBoxInner then
				TransparencyBoxInner.BackgroundColor3 = ColorPicker.Value;
				TransparencyCursor.Position = UDim2.new(1 - ColorPicker.Transparency, 0, 0, 0);
			end;

			CursorOuter.Position = UDim2.new(ColorPicker.Sat, 0, 1 - ColorPicker.Vib, 0);
			HueCursor.Position = UDim2.new(0, 0, ColorPicker.Hue, 0);

			HueBox.Text = '#' .. ColorPicker.Value:ToHex()
			RgbBox.Text = table.concat({ math.floor(ColorPicker.Value.R * 255), math.floor(ColorPicker.Value.G * 255), math.floor(ColorPicker.Value.B * 255) }, ', ')

			Library:SafeCallback(ColorPicker.Callback, ColorPicker.Value);
			Library:SafeCallback(ColorPicker.Changed, ColorPicker.Value);
		end;

		function ColorPicker:OnChanged(Func)
			ColorPicker.Changed = Func;
			Func(ColorPicker.Value)
		end;

		function ColorPicker:Show()
			for Frame, Val in next, Library.OpenedFrames do
				if Frame.Name == 'Color' then
					Frame.Visible = false;
					Library.OpenedFrames[Frame] = nil;
				end;
			end;

			PickerFrameOuter.Visible = true;
			Library.OpenedFrames[PickerFrameOuter] = true;
		end;

		function ColorPicker:Hide()
			PickerFrameOuter.Visible = false;
			Library.OpenedFrames[PickerFrameOuter] = nil;
		end;

		function ColorPicker:SetValue(HSV, Transparency)
			local Color = Color3.fromHSV(HSV[1], HSV[2], HSV[3]);

			ColorPicker.Transparency = Transparency or 0;
			ColorPicker:SetHSVFromRGB(Color);
			ColorPicker:Display();
		end;

		function ColorPicker:SetValueRGB(Color, Transparency)
			ColorPicker.Transparency = Transparency or 0;
			ColorPicker:SetHSVFromRGB(Color);
			ColorPicker:Display();
		end;

		SatVibMap.InputBegan:Connect(function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
				local dragging = true;
				local lastPos = Vector2.new(Input.Position.X, Input.Position.Y);

				local moveConn = InputService.InputChanged:Connect(function(changed)
					if changed.UserInputType == Enum.UserInputType.MouseMovement or changed.UserInputType == Enum.UserInputType.Touch then
						lastPos = Vector2.new(changed.Position.X, changed.Position.Y);
					end;
				end);

				local endConn = InputService.InputEnded:Connect(function(endInput)
					if endInput == Input then
						dragging = false;
					end;
				end);

				while dragging do
					local MinX = SatVibMap.AbsolutePosition.X;
					local MaxX = MinX + SatVibMap.AbsoluteSize.X;
					local MouseX = math.clamp(lastPos.X, MinX, MaxX);

					local MinY = SatVibMap.AbsolutePosition.Y;
					local MaxY = MinY + SatVibMap.AbsoluteSize.Y;
					local MouseY = math.clamp(lastPos.Y, MinY, MaxY);

					ColorPicker.Sat = (MouseX - MinX) / (MaxX - MinX);
					ColorPicker.Vib = 1 - ((MouseY - MinY) / (MaxY - MinY));
					ColorPicker:Display();

					RenderStepped:Wait();
				end;

				moveConn:Disconnect();
				endConn:Disconnect();
				Library:AttemptSave();
			end;
		end);

		HueSelectorInner.InputBegan:Connect(function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
				local dragging = true;
				local lastY = Input.Position.Y;

				local moveConn = InputService.InputChanged:Connect(function(changed)
					if changed.UserInputType == Enum.UserInputType.MouseMovement or changed.UserInputType == Enum.UserInputType.Touch then
						lastY = changed.Position.Y;
					end;
				end);

				local endConn = InputService.InputEnded:Connect(function(endInput)
					if endInput == Input then
						dragging = false;
					end;
				end);

				while dragging do
					local MinY = HueSelectorInner.AbsolutePosition.Y;
					local MaxY = MinY + HueSelectorInner.AbsoluteSize.Y;
					local MouseY = math.clamp(lastY, MinY, MaxY);

					ColorPicker.Hue = ((MouseY - MinY) / (MaxY - MinY));
					ColorPicker:Display();

					RenderStepped:Wait();
				end;

				moveConn:Disconnect();
				endConn:Disconnect();
				Library:AttemptSave();
			end;
		end);
		DisplayFrame.InputBegan:Connect(function(Input)
			if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) and not Library:MouseIsOverOpenedFrame() then
				if PickerFrameOuter.Visible then
					ColorPicker:Hide()
				else
					ContextMenu:Hide()
					ColorPicker:Show()
				end;
			elseif Input.UserInputType == Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame() then
				ContextMenu:Show()
				ColorPicker:Hide()
			end
		end);

		if TransparencyBoxInner then
			TransparencyBoxInner.InputBegan:Connect(function(Input)
				if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
					local dragging = true;
					local lastX = Input.Position.X;

					local moveConn = InputService.InputChanged:Connect(function(changed)
						if changed.UserInputType == Enum.UserInputType.MouseMovement or changed.UserInputType == Enum.UserInputType.Touch then
							lastX = changed.Position.X;
						end;
					end);

					local endConn = InputService.InputEnded:Connect(function(endInput)
						if endInput == Input then
							dragging = false;
						end;
					end);

					while dragging do
						local MinX = TransparencyBoxInner.AbsolutePosition.X;
						local MaxX = MinX + TransparencyBoxInner.AbsoluteSize.X;
						local MouseX = math.clamp(lastX, MinX, MaxX);

						ColorPicker.Transparency = 1 - ((MouseX - MinX) / (MaxX - MinX));

						ColorPicker:Display();

						RenderStepped:Wait();
					end;

					moveConn:Disconnect();
					endConn:Disconnect();
					Library:AttemptSave();
				end;
			end);
		end;

		Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
				local AbsPos, AbsSize = PickerFrameOuter.AbsolutePosition, PickerFrameOuter.AbsoluteSize;
				local px, py = Input.Position.X, Input.Position.Y;

				if px < AbsPos.X or px > AbsPos.X + AbsSize.X
					or py < (AbsPos.Y - 20 - 1) or py > AbsPos.Y + AbsSize.Y then

					ColorPicker:Hide();
				end;

				if not Library:IsMouseOverFrame(ContextMenu.Container) then
					ContextMenu:Hide()
				end
			end;

			if Input.UserInputType == Enum.UserInputType.MouseButton2 and ContextMenu.Container.Visible then
				if not Library:IsMouseOverFrame(ContextMenu.Container) and not Library:IsMouseOverFrame(DisplayFrame) then
					ContextMenu:Hide()
				end
			end
		end))

		ColorPicker:Display();
		ColorPicker.DisplayFrame = DisplayFrame

		Options[Idx] = ColorPicker;

		return self;
	end;

	function Funcs:AddKeyPicker(Idx, Info)
		local ParentObj = self;
		local ToggleLabel = self.TextLabel;
		local Container = self.Container;

		assert(Info.Default, 'AddKeyPicker: Missing default value.');

		local KeyPicker = {
			Value = Info.Default;
			Toggled = false;
			Mode = Info.Mode or 'Toggle';
			Type = 'KeyPicker';
			Callback = Info.Callback or function(Value) end;
			ChangedCallback = Info.ChangedCallback or function(New) end;

			SyncToggleState = Info.SyncToggleState or false;
		};

		if KeyPicker.SyncToggleState then
			Info.Modes = { 'Toggle' }
			Info.Mode = 'Toggle'
		end

		local PickOuter = Library:Create('Frame', {
			BackgroundColor3 = Color3.new(0, 0, 0);
			BorderColor3 = Color3.new(0, 0, 0);
			Size = UDim2.new(0, 28, 0, 15);
			ZIndex = 6;
			Parent = ToggleLabel;
		});

		local PickInner = Library:Create('Frame', {
			BackgroundColor3 = Library.BackgroundColor;
			BorderColor3 = Library.OutlineColor;
			BorderMode = Enum.BorderMode.Inset;
			Size = UDim2.new(1, 0, 1, 0);
			ZIndex = 7;
			Parent = PickOuter;
		});

		Library:AddToRegistry(PickInner, {
			BackgroundColor3 = 'BackgroundColor';
			BorderColor3 = 'OutlineColor';
		});

		local DisplayLabel = Library:CreateLabel({
			Size = UDim2.new(1, 0, 1, 0);
			TextSize = 13;
			Text = Info.Default;
			TextWrapped = true;
			ZIndex = 8;
			Parent = PickInner;
		});

		local ModeSelectOuter = Library:Create('Frame', {
			BorderColor3 = Color3.new(0, 0, 0);
			Position = UDim2.fromOffset(ToggleLabel.AbsolutePosition.X + ToggleLabel.AbsoluteSize.X + 4, ToggleLabel.AbsolutePosition.Y + 1);
			Size = UDim2.new(0, 60, 0, 45 + 2);
			Visible = false;
			ZIndex = 14;
			Parent = ScreenGui;
		});

		ToggleLabel:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
			ModeSelectOuter.Position = UDim2.fromOffset(ToggleLabel.AbsolutePosition.X + ToggleLabel.AbsoluteSize.X + 4, ToggleLabel.AbsolutePosition.Y + 1);
		end);

		local ModeSelectInner = Library:Create('Frame', {
			BackgroundColor3 = Library.BackgroundColor;
			BorderColor3 = Library.OutlineColor;
			BorderMode = Enum.BorderMode.Inset;
			Size = UDim2.new(1, 0, 1, 0);
			ZIndex = 15;
			Parent = ModeSelectOuter;
		});

		Library:AddToRegistry(ModeSelectInner, {
			BackgroundColor3 = 'BackgroundColor';
			BorderColor3 = 'OutlineColor';
		});

		Library:Create('UIListLayout', {
			FillDirection = Enum.FillDirection.Vertical;
			SortOrder = Enum.SortOrder.LayoutOrder;
			Parent = ModeSelectInner;
		});

		local ContainerLabel = Library:CreateLabel({
			TextXAlignment = Enum.TextXAlignment.Left;
			Size = UDim2.new(1, 0, 0, 18);
			TextSize = 13;
			Visible = false;
			ZIndex = 110;
			Parent = Library.KeybindContainer;
		},  true);

		local Modes = Info.Modes or { 'Always', 'Toggle', 'Hold' };
		local ModeButtons = {};

		for Idx, Mode in next, Modes do
			local ModeButton = {};

			local Label = Library:CreateLabel({
				Active = true;
				Size = UDim2.new(1, 0, 0, 15);
				TextSize = 13;
				Text = Mode;
				ZIndex = 16;
				Parent = ModeSelectInner;
			});

			function ModeButton:Select()
				for _, Button in next, ModeButtons do
					Button:Deselect();
				end;

				KeyPicker.Mode = Mode;

				Label.TextColor3 = Library.AccentColor;
				Library.RegistryMap[Label].Properties.TextColor3 = 'AccentColor';

				ModeSelectOuter.Visible = false;
			end;

			function ModeButton:Deselect()
				KeyPicker.Mode = nil;

				Label.TextColor3 = Library.FontColor;
				Library.RegistryMap[Label].Properties.TextColor3 = 'FontColor';
			end;

			Label.InputBegan:Connect(function(Input)
				if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
					ModeButton:Select();
					Library:AttemptSave();
				end;
			end);

			if Mode == KeyPicker.Mode then
				ModeButton:Select();
			end;

			ModeButtons[Mode] = ModeButton;
		end;

		function KeyPicker:Update()
			if Info.NoUI then
				return;
			end;

			local State = KeyPicker:GetState();

			ContainerLabel.Text = string.format('[%s] %s (%s)', KeyPicker.Value, Info.Text, KeyPicker.Mode);

			ContainerLabel.Visible = true;
			ContainerLabel.TextColor3 = State and Library.AccentColor or Library.FontColor;

			Library.RegistryMap[ContainerLabel].Properties.TextColor3 = State and 'AccentColor' or 'FontColor';

			local YSize = 0
			local XSize = 0

			for _, Label in next, Library.KeybindContainer:GetChildren() do
				if Label:IsA('TextLabel') and Label.Visible then
					YSize = YSize + 18;
					if (Label.TextBounds.X > XSize) then
						XSize = Label.TextBounds.X
					end
				end;
			end;

			Library.KeybindFrame.Size = UDim2.new(0, math.max(XSize + 10, 210), 0, YSize + 23)
		end;

		function KeyPicker:GetState()
			if KeyPicker.Mode == 'Always' then
				return true;
			elseif KeyPicker.Mode == 'Hold' then
				if KeyPicker.Value == 'None' then
					return false;
				end

				local Key = KeyPicker.Value;

				if Key == 'MB1' or Key == 'MB2' then
					return Key == 'MB1' and InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
						or Key == 'MB2' and InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2);
				else
					return InputService:IsKeyDown(Enum.KeyCode[KeyPicker.Value]);
				end;
			else
				return KeyPicker.Toggled;
			end;
		end;

		function KeyPicker:SetValue(Data)
			local Key, Mode = Data[1], Data[2];
			DisplayLabel.Text = Key;
			KeyPicker.Value = Key;
			ModeButtons[Mode]:Select();
			KeyPicker:Update();
		end;

		function KeyPicker:OnClick(Callback)
			KeyPicker.Clicked = Callback
		end

		function KeyPicker:OnChanged(Callback)
			KeyPicker.Changed = Callback
			Callback(KeyPicker.Value)
		end

		if ParentObj.Addons then
			table.insert(ParentObj.Addons, KeyPicker)
		end

		function KeyPicker:DoClick()
			if ParentObj.Type == 'Toggle' and KeyPicker.SyncToggleState then
				ParentObj:SetValue(not ParentObj.Value)
			end

			Library:SafeCallback(KeyPicker.Callback, KeyPicker.Toggled)
			Library:SafeCallback(KeyPicker.Clicked, KeyPicker.Toggled)
		end

		local Picking = false;

		PickOuter.InputBegan:Connect(function(Input)
			if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) and not Library:MouseIsOverOpenedFrame() then
				Picking = true;

				DisplayLabel.Text = '';

				local Break;
				local Text = '';

				task.spawn(function()
					while (not Break) do
						if Text == '...' then
							Text = '';
						end;

						Text = Text .. '.';
						DisplayLabel.Text = Text;

						wait(0.4);
					end;
				end);

				wait(0.2);

				local Event;
				Event = InputService.InputBegan:Connect(function(Input)
					local Key;

					if Input.UserInputType == Enum.UserInputType.Keyboard then
						Key = Input.KeyCode.Name;
					elseif Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
						Key = 'MB1';
					elseif Input.UserInputType == Enum.UserInputType.MouseButton2 then
						Key = 'MB2';
					end;

					Break = true;
					Picking = false;

					DisplayLabel.Text = Key;
					KeyPicker.Value = Key;

					Library:SafeCallback(KeyPicker.ChangedCallback, Input.KeyCode or Input.UserInputType)
					Library:SafeCallback(KeyPicker.Changed, Input.KeyCode or Input.UserInputType)

					Library:AttemptSave();

					Event:Disconnect();
				end);
			elseif Input.UserInputType == Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame() then
				ModeSelectOuter.Visible = true;
			end;
		end);

		Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
			if (not Picking) then
				if KeyPicker.Mode == 'Toggle' then
					local Key = KeyPicker.Value;

					if Key == 'MB1' or Key == 'MB2' then
						if Key == 'MB1' and Input.UserInputType == Enum.UserInputType.MouseButton1
						or Key == 'MB2' and Input.UserInputType == Enum.UserInputType.MouseButton2 then
							KeyPicker.Toggled = not KeyPicker.Toggled
							KeyPicker:DoClick()
						end;
					elseif Input.UserInputType == Enum.UserInputType.Keyboard then
						if Input.KeyCode.Name == Key then
							KeyPicker.Toggled = not KeyPicker.Toggled;
							KeyPicker:DoClick()
						end;
					end;
				end;

				KeyPicker:Update();
			end;

			if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
				local AbsPos, AbsSize = ModeSelectOuter.AbsolutePosition, ModeSelectOuter.AbsoluteSize;
				local px = Input.Position.X; local py = Input.Position.Y;

				if px < AbsPos.X or px > AbsPos.X + AbsSize.X
					or py < (AbsPos.Y - 20 - 1) or py > AbsPos.Y + AbsSize.Y then

					ModeSelectOuter.Visible = false;
				end;
			end;
		end))

		Library:GiveSignal(InputService.InputEnded:Connect(function(Input)
			if (not Picking) then
				KeyPicker:Update();
			end;
		end))

		KeyPicker:Update();

		Options[Idx] = KeyPicker;

		return self;
	end;

	BaseAddons.__index = Funcs;
	BaseAddons.__namecall = function(Table, Key, ...)
		return Funcs[Key](...);
	end;
end;

local BaseGroupbox = {};

do
	local Funcs = {};

	function Funcs:AddBlank(Size)
		local Groupbox = self;
		local Container = Groupbox.Container;

		Library:Create('Frame', {
			BackgroundTransparency = 1;
			Size = UDim2.new(1, 0, 0, Size);
			ZIndex = 1;
			Parent = Container;
		});
	end;

	function Funcs:AddLabel(Text, DoesWrap)
		local Label = {};

		local Groupbox = self;
		local Container = Groupbox.Container;

		local TextLabel = Library:CreateLabel({
			Size = UDim2.new(1, -4, 0, 15);
			TextSize = 14;
			Text = Text;
			TextWrapped = DoesWrap or false,
			TextXAlignment = Enum.TextXAlignment.Left;
			ZIndex = 5;
			Parent = Container;
		});

		if DoesWrap then
			local Y = select(2, Library:GetTextBounds(Text, Library.Font, 14, Vector2.new(TextLabel.AbsoluteSize.X, math.huge)))
			TextLabel.Size = UDim2.new(1, -4, 0, Y)
		else
			Library:Create('UIListLayout', {
				Padding = UDim.new(0, 4);
				FillDirection = Enum.FillDirection.Horizontal;
				HorizontalAlignment = Enum.HorizontalAlignment.Right;
				SortOrder = Enum.SortOrder.LayoutOrder;
				Parent = TextLabel;
			});
		end

		Label.TextLabel = TextLabel;
		Label.Container = Container;

		function Label:SetText(Text)
			TextLabel.Text = Text

			if DoesWrap then
				local Y = select(2, Library:GetTextBounds(Text, Library.Font, 14, Vector2.new(TextLabel.AbsoluteSize.X, math.huge)))
				TextLabel.Size = UDim2.new(1, -4, 0, Y)
			end

			Groupbox:Resize();
		end

		if (not DoesWrap) then
			setmetatable(Label, BaseAddons);
		end

		Groupbox:AddBlank(5);
		Groupbox:Resize();

		return Label;
	end;

	function Funcs:AddButton(...)
		local Button = {};
		local function ProcessButtonParams(Class, Obj, ...)
			local Props = select(1, ...)
			if type(Props) == 'table' then
				Obj.Text = Props.Text
				Obj.Func = Props.Func
				Obj.DoubleClick = Props.DoubleClick
				Obj.Tooltip = Props.Tooltip
			else
				Obj.Text = select(1, ...)
				Obj.Func = select(2, ...)
			end

			assert(type(Obj.Func) == 'function', 'AddButton: `Func` callback is missing.');
		end

		ProcessButtonParams('Button', Button, ...)

		local Groupbox = self;
		local Container = Groupbox.Container;

local function CreateBaseButton(Button)
			local Outer = Library:Create('Frame', {
				Active = true;
				BackgroundColor3 = Color3.new(0, 0, 0);
				BorderColor3 = Color3.new(0, 0, 0);
				Size = UDim2.new(1, -4, 0, 20);
				ZIndex = 5;
			});

			local Inner = Library:Create('Frame', {
				BackgroundColor3 = Library.MainColor;
				BorderColor3 = Library.OutlineColor;
				BorderMode = Enum.BorderMode.Inset;
				Size = UDim2.new(1, 0, 1, 0);
				ZIndex = 6;
				ClipsDescendants = true;
				Parent = Outer;
			});

			local Label = Library:CreateLabel({
				Size = UDim2.new(1, -4, 1, 0);
				Position = UDim2.new(0, 2, 0, 0);
				TextSize = 14;
				Text = Button.Text;
				TextTruncate = Enum.TextTruncate.AtEnd;
				ZIndex = 6;
				Parent = Inner;
			});

			Library:Create('UIGradient', {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
				});
				Rotation = 90;
				Parent = Inner;
			});

			Library:AddToRegistry(Outer, {
				BorderColor3 = 'Black';
			});

			Library:AddToRegistry(Inner, {
				BackgroundColor3 = 'MainColor';
				BorderColor3 = 'OutlineColor';
			});

			Library:OnHighlight(Outer, Outer,
				{ BorderColor3 = 'AccentColor' },
				{ BorderColor3 = 'Black' }
			);

			local _BtnScale = Instance.new('UIScale');
			_BtnScale.Scale  = 1;
			_BtnScale.Parent = Outer;

			return Outer, Inner, Label;
		end;

		local function InitEvents(Button)
			local function WaitForEvent(event, timeout, validator)
				local bindable = Instance.new('BindableEvent')
				local connection = event:Once(function(...)
					if type(validator) == 'function' and validator(...) then
						bindable:Fire(true)
					else
						bindable:Fire(false)
					end
				end)
				task.delay(timeout, function()
					connection:disconnect()
					bindable:Fire(false)
				end)
				return bindable.Event:Wait()
			end

			local function ValidateClick(Input)
				if Library:MouseIsOverOpenedFrame() then
					return false
				end
				if Input.UserInputType ~= Enum.UserInputType.MouseButton1 and Input.UserInputType ~= Enum.UserInputType.Touch then
					return false
				end
				return true
			end

			Button.Outer.InputBegan:Connect(function(Input)
				if not ValidateClick(Input) then return end
				if Button.Locked then return end

				local _sc = Button.Outer:FindFirstChildWhichIsA('UIScale');
				if _sc then
					TweenService:Create(_sc, TweenInfo.new(0.06, Enum.EasingStyle.Quad), { Scale = 0.95 }):Play();
					task.delay(0.08, function()
						TweenService:Create(_sc, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play();
					end);
				end;

				if Button.DoubleClick then
					Library:RemoveFromRegistry(Button.Label)
					Library:AddToRegistry(Button.Label, { TextColor3 = 'AccentColor' })
					Button.Label.TextColor3 = Library.AccentColor
					Button.Label.Text = 'Are you sure?'
					Button.Locked = true
					local clicked = WaitForEvent(Button.Outer.InputBegan, 0.5, ValidateClick)
					Library:RemoveFromRegistry(Button.Label)
					Library:AddToRegistry(Button.Label, { TextColor3 = 'FontColor' })
					Button.Label.TextColor3 = Library.FontColor
					Button.Label.Text = Button.Text
					task.defer(rawset, Button, 'Locked', false)
					if clicked then
						Library:SafeCallback(Button.Func)
					end
					return
				end

				Library:SafeCallback(Button.Func);
			end)

		end;

		Button.Outer, Button.Inner, Button.Label = CreateBaseButton(Button)
		Button.Outer.Parent = Container

		InitEvents(Button)

		function Button:AddTooltip(tooltip)
			if type(tooltip) == 'string' then
				Library:AddToolTip(tooltip, self.Outer)
			end
			return self
		end


		function Button:AddButton(...)
			local SubButton = {}

			ProcessButtonParams('SubButton', SubButton, ...)

			self.Outer.Size = UDim2.new(0.5, -2, 0, 20)

			SubButton.Outer, SubButton.Inner, SubButton.Label = CreateBaseButton(SubButton)

			SubButton.Outer.Position = UDim2.new(1, 3, 0, 0)
			SubButton.Outer.Size = UDim2.fromOffset(self.Outer.AbsoluteSize.X - 2, self.Outer.AbsoluteSize.Y)
			SubButton.Outer.Parent = self.Outer

			function SubButton:AddTooltip(tooltip)
				if type(tooltip) == 'string' then
					Library:AddToolTip(tooltip, self.Outer)
				end
				return SubButton
			end

			if type(SubButton.Tooltip) == 'string' then
				SubButton:AddTooltip(SubButton.Tooltip)
			end

			InitEvents(SubButton)
			return SubButton
		end

		if type(Button.Tooltip) == 'string' then
			Button:AddTooltip(Button.Tooltip)
		end

		Groupbox:AddBlank(5);
		Groupbox:Resize();

		return Button;
	end;

	-- ── AddRow: horizontal row with left-aligned text and right-aligned buttons ──
	-- Usage: Groupbox:AddRow({ Text = '9/11  ServerName', Buttons = {{ Text = 'Join', Func = fn }, { Text = 'Copy', Func = fn }} })
	-- Returns a Row object with :SetText(str), :SetVisible(bool), :SetButtons(btns)
	function Funcs:AddRow(Info)
		Info = Info or {};
		local Row = {};
		local Groupbox = self;
		local Container = self.Container;

		local ROW_HEIGHT = 22;
		local BTN_PAD = 3;

		-- Row frame (full width, fixed height)
		local RowFrame = Library:Create('Frame', {
			BackgroundTransparency = 1;
			Size = UDim2.new(1, -4, 0, ROW_HEIGHT);
			ZIndex = 5;
			Parent = Container;
		});

		-- Left text label
		local TextLabel = Library:CreateLabel({
			Position = UDim2.new(0, 0, 0, 0);
			Size = UDim2.new(1, 0, 1, 0);
			TextSize = 13;
			Text = Info.Text or '';
			TextXAlignment = Enum.TextXAlignment.Left;
			TextTruncate = Enum.TextTruncate.AtEnd;
			ZIndex = 6;
			Parent = RowFrame;
		});

		-- Container for right-side buttons
		local BtnContainer = Library:Create('Frame', {
			BackgroundTransparency = 1;
			AnchorPoint = Vector2.new(1, 0);
			Position = UDim2.new(1, 0, 0, 0);
			Size = UDim2.new(0, 0, 1, 0);
			ZIndex = 6;
			Parent = RowFrame;
		});
		Library:Create('UIListLayout', {
			FillDirection = Enum.FillDirection.Horizontal;
			HorizontalAlignment = Enum.HorizontalAlignment.Right;
			VerticalAlignment = Enum.VerticalAlignment.Center;
			Padding = UDim.new(0, BTN_PAD);
			SortOrder = Enum.SortOrder.LayoutOrder;
			Parent = BtnContainer;
		});

		local _rowBtns = {};

		local function CreateRowButton(BtnInfo, order)
			local btnText = BtnInfo.Text or 'Btn';
			-- Measure text width for snug button
			local textWidth = 30;
			pcall(function()
				textWidth = select(1, Library:GetTextBounds(btnText, Library.Font, 12, Vector2.new(200, ROW_HEIGHT)));
			end);
			local btnWidth = math.max(textWidth + 12, 36);

			local Outer = Library:Create('Frame', {
				Active = true;
				BackgroundColor3 = Color3.new(0, 0, 0);
				BorderColor3 = Color3.new(0, 0, 0);
				Size = UDim2.new(0, btnWidth, 0, ROW_HEIGHT - 4);
				LayoutOrder = order or 0;
				ZIndex = 7;
				Parent = BtnContainer;
			});

			local Inner = Library:Create('Frame', {
				BackgroundColor3 = Library.MainColor;
				BorderColor3 = Library.OutlineColor;
				BorderMode = Enum.BorderMode.Inset;
				Size = UDim2.new(1, 0, 1, 0);
				ZIndex = 8;
				Parent = Outer;
			});

			local Label = Library:CreateLabel({
				Size = UDim2.new(1, 0, 1, 0);
				TextSize = 12;
				Text = btnText;
				ZIndex = 8;
				Parent = Inner;
			});

			Library:Create('UIGradient', {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
				});
				Rotation = 90;
				Parent = Inner;
			});

			Library:AddToRegistry(Outer, { BorderColor3 = 'Black' });
			Library:AddToRegistry(Inner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor' });
			Library:OnHighlight(Outer, Outer, { BorderColor3 = 'AccentColor' }, { BorderColor3 = 'Black' });

			Outer.InputBegan:Connect(function(Input)
				if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
					if BtnInfo.Func then
						Library:SafeCallback(BtnInfo.Func);
					end;
				end;
			end);

			table.insert(_rowBtns, { Outer = Outer; Inner = Inner; Label = Label; Info = BtnInfo });
			return Outer;
		end

		-- Build initial buttons
		if Info.Buttons then
			local totalWidth = 0;
			for i, btnInfo in ipairs(Info.Buttons) do
				local btn = CreateRowButton(btnInfo, i);
				totalWidth = totalWidth + btn.Size.X.Offset + BTN_PAD;
			end
			BtnContainer.Size = UDim2.new(0, totalWidth, 1, 0);
			TextLabel.Size = UDim2.new(1, -(totalWidth + 4), 1, 0);
		end

		function Row:SetText(text)
			TextLabel.Text = text;
		end

		function Row:SetVisible(vis)
			RowFrame.Visible = vis;
			Groupbox:Resize();
		end

		function Row:GetFrame()
			return RowFrame;
		end

		Row.TextLabel = TextLabel;
		Row.Frame = RowFrame;

		Groupbox:AddBlank(3);
		Groupbox:Resize();
		return Row;
	end

	function Funcs:AddCard(Info)
		Info = Info or {};
		local Card = {};
		local Groupbox = self;
		local Container = self.Container;

		local CARD_HEIGHT = Info.Height or 52;
		local CARD_PAD = 6;

		-- Card outer frame (rounded, with UIStroke)
		local CardFrame = Library:Create('Frame', {
			BackgroundColor3 = Library.BackgroundColor;
			BorderSizePixel = 0;
			Size = UDim2.new(1, -4, 0, CARD_HEIGHT);
			ZIndex = 5;
			Parent = Container;
		});
		Library:Create('UICorner', { CornerRadius = UDim.new(0, 6); Parent = CardFrame; });
		Library:Create('UIStroke', {
			Color = Library.OutlineColor;
			Thickness = 1;
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border;
			Parent = CardFrame;
		});
		Library:AddToRegistry(CardFrame, { BackgroundColor3 = 'BackgroundColor' });

		-- Top-left badge/tag (e.g. "Normal", "XL", "VC")
		local BadgeFrame = Library:Create('Frame', {
			BackgroundColor3 = Library.AccentColor;
			BorderSizePixel = 0;
			Position = UDim2.new(0, CARD_PAD, 0, CARD_PAD);
			Size = UDim2.fromOffset(48, 16);
			ZIndex = 7;
			Parent = CardFrame;
		});
		Library:Create('UICorner', { CornerRadius = UDim.new(0, 4); Parent = BadgeFrame; });
		Library:AddToRegistry(BadgeFrame, { BackgroundColor3 = 'AccentColor' });

		local BadgeLabel = Library:Create('TextLabel', {
			BackgroundTransparency = 1;
			Size = UDim2.new(1, 0, 1, 0);
			Font = Library.Font;
			Text = Info.Badge or '';
			TextColor3 = Library.FontColor;
			TextSize = 11;
			ZIndex = 8;
			Parent = BadgeFrame;
		});
		Library:AddToRegistry(BadgeLabel, { TextColor3 = 'FontColor' });

		-- Auto-size badge to text
		pcall(function()
			local tw = select(1, Library:GetTextBounds(BadgeLabel.Text, Library.Font, 11, Vector2.new(200, 16)));
			BadgeFrame.Size = UDim2.fromOffset(math.max(tw + 10, 28), 16);
		end);

		-- Subtitle under badge (e.g. uptime)
		local SubLabel = Library:CreateLabel({
			Position = UDim2.new(0, CARD_PAD, 0, CARD_PAD + 18);
			Size = UDim2.new(0, 80, 0, 14);
			TextSize = 11;
			Text = Info.Subtitle or '';
			TextXAlignment = Enum.TextXAlignment.Left;
			TextColor3 = Color3.fromRGB(170, 170, 170);
			ZIndex = 7;
			Parent = CardFrame;
		});

		-- Left middle area: player count text
		local CountLabel = Library:CreateLabel({
			Position = UDim2.new(0, CARD_PAD, 0, CARD_PAD + 32);
			Size = UDim2.new(0, 50, 0, 14);
			TextSize = 13;
			Text = Info.LeftText or '';
			TextXAlignment = Enum.TextXAlignment.Left;
			ZIndex = 7;
			Parent = CardFrame;
		});

		-- Thumbnail container (for player avatars)
		local ThumbContainer = Library:Create('Frame', {
			BackgroundTransparency = 1;
			Position = UDim2.new(0, CARD_PAD + 48, 0, CARD_PAD + 30);
			Size = UDim2.fromOffset(60, 18);
			ZIndex = 7;
			Parent = CardFrame;
		});
		Library:Create('UIListLayout', {
			FillDirection = Enum.FillDirection.Horizontal;
			Padding = UDim.new(0, -4);
			VerticalAlignment = Enum.VerticalAlignment.Center;
			SortOrder = Enum.SortOrder.LayoutOrder;
			Parent = ThumbContainer;
		});

		local _thumbImages = {};
		for idx = 1, 3 do
			local img = Library:Create('ImageLabel', {
				BackgroundColor3 = Color3.fromRGB(40, 40, 40);
				BorderSizePixel = 0;
				Size = UDim2.fromOffset(18, 18);
				Image = '';
				Visible = false;
				LayoutOrder = idx;
				ZIndex = 8 + (3 - idx);
				Parent = ThumbContainer;
			});
			Library:Create('UICorner', { CornerRadius = UDim.new(1, 0); Parent = img; });
			Library:Create('UIStroke', {
				Color = Library.BackgroundColor;
				Thickness = 1.5;
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border;
				Parent = img;
			});
			_thumbImages[idx] = img;
		end

		-- Right-side action button
		local btnText = (Info.Button and Info.Button.Text) or 'Join';
		local btnColor = (Info.Button and Info.Button.Color) or Color3.fromRGB(46, 160, 67);
		local btnHover = (Info.Button and Info.Button.HoverColor) or Color3.fromRGB(56, 185, 80);

		local btnWidth = 52;
		pcall(function()
			local tw = select(1, Library:GetTextBounds(btnText, Library.Font, 13, Vector2.new(200, 30)));
			btnWidth = math.max(tw + 16, 48);
		end);

		local BtnFrame = Library:Create('Frame', {
			Active = true;
			AnchorPoint = Vector2.new(1, 0.5);
			BackgroundColor3 = btnColor;
			BorderSizePixel = 0;
			Position = UDim2.new(1, -CARD_PAD, 0.5, 0);
			Size = UDim2.fromOffset(btnWidth, CARD_HEIGHT - 16);
			ZIndex = 7;
			Parent = CardFrame;
		});
		Library:Create('UICorner', { CornerRadius = UDim.new(0, 5); Parent = BtnFrame; });

		local BtnLabel = Library:Create('TextLabel', {
			BackgroundTransparency = 1;
			Size = UDim2.new(1, 0, 1, 0);
			Font = Library.Font;
			Text = btnText;
			TextColor3 = Color3.new(1, 1, 1);
			TextSize = 13;
			ZIndex = 8;
			Parent = BtnFrame;
		});

		BtnFrame.MouseEnter:Connect(function()
			TweenService:Create(BtnFrame, TweenInfo.new(0.12), { BackgroundColor3 = btnHover }):Play();
		end);
		BtnFrame.MouseLeave:Connect(function()
			TweenService:Create(BtnFrame, TweenInfo.new(0.12), { BackgroundColor3 = btnColor }):Play();
		end);
		BtnFrame.InputBegan:Connect(function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
				if Info.Button and Info.Button.Func then
					Library:SafeCallback(Info.Button.Func);
				end;
			end;
		end);

		-- API
		function Card:SetBadge(text)
			BadgeLabel.Text = text;
			pcall(function()
				local tw = select(1, Library:GetTextBounds(text, Library.Font, 11, Vector2.new(200, 16)));
				BadgeFrame.Size = UDim2.fromOffset(math.max(tw + 10, 28), 16);
			end);
		end

		function Card:SetBadgeColor(color)
			BadgeFrame.BackgroundColor3 = color;
		end

		function Card:SetSubtitle(text)
			SubLabel.Text = text;
		end

		function Card:SetLeftText(text)
			CountLabel.Text = text;
		end

		function Card:SetThumbnails(urls)
			for i = 1, 3 do
				if urls and urls[i] and urls[i] ~= '' then
					_thumbImages[i].Image = urls[i];
					_thumbImages[i].Visible = true;
				else
					_thumbImages[i].Image = '';
					_thumbImages[i].Visible = false;
				end
			end
		end

		function Card:SetButtonFunc(func)
			Info.Button = Info.Button or {};
			Info.Button.Func = func;
		end

		function Card:SetVisible(vis)
			CardFrame.Visible = vis;
			Groupbox:Resize();
		end

		function Card:GetFrame()
			return CardFrame;
		end

		Card.Frame = CardFrame;
		Card.BadgeLabel = BadgeLabel;
		Card.BadgeFrame = BadgeFrame;
		Card.SubLabel = SubLabel;
		Card.CountLabel = CountLabel;
		Card.BtnFrame = BtnFrame;
		Card.BtnLabel = BtnLabel;

		Groupbox:AddBlank(3);
		Groupbox:Resize();
		return Card;
	end

	function Funcs:AddDivider()
		local Groupbox = self;
		local Container = self.Container

		local Divider = {
			Type = 'Divider',
		}

		Groupbox:AddBlank(2);
		local DividerOuter = Library:Create('Frame', {
			BackgroundColor3 = Color3.new(0, 0, 0);
			BorderColor3 = Color3.new(0, 0, 0);
			Size = UDim2.new(1, -4, 0, 5);
			ZIndex = 5;
			Parent = Container;
		});

		local DividerInner = Library:Create('Frame', {
			BackgroundColor3 = Library.MainColor;
			BorderColor3 = Library.OutlineColor;
			BorderMode = Enum.BorderMode.Inset;
			Size = UDim2.new(1, 0, 1, 0);
			ZIndex = 6;
			Parent = DividerOuter;
		});

		Library:AddToRegistry(DividerOuter, {
			BorderColor3 = 'Black';
		});

		Library:AddToRegistry(DividerInner, {
			BackgroundColor3 = 'MainColor';
			BorderColor3 = 'OutlineColor';
		});

		Groupbox:AddBlank(9);
		Groupbox:Resize();
	end

	function Funcs:AddInput(Idx, Info)
		assert(Info.Text, 'AddInput: Missing `Text` string.')

		local Textbox = {
			Value = Info.Default or '';
			Numeric = Info.Numeric or false;
			Finished = Info.Finished or false;
			Type = 'Input';
			Callback = Info.Callback or function(Value) end;
		};

		local Groupbox = self;
		local Container = Groupbox.Container;

		local InputLabel = Library:CreateLabel({
			Size = UDim2.new(1, 0, 0, 15);
			TextSize = 14;
			Text = Info.Text;
			TextXAlignment = Enum.TextXAlignment.Left;
			ZIndex = 5;
			Parent = Container;
		});

		Groupbox:AddBlank(1);

		local TextBoxOuter = Library:Create('Frame', {
			BackgroundColor3 = Color3.new(0, 0, 0);
			BorderColor3 = Color3.new(0, 0, 0);
			Size = UDim2.new(1, -4, 0, 20);
			ZIndex = 5;
			Parent = Container;
		});

		local TextBoxInner = Library:Create('Frame', {
			BackgroundColor3 = Library.MainColor;
			BorderColor3 = Library.OutlineColor;
			BorderMode = Enum.BorderMode.Inset;
			Size = UDim2.new(1, 0, 1, 0);
			ZIndex = 6;
			Parent = TextBoxOuter;
		});

		Library:AddToRegistry(TextBoxInner, {
			BackgroundColor3 = 'MainColor';
			BorderColor3 = 'OutlineColor';
		});

		Library:OnHighlight(TextBoxOuter, TextBoxOuter,
			{ BorderColor3 = 'AccentColor' },
			{ BorderColor3 = 'Black' }
		);

		if type(Info.Tooltip) == 'string' then
			Library:AddToolTip(Info.Tooltip, TextBoxOuter)
		end

		Library:Create('UIGradient', {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
			});
			Rotation = 90;
			Parent = TextBoxInner;
		});

		local Container = Library:Create('Frame', {
			BackgroundTransparency = 1;
			ClipsDescendants = true;

			Position = UDim2.new(0, 5, 0, 0);
			Size = UDim2.new(1, -5, 1, 0);

			ZIndex = 7;
			Parent = TextBoxInner;
		})

		local Box = Library:Create('TextBox', {
			BackgroundTransparency = 1;

			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.fromScale(5, 1),

			Font = Library.Font;
			PlaceholderColor3 = Color3.fromRGB(190, 190, 190);
			PlaceholderText = Info.Placeholder or '';

			Text = Info.Default or '';
			TextColor3 = Library.FontColor;
			TextSize = 14;
			TextStrokeTransparency = 0;
			TextXAlignment = Enum.TextXAlignment.Left;

			ZIndex = 7;
			Parent = Container;
		});

		Library:ApplyTextStroke(Box);

		function Textbox:SetValue(Text)
			if Info.MaxLength and #Text > Info.MaxLength then
				Text = Text:sub(1, Info.MaxLength);
			end;

			if Textbox.Numeric then
				if (not tonumber(Text)) and Text:len() > 0 then
					Text = Textbox.Value
				end
			end

			Textbox.Value = Text;
			Box.Text = Text;

			Library:SafeCallback(Textbox.Callback, Textbox.Value);
			Library:SafeCallback(Textbox.Changed, Textbox.Value);
		end;

		if Textbox.Finished then
			Box.FocusLost:Connect(function(enter)
				if not enter then return end

				Textbox:SetValue(Box.Text);
				Library:AttemptSave();
			end)
		else
			Box:GetPropertyChangedSignal('Text'):Connect(function()
				Textbox:SetValue(Box.Text);
				Library:AttemptSave();
			end);
		end

		local function Update()
			local PADDING = 2
			local reveal = Container.AbsoluteSize.X

			if not Box:IsFocused() or Box.TextBounds.X <= reveal - 2 * PADDING then
				Box.Position = UDim2.new(0, PADDING, 0, 0)
			else
				local cursor = Box.CursorPosition
				if cursor ~= -1 then
					local subtext = string.sub(Box.Text, 1, cursor-1)
					local width = TextService:GetTextSize(subtext, Box.TextSize, Box.Font, Vector2.new(math.huge, math.huge)).X

					local currentCursorPos = Box.Position.X.Offset + width

					if currentCursorPos < PADDING then
						Box.Position = UDim2.fromOffset(PADDING-width, 0)
					elseif currentCursorPos > reveal - PADDING - 1 then
						Box.Position = UDim2.fromOffset(reveal-width-PADDING-1, 0)
					end
				end
			end
		end

		task.spawn(Update)

		Box:GetPropertyChangedSignal('Text'):Connect(Update)
		Box:GetPropertyChangedSignal('CursorPosition'):Connect(Update)
		Box.FocusLost:Connect(Update)
		Box.Focused:Connect(Update)

		Library:AddToRegistry(Box, {
			TextColor3 = 'FontColor';
		});

		function Textbox:OnChanged(Func)
			Textbox.Changed = Func;
			Func(Textbox.Value);
		end;

		Groupbox:AddBlank(5);
		Groupbox:Resize();

		Options[Idx] = Textbox;

		return Textbox;
	end;

	function Funcs:AddToggle(Idx, Info)
		assert(Info.Text, 'AddInput: Missing `Text` string.')

		local Toggle = {
			Value = Info.Default or false;
			Type = 'Toggle';

			Callback = Info.Callback or function(Value) end;
			Addons = {},
			Risky = Info.Risky,
		};

		local Groupbox = self;
		local Container = Groupbox.Container;

		local ToggleOuter = Library:Create('Frame', {
			BackgroundColor3 = Color3.new(0, 0, 0);
			BorderColor3 = Color3.new(0, 0, 0);
			Size = UDim2.new(0, 13, 0, 13);
			ZIndex = 5;
			Parent = Container;
		});

		Library:AddToRegistry(ToggleOuter, {
			BorderColor3 = 'Black';
		});

		local ToggleInner = Library:Create('Frame', {
			BackgroundColor3 = Library.MainColor;
			BorderColor3 = Library.OutlineColor;
			BorderMode = Enum.BorderMode.Inset;
			Size = UDim2.new(1, 0, 1, 0);
			ZIndex = 6;
			Parent = ToggleOuter;
		});

		Library:AddToRegistry(ToggleInner, {
			BackgroundColor3 = 'MainColor';
			BorderColor3 = 'OutlineColor';
		});

		local ToggleLabel = Library:CreateLabel({
			Size = UDim2.new(0, 216, 1, 0);
			Position = UDim2.new(1, 6, 0, 0);
			TextSize = 14;
			Text = Info.Text;
			TextXAlignment = Enum.TextXAlignment.Left;
			TextTruncate = Enum.TextTruncate.AtEnd;
			ClipsDescendants = true;
			ZIndex = 6;
			Parent = ToggleInner;
		});

		Library:Create('UIListLayout', {
			Padding = UDim.new(0, 4);
			FillDirection = Enum.FillDirection.Horizontal;
			HorizontalAlignment = Enum.HorizontalAlignment.Right;
			SortOrder = Enum.SortOrder.LayoutOrder;
			Parent = ToggleLabel;
		});

		local ToggleRegion = Library:Create('Frame', {
			Active = true;
			BackgroundTransparency = 1;
			Size = UDim2.new(0, 170, 1, 0);
			ZIndex = 8;
			Parent = ToggleOuter;
		});

		Library:OnHighlight(ToggleRegion, ToggleOuter,
			{ BorderColor3 = 'AccentColor' },
			{ BorderColor3 = 'Black' }
		);

		function Toggle:UpdateColors()
			Toggle:Display();
		end;

		if type(Info.Tooltip) == 'string' then
			Library:AddToolTip(Info.Tooltip, ToggleRegion)
		end

function Toggle:Display()
	local targetBG     = Toggle.Value and Library.AccentColor     or Library.MainColor;
	local targetBorder = Toggle.Value and Library.AccentColorDark  or Library.OutlineColor;

	TweenService:Create(ToggleInner, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundColor3 = targetBG;
	}):Play();

	ToggleInner.BorderColor3 = targetBorder;
	Library.RegistryMap[ToggleInner].Properties.BackgroundColor3 = Toggle.Value and 'AccentColor' or 'MainColor';
	Library.RegistryMap[ToggleInner].Properties.BorderColor3     = Toggle.Value and 'AccentColorDark' or 'OutlineColor';
end;

		function Toggle:OnChanged(Func)
			Toggle.Changed = Func;
			Func(Toggle.Value);
		end;

		function Toggle:SetValue(Bool)
			Bool = (not not Bool);

			Toggle.Value = Bool;
			Toggle:Display();

			for _, Addon in next, Toggle.Addons do
				if Addon.Type == 'KeyPicker' and Addon.SyncToggleState then
					Addon.Toggled = Bool
					Addon:Update()
				end
			end

			Library:SafeCallback(Toggle.Callback, Toggle.Value);
			Library:SafeCallback(Toggle.Changed, Toggle.Value);
			Library:UpdateDependencyBoxes();
		end;

local _ToggleClickSfx = Instance.new('Sound');
_ToggleClickSfx.SoundId            = 'rbxassetid://6895079853';
_ToggleClickSfx.Volume             = 0.18;
_ToggleClickSfx.RollOffMaxDistance = 0;
_ToggleClickSfx.Parent             = ToggleOuter;

ToggleRegion.InputBegan:Connect(function(Input)
	if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) and not Library:MouseIsOverOpenedFrame() then
		pcall(function() _ToggleClickSfx:Play() end);
		-- Tiny bounce on the toggle box
		local _ts = Instance.new('UIScale'); _ts.Scale = 1; _ts.Parent = ToggleOuter;
		TweenService:Create(_ts, TweenInfo.new(0.07, Enum.EasingStyle.Quad), { Scale = 0.88 }):Play();
		task.delay(0.07, function()
			TweenService:Create(_ts, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play();
			task.delay(0.2, function() _ts:Destroy() end);
		end);
		Toggle:SetValue(not Toggle.Value);
		Library:AttemptSave();
	end;
end);

		if Toggle.Risky then
			Library:RemoveFromRegistry(ToggleLabel)
			ToggleLabel.TextColor3 = Library.RiskColor
			Library:AddToRegistry(ToggleLabel, { TextColor3 = 'RiskColor' })
		end

		Toggle:Display();
		Groupbox:AddBlank(Info.BlankSize or 5 + 2);
		Groupbox:Resize();

		Toggle.TextLabel = ToggleLabel;
		Toggle.Container = Container;
		setmetatable(Toggle, BaseAddons);

		Toggles[Idx] = Toggle;

		Library:UpdateDependencyBoxes();

		return Toggle;
	end;

	function Funcs:AddSlider(Idx, Info)
		assert(Info.Default, 'AddSlider: Missing default value.');
		assert(Info.Text, 'AddSlider: Missing slider text.');
		assert(Info.Min, 'AddSlider: Missing minimum value.');
		assert(Info.Max, 'AddSlider: Missing maximum value.');
		assert(Info.Rounding, 'AddSlider: Missing rounding value.');

		local Slider = {
			Value = Info.Default;
			Min = Info.Min;
			Max = Info.Max;
			Rounding = Info.Rounding;
			MaxSize = 232;
			Type = 'Slider';
			Callback = Info.Callback or function(Value) end;
		};

		local Groupbox = self;
		local Container = Groupbox.Container;

		if not Info.Compact then
			Library:CreateLabel({
				Size = UDim2.new(1, 0, 0, 10);
				TextSize = 14;
				Text = Info.Text;
				TextXAlignment = Enum.TextXAlignment.Left;
				TextYAlignment = Enum.TextYAlignment.Bottom;
				ZIndex = 5;
				Parent = Container;
			});

			Groupbox:AddBlank(3);
		end

		local SliderOuter = Library:Create('Frame', {
			BackgroundColor3 = Color3.new(0, 0, 0);
			BorderColor3 = Color3.new(0, 0, 0);
			Size = UDim2.new(1, -4, 0, 13);
			ZIndex = 5;
			Parent = Container;
		});

		Library:AddToRegistry(SliderOuter, {
			BorderColor3 = 'Black';
		});

		local SliderInner = Library:Create('Frame', {
			BackgroundColor3 = Library.MainColor;
			BorderColor3 = Library.OutlineColor;
			BorderMode = Enum.BorderMode.Inset;
			Size = UDim2.new(1, 0, 1, 0);
			ZIndex = 6;
			Parent = SliderOuter;
		});

Library:AddToRegistry(SliderInner, {
	BackgroundColor3 = 'MainColor';
	BorderColor3 = 'OutlineColor';
});

-- Dynamically recalculate MaxSize so fill always reaches the far edge correctly
local function _UpdateSliderMax()
	local w = SliderInner.AbsoluteSize.X;
	if w > 0 then
		Slider.MaxSize = w;
		Slider:Display();
	end;
end;
SliderInner:GetPropertyChangedSignal('AbsoluteSize'):Connect(_UpdateSliderMax);
task.spawn(function() task.wait(); _UpdateSliderMax(); end);

		local Fill = Library:Create('Frame', {
			BackgroundColor3 = Library.AccentColor;
			BorderColor3 = Library.AccentColorDark;
			Size = UDim2.new(0, 0, 1, 0);
			ZIndex = 7;
			Parent = SliderInner;
		});

		Library:AddToRegistry(Fill, {
			BackgroundColor3 = 'AccentColor';
			BorderColor3 = 'AccentColorDark';
		});

		local HideBorderRight = Library:Create('Frame', {
			BackgroundColor3 = Library.AccentColor;
			BorderSizePixel = 0;
			Position = UDim2.new(1, 0, 0, 0);
			Size = UDim2.new(0, 1, 1, 0);
			ZIndex = 8;
			Parent = Fill;
		});

		Library:AddToRegistry(HideBorderRight, {
			BackgroundColor3 = 'AccentColor';
		});

		local DisplayLabel = Library:CreateLabel({
			Size = UDim2.new(1, 0, 1, 0);
			TextSize = 14;
			Text = 'Infinite';
			ZIndex = 9;
			Parent = SliderInner;
		});

		Library:OnHighlight(SliderOuter, SliderOuter,
			{ BorderColor3 = 'AccentColor' },
			{ BorderColor3 = 'Black' }
		);

		if type(Info.Tooltip) == 'string' then
			Library:AddToolTip(Info.Tooltip, SliderOuter)
		end

		function Slider:UpdateColors()
			Fill.BackgroundColor3 = Library.AccentColor;
			Fill.BorderColor3 = Library.AccentColorDark;
		end;

		function Slider:Display()
			local Suffix = Info.Suffix or '';

			if Info.Compact then
				DisplayLabel.Text = Info.Text .. ': ' .. Slider.Value .. Suffix
			elseif Info.HideMax then
				DisplayLabel.Text = string.format('%s', Slider.Value .. Suffix)
			else
				DisplayLabel.Text = string.format('%s/%s', Slider.Value .. Suffix, Slider.Max .. Suffix);
			end

			local X = math.ceil(Library:MapValue(Slider.Value, Slider.Min, Slider.Max, 0, Slider.MaxSize));
			Fill.Size = UDim2.new(0, X, 1, 0);

			HideBorderRight.Visible = not (X == Slider.MaxSize or X == 0);
		end;

		function Slider:OnChanged(Func)
			Slider.Changed = Func;
			Func(Slider.Value);
		end;

		local function Round(Value)
			if Slider.Rounding == 0 then
				return math.floor(Value);
			end;


			return tonumber(string.format('%.' .. Slider.Rounding .. 'f', Value))
		end;

		function Slider:GetValueFromXOffset(X)
			return Round(Library:MapValue(X, 0, Slider.MaxSize, Slider.Min, Slider.Max));
		end;

		function Slider:SetValue(Str)
			local Num = tonumber(Str);

			if (not Num) then
				return;
			end;

			Num = math.clamp(Num, Slider.Min, Slider.Max);

			Slider.Value = Num;
			Slider:Display();

			Library:SafeCallback(Slider.Callback, Slider.Value);
			Library:SafeCallback(Slider.Changed, Slider.Value);
		end;

		SliderInner.InputBegan:Connect(function(Input)
			if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) and not Library:MouseIsOverOpenedFrame() then
				local mPos = Input.Position.X;
				local gPos = Fill.Size.X.Offset;
				local Diff = mPos - (Fill.AbsolutePosition.X + gPos);
				local lastX = mPos;

				local dragging = true;

				local moveConn = InputService.InputChanged:Connect(function(changed)
					if changed.UserInputType == Enum.UserInputType.MouseMovement or changed.UserInputType == Enum.UserInputType.Touch then
						lastX = changed.Position.X;
					end;
				end);

				local endConn = InputService.InputEnded:Connect(function(endInput)
					if endInput == Input then
						dragging = false;
					end;
				end);

				while dragging do
					local nX = math.clamp(gPos + (lastX - mPos) + Diff, 0, Slider.MaxSize);

					local nValue = Slider:GetValueFromXOffset(nX);
					local OldValue = Slider.Value;
					Slider.Value = nValue;

					Slider:Display();

					if nValue ~= OldValue then
						Library:SafeCallback(Slider.Callback, Slider.Value);
						Library:SafeCallback(Slider.Changed, Slider.Value);
					end;

					RenderStepped:Wait();
				end;

				moveConn:Disconnect();
				endConn:Disconnect();

				Library:AttemptSave();
			end;
		end);

		Slider:Display();
		Groupbox:AddBlank(Info.BlankSize or 6);
		Groupbox:Resize();

		Options[Idx] = Slider;

		return Slider;
	end;

	function Funcs:AddDropdown(Idx, Info)
		if Info.SpecialType == 'Player' then
			Info.Values = GetPlayersString();
			Info.AllowNull = true;
		elseif Info.SpecialType == 'Team' then
			Info.Values = GetTeamsString();
			Info.AllowNull = true;
		end;

		assert(Info.Values, 'AddDropdown: Missing dropdown value list.');
		assert(Info.AllowNull or Info.Default, 'AddDropdown: Missing default value. Pass `AllowNull` as true if this was intentional.')

		if (not Info.Text) then
			Info.Compact = true;
		end;

		local Dropdown = {
			Values = Info.Values;
			Value = Info.Multi and {};
			Multi = Info.Multi;
			Type = 'Dropdown';
			SpecialType = Info.SpecialType;
			Callback = Info.Callback or function(Value) end;
		};

		local Groupbox = self;
		local Container = Groupbox.Container;

		local RelativeOffset = 0;

		if not Info.Compact then
			local DropdownLabel = Library:CreateLabel({
				Size = UDim2.new(1, 0, 0, 10);
				TextSize = 14;
				Text = Info.Text;
				TextXAlignment = Enum.TextXAlignment.Left;
				TextYAlignment = Enum.TextYAlignment.Bottom;
				ZIndex = 5;
				Parent = Container;
			});

			Groupbox:AddBlank(3);
		end

		for _, Element in next, Container:GetChildren() do
			if not Element:IsA('UIListLayout') then
				RelativeOffset = RelativeOffset + Element.Size.Y.Offset;
			end;
		end;

		local DropdownOuter = Library:Create('Frame', {
			Active = true;
			BackgroundColor3 = Color3.new(0, 0, 0);
			BorderColor3 = Color3.new(0, 0, 0);
			Size = UDim2.new(1, -4, 0, 20);
			ZIndex = 5;
			Parent = Container;
		});

		Library:AddToRegistry(DropdownOuter, {
			BorderColor3 = 'Black';
		});

		local DropdownInner = Library:Create('Frame', {
			BackgroundColor3 = Library.MainColor;
			BorderColor3 = Library.OutlineColor;
			BorderMode = Enum.BorderMode.Inset;
			Size = UDim2.new(1, 0, 1, 0);
			ZIndex = 6;
			Parent = DropdownOuter;
		});

		Library:AddToRegistry(DropdownInner, {
			BackgroundColor3 = 'MainColor';
			BorderColor3 = 'OutlineColor';
		});

		Library:Create('UIGradient', {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
			});
			Rotation = 90;
			Parent = DropdownInner;
		});

		local DropdownArrow = Library:Create('ImageLabel', {
			AnchorPoint = Vector2.new(0, 0.5);
			BackgroundTransparency = 1;
			Position = UDim2.new(1, -16, 0.5, 0);
			Size = UDim2.new(0, 12, 0, 12);
			Image = 'http://www.roblox.com/asset/?id=6282522798';
			ZIndex = 8;
			Parent = DropdownInner;
		});

		local ItemList = Library:CreateLabel({
			Position = UDim2.new(0, 5, 0, 0);
			Size = UDim2.new(1, -5, 1, 0);
			TextSize = 14;
			Text = '--';
			TextXAlignment = Enum.TextXAlignment.Left;
			TextWrapped = true;
			ZIndex = 7;
			Parent = DropdownInner;
		});

		Library:OnHighlight(DropdownOuter, DropdownOuter,
			{ BorderColor3 = 'AccentColor' },
			{ BorderColor3 = 'Black' }
		);

		if type(Info.Tooltip) == 'string' then
			Library:AddToolTip(Info.Tooltip, DropdownOuter)
		end

		local MAX_DROPDOWN_ITEMS = 8;

		local ListOuter = Library:Create('Frame', {
			BackgroundColor3 = Color3.new(0, 0, 0);
			BorderColor3 = Color3.new(0, 0, 0);
			ZIndex = 20;
			Visible = false;
			Parent = ScreenGui;
		});

		local function RecalculateListPosition()
			ListOuter.Position = UDim2.fromOffset(DropdownOuter.AbsolutePosition.X, DropdownOuter.AbsolutePosition.Y + DropdownOuter.Size.Y.Offset + 1);
		end;

		local function RecalculateListSize(YSize)
			ListOuter.Size = UDim2.fromOffset(DropdownOuter.AbsoluteSize.X, YSize or (MAX_DROPDOWN_ITEMS * 20 + 2))
		end;

		RecalculateListPosition();
		RecalculateListSize();

		DropdownOuter:GetPropertyChangedSignal('AbsolutePosition'):Connect(RecalculateListPosition);

		local ListInner = Library:Create('Frame', {
			BackgroundColor3 = Library.MainColor;
			BorderColor3 = Library.OutlineColor;
			BorderMode = Enum.BorderMode.Inset;
			BorderSizePixel = 0;
			Size = UDim2.new(1, 0, 1, 0);
			ZIndex = 21;
			Parent = ListOuter;
		});

		Library:AddToRegistry(ListInner, {
			BackgroundColor3 = 'MainColor';
			BorderColor3 = 'OutlineColor';
		});

		local Scrolling = Library:Create('ScrollingFrame', {
			BackgroundTransparency = 1;
			BorderSizePixel = 0;
			CanvasSize = UDim2.new(0, 0, 0, 0);
			Size = UDim2.new(1, 0, 1, 0);
			ZIndex = 21;
			Parent = ListInner;

			TopImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png',
			BottomImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png',

			ScrollBarThickness = 3,
			ScrollBarImageColor3 = Library.AccentColor,
		});

		Library:AddToRegistry(Scrolling, {
			ScrollBarImageColor3 = 'AccentColor'
		})

		Library:Create('UIListLayout', {
			Padding = UDim.new(0, 0);
			FillDirection = Enum.FillDirection.Vertical;
			SortOrder = Enum.SortOrder.LayoutOrder;
			Parent = Scrolling;
		});

		function Dropdown:Display()
			local Values = Dropdown.Values;
			local Str = '';

			if Info.Multi then
				for Idx, Value in next, Values do
					if Dropdown.Value[Value] then
						Str = Str .. Value .. ', ';
					end;
				end;

				Str = Str:sub(1, #Str - 2);
			else
				Str = Dropdown.Value or '';
			end;

			ItemList.Text = (Str == '' and '--' or Str);
		end;

		function Dropdown:GetActiveValues()
			if Info.Multi then
				local T = {};

				for Value, Bool in next, Dropdown.Value do
					table.insert(T, Value);
				end;

				return T;
			else
				return Dropdown.Value and 1 or 0;
			end;
		end;

		function Dropdown:BuildDropdownList()
			local Values = Dropdown.Values;
			local Buttons = {};

			for _, Element in next, Scrolling:GetChildren() do
				if not Element:IsA('UIListLayout') then
					Element:Destroy();
				end;
			end;

			local Count = 0;

			for Idx, Value in next, Values do
				local Table = {};

				Count = Count + 1;

				local Button = Library:Create('Frame', {
					BackgroundColor3 = Library.MainColor;
					BorderColor3 = Library.OutlineColor;
					BorderMode = Enum.BorderMode.Middle;
					Size = UDim2.new(1, -1, 0, 20);
					ZIndex = 23;
					Active = true,
					Parent = Scrolling;
				});

				Library:AddToRegistry(Button, {
					BackgroundColor3 = 'MainColor';
					BorderColor3 = 'OutlineColor';
				});

				local ButtonLabel = Library:CreateLabel({
					Active = true;
					Size = UDim2.new(1, -6, 1, 0);
					Position = UDim2.new(0, 6, 0, 0);
					TextSize = 14;
					Text = Value;
					TextXAlignment = Enum.TextXAlignment.Left;
					ZIndex = 25;
					Parent = Button;
				});

				Library:OnHighlight(Button, Button,
					{ BorderColor3 = 'AccentColor', ZIndex = 24 },
					{ BorderColor3 = 'OutlineColor', ZIndex = 23 }
				);

				local Selected;

				if Info.Multi then
					Selected = Dropdown.Value[Value];
				else
					Selected = Dropdown.Value == Value;
				end;

				function Table:UpdateButton()
					if Info.Multi then
						Selected = Dropdown.Value[Value];
					else
						Selected = Dropdown.Value == Value;
					end;

					ButtonLabel.TextColor3 = Selected and Library.AccentColor or Library.FontColor;
					Library.RegistryMap[ButtonLabel].Properties.TextColor3 = Selected and 'AccentColor' or 'FontColor';
				end;

				ButtonLabel.InputBegan:Connect(function(Input)
					if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
						local Try = not Selected;

						if Dropdown:GetActiveValues() == 1 and (not Try) and (not Info.AllowNull) then
						else
							if Info.Multi then
								Selected = Try;

								if Selected then
									Dropdown.Value[Value] = true;
								else
									Dropdown.Value[Value] = nil;
								end;
							else
								Selected = Try;

								if Selected then
									Dropdown.Value = Value;
								else
									Dropdown.Value = nil;
								end;

								for _, OtherButton in next, Buttons do
									OtherButton:UpdateButton();
								end;
							end;

							Table:UpdateButton();
							Dropdown:Display();

							Library:SafeCallback(Dropdown.Callback, Dropdown.Value);
							Library:SafeCallback(Dropdown.Changed, Dropdown.Value);

							Library:AttemptSave();
						end;
					end;
				end);

				Table:UpdateButton();
				Dropdown:Display();

				Buttons[Button] = Table;
			end;

			Scrolling.CanvasSize = UDim2.fromOffset(0, (Count * 20) + 1);

			local Y = math.clamp(Count * 20, 0, MAX_DROPDOWN_ITEMS * 20) + 1;
			RecalculateListSize(Y);
		end;

		function Dropdown:SetValues(NewValues)
			if NewValues then
				Dropdown.Values = NewValues;
			end;

			Dropdown:BuildDropdownList();
		end;

function Dropdown:OpenDropdown()
	ListOuter.Visible = true;
	Library.OpenedFrames[ListOuter] = true;
	TweenService:Create(DropdownArrow, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Rotation = 180;
	}):Play();
end;

function Dropdown:CloseDropdown()
	ListOuter.Visible = false;
	Library.OpenedFrames[ListOuter] = nil;
	TweenService:Create(DropdownArrow, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Rotation = 0;
	}):Play();
end;

		function Dropdown:OnChanged(Func)
			Dropdown.Changed = Func;
			Func(Dropdown.Value);
		end;

		function Dropdown:SetValue(Val)
			if Dropdown.Multi then
				local nTable = {};

				for Value, Bool in next, Val do
					if table.find(Dropdown.Values, Value) then
						nTable[Value] = true
					end;
				end;

				Dropdown.Value = nTable;
			else
				if (not Val) then
					Dropdown.Value = nil;
				elseif table.find(Dropdown.Values, Val) then
					Dropdown.Value = Val;
				end;
			end;

			Dropdown:BuildDropdownList();

			Library:SafeCallback(Dropdown.Callback, Dropdown.Value);
			Library:SafeCallback(Dropdown.Changed, Dropdown.Value);
		end;

		DropdownOuter.InputBegan:Connect(function(Input)
			if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) and not Library:MouseIsOverOpenedFrame() then
				if ListOuter.Visible then
					Dropdown:CloseDropdown();
				else
					Dropdown:OpenDropdown();
				end;
			end;
		end);

		InputService.InputBegan:Connect(function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
				local AbsPos, AbsSize = ListOuter.AbsolutePosition, ListOuter.AbsoluteSize;
				local px, py = Input.Position.X, Input.Position.Y;

				if px < AbsPos.X or px > AbsPos.X + AbsSize.X
					or py < (AbsPos.Y - 20 - 1) or py > AbsPos.Y + AbsSize.Y then

					Dropdown:CloseDropdown();
				end;
			end;
		end);

		Dropdown:BuildDropdownList();
		Dropdown:Display();

		local Defaults = {}

		if type(Info.Default) == 'string' then
			local Idx = table.find(Dropdown.Values, Info.Default)
			if Idx then
				table.insert(Defaults, Idx)
			end
		elseif type(Info.Default) == 'table' then
			for _, Value in next, Info.Default do
				local Idx = table.find(Dropdown.Values, Value)
				if Idx then
					table.insert(Defaults, Idx)
				end
			end
		elseif type(Info.Default) == 'number' and Dropdown.Values[Info.Default] ~= nil then
			table.insert(Defaults, Info.Default)
		end

		if next(Defaults) then
			for i = 1, #Defaults do
				local Index = Defaults[i]
				if Info.Multi then
					Dropdown.Value[Dropdown.Values[Index]] = true
				else
					Dropdown.Value = Dropdown.Values[Index];
				end

				if (not Info.Multi) then break end
			end

			Dropdown:BuildDropdownList();
			Dropdown:Display();
		end

		Groupbox:AddBlank(Info.BlankSize or 5);
		Groupbox:Resize();

		Options[Idx] = Dropdown;

		return Dropdown;
	end;

	function Funcs:AddDependencyBox()
		local Depbox = {
			Dependencies = {};
		};

		local Groupbox = self;
		local Container = Groupbox.Container;

		local Holder = Library:Create('Frame', {
			BackgroundTransparency = 1;
			Size = UDim2.new(1, 0, 0, 0);
			Visible = false;
			Parent = Container;
		});

		local Frame = Library:Create('Frame', {
			BackgroundTransparency = 1;
			Size = UDim2.new(1, 0, 1, 0);
			Visible = true;
			Parent = Holder;
		});

		local Layout = Library:Create('UIListLayout', {
			FillDirection = Enum.FillDirection.Vertical;
			SortOrder = Enum.SortOrder.LayoutOrder;
			Parent = Frame;
		});

		function Depbox:Resize()
			Holder.Size = UDim2.new(1, 0, 0, Layout.AbsoluteContentSize.Y);
			Groupbox:Resize();
		end;

		Layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
			Depbox:Resize();
		end);

		Holder:GetPropertyChangedSignal('Visible'):Connect(function()
			Depbox:Resize();
		end);

		function Depbox:Update()
			for _, Dependency in next, Depbox.Dependencies do
				local Elem = Dependency[1];
				local Value = Dependency[2];

				if Elem.Type == 'Toggle' and Elem.Value ~= Value then
					Holder.Visible = false;
					Depbox:Resize();
					return;
				end;
			end;

			Holder.Visible = true;
			Depbox:Resize();
		end;

		function Depbox:SetupDependencies(Dependencies)
			for _, Dependency in next, Dependencies do
				assert(type(Dependency) == 'table', 'SetupDependencies: Dependency is not of type `table`.');
				assert(Dependency[1], 'SetupDependencies: Dependency is missing element argument.');
				assert(Dependency[2] ~= nil, 'SetupDependencies: Dependency is missing value argument.');
			end;

			Depbox.Dependencies = Dependencies;
			Depbox:Update();
		end;

		Depbox.Container = Frame;

		setmetatable(Depbox, BaseGroupbox);

		table.insert(Library.DependencyBoxes, Depbox);

		return Depbox;
	end;

	BaseGroupbox.__index = Funcs;
	BaseGroupbox.__namecall = function(Table, Key, ...)
		return Funcs[Key](...);
	end;
end;

-- < Create other UI elements >
do
	Library.NotificationArea = Library:Create('Frame', {
		BackgroundTransparency = 1;
		Position = UDim2.new(0, 0, 0, 40);
		Size = UDim2.new(0, 300, 0, 200);
		ZIndex = 100;
		Parent = ScreenGui;
	});

	Library:Create('UIListLayout', {
		Padding = UDim.new(0, 4);
		FillDirection = Enum.FillDirection.Vertical;
		SortOrder = Enum.SortOrder.LayoutOrder;
		Parent = Library.NotificationArea;
	});

-- ── Watermark ───────────────────────────────────────────────────────────
local WatermarkOuter = Library:Create('Frame', {
	BackgroundColor3 = Library.OutlineColor;
	BorderSizePixel  = 0;
	Position         = UDim2.fromOffset(100, 10);
	Size             = UDim2.fromOffset(213, 28);
	ZIndex           = 200;
	Visible          = false;
	Parent           = ScreenGui;
});

Library:Create('UICorner', {
	CornerRadius = UDim.new(0, 4);
	Parent       = WatermarkOuter;
});

Library:AddToRegistry(WatermarkOuter, {
	BackgroundColor3 = 'OutlineColor';
});

local WatermarkShadow = Library:Create('Frame', {
	BackgroundColor3       = Color3.new(0, 0, 0);
	BackgroundTransparency = 0.6;
	BorderSizePixel        = 0;
	Position               = UDim2.new(0, -1, 0, 1);
	Size                   = UDim2.new(1, 2, 1, 2);
	ZIndex                 = 199;
	Parent                 = WatermarkOuter;
});

Library:Create('UICorner', {
	CornerRadius = UDim.new(0, 5);
	Parent       = WatermarkShadow;
});

local WatermarkInner = Library:Create('Frame', {
	BackgroundColor3 = Library.MainColor;
	BorderSizePixel  = 0;
	Position         = UDim2.new(0, 1, 0, 1);
	Size             = UDim2.new(1, -2, 1, -2);
	ZIndex           = 201;
	Parent           = WatermarkOuter;
});

Library:Create('UICorner', {
	CornerRadius = UDim.new(0, 3);
	Parent       = WatermarkInner;
});

Library:AddToRegistry(WatermarkInner, {
	BackgroundColor3 = 'MainColor';
});

local WatermarkAccentBar = Library:Create('Frame', {
	BackgroundColor3 = Library.AccentColor;
	BorderSizePixel  = 0;
	Size             = UDim2.new(1, 0, 0, 2);
	ZIndex           = 203;
	Parent           = WatermarkInner;
});

Library:Create('UICorner', {
	CornerRadius = UDim.new(0, 3);
	Parent       = WatermarkAccentBar;
});

Library:AddToRegistry(WatermarkAccentBar, {
	BackgroundColor3 = 'AccentColor';
});

local WatermarkAccentBarBottom = Library:Create('Frame', {
	BackgroundColor3       = Library.AccentColor;
	BackgroundTransparency = 0.75;
	BorderSizePixel        = 0;
	AnchorPoint            = Vector2.new(0, 1);
	Position               = UDim2.new(0, 0, 1, 0);
	Size                   = UDim2.new(1, 0, 0, 1);
	ZIndex                 = 203;
	Parent                 = WatermarkInner;
});

Library:Create('UICorner', {
	CornerRadius = UDim.new(0, 3);
	Parent       = WatermarkAccentBarBottom;
});

Library:AddToRegistry(WatermarkAccentBarBottom, {
	BackgroundColor3 = 'AccentColor';
});

local LiveDot = Library:Create('Frame', {
	BackgroundColor3 = Library.AccentColor;
	BorderSizePixel  = 0;
	AnchorPoint      = Vector2.new(0.5, 0.5);
	Position         = UDim2.new(0, 12, 0.5, 0);
	Size             = UDim2.fromOffset(7, 7);
	ZIndex           = 205;
	Parent           = WatermarkInner;
});

Library:Create('UICorner', {
	CornerRadius = UDim.new(1, 0);
	Parent       = LiveDot;
});

Library:AddToRegistry(LiveDot, {
	BackgroundColor3 = 'AccentColor';
});

local LiveDotGlow = Library:Create('Frame', {
	BackgroundColor3       = Library.AccentColor;
	BackgroundTransparency = 0.55;
	BorderSizePixel        = 0;
	AnchorPoint            = Vector2.new(0.5, 0.5);
	Position               = UDim2.new(0.5, 0, 0.5, 0);
	Size                   = UDim2.fromOffset(7, 7);
	ZIndex                 = 204;
	Parent                 = LiveDot;
});

Library:Create('UICorner', {
	CornerRadius = UDim.new(1, 0);
	Parent       = LiveDotGlow;
});

Library:AddToRegistry(LiveDotGlow, {
	BackgroundColor3 = 'AccentColor';
});

local WatermarkDivider = Library:Create('Frame', {
	BackgroundColor3       = Library.OutlineColor;
	BackgroundTransparency = 0.4;
	BorderSizePixel        = 0;
	Position               = UDim2.new(0, 22, 0, 4);
	Size                   = UDim2.new(0, 1, 1, -8);
	ZIndex                 = 204;
	Parent                 = WatermarkInner;
});

Library:AddToRegistry(WatermarkDivider, {
	BackgroundColor3 = 'OutlineColor';
});

local WatermarkLabel = Library:CreateLabel({
	Position       = UDim2.new(0, 27, 0, 0);
	Size           = UDim2.new(1, -31, 1, 0);
	TextSize       = 12;
	TextXAlignment = Enum.TextXAlignment.Left;
	ZIndex         = 204;
	Parent         = WatermarkInner;
});

local WatermarkScale = Instance.new('UIScale');
WatermarkScale.Scale  = 1;
WatermarkScale.Parent = WatermarkOuter;

local WmHoverSound = Instance.new('Sound');
WmHoverSound.SoundId             = 'rbxassetid://6026984224';
WmHoverSound.Volume              = 0.12;
WmHoverSound.RollOffMaxDistance  = 0;
WmHoverSound.Parent              = WatermarkOuter;

local wmFastTween   = TweenInfo.new(0.1,  Enum.EasingStyle.Quad, Enum.EasingDirection.Out);
local wmBounceTween = TweenInfo.new(0.25, Enum.EasingStyle.Back,  Enum.EasingDirection.Out);

local wmHovered = false;

local function WmLighten(c, amt)
	return Color3.new(
		math.clamp(c.R + amt, 0, 1),
		math.clamp(c.G + amt, 0, 1),
		math.clamp(c.B + amt, 0, 1)
	);
end;

WatermarkOuter.MouseEnter:Connect(function()
	if wmHovered then return end;
	wmHovered = true;
	pcall(function() WmHoverSound:Play() end);

	TweenService:Create(WatermarkInner, wmFastTween, {
		BackgroundColor3 = WmLighten(Library.MainColor, 0.05);
	}):Play();

	TweenService:Create(WatermarkAccentBar, wmFastTween, {
		Size = UDim2.new(1, 0, 0, 3);
	}):Play();

	TweenService:Create(WatermarkScale, wmFastTween, {
		Scale = 1.04;
	}):Play();
end);

WatermarkOuter.MouseLeave:Connect(function()
	if not wmHovered then return end;
	wmHovered = false;

	TweenService:Create(WatermarkInner, wmFastTween, {
		BackgroundColor3 = Library.MainColor;
	}):Play();

	TweenService:Create(WatermarkAccentBar, wmFastTween, {
		Size = UDim2.new(1, 0, 0, 2);
	}):Play();

	TweenService:Create(WatermarkScale, wmBounceTween, {
		Scale = 1;
	}):Play();
end);

WatermarkOuter.TouchTap:Connect(function()
	pcall(function() WmHoverSound:Play() end);
	TweenService:Create(WatermarkInner, wmFastTween, { BackgroundColor3 = WmLighten(Library.MainColor, 0.05) }):Play();
	TweenService:Create(WatermarkAccentBar, wmFastTween, { Size = UDim2.new(1, 0, 0, 3) }):Play();
	TweenService:Create(WatermarkScale, wmFastTween, { Scale = 1.04 }):Play();
	task.delay(0.25, function()
		TweenService:Create(WatermarkInner, wmFastTween, { BackgroundColor3 = Library.MainColor }):Play();
		TweenService:Create(WatermarkAccentBar, wmFastTween, { Size = UDim2.new(1, 0, 0, 2) }):Play();
		TweenService:Create(WatermarkScale, wmBounceTween, { Scale = 1 }):Play();
	end);
end);

task.spawn(function()
	local pulseTween = TweenInfo.new(0.85, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true);
	TweenService:Create(LiveDotGlow, pulseTween, {
		Size                   = UDim2.fromOffset(13, 13);
		BackgroundTransparency = 0.88;
	}):Play();
end);

Library.Watermark = WatermarkOuter;
Library.WatermarkText = WatermarkLabel;
Library:MakeDraggable(Library.Watermark);



	local KeybindOuter = Library:Create('Frame', {
		AnchorPoint = Vector2.new(0, 0.5);
		BorderColor3 = Color3.new(0, 0, 0);
		Position = UDim2.new(0, 10, 0.5, 0);
		Size = UDim2.new(0, 210, 0, 20);
		Visible = false;
		ZIndex = 100;
		Parent = ScreenGui;
	});

	local KeybindInner = Library:Create('Frame', {
		BackgroundColor3 = Library.MainColor;
		BorderColor3 = Library.OutlineColor;
		BorderMode = Enum.BorderMode.Inset;
		Size = UDim2.new(1, 0, 1, 0);
		ZIndex = 101;
		Parent = KeybindOuter;
	});

	Library:AddToRegistry(KeybindInner, {
		BackgroundColor3 = 'MainColor';
		BorderColor3 = 'OutlineColor';
	}, true);

	local ColorFrame = Library:Create('Frame', {
		BackgroundColor3 = Library.AccentColor;
		BorderSizePixel = 0;
		Size = UDim2.new(1, 0, 0, 2);
		ZIndex = 102;
		Parent = KeybindInner;
	});

	Library:AddToRegistry(ColorFrame, {
		BackgroundColor3 = 'AccentColor';
	}, true);

	local KeybindLabel = Library:CreateLabel({
		Size = UDim2.new(1, 0, 0, 20);
		Position = UDim2.fromOffset(5, 2),
		TextXAlignment = Enum.TextXAlignment.Left,

		Text = 'Keybinds';
		ZIndex = 104;
		Parent = KeybindInner;
	});

	local KeybindContainer = Library:Create('Frame', {
		BackgroundTransparency = 1;
		Size = UDim2.new(1, 0, 1, -20);
		Position = UDim2.new(0, 0, 0, 20);
		ZIndex = 1;
		Parent = KeybindInner;
	});

	Library:Create('UIListLayout', {
		FillDirection = Enum.FillDirection.Vertical;
		SortOrder = Enum.SortOrder.LayoutOrder;
		Parent = KeybindContainer;
	});

	Library:Create('UIPadding', {
		PaddingLeft = UDim.new(0, 5),
		Parent = KeybindContainer,
	})

	Library.KeybindFrame = KeybindOuter;
	Library.KeybindContainer = KeybindContainer;
	Library:MakeDraggable(KeybindOuter);
end;

function Library:SetWatermarkVisibility(Bool)
	Library.Watermark.Visible = Bool;
end;

function Library:SetWatermark(Text)
	Library.WatermarkText.Text = Text;
	local X = Library:GetTextBounds(Text, Library.Font, 12);
	Library.Watermark.Size = UDim2.fromOffset(X + 27 + 12, 28);
	Library:SetWatermarkVisibility(true);
end;

	--[[
	Library:CreatePopout(Config)
	  Config.Title    -- string
	  Config.Size     -- UDim2  (default 260×420)
	  Config.Position -- UDim2  (default right of main window)

	Returns a Popout object with:
	  Popout:Show()
	  Popout:Hide()
	  Popout:Toggle()
	  Popout:AddGroupbox(Name)  → same API as Tab:AddGroupbox
	  Popout:CreateToggleButton(Text) → draggable button to toggle the popout
--]]
function Library:CreatePopout(Config)
	Config = Config or {};
	local PTitle = Config.Title    or 'Popout';
	local PSize  = Config.Size     or UDim2.fromOffset(262, 420);
	local PPos   = Config.Position or UDim2.fromOffset(740, 50);

	local Popout = { Visible = false };

	-- ── Outer shell ───────────────────────────────────────────────────────
	local PopoutOuter = Library:Create('Frame', {
		BackgroundColor3 = Library.OutlineColor;
		BorderSizePixel  = 0;
		Position         = PPos;
		Size             = PSize;
		Visible          = false;
		ZIndex           = 50;
		Parent           = ScreenGui;
	});
	Library:Create('UICorner', { CornerRadius = UDim.new(0, 6); Parent = PopoutOuter; });
	Library:AddToRegistry(PopoutOuter, { BackgroundColor3 = 'OutlineColor' });

	-- Drop shadow
	local _PopShadow = Library:Create('Frame', {
		BackgroundColor3       = Color3.new(0, 0, 0);
		BackgroundTransparency = 0.55;
		BorderSizePixel        = 0;
		Position               = UDim2.new(0, -2, 0, 3);
		Size                   = UDim2.new(1, 4, 1, 4);
		ZIndex                 = 49;
		Parent                 = PopoutOuter;
	});
	Library:Create('UICorner', { CornerRadius = UDim.new(0, 8); Parent = _PopShadow; });

	-- ── Inner panel ───────────────────────────────────────────────────────
	local PopoutInner = Library:Create('Frame', {
		BackgroundColor3 = Library.MainColor;
		BorderSizePixel  = 0;
		Position         = UDim2.new(0, 1, 0, 1);
		Size             = UDim2.new(1, -2, 1, -2);
		ZIndex           = 51;
		Parent           = PopoutOuter;
	});
	Library:Create('UICorner', { CornerRadius = UDim.new(0, 5); Parent = PopoutInner; });
	Library:AddToRegistry(PopoutInner, { BackgroundColor3 = 'MainColor' });

	-- Accent bars
	local _PopAccentTop = Library:Create('Frame', {
		BackgroundColor3 = Library.AccentColor;
		BorderSizePixel  = 0;
		Size             = UDim2.new(1, 0, 0, 2);
		ZIndex           = 52;
		Parent           = PopoutInner;
	});
	Library:Create('UICorner', { CornerRadius = UDim.new(0, 5); Parent = _PopAccentTop; });
	Library:AddToRegistry(_PopAccentTop, { BackgroundColor3 = 'AccentColor' });

	local _PopAccentBot = Library:Create('Frame', {
		BackgroundColor3       = Library.AccentColor;
		BackgroundTransparency = 0.75;
		BorderSizePixel        = 0;
		AnchorPoint            = Vector2.new(0, 1);
		Position               = UDim2.new(0, 0, 1, 0);
		Size                   = UDim2.new(1, 0, 0, 1);
		ZIndex                 = 52;
		Parent                 = PopoutInner;
	});
	Library:Create('UICorner', { CornerRadius = UDim.new(0, 5); Parent = _PopAccentBot; });
	Library:AddToRegistry(_PopAccentBot, { BackgroundColor3 = 'AccentColor' });

	-- Title divider
	local _PopDivider = Library:Create('Frame', {
		BackgroundColor3       = Library.OutlineColor;
		BackgroundTransparency = 0.4;
		BorderSizePixel        = 0;
		Position               = UDim2.new(0, 6, 0, 24);
		Size                   = UDim2.new(1, -12, 0, 1);
		ZIndex                 = 52;
		Parent                 = PopoutInner;
	});
	Library:AddToRegistry(_PopDivider, { BackgroundColor3 = 'OutlineColor' });

	-- Title label
	Library:CreateLabel({
		Position       = UDim2.new(0, 8, 0, 4);
		Size           = UDim2.new(1, -40, 0, 18);
		Text           = PTitle;
		TextSize       = 13;
		TextXAlignment = Enum.TextXAlignment.Left;
		ZIndex         = 53;
		Parent         = PopoutInner;
	});

	-- ── Close button ─────────────────────────────────────────────────────
	local _PopCloseBtn = Library:Create('Frame', {
		Active           = true;
		AnchorPoint      = Vector2.new(1, 0.5);
		BackgroundColor3 = Color3.fromRGB(255, 95, 87);
		BorderSizePixel  = 0;
		Position         = UDim2.new(1, -7, 0, 14);
		Size             = UDim2.fromOffset(14, 14);
		ZIndex           = 55;
		Parent           = PopoutInner;
	});
	Library:Create('UICorner', { CornerRadius = UDim.new(1, 0); Parent = _PopCloseBtn; });

	local _PopCloseIcon = Library:Create('TextLabel', {
		BackgroundTransparency = 1;
		Size       = UDim2.new(1, 0, 1, 0);
		Text       = '×';
		TextColor3 = Color3.fromRGB(120, 20, 10);
		TextSize   = 15;
		Font       = Enum.Font.GothamBold;
		ZIndex     = 56;
		Visible    = true;
		Parent     = _PopCloseBtn;
	});

	_PopCloseBtn.MouseEnter:Connect(function()
		TweenService:Create(_PopCloseBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(255, 115, 105) }):Play();
	end);
	_PopCloseBtn.MouseLeave:Connect(function()
		TweenService:Create(_PopCloseBtn, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromRGB(255, 95, 87) }):Play();
	end);
	_PopCloseBtn.InputBegan:Connect(function(Input)
		if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
			Popout:Hide();
		end;
	end);

	-- ── Scrollable content area ───────────────────────────────────────────
	local PopoutContent = Library:Create('ScrollingFrame', {
		BackgroundTransparency = 1;
		BorderSizePixel        = 0;
		Position               = UDim2.new(0, 6, 0, 30);
		Size                   = UDim2.new(1, -12, 1, -36);
		CanvasSize             = UDim2.new(0, 0, 0, 0);
		AutomaticCanvasSize    = Enum.AutomaticSize.Y;
		ScrollingDirection     = Enum.ScrollingDirection.Y;
		ScrollBarThickness     = 3;
		ScrollBarImageColor3   = Library.AccentColor;
		ZIndex                 = 52;
		Parent                 = PopoutInner;
	});
	Library:AddToRegistry(PopoutContent, { ScrollBarImageColor3 = 'AccentColor' });

	Library:Create('UIListLayout', {
		Padding             = UDim.new(0, 6);
		FillDirection       = Enum.FillDirection.Vertical;
		SortOrder           = Enum.SortOrder.LayoutOrder;
		HorizontalAlignment = Enum.HorizontalAlignment.Center;
		Parent              = PopoutContent;
	});
	Library:Create('UIPadding', {
		PaddingTop  = UDim.new(0, 4);
		PaddingLeft = UDim.new(0, 0);
		Parent      = PopoutContent;
	});

	Library:MakeDraggable(PopoutOuter, 28);

	-- ── Scale / show / hide tweens ────────────────────────────────────────
	local _PopScale = Instance.new('UIScale');
	_PopScale.Scale  = 0.92;
	_PopScale.Parent = PopoutOuter;

	local _showTw = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out);
	local _hideTw = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In);

	function Popout:Show()
		PopoutOuter.Visible = true;
		Popout.Visible      = true;
		TweenService:Create(_PopScale, _showTw, { Scale = 1 }):Play();
	end;

	function Popout:Hide()
		Popout.Visible = false;
		TweenService:Create(_PopScale, _hideTw, { Scale = 0.92 }):Play();
		task.delay(0.15, function()
			if not Popout.Visible then
				PopoutOuter.Visible = false;
			end;
		end);
	end;

	function Popout:Toggle()
		if Popout.Visible then Popout:Hide() else Popout:Show() end;
	end;

	-- ── AddGroupbox ───────────────────────────────────────────────────────
	function Popout:AddGroupbox(Name)
		local Groupbox = {};

		local BoxOuter = Library:Create('Frame', {
			BackgroundColor3 = Library.OutlineColor;
			BorderSizePixel  = 0;
			Size             = UDim2.new(1, 0, 0, 50);
			ZIndex           = 53;
			Parent           = PopoutContent;
		});
		Library:Create('UICorner', { CornerRadius = UDim.new(0, 4); Parent = BoxOuter; });
		Library:AddToRegistry(BoxOuter, { BackgroundColor3 = 'OutlineColor' });

		local BoxInner = Library:Create('Frame', {
			BackgroundColor3 = Library.BackgroundColor;
			BorderSizePixel  = 0;
			Position         = UDim2.new(0, 1, 0, 1);
			Size             = UDim2.new(1, -2, 1, -2);
			ZIndex           = 54;
			Parent           = BoxOuter;
		});
		Library:Create('UICorner', { CornerRadius = UDim.new(0, 3); Parent = BoxInner; });
		Library:AddToRegistry(BoxInner, { BackgroundColor3 = 'BackgroundColor' });

		local _GbHL = Library:Create('Frame', {
			BackgroundColor3 = Library.AccentColor;
			BorderSizePixel  = 0;
			Size             = UDim2.new(1, 0, 0, 2);
			ZIndex           = 55;
			Parent           = BoxInner;
		});
		Library:Create('UICorner', { CornerRadius = UDim.new(0, 3); Parent = _GbHL; });
		Library:AddToRegistry(_GbHL, { BackgroundColor3 = 'AccentColor' });

		Library:CreateLabel({
			Position       = UDim2.new(0, 4, 0, 2);
			Size           = UDim2.new(1, -4, 0, 18);
			TextSize       = 13;
			Text           = Name;
			TextXAlignment = Enum.TextXAlignment.Left;
			ZIndex         = 55;
			Parent         = BoxInner;
		});

		local Container = Library:Create('Frame', {
			BackgroundTransparency = 1;
			Position = UDim2.new(0, 4, 0, 20);
			Size     = UDim2.new(1, -4, 1, -20);
			ZIndex   = 55;
			Parent   = BoxInner;
		});
		Library:Create('UIListLayout', {
			FillDirection = Enum.FillDirection.Vertical;
			SortOrder     = Enum.SortOrder.LayoutOrder;
			Parent        = Container;
		});

		-- With Global ZIndexBehavior, child elements must have ZIndex >= 55
		-- to render above the popout panels (ZIndex 50-54).
		-- BaseGroupbox creates elements at ZIndex 5-6, so we boost them.
		local POPOUT_ZINDEX_BOOST = 54;
		Container.DescendantAdded:Connect(function(desc)
			if desc:IsA('GuiObject') or desc:IsA('TextLabel') or desc:IsA('TextButton') or desc:IsA('Frame') or desc:IsA('ImageLabel') then
				if desc.ZIndex < POPOUT_ZINDEX_BOOST then
					desc.ZIndex = desc.ZIndex + POPOUT_ZINDEX_BOOST;
				end;
			end;
		end);

		function Groupbox:Resize()
			local Size = 0;
			for _, El in next, Container:GetChildren() do
				if not El:IsA('UIListLayout') and El.Visible then
					Size = Size + El.Size.Y.Offset;
				end;
			end;
			BoxOuter.Size = UDim2.new(1, 0, 0, 20 + Size + 4);
		end;

		Groupbox.Container = Container;
		setmetatable(Groupbox, BaseGroupbox);
		Groupbox:AddBlank(3);
		Groupbox:Resize();

		return Groupbox;
	end;

	-- ── Popout toggle button (draggable, matches main toggle button style) ─
	function Popout:CreateToggleButton(Text)
		Text = Text or PTitle;

		local BtnOuter = Library:Create('Frame', {
			Active           = true;
			BackgroundColor3 = Library.OutlineColor;
			BorderSizePixel  = 0;
			Position         = UDim2.fromOffset(10, 50);
			Size             = UDim2.fromOffset(96, 28);
			ZIndex           = 300;
			Parent           = ScreenGui;
		});
		Library:Create('UICorner', { CornerRadius = UDim.new(0, 4); Parent = BtnOuter; });
		Library:AddToRegistry(BtnOuter, { BackgroundColor3 = 'OutlineColor' });

		local _BtnShadow = Library:Create('Frame', {
			BackgroundColor3       = Color3.new(0, 0, 0);
			BackgroundTransparency = 0.6;
			BorderSizePixel        = 0;
			Position               = UDim2.new(0, -1, 0, 1);
			Size                   = UDim2.new(1, 2, 1, 2);
			ZIndex                 = 299;
			Parent                 = BtnOuter;
		});
		Library:Create('UICorner', { CornerRadius = UDim.new(0, 5); Parent = _BtnShadow; });

		local BtnInner = Library:Create('Frame', {
			BackgroundColor3 = Library.MainColor;
			BorderSizePixel  = 0;
			Position         = UDim2.new(0, 1, 0, 1);
			Size             = UDim2.new(1, -2, 1, -2);
			ZIndex           = 301;
			Parent           = BtnOuter;
		});
		Library:Create('UICorner', { CornerRadius = UDim.new(0, 3); Parent = BtnInner; });
		Library:AddToRegistry(BtnInner, { BackgroundColor3 = 'MainColor' });

		local _BtnAccent = Library:Create('Frame', {
			BackgroundColor3 = Library.AccentColor;
			BorderSizePixel  = 0;
			Size             = UDim2.new(1, 0, 0, 2);
			ZIndex           = 303;
			Parent           = BtnInner;
		});
		Library:Create('UICorner', { CornerRadius = UDim.new(0, 3); Parent = _BtnAccent; });
		Library:AddToRegistry(_BtnAccent, { BackgroundColor3 = 'AccentColor' });

		local BtnLabel = Library:Create('TextLabel', {
			BackgroundTransparency = 1;
			Size       = UDim2.new(1, 0, 1, 0);
			Text       = Text;
			TextColor3 = Library.FontColor;
			TextSize   = 12;
			Font       = Library.Font;
			ZIndex     = 302;
			Parent     = BtnInner;
		});
		Library:AddToRegistry(BtnLabel, { TextColor3 = 'FontColor' });

		local BtnScale = Instance.new('UIScale');
		BtnScale.Scale  = 1;
		BtnScale.Parent = BtnOuter;

		local _BtnHoverSfx = Instance.new('Sound');
		_BtnHoverSfx.SoundId = 'rbxassetid://6026984224'; _BtnHoverSfx.Volume = 0.12;
		_BtnHoverSfx.RollOffMaxDistance = 0; _BtnHoverSfx.Parent = BtnOuter;

		local _BtnClickSfx = Instance.new('Sound');
		_BtnClickSfx.SoundId = 'rbxassetid://6895079853'; _BtnClickSfx.Volume = 0.3;
		_BtnClickSfx.RollOffMaxDistance = 0; _BtnClickSfx.Parent = BtnOuter;

		local _ftw = TweenInfo.new(0.1,  Enum.EasingStyle.Quad, Enum.EasingDirection.Out);
		local _btw = TweenInfo.new(0.25, Enum.EasingStyle.Back,  Enum.EasingDirection.Out);

		local _bHov  = false;
		local _bDrag = false;
		local THRESH = 6;

		local function _lighten(c, a)
			return Color3.new(math.clamp(c.R+a,0,1), math.clamp(c.G+a,0,1), math.clamp(c.B+a,0,1));
		end;

		BtnOuter.MouseEnter:Connect(function()
			if _bHov then return end; _bHov = true;
			pcall(function() _BtnHoverSfx:Play() end);
			TweenService:Create(BtnScale, _ftw, { Scale = 1.04 }):Play();
			TweenService:Create(BtnInner, _ftw, { BackgroundColor3 = _lighten(Library.MainColor, 0.05) }):Play();
		end);
		BtnOuter.MouseLeave:Connect(function()
			if not _bHov then return end; _bHov = false;
			TweenService:Create(BtnScale, _btw, { Scale = 1 }):Play();
			TweenService:Create(BtnInner, _ftw, { BackgroundColor3 = Library.MainColor }):Play();
		end);

		BtnOuter.InputBegan:Connect(function(Input)
			if Input.UserInputType ~= Enum.UserInputType.MouseButton1
			and Input.UserInputType ~= Enum.UserInputType.Touch then return end;

			_bDrag = false;
			TweenService:Create(BtnScale, TweenInfo.new(0.07, Enum.EasingStyle.Quad), { Scale = 0.91 }):Play();

			local SX = Input.Position.X; local SY = Input.Position.Y;
			local OX = Input.Position.X - BtnOuter.AbsolutePosition.X;
			local OY = Input.Position.Y - BtnOuter.AbsolutePosition.Y;

			local movedConn = InputService.InputChanged:Connect(function(ch)
				if ch.UserInputType ~= Enum.UserInputType.MouseMovement
				and ch.UserInputType ~= Enum.UserInputType.Touch then return end;
				if math.abs(ch.Position.X-SX) > THRESH or math.abs(ch.Position.Y-SY) > THRESH then
					_bDrag = true;
				end;
				if _bDrag then
					BtnOuter.Position = UDim2.fromOffset(ch.Position.X - OX, ch.Position.Y - OY);
				end;
			end);

			local relConn;
			relConn = InputService.InputEnded:Connect(function(endInp)
				if endInp ~= Input then return end;
				relConn:Disconnect(); movedConn:Disconnect();
				TweenService:Create(BtnScale, _btw, { Scale = _bHov and 1.04 or 1 }):Play();
				TweenService:Create(BtnInner, _ftw, { BackgroundColor3 = Library.MainColor }):Play();
				if not _bDrag then
					pcall(function() _BtnClickSfx:Play() end);
					Popout:Toggle();
				end;
				_bDrag = false;
			end);
		end);

		return BtnOuter;
	end;

	return Popout;
end;

function Library:CreateToggleButton(Text)
    Text = Text or 'Menu';

    local TweenService = game:GetService('TweenService');
    local fastTween  = TweenInfo.new(0.1,  Enum.EasingStyle.Quad, Enum.EasingDirection.Out);
    local bounceTween = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out);

    local ButtonOuter = Library:Create('Frame', {
        BackgroundColor3 = Library.OutlineColor or Color3.fromRGB(60, 60, 60);
        BorderSizePixel  = 0;
        Position         = UDim2.fromOffset(10, 10);
        Size             = UDim2.fromOffset(96, 28);
        ZIndex           = 300;
        Parent           = ScreenGui;
    });

    Library:Create('UICorner', {
        CornerRadius = UDim.new(0, 4);
        Parent       = ButtonOuter;
    });

    Library:AddToRegistry(ButtonOuter, {
        BackgroundColor3 = 'OutlineColor';
    });

    local Shadow = Library:Create('Frame', {
        BackgroundColor3 = Color3.new(0, 0, 0);
        BackgroundTransparency = 0.6;
        BorderSizePixel  = 0;
        Position         = UDim2.new(0, -1, 0, 1);
        Size             = UDim2.new(1, 2, 1, 2);
        ZIndex           = 299;
        Parent           = ButtonOuter;
    });

    Library:Create('UICorner', {
        CornerRadius = UDim.new(0, 5);
        Parent       = Shadow;
    });

    local ButtonInner = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderSizePixel  = 0;
        Position         = UDim2.new(0, 1, 0, 1);
        Size             = UDim2.new(1, -2, 1, -2);
        ZIndex           = 301;
        Parent           = ButtonOuter;
    });

    Library:Create('UICorner', {
        CornerRadius = UDim.new(0, 3);
        Parent       = ButtonInner;
    });

    Library:AddToRegistry(ButtonInner, {
        BackgroundColor3 = 'MainColor';
    });

    local AccentBar = Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor;
        BorderSizePixel  = 0;
        Size             = UDim2.new(1, 0, 0, 2);
        ZIndex           = 303;
        Parent           = ButtonInner;
    });

    Library:Create('UICorner', {
        CornerRadius = UDim.new(0, 3);
        Parent       = AccentBar;
    });

    Library:AddToRegistry(AccentBar, {
        BackgroundColor3 = 'AccentColor';
    });

    local AccentBarBottom = Library:Create('Frame', {
        BackgroundColor3    = Library.AccentColor;
        BackgroundTransparency = 0.75;
        BorderSizePixel     = 0;
        AnchorPoint         = Vector2.new(0, 1);
        Position            = UDim2.new(0, 0, 1, 0);
        Size                = UDim2.new(1, 0, 0, 1);
        ZIndex              = 303;
        Parent              = ButtonInner;
    });

    Library:Create('UICorner', {
        CornerRadius = UDim.new(0, 3);
        Parent       = AccentBarBottom;
    });

    Library:AddToRegistry(AccentBarBottom, {
        BackgroundColor3 = 'AccentColor';
    });

    local IconLabel = Library:Create('TextLabel', {
        BackgroundTransparency = 1;
        Position  = UDim2.new(0, 6, 0, 0);
        Size      = UDim2.new(0, 16, 1, 0);
        Font      = Enum.Font.GothamBold;
        Text      = '📁';
        TextColor3 = Library.AccentColor;
        TextSize  = 12;
        TextXAlignment = Enum.TextXAlignment.Center;
        ZIndex    = 304;
        Parent    = ButtonInner;
    });

    Library:AddToRegistry(IconLabel, {
        TextColor3 = 'AccentColor';
    });

    local Divider = Library:Create('Frame', {
        BackgroundColor3    = Library.OutlineColor or Color3.fromRGB(60, 60, 60);
        BackgroundTransparency = 0.4;
        BorderSizePixel     = 0;
        Position            = UDim2.new(0, 23, 0, 4);
        Size                = UDim2.new(0, 1, 1, -8);
        ZIndex              = 304;
        Parent              = ButtonInner;
    });

    Library:AddToRegistry(Divider, {
        BackgroundColor3 = 'OutlineColor';
    });

    local TextLabel = Library:Create('TextLabel', {
        BackgroundTransparency = 1;
        Position  = UDim2.new(0, 28, 0, 0);
        Size      = UDim2.new(1, -32, 1, 0);
        Font      = Library.Font or Enum.Font.Gotham;
        Text = 'Close UI';
        TextColor3 = Library.FontColor or Color3.fromRGB(240, 240, 240);
        TextSize  = 12;
        TextXAlignment = Enum.TextXAlignment.Left;
        ZIndex    = 304;
        Parent    = ButtonInner;
    });

    Library:AddToRegistry(TextLabel, {
        TextColor3 = 'FontColor';
    });

    local Scale = Instance.new('UIScale');
    Scale.Scale  = 1;
    Scale.Parent = ButtonOuter;

    local ClickSound = Instance.new('Sound');
    ClickSound.SoundId  = 'rbxassetid://6895079853';
    ClickSound.Volume   = 0.35;
    ClickSound.RollOffMaxDistance = 0;
    ClickSound.Parent   = ButtonOuter;

    local HoverSound = Instance.new('Sound');
    HoverSound.SoundId  = 'rbxassetid://6026984224';
    HoverSound.Volume   = 0.12;
    HoverSound.RollOffMaxDistance = 0;
    HoverSound.Parent   = ButtonOuter;

    local isHovered  = false;
    local isDragging = false;

    local function lighten(c, amt)
        return Color3.new(
            math.clamp(c.R + amt, 0, 1),
            math.clamp(c.G + amt, 0, 1),
            math.clamp(c.B + amt, 0, 1)
        );
    end;

    ButtonOuter.MouseEnter:Connect(function()
        if isHovered then return end;
        isHovered = true;
        pcall(function() HoverSound:Play() end);

        TweenService:Create(ButtonInner, fastTween, {
            BackgroundColor3 = lighten(Library.MainColor, 0.05);
        }):Play();

        TweenService:Create(AccentBar, fastTween, {
            Size = UDim2.new(1, 0, 0, 3);
        }):Play();

        TweenService:Create(IconLabel, fastTween, {
            TextTransparency = 0.2;
        }):Play();

        TweenService:Create(Scale, fastTween, {
            Scale = 1.04;
        }):Play();
    end);

    ButtonOuter.MouseLeave:Connect(function()
        if not isHovered then return end;
        isHovered = false;

        TweenService:Create(ButtonInner, fastTween, {
            BackgroundColor3 = Library.MainColor;
        }):Play();

        TweenService:Create(AccentBar, fastTween, {
            Size = UDim2.new(1, 0, 0, 2);
        }):Play();

        TweenService:Create(IconLabel, fastTween, {
            TextTransparency = 0;
        }):Play();

        TweenService:Create(Scale, fastTween, {
            Scale = 1;
        }):Play();
    end);

-- Keep this button's label in sync when the minus button (or keybind) toggles the window
Library._onToggleChanged = function(state)
	isOpen = state;
	TextLabel.Text = Toggled and 'Close UI' or 'Open UI';
end;

local function doToggle()
	task.spawn(function() Library:Toggle() end);
	isOpen = not isOpen;
	TextLabel.Text = Toggled and 'Close UI' or 'Open UI';
end;
    local DRAG_THRESHOLD = 6;

    ButtonOuter.InputBegan:Connect(function(Input)
        if Input.UserInputType ~= Enum.UserInputType.MouseButton1
        and Input.UserInputType ~= Enum.UserInputType.Touch then
            return;
        end;

        isDragging = false;

        TweenService:Create(Scale, TweenInfo.new(0.07, Enum.EasingStyle.Quad), {
            Scale = 0.91;
        }):Play();

        TweenService:Create(ButtonInner, TweenInfo.new(0.07), {
            BackgroundColor3 = lighten(Library.MainColor, -0.04);
        }):Play();

        local StartX = Input.Position.X;
        local StartY = Input.Position.Y;
        local ObjX   = Input.Position.X - ButtonOuter.AbsolutePosition.X;
        local ObjY   = Input.Position.Y - ButtonOuter.AbsolutePosition.Y;

		local UIS = game:GetService('UserInputService');
		local moved = UIS.InputChanged:Connect(function(changed)
    	if changed.UserInputType ~= Enum.UserInputType.MouseMovement
    	and changed.UserInputType ~= Enum.UserInputType.Touch then return end;

    	local dx = changed.Position.X - StartX;
    	local dy = changed.Position.Y - StartY;

    	if math.abs(dx) > DRAG_THRESHOLD or math.abs(dy) > DRAG_THRESHOLD then
        isDragging = true;
    	end;

    	if isDragging then
        ButtonOuter.Position = UDim2.fromOffset(
            changed.Position.X - ObjX,
            changed.Position.Y - ObjY
        );
    	end;
		end);

        local releaseConn;
        releaseConn = game:GetService('UserInputService').InputEnded:Connect(function(endInput)
            if endInput ~= Input then return end;
            releaseConn:Disconnect();

            moved:Disconnect();

            TweenService:Create(Scale, bounceTween, {
                Scale = isHovered and 1.04 or 1;
            }):Play();

            TweenService:Create(ButtonInner, fastTween, {
                BackgroundColor3 = isHovered
                    and lighten(Library.MainColor, 0.05)
                    or  Library.MainColor;
            }):Play();

            if not isDragging then
                pcall(function() ClickSound:Play() end);

                TweenService:Create(AccentBar, TweenInfo.new(0.05), {
                    BackgroundColor3 = Color3.new(1, 1, 1);
                    Size = UDim2.new(1, 0, 0, 2);
                }):Play();

                task.delay(0.12, function()
                    TweenService:Create(AccentBar, TweenInfo.new(0.25), {
                        BackgroundColor3 = Library.AccentColor;
                    }):Play();
                end);

                doToggle();
            end;

            isDragging = false;
    end)
		end)

    return ButtonOuter;
end;

-- ══════════════════════════════════════════════════════════════════════════════
-- CreateHomeTab  —  Shows as a splash on startup (no tab button in tab bar).
--                   Disappears permanently when the user clicks any real tab.
-- ══════════════════════════════════════════════════════════════════════════════
function Library:CreateHomeTab(Window, Info)
	Info = Info or {};
	local ScriptName  = Info.ScriptName  or 'Script';
	local Version     = Info.Version     or 'v1.0';
	local Creator     = Info.Creator     or 'Unknown';
	local Discord     = Info.Discord     or 'N/A';
	local Description = Info.Description or 'No description provided.';

	local GameName = 'Unknown Game';
	local PlaceId  = game.PlaceId;
	pcall(function()
		local mInfo = game:GetService('MarketplaceService'):GetProductInfo(PlaceId);
		GameName = mInfo.Name or GameName;
	end);

	-- ── Build a silent tab-like frame directly in TabContainer ───────────
	-- We do NOT call Window:AddTab(), so no button appears in the tab bar.

	local TabContainer = Window.TabContainer;

	local HomeFrame = Library:Create('ScrollingFrame', {
		Name                 = 'HomeTabFrame';
		BackgroundTransparency = 1;
		Position             = UDim2.new(0, 0, 0, 0);
		Size                 = UDim2.new(1, 0, 1, 0);
		Visible              = true;   -- <── shown immediately on exec
		ZIndex               = 2;
		CanvasSize           = UDim2.new(0, 0, 5, 0);
		AutomaticCanvasSize  = Enum.AutomaticSize.Y;
		ScrollingDirection   = Enum.ScrollingDirection.Y;
		ScrollBarThickness   = 0;
		Parent               = TabContainer;
	});

	-- Replicate the two-column layout identical to a normal AddTab
	local LeftSide = Library:Create('ScrollingFrame', {
		BackgroundTransparency = 1;
		BorderSizePixel = 0;
		Position = UDim2.new(0, 8 - 1, 0, 8 - 1);
		Size     = UDim2.new(0.5, -12 + 2, 0, 507 + 2);
		CanvasSize = UDim2.new(0, 0, 0, 0);
		BottomImage = ''; TopImage = '';
		ScrollBarThickness = 0;
		ZIndex = 2;
		Parent = HomeFrame;
	});

	local RightSide = Library:Create('ScrollingFrame', {
		BackgroundTransparency = 1;
		BorderSizePixel = 0;
		Position = UDim2.new(0.5, 4 + 1, 0, 8 - 1);
		Size     = UDim2.new(0.5, -12 + 2, 0, 507 + 2);
		CanvasSize = UDim2.new(0, 0, 0, 0);
		BottomImage = ''; TopImage = '';
		ScrollBarThickness = 0;
		ZIndex = 2;
		Parent = HomeFrame;
	});

	Library:Create('UIListLayout', {
		Padding = UDim.new(0, 8);
		FillDirection = Enum.FillDirection.Vertical;
		SortOrder = Enum.SortOrder.LayoutOrder;
		HorizontalAlignment = Enum.HorizontalAlignment.Center;
		Parent = LeftSide;
	});

	Library:Create('UIListLayout', {
		Padding = UDim.new(0, 8);
		FillDirection = Enum.FillDirection.Vertical;
		SortOrder = Enum.SortOrder.LayoutOrder;
		HorizontalAlignment = Enum.HorizontalAlignment.Center;
		Parent = RightSide;
	});

	for _, Side in next, { LeftSide, RightSide } do
		Side:WaitForChild('UIListLayout'):GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
			Side.CanvasSize = UDim2.fromOffset(0, Side.UIListLayout.AbsoluteContentSize.Y);
		end);
	end;

	-- ── Minimal HomeTab object with AddGroupbox / AddLeftGroupbox / AddRightGroupbox
	local HomeTab = { Groupboxes = {}; Tabboxes = {}; };

	function HomeTab:AddGroupbox(gInfo)
		local Groupbox = {};

		local BoxOuter = Library:Create('Frame', {
			BackgroundColor3 = Library.OutlineColor;
			BorderSizePixel  = 0;
			Size             = UDim2.new(1, 0, 0, 507 + 2);
			ZIndex           = 2;
			Parent           = gInfo.Side == 1 and LeftSide or RightSide;
		});

		Library:Create('UICorner', { CornerRadius = UDim.new(0, 4); Parent = BoxOuter; });
		Library:AddToRegistry(BoxOuter, { BackgroundColor3 = 'OutlineColor'; });

		local BoxInner = Library:Create('Frame', {
			BackgroundColor3 = Library.BackgroundColor;
			BorderSizePixel  = 0;
			Size             = UDim2.new(1, -2, 1, -2);
			Position         = UDim2.new(0, 1, 0, 1);
			ZIndex           = 4;
			Parent           = BoxOuter;
		});

		Library:Create('UICorner', { CornerRadius = UDim.new(0, 3); Parent = BoxInner; });
		Library:AddToRegistry(BoxInner, { BackgroundColor3 = 'BackgroundColor'; });

		local Highlight = Library:Create('Frame', {
			BackgroundColor3 = Library.AccentColor;
			BorderSizePixel  = 0;
			Size             = UDim2.new(1, 0, 0, 2);
			ZIndex           = 5;
			Parent           = BoxInner;
		});
		Library:AddToRegistry(Highlight, { BackgroundColor3 = 'AccentColor'; });

		Library:CreateLabel({
			Size           = UDim2.new(1, 0, 0, 18);
			Position       = UDim2.new(0, 4, 0, 2);
			TextSize       = 14;
			Text           = gInfo.Name;
			TextXAlignment = Enum.TextXAlignment.Left;
			ZIndex         = 5;
			Parent         = BoxInner;
		});

		local Container = Library:Create('Frame', {
			BackgroundTransparency = 1;
			Position = UDim2.new(0, 4, 0, 20);
			Size     = UDim2.new(1, -4, 1, -20);
			ZIndex   = 1;
			Parent   = BoxInner;
		});

		Library:Create('UIListLayout', {
			FillDirection = Enum.FillDirection.Vertical;
			SortOrder     = Enum.SortOrder.LayoutOrder;
			Parent        = Container;
		});

		function Groupbox:Resize()
			local Size = 0;
			for _, Element in next, Container:GetChildren() do
				if not Element:IsA('UIListLayout') and Element.Visible then
					Size = Size + Element.Size.Y.Offset;
				end;
			end;
			BoxOuter.Size = UDim2.new(1, 0, 0, 20 + Size + 2 + 2);
		end;

		Groupbox.Container = Container;
		setmetatable(Groupbox, BaseGroupbox);

		Groupbox:AddBlank(3);
		Groupbox:Resize();

		HomeTab.Groupboxes[gInfo.Name] = Groupbox;
		return Groupbox;
	end;

	function HomeTab:AddLeftGroupbox(Name)
		return HomeTab:AddGroupbox({ Side = 1; Name = Name; });
	end;

	function HomeTab:AddRightGroupbox(Name)
		return HomeTab:AddGroupbox({ Side = 2; Name = Name; });
	end;

	-- Store references so the patch below can hide HomeFrame
	HomeTab.Frame    = HomeFrame;
	Window.HomeTab   = HomeTab;

	-- ── Patch Window.AddTab so every real tab's ShowTab hides HomeFrame ──
	-- We wrap once; subsequent calls to AddTab also get the wrapper because
	-- we replace Window.AddTab in-place.
	local _OrigAddTab = Window.AddTab;
	Window.AddTab = function(win, name)
		local tab = _OrigAddTab(win, name);
		local _OrigShow = tab.ShowTab;
		tab.ShowTab = function(t)
			-- Hide the home splash the first time any real tab is shown
			if Window.HomeTab and Window.HomeTab.Frame then
				Window.HomeTab.Frame.Visible = false;
			end;
			_OrigShow(t);
		end;
		return tab;
	end;

	-- ── LEFT SIDE content ────────────────────────────────────────────────
	local InfoBox = HomeTab:AddLeftGroupbox('Script Info');

	local WelcomeLabel = InfoBox:AddLabel('✦  Welcome to ' .. ScriptName .. '  ✦', false);

	InfoBox:AddBlank(4);
	InfoBox:AddDivider();
	InfoBox:AddBlank(2);

	InfoBox:AddLabel('📋  Version:  ' .. Version, false);
	InfoBox:AddBlank(2);
	InfoBox:AddLabel('👤  Creator:  ' .. Creator, false);
	InfoBox:AddBlank(2);
	InfoBox:AddLabel('🎮  Game:  ' .. GameName, false);
	InfoBox:AddBlank(2);
	InfoBox:AddLabel('🆔  Place ID:  ' .. tostring(PlaceId), false);
	InfoBox:AddBlank(2);

	local UptimeLabel = InfoBox:AddLabel('⏱  Uptime:  0s', false);
	InfoBox:AddBlank(4);
	InfoBox:AddDivider();
	InfoBox:AddBlank(2);
	InfoBox:AddLabel(Description, true);

	-- ── RIGHT SIDE content ───────────────────────────────────────────────
	local SocialBox = HomeTab:AddRightGroupbox('Socials & Links');

	SocialBox:AddButton({
		Text = '💬  Copy Discord Invite',
		Func = function()
			pcall(setclipboard, Discord);
			Library:Notify('Discord link copied to clipboard!', 3);
		end;
	});

	SocialBox:AddBlank(3);

	SocialBox:AddButton({
		Text = '🌐  Copy Game Link',
		Func = function()
			pcall(setclipboard, 'https://www.roblox.com/games/' .. tostring(PlaceId));
			Library:Notify('Game link copied to clipboard!', 3);
		end;
	});

	SocialBox:AddBlank(3);
	SocialBox:AddDivider();
	SocialBox:AddBlank(2);

	local ServerLabel = SocialBox:AddLabel('👥  Players:  ' .. #game:GetService("Players"):GetPlayers() .. ' / ' .. game.Players.MaxPlayers, false);
	SocialBox:AddBlank(2);

	local PingLabel = SocialBox:AddLabel('📶  Ping:  --', false);
	SocialBox:AddBlank(2);

	local FpsLabel = SocialBox:AddLabel('🖥  FPS:  --', false);
	SocialBox:AddBlank(4);
	SocialBox:AddDivider();
	SocialBox:AddBlank(2);

	local Tips = {
		'💡  Tip: Right-click keybinds to change mode.',
		'💡  Tip: Drag any panel by its title bar.',
		'💡  Tip: Use RightShift to toggle the menu.',
		'💡  Tip: Right-click color pickers to copy hex.',
		'💡  Tip: Configs auto-save when you change a value.',
	};

	local TipLabel = SocialBox:AddLabel(Tips[1], true);
	SocialBox:AddBlank(2);

	-- ── Live update loop ─────────────────────────────────────────────────
	local StartTime = tick();
	local TipIndex  = 1;
	local LastTipSwap = tick();

	local RunService = game:GetService('RunService');
	local Players    = game:GetService('Players');

	local WelcomeMessages = {
		'✦  Welcome to ' .. ScriptName .. '  ✦',
		'✦  Enjoy ' .. ScriptName .. ' ' .. Version .. '  ✦',
		'✦  Made by ' .. Creator .. '  ✦',
	};
	local WelcomeIndex   = 1;
	local LastWelcomeSwap = tick();

	local LastFpsTime = tick();
	local FpsCount = 0;
	local CurrentFps = 0;

	Library:GiveSignal(RunService.Heartbeat:Connect(function(Delta)
		local Now = tick();

		FpsCount = FpsCount + 1;
		if Now - LastFpsTime >= 1 then
			CurrentFps = FpsCount;
			FpsCount = 0;
			LastFpsTime = Now;
		end;

		local Elapsed = math.floor(Now - StartTime);
		local Hours   = math.floor(Elapsed / 3600);
		local Mins    = math.floor((Elapsed % 3600) / 60);
		local Secs    = Elapsed % 60;
		local UptimeStr;

		if Hours > 0 then
			UptimeStr = string.format('%dh %dm %ds', Hours, Mins, Secs);
		elseif Mins > 0 then
			UptimeStr = string.format('%dm %ds', Mins, Secs);
		else
			UptimeStr = Secs .. 's';
		end;

		pcall(function() UptimeLabel:SetText('⏱  Uptime:  ' .. UptimeStr) end);
		pcall(function() FpsLabel:SetText('🖥  FPS:  ' .. CurrentFps) end);

		pcall(function()
			local lp = Players.LocalPlayer;
			if lp and typeof(lp.GetNetworkPing) == 'function' then
				PingLabel:SetText('📶  Ping:  ' .. math.floor(lp:GetNetworkPing() * 1000) .. 'ms');
			end;
		end);

		pcall(function()
			ServerLabel:SetText('👥  Players:  ' .. #Players:GetPlayers() .. ' / ' .. Players.MaxPlayers);
		end);

		if Now - LastTipSwap >= 8 then
			LastTipSwap = Now;
			TipIndex = (TipIndex % #Tips) + 1;
			pcall(function() TipLabel:SetText(Tips[TipIndex]) end);
		end;

		if Now - LastWelcomeSwap >= 4 then
			LastWelcomeSwap = Now;
			WelcomeIndex = (WelcomeIndex % #WelcomeMessages) + 1;
			pcall(function() WelcomeLabel:SetText(WelcomeMessages[WelcomeIndex]) end);
		end;
	end));

	return HomeTab;
end;

function Library:Notify(Text, Time)
	local XSize, YSize = Library:GetTextBounds(Text, Library.Font, 14);

	YSize = YSize + 7

	local NotifyOuter = Library:Create('Frame', {
		BorderColor3 = Color3.new(0, 0, 0);
		Position = UDim2.new(0, 100, 0, 10);
		Size = UDim2.new(0, 0, 0, YSize);
		ClipsDescendants = true;
		ZIndex = 100;
		Parent = Library.NotificationArea;
	});

	local NotifyInner = Library:Create('Frame', {
		BackgroundColor3 = Library.MainColor;
		BorderColor3 = Library.OutlineColor;
		BorderMode = Enum.BorderMode.Inset;
		Size = UDim2.new(1, 0, 1, 0);
		ZIndex = 101;
		Parent = NotifyOuter;
	});

	Library:AddToRegistry(NotifyInner, {
		BackgroundColor3 = 'MainColor';
		BorderColor3 = 'OutlineColor';
	}, true);

	local InnerFrame = Library:Create('Frame', {
		BackgroundColor3 = Color3.new(1, 1, 1);
		BorderSizePixel = 0;
		Position = UDim2.new(0, 1, 0, 1);
		Size = UDim2.new(1, -2, 1, -2);
		ZIndex = 102;
		Parent = NotifyInner;
	});

	local Gradient = Library:Create('UIGradient', {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
			ColorSequenceKeypoint.new(1, Library.MainColor),
		});
		Rotation = -90;
		Parent = InnerFrame;
	});

	Library:AddToRegistry(Gradient, {
		Color = function()
			return ColorSequence.new({
				ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
				ColorSequenceKeypoint.new(1, Library.MainColor),
			});
		end
	});

	local NotifyLabel = Library:CreateLabel({
		Position = UDim2.new(0, 4, 0, 0);
		Size = UDim2.new(1, -4, 1, 0);
		Text = Text;
		TextXAlignment = Enum.TextXAlignment.Left;
		TextSize = 14;
		ZIndex = 103;
		Parent = InnerFrame;
	});

	local LeftColor = Library:Create('Frame', {
		BackgroundColor3 = Library.AccentColor;
		BorderSizePixel = 0;
		Position = UDim2.new(0, -1, 0, -1);
		Size = UDim2.new(0, 3, 1, 2);
		ZIndex = 104;
		Parent = NotifyOuter;
	});

	Library:AddToRegistry(LeftColor, {
		BackgroundColor3 = 'AccentColor';
	}, true);

NotifyOuter.Size = UDim2.new(0, 0, 0, YSize);
TweenService:Create(NotifyOuter, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
	Size = UDim2.new(0, XSize + 8 + 4, 0, YSize);
}):Play();

task.spawn(function()
	task.wait(Time or 5);
	TweenService:Create(NotifyOuter, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size = UDim2.new(0, 0, 0, YSize);
	}):Play();
	task.wait(0.3);
	NotifyOuter:Destroy();
end);
end;

function Library:CreateWindow(...)
	local Arguments = { ... }
	local Config = { AnchorPoint = Vector2.zero }

	if type(...) == 'table' then
		Config = ...;
	else
		Config.Title = Arguments[1]
		Config.AutoShow = Arguments[2] or false;
	end

	if type(Config.Title) ~= 'string' then Config.Title = 'No title' end
	if type(Config.TabPadding) ~= 'number' then Config.TabPadding = 0 end
	if type(Config.MenuFadeTime) ~= 'number' then Config.MenuFadeTime = 0.2 end

	if typeof(Config.Position) ~= 'UDim2' then Config.Position = UDim2.fromOffset(175, 50) end
	if typeof(Config.Size) ~= 'UDim2' then Config.Size = UDim2.fromOffset(550, 600) end

	if Config.Center then
		Config.AnchorPoint = Vector2.new(0.5, 0.5)
		Config.Position = UDim2.fromScale(0.5, 0.5)
	end

	local Window = {
		Tabs = {};
	};

	local Outer = Library:Create('Frame', {
		AnchorPoint      = Config.AnchorPoint;
		BackgroundColor3 = Library.OutlineColor;
		BorderSizePixel  = 0;
		Position         = Config.Position;
		Size             = Config.Size;
		Visible          = false;
		ZIndex           = 1;
		Parent           = ScreenGui;
	});

	Library:Create('UICorner', {
		CornerRadius = UDim.new(0, 6);
		Parent       = Outer;
	});

	Library:AddToRegistry(Outer, {
		BackgroundColor3 = 'OutlineColor';
	});

	Library:MakeDraggable(Outer, 30);

	local Inner = Library:Create('Frame', {
		BackgroundColor3 = Library.MainColor;
		BorderSizePixel  = 0;
		Position         = UDim2.new(0, 1, 0, 1);
		Size             = UDim2.new(1, -2, 1, -2);
		ZIndex           = 1;
		Parent           = Outer;
	});

	Library:Create('UICorner', {
		CornerRadius = UDim.new(0, 5);
		Parent       = Inner;
	});

	Library:AddToRegistry(Inner, {
		BackgroundColor3 = 'MainColor';
	});

	local WindowAccentBar = Library:Create('Frame', {
		BackgroundColor3 = Library.AccentColor;
		BorderSizePixel  = 0;
		Size             = UDim2.new(1, 0, 0, 2);
		ZIndex           = 2;
		Parent           = Inner;
	});

	Library:Create('UICorner', {
		CornerRadius = UDim.new(0, 5);
		Parent       = WindowAccentBar;
	});

	Library:AddToRegistry(WindowAccentBar, {
		BackgroundColor3 = 'AccentColor';
	});

	local WindowAccentBarBottom = Library:Create('Frame', {
		BackgroundColor3       = Library.AccentColor;
		BackgroundTransparency = 0.75;
		BorderSizePixel        = 0;
		AnchorPoint            = Vector2.new(0, 1);
		Position               = UDim2.new(0, 0, 1, 0);
		Size                   = UDim2.new(1, 0, 0, 1);
		ZIndex                 = 2;
		Parent                 = Inner;
	});

	Library:Create('UICorner', {
		CornerRadius = UDim.new(0, 5);
		Parent       = WindowAccentBarBottom;
	});

	Library:AddToRegistry(WindowAccentBarBottom, {
		BackgroundColor3 = 'AccentColor';
	});

	local TitleDivider = Library:Create('Frame', {
		BackgroundColor3       = Library.OutlineColor;
		BackgroundTransparency = 0.4;
		BorderSizePixel        = 0;
		Position               = UDim2.new(0, 8, 0, 26);
		Size                   = UDim2.new(1, -16, 0, 1);
		ZIndex                 = 2;
		Parent                 = Inner;
	});

	Library:AddToRegistry(TitleDivider, {
		BackgroundColor3 = 'OutlineColor';
	});

local WindowLabel = Library:CreateLabel({
	Position       = UDim2.new(0, 10, 0, 5);
	Size           = UDim2.new(1, -60, 0, 21);   -- narrowed to leave room for controls
	Text           = Config.Title or '';
	TextSize       = 14;
	TextXAlignment = Enum.TextXAlignment.Left;
	ZIndex         = 3;
	Parent         = Inner;
});

-- ── Minimize button (yellow) ─────────────────────────────────────────────
local WinMinBtn = Library:Create('Frame', {
	Active           = true;
	AnchorPoint      = Vector2.new(1, 0.5);
	BackgroundColor3 = Color3.fromRGB(255, 189, 68);
	BorderSizePixel  = 0;
	Position         = UDim2.new(1, -28, 0, 15);
	Size             = UDim2.fromOffset(15, 15);
	ZIndex           = 10;
	Parent           = Inner;
});
Library:Create('UICorner', { CornerRadius = UDim.new(1, 0); Parent = WinMinBtn; });

local WinMinIcon = Library:Create('TextLabel', {
	BackgroundTransparency = 1;
	Size       = UDim2.new(1, 0, 1, 0);
	Text       = '−';
	TextColor3 = Color3.fromRGB(100, 60, 0);
	TextSize   = 15;
	Font       = Enum.Font.GothamBold;
	ZIndex     = 11;
	Visible    = true;
	Parent     = WinMinBtn;
});

WinMinBtn.MouseEnter:Connect(function()
	TweenService:Create(WinMinBtn, TweenInfo.new(0.1), {
		BackgroundColor3 = Color3.fromRGB(255, 210, 100);
	}):Play();
end);
WinMinBtn.MouseLeave:Connect(function()
	TweenService:Create(WinMinBtn, TweenInfo.new(0.12), {
		BackgroundColor3 = Color3.fromRGB(255, 189, 68);
	}):Play();
end);
WinMinBtn.InputBegan:Connect(function(Input)
	if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
		task.spawn(Library.Toggle);
	end;
end);

-- ── Close button (red) ───────────────────────────────────────────────────
local WinCloseBtn = Library:Create('Frame', {
	Active           = true;
	AnchorPoint      = Vector2.new(1, 0.5);
	BackgroundColor3 = Color3.fromRGB(255, 95, 87);
	BorderSizePixel  = 0;
	Position         = UDim2.new(1, -9, 0, 15);
	Size             = UDim2.fromOffset(15, 15);
	ZIndex           = 10;
	Parent           = Inner;
});
Library:Create('UICorner', { CornerRadius = UDim.new(1, 0); Parent = WinCloseBtn; });

local WinCloseIcon = Library:Create('TextLabel', {
	BackgroundTransparency = 1;
	Size       = UDim2.new(1, 0, 1, 0);
	Text       = '×';
	TextColor3 = Color3.fromRGB(120, 20, 10);
	TextSize   = 16;
	Font       = Enum.Font.GothamBold;
	ZIndex     = 11;
	Visible    = true;
	Parent     = WinCloseBtn;
});

WinCloseBtn.MouseEnter:Connect(function()
	TweenService:Create(WinCloseBtn, TweenInfo.new(0.1), {
		BackgroundColor3 = Color3.fromRGB(255, 115, 105);
	}):Play();
end);
WinCloseBtn.MouseLeave:Connect(function()
	TweenService:Create(WinCloseBtn, TweenInfo.new(0.12), {
		BackgroundColor3 = Color3.fromRGB(255, 95, 87);
	}):Play();
end);
WinCloseBtn.InputBegan:Connect(function(Input)
	if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
		Library:Unload();
	end;
end);

	local MainSectionOuter = Library:Create('Frame', {
		BackgroundColor3 = Library.BackgroundColor;
		BorderSizePixel  = 0;
		Position         = UDim2.new(0, 8, 0, 30);
		Size             = UDim2.new(1, -16, 1, -38);
		ZIndex           = 1;
		Parent           = Inner;
	});

	Library:Create('UICorner', {
		CornerRadius = UDim.new(0, 4);
		Parent       = MainSectionOuter;
	});

	Library:AddToRegistry(MainSectionOuter, {
		BackgroundColor3 = 'BackgroundColor';
	});

	local MainSectionInner = Library:Create('Frame', {
		BackgroundColor3 = Library.BackgroundColor;
		BorderSizePixel  = 0;
		Position         = UDim2.new(0, 0, 0, 0);
		Size             = UDim2.new(1, 0, 1, 0);
		ZIndex           = 1;
		Parent           = MainSectionOuter;
	});

	Library:Create('UICorner', {
		CornerRadius = UDim.new(0, 4);
		Parent       = MainSectionInner;
	});

	Library:AddToRegistry(MainSectionInner, {
		BackgroundColor3 = 'BackgroundColor';
	});

local TabArea = Library:Create('ScrollingFrame', {
	BackgroundTransparency = 1;
	Position = UDim2.new(0, 8, 0, 8);
	Size = UDim2.new(1, -16, 0, 21);
	ZIndex = 1;
	CanvasSize = UDim2.new(0, 0, 0, 0);
	AutomaticCanvasSize = Enum.AutomaticSize.None;
	ScrollingDirection = Enum.ScrollingDirection.X;
	ScrollBarThickness = 0;
	Parent = MainSectionInner;
});

local TabListLayout = Library:Create('UIListLayout', {
	Padding = UDim.new(0, Config.TabPadding);
	FillDirection = Enum.FillDirection.Horizontal;
	VerticalAlignment = Enum.VerticalAlignment.Center;
	SortOrder = Enum.SortOrder.LayoutOrder;
	Parent = TabArea;
});

-- Keep canvas size exactly tight to tab content so scroll can't go past the last tab
TabListLayout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
	TabArea.CanvasSize = UDim2.fromOffset(TabListLayout.AbsoluteContentSize.X, 0);
end);

	local TabContainer = Library:Create('Frame', {
		BackgroundColor3 = Library.MainColor;
		BorderSizePixel  = 0;
		Position         = UDim2.new(0, 8, 0, 30);
		Size             = UDim2.new(1, -16, 1, -38);
		ZIndex           = 2;
		Parent           = MainSectionInner;
	});

	Library:Create('UICorner', {
		CornerRadius = UDim.new(0, 4);
		Parent       = TabContainer;
	});

	Library:AddToRegistry(TabContainer, {
		BackgroundColor3 = 'MainColor';
	});

	function Window:SetWindowTitle(Title)
		WindowLabel.Text = Title;
	end;

	function Window:AddTab(Name)
		local Tab = {
			Groupboxes = {};
			Tabboxes = {};
		};

		local TabButtonWidth = Library:GetTextBounds(Name, Library.Font, 16);

		local TabButton = Library:Create('Frame', {
			BackgroundColor3 = Library.BackgroundColor;
			BorderSizePixel  = 0;
			Size             = UDim2.new(0, TabButtonWidth + 8 + 4, 1, -2);
			ZIndex           = 1;
			Parent           = TabArea;
		});

		Library:AddToRegistry(TabButton, {
			BackgroundColor3 = 'BackgroundColor';
		});

		local TabButtonLabel = Library:CreateLabel({
			Position = UDim2.new(0, 0, 0, 0);
			Size     = UDim2.new(1, 0, 1, -1);
			Text     = Name;
			ZIndex   = 1;
			Parent   = TabButton;
		});

		local Blocker = Library:Create('Frame', {
			BackgroundColor3       = Library.AccentColor;
			BackgroundTransparency = 1;
			BorderSizePixel        = 0;
			Position               = UDim2.new(0, 0, 1, 0);
			Size                   = UDim2.new(1, 0, 0, 2);
			ZIndex                 = 3;
			Parent                 = TabButton;
		});

		Library:AddToRegistry(Blocker, {
			BackgroundColor3 = 'AccentColor';
		});

		local TabHoverSound = Instance.new('Sound');
		TabHoverSound.SoundId            = 'rbxassetid://6026984224';
		TabHoverSound.Volume             = 0.1;
		TabHoverSound.RollOffMaxDistance = 0;
		TabHoverSound.Parent             = TabButton;

		local TabClickSound = Instance.new('Sound');
		TabClickSound.SoundId            = 'rbxassetid://6895079853';
		TabClickSound.Volume             = 0.2;
		TabClickSound.RollOffMaxDistance = 0;
		TabClickSound.Parent             = TabButton;

		local tabTween = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out);

		TabButton.MouseEnter:Connect(function()
			if Blocker.BackgroundTransparency == 0 then return end;
			pcall(function() TabHoverSound:Play() end);
			TweenService:Create(TabButtonLabel, tabTween, {
				TextColor3 = Library.AccentColor;
			}):Play();
			Library.RegistryMap[TabButtonLabel].Properties.TextColor3 = 'AccentColor';
		end);

		TabButton.MouseLeave:Connect(function()
			if Blocker.BackgroundTransparency == 0 then return end;
			TweenService:Create(TabButtonLabel, tabTween, {
				TextColor3 = Library.FontColor;
			}):Play();
			Library.RegistryMap[TabButtonLabel].Properties.TextColor3 = 'FontColor';
		end);

		TabButton.TouchTap:Connect(function()
			if Blocker.BackgroundTransparency == 0 then return end;
			pcall(function() TabHoverSound:Play() end);
			TweenService:Create(TabButtonLabel, tabTween, { TextColor3 = Library.AccentColor }):Play();
			task.delay(0.2, function()
				TweenService:Create(TabButtonLabel, tabTween, { TextColor3 = Library.FontColor }):Play();
			end);
		end);

		local TabFrame = Library:Create('ScrollingFrame', {
			Name = 'TabFrame',
			BackgroundTransparency = 1;
			Position = UDim2.new(0, 0, 0, 0);
			Size = UDim2.new(1, 0, 1, 0);
			Visible = false;
			ZIndex = 2;
			CanvasSize = UDim2.new(0,0,0,0);
			AutomaticCanvasSize = Enum.AutomaticSize.Y;
			ScrollingDirection = Enum.ScrollingDirection.Y;
			ScrollBarThickness = 0;
			Parent = TabContainer;
		});

		local LeftSide = Library:Create('Frame', {
			BackgroundTransparency = 1;
			BorderSizePixel = 0;
			Position = UDim2.new(0, 8 - 1, 0, 8 - 1);
			Size = UDim2.new(0.5, -12 + 2, 0, 507 + 2);
			ZIndex = 2;
			Parent = TabFrame;
		});

		local RightSide = Library:Create('Frame', {
			BackgroundTransparency = 1;
			BorderSizePixel = 0;
			Position = UDim2.new(0.5, 4 + 1, 0, 8 - 1);
			Size = UDim2.new(0.5, -12 + 2, 0, 507 + 2);
			ZIndex = 2;
			Parent = TabFrame;
		});

		Library:Create('UIListLayout', {
			Padding = UDim.new(0, 8);
			FillDirection = Enum.FillDirection.Vertical;
			SortOrder = Enum.SortOrder.LayoutOrder;
			HorizontalAlignment = Enum.HorizontalAlignment.Center;
			Parent = LeftSide;
		});

		Library:Create('UIListLayout', {
			Padding = UDim.new(0, 8);
			FillDirection = Enum.FillDirection.Vertical;
			SortOrder = Enum.SortOrder.LayoutOrder;
			HorizontalAlignment = Enum.HorizontalAlignment.Center;
			Parent = RightSide;
		});

		--[[for _, Side in next, { LeftSide, RightSide } do
			Side:WaitForChild('UIListLayout'):GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
				Side.CanvasSize = UDim2.fromOffset(0, Side.UIListLayout.AbsoluteContentSize.Y);
			end);
		end;]]

		local tabActiveTween = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out);

		function Tab:ShowTab()
			for _, Tab in next, Window.Tabs do
				Tab:HideTab();
			end;

			pcall(function() TabClickSound:Play() end);

			TweenService:Create(Blocker, tabActiveTween, {
				BackgroundTransparency = 0;
			}):Play();

			TweenService:Create(TabButton, tabActiveTween, {
				BackgroundColor3 = Library.MainColor;
			}):Play();

			TweenService:Create(TabButtonLabel, tabActiveTween, {
				TextColor3 = Library.AccentColor;
			}):Play();

			Library.RegistryMap[TabButton].Properties.BackgroundColor3 = 'MainColor';
			Library.RegistryMap[TabButtonLabel].Properties.TextColor3 = 'AccentColor';
			TabFrame.Visible = true;
		end;

		function Tab:HideTab()
			TweenService:Create(Blocker, tabActiveTween, {
				BackgroundTransparency = 1;
			}):Play();

			TweenService:Create(TabButton, tabActiveTween, {
				BackgroundColor3 = Library.BackgroundColor;
			}):Play();

			TweenService:Create(TabButtonLabel, tabActiveTween, {
				TextColor3 = Library.FontColor;
			}):Play();

			Library.RegistryMap[TabButton].Properties.BackgroundColor3 = 'BackgroundColor';
			Library.RegistryMap[TabButtonLabel].Properties.TextColor3 = 'FontColor';
			TabFrame.Visible = false;
		end;

		function Tab:SetLayoutOrder(Position)
			TabButton.LayoutOrder = Position;
			TabListLayout:ApplyLayout();
		end;

		function Tab:AddGroupbox(Info)
			local Groupbox = {};

			local BoxOuter = Library:Create('Frame', {
				BackgroundColor3 = Library.OutlineColor;
				BorderSizePixel  = 0;
				Size             = UDim2.new(1, 0, 0, 507 + 2);
				ZIndex           = 2;
				Parent           = Info.Side == 1 and LeftSide or RightSide;
			});

			Library:Create('UICorner', {
				CornerRadius = UDim.new(0, 4);
				Parent       = BoxOuter;
			});

			Library:AddToRegistry(BoxOuter, {
				BackgroundColor3 = 'OutlineColor';
			});

			local BoxInner = Library:Create('Frame', {
				BackgroundColor3 = Library.BackgroundColor;
				BorderSizePixel  = 0;
				Size             = UDim2.new(1, -2, 1, -2);
				Position         = UDim2.new(0, 1, 0, 1);
				ZIndex           = 4;
				Parent           = BoxOuter;
			});

			Library:Create('UICorner', {
				CornerRadius = UDim.new(0, 3);
				Parent       = BoxInner;
			});

			Library:AddToRegistry(BoxInner, {
				BackgroundColor3 = 'BackgroundColor';
			});

			local Highlight = Library:Create('Frame', {
				BackgroundColor3 = Library.AccentColor;
				BorderSizePixel = 0;
				Size = UDim2.new(1, 0, 0, 2);
				ZIndex = 5;
				Parent = BoxInner;
			});

			Library:AddToRegistry(Highlight, {
				BackgroundColor3 = 'AccentColor';
			});

			local GroupboxLabel = Library:CreateLabel({
				Size = UDim2.new(1, 0, 0, 18);
				Position = UDim2.new(0, 4, 0, 2);
				TextSize = 14;
				Text = Info.Name;
				TextXAlignment = Enum.TextXAlignment.Left;
				ZIndex = 5;
				Parent = BoxInner;
			});

			local Container = Library:Create('Frame', {
				BackgroundTransparency = 1;
				Position = UDim2.new(0, 4, 0, 20);
				Size = UDim2.new(1, -4, 1, -20);
				ZIndex = 1;
				Parent = BoxInner;
			});

			Library:Create('UIListLayout', {
				FillDirection = Enum.FillDirection.Vertical;
				SortOrder = Enum.SortOrder.LayoutOrder;
				Parent = Container;
			});

			function Groupbox:Resize()
				local Size = 0;

				for _, Element in next, Groupbox.Container:GetChildren() do
					if (not Element:IsA('UIListLayout')) and Element.Visible then
						Size = Size + Element.Size.Y.Offset;
					end;
				end;

				BoxOuter.Size = UDim2.new(1, 0, 0, 20 + Size + 2 + 2);
			end;

			Groupbox.Container = Container;
			setmetatable(Groupbox, BaseGroupbox);

			Groupbox:AddBlank(3);
			Groupbox:Resize();

			Tab.Groupboxes[Info.Name] = Groupbox;

			return Groupbox;
		end;

		function Tab:AddLeftGroupbox(Name)
			return Tab:AddGroupbox({ Side = 1; Name = Name; });
		end;

		function Tab:AddRightGroupbox(Name)
			return Tab:AddGroupbox({ Side = 2; Name = Name; });
		end;

		function Tab:AddTabbox(Info)
			local Tabbox = {
				Tabs = {};
			};

			local BoxOuter = Library:Create('Frame', {
				BackgroundColor3 = Library.OutlineColor;
				BorderSizePixel  = 0;
				Size             = UDim2.new(1, 0, 0, 0);
				ZIndex           = 2;
				Parent           = Info.Side == 1 and LeftSide or RightSide;
			});

			Library:Create('UICorner', {
				CornerRadius = UDim.new(0, 4);
				Parent       = BoxOuter;
			});

			Library:AddToRegistry(BoxOuter, {
				BackgroundColor3 = 'OutlineColor';
			});

			local BoxInner = Library:Create('Frame', {
				BackgroundColor3 = Library.BackgroundColor;
				BorderSizePixel  = 0;
				Size             = UDim2.new(1, -2, 1, -2);
				Position         = UDim2.new(0, 1, 0, 1);
				ZIndex           = 4;
				Parent           = BoxOuter;
			});

			Library:Create('UICorner', {
				CornerRadius = UDim.new(0, 3);
				Parent       = BoxInner;
			});

			Library:AddToRegistry(BoxInner, {
				BackgroundColor3 = 'BackgroundColor';
			});

			local Highlight = Library:Create('Frame', {
				BackgroundColor3 = Library.AccentColor;
				BorderSizePixel = 0;
				Size = UDim2.new(1, 0, 0, 2);
				ZIndex = 10;
				Parent = BoxInner;
			});

			Library:AddToRegistry(Highlight, {
				BackgroundColor3 = 'AccentColor';
			});

			local TabboxButtons = Library:Create('Frame', {
				BackgroundTransparency = 1;
				Position = UDim2.new(0, 0, 0, 1);
				Size = UDim2.new(1, 0, 0, 18);
				ZIndex = 5;
				Parent = BoxInner;
			});

			Library:Create('UIListLayout', {
				FillDirection = Enum.FillDirection.Horizontal;
				HorizontalAlignment = Enum.HorizontalAlignment.Left;
				SortOrder = Enum.SortOrder.LayoutOrder;
				Parent = TabboxButtons;
			});

			function Tabbox:AddTab(Name)
				local Tab = {};

				local Button = Library:Create('Frame', {
					Active = true;
					BackgroundColor3 = Library.MainColor;
					BorderColor3 = Color3.new(0, 0, 0);
					Size = UDim2.new(0.5, 0, 1, 0);
					ZIndex = 6;
					Parent = TabboxButtons;
				});

				Library:AddToRegistry(Button, {
					BackgroundColor3 = 'MainColor';
				});

				local ButtonLabel = Library:CreateLabel({
					Size = UDim2.new(1, 0, 1, 0);
					TextSize = 14;
					Text = Name;
					TextXAlignment = Enum.TextXAlignment.Center;
					ZIndex = 7;
					Parent = Button;
				});

				local Block = Library:Create('Frame', {
					BackgroundColor3 = Library.BackgroundColor;
					BorderSizePixel = 0;
					Position = UDim2.new(0, 0, 1, 0);
					Size = UDim2.new(1, 0, 0, 1);
					Visible = false;
					ZIndex = 9;
					Parent = Button;
				});

				Library:AddToRegistry(Block, {
					BackgroundColor3 = 'BackgroundColor';
				});

				local Container = Library:Create('Frame', {
					BackgroundTransparency = 1;
					Position = UDim2.new(0, 4, 0, 20);
					Size = UDim2.new(1, -4, 1, -20);
					ZIndex = 1;
					Visible = false;
					Parent = BoxInner;
				});

				Library:Create('UIListLayout', {
					FillDirection = Enum.FillDirection.Vertical;
					SortOrder = Enum.SortOrder.LayoutOrder;
					Parent = Container;
				});

				function Tab:Show()
					for _, Tab in next, Tabbox.Tabs do
						Tab:Hide();
					end;

					Container.Visible = true;
					Block.Visible = true;

					Button.BackgroundColor3 = Library.BackgroundColor;
					Library.RegistryMap[Button].Properties.BackgroundColor3 = 'BackgroundColor';

					Tab:Resize();
				end;

				function Tab:Hide()
					Container.Visible = false;
					Block.Visible = false;

					Button.BackgroundColor3 = Library.MainColor;
					Library.RegistryMap[Button].Properties.BackgroundColor3 = 'MainColor';
				end;

				function Tab:Resize()
					local TabCount = 0;

					for _, Tab in next, Tabbox.Tabs do
						TabCount = TabCount + 1;
					end;

					for _, Button in next, TabboxButtons:GetChildren() do
						if not Button:IsA('UIListLayout') then
							Button.Size = UDim2.new(1 / TabCount, 0, 1, 0);
						end;
					end;

					if (not Container.Visible) then
						return;
					end;

					local Size = 0;

					for _, Element in next, Tab.Container:GetChildren() do
						if (not Element:IsA('UIListLayout')) and Element.Visible then
							Size = Size + Element.Size.Y.Offset;
						end;
					end;

					BoxOuter.Size = UDim2.new(1, 0, 0, 20 + Size + 2 + 2);
				end;

				Button.InputBegan:Connect(function(Input)
					if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) and not Library:MouseIsOverOpenedFrame() then
						Tab:Show();
						Tab:Resize();
					end;
				end);

				Tab.Container = Container;
				Tabbox.Tabs[Name] = Tab;

				setmetatable(Tab, BaseGroupbox);

				Tab:AddBlank(3);
				Tab:Resize();

				if #TabboxButtons:GetChildren() == 2 then
					Tab:Show();
				end;

				return Tab;
			end;

			Tab.Tabboxes[Info.Name or ''] = Tabbox;

			return Tabbox;
		end;

		function Tab:AddLeftTabbox(Name)
			return Tab:AddTabbox({ Name = Name, Side = 1; });
		end;

		function Tab:AddRightTabbox(Name)
			return Tab:AddTabbox({ Name = Name, Side = 2; });
		end;

		TabButton.InputBegan:Connect(function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
				Tab:ShowTab();
			end;
		end);

		-- NOTE: We no longer auto-show the first tab here.
		-- The HomeFrame (if CreateHomeTab was called) shows instead.
		-- If CreateHomeTab was NOT called, the first tab added auto-shows normally.
		if #TabContainer:GetChildren() == 1 then
			Tab:ShowTab();
		end;

		Window.Tabs[Name] = Tab;
		return Tab;
	end;

	local ModalElement = Library:Create('TextButton', {
		BackgroundTransparency = 1;
		Size = UDim2.new(0, 0, 0, 0);
		Visible = true;
		Text = '';
		Modal = false;
		Parent = ScreenGui;
	});

local TransparencyCache = {};
-- Toggled boolean moved to start of script
local Fading = false;

function Library:Toggle()
	if Fading then
		return;
	end;

	local FadeTime = Config.MenuFadeTime;
	Fading = true;
	Toggled = (not Toggled);

	-- Notify CreateToggleButton (and anyone else) about the new state
	if Library._onToggleChanged then
		Library._onToggleChanged(Toggled);
	end;

		if Toggled then
			Outer.Visible = true;

			task.spawn(function()
				local State = InputService.MouseIconEnabled;

				local Cursor = Drawing.new('Triangle');
				Cursor.Thickness = 1;
				Cursor.Filled = true;
				Cursor.Visible = true;

				local CursorOutline = Drawing.new('Triangle');
				CursorOutline.Thickness = 1;
				CursorOutline.Filled = false;
				CursorOutline.Color = Color3.new(0, 0, 0);
				CursorOutline.Visible = true;

				while Toggled and ScreenGui.Parent do
					InputService.MouseIconEnabled = false;

					Cursor.Color = Library.AccentColor;

					local mx, my = Library:GetMousePosition();
					Cursor.PointA = Vector2.new(mx, my);
					Cursor.PointB = Vector2.new(mx + 16, my + 6);
					Cursor.PointC = Vector2.new(mx + 6, my + 16);

					CursorOutline.PointA = Cursor.PointA;
					CursorOutline.PointB = Cursor.PointB;
					CursorOutline.PointC = Cursor.PointC;

					RenderStepped:Wait();
				end;

				InputService.MouseIconEnabled = State;

				Cursor:Remove();
				CursorOutline:Remove();
			end);
		end;

		for _, Desc in next, Outer:GetDescendants() do
			local Properties = {};

			if Desc:IsA('ImageLabel') then
				table.insert(Properties, 'ImageTransparency');
				table.insert(Properties, 'BackgroundTransparency');
			elseif Desc:IsA('TextLabel') or Desc:IsA('TextBox') then
				table.insert(Properties, 'TextTransparency');
			elseif Desc:IsA('Frame') or Desc:IsA('ScrollingFrame') then
				table.insert(Properties, 'BackgroundTransparency');
			elseif Desc:IsA('UIStroke') then
				table.insert(Properties, 'Transparency');
			end;

			local Cache = TransparencyCache[Desc];

			if (not Cache) then
				Cache = {};
				TransparencyCache[Desc] = Cache;
			end;

			for _, Prop in next, Properties do
				if not Cache[Prop] then
					Cache[Prop] = Desc[Prop];
				end;

				if Cache[Prop] == 1 then
					continue;
				end;

				TweenService:Create(Desc, TweenInfo.new(FadeTime, Enum.EasingStyle.Linear), { [Prop] = Toggled and Cache[Prop] or 1 }):Play();
			end;
		end;

		task.wait(FadeTime);

		Outer.Visible = Toggled;

		Fading = false;
	end

	Library:GiveSignal(InputService.InputBegan:Connect(function(Input, Processed)
		if type(Library.ToggleKeybind) == 'table' and Library.ToggleKeybind.Type == 'KeyPicker' then
			if Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode.Name == Library.ToggleKeybind.Value then
				task.spawn(Library.Toggle)
			end
		elseif Input.KeyCode == Enum.KeyCode.RightControl or (Input.KeyCode == Enum.KeyCode.RightShift and (not Processed)) then
			task.spawn(Library.Toggle)
		end
	end))

	if Config.AutoShow then task.spawn(Library.Toggle) end

	-- ── Store TabContainer on Window so CreateHomeTab can access it ───────
	Window.TabContainer = TabContainer;
	Window.Holder = Outer;

	return Window;
end;

local function OnPlayerChange()
	local PlayerList = GetPlayersString();

	for _, Value in next, Options do
		if Value.Type == 'Dropdown' and Value.SpecialType == 'Player' then
			Value:SetValues(PlayerList);
		end;
	end;
end;

Players.PlayerAdded:Connect(OnPlayerChange);
Players.PlayerRemoving:Connect(OnPlayerChange);

-- ================================================================
--  Tool Panel Builder — themed floating panels for custom tools
-- ================================================================
Library._ToolPanels = {}

function Library:CreateToolPanel(config)
    local gui = Instance.new("ScreenGui")
    gui.Name = config.name or "ToolPanel"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Enabled = false
    gui.Parent = CoreGui

    local frame = Instance.new("Frame")
    frame.AnchorPoint = config.anchor or Vector2.new(0.5, 0)
    frame.BackgroundColor3 = Library.BackgroundColor
    frame.BackgroundTransparency = 0.05
    frame.BorderSizePixel = 0
    frame.Position = config.position or UDim2.new(0.5, 0, 0.03, 0)
    frame.Size = config.size or UDim2.new(0, 200, 0, 140)
    frame.ClipsDescendants = true
    frame.Parent = gui
    do
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = frame
        local s = Instance.new("UIStroke"); s.Color = Library.AccentColor; s.Thickness = 2; s.Parent = frame
        s.Name = "AccentStroke"
    end

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.AnchorPoint = Vector2.new(0.5, 0)
    title.BackgroundTransparency = 1
    title.Position = UDim2.new(0.5, 0, 0.02, 0)
    title.Size = UDim2.new(0.92, 0, 0.13, 0)
    title.Font = Library.BoldFont or Enum.Font.GothamBold
    title.Text = config.title or "Tool"
    title.TextColor3 = Library.AccentColor
    title.TextScaled = true
    title.TextTruncate = Enum.TextTruncate.AtEnd
    title.Parent = frame

    local status = Instance.new("TextLabel")
    status.Name = "Status"
    status.AnchorPoint = Vector2.new(0.5, 1)
    status.BackgroundTransparency = 1
    status.Position = UDim2.new(0.5, 0, 0.98, 0)
    status.Size = UDim2.new(0.92, 0, 0.18, 0)
    status.Font = Library.Font or Enum.Font.Gotham
    status.Text = config.statusText or ""
    status.TextColor3 = Library.FontColor or Color3.fromRGB(200, 200, 200)
    status.TextScaled = true
    status.TextWrapped = true
    status.TextTruncate = Enum.TextTruncate.AtEnd
    status.Parent = frame

    local panel = {gui = gui, frame = frame, title = title, status = status}
    table.insert(Library._ToolPanels, panel)
    return panel
end

function Library:CreateToolInput(parent, yPos, placeholder)
    local box = Instance.new("TextBox")
    box.AnchorPoint = Vector2.new(0.5, 0)
    box.BackgroundColor3 = Library.MainColor
    box.BorderSizePixel = 0
    box.Position = UDim2.new(0.5, 0, yPos, 0)
    box.Size = UDim2.new(0.84, 0, 0.12, 0)
    box.Font = Library.Font or Enum.Font.Gotham
    box.PlaceholderText = placeholder or ""
    box.PlaceholderColor3 = Color3.fromRGB(100, 100, 100)
    box.Text = ""
    box.TextColor3 = Library.FontColor or Color3.fromRGB(255, 255, 255)
    box.TextScaled = true
    box.ClearTextOnFocus = true
    box.ClipsDescendants = true
    box.Parent = parent
    do
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 4); c.Parent = box
        local s = Instance.new("UIStroke"); s.Color = Library.OutlineColor; s.Thickness = 1; s.Parent = box
    end
    return box
end

function Library:CreateToolButton(parent, text, yPos, xPos, width, callback)
    local btn = Instance.new("TextButton")
    btn.AnchorPoint = Vector2.new(0, 0)
    btn.BackgroundColor3 = Library.AccentColor
    btn.BorderSizePixel = 0
    btn.Position = UDim2.new(xPos, 0, yPos, 0)
    btn.Size = UDim2.new(width or 0.44, 0, 0.1, 0)
    btn.Font = Library.BoldFont or Enum.Font.GothamBold
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextScaled = true
    btn.ClipsDescendants = true
    btn.Parent = parent
    do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 4); c.Parent = btn end
    if callback then btn.MouseButton1Click:Connect(callback) end
    return btn
end

function Library:CreateToolLabel(parent, text, yPos)
    local lbl = Instance.new("TextLabel")
    lbl.AnchorPoint = Vector2.new(0.5, 0)
    lbl.BackgroundColor3 = Library.MainColor
    lbl.BackgroundTransparency = 0.3
    lbl.BorderSizePixel = 0
    lbl.Position = UDim2.new(0.5, 0, yPos, 0)
    lbl.Size = UDim2.new(0.84, 0, 0.12, 0)
    lbl.Font = Library.Font or Enum.Font.Gotham
    lbl.Text = text
    lbl.TextColor3 = Library.FontColor or Color3.fromRGB(200, 200, 200)
    lbl.TextScaled = true
    lbl.TextTruncate = Enum.TextTruncate.AtEnd
    lbl.ClipsDescendants = true
    lbl.Parent = parent
    do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 4); c.Parent = lbl end
    return lbl
end

-- Theme update loop for tool panels
task.defer(function()
    while not Library.Unloaded do
        for _, panel in ipairs(Library._ToolPanels) do
            pcall(function()
                if panel.frame and panel.frame.Parent then
                    panel.frame.BackgroundColor3 = Library.BackgroundColor
                    local stroke = panel.frame:FindFirstChild("AccentStroke")
                    if stroke then stroke.Color = Library.AccentColor end
                end
                if panel.title and panel.title.Parent then
                    panel.title.TextColor3 = Library.AccentColor
                end
                if panel.status and panel.status.Parent then
                    panel.status.TextColor3 = Library.FontColor or Color3.fromRGB(200, 200, 200)
                end
            end)
        end
        task.wait(1)
    end
end)

getgenv().Library = Library
return Library
