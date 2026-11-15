pcall(function() for _,v in pairs(game.CoreGui:GetChildren()) do if v.Name:find("Luxury") then v:Destroy() end end end)
pcall(function() for _,v in pairs(game.Players.LocalPlayer.PlayerGui:GetChildren()) do if v.Name:find("Luxury") then v:Destroy() end end end)
task.wait(0.2)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local InsertService = game:GetService("InsertService")
local lp = Players.LocalPlayer
local PlayerGui = lp:WaitForChild("PlayerGui")

-- ===================== إعدادات السكن =====================
local HEADLESS = true
local KORBLOX = true
local KORBLOX_ID = 139607718
local HEADLESS_ASSET = 134082579
local FREEZE_SKINS = true
local SKINS_FILE = "Luxury_skins.json"
local frozen = {}
local currentSkin = 1
local skinActive = true
local skinGuis = {}
local fakeLegParts = {}
local saved = nil
local hideConn = nil
local origDesc = nil
local uidCache = {}
local modelCache = {}
local dummyCache = {}
local applying = false

-- تحميل السكنات المحفوظة
if FREEZE_SKINS then
	pcall(function()
		if isfile and isfile(SKINS_FILE) then
			frozen = HttpService:JSONDecode(readfile(SKINS_FILE))
		end
	end)
end

local function saveFrozen()
	pcall(function()
		if writefile then
			writefile(SKINS_FILE, HttpService:JSONEncode(frozen))
		end
	end)
end

-- ===================== دوال مساعدة =====================
local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do o[k] = v end
	if parent then o.Parent = parent end
	return o
end

local function corner(o, r)
	return new("UICorner", {CornerRadius = UDim.new(0, r or 8)}, o)
end

local function stroke(o, col, th, tr)
	return new("UIStroke", {Color = col, Thickness = th or 1, Transparency = tr or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, o)
end

local function getChar(p)
	local c = p and p.Character
	if not c then return nil end
	local h = c:FindFirstChildOfClass("Humanoid")
	local r = c:FindFirstChild("HumanoidRootPart")
	if h and r and h.Health > 0 then return c, h, r end
	return nil
end

local function userIdOf(name)
	if uidCache[name] then return uidCache[name] end
	local ok, uid = pcall(function() return Players:GetUserIdFromNameAsync(name) end)
	if ok and uid then
		uidCache[name] = uid
		return uid
	end
	return nil
end

local function resolveUserId(name)
	name = (string.gsub(tostring(name or ""), "^%s*@?%s*(.-)%s*$", "%1"))
	if name == "" then return nil end
	if uidCache[name] then return uidCache[name] end
	if string.match(name, "^%d+$") and #name >= 6 then
		local n = tonumber(name)
		uidCache[name] = n
		return n
	end
	for _ = 1, 3 do
		local ok, uid = pcall(function() return Players:GetUserIdFromNameAsync(name) end)
		if ok and uid then
			uidCache[name] = uid
			return uid
		end
		task.wait(0.3)
	end
	return nil
end

local DESC_PROPS = {"Shirt","Pants","GraphicTShirt","Face","Head","Torso","LeftArm","RightArm","LeftLeg","RightLeg","HeightScale","WidthScale","HeadScale","DepthScale","BodyTypeScale","ProportionScale"}
local COLOR_PROPS = {"HeadColor","TorsoColor","LeftArmColor","RightArmColor","LeftLegColor","RightLegColor"}

local function freezeDesc(d)
	local r = {p = {}, c = {}, a = {}}
	for _, k in ipairs(DESC_PROPS) do pcall(function() r.p[k] = d[k] end) end
	for _, k in ipairs(COLOR_PROPS) do
		pcall(function()
			local c = d[k]
			r.c[k] = {c.R, c.G, c.B}
		end)
	end
	local ok, list = pcall(function() return d:GetAccessories(true) end)
	if ok and list then
		for _, i in ipairs(list) do
			table.insert(r.a, {AssetId = i.AssetId, Type = i.AccessoryType.Name, Layered = i.IsLayered, Order = i.Order, Puffiness = i.Puffiness})
		end
	end
	return r
end

local function thawDesc(r)
	local d = Instance.new("HumanoidDescription")
	for k, v in pairs(r.p or {}) do pcall(function() d[k] = v end) end
	for k, v in pairs(r.c or {}) do pcall(function() d[k] = Color3.new(v[1], v[2], v[3]) end) end
	local list = {}
	for _, i in ipairs(r.a or {}) do
		table.insert(list, {AssetId = i.AssetId, AccessoryType = Enum.AccessoryType[i.Type], IsLayered = i.Layered, Order = i.Order, Puffiness = i.Puffiness})
	end
	pcall(function() d:SetAccessories(list, true) end)
	return d
end

local function getDesc(name, uid)
	if FREEZE_SKINS and frozen[name] then
		return thawDesc(frozen[name])
	end
	local d = Players:GetHumanoidDescriptionFromUserId(uid)
	if FREEZE_SKINS then
		frozen[name] = freezeDesc(d)
		saveFrozen()
	end
	return d
end

local function loadAssetObj(id)
	local obj = nil
	local ok, objs = pcall(function() return game:GetObjects("rbxassetid://" .. tostring(id)) end)
	if ok and objs and objs[1] then obj = objs[1] end
	if not obj then
		local ok2, model = pcall(function() return InsertService:LoadAsset(id) end)
		if ok2 and model then
			local kids = model:GetChildren()
			if kids[1] then obj = kids[1] end
		end
	end
	return obj
end

local function snapshotAndStrip(char)
	saved = {removed = {}, colors = nil, face = nil, transp = {}}
	for _, d in ipairs(char:GetChildren()) do
		if d:IsA("Accessory") or d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") then
			table.insert(saved.removed, d)
			d.Parent = nil
		end
	end
	local bc = char:FindFirstChildOfClass("BodyColors")
	if bc then saved.colors = bc:Clone() end
	local head = char:FindFirstChild("Head")
	local face = head and head:FindFirstChildOfClass("Decal")
	if face then saved.face = face.Texture end
end

local function restoreVisual(char)
	if hideConn then hideConn:Disconnect() hideConn = nil end
	for _, fp in ipairs(fakeLegParts) do pcall(function() fp:Destroy() end) end
	fakeLegParts = {}
	if origDesc then
		local c = lp.Character
		local hm = c and c:FindFirstChildOfClass("Humanoid")
		if hm then pcall(function() hm:ApplyDescription(origDesc) end) end
		origDesc = nil
	end
	for _, g in ipairs(skinGuis) do pcall(function() g:Destroy() end) end
	skinGuis = {}
	if not saved then return end
	char = char or lp.Character
	if char then
		for _, d in ipairs(saved.removed) do pcall(function() d.Parent = char end) end
		local bc = char:FindFirstChildOfClass("BodyColors")
		if bc and saved.colors then
			for _, prop in ipairs({"HeadColor3","TorsoColor3","LeftArmColor3","RightArmColor3","LeftLegColor3","RightLegColor3"}) do
				local orig = saved.colors[prop]
				bc[prop] = Color3.new(1,0,1)
				bc[prop] = orig
			end
		end
		local head = char:FindFirstChild("Head")
		local face = head and head:FindFirstChildOfClass("Decal")
		if face and saved.face then face.Texture = saved.face end
	end
	if saved.transp then
		for inst, val in pairs(saved.transp) do
			pcall(function() inst.Transparency = val end)
		end
	end
	saved = nil
end

local function isWelded(handle)
	for _, d in ipairs(handle:GetChildren()) do
		if d:IsA("Weld") or d:IsA("WeldConstraint") or d:IsA("Motor6D") then return true end
	end
	return false
end

local function attachAccessory(char, h, acc)
	pcall(function() h:AddAccessory(acc) end)
	if acc.Parent ~= char then acc.Parent = char end
	local handle = acc:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then return false end
	if isWelded(handle) then return true end
	handle.CanCollide = false
	handle.Massless = true
	local att = handle:FindFirstChildOfClass("Attachment")
	local target = nil
	if att then
		for _, part in ipairs(char:GetChildren()) do
			if part:IsA("BasePart") then
				local a = part:FindFirstChild(att.Name)
				if a and a:IsA("Attachment") then target = a break end
			end
		end
	end
	local head = char:FindFirstChild("Head")
	if target then
		handle.CFrame = target.WorldCFrame * att.CFrame:Inverse()
		local w = Instance.new("Weld")
		w.Part0 = target.Parent
		w.Part1 = handle
		w.C0 = target.CFrame
		w.C1 = att.CFrame
		w.Parent = handle
		return true
	elseif head then
		handle.CFrame = head.CFrame * CFrame.new(0, head.Size.Y / 2, 0)
		local w = Instance.new("WeldConstraint")
		w.Part0 = head
		w.Part1 = handle
		w.Parent = handle
		return true
	end
	return false
end

local function buildFakeLeg(char)
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local darkTeal = Color3.fromRGB(8, 100, 100)
	local teal = Color3.fromRGB(40, 190, 190)
	local function add(inst, off, size, col)
		inst.Size = size
		inst.Color = col
		inst.Material = Enum.Material.SmoothPlastic
		inst.CanCollide = false
		inst.CanTouch = false
		inst.CanQuery = false
		inst.Massless = true
		inst.Anchored = false
		inst.CFrame = hrp.CFrame * off
		local w = Instance.new("WeldConstraint")
		w.Part0 = hrp
		w.Part1 = inst
		w.Parent = inst
		inst.Parent = char
		table.insert(fakeLegParts, inst)
	end
	local LEG_X, LEG_TOP = 0.5, -1.0
	local LEG_W = 0.14
	local LEG_TOP_LEN, LEG_TIP_LEN = 0.4, 0.6
	local zHalf = 0.1
	add(Instance.new("Part"), CFrame.new(LEG_X, LEG_TOP - LEG_TOP_LEN / 2, 0), Vector3.new(LEG_W, LEG_TOP_LEN, zHalf * 2), darkTeal)
	local y2 = LEG_TOP - LEG_TOP_LEN - LEG_TIP_LEN / 2
	add(Instance.new("WedgePart"), CFrame.new(LEG_X, y2, -zHalf / 2) * CFrame.Angles(0, 0, math.pi), Vector3.new(LEG_W, LEG_TIP_LEN, zHalf), teal)
	add(Instance.new("WedgePart"), CFrame.new(LEG_X, y2, zHalf / 2) * CFrame.Angles(0, math.pi, math.pi), Vector3.new(LEG_W, LEG_TIP_LEN, zHalf), teal)
end

local function buildUserLeg(char, desc, key)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not (hum and desc) then return false end
	local cacheKey = key and (key .. tostring(hum.RigType))
	local okM, dummy = true, nil
	if cacheKey and dummyCache[cacheKey] then
		dummy = dummyCache[cacheKey]:Clone()
	else
		okM, dummy = pcall(function() return Players:CreateHumanoidModelFromDescription(desc, hum.RigType) end)
		if okM and dummy and cacheKey then dummyCache[cacheKey] = dummy:Clone() end
	end
	if not (okM and dummy) then return false end
	if hum.RigType == Enum.HumanoidRigType.R6 then
		for _, d in ipairs(dummy:GetChildren()) do
			if d:IsA("CharacterMesh") and d.BodyPart == Enum.BodyPart.RightLeg then
				local cm = d:Clone()
				cm.Parent = char
				table.insert(fakeLegParts, cm)
			end
		end
		pcall(function() dummy:Destroy() end)
		return true, true
	end
	local names = {"RightUpperLeg", "RightLowerLeg", "RightFoot"}
	local made = 0
	for _, n in ipairs(names) do
		local src, dst = dummy:FindFirstChild(n), char:FindFirstChild(n)
		if src and dst then
			local c = src:Clone()
			for _, d in ipairs(c:GetChildren()) do
				if d:IsA("Motor6D") or d:IsA("Weld") or d:IsA("WeldConstraint") then d:Destroy() end
			end
			c.Name = "KX_" .. n
			c.Anchored = false
			c.CanCollide = false
			c.CanTouch = false
			c.CanQuery = false
			c.Massless = true
			c.Transparency = 0
			c.CFrame = dst.CFrame
			local w = Instance.new("WeldConstraint")
			w.Part0 = dst
			w.Part1 = c
			w.Parent = c
			c.Parent = char
			table.insert(fakeLegParts, c)
			made = made + 1
		end
	end
	pcall(function() dummy:Destroy() end)
	return made > 0
end

local function applySpec(char, h, spec)
	local korbloxOk, nativeLeg = false, false
	local useFake = false
	if KORBLOX and spec.desc then
		korbloxOk, nativeLeg = buildUserLeg(char, spec.desc, spec.key)
		if not korbloxOk then useFake = true end
	elseif KORBLOX then
		useFake = true
	end
	snapshotAndStrip(char)
	if useFake then buildFakeLeg(char) end
	local count = 0
	for _, key in ipairs({"Shirt", "Pants", "GraphicTShirt"}) do
		local id = spec[key]
		if id and id > 0 then
			local obj = loadAssetObj(id)
			if obj then
				obj.Parent = char
				table.insert(skinGuis, obj)
				count = count + 1
			end
		end
	end
	local accOk, accTotal = 0, #(spec.accs or {})
	for _, id in ipairs(spec.accs or {}) do
		local obj = loadAssetObj(id)
		if obj and obj:IsA("Accessory") then
			if attachAccessory(char, h, obj) then accOk = accOk + 1 end
			table.insert(skinGuis, obj)
			count = count + 1
		end
	end
	local bc = char:FindFirstChildOfClass("BodyColors")
	if bc and spec.colors then
		for k, v in pairs(spec.colors) do pcall(function() bc[k] = v end) end
	end
	saved.transp = saved.transp or {}
	local legSets = {
		Right = {"Right Leg", "RightUpperLeg", "RightLowerLeg", "RightFoot"},
		Left = {"Left Leg", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot"},
	}
	local hideLeg = "Right"
	if nativeLeg then hideLeg = ""
	elseif korbloxOk or useFake then hideLeg = "Right" end
	if hideConn then hideConn:Disconnect() end
	hideConn = RunService.RenderStepped:Connect(function()
		local list = {}
		if HEADLESS then
			local hd = char:FindFirstChild("Head")
			if hd then
				table.insert(list, hd)
				for _, d in ipairs(hd:GetChildren()) do
					if d:IsA("Decal") then table.insert(list, d) end
				end
			end
		end
		local names = {}
		for _, n in ipairs(legSets[hideLeg] or {}) do names[n] = true end
		if next(names) then
			for _, d in ipairs(char:GetDescendants()) do
				if d:IsA("BasePart") and names[d.Name] then table.insert(list, d) end
			end
		end
		for _, inst in ipairs(list) do
			if saved and saved.transp[inst] == nil then saved.transp[inst] = inst.Transparency end
			inst.Transparency = 1
			if inst:IsA("BasePart") then inst.LocalTransparencyModifier = 1 end
		end
	end)
	local head = char:FindFirstChild("Head")
	if head and spec.Face and spec.Face > 0 and not HEADLESS then
		local f = loadAssetObj(spec.Face)
		if f and f:IsA("Decal") then
			local old = head:FindFirstChildOfClass("Decal")
			if old then old.Parent = nil table.insert(saved.removed, old) end
			f.Name = "face"
			f.Parent = head
			table.insert(skinGuis, f)
			count = count + 1
		end
	end
	return count
end

local function copyBodyParts(char, h, model, opts)
	opts = opts or {}
	saved = saved or {}
	saved.transp = saved.transp or {}
	local hideList = {}
	local function hideOrig(p)
		saved.transp[p] = saved.transp[p] or p.Transparency
		table.insert(hideList, p)
		for _, d in ipairs(p:GetChildren()) do
			if d:IsA("Decal") then
				saved.transp[d] = saved.transp[d] or d.Transparency
				table.insert(hideList, d)
			end
		end
	end
	if h.RigType == Enum.HumanoidRigType.R6 then
		for _, d in ipairs(model:GetChildren()) do
			if d:IsA("CharacterMesh") then
				local cm = d:Clone()
				cm.Parent = char
				table.insert(fakeLegParts, cm)
			end
		end
	end
	for _, src in ipairs(model:GetChildren()) do
		local dst = char:FindFirstChild(src.Name)
		local diffMesh = dst and src:IsA("MeshPart") and dst:IsA("MeshPart") and src.MeshId ~= dst.MeshId
		if dst and src ~= dst and diffMesh and src.Name ~= "HumanoidRootPart" then
			local c = src:Clone()
			for _, d in ipairs(c:GetChildren()) do
				if d:IsA("Motor6D") or d:IsA("Weld") or d:IsA("WeldConstraint") then d:Destroy() end
			end
			c.Name = "KX_" .. src.Name
			c.Anchored = false
			c.CanCollide = false
			c.CanTouch = false
			c.CanQuery = false
			c.Massless = true
			c.Transparency = 0
			c.CFrame = dst.CFrame
			local w = Instance.new("WeldConstraint")
			w.Part0 = dst
			w.Part1 = c
			w.Parent = c
			c.Parent = char
			table.insert(fakeLegParts, c)
			hideOrig(dst)
		end
	end
	local hd = char:FindFirstChild("Head")
	local mh = model:FindFirstChild("Head")
	if hd and mh and not opts.headless then
		local om, nm = hd:FindFirstChildOfClass("SpecialMesh"), mh:FindFirstChildOfClass("SpecialMesh")
		if om and nm then
			pcall(function()
				om.MeshType = nm.MeshType
				om.MeshId = nm.MeshId
				om.TextureId = nm.TextureId
				om.Scale = nm.Scale
				om.Offset = nm.Offset
			end)
		end
		for _, d in ipairs(hd:GetChildren()) do
			if d:IsA("Decal") and d.Name ~= "KX_face" then
				saved.transp[d] = saved.transp[d] or d.Transparency
				table.insert(hideList, d)
			end
		end
		if not opts.noFace then
			for _, d in ipairs(mh:GetChildren()) do
				if d:IsA("Decal") then
					local c = d:Clone()
					c.Name = "KX_face"
					c.Transparency = 0
					c.Parent = hd
					table.insert(fakeLegParts, c)
				end
			end
		end
	elseif hd and opts.headless then
		for _, d in ipairs(hd:GetChildren()) do
			if d:IsA("Decal") then
				saved.transp[d] = saved.transp[d] or d.Transparency
				table.insert(hideList, d)
			end
		end
	end
	if opts.headless then
		for _, pt in ipairs({hd}) do
			if pt then
				saved.transp[pt] = saved.transp[pt] or pt.Transparency
				table.insert(hideList, pt)
			end
		end
	end
	if #hideList > 0 then
		if hideConn then hideConn:Disconnect() end
		hideConn = RunService.RenderStepped:Connect(function()
			for _, p in ipairs(hideList) do
				if p.Parent then p.Transparency = 1 end
			end
		end)
	end
end

local function copyFromModel(char, h, model, opts)
	snapshotAndStrip(char)
	local count = 0
	for _, d in ipairs(model:GetChildren()) do
		if d:IsA("Accessory") then
			local acc = d:Clone()
			local handle = acc:FindFirstChild("Handle")
			if handle then
				for _, w in ipairs(handle:GetChildren()) do
					if w:IsA("Weld") or w:IsA("WeldConstraint") or w:IsA("Motor6D") then w:Destroy() end
				end
			end
			attachAccessory(char, h, acc)
			table.insert(skinGuis, acc)
			count = count + 1
		elseif d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") then
			local o = d:Clone()
			o.Parent = char
			table.insert(skinGuis, o)
			count = count + 1
		end
	end
	local mbc, bc = model:FindFirstChildOfClass("BodyColors"), char:FindFirstChildOfClass("BodyColors")
	if mbc and bc then
		for _, prop in ipairs({"HeadColor3","TorsoColor3","LeftArmColor3","RightArmColor3","LeftLegColor3","RightLegColor3"}) do
			pcall(function() bc[prop] = mbc[prop] end)
		end
	end
	pcall(copyBodyParts, char, h, model, opts)
	return count
end

local function applyUserSkin(username, opts)
	opts = opts or {}
	local c0, h0 = getChar(lp)
	if not c0 then return false, "الشخصية مو جاهزة" end
	local desc, uid = nil, nil
	uid = resolveUserId(username)
	if not uid then return false, "اليوزر ما انجاب" end
	for _ = 1, 3 do
		local ok, d = pcall(getDesc, username, uid)
		if ok and d then desc = d break end
		task.wait(0.35)
	end
	if desc and opts.forceKorblox then
		pcall(function() desc.RightLeg = KORBLOX_ID end)
	end
	local sources = {
		function()
			if not desc then return nil end
			local mkey = username .. tostring(h0.RigType)
			if modelCache[mkey] then return modelCache[mkey]:Clone() end
			local ok, model = pcall(function() return Players:CreateHumanoidModelFromDescription(desc, h0.RigType) end)
			if ok and model then
				modelCache[mkey] = model:Clone()
				return model
			end
			return nil
		end,
		function()
			if not uid then return nil end
			local ok, m = pcall(function() return Players:GetCharacterAppearanceAsync(uid) end)
			if ok and m then return m end
			return nil
		end,
	}
	for _, src in ipairs(sources) do
		local okS, model = pcall(src)
		if okS and model then
			restoreVisual(c0)
			local c, h = getChar(lp)
			if not c then
				pcall(function() model:Destroy() end)
				return false, "الشخصية مو جاهزة"
			end
			local okC, count = pcall(copyFromModel, c, h, model, opts)
			pcall(function() model:Destroy() end)
			if okC and ((count or 0) > 0) then
				return true
			end
			restoreVisual(c)
		end
	end
	if desc then
		local c, h = getChar(lp)
		if c then
			restoreVisual(c)
			local okO, cur = pcall(function() return h:GetAppliedDescription() end)
			if okO and cur then origDesc = cur end
			local okA = pcall(function() h:ApplyDescription(desc) end)
			if okA then
				for _, ch in ipairs(c:GetChildren()) do
					if ch:IsA("Accessory") or ch:IsA("Shirt") or ch:IsA("Pants") or ch:IsA("ShirtGraphic") then
						table.insert(skinGuis, ch)
					end
				end
				return true
			end
			origDesc = nil
		end
	end
	return false, "ما قدرت أجيب سكن هذا اليوزر"
end

local function restoreSkin()
	skinActive = false
	restoreVisual()
end

-- قائمة سكنات جاهزة (من الأصلي)
local SKINS = {
	{label = "FF_071", username = "FF_071", exact = true},
	{label = "TLLWP", username = "TLLWP", exact = true},
	{label = "ASOOXLI", username = "ASOOXLI", exact = true},
	{label = "UB1ER", username = "UB1ER", exact = true},
	{label = "ZXCFFWX", username = "ZXCFFWX", exact = true},
	{label = "xk8sq", username = "xk8sq", exact = true},
	{label = "44j", username = "44j"},
	{label = "Soulcrxck", username = "Soulcrxck", exact = true},
	{label = "H_XRU", username = "H_XRU", exact = true},
	{label = "silentcrimer", username = "silentcrimer", exact = true},
	{label = "Linkmon99", username = "Linkmon99", exact = true},
	{label = "Stickmasterluke", username = "Stickmasterluke", exact = true},
	{label = "Builderman", username = "Builderman", forceKorblox = true},
	{label = "Shedletsky", username = "Shedletsky", forceKorblox = true},
}

local function applyCurrent()
	local sk = SKINS[currentSkin]
	if not sk then return false end
	if sk.exact then
		HEADLESS = false
		KORBLOX = false
	else
		HEADLESS = true
		KORBLOX = true
	end
	if sk.username then
		local ok, err = applyUserSkin(sk.username, sk)
		return ok
	end
	return false
end

local function doApply()
	if applying then return false end
	applying = true
	local ok, res = pcall(applyCurrent)
	applying = false
	return ok and res
end

local function selectSkin(i)
	currentSkin = i
	skinActive = true
	task.spawn(doApply)
end

-- ===================== الواجهة Luxury =====================
local gui = Instance.new("ScreenGui")
gui.Name = "LuxurySkins"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = PlayerGui

local blur = Instance.new("BlurEffect", game.Lighting)
blur.Size = 0

local openBtn = Instance.new("TextButton", gui)
openBtn.Size = UDim2.fromOffset(130, 45)
openBtn.Position = UDim2.fromOffset(15, 15)
openBtn.Text = "✨ LUXURY"
openBtn.BackgroundColor3 = Color3.fromHex("#8A2BE2")
openBtn.TextColor3 = Color3.new(1,1,1)
openBtn.Font = Enum.Font.GothamBold
openBtn.TextSize = 16
Instance.new("UICorner", openBtn).CornerRadius = UDim.new(0, 14)
openBtn.ZIndex = 20
Instance.new("UIStroke", openBtn).Color = Color3.fromHex("#FF00FF")
local grad = Instance.new("UIGradient", openBtn)
grad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, Color3.fromHex("#8A2BE2")), ColorSequenceKeypoint.new(1, Color3.fromHex("#FF00FF"))}
grad.Rotation = 45

local main = Instance.new("Frame", gui)
main.Size = UDim2.fromOffset(650, 420)
main.Position = UDim2.new(0.5, -325, 0.5, -210)
main.BackgroundColor3 = Color3.fromHex("#0A0A12")
main.BackgroundTransparency = 0.15
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 20)
main.Active = true
main.Draggable = true
main.Visible = false
main.ZIndex = 10

local strokeMain = Instance.new("UIStroke", main)
strokeMain.Thickness = 2
task.spawn(function()
	local cols = {Color3.fromHex("#8A2BE2"), Color3.fromHex("#FF00FF"), Color3.fromHex("#00FFFF"), Color3.fromHex("#8A2BE2")}
	local i = 1
	while main.Parent do
		TweenService:Create(strokeMain, TweenInfo.new(2), {Color = cols[i]}):Play()
		i = i + 1 if i > 4 then i = 1 end
		task.wait(2)
	end
end)

local bgGrad = Instance.new("UIGradient", main)
bgGrad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, Color3.fromHex("#1A1A2E")), ColorSequenceKeypoint.new(1, Color3.fromHex("#0F0F1E"))}
bgGrad.Rotation = 20

-- شريط علوي
local topBar = Instance.new("Frame", main)
topBar.Size = UDim2.fromOffset(650, 50)
topBar.BackgroundTransparency = 1

local title = Instance.new("TextLabel", topBar)
title.Position = UDim2.fromOffset(20, 10)
title.Size = UDim2.fromOffset(400, 25)
title.Text = "✨ LUXURY SKINS"
title.BackgroundTransparency = 1
title.TextColor3 = Color3.new(1,1,1)
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.TextXAlignment = Enum.TextXAlignment.Left

local sub = Instance.new("TextLabel", topBar)
sub.Position = UDim2.fromOffset(20, 30)
sub.Size = UDim2.fromOffset(400, 15)
sub.Text = "جلب سكن • Headless • Korblox • حفظ تلقائي"
sub.BackgroundTransparency = 1
sub.TextColor3 = Color3.fromRGB(180,180,180)
sub.Font = Enum.Font.Gotham
sub.TextSize = 12
sub.TextXAlignment = Enum.TextXAlignment.Left

local close = Instance.new("TextButton", topBar)
close.Position = UDim2.fromOffset(610, 10)
close.Size = UDim2.fromOffset(28, 28)
close.Text = "✕"
close.BackgroundColor3 = Color3.fromRGB(255,50,50)
close.TextColor3 = Color3.new(1,1,1)
close.Font = Enum.Font.GothamBold
Instance.new("UICorner", close).CornerRadius = UDim.new(1,0)

-- محتوى
local content = Instance.new("ScrollingFrame", main)
content.Position = UDim2.fromOffset(15, 60)
content.Size = UDim2.fromOffset(620, 345)
content.BackgroundColor3 = Color3.fromHex("#0F0F1E")
content.BackgroundTransparency = 0.5
content.BorderSizePixel = 0
content.ScrollBarThickness = 4
content.ScrollBarImageColor3 = Color3.fromHex("#8A2BE2")
content.CanvasSize = UDim2.new(0, 0, 0, 0)
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
Instance.new("UICorner", content).CornerRadius = UDim.new(0, 15)
Instance.new("UIStroke", content).Color = Color3.fromHex("#1E1E32")
Instance.new("UIListLayout", content).Padding = UDim.new(0, 8)
Instance.new("UIPadding", content).PaddingTop = UDim.new(0, 10)
Instance.new("UIPadding", content).PaddingLeft = UDim.new(0, 10)
Instance.new("UIPadding", content).PaddingRight = UDim.new(0, 10)
Instance.new("UIPadding", content).PaddingBottom = UDim.new(0, 10)

-- ===== قسم جلب يوزر =====
local function makeSection(text)
	local l = Instance.new("TextLabel", content)
	l.Size = UDim2.new(1, -10, 0, 22)
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextColor3 = Color3.fromHex("#FF00FF")
	l.Font = Enum.Font.GothamBold
	l.TextSize = 14
	l.TextXAlignment = Enum.TextXAlignment.Left
	return l
end

makeSection("جلب سكن أي لاعب")

local inputFrame = Instance.new("Frame", content)
inputFrame.Size = UDim2.new(1, -10, 0, 42)
inputFrame.BackgroundColor3 = Color3.fromHex("#1A1A2E")
Instance.new("UICorner", inputFrame).CornerRadius = UDim.new(0, 10)

local userBox = Instance.new("TextBox", inputFrame)
userBox.Position = UDim2.fromOffset(8, 6)
userBox.Size = UDim2.new(1, -120, 0, 30)
userBox.BackgroundColor3 = Color3.fromHex("#0A0A12")
userBox.TextColor3 = Color3.new(1,1,1)
userBox.PlaceholderText = "اكتب اليوزر هنا..."
userBox.PlaceholderColor3 = Color3.fromRGB(120,120,140)
userBox.Text = ""
userBox.Font = Enum.Font.Gotham
userBox.TextSize = 14
userBox.ClearTextOnFocus = false
Instance.new("UICorner", userBox).CornerRadius = UDim.new(0, 8)

local applyBtn = Instance.new("TextButton", inputFrame)
applyBtn.Position = UDim2.new(1, -105, 0, 6)
applyBtn.Size = UDim2.fromOffset(95, 30)
applyBtn.Text = "لبس السكن"
applyBtn.BackgroundColor3 = Color3.fromHex("#8A2BE2")
applyBtn.TextColor3 = Color3.new(1,1,1)
applyBtn.Font = Enum.Font.GothamBold
applyBtn.TextSize = 13
Instance.new("UICorner", applyBtn).CornerRadius = UDim.new(0, 8)

local statusLbl = Instance.new("TextLabel", content)
statusLbl.Size = UDim2.new(1, -10, 0, 20)
statusLbl.BackgroundTransparency = 1
statusLbl.Text = "جاهز"
statusLbl.TextColor3 = Color3.fromRGB(150,150,170)
statusLbl.Font = Enum.Font.Gotham
statusLbl.TextSize = 12
statusLbl.TextXAlignment = Enum.TextXAlignment.Left

applyBtn.MouseButton1Click:Connect(function()
	local name = userBox.Text
	if name == "" then
		statusLbl.Text = "اكتب يوزر"
		statusLbl.TextColor3 = Color3.fromRGB(255,80,80)
		return
	end
	statusLbl.Text = "جاري جلب السكن..."
	statusLbl.TextColor3 = Color3.fromRGB(200,200,100)
	task.spawn(function()
		local ok, err = applyUserSkin(name, {exact = true})
		if ok then
			statusLbl.Text = "تم لبس سكن " .. name
			statusLbl.TextColor3 = Color3.fromRGB(80,255,140)
			skinActive = true
		else
			statusLbl.Text = "فشل: " .. tostring(err)
			statusLbl.TextColor3 = Color3.fromRGB(255,80,80)
		end
	end)
end)

-- زر استرجاع
local restoreBtn = Instance.new("TextButton", content)
restoreBtn.Size = UDim2.new(1, -10, 0, 36)
restoreBtn.Text = "↩ إرجاع سكني الأصلي"
restoreBtn.BackgroundColor3 = Color3.fromRGB(60,30,40)
restoreBtn.TextColor3 = Color3.new(1,1,1)
restoreBtn.Font = Enum.Font.GothamBold
restoreBtn.TextSize = 14
Instance.new("UICorner", restoreBtn).CornerRadius = UDim.new(0, 10)
restoreBtn.MouseButton1Click:Connect(function()
	restoreSkin()
	statusLbl.Text = "رجع شكلك الأصلي"
	statusLbl.TextColor3 = Color3.fromRGB(150,150,170)
end)

-- ===== توجات Headless / Korblox =====
makeSection("المظهر (يظهر لك فقط)")

local function makeToggle(title, desc, get, set)
	local f = Instance.new("Frame", content)
	f.Size = UDim2.new(1, -10, 0, 50)
	f.BackgroundColor3 = Color3.fromHex("#1A1A2E")
	Instance.new("UICorner", f).CornerRadius = UDim.new(0, 10)

	local t = Instance.new("TextLabel", f)
	t.Position = UDim2.fromOffset(12, 6)
	t.Size = UDim2.new(1, -80, 0, 20)
	t.BackgroundTransparency = 1
	t.Text = title
	t.TextColor3 = Color3.new(1,1,1)
	t.Font = Enum.Font.GothamBold
	t.TextSize = 14
	t.TextXAlignment = Enum.TextXAlignment.Left

	local d = Instance.new("TextLabel", f)
	d.Position = UDim2.fromOffset(12, 26)
	d.Size = UDim2.new(1, -80, 0, 18)
	d.BackgroundTransparency = 1
	d.Text = desc
	d.TextColor3 = Color3.fromRGB(140,140,160)
	d.Font = Enum.Font.Gotham
	d.TextSize = 11
	d.TextXAlignment = Enum.TextXAlignment.Left

	local sw = Instance.new("TextButton", f)
	sw.Position = UDim2.new(1, -55, 0.5, -12)
	sw.Size = UDim2.fromOffset(44, 24)
	sw.Text = ""
	sw.BackgroundColor3 = Color3.fromRGB(40,40,55)
	Instance.new("UICorner", sw).CornerRadius = UDim.new(1, 0)

	local knob = Instance.new("Frame", sw)
	knob.Size = UDim2.fromOffset(18, 18)
	knob.Position = UDim2.fromOffset(3, 3)
	knob.BackgroundColor3 = Color3.new(1,1,1)
	Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

	local function render()
		local on = get()
		sw.BackgroundColor3 = on and Color3.fromHex("#8A2BE2") or Color3.fromRGB(40,40,55)
		knob.Position = on and UDim2.fromOffset(23, 3) or UDim2.fromOffset(3, 3)
	end
	render()
	sw.MouseButton1Click:Connect(function()
		set(not get())
		render()
	end)
	return render
end

local headlessRender = makeToggle("Headless", "إخفاء الراس", function() return HEADLESS end, function(v)
	HEADLESS = v
	if skinActive then task.spawn(doApply) end
end)

local korbloxRender = makeToggle("Korblox", "الرجل اليمين تصير Korblox", function() return KORBLOX end, function(v)
	KORBLOX = v
	if skinActive then task.spawn(doApply) end
end)

-- ===== المعرض =====
makeSection("معرض السكنات السريعة")

local grid = Instance.new("Frame", content)
grid.Size = UDim2.new(1, -10, 0, 0)
grid.AutomaticSize = Enum.AutomaticSize.Y
grid.BackgroundTransparency = 1
local gridLayout = Instance.new("UIGridLayout", grid)
gridLayout.CellSize = UDim2.fromOffset(95, 95)
gridLayout.CellPadding = UDim2.fromOffset(8, 8)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder

for i, sk in ipairs(SKINS) do
	local b = Instance.new("TextButton", grid)
	b.Text = ""
	b.BackgroundColor3 = Color3.fromHex("#1A1A2E")
	b.AutoButtonColor = false
	b.LayoutOrder = i
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
	local st = Instance.new("UIStroke", b)
	st.Color = Color3.fromHex("#8A2BE2")
	st.Thickness = 1.5
	st.Transparency = 0.5

	local lbl = Instance.new("TextLabel", b)
	lbl.Size = UDim2.new(1, 0, 0, 20)
	lbl.Position = UDim2.new(0, 0, 1, -20)
	lbl.BackgroundColor3 = Color3.new(0,0,0)
	lbl.BackgroundTransparency = 0.4
	lbl.Text = sk.label
	lbl.TextColor3 = Color3.new(1,1,1)
	lbl.Font = Enum.Font.Gotham
	lbl.TextSize = 11
	lbl.TextTruncate = Enum.TextTruncate.AtEnd

	-- صورة مصغرة
	task.spawn(function()
		local uid = userIdOf(sk.username)
		if uid then
			local ok, url = pcall(function()
				return Players:GetUserThumbnailAsync(uid, Enum.ThumbnailType.AvatarBust, Enum.ThumbnailSize.Size150x150)
			end)
			if ok and url then
				local img = Instance.new("ImageLabel", b)
				img.Size = UDim2.new(1, 0, 1, -20)
				img.BackgroundTransparency = 1
				img.Image = url
				img.ScaleType = Enum.ScaleType.Crop
				img.ZIndex = 0
			end
		end
	end)

	b.MouseButton1Click:Connect(function()
		selectSkin(i)
		statusLbl.Text = "جاري تطبيق: " .. sk.label
		statusLbl.TextColor3 = Color3.fromRGB(200,200,100)
		task.delay(1.5, function()
			statusLbl.Text = "تم تطبيق " .. sk.label
			statusLbl.TextColor3 = Color3.fromRGB(80,255,140)
		end)
	end)
end

-- ===== أنيميشن فتح / إغلاق =====
local function openAnim()
	main.Visible = true
	main.Size = UDim2.fromOffset(0, 0)
	TweenService:Create(main, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.fromOffset(650, 420)}):Play()
	TweenService:Create(blur, TweenInfo.new(0.5), {Size = 8}):Play()
	openBtn.Text = "✕ اغلاق"
	openBtn.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
end

local function closeAnim()
	TweenService:Create(main, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Size = UDim2.fromOffset(0, 0)}):Play()
	TweenService:Create(blur, TweenInfo.new(0.4), {Size = 0}):Play()
	task.wait(0.4)
	main.Visible = false
	openBtn.Text = "✨ LUXURY"
	openBtn.BackgroundColor3 = Color3.fromHex("#8A2BE2")
end

openBtn.MouseButton1Click:Connect(function()
	if main.Visible then closeAnim() else openAnim() end
end)
close.MouseButton1Click:Connect(closeAnim)

-- تطبيق تلقائي عند الـ Respawn
lp.CharacterAdded:Connect(function()
	if skinActive then
		task.wait(1.2)
		task.spawn(doApply)
	end
end)

openAnim()
print("[Luxury Skins] Loaded successfully")
