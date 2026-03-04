--[[
    imgui_loader.lua
    Roblox ImGui Port - Core Library
    Replicates Dear ImGui's look and feel using Drawing API
    
    Font: ProggyClean.ttf (ImGui default)
    Executor custom font loading:
    local ProggyClean = getcustomasset and getcustomasset("ProggyClean.ttf")
    Apply via Drawing text .Font property if supported
]]

local ImGui = {}

-- [ Services ]
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

-- [ ImGui Color Scheme - Exact Default Dark Theme ]
local Colors = {
    TitleBg = Color3.fromRGB(41, 74, 122),
    TitleText = Color3.fromRGB(255, 255, 255),
    WindowBg = Color3.fromRGB(15, 15, 15),
    Border = Color3.fromRGB(110, 110, 128),
    Text = Color3.fromRGB(255, 255, 255),
    Button = Color3.fromRGB(66, 150, 250),
    ButtonHovered = Color3.fromRGB(66, 150, 250),
    ButtonActive = Color3.fromRGB(66, 150, 250),
    Header = Color3.fromRGB(66, 150, 250),
    FrameBg = Color3.fromRGB(41, 41, 41),
    Separator = Color3.fromRGB(110, 110, 128),
    CheckMark = Color3.fromRGB(66, 150, 250),
    SliderGrab = Color3.fromRGB(66, 150, 250),
    TabActive = Color3.fromRGB(31, 31, 31),
    TabInactive = Color3.fromRGB(21, 21, 21),
}

-- Alpha blending helper
local function BlendColor(color, alpha, bgColor)
    bgColor = bgColor or Colors.WindowBg
    return Color3.new(
        bgColor.R + (color.R - bgColor.R) * alpha,
        bgColor.G + (color.G - bgColor.G) * alpha,
        bgColor.B + (color.B - bgColor.B) * alpha
    )
end

-- [ Retained Mode Drawing Pool - NO FLICKERING ]
local drawPool = {}
local drawCursor = 0

local function getDrawing(drawType)
    drawCursor = drawCursor + 1
    if not drawPool[drawCursor] then
        drawPool[drawCursor] = Drawing.new(drawType)
    end
    local d = drawPool[drawCursor]
    d.Visible = true
    return d
end

local function beginFrame()
    drawCursor = 0
end

local function endFrame()
    for i = drawCursor + 1, #drawPool do
        drawPool[i].Visible = false
    end
end

-- [ Input State ]
local mousePos = Vector2.new(0, 0)
local mouseDown = false
local mouseClicked = false
local lastMouseDown = false

UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        mousePos = Vector2.new(input.Position.X, input.Position.Y)
    end
end)

UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        mouseDown = true
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        mouseDown = false
    end
end)

-- [ Window Management ]
local windows = {}
local currentWindow = nil
local draggedWindow = nil
local dragOffset = Vector2.new(0, 0)

-- Window cursor state
local cursorX = 0
local cursorY = 0
local itemSpacing = 4
local windowPadding = 8

-- [ Widget Dimensions ]
local TITLE_BAR_HEIGHT = 19
local BUTTON_HEIGHT = 21
local TEXT_HEIGHT = 13
local CHECKBOX_SIZE = 13
local SLIDER_HEIGHT = 21
local INPUT_HEIGHT = 21
local HEADER_HEIGHT = 21
local SEPARATOR_HEIGHT = 1
local FONT_SIZE = 13

-- [ Helper Functions ]
local function isMouseInRect(x, y, w, h)
    return mousePos.X >= x and mousePos.X <= x + w and
           mousePos.Y >= y and mousePos.Y <= y + h
end

-- [ Core API ]
function ImGui.Begin(title, flags)
    flags = flags or {}
    
    if not windows[title] then
        windows[title] = {
            title = title,
            pos = Vector2.new(100 + (#windows * 30), 100 + (#windows * 30)),
            size = Vector2.new(400, 300),
            collapsed = false,
            visible = true,
            collapsingHeaders = {},
        }
    end
    
    currentWindow = windows[title]
    
    if not currentWindow.visible then
        return false
    end
    
    local win = currentWindow
    local titleBarY = win.pos.Y
    local titleBarHeight = TITLE_BAR_HEIGHT
    
    -- Handle window dragging
    if isMouseInRect(win.pos.X, titleBarY, win.size.X - 20, titleBarHeight) then
        if mouseDown and not lastMouseDown then
            draggedWindow = win
            dragOffset = mousePos - win.pos
        end
    end
    
    if draggedWindow == win and mouseDown then
        win.pos = mousePos - dragOffset
    elseif not mouseDown then
        draggedWindow = nil
    end
    
    -- Handle collapse toggle
    if isMouseInRect(win.pos.X, titleBarY, 20, titleBarHeight) then
        if mouseDown and not lastMouseDown then
            win.collapsed = not win.collapsed
        end
    end
    
    -- Handle close button
    local closeX = win.pos.X + win.size.X - 18
    if isMouseInRect(closeX, titleBarY + 2, 15, 15) then
        if mouseDown and not lastMouseDown then
            win.visible = false
            return false
        end
    end
    
    -- Draw window background
    local bg = getDrawing("Square")
    bg.Position = win.pos
    bg.Size = win.size
    bg.Color = Colors.WindowBg
    bg.Filled = true
    bg.Transparency = 0.95
    bg.ZIndex = 1
    
    -- Draw window border
    local border = getDrawing("Square")
    border.Position = win.pos
    border.Size = win.size
    border.Color = Colors.Border
    border.Filled = false
    border.Thickness = 1
    border.ZIndex = 2
    
    -- Draw title bar
    local titleBar = getDrawing("Square")
    titleBar.Position = win.pos
    titleBar.Size = Vector2.new(win.size.X, titleBarHeight)
    titleBar.Color = Colors.TitleBg
    titleBar.Filled = true
    titleBar.ZIndex = 3
    
    -- Draw collapse arrow
    local arrow = getDrawing("Text")
    arrow.Text = win.collapsed and "▶" or "▼"
    arrow.Position = win.pos + Vector2.new(4, 2)
    arrow.Size = FONT_SIZE
    arrow.Color = Colors.TitleText
    arrow.Font = Drawing.Fonts.Monospace
    arrow.ZIndex = 4
    
    -- Draw title text
    local titleText = getDrawing("Text")
    titleText.Text = title
    titleText.Position = win.pos + Vector2.new(20, 2)
    titleText.Size = FONT_SIZE
    titleText.Color = Colors.TitleText
    titleText.Font = Drawing.Fonts.Monospace
    titleText.ZIndex = 4
    
    -- Draw close button
    local closeBtn = getDrawing("Text")
    closeBtn.Text = "X"
    closeBtn.Position = Vector2.new(closeX, titleBarY + 2)
    closeBtn.Size = FONT_SIZE
    closeBtn.Color = Colors.TitleText
    closeBtn.Font = Drawing.Fonts.Monospace
    closeBtn.ZIndex = 4
    
    -- Initialize cursor
    cursorX = win.pos.X + windowPadding
    cursorY = win.pos.Y + titleBarHeight + windowPadding
    
    return not win.collapsed
end

function ImGui.End()
    currentWindow = nil
end

-- [ Widgets ]
function ImGui.Text(text)
    if not currentWindow then return end
    
    local txt = getDrawing("Text")
    txt.Text = text
    txt.Position = Vector2.new(cursorX, cursorY)
    txt.Size = FONT_SIZE
    txt.Color = Colors.Text
    txt.Font = Drawing.Fonts.Monospace
    txt.ZIndex = 5
    
    cursorY = cursorY + TEXT_HEIGHT + itemSpacing
end

function ImGui.Button(label)
    if not currentWindow then return false end
    
    local buttonWidth = 80
    local buttonHeight = BUTTON_HEIGHT
    local clicked = false
    
    local hovered = isMouseInRect(cursorX, cursorY, buttonWidth, buttonHeight)
    
    local buttonColor = Colors.Button
    local alpha = 0.4
    if hovered then
        alpha = mouseDown and 1.0 or 0.6
        if mouseDown and not lastMouseDown then
            clicked = true
        end
    end
    
    buttonColor = BlendColor(buttonColor, alpha)
    
    local btn = getDrawing("Square")
    btn.Position = Vector2.new(cursorX, cursorY)
    btn.Size = Vector2.new(buttonWidth, buttonHeight)
    btn.Color = buttonColor
    btn.Filled = true
    btn.ZIndex = 5
    
    local btnBorder = getDrawing("Square")
    btnBorder.Position = Vector2.new(cursorX, cursorY)
    btnBorder.Size = Vector2.new(buttonWidth, buttonHeight)
    btnBorder.Color = Colors.Border
    btnBorder.Filled = false
    btnBorder.Thickness = 1
    btnBorder.ZIndex = 6
    
    local btnText = getDrawing("Text")
    btnText.Text = label
    btnText.Position = Vector2.new(cursorX + 4, cursorY + 4)
    btnText.Size = FONT_SIZE
    btnText.Color = Colors.Text
    btnText.Font = Drawing.Fonts.Monospace
    btnText.ZIndex = 7
    
    cursorY = cursorY + buttonHeight + itemSpacing
    
    return clicked
end

function ImGui.Checkbox(label, value)
    if not currentWindow then return value end
    
    local boxSize = CHECKBOX_SIZE
    local hovered = isMouseInRect(cursorX, cursorY, boxSize, boxSize)
    
    if hovered and mouseDown and not lastMouseDown then
        value = not value
    end
    
    local box = getDrawing("Square")
    box.Position = Vector2.new(cursorX, cursorY)
    box.Size = Vector2.new(boxSize, boxSize)
    box.Color = value and Colors.CheckMark or Colors.FrameBg
    box.Filled = true
    box.ZIndex = 5
    
    local boxBorder = getDrawing("Square")
    boxBorder.Position = Vector2.new(cursorX, cursorY)
    boxBorder.Size = Vector2.new(boxSize, boxSize)
    boxBorder.Color = Colors.Border
    boxBorder.Filled = false
    boxBorder.Thickness = 1
    boxBorder.ZIndex = 6
    
    if value then
        local check = getDrawing("Text")
        check.Text = "✓"
        check.Position = Vector2.new(cursorX + 1, cursorY - 1)
        check.Size = FONT_SIZE
        check.Color = Colors.Text
        check.Font = Drawing.Fonts.Monospace
        check.ZIndex = 7
    end
    
    local labelText = getDrawing("Text")
    labelText.Text = label
    labelText.Position = Vector2.new(cursorX + boxSize + 8, cursorY)
    labelText.Size = FONT_SIZE
    labelText.Color = Colors.Text
    labelText.Font = Drawing.Fonts.Monospace
    labelText.ZIndex = 5
    
    cursorY = cursorY + boxSize + itemSpacing
    
    return value
end

function ImGui.SliderFloat(label, value, minVal, maxVal)
    if not currentWindow then return value end
    
    local sliderWidth = 200
    local sliderHeight = SLIDER_HEIGHT
    local trackHeight = 4
    local grabWidth = 10
    
    -- Draw label
    local labelText = getDrawing("Text")
    labelText.Text = label
    labelText.Position = Vector2.new(cursorX, cursorY)
    labelText.Size = FONT_SIZE
    labelText.Color = Colors.Text
    labelText.Font = Drawing.Fonts.Monospace
    labelText.ZIndex = 5
    
    cursorY = cursorY + TEXT_HEIGHT + 2
    
    -- Draw slider track
    local trackY = cursorY + (sliderHeight - trackHeight) / 2
    local track = getDrawing("Square")
    track.Position = Vector2.new(cursorX, trackY)
    track.Size = Vector2.new(sliderWidth, trackHeight)
    track.Color = Colors.FrameBg
    track.Filled = true
    track.ZIndex = 5
    
    -- Handle slider interaction
    local hovered = isMouseInRect(cursorX, cursorY, sliderWidth, sliderHeight)
    if hovered and mouseDown then
        local mouseX = math.clamp(mousePos.X - cursorX, 0, sliderWidth)
        local normalized = mouseX / sliderWidth
        value = minVal + (maxVal - minVal) * normalized
    end
    
    -- Draw slider grab
    local normalized = (value - minVal) / (maxVal - minVal)
    local grabX = cursorX + (sliderWidth - grabWidth) * normalized
    
    local grab = getDrawing("Square")
    grab.Position = Vector2.new(grabX, cursorY)
    grab.Size = Vector2.new(grabWidth, sliderHeight)
    grab.Color = Colors.SliderGrab
    grab.Filled = true
    grab.ZIndex = 6
    
    -- Draw value text
    local valueText = getDrawing("Text")
    valueText.Text = string.format("%.3f", value)
    valueText.Position = Vector2.new(cursorX + sliderWidth + 10, cursorY + 4)
    valueText.Size = FONT_SIZE
    valueText.Color = Colors.Text
    valueText.Font = Drawing.Fonts.Monospace
    valueText.ZIndex = 5
    
    cursorY = cursorY + sliderHeight + itemSpacing
    
    return value
end

function ImGui.SliderInt(label, value, minVal, maxVal)
    local result = ImGui.SliderFloat(label, value, minVal, maxVal)
    return math.floor(result + 0.5)
end

function ImGui.InputText(label, text)
    if not currentWindow then return text end
    
    local inputWidth = 200
    local inputHeight = INPUT_HEIGHT
    
    -- Draw label
    local labelText = getDrawing("Text")
    labelText.Text = label
    labelText.Position = Vector2.new(cursorX, cursorY)
    labelText.Size = FONT_SIZE
    labelText.Color = Colors.Text
    labelText.Font = Drawing.Fonts.Monospace
    labelText.ZIndex = 5
    
    cursorY = cursorY + TEXT_HEIGHT + 2
    
    -- Draw input box
    local inputBox = getDrawing("Square")
    inputBox.Position = Vector2.new(cursorX, cursorY)
    inputBox.Size = Vector2.new(inputWidth, inputHeight)
    inputBox.Color = Colors.FrameBg
    inputBox.Filled = true
    inputBox.ZIndex = 5
    
    local inputBorder = getDrawing("Square")
    inputBorder.Position = Vector2.new(cursorX, cursorY)
    inputBorder.Size = Vector2.new(inputWidth, inputHeight)
    inputBorder.Color = Colors.Border
    inputBorder.Filled = false
    inputBorder.Thickness = 1
    inputBorder.ZIndex = 6
    
    -- Draw text
    local inputText = getDrawing("Text")
    inputText.Text = text
    inputText.Position = Vector2.new(cursorX + 4, cursorY + 4)
    inputText.Size = FONT_SIZE
    inputText.Color = Colors.Text
    inputText.Font = Drawing.Fonts.Monospace
    inputText.ZIndex = 7
    
    cursorY = cursorY + inputHeight + itemSpacing
    
    return text
end

function ImGui.ColorEdit3(label, r, g, b)
    if not currentWindow then return r, g, b end
    
    -- Draw label
    local labelText = getDrawing("Text")
    labelText.Text = label
    labelText.Position = Vector2.new(cursorX, cursorY)
    labelText.Size = FONT_SIZE
    labelText.Color = Colors.Text
    labelText.Font = Drawing.Fonts.Monospace
    labelText.ZIndex = 5
    
    cursorY = cursorY + TEXT_HEIGHT + 2
    
    -- Draw color preview
    local previewSize = 30
    local preview = getDrawing("Square")
    preview.Position = Vector2.new(cursorX, cursorY)
    preview.Size = Vector2.new(previewSize, previewSize)
    preview.Color = Color3.fromRGB(r, g, b)
    preview.Filled = true
    preview.ZIndex = 5
    
    local previewBorder = getDrawing("Square")
    previewBorder.Position = Vector2.new(cursorX, cursorY)
    previewBorder.Size = Vector2.new(previewSize, previewSize)
    previewBorder.Color = Colors.Border
    previewBorder.Filled = false
    previewBorder.Thickness = 1
    previewBorder.ZIndex = 6
    
    cursorY = cursorY + previewSize + itemSpacing
    
    -- R, G, B sliders
    r = ImGui.SliderInt("R", r, 0, 255)
    g = ImGui.SliderInt("G", g, 0, 255)
    b = ImGui.SliderInt("B", b, 0, 255)
    
    return r, g, b
end

function ImGui.Separator()
    if not currentWindow then return end
    
    local sepWidth = currentWindow.size.X - windowPadding * 2
    
    local sep = getDrawing("Line")
    sep.From = Vector2.new(cursorX, cursorY)
    sep.To = Vector2.new(cursorX + sepWidth, cursorY)
    sep.Color = Colors.Separator
    sep.Thickness = 1
    sep.ZIndex = 5
    
    cursorY = cursorY + SEPARATOR_HEIGHT + itemSpacing
end

function ImGui.SameLine()
    -- Move cursor to same line for next widget
    cursorX = cursorX + 120
    cursorY = cursorY - (TEXT_HEIGHT + itemSpacing)
end

function ImGui.CollapsingHeader(label)
    if not currentWindow then return false end
    
    local win = currentWindow
    if not win.collapsingHeaders[label] then
        win.collapsingHeaders[label] = false
    end
    
    local headerWidth = win.size.X - windowPadding * 2
    local headerHeight = HEADER_HEIGHT
    
    local hovered = isMouseInRect(cursorX, cursorY, headerWidth, headerHeight)
    
    if hovered and mouseDown and not lastMouseDown then
        win.collapsingHeaders[label] = not win.collapsingHeaders[label]
    end
    
    local headerColor = BlendColor(Colors.Header, 0.31)
    if hovered then
        headerColor = BlendColor(Colors.Header, 0.45)
    end
    
    local header = getDrawing("Square")
    header.Position = Vector2.new(cursorX, cursorY)
    header.Size = Vector2.new(headerWidth, headerHeight)
    header.Color = headerColor
    header.Filled = true
    header.ZIndex = 5
    
    local arrow = getDrawing("Text")
    arrow.Text = win.collapsingHeaders[label] and "▼" or "▶"
    arrow.Position = Vector2.new(cursorX + 4, cursorY + 4)
    arrow.Size = FONT_SIZE
    arrow.Color = Colors.Text
    arrow.Font = Drawing.Fonts.Monospace
    arrow.ZIndex = 6
    
    local headerText = getDrawing("Text")
    headerText.Text = label
    headerText.Position = Vector2.new(cursorX + 20, cursorY + 4)
    headerText.Size = FONT_SIZE
    headerText.Color = Colors.Text
    headerText.Font = Drawing.Fonts.Monospace
    headerText.ZIndex = 6
    
    cursorY = cursorY + headerHeight + itemSpacing
    
    return win.collapsingHeaders[label]
end

function ImGui.Combo(label, selectedIndex, options)
    if not currentWindow then return selectedIndex end
    
    local comboWidth = 200
    local comboHeight = INPUT_HEIGHT
    
    -- Draw label
    local labelText = getDrawing("Text")
    labelText.Text = label
    labelText.Position = Vector2.new(cursorX, cursorY)
    labelText.Size = FONT_SIZE
    labelText.Color = Colors.Text
    labelText.Font = Drawing.Fonts.Monospace
    labelText.ZIndex = 5
    
    cursorY = cursorY + TEXT_HEIGHT + 2
    
    -- Draw combo box
    local combo = getDrawing("Square")
    combo.Position = Vector2.new(cursorX, cursorY)
    combo.Size = Vector2.new(comboWidth, comboHeight)
    combo.Color = Colors.FrameBg
    combo.Filled = true
    combo.ZIndex = 5
    
    local comboBorder = getDrawing("Square")
    comboBorder.Position = Vector2.new(cursorX, cursorY)
    comboBorder.Size = Vector2.new(comboWidth, comboHeight)
    comboBorder.Color = Colors.Border
    comboBorder.Filled = false
    comboBorder.Thickness = 1
    comboBorder.ZIndex = 6
    
    -- Draw selected text
    local selectedText = options[selectedIndex] or ""
    local comboText = getDrawing("Text")
    comboText.Text = selectedText
    comboText.Position = Vector2.new(cursorX + 4, cursorY + 4)
    comboText.Size = FONT_SIZE
    comboText.Color = Colors.Text
    comboText.Font = Drawing.Fonts.Monospace
    comboText.ZIndex = 7
    
    cursorY = cursorY + comboHeight + itemSpacing
    
    return selectedIndex
end

function ImGui.ProgressBar(fraction, labelText)
    if not currentWindow then return end
    
    local barWidth = 200
    local barHeight = 15
    
    -- Draw background
    local barBg = getDrawing("Square")
    barBg.Position = Vector2.new(cursorX, cursorY)
    barBg.Size = Vector2.new(barWidth, barHeight)
    barBg.Color = Colors.FrameBg
    barBg.Filled = true
    barBg.ZIndex = 5
    
    -- Draw fill
    local fillWidth = barWidth * math.clamp(fraction, 0, 1)
    if fillWidth > 0 then
        local barFill = getDrawing("Square")
        barFill.Position = Vector2.new(cursorX, cursorY)
        barFill.Size = Vector2.new(fillWidth, barHeight)
        barFill.Color = Colors.Button
        barFill.Filled = true
        barFill.ZIndex = 6
    end
    
    -- Draw border
    local barBorder = getDrawing("Square")
    barBorder.Position = Vector2.new(cursorX, cursorY)
    barBorder.Size = Vector2.new(barWidth, barHeight)
    barBorder.Color = Colors.Border
    barBorder.Filled = false
    barBorder.Thickness = 1
    barBorder.ZIndex = 7
    
    -- Draw label
    if labelText then
        local label = getDrawing("Text")
        label.Text = labelText
        label.Position = Vector2.new(cursorX + 4, cursorY + 1)
        label.Size = FONT_SIZE
        label.Color = Colors.Text
        label.Font = Drawing.Fonts.Monospace
        label.ZIndex = 8
    end
    
    cursorY = cursorY + barHeight + itemSpacing
end

-- [ Render Loop ]
function ImGui.Render()
    beginFrame()
    
    -- Update click state
    mouseClicked = not mouseDown and lastMouseDown
    lastMouseDown = mouseDown
end

function ImGui.EndRender()
    endFrame()
end

-- [ Utility ]
function ImGui.SetWindowVisible(title, visible)
    if windows[title] then
        windows[title].visible = visible
    end
end

return ImGui
