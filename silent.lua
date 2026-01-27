_G.AimbotConfig = _G.AimbotConfig or {
    Enabled = false,
    TeamCheck = "Team",         
    TargetPart = {"Random"},      
    MaxDistance = 1000,         
    SwitchThreshold = 1,
    WhitelistedUsers = {}, 
    WhitelistedTeams = {}, 
    FocusList = {},
    FocusMode = false,
    UseLegitOffset = true,
    HitChance = 60,
    WallCheck = true,
    FOVSize = 200,
    ShowFOV = true,
    FOVBehavior = "Center",
    FOVColor1 = Color3.fromRGB(255, 255, 255), 
    ShowHighlight = true,
    HighlightColor = Color3.fromRGB(255, 60, 60),
    ESP = {
        Enabled = true,
        ShowName = true,
        ShowTeam = true,
        ShowHealth = true,
        ShowWeapon = true,
        TextColor = Color3.fromRGB(255, 255, 255),
        OutlineColor = Color3.fromRGB(255, 60, 60),
    }
}

-- Serviços
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- Otimização
local Vector2New = Vector2.new
local Vector3New = Vector3.new
local CFrameNew = CFrame.new
local MathRandom = math.random
local IPairs = ipairs
local Pairs = pairs
local StringLower = string.lower
local StringFind = string.find
local MathHuge = math.huge
local MathFloor = math.floor

_G.SilentAimConnections = {}
_G.SilentAimActive = false
local ClosestHitPart = nil
local CurrentTargetCharacter = nil

-- Mapeamento completo
local PartMapping = {
    ["Head"] = {"Head"},
    ["Torso"] = {"HumanoidRootPart", "Torso", "UpperTorso", "LowerTorso"},
    ["Left Arm"] = {"Left Arm", "LeftUpperArm", "LeftLowerArm", "LeftHand"},
    ["Right Arm"] = {"Right Arm", "RightUpperArm", "RightLowerArm", "RightHand"},
    ["Left Leg"] = {"Left Leg", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot"},
    ["Right Leg"] = {"Right Leg", "RightUpperLeg", "RightLowerLeg", "RightFoot"}
}

local bulletFunctions = {
    "fire", "shoot", "bullet", "ammo", "projectile", 
    "missile", "rocket", "hit", "damage", "attack", 
    "cast", "ray", "target", "server", "remote", "action", 
    "mouse", "input", "create"
}

local function getLegitOffset()
    if not _G.AimbotConfig.UseLegitOffset then return Vector3New(0,0,0) end
    return Vector3New(
        (MathRandom() - 0.5) * (MathRandom(1, 35) / 10),
        (MathRandom() - 0.5) * (MathRandom(1, 35) / 10),
        (MathRandom() - 0.5) * (MathRandom(1, 35) / 10)
    )
end

local function isBulletRemote(name)
    name = StringLower(name)
    for _, keyword in IPairs(bulletFunctions) do
        if StringFind(name, keyword) then return true end
    end
    return false
end

local function isWhitelisted(player)
    if not player then return false end
    if #_G.AimbotConfig.WhitelistedUsers > 0 then
        if table.find(_G.AimbotConfig.WhitelistedUsers, player.Name) then return true end
    end
    if player.Team and #_G.AimbotConfig.WhitelistedTeams > 0 then
        if table.find(_G.AimbotConfig.WhitelistedTeams, player.Team.Name) then return true end
    end
    return false
end

local function toUpper(str)
    if not str then return "" end
    local map = {
        ["á"]="Á", ["é"]="É", ["í"]="Í", ["ó"]="Ó", ["ú"]="Ú",
        ["ã"]="Ã", ["õ"]="Õ", ["â"]="Â", ["ê"]="Ê", ["ô"]="Ô",
        ["ç"]="Ç", ["à"]="À"
    }
    local result = str:upper()
    for lower, upper in pairs(map) do
        result = result:gsub(lower, upper)
    end
    return result
end

local RayParams = RaycastParams.new()
RayParams.FilterType = Enum.RaycastFilterType.Exclude
RayParams.IgnoreWater = true

local function IsPartVisible(part, character)
    if not _G.AimbotConfig.WallCheck then return true end
    local origin = Camera.CFrame.Position
    local direction = part.Position - origin
    RayParams.FilterDescendantsInstances = {LocalPlayer.Character, character, Camera, _G.AimbotGui}
    local rayResult = Workspace:Raycast(origin, direction, RayParams)
    return rayResult == nil
end

local function GetBestPart(character)
    local targets = _G.AimbotConfig.TargetPart
    if typeof(targets) ~= "table" then targets = {targets} end
    
    if #targets == 0 or table.find(targets, "Random") then
        local priority = {"Head", "Torso", "Right Arm", "Left Arm", "Right Leg", "Left Leg"}
        for _, groupName in IPairs(priority) do
            local group = PartMapping[groupName]
            if group then
                for _, partName in IPairs(group) do
                    local part = character:FindFirstChild(partName)
                    if part and IsPartVisible(part, character) then return part end
                end
            end
        end
        return nil
    end

    for _, uiName in IPairs(targets) do
        local partsToCheck = PartMapping[uiName]
        if partsToCheck then
            for _, partName in IPairs(partsToCheck) do
                local part = character:FindFirstChild(partName)
                if part and IsPartVisible(part, character) then return part end
            end
        end
    end
    return nil
end

-- LÓGICA OTIMIZADA: Evita loops infinitos e crash
local function getClosestPlayer()
    local BestPart = nil
    local BestChar = nil
    local ShortestDistance = MathHuge

    local OriginPos
    if _G.AimbotConfig.FOVBehavior == "Mouse" then
        OriginPos = UserInputService:GetMouseLocation()
    else
        OriginPos = Vector2New(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    end

    local MyPos = Camera.CFrame.Position

    for _, Player in Pairs(Players:GetPlayers()) do
        if Player == LocalPlayer then continue end
        if _G.AimbotConfig.TeamCheck == "Team" and Player.Team == LocalPlayer.Team then continue end

        if _G.AimbotConfig.FocusMode then
            if not table.find(_G.AimbotConfig.FocusList, Player.Name) then continue end
        else
            if isWhitelisted(Player) then continue end
        end

        local Character = Player.Character
        if not Character then continue end

        local RootPart = Character:FindFirstChild("HumanoidRootPart")
        local Humanoid = Character:FindFirstChild("Humanoid")
        if not RootPart or not Humanoid or Humanoid.Health <= 0 then continue end

        local dist3D = (RootPart.Position - MyPos).Magnitude
        if dist3D > _G.AimbotConfig.MaxDistance then continue end

        -- LÓGICA CORRIGIDA (SEM CRASH):
        -- Verifica apenas as partes do corpo mapeadas, em vez de GetChildren()
        local playerInFOV = false
        local distanceToCenter = MathHuge

        for _, groupParts in Pairs(PartMapping) do
            for _, partName in IPairs(groupParts) do
                local part = Character:FindFirstChild(partName)
                if part then
                    local screenPos, onScreen = Camera:WorldToScreenPoint(part.Position)
                    if onScreen then
                        local dist2D = (OriginPos - Vector2New(screenPos.X, screenPos.Y)).Magnitude
                        if dist2D <= _G.AimbotConfig.FOVSize then
                            playerInFOV = true
                            if dist2D < distanceToCenter then
                                distanceToCenter = dist2D
                            end
                        end
                    end
                end
            end
        end

        if playerInFOV then
            if distanceToCenter < ShortestDistance then
                local PotentialPart = GetBestPart(Character)
                if PotentialPart then
                    ShortestDistance = distanceToCenter
                    BestPart = PotentialPart
                    BestChar = Character
                end
            end
        end
    end

    return BestPart, BestChar
end

_G.StopSilentAim = function()
    _G.SilentAimActive = false
    
    for _, conn in pairs(_G.SilentAimConnections) do
        if conn then conn:Disconnect() end
    end
    _G.SilentAimConnections = {}

    if _G.AimFOVCircle then _G.AimFOVCircle:Remove(); _G.AimFOVCircle = nil end
    if _G.AimbotGui then _G.AimbotGui:Destroy(); _G.AimbotGui = nil end
    if _G.AimHighlight then _G.AimHighlight:Destroy(); _G.AimHighlight = nil end
    
    ClosestHitPart = nil
    CurrentTargetCharacter = nil
end

_G.StartSilentAim = function()
    _G.StopSilentAim()
    _G.SilentAimActive = true
    local config = _G.AimbotConfig

    local fov_circle = Drawing.new("Circle")
    fov_circle.Visible = false
    fov_circle.Thickness = 2
    fov_circle.Transparency = 1
    fov_circle.Color = config.FOVColor1
    fov_circle.Filled = false
    fov_circle.NumSides = 64
    _G.AimFOVCircle = fov_circle

    local SafeParent = (gethui and gethui()) or CoreGui
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "HUD"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.IgnoreGuiInset = true 
    ScreenGui.Parent = SafeParent
    _G.AimbotGui = ScreenGui

    local TargetHighlight = Instance.new("Highlight")
    TargetHighlight.Name = "TargetFX"
    TargetHighlight.FillTransparency = 0.85
    TargetHighlight.OutlineTransparency = 0.1
    TargetHighlight.OutlineColor = config.HighlightColor
    TargetHighlight.FillColor = config.HighlightColor
    TargetHighlight.Parent = ScreenGui
    _G.AimHighlight = TargetHighlight

    local HeadBillboard = Instance.new("BillboardGui")
    HeadBillboard.Size = UDim2.new(0, 200, 0, 70) 
    HeadBillboard.StudsOffset = Vector3New(0, 4, 0)
    HeadBillboard.AlwaysOnTop = true
    HeadBillboard.Enabled = false
    HeadBillboard.Parent = ScreenGui

    local MainContainer = Instance.new("Frame")
    MainContainer.Name = "MainContainer"
    MainContainer.AnchorPoint = Vector2.new(0.5, 1)
    MainContainer.Position = UDim2.fromScale(0.5, 1)
    MainContainer.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    MainContainer.BackgroundTransparency = 0.2
    MainContainer.BorderSizePixel = 0
    MainContainer.Size = UDim2.new(1, 0, 1, 0)
    MainContainer.Parent = HeadBillboard

    local ContainerCorner = Instance.new("UICorner")
    ContainerCorner.CornerRadius = UDim.new(0, 6)
    ContainerCorner.Parent = MainContainer

    local ContainerStroke = Instance.new("UIStroke")
    ContainerStroke.Thickness = 1.5
    ContainerStroke.Color = config.HighlightColor
    ContainerStroke.Transparency = 0.3
    ContainerStroke.Parent = MainContainer

    local ListLayout = Instance.new("UIListLayout")
    ListLayout.FillDirection = Enum.FillDirection.Vertical
    ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    ListLayout.Padding = UDim.new(0, 0)
    ListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    ListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    ListLayout.Parent = MainContainer

    local Padding = Instance.new("UIPadding")
    Padding.PaddingTop = UDim.new(0, 4)
    Padding.PaddingBottom = UDim.new(0, 4)
    Padding.PaddingLeft = UDim.new(0, 8)
    Padding.PaddingRight = UDim.new(0, 8)
    Padding.Parent = MainContainer

    local InfoRow = Instance.new("Frame")
    InfoRow.Name = "InfoRow"
    InfoRow.BackgroundTransparency = 1
    InfoRow.Size = UDim2.new(1, 0, 0, 16)
    InfoRow.LayoutOrder = 1
    InfoRow.Parent = MainContainer

    local NameLabel = Instance.new("TextLabel")
    NameLabel.BackgroundTransparency = 1
    NameLabel.Size = UDim2.new(0.6, 0, 1, 0)
    NameLabel.Font = Enum.Font.GothamBold
    NameLabel.TextSize = 13
    NameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    NameLabel.TextXAlignment = Enum.TextXAlignment.Left
    NameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    NameLabel.Parent = InfoRow

    local TeamLabel = Instance.new("TextLabel")
    TeamLabel.BackgroundTransparency = 1
    TeamLabel.Size = UDim2.new(0.4, 0, 1, 0)
    TeamLabel.Position = UDim2.new(0.6, 0, 0, 0)
    TeamLabel.Font = Enum.Font.Gotham
    TeamLabel.TextSize = 11
    TeamLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    TeamLabel.TextXAlignment = Enum.TextXAlignment.Right
    TeamLabel.TextTruncate = Enum.TextTruncate.AtEnd
    TeamLabel.Parent = InfoRow

    local WeaponRow = Instance.new("Frame")
    WeaponRow.Name = "WeaponRow"
    WeaponRow.BackgroundTransparency = 1
    WeaponRow.Size = UDim2.new(1, 0, 0, 14)
    WeaponRow.LayoutOrder = 2
    WeaponRow.Parent = MainContainer

    local WeaponLabel = Instance.new("TextLabel")
    WeaponLabel.BackgroundTransparency = 1
    WeaponLabel.Size = UDim2.new(1, 0, 1, 0)
    WeaponLabel.Font = Enum.Font.Gotham
    WeaponLabel.TextSize = 11
    WeaponLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    WeaponLabel.TextXAlignment = Enum.TextXAlignment.Left
    WeaponLabel.TextTruncate = Enum.TextTruncate.AtEnd
    WeaponLabel.Parent = WeaponRow

    local HealthRow = Instance.new("Frame")
    HealthRow.Name = "HealthRow"
    HealthRow.BackgroundTransparency = 1
    HealthRow.Size = UDim2.new(1, 0, 0, 12)
    HealthRow.LayoutOrder = 3
    HealthRow.Parent = MainContainer

    local HPText = Instance.new("TextLabel")
    HPText.BackgroundTransparency = 1
    HPText.Size = UDim2.new(1, 0, 1, 0)
    HPText.Font = Enum.Font.Code
    HPText.TextSize = 10
    HPText.TextColor3 = Color3.fromRGB(0, 255, 150)
    HPText.TextXAlignment = Enum.TextXAlignment.Center
    HPText.Text = "[ 100 / 100 ]"
    HPText.Parent = HealthRow

    local c1 = RunService.RenderStepped:Connect(function()
        if _G.SilentAimActive and config.ShowFOV and fov_circle then
            fov_circle.Visible = true
            fov_circle.Radius = config.FOVSize
            fov_circle.Color = config.FOVColor1
            
            local pos
            if config.FOVBehavior == "Mouse" then
                pos = UserInputService:GetMouseLocation()
            else
                pos = Vector2New(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
            end
            fov_circle.Position = pos
        elseif fov_circle then
            fov_circle.Visible = false
        end
    end)
    table.insert(_G.SilentAimConnections, c1)

    local c2 = RunService.RenderStepped:Connect(function()
        if _G.SilentAimActive then
            local Part, Character = getClosestPlayer()
            ClosestHitPart = Part
            CurrentTargetCharacter = Character
        
            if config.ShowHighlight and Character then
                TargetHighlight.Adornee = Character
                TargetHighlight.Enabled = true
                TargetHighlight.OutlineColor = config.HighlightColor
                ContainerStroke.Color = config.HighlightColor
            else
                TargetHighlight.Adornee = nil
                TargetHighlight.Enabled = false
            end

            if config.ESP.Enabled and Character then
                local head = Character:FindFirstChild("Head")
                local hum = Character:FindFirstChild("Humanoid")
                local plr = Players:GetPlayerFromCharacter(Character)

                if head and hum then
                    HeadBillboard.Adornee = head
                    HeadBillboard.Enabled = true
                    
                    if config.ESP.ShowName then
                        NameLabel.Visible = true
                        NameLabel.Text = Character.Name
                    else
                        NameLabel.Visible = false
                    end

                    if config.ESP.ShowTeam and plr then
                        TeamLabel.Visible = true
                        TeamLabel.Text = plr.Team and plr.Team.Name or "Sem time"
                        TeamLabel.TextColor3 = plr.TeamColor and plr.TeamColor.Color or Color3.fromRGB(200, 200, 200)
                    else
                        TeamLabel.Visible = false
                    end

                    if config.ESP.ShowWeapon then
                        WeaponLabel.Visible = true
                        local tool = Character:FindFirstChildWhichIsA("Tool")
                        if tool then
                            WeaponLabel.Text = toUpper(tool.Name)
                            WeaponLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                        else
                            WeaponLabel.Text = "NADA EQUIPADO"
                            WeaponLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
                        end
                    else
                        WeaponLabel.Visible = false
                    end

                    if config.ESP.ShowHealth then
                        HealthRow.Visible = true
                        local hp = MathFloor(hum.Health)
                        local maxHp = MathFloor(hum.MaxHealth)
                        HPText.Text = string.format("[ %d / %d ]", hp, maxHp)
                        local frac = math.clamp(hp/maxHp, 0, 1)
                        HPText.TextColor3 = Color3.fromHSV(frac * 0.3, 0.9, 1)
                    else
                        HealthRow.Visible = false
                    end
                else
                    HeadBillboard.Enabled = false
                end
            else
                HeadBillboard.Enabled = false
            end
        else
            ClosestHitPart = nil
            CurrentTargetCharacter = nil
            TargetHighlight.Enabled = false
            HeadBillboard.Enabled = false
        end
    end)
    table.insert(_G.SilentAimConnections, c2)
end

local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    if not checkcaller() and _G.SilentAimActive and ClosestHitPart then
        local Method = getnamecallmethod()
        
        if MathRandom(1, 100) <= _G.AimbotConfig.HitChance then
            local Arguments = {...}

            if Method == "Raycast" and self == Workspace then
                local finalPosition = ClosestHitPart.Position + getLegitOffset()
                local origin = Arguments[1] 
                local direction = (finalPosition - origin).Unit * 1000 
                Arguments[2] = direction 
                return oldNamecall(self, unpack(Arguments))
            
            elseif (Method == "FireServer" or Method == "InvokeServer") then
                if isBulletRemote(self.Name) then
                    local finalPosition = ClosestHitPart.Position + getLegitOffset()
                    local cameraPos = Camera.CFrame.Position
                    
                    for i, v in Pairs(Arguments) do
                        if typeof(v) == "Vector3" then
                            if v.Magnitude <= 5 then 
                                Arguments[i] = (finalPosition - cameraPos).Unit
                            else
                                Arguments[i] = finalPosition
                            end
                        elseif typeof(v) == "CFrame" then
                            Arguments[i] = CFrameNew(cameraPos, finalPosition)
                        elseif typeof(v) == "table" then
                            for k, subVal in Pairs(v) do
                                if typeof(subVal) == "Vector3" then
                                     if subVal.Magnitude <= 5 then
                                        v[k] = (finalPosition - cameraPos).Unit
                                     else
                                        v[k] = finalPosition
                                     end
                                elseif typeof(subVal) == "CFrame" then
                                    v[k] = CFrameNew(cameraPos, finalPosition)
                                end
                            end
                        end
                    end
                    return oldNamecall(self, unpack(Arguments))
                end
            end
        end
    end
    return oldNamecall(self, ...)
end))
