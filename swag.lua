
local lastNotifiedTarget = nil

local function Notify(message)
    if getgenv()["Silent"].ShowNotifications then
        game.StarterGui:SetCore("SendNotification", {
            Title = "Silent Aim",
            Text = message,
            Duration = 2
        })
    end
end


local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local SilentAimTarget = nil
local Enabled = false
local LockedTarget = nil -- for StickyAim

-- FOV Drawing
local Circle = Drawing.new("Circle")
Circle.Radius = getgenv()["Silent"].FOV
Circle.Thickness = 1
Circle.Filled = false
Circle.Transparency = 1
Circle.Color = Color3.fromRGB(255, 255, 255)
Circle.ZIndex = 999
Circle.Visible = getgenv()["Silent"].ShowFOV

-- Draw FOV circle
RunService.RenderStepped:Connect(function()
    local mousePos = UserInputService:GetMouseLocation()
    Circle.Position = Vector2.new(mousePos.X, mousePos.Y)
    Circle.Visible = getgenv()["Silent"].ShowFOV
end)


-- Toggle with keybind
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == getgenv()["Silent"].keybind then
        Enabled = not Enabled
        if not Enabled then
            LockedTarget = nil -- reset sticky target when turning off
        end
    end
end)

-- Get closest target inside FOV
local function GetClosestTarget()
    local closest = nil
    local dist = getgenv()["Silent"].FOV

    for _, v in pairs(Players:GetPlayers()) do
        if v ~= LocalPlayer and v.Character and v.Character:FindFirstChild("HumanoidRootPart") and v.Character:FindFirstChild("Humanoid") and v.Character.Humanoid.Health > 0 then
            local screenPos, onScreen = Camera:WorldToViewportPoint(v.Character.HumanoidRootPart.Position)
            if onScreen then
                local mag = (Vector2.new(screenPos.X, screenPos.Y) - UserInputService:GetMouseLocation()).Magnitude
                if mag < dist then
                    dist = mag
                    closest = v
                end
            end
        end
    end

    return closest
end

-- Mouse __index Hook
if not getgenv().Hooked then
    local raw = getrawmetatable(game)
    local old = raw.__index
    setreadonly(raw, false)

    raw.__index = function(t, k)
        if not checkcaller() and t == Mouse and Enabled then
            if k == "Hit" or k == "Target" then
                local partName = getgenv()["Silent"].hitPart or "Head"
                if getgenv()["Silent"].StickyAim then
                    -- Get new lock-on only if needed
                    if not LockedTarget or not LockedTarget.Character or not LockedTarget.Character:FindFirstChild(partName) then
                        local newTarget = GetClosestTarget()
                        if newTarget and newTarget ~= LockedTarget then
                            LockedTarget = newTarget
                            lastNotifiedTarget = LockedTarget
                            Notify("targeting: " .. LockedTarget.DisplayName)
                        elseif not newTarget and lastNotifiedTarget then
                            Notify("lost the target")
                            lastNotifiedTarget = nil
                        end
                    end

                    -- Handle if lost target during lock
                    if LockedTarget and (not LockedTarget.Character or not LockedTarget.Character:FindFirstChild(partName)) then
                        if lastNotifiedTarget then
                            Notify("lost the target")
                            lastNotifiedTarget = nil
                        end
                        LockedTarget = nil
                    end

                    if LockedTarget and LockedTarget.Character:FindFirstChild(partName) then
                        return k == "Hit" and LockedTarget.Character[partName].CFrame or LockedTarget.Character
                    end
                else
                    local dynamicTarget = GetClosestTarget()
                    if dynamicTarget ~= lastNotifiedTarget then
                        if lastNotifiedTarget then
                            Notify("lost the target")
                        end
                        if dynamicTarget then
                            Notify("targeting: " .. dynamicTarget.DisplayName)
                        end
                        lastNotifiedTarget = dynamicTarget
                    end

                    if dynamicTarget and dynamicTarget.Character and dynamicTarget.Character:FindFirstChild(partName) then
                        return k == "Hit" and dynamicTarget.Character[partName].CFrame or dynamicTarget.Character
                    end
                end
            end
        end
        return old(t, k)
    end

    setreadonly(raw, true)
    getgenv().Hooked = true
end
