-- imgui_loader.lua
-- Core UI Framework Host for Script Executor
-- Manages main window, rendering loop, and module registration system

local ImGui = require("imgui")

-- Global UI Registration System
UI = {
    Tabs = {},
    Windows = {},
    Menus = {},
    State = {
        showDemo = false,
        showExtra = false,
        speed = 50.0,
        accentColor = {0.2, 0.4, 0.8, 1.0},
        counter = 0,
        uiVisible = true,
        reloadRequested = false
    }
}

-- Registration API
function UI:RegisterTab(name, callback)
    table.insert(self.Tabs, {name = name, callback = callback})
end

function UI:RegisterWindow(name, callback)
    table.insert(self.Windows, {name = name, callback = callback, open = true})
end

function UI:RegisterMenu(name, callback)
    table.insert(self.Menus, {name = name, callback = callback})
end

function UI:RequestReload()
    self.State.reloadRequested = true
end

-- Apply Dark Theme with Blue Accent
local function ApplyTheme()
    local style = ImGui.GetStyle()
    
    -- Colors
    local colors = style.Colors
    colors[ImGui.Col.WindowBg] = ImGui.ImVec4(0.1, 0.1, 0.12, 1.0)
    colors[ImGui.Col.ChildBg] = ImGui.ImVec4(0.12, 0.12, 0.14, 1.0)
    colors[ImGui.Col.Border] = ImGui.ImVec4(0.2, 0.2, 0.25, 1.0)
    colors[ImGui.Col.FrameBg] = ImGui.ImVec4(0.15, 0.15, 0.18, 1.0)
    colors[ImGui.Col.FrameBgHovered] = ImGui.ImVec4(0.2, 0.4, 0.8, 0.4)
    colors[ImGui.Col.FrameBgActive] = ImGui.ImVec4(0.2, 0.4, 0.8, 0.6)
    colors[ImGui.Col.TitleBg] = ImGui.ImVec4(0.1, 0.1, 0.12, 1.0)
    colors[ImGui.Col.TitleBgActive] = ImGui.ImVec4(0.15, 0.15, 0.18, 1.0)
    colors[ImGui.Col.Button] = ImGui.ImVec4(0.2, 0.4, 0.8, 0.8)
    colors[ImGui.Col.ButtonHovered] = ImGui.ImVec4(0.3, 0.5, 0.9, 1.0)
    colors[ImGui.Col.ButtonActive] = ImGui.ImVec4(0.15, 0.3, 0.7, 1.0)
    colors[ImGui.Col.Header] = ImGui.ImVec4(0.2, 0.4, 0.8, 0.6)
    colors[ImGui.Col.HeaderHovered] = ImGui.ImVec4(0.3, 0.5, 0.9, 0.8)
    colors[ImGui.Col.HeaderActive] = ImGui.ImVec4(0.2, 0.4, 0.8, 1.0)
    colors[ImGui.Col.Tab] = ImGui.ImVec4(0.15, 0.15, 0.18, 1.0)
    colors[ImGui.Col.TabHovered] = ImGui.ImVec4(0.3, 0.5, 0.9, 0.8)
    colors[ImGui.Col.TabActive] = ImGui.ImVec4(0.2, 0.4, 0.8, 1.0)
    colors[ImGui.Col.CheckMark] = ImGui.ImVec4(0.3, 0.6, 1.0, 1.0)
    colors[ImGui.Col.SliderGrab] = ImGui.ImVec4(0.2, 0.4, 0.8, 1.0)
    colors[ImGui.Col.SliderGrabActive] = ImGui.ImVec4(0.3, 0.5, 0.9, 1.0)
    
    -- Spacing
    style.WindowPadding = ImGui.ImVec2(12, 12)
    style.FramePadding = ImGui.ImVec2(8, 4)
    style.ItemSpacing = ImGui.ImVec2(8, 6)
    style.ItemInnerSpacing = ImGui.ImVec2(6, 4)
    style.WindowRounding = 6.0
    style.FrameRounding = 4.0
    style.GrabRounding = 3.0
end

-- Load Font
local function LoadFont()
    local io = ImGui.GetIO()
    io.Fonts:AddFontFromFileTTF("ProggyClean.ttf", 13.0)
end

-- Render Left Panel (Main Controls)
local function RenderMainPanel()
    ImGui.BeginChild("MainPanel", ImGui.ImVec2(300, 0), true)
    
    ImGui.TextColored(ImGui.ImVec4(0.3, 0.6, 1.0, 1.0), "Executor Control Panel")
    ImGui.Separator()
    ImGui.Spacing()
    
    -- Checkboxes
    UI.State.showDemo = ImGui.Checkbox("Show Demo", UI.State.showDemo)
    UI.State.showExtra = ImGui.Checkbox("Show Extra Window", UI.State.showExtra)
    
    ImGui.Spacing()
    
    -- Speed Slider
    UI.State.speed = ImGui.SliderFloat("Speed", UI.State.speed, 0.0, 100.0)
    
    ImGui.Spacing()
    
    -- Accent Color Picker
    UI.State.accentColor = ImGui.ColorEdit4("Accent Color", UI.State.accentColor)
    
    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()
    
    -- Inject Button
    if ImGui.Button("Inject", ImGui.ImVec2(280, 30)) then
        UI.State.counter = UI.State.counter + 1
    end
    
    ImGui.Spacing()
    ImGui.Text("Injections: " .. UI.State.counter)
    
    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()
    
    -- FPS Display
    local fps = ImGui.GetIO().Framerate
    ImGui.TextColored(ImGui.ImVec4(0.3, 1.0, 0.3, 1.0), string.format("FPS: %.1f", fps))
    
    ImGui.EndChild()
end

-- Render Right Panel (Modules)
local function RenderModulesPanel()
    ImGui.BeginChild("ModulesPanel", ImGui.ImVec2(0, 0), true)
    
    ImGui.TextColored(ImGui.ImVec4(0.3, 0.6, 1.0, 1.0), "Modules")
    ImGui.Separator()
    ImGui.Spacing()
    
    if #UI.Tabs == 0 then
        ImGui.TextWrapped("No modules loaded. Check imgui_script.lua")
    else
        if ImGui.BeginTabBar("ModuleTabs") then
            for _, tab in ipairs(UI.Tabs) do
                if ImGui.BeginTabItem(tab.name) then
                    ImGui.Spacing()
                    tab.callback()
                    ImGui.EndTabItem()
                end
            end
            ImGui.EndTabBar()
        end
    end
    
    ImGui.EndChild()
end

-- Render Extra Window
local function RenderExtraWindow()
    if not UI.State.showExtra then return end
    
    ImGui.SetNextWindowSize(ImGui.ImVec2(300, 200), ImGui.Cond.FirstUseEver)
    local open = ImGui.Begin("Extra Window", true)
    
    if open then
        ImGui.Text("This is an extra window!")
        ImGui.Spacing()
        ImGui.TextWrapped("You can add additional content here or close it using the checkbox in the main panel.")
        
        if ImGui.Button("Close") then
            UI.State.showExtra = false
        end
    else
        UI.State.showExtra = false
    end
    
    ImGui.End()
end

-- Render Registered Windows
local function RenderRegisteredWindows()
    for _, window in ipairs(UI.Windows) do
        if window.open then
            ImGui.SetNextWindowSize(ImGui.ImVec2(400, 300), ImGui.Cond.FirstUseEver)
            window.open = ImGui.Begin(window.name, true)
            
            if window.open then
                window.callback()
            end
            
            ImGui.End()
        end
    end
end

-- Main Render Loop
local function RenderUI()
    if not UI.State.uiVisible then return end
    
    -- Main Window
    ImGui.SetNextWindowSize(ImGui.ImVec2(900, 600), ImGui.Cond.FirstUseEver)
    ImGui.Begin("Executor UI Framework", true, ImGui.WindowFlags.NoCollapse)
    
    -- Split into two panels
    RenderMainPanel()
    ImGui.SameLine()
    RenderModulesPanel()
    
    ImGui.End()
    
    -- Extra Window
    RenderExtraWindow()
    
    -- Registered Windows
    RenderRegisteredWindows()
    
    -- Demo Window
    if UI.State.showDemo then
        ImGui.ShowDemoWindow()
    end
end

-- Hot Reload Module Script
local function ReloadModuleScript()
    if UI.State.reloadRequested then
        UI.Tabs = {}
        UI.Windows = {}
        UI.Menus = {}
        
        package.loaded["imgui_script"] = nil
        local success, err = pcall(require, "imgui_script")
        
        if not success then
            print("Failed to reload imgui_script.lua: " .. tostring(err))
        end
        
        UI.State.reloadRequested = false
    end
end

-- Initialize Framework
local function Initialize()
    ApplyTheme()
    LoadFont()
    
    -- Load module script
    local success, err = pcall(require, "imgui_script")
    if not success then
        print("Warning: Could not load imgui_script.lua: " .. tostring(err))
    end
end

-- Keybind Handler (Insert key toggles UI)
local function HandleKeybinds()
    if ImGui.IsKeyPressed(ImGui.Key.Insert) then
        UI.State.uiVisible = not UI.State.uiVisible
    end
end

-- Main Entry Point
Initialize()

-- Frame Callback (called every frame by executor)
function OnFrame()
    HandleKeybinds()
    ReloadModuleScript()
    RenderUI()
end

-- Export for executor environments that need explicit render call
return {
    Render = RenderUI,
    Initialize = Initialize,
    UI = UI
}
