--[[
    imgui_loader.lua
    Roblox ImGui Port - Core Library
    Replicates Dear ImGui's look and feel using Drawing API
]]

local ImGui = {}

-- [ Services ]
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

-- [ Theme System ]
local Themes = {
    Dark = {
        Background = Color3.fromRGB(30, 30, 46),
        TitleBar = Color3.fromRGB(60, 63, 88),
        Accent = Color3.fromRGB(74, 158, 255),
        Text = Color3.fromRGB(255, 255, 255),
        Border = Color3.fromRGB(85, 85, 119),
        Widget = Color3.fromRGB(45, 45, 65),
        WidgetHover = Color3.fromRGB(55, 55, 75),
        WidgetActive = Color3.fromRGB(35, 35, 55),
    },
    Light = {
        Background = Color3.fromRGB(240, 240, 240),
        TitleBar = Color3.fromRGB(200, 200, 210),
        Accent = Color3.fromRGB(74, 158, 255),
        Text = Color3.fromRGB(0, 0, 0),
        Border = Color3.fromRGB(150, 150, 150),
        Widget = Color3.fromRGB(220, 220, 220),
        WidgetHover = Color3.fromRGB(230, 230, 230),
        WidgetActive = Color3.fromRGB(200, 200, 200),
    },
    Classic = {
        Background = Color3.fromRGB(51, 51, 55),
        TitleBar = Color3.fromRGB(82, 82, 85),
        Accent = Color3.fromRGB(66, 150, 250),
        Text = Color3.fromRGB(255, 255, 255),
        Border = Color3.fromRGB(110, 110, 128),
        Widget = Color3.fromRGB(66, 66, 70),
        WidgetHover = Color3.fromRGB(76, 76, 80),
        WidgetActive = Color3.fromRGB(56, 56, 60),
    }
}

local CurrentTheme = Themes.Dark

-- [ State Management ]
local DrawingObjects = {}
local Windows = {}
local ActiveWindow = nil
local MousePos = Vector2.new(0, 0)
local MouseDown = false
local LastMouseDown = false
local DraggedWindow = nil
local DragOffset = Vector2.new(0, 0)
local ResizingWindow = nil
local HoveredWidget = nil
local FocusedTextBox = nil

-- Current window context
local CurrentWindow = nil
local CursorX = 0
local CursorY = 0
local SameLineActive = false
local LastWidgetHeight = 0

-- Tab state
local TabBars = {}
local CurrentTabBar = nil

-- [ Drawing Utilities ]
local function CreateDrawing(type, properties)
    local obj = Drawing.new(type)
    for k, v in pairs(properties) do
        obj[k] = v
    end
    table.insert(DrawingObjects, obj)
    return obj
end

local function ClearDrawings()
    for _, obj in ipairs(DrawingObjects) do
        obj:Remove()
    end
    DrawingObjects = {}
end

-- [ Input Handling ]
UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        MousePos = Vector2.new(input.Position.X, input.Position.Y)
    end
end)

UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        MouseDown = true
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        MouseDown = false
        DraggedWindow = nil
        ResizingWindow = nil
    end
end)

-- [ Window Management ]
function ImGui.Begin(title, flags)
    flags = flags or {}
    
    if not Windows[title] then
        Windows[title] = {
            Title = title,
            Position = Vector2.new(100 + #Windows * 30, 100 + #Windows * 30),
            Size = Vector2.new(400, 300),
            Collapsed = false,
            Visible = true,
            ZIndex = #Windows,
            ScrollY = 0,
            MaxScrollY = 0,
        }
    end
    
    CurrentWindow = Windows[title]
    if not CurrentWindow.Visible then
        return false
    end
    
    -- Handle window dragging
    local titleBarHeight = 25
    local titleBarBounds = {
        Min = CurrentWindow.Position,
        Max = CurrentWindow.Position + Vector2.new(CurrentWindow.Size.X, titleBarHeight)
    }
    
    if MousePos.X >= titleBarBounds.Min.X and MousePos.X <= titleBarBounds.Max.X and
       MousePos.Y >= titleBarBounds.Min.Y and MousePos.Y <= titleBarBounds.Max.Y then
        if MouseDown and not LastMouseDown and not DraggedWindow then
            DraggedWindow = CurrentWindow
            DragOffset = MousePos - CurrentWindow.Position
            CurrentWindow.ZIndex = 1000
        end
    end
    
    if DraggedWindow == CurrentWindow then
        CurrentWindow.Position = MousePos - DragOffset
    end
    
    -- Draw window background
    CreateDrawing("Square", {
        Position = CurrentWindow.Position,
        Size = CurrentWindow.Size,
        Color = CurrentTheme.Background,
        Filled = true,
        Visible = true,
        ZIndex = CurrentWindow.ZIndex
    })
    
    -- Draw border
    CreateDrawing("Square", {
        Position = CurrentWindow.Position,
        Size = CurrentWindow.Size,
        Color = CurrentTheme.Border,
        Filled = false,
        Thickness = 1,
        Visible = true,
        ZIndex = CurrentWindow.ZIndex + 1
    })
    
    -- Draw title bar
    CreateDrawing("Square", {
        Position = CurrentWindow.Position,
        Size = Vector2.new(CurrentWindow.Size.X, titleBarHeight),
        Color = CurrentTheme.TitleBar,
        Filled = true,
        Visible = true,
        ZIndex = CurrentWindow.ZIndex + 2
    })
    
    -- Draw title text
    CreateDrawing("Text", {
        Text = (CurrentWindow.Collapsed and "▶ " or "▼ ") .. title,
        Position = CurrentWindow.Position + Vector2.new(5, 5),
        Size = 13,
        Color = CurrentTheme.Text,
        Font = Drawing.Fonts.Monospace,
        Visible = true,
        ZIndex = CurrentWindow.ZIndex + 3
    })
    
    -- Draw close button
    local closeButtonX = CurrentWindow.Position.X + CurrentWindow.Size.X - 20
    local closeButtonY = CurrentWindow.Position.Y + 5
    CreateDrawing("Text", {
        Text = "X",
        Position = Vector2.new(closeButtonX, closeButtonY),
        Size = 13,
        Color = CurrentTheme.Text,
        Font = Drawing.Fonts.Monospace,
        Visible = true,
        ZIndex = CurrentWindow.ZIndex + 3
    })
    
    -- Handle close button click
    if MouseDown and not LastMouseDown then
        if MousePos.X >= closeButtonX and MousePos.X <= closeButtonX + 15 and
           MousePos.Y >= closeButtonY and MousePos.Y <= closeButtonY + 15 then
            CurrentWindow.Visible = false
            return false
        end
    end
    
    -- Initialize cursor position
    CursorX = CurrentWindow.Position.X + 10
    CursorY = CurrentWindow.Position.Y + titleBarHeight + 10
    SameLineActive = false
    
    return not CurrentWindow.Collapsed
end

function ImGui.End()
    CurrentWindow = nil
end

-- [ Widget Rendering ]
function ImGui.Text(text)
    if not CurrentWindow then return end
    
    CreateDrawing("Text", {
        Text = text,
        Position = Vector2.new(CursorX, CursorY),
        Size = 13,
        Color = CurrentTheme.Text,
        Font = Drawing.Fonts.Monospace,
        Visible = true,
        ZIndex = CurrentWindow.ZIndex + 4
    })
    
    if not SameLineActive then
        CursorY = CursorY + 20
    end
    SameLineActive = false
    LastWidgetHeight = 20
end

function ImGui.Button(label)
    if not CurrentWindow then return false end
    
    local buttonWidth = 100
    local buttonHeight = 20
    local clicked = false
    
    local isHovered = MousePos.X >= CursorX and MousePos.X <= CursorX + buttonWidth and
                      MousePos.Y >= CursorY and MousePos.Y <= CursorY + buttonHeight
    
    local buttonColor = CurrentTheme.Widget
    if isHovered then
        buttonColor = MouseDown and CurrentTheme.WidgetActive or CurrentTheme.WidgetHover
        if MouseDown and not LastMouseDown then
            clicked = true
        end
    end
    
    CreateDrawing("Square", {
        Position = Vector2.new(CursorX, CursorY),
        Size = Vector2.new(buttonWidth, buttonHeight),
        Color = buttonColor,
        Filled = true,
        Visible = true,
        ZIndex = CurrentWindow.ZIndex + 4
    })
    
    CreateDrawing("Square", {
        Position = Vector2.new(CursorX, CursorY),
        Size = Vector2.new(buttonWidth, buttonHeight),
        Color = CurrentTheme.Border,
        Filled = false,
        Thickness = 1,
        Visible = true,
        ZIndex = CurrentWindow.ZIndex + 5
    })
    
    CreateDrawing("Text", {
        Text = label,
        Position = Vector2.new(CursorX + 5, CursorY + 3),
        Size = 13,
        Color = CurrentTheme.Text,
        Font = Drawing.Fonts.Monospace,
        Visible = true,
        ZIndex = CurrentWindow.ZIndex + 6
    })
    
    if not SameLineActive then
        CursorY = CursorY + buttonHeight + 5
    else
        CursorX = CursorX + buttonWidth + 5
    end
    SameLineActive = false
    LastWidgetHeight = buttonHeight
    
    return clicked
end

function ImGui.Checkbox(label, value)
    if not CurrentWindow then return value end
    
    local boxSize = 15
    local isHovered = MousePos.X >= CursorX and MousePos.X <= CursorX + boxSize and
                      MousePos.Y >= CursorY and MousePos.Y <= CursorY + boxSize
    
    if isHovered and MouseDown and not LastMouseDown then
        value = not value
    end
    
    CreateDrawing("Square", {
        Position = Vector2.new(CursorX, CursorY),
        Size = Vector2.new(boxSize, boxSize),
        Color = value and CurrentTheme.Accent or CurrentTheme.Widget,
        Filled = true,
        Visible = true,
        ZIndex = CurrentWindow.ZIndex + 4
    })
    
    CreateDrawing("Square", {
        Position = Vector2.new(CursorX, CursorY),
        Size = Vector2.new(boxSize, boxSize),
        Color = CurrentTheme.Border,
        Filled = false,
        Thickness = 1,
        Visible = true,
        ZIndex = CurrentWindow.ZIndex + 5
    })
    
    if value then
        CreateDrawing("Text", {
            Text = "✓",
            Position = Vector2.new(CursorX + 2, CursorY),
            Size = 13,
            Color = CurrentTheme.Text,
            Font = Drawing.Fonts.Monospace,
            Visible = true,
            ZIndex = CurrentWindow.ZIndex + 6
        })
    end
    
    CreateDrawing("Text", {
        Text = label,
        Position = Vector2.new(CursorX + boxSize + 5, CursorY),
        Size = 13,
        Color = CurrentTheme.Text,
        Font = Drawing.Fonts.Monospace,
        Visible = true,
        ZIndex = CurrentWindow.ZIndex + 6
    })
    
    if not SameLineActive then
        CursorY = CursorY + boxSize + 5
    end
    SameLineActive = false
    LastWidgetHeight = boxSize
    
    return value
end

function ImGui.SliderFloat(label, value, min, max)
    if not CurrentWindow then return value end
    
    local sliderWidth = 200
    local sliderHeight = 15
    local handleWidth = 10
    
    CreateDrawing("Text", {
        Text = label,
        Position = Vector2.new(CursorX, CursorY),
        Size = 13,
        Color = CurrentTheme.Text,
        Font = Drawing.Fonts.Monospace,
        Visible = true,
        ZIndex = CurrentWindow.ZIndex + 4
    })
    
    local sliderY = CursorY + 18
    
    CreateDrawing("Square", {
        Position = Vector2.new(CursorX, sliderY),
        Size = Vector2.new(sliderWidth, sliderHeight),
        Color = CurrentTheme.Widget,
        Filled = true,
        Visible = true,
        ZIndex = CurrentWindow.ZIndex + 4
    })
    
    local normalizedValue = (value - min) / (max - min)
    local handleX = CursorX + (sliderWidth - handleWidth) * normalizedValue
    
    local isHovered = MousePos.X >= CursorX and MousePos.X <= CursorX + sliderWidth and
                      MousePos.Y >= sliderY and MousePos.Y <= sliderY + sliderHeight
    
    if isHovered and MouseDown then
        local mouseX = math.clamp(MousePos.X - CursorX, 0, sliderWidth)
        normalizedValue = mouseX / sliderWidth
        value = min + (max - min) * normalizedValue
    end
    
    handleX = CursorX + (sliderWidth - handleWidth) * normalizedValue
    
    CreateDrawing("Square", {
        Position = Vector2.new(handleX, sliderY),
        Size = Vector2.new(handleWidth, sliderHeight),
        Color = CurrentTheme.Accent,
        Filled = true,
        Visible = true,
        ZIndex = CurrentWindow.ZIndex + 5
    })
    
    CreateDrawing("Text", {
        Text = string.format("%.3f", value),
        Position = Vector2.new(CursorX + sliderWidth + 10, sliderY),
        Size = 13,
        Color = CurrentTheme.Text,
        Font = Drawing.Fonts.Monospace,
        Visible = true,
        ZIndex = CurrentWindow.ZIndex + 4
    })
    
    CursorY = sliderY + sliderHeight + 5
    SameLineActive = false
    
    return value
end

function ImGui.SliderInt(label, value, min, max)
    local result = ImGui.SliderFloat(label, value, min, max)
    return math.floor(result + 0.5)
end

function ImGui.InputText(label, text)
    if not CurrentWindow then return text end
    
    local inputWidth = 200
    local inputHeight = 20
    
    CreateDrawing("Text", {
        Text = label,
        Position = Vector2.new(CursorX, CursorY),
        Size = 13,
        Color = CurrentTheme.Text,
        Font = Drawing.Fonts.Monospace,
        Visible = true,
        ZIndex = CurrentWindow.ZIndex + 4
    })
    
    local inputY = CursorY + 18
    
    CreateDrawing("Square", {
        Position = Vector2.new(CursorX, inputY),
        Size = Vector2.new(inputWidth, inputHeight),
        Color = CurrentTheme.Widget,
        Filled = true,
        Visible = true,
        ZIndex = CurrentWindow.ZIndex + 4
    })
    
    CreateDrawing("Square", {
        Position = Vector2.new(CursorX, inputY),
        Size = Vector2.new(inputWidth, inputHeight),
        Color = CurrentTheme.Border,
        Filled = false,
        Thickness = 1,
        Visible = true,
        ZIndex = CurrentWindow.ZIndex + 5
    })
    
    CreateDrawing("Text", {
        Text = text,
        Position = Vector2.new(CursorX + 5, inputY + 3),
        Size = 13,
        Color = CurrentTheme.Text,
        Font = Drawing.Fonts.Monospace,
        Visible = true,
        ZIndex = CurrentWindow.ZIndex + 6
    })
    
    CursorY = inputY + inputHeight + 5
    SameLineActive = false
    
    return text
end

function ImGui.ColorEdit3(label, r, g, b)
    if not CurrentWindow then return r, g, b end
    
    CreateDrawing("Text", {
        Text = label,
        Position = Vector2.new(CursorX, CursorY),
        Size = 13,
        Color = CurrentTheme.Text,
        Font = Drawing.Fonts.Monospace,
        Visible = true,
        ZIndex = CurrentWindow.ZIndex + 4
    })
    
    CursorY = CursorY + 18
    
    -- Color preview box
    CreateDrawing("Square", {
        Position = Vector2.new(CursorX, CursorY),
        Size = Vector2.new(30, 30),
        Color = Color3.fromRGB(r, g, b),
        Filled = true,
        Visible = true,
        ZIndex = CurrentWindow.ZIndex + 4
    })
    
    CreateDrawing("Square", {
        Position = Vector2.new(CursorX, CursorY),
        Size = Vector2.new(30, 30),
        Color = CurrentTheme.Border,
        Filled = false,
        Thickness = 1,
        Visible = true,
        ZIndex = CurrentWindow.ZIndex + 5
    })
    
    CursorY = CursorY + 35
    
    -- R slider
    r = ImGui.SliderInt("R", r, 0, 255)
    -- G slider
    g = ImGui.SliderInt("G", g, 0, 255)
    -- B slider
    b = ImGui.SliderInt("B", b, 0, 255)
    
    return r, g, b
end

function ImGui.Separator()
    if not CurrentWindow then return end
    
    CreateDrawing("Line", {
        From = Vector2.new(CursorX, CursorY),
        To = Vector2.new(CursorX + CurrentWindow.Size.X - 20, CursorY),
        Color = CurrentTheme.Border,
        Thickness = 1,
        Visible = true,
        ZIndex = CurrentWindow.ZIndex + 4
    })
    
    CursorY = CursorY + 10
    SameLineActive = false
end

function ImGui.SameLine()
    SameLineActive = true
    CursorX = CursorX + 110
    CursorY = CursorY - LastWidgetHeight - 5
end

function ImGui.CollapsingHeader(label)
    if not CurrentWindow then return false end
    
    local headerHeight = 20
    local headerWidth = CurrentWindow.Size.X - 20
    
    if not CurrentWindow.CollapsingHeaders then
        CurrentWindow.CollapsingHeaders = {}
    end
    
    if CurrentWindow.CollapsingHeaders[label] == nil then
        CurrentWindow.CollapsingHeaders[label] = false
    end
    
    local isHovered = MousePos.X >= CursorX and MousePos.X <= CursorX + headerWidth and
                      MousePos.Y >= CursorY and MousePos.Y <= CursorY + headerHeight
    
    if isHovered and MouseDown and not LastMouseDown then
        CurrentWindow.CollapsingHeaders[label] = not CurrentWindow.CollapsingHeaders[label]
    end
    
    CreateDrawing("Square", {
        Position = Vector2.new(CursorX, CursorY),
        Size = Vector2.new(headerWidth, headerHeight),
        Color = isHovered and CurrentTheme.WidgetHover or CurrentTheme.Widget,
        Filled = true,
        Visible = true,
        ZIndex = CurrentWindow.ZIndex + 4
    })
    
    local arrow = CurrentWindow.CollapsingHeaders[label] and "▼" or "▶"
    CreateDrawing("Text", {
        Text = arrow .. " " .. label,
        Position = Vector2.new(CursorX + 5, CursorY + 3),
        Size = 13,
        Color = CurrentTheme.Text,
        Font = Drawing.Fonts.Monospace,
        Visible = true,
        ZIndex = CurrentWindow.ZIndex + 5
    })
    
    CursorY = CursorY + headerHeight + 5
    SameLineActive = false
    
    return CurrentWindow.CollapsingHeaders[label]
end

function ImGui.Combo(label, selectedIndex, options)
    if not CurrentWindow then return selectedIndex end
    
    local comboWidth = 200
    local comboHeight = 20
    
    CreateDrawing("Text", {
        Text = label,
        Position = Vector2.new(CursorX, CursorY),
        Size = 13,
        Color = CurrentTheme.Text,
        Font = Drawing.Fonts.Monospace,
        Visible = true,
        ZIndex = CurrentWindow.ZIndex + 4
    })
    
    local comboY = CursorY + 18
    
    CreateDrawing("Square", {
        Position = Vector2.new(CursorX, comboY),
        Size = Vector2.new(comboWidth, comboHeight),
        Color = CurrentTheme.Widget,
        Filled = true,
        Visible = true,
        ZIndex = CurrentWindow.ZIndex + 4
    })
    
    CreateDrawing("Square", {
        Position = Vector2.new(CursorX, comboY),
        Size = Vector2.new(comboWidth, comboHeight),
        Color = CurrentTheme.Border,
        Filled = false,
        Thickness = 1,
        Visible = true,
        ZIndex = CurrentWindow.ZIndex + 5
    })
    
    local selectedText = options[selectedIndex] or ""
    CreateDrawing("Text", {
        Text = selectedText,
        Position = Vector2.new(CursorX + 5, comboY + 3),
        Size = 13,
        Color = CurrentTheme.Text,
        Font = Drawing.Fonts.Monospace,
        Visible = true,
        ZIndex = CurrentWindow.ZIndex + 6
    })
    
    CursorY = comboY + comboHeight + 5
    SameLineActive = false
    
    return selectedIndex
end

function ImGui.ProgressBar(fraction, label)
    if not CurrentWindow then return end
    
    local barWidth = 200
    local barHeight = 20
    
    CreateDrawing("Square", {
        Position = Vector2.new(CursorX, CursorY),
        Size = Vector2.new(barWidth, barHeight),
        Color = CurrentTheme.Widget,
        Filled = true,
        Visible = true,
        ZIndex = CurrentWindow.ZIndex + 4
    })
    
    local fillWidth = barWidth * math.clamp(fraction, 0, 1)
    CreateDrawing("Square", {
        Position = Vector2.new(CursorX, CursorY),
        Size = Vector2.new(fillWidth, barHeight),
        Color = CurrentTheme.Accent,
        Filled = true,
        Visible = true,
        ZIndex = CurrentWindow.ZIndex + 5
    })
    
    CreateDrawing("Square", {
        Position = Vector2.new(CursorX, CursorY),
        Size = Vector2.new(barWidth, barHeight),
        Color = CurrentTheme.Border,
        Filled = false,
        Thickness = 1,
        Visible = true,
        ZIndex = CurrentWindow.ZIndex + 6
    })
    
    if label then
        CreateDrawing("Text", {
            Text = label,
            Position = Vector2.new(CursorX + 5, CursorY + 3),
            Size = 13,
            Color = CurrentTheme.Text,
            Font = Drawing.Fonts.Monospace,
            Visible = true,
            ZIndex = CurrentWindow.ZIndex + 7
        })
    end
    
    CursorY = CursorY + barHeight + 5
    SameLineActive = false
end

function ImGui.BeginTabBar(id)
    if not CurrentWindow then return end
    
    if not TabBars[id] then
        TabBars[id] = {
            Tabs = {},
            ActiveTab = 1
        }
    end
    
    CurrentTabBar = TabBars[id]
    CurrentTabBar.Tabs = {}
    CurrentTabBar.StartY = CursorY
end

function ImGui.BeginTab(label)
    if not CurrentWindow or not CurrentTabBar then return false end
    
    table.insert(CurrentTabBar.Tabs, label)
    local tabIndex = #CurrentTabBar.Tabs
    
    -- Draw tab headers on first tab
    if tabIndex == 1 then
        local tabX = CursorX
        for i, tabLabel in ipairs(CurrentTabBar.Tabs) do
            -- This will be drawn when all tabs are registered
        end
    end
    
    return tabIndex == CurrentTabBar.ActiveTab
end

function ImGui.EndTab()
    -- Tab content rendering handled by BeginTab return value
end

function ImGui.EndTabBar()
    if not CurrentWindow or not CurrentTabBar then return end
    
    -- Draw all tab headers
    local tabX = CursorX
    local tabHeight = 25
    local tabWidth = 100
    
    for i, label in ipairs(CurrentTabBar.Tabs) do
        local isActive = i == CurrentTabBar.ActiveTab
        local isHovered = MousePos.X >= tabX and MousePos.X <= tabX + tabWidth and
                          MousePos.Y >= CurrentTabBar.StartY and MousePos.Y <= CurrentTabBar.StartY + tabHeight
        
        if isHovered and MouseDown and not LastMouseDown then
            CurrentTabBar.ActiveTab = i
            isActive = true
        end
        
        CreateDrawing("Square", {
            Position = Vector2.new(tabX, CurrentTabBar.StartY),
            Size = Vector2.new(tabWidth, tabHeight),
            Color = isActive and CurrentTheme.Accent or (isHovered and CurrentTheme.WidgetHover or CurrentTheme.Widget),
            Filled = true,
            Visible = true,
            ZIndex = CurrentWindow.ZIndex + 4
        })
        
        CreateDrawing("Text", {
            Text = label,
            Position = Vector2.new(tabX + 10, CurrentTabBar.StartY + 6),
            Size = 13,
            Color = CurrentTheme.Text,
            Font = Drawing.Fonts.Monospace,
            Visible = true,
            ZIndex = CurrentWindow.ZIndex + 5
        })
        
        tabX = tabX + tabWidth
    end
    
    CursorY = CurrentTabBar.StartY + tabHeight + 10
    CurrentTabBar = nil
end

function ImGui.Tooltip(text)
    -- Tooltip shown on hover of previous widget
    -- Simplified implementation
end

-- [ Theme Management ]
function ImGui.SetTheme(themeName)
    if Themes[themeName] then
        CurrentTheme = Themes[themeName]
    end
end

-- [ Render Loop ]
function ImGui.Render()
    ClearDrawings()
    LastMouseDown = MouseDown
end

-- To use ProggyClean.ttf exactly:
-- local fontId = getcustomasset("ProggyClean.ttf")
-- Then apply fontId to Drawing text objects if your executor supports it

return ImGui
