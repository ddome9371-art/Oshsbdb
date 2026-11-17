-- إعداد الخدمات الأساسية
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")

local parentGui = (gethui and gethui()) or CoreGui or Players.LocalPlayer:WaitForChild("PlayerGui")

if parentGui:FindFirstChild("M7md_Cleaner_UI") then
    parentGui:FindFirstChild("M7md_Cleaner_UI"):Destroy()
end

-- إنشاء الواجهة
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "M7md_Cleaner_UI"
ScreenGui.Parent = parentGui
ScreenGui.ResetOnSpawn = false

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
MainFrame.Position = UDim2.new(0.5, -90, 0.5, -57)
MainFrame.Size = UDim2.new(0, 180, 0, 115)
MainFrame.Active = true
MainFrame.Draggable = true

local FrameCorner = Instance.new("UICorner")
FrameCorner.CornerRadius = UDim.new(0, 12)
FrameCorner.Parent = MainFrame

local FrameStroke = Instance.new("UIStroke")
FrameStroke.Color = Color3.fromRGB(220, 20, 20)
FrameStroke.Thickness = 2.5
FrameStroke.Parent = MainFrame

-- العنوان
local TitleLabel = Instance.new("TextLabel")
TitleLabel.Name = "Title"
TitleLabel.Parent = MainFrame
TitleLabel.BackgroundColor3 = Color3.fromRGB(180, 15, 15)
TitleLabel.Size = UDim2.new(1, 0, 0, 38)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.Text = "M7md"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.TextSize = 20

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 12)
TitleCorner.Parent = TitleLabel

-- الزر الأحمر
local ActivateBtn = Instance.new("TextButton")
ActivateBtn.Name = "ActivateButton"
ActivateBtn.Parent = MainFrame
ActivateBtn.BackgroundColor3 = Color3.fromRGB(200, 20, 20)
ActivateBtn.Position = UDim2.new(0.08, 0, 0, 52)
ActivateBtn.Size = UDim2.new(0.84, 0, 0, 46)
ActivateBtn.Font = Enum.Font.GothamBold
ActivateBtn.Text = "مسح الجودة"
ActivateBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ActivateBtn.TextSize = 17
ActivateBtn.AutoButtonColor = true

local BtnCorner = Instance.new("UICorner")
BtnCorner.CornerRadius = UDim.new(0, 8)
BtnCorner.Parent = ActivateBtn

-- دالة تخفيف العناصر ومسح الخامات
local function optimizeObject(obj)
    if obj:IsA("Texture") or obj:IsA("Decal") then
        obj:Destroy()
    elseif obj:IsA("BasePart") then
        obj.Material = Enum.Material.SmoothPlastic
        obj.Reflectance = 0
    elseif obj:IsA("MeshPart") then
        obj.TextureID = ""
        obj.Material = Enum.Material.SmoothPlastic
    elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Smoke") or obj:IsA("Fire") then
        obj.Enabled = false
    end
end

local activated = false

ActivateBtn.Activated:Connect(function()
    if activated then return end
    activated = true

    -- تعطيل الظلال والمؤثرات الجوّية
    Lighting.GlobalShadows = false
    Lighting.FogEnd = 9e9
    for _, effect in ipairs(Lighting:GetChildren()) do
        if effect:IsA("PostEffect") then
            effect.Enabled = false
        end
    end

    -- مسح الخامات من الماب بالكامل
    for _, item in ipairs(workspace:GetDescendants()) do
        pcall(optimizeObject, item)
    end

    -- مسح أي خامة جديدة تظهر في الماب تلقائياً
    workspace.DescendantAdded:Connect(function(newItem)
        pcall(optimizeObject, newItem)
    end)

    ActivateBtn.Text = "تم التفعيل ✓"
    ActivateBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
end)
