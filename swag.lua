local cfg = getgenv()["Silent"]
if not cfg then return warn("Silent Aim config missing!") end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local SilentAimTarget = nil
local Enabled = false
local LockedTarget = nil
local lastNotifiedTarget = nil

-- FOV Drawing
local Circle = Drawing.new("Circle")
Circle.Radius = cfg.FOV
Circle.Thickness = 1
Circle.Filled = false
Circle.Transparency = 1
Circle.Color = Color3.fromRGB(255, 255, 255)
Circle.ZIndex = 999
Circle.Visible = cfg.ShowFOV

RunService.RenderStepped:Connect(function()
    local mousePos = UserInputService:GetMouseLocation()
    Circle.Position = Vector2.new(mousePos.X, mousePos.Y)
    Circle.Visible = cfg.ShowFOV
end)

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == cfg.keybind then
        Enabled = not Enabled
        if not Enabled then
            LockedTarget = nil
        end
    end
end)

local function Notify(message)
    if cfg.ShowNotifications then
        pcall(function()
            game.StarterGui:SetCore("SendNotification", {
                Title = "Silent Aim",
                Text = message,
                Duration = 2
            })
        end)
    end
end

local function GetClosestTarget()
    local closest = nil
    local dist = cfg.FOV

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

if not getgenv().Hooked then
    local raw = getrawmetatable(game)
    local old = raw.__index
    setreadonly(raw, false)

    raw.__index = function(t, k)
        if not checkcaller() and t == Mouse and Enabled then
            if k == "Hit" or k == "Target" then
                local partName = cfg.hitPart or "Head"

                if cfg.StickyAim then
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
