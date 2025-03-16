-- Load necessary services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera

-- Define colors
local Green = Color3.fromRGB(0, 255, 0)
local Red = Color3.fromRGB(255, 0, 0)

-- Aimbot settings
local player = Players.LocalPlayer
local aiming = false
local pcMod = false
local radius = 150
local useTeamCheck = true
local useWallCheck = true
local targetPart = "Head" -- Default target part (Head or Torso)
local lockOnTarget = false -- Lock onto target until death or out of radius
local currentTarget = nil -- Current locked target
local espEnabled = true -- Toggle for ESP functionality
local teleportEnabled = false -- Toggle for teleportation functionality
local rotationSpeed = 10 -- Скорость вращения (настраиваемая)
local verticalSpeedMultiplier = 2 -- Множитель скорости вертикального движения (в 2 раза быстрее)
local rotationRadius = 5 -- Радиус вращения (настраиваемый)
local verticalAmplitude = 3 -- Амплитуда вертикального движения над головой (настраиваемая)
local isRotating = false -- Флаг для управления вращением
local teleportLockedTarget = nil -- Target locked after teleportation
local lookAtTargetTime = 0 -- Время, в течение которого нужно смотреть на цель после телепортации

-- ESP settings
local esp = {}

-- Function to create a new drawing object
local function NewDrawing(className, properties)
    local drawing = Drawing.new(className)
    for property, value in pairs(properties) do
        drawing[property] = value
    end
    return drawing
end

-- Aimbot circle drawing
local drawing = NewDrawing("Circle", {
    Color = Color3.new(1, 0, 0),
    Thickness = 2,
    Radius = radius,
    Filled = false,
    Visible = true
})

-- Function to update circle position
local function updateCirclePosition()
    local screenSize = Camera.ViewportSize
    drawing.Position = Vector2.new(screenSize.X / 2, screenSize.Y / 2)
end

-- Изначально центрируем кружок
updateCirclePosition()

-- Function to check target visibility
local function isTargetVisible(targetPosition)
    if not useWallCheck then
        return true
    end
    local ray = Ray.new(Camera.CFrame.Position, (targetPosition - Camera.CFrame.Position).unit * 1000)
    local ignoreList = {player.Character}
    local hit, position = workspace:FindPartOnRayWithIgnoreList(ray, ignoreList)

    if hit then
        local targetPlayer = Players:GetPlayerFromCharacter(hit.Parent)
        return targetPlayer ~= nil
    end
    return false
end

-- Function to get the closest target in radius
local function getClosestTargetInRadius()
    local target = nil
    local shortestDistance = math.huge

    for _, playerModel in pairs(Players:GetPlayers()) do
        if playerModel ~= player and playerModel.Character then
            local character = playerModel.Character
            local humanoid = character:FindFirstChild("Humanoid")
            local targetPartInstance = character:FindFirstChild(targetPart)
            if humanoid and targetPartInstance and humanoid.Health > 0 then
                -- Team check
                if not useTeamCheck or (player.Team and playerModel.Team ~= player.Team) then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(targetPartInstance.Position)
                    local distanceToCenter = (Vector2.new(screenPos.X, screenPos.Y) - drawing.Position).magnitude
                    if distanceToCenter <= radius and isTargetVisible(targetPartInstance.Position) then
                        local distance = (targetPartInstance.Position - Camera.CFrame.Position).magnitude
                        if distance < shortestDistance then
                            shortestDistance = distance
                            target = targetPartInstance
                        end
                    end
                end
            end
        end
    end

    return target
end

-- Function to aim at the target
local function aimAtTarget()
    if teleportLockedTarget and teleportLockedTarget.Parent and teleportLockedTarget.Parent:FindFirstChild("Humanoid") and teleportLockedTarget.Parent.Humanoid.Health > 0 then
        -- Check if the teleport locked target is within the radius
        local screenPos, onScreen = Camera:WorldToViewportPoint(teleportLockedTarget.Position)
        local distanceToCenter = (Vector2.new(screenPos.X, screenPos.Y) - drawing.Position).magnitude
        if distanceToCenter <= radius and isTargetVisible(teleportLockedTarget.Position) then
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, teleportLockedTarget.Position)
            drawing.Color = Color3.new(0, 1, 0)

            -- Teleport the player behind the target and start rotating if enabled
            if teleportEnabled then
                local targetPosition = teleportLockedTarget.Position
                local behindTarget = targetPosition - (Camera.CFrame.LookVector * rotationRadius)
                local character = player.Character or player.CharacterAdded:Wait()
                local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
                humanoidRootPart.CFrame = CFrame.new(behindTarget, targetPosition - Vector3.new(0, 1, 0)) -- Look down when teleporting
                isRotating = true -- Enable rotation
                lookAtTargetTime = tick() + 1 -- Set the time to look at the target
            end

            return
        else
            teleportLockedTarget = nil -- Target out of radius, reset
            isRotating = false -- Stop rotation
        end
    end

    -- Find a new target
    local target = getClosestTargetInRadius()
    if target then
        currentTarget = target
        Camera.CFrame = CFrame.new(Camera.CFrame.Position, target.Position)
        drawing.Color = Color3.new(0, 1, 0)

        -- Teleport the player behind the target and start rotating if enabled
        if teleportEnabled then
            teleportLockedTarget = target -- Lock onto the teleported target
            local targetPosition = teleportLockedTarget.Position
            local behindTarget = targetPosition - (Camera.CFrame.LookVector * rotationRadius)
            local character = player.Character or player.CharacterAdded:Wait()
            local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
            humanoidRootPart.CFrame = CFrame.new(behindTarget, targetPosition - Vector3.new(0, 1, 0)) -- Look down when teleporting
            isRotating = true -- Enable rotation
            lookAtTargetTime = tick() + 1 -- Set the time to look at the target
        end
    else
        drawing.Color = Color3.new(1, 0, 0)
        isRotating = false -- Stop rotation
    end
end

-- Function to update the ESP
local function UpdateESP()
    if not espEnabled then
        for _, plr in pairs(esp) do
            plr.box.Visible = false
            plr.name.Visible = false
        end
        return
    end

    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= Players.LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") and plr.Character:FindFirstChild("Humanoid") and plr.Character.Humanoid.Health > 0 then
            local rootPart = plr.Character.HumanoidRootPart

            -- Determine the color based on the team
            local color = plr.TeamColor == Players.LocalPlayer.TeamColor and Green or Red

            if not esp[plr] then
                esp[plr] = {
                    box = NewDrawing("Square", {
                        Thickness = 2,
                        Color = color,
                        Filled = false
                    }),
                    name = NewDrawing("Text", {
                        Text = plr.Name,
                        Size = 14, -- Adjusted text size
                        Center = true,
                        Outline = true,
                        Color = color
                    })
                }
            else
                -- Update the color if the player's team changes
                esp[plr].box.Color = color
                esp[plr].name.Color = color
            end

            local box = esp[plr].box
            local name = esp[plr].name

            -- Box ESP
            local vector, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
            if onScreen then
                local size = 2000 / vector.Z -- Adjust size based on distance
                box.Size = Vector2.new(size, size)
                box.Position = Vector2.new(vector.X - size / 2, vector.Y - size / 2)
                box.Visible = true

                -- Name display
                name.Position = Vector2.new(vector.X, vector.Y - size / 2 - 20)
                name.Visible = true
            else
                box.Visible = false
                name.Visible = false
            end
        end
    end

    -- Дополнительная очистка для несуществующих игроков
    for plr, data in pairs(esp) do
        if not Players:GetPlayerByUserId(plr.UserId) then
            data.box:Remove()
            data.name:Remove()
            esp[plr] = nil
        end
    end
end

-- Load Rayfield UI
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "Aimbot Interface",
    LoadingTitle = "Loading Aimbot...",
    LoadingSubtitle = "by Sirius",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = nil,
        FileName = "AimbotConfig"
    },
    Discord = {
        Enabled = false,
        Invite = "noinvitelink",
        RememberJoins = true
    },
    KeySystem = false
})

local AimbotTab = Window:CreateTab("Aimbot", 4483362458)

local aimbotToggle = AimbotTab:CreateToggle({
    Name = "Enable Aimbot",
    CurrentValue = false,
    Flag = "AimbotToggle",
    Callback = function(Value)
        aiming = Value
        if not Value then
            drawing.Color = Color3.new(1, 0, 0)
            currentTarget = nil
            isRotating = false
            teleportLockedTarget = nil
        end
    end
})

local radiusSlider = AimbotTab:CreateSlider({
    Name = "Aimbot Radius",
    Range = {1, 500},
    Increment = 1,
    CurrentValue = radius,
    Flag = "AimbotRadius",
    Callback = function(Value)
        radius = Value
        drawing.Radius = radius
    end
})

local teamCheckToggle = AimbotTab:CreateToggle({
    Name = "Team Check",
    CurrentValue = useTeamCheck,
    Flag = "TeamCheckToggle",
    Callback = function(Value)
        useTeamCheck = Value
    end
})

local wallCheckToggle = AimbotTab:CreateToggle({
    Name = "Wall Check",
    CurrentValue = useWallCheck,
    Flag = "WallCheckToggle",
    Callback = function(Value)
        useWallCheck = Value
    end
})

local targetPartDropdown = AimbotTab:CreateDropdown({
    Name = "Target Part",
    Options = {"Head", "Torso"},
    CurrentOption = targetPart,
    Flag = "TargetPartDropdown",
    Callback = function(Option)
        targetPart = Option
        currentTarget = nil
    end
})

local lockOnToggle = AimbotTab:CreateToggle({
    Name = "Lock On Target",
    CurrentValue = lockOnTarget,
    Flag = "LockOnToggle",
    Callback = function(Value)
        lockOnTarget = Value
        if not Value then
            currentTarget = nil
            isRotating = false
            teleportLockedTarget = nil
        end
    end
})

local pcModToggle = AimbotTab:CreateToggle({
    Name = "PC Mod",
    CurrentValue = pcMod,
    Flag = "PcModToggle",
    Callback = function(Value)
        pcMod = Value
    end
})

local espToggle = AimbotTab:CreateToggle({
    Name = "Enable ESP",
    CurrentValue = espEnabled,
    Flag = "EspToggle",
    Callback = function(Value)
        espEnabled = Value
    end
})

local teleportToggle = AimbotTab:CreateToggle({
    Name = "Enable Teleport",
    CurrentValue = teleportEnabled,
    Flag = "TeleportToggle",
    Callback = function(Value)
        teleportEnabled = Value
        if not Value then
            isRotating = false -- Stop rotation if teleportation is disabled
            teleportLockedTarget = nil
        end
    end
})

-- Handle character respawn
player.CharacterAdded:Connect(function(character)
    -- Reinitialize references if needed
    currentTarget = nil
    isRotating = false
    teleportLockedTarget = nil
end)

-- Очистка ESP при выходе игрока с сервера
Players.PlayerRemoving:Connect(function(plr)
    if esp[plr] then
        esp[plr].box:Remove() -- Удаляем объект бокса
        esp[plr].name:Remove() -- Удаляем объект имени
        esp[plr] = nil -- Удаляем запись из таблицы
    end
end)

-- Main loop for aiming, rotating, and ESP
RunService.RenderStepped:Connect(function(deltaTime)
    -- Обновляем позицию кружка в центре экрана
    updateCirclePosition()

    if pcMod then
        if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
            aiming = true
            aimAtTarget()
        else
            aiming = false
            drawing.Color = Color3.new(1, 0, 0)
            currentTarget = nil
            isRotating = false
            teleportLockedTarget = nil
        end
    else
        if aiming then
            aimAtTarget()
        else
            drawing.Color = Color3.new(1, 0, 0)
            currentTarget = nil
            isRotating = false
            teleportLockedTarget = nil
        end
    end

    -- Вращение вокруг головы цели с вертикальным движением и взглядом на голову
    if isRotating and teleportLockedTarget and teleportEnabled then
        local character = player.Character
        if character and character:FindFirstChild("HumanoidRootPart") then
            local humanoidRootPart = character.HumanoidRootPart
            local targetPosition = teleportLockedTarget.Position -- Позиция головы цели
            local angle = tick() * rotationSpeed -- Угол вращения
            local verticalAngle = tick() * rotationSpeed * verticalSpeedMultiplier -- Угол для вертикального движения
            local horizontalOffset = Vector3.new(math.sin(angle), 0, math.cos(angle)) * rotationRadius -- Горизонтальное смещение
            local verticalOffset = Vector3.new(0, math.abs(math.sin(verticalAngle)) * verticalAmplitude, 0) -- Вертикальное смещение
            local newPosition = targetPosition + horizontalOffset + verticalOffset -- Новая позиция
            humanoidRootPart.CFrame = CFrame.new(newPosition, targetPosition - Vector3.new(0, 1, 0)) -- Смотрим вниз
        end
    end

    -- Look at the target for 1 second after teleportation
    if lookAtTargetTime > tick() then
        if teleportLockedTarget and teleportLockedTarget.Parent and teleportLockedTarget.Parent:FindFirstChild("Humanoid") and teleportLockedTarget.Parent.Humanoid.Health > 0 then
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, teleportLockedTarget.Position)
        end
    end

    UpdateESP()
end)
