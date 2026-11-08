local Library = {}

function Library.new(config)
config = config or {}
local UNLOAD_KEY = (config.Name or "ZeroHubUI") .. "_Unload"

-- ZeroHub UI Library — ไลบรารี UI สำหรับ loadstring
-- ใช้: local Lib = loadstring(game:HttpGet(URL))(); local UI = Lib.new({Title = "..."})
-- ปรับปรุง: ระบบคอมโพเนนต์ (Toggle/Slider/Dropdown/Button), ค้นหา, แจ้งเตือน, แคชหน้า,
--          ลากแยกจากคลิก, ล้าง connection ตอนปิด, ปรับขนาดตามหน้าจอ

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

-- ล้างของเดิมถ้ารันซ้ำ
if _G[UNLOAD_KEY] then
    pcall(_G[UNLOAD_KEY])
end

local function getParent()
    local p = CoreGui
    pcall(function()
        if gethui then p = gethui() end
    end)
    return p
end

---------------------------------------------------------------------
-- THEME / HELPERS
---------------------------------------------------------------------
local function hexc(h) return Color3.fromHex(h) end

-- โทนสีสำเร็จรูป (ได้แรงบันดาลใจจาก BASED Hub) + สีหลัก 8 แบบ
local SCHEMES = {
    graphite  = {base = hexc("0B0B0F"), ink = hexc("F5F4EF"), sub = hexc("A9A8B4")},
    midnight  = {base = hexc("000000"), ink = hexc("F5F4EF"), sub = hexc("9E9DA9")},
    porcelain = {base = hexc("F3F2EE"), ink = hexc("121216"), sub = hexc("56555F")},
}
local ACCENTS = {
    {name = "ม่วง",    color = hexc("8E7DFF")},
    {name = "ฟ้า",     color = hexc("4DA3FF")},
    {name = "มิ้นต์",   color = hexc("45DDA8")},
    {name = "ส้ม",     color = hexc("FF7A45")},
    {name = "ชมพู",    color = hexc("FF5C93")},
    {name = "ทอง",    color = hexc("F2C14E")},
    {name = "แดง",    color = hexc("FF4B4B")},
    {name = "ขาวนวล", color = hexc("EDEBE4")},
}
local THEME_TOKENS = {"panel", "panelSoft", "card", "box", "off", "border", "muted", "white", "accent", "accentSoft"}

local function buildTokens(scheme, accent)
    local sc = SCHEMES[scheme] or SCHEMES.graphite
    return {
        panel      = sc.base,
        panelSoft  = sc.base:Lerp(sc.ink, 0.05),
        card       = sc.base:Lerp(sc.ink, 0.08),
        box        = sc.base:Lerp(sc.ink, 0.035),
        off        = sc.base:Lerp(sc.ink, 0.22),
        border     = sc.base:Lerp(sc.ink, 0.40),
        muted      = sc.sub,
        white      = sc.ink,
        accent     = accent,
        accentSoft = accent:Lerp(sc.base, 0.55),
    }
end

local THEME = buildTokens("graphite", ACCENTS[1].color)
THEME.black = Color3.new(0, 0, 0)
local themeState = {scheme = "graphite", accent = ACCENTS[1].color}

-- ใส่รหัสรูปไอคอนของแต่ละแท็บที่นี่ (asset id ตัวเลข) เช่น ["ภาพ"] = 1234567890
-- ถ้าเว้นว่าง แท็บจะใช้อีโมจิ/ตัวอักษรที่ระบุใน createTab แทน
local TAB_ICON_IMAGES = config.TabIcons or {}

local connections = {}
local function connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(connections, c)
    return c
end

local function create(class, props, parent)
    local inst = Instance.new(class)
    for k, v in pairs(props) do
        inst[k] = v
    end
    if parent then inst.Parent = parent end
    return inst
end

local function corner(p, r)
    return create("UICorner", {CornerRadius = UDim.new(0, r)}, p)
end

local function stroke(p, color, thickness, transparency)
    return create("UIStroke", {
        Color = color,
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, p)
end

local function padding(p, l, t, r, b)
    return create("UIPadding", {
        PaddingLeft = UDim.new(0, l), PaddingTop = UDim.new(0, t),
        PaddingRight = UDim.new(0, r), PaddingBottom = UDim.new(0, b),
    }, p)
end

local function tween(inst, time, props, style, dir)
    local tw = TweenService:Create(inst, TweenInfo.new(
        time, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
    tw:Play()
    return tw
end

local function label(parent, text, size, color, font)
    return create("TextLabel", {
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = color or THEME.white,
        TextSize = size or 14,
        Font = font or Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, parent)
end

local function fire(callback, ...)
    if type(callback) ~= "function" then return end
    local args = table.pack(...)
    task.spawn(function()
        local ok, err = pcall(callback, table.unpack(args, 1, args.n))
        if not ok then warn("[NewUI] callback error: " .. tostring(err)) end
    end)
end

-- คำนวณตำแหน่งที่ถูกจำกัดให้อยู่ในจอ (คิดจาก Size/AnchorPoint/UIScale โดยตรง)
local function clampedPosition(target, pos)
    local g = target:FindFirstAncestorOfClass("ScreenGui")
    if not g then return pos end
    local vp = g.AbsoluteSize
    local us = target:FindFirstChildOfClass("UIScale")
    local sc = us and us.Scale or 1
    local w = target.Size.X.Offset * sc
    local h = target.Size.Y.Offset * sc
    local a = target.AnchorPoint
    local px = vp.X * pos.X.Scale + pos.X.Offset
    local py = vp.Y * pos.Y.Scale + pos.Y.Offset
    local minX, maxX = a.X * w, vp.X - (1 - a.X) * w
    local minY, maxY = a.Y * h, vp.Y - (1 - a.Y) * h
    if maxX < minX then minX = (minX + maxX) / 2; maxX = minX end
    if maxY < minY then minY = (minY + maxY) / 2; maxY = minY end
    local cx = math.clamp(px, minX, maxX)
    local cy = math.clamp(py, minY, maxY)
    return UDim2.new(pos.X.Scale, pos.X.Offset + (cx - px), pos.Y.Scale, pos.Y.Offset + (cy - py))
end

local function reclamp(target)
    target.Position = clampedPosition(target, target.Position)
end

-- ลากได้ + แยก "ลาก" ออกจาก "คลิก" (ขยับเกิน 6px ถือว่าลาก)
local function makeDraggable(handle, target)
    local dragging, moved = false, false
    local dragStart, startPos
    connect(handle.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging, moved = true, false
            dragStart, startPos = input.Position, target.Position
            local endConn
            endConn = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    endConn:Disconnect()
                end
            end)
        end
    end)
    connect(UserInputService.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            if d.Magnitude > 6 then moved = true end
            if moved then
                target.Position = clampedPosition(target, UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + d.X,
                    startPos.Y.Scale, startPos.Y.Offset + d.Y))
            end
        end
    end)
    return function() return moved end
end

---------------------------------------------------------------------
-- ROOT GUI
---------------------------------------------------------------------
local gui = create("ScreenGui", {
    Name = config.Name or "ZeroHubUI",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 100,
}, getParent())

local animationsEnabled = true
local visible = true
local visibleToken = 0
local normalScale = 1
local userScale = 1
local menuKey = config.MenuKey or Enum.KeyCode.RightShift   -- ปุ่มลัดเปิด/ปิดเมนู (เปลี่ยนได้จากแท็บ "อื่น ๆ")
local keybindListening = false           -- กำลังรอรับปุ่มใหม่อยู่หรือไม่

---------------------------------------------------------------------
-- TOGGLE BUTTON (ปุ่มลอย)
---------------------------------------------------------------------
local toggleHolder = create("Frame", {
    Name = "ToggleHolder",
    Size = UDim2.fromOffset(58, 58),
    Position = UDim2.fromOffset(16, 120),
    BackgroundTransparency = 1,
}, gui)

local toggleButton = create("TextButton", {
    Name = "ToggleButton",
    Size = UDim2.fromOffset(48, 48),
    Position = UDim2.fromOffset(5, 5),
    BackgroundColor3 = THEME.black,
    BackgroundTransparency = 0.08,
    BorderSizePixel = 0,
    Text = "",
    AutoButtonColor = false,
}, toggleHolder)
corner(toggleButton, 15)
local toggleStroke = stroke(toggleButton, THEME.white, 1.8, 0.05)

create("ImageLabel", {
    Name = "ToggleIcon",
    BackgroundTransparency = 1,
    Size = UDim2.fromScale(0.68, 0.68),
    Position = UDim2.fromScale(0.16, 0.16),
    Image = "rbxassetid://133728442471679" .. tostring(config.ToggleIcon or 133728442471679),
    ImageColor3 = THEME.white,
    ScaleType = Enum.ScaleType.Fit,
}, toggleButton)

connect(toggleButton.MouseEnter, function()
    tween(toggleStroke, 0.15, {Color = THEME.accent})
end)
connect(toggleButton.MouseLeave, function()
    tween(toggleStroke, 0.15, {Color = THEME.white})
end)

---------------------------------------------------------------------
-- WINDOW
---------------------------------------------------------------------
local window = create("Frame", {
    Name = "MainWindow",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(650, 455),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
}, gui)
corner(window, 28)
local windowStroke = stroke(window, THEME.border, 1.2, 0.25)

-- CanvasGroup: ทุกอย่างในหน้าต่างจางหาย/โผล่พร้อมกัน (พื้นหลังอยู่ในนี้ด้วย)
local canvas = create("CanvasGroup", {
    Name = "WindowCanvas",
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = THEME.panel,
    BackgroundTransparency = 0.08,
    BorderSizePixel = 0,
    GroupTransparency = 0,
}, window)
corner(canvas, 28)

local windowScale = create("UIScale", {}, window)

local function fitWindow()
    local vp = gui.AbsoluteSize
    if vp.X <= 0 or vp.Y <= 0 then return end
    normalScale = math.clamp(math.min((vp.X - 32) / 650, (vp.Y - 32) / 455, 1), 0.45, 1) * userScale
    if visible then windowScale.Scale = normalScale end
    reclamp(window)
    reclamp(toggleHolder)
end
fitWindow()
connect(gui:GetPropertyChangedSignal("AbsoluteSize"), fitWindow)

-- BACKGROUND FX (ลูกแสงเคลื่อนช้า ๆ) -------------------------------
-- เบา: ใช้ Tween วนซ้ำแค่ 3 ก้อน ไม่มี Heartbeat/ลูปคำนวณเอง
-- หยุดทำงานอัตโนมัติตอนซ่อนเมนู และปิดได้จากแท็บ "อื่น ๆ"
local bgEnabled = true
local bgLayer = create("Frame", {
    Name = "BackgroundFX",
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    ZIndex = 0,
}, canvas)

local ORBS = {
    {color = THEME.accent,                  size = 300, from = UDim2.fromScale(0.08, 0.15), to = UDim2.fromScale(0.40, 0.50), time = 11},
    {color = Color3.fromRGB(150, 105, 255), size = 260, from = UDim2.fromScale(0.70, 0.60), to = UDim2.fromScale(0.45, 0.10), time = 14},
    {color = Color3.fromRGB(70, 200, 220),  size = 220, from = UDim2.fromScale(0.85, 0.05), to = UDim2.fromScale(0.60, 0.65), time = 17},
}
local orbFrames, orbTweens = {}, {}

for i, o in ipairs(ORBS) do
    local orb = create("Frame", {
        Name = "Orb" .. i,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(o.size, o.size),
        Position = o.from,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    }, bgLayer)
    -- ซ้อนวงกลม 3 ชั้นให้ขอบดูฟุ้ง (ไม่ต้องใช้รูปภาพ)
    for _, layer in ipairs({{1, 0.95}, {0.68, 0.92}, {0.4, 0.88}}) do
        local c = create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromScale(layer[1], layer[1]),
            BackgroundColor3 = o.color,
            BackgroundTransparency = layer[2],
            BorderSizePixel = 0,
        }, orb)
        create("UICorner", {CornerRadius = UDim.new(0.5, 0)}, c)
    end
    orbFrames[i] = orb
end

local function stopBackground()
    for i, tw in pairs(orbTweens) do
        tw:Cancel()
        orbTweens[i] = nil
    end
end

local function startBackground()
    for i, orb in ipairs(orbFrames) do
        if not orbTweens[i] then
            local tw = TweenService:Create(orb, TweenInfo.new(
                ORBS[i].time, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
                {Position = ORBS[i].to})
            orbTweens[i] = tw
            tw:Play()
        end
    end
end

local function refreshBackground()
    bgLayer.Visible = bgEnabled
    if bgEnabled and visible then
        startBackground()
    else
        stopBackground()
    end
end

-- HEADER ------------------------------------------------------------
local header = create("Frame", {
    Name = "Header",
    Size = UDim2.new(1, 0, 0, 64),
    BackgroundColor3 = THEME.panelSoft,
    BackgroundTransparency = 0.1,
    BorderSizePixel = 0,
}, canvas)

create("Frame", { -- เส้นคั่นใต้ header
    Size = UDim2.new(1, 0, 0, 1),
    Position = UDim2.new(0, 0, 1, -1),
    BackgroundColor3 = THEME.border,
    BackgroundTransparency = 0.8,
    BorderSizePixel = 0,
}, header)

local logoDot = create("Frame", {
    Size = UDim2.fromOffset(10, 10),
    Position = UDim2.fromOffset(24, 27),
    BackgroundColor3 = Color3.fromRGB(90, 210, 140), -- ค่า เดิม THEME.accent
    BorderSizePixel = 0,
}, header)
corner(logoDot, 5)

local title = label(header, config.Title or "UI", 20, THEME.white, Enum.Font.GothamBold)
title.Position = UDim2.fromOffset(44, 11)
title.Size = UDim2.new(1, -120, 0, 24)
local subtitle = label(header, config.Subtitle or "Mobile Ready UI", 11, THEME.muted)
subtitle.Position = UDim2.fromOffset(45, 36)
subtitle.Size = UDim2.new(1, -120, 0, 18)

local closeButton = create("TextButton", {
    Name = "CloseButton",
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -18, 0.5, 0),
    Size = UDim2.fromOffset(34, 34),
    BackgroundColor3 = THEME.card,
    BorderSizePixel = 0,
    Text = "×",
    TextColor3 = THEME.white,
    TextSize = 22,
    Font = Enum.Font.Gotham,
    AutoButtonColor = false,
}, header)
corner(closeButton, 12)
connect(closeButton.MouseEnter, function()
    tween(closeButton, 0.15, {BackgroundColor3 = Color3.fromRGB(170, 60, 70)})
end)
connect(closeButton.MouseLeave, function()
    tween(closeButton, 0.15, {BackgroundColor3 = THEME.card})
end)

-- SIDEBAR -----------------------------------------------------------
local sidebar = create("Frame", {
    Name = "Sidebar",
    Position = UDim2.fromOffset(0, 64),
    Size = UDim2.new(0, 164, 1, -64),
    BackgroundColor3 = THEME.panelSoft,
    BackgroundTransparency = 0.25,
    BorderSizePixel = 0,
}, canvas)

local tabList = create("ScrollingFrame", {
    Name = "TabList",
    Size = UDim2.new(1, 0, 1, -76),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 0,
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollingDirection = Enum.ScrollingDirection.Y,
}, sidebar)
padding(tabList, 12, 14, 12, 0)
create("UIListLayout", {
    Padding = UDim.new(0, 4),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, tabList)

-- โปรไฟล์ผู้เล่นด้านล่าง sidebar
local profile = create("Frame", {
    Name = "Profile",
    AnchorPoint = Vector2.new(0, 1),
    Position = UDim2.new(0, 12, 1, -12),
    Size = UDim2.new(1, -24, 0, 52),
    BackgroundColor3 = THEME.card,
    BackgroundTransparency = 0.2,
    BorderSizePixel = 0,
}, sidebar)
corner(profile, 16)
stroke(profile, THEME.border, 1, 0.75)

local avatar = create("ImageLabel", {
    Size = UDim2.fromOffset(34, 34),
    Position = UDim2.fromOffset(9, 9),
    BackgroundColor3 = THEME.off,
    BorderSizePixel = 0,
    Image = "",
}, profile)
corner(avatar, 17)

local pName = label(profile, LocalPlayer and LocalPlayer.DisplayName or "Player", 12, THEME.white, Enum.Font.GothamMedium)
pName.Position = UDim2.fromOffset(51, 9)
pName.Size = UDim2.new(1, -58, 0, 18)
pName.TextTruncate = Enum.TextTruncate.AtEnd
local pSub = label(profile, "พร้อมใช้งาน", 10, THEME.accent)
pSub.Position = UDim2.fromOffset(51, 27)
pSub.Size = UDim2.new(1, -58, 0, 16)

task.spawn(function()
    pcall(function()
        local img = Players:GetUserThumbnailAsync(LocalPlayer.UserId,
            Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
        avatar.Image = img
    end)
end)

-- CONTENT -----------------------------------------------------------
local content = create("Frame", {
    Name = "Content",
    Position = UDim2.fromOffset(164, 64),
    Size = UDim2.new(1, -164, 1, -64),
    BackgroundTransparency = 1,
    ClipsDescendants = true,
}, canvas)

local contentTitle = label(content, "", 18, THEME.white, Enum.Font.GothamBold)
contentTitle.Position = UDim2.fromOffset(26, 16)
contentTitle.Size = UDim2.new(1, -220, 0, 26)

local contentHint = label(content, "", 12, THEME.muted)
contentHint.Position = UDim2.fromOffset(27, 44)
contentHint.Size = UDim2.new(1, -220, 0, 20)
contentHint.TextTruncate = Enum.TextTruncate.AtEnd

local searchBox = create("TextBox", {
    Name = "Search",
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -22, 0, 18),
    Size = UDim2.fromOffset(150, 32),
    BackgroundColor3 = THEME.card,
    BackgroundTransparency = 0.15,
    BorderSizePixel = 0,
    PlaceholderText = "ค้นหา...",
    PlaceholderColor3 = THEME.muted,
    Text = "",
    TextColor3 = THEME.white,
    TextSize = 12,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left,
    ClearTextOnFocus = false,
}, content)
corner(searchBox, 12)
padding(searchBox, 10, 0, 10, 0)
local searchStroke = stroke(searchBox, THEME.border, 1, 0.75)
connect(searchBox.Focused, function() tween(searchStroke, 0.15, {Color = THEME.accent, Transparency = 0.2}) end)
connect(searchBox.FocusLost, function() tween(searchStroke, 0.15, {Color = THEME.border, Transparency = 0.75}) end)

---------------------------------------------------------------------
-- TOAST (การแจ้งเตือน)
---------------------------------------------------------------------
local toastHolder = create("Frame", {
    Name = "Toasts",
    AnchorPoint = Vector2.new(0.5, 1),
    Position = UDim2.new(0.5, 0, 1, -24),
    Size = UDim2.fromOffset(300, 200),
    BackgroundTransparency = 1,
}, gui)
create("UIListLayout", {
    VerticalAlignment = Enum.VerticalAlignment.Bottom,
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    Padding = UDim.new(0, 6),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, toastHolder)

local activeToasts = {}

local function removeToast(entry)
    if entry.dead then return end
    entry.dead = true
    for i, e in ipairs(activeToasts) do
        if e == entry then table.remove(activeToasts, i) break end
    end
    local toast = entry.toast
    if not toast.Parent then return end
    -- จางหายเร็ว ๆ แล้วหดความสูงให้ toast อื่นเลื่อนลงนุ่ม ๆ ไม่กระชาก
    tween(toast, 0.14, {BackgroundTransparency = 1}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    tween(entry.stroke, 0.14, {Transparency = 1})
    tween(entry.bar, 0.14, {BackgroundTransparency = 1})
    tween(entry.text, 0.14, {TextTransparency = 1})
    local shrink = tween(toast, 0.2, {Size = UDim2.fromOffset(280, 0)}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    shrink.Completed:Connect(function() toast:Destroy() end)
end

local function notify(text, duration)
    -- ถ้ามีข้อความเดิมอยู่แล้ว ให้รีเซ็ตเวลาแทนการซ้อนเพิ่ม (กดรัว ๆ ไม่สะสม)
    for _, e in ipairs(activeToasts) do
        if e.message == text then
            e.token = e.token + 1
            local token = e.token
            task.delay(duration or 1.6, function()
                if e.token == token then removeToast(e) end
            end)
            return
        end
    end
    -- จำกัดสูงสุด 3 อัน
    while #activeToasts >= 3 do
        removeToast(activeToasts[1])
    end

    -- ใช้ Frame ธรรมดา (เบากว่า CanvasGroup บนมือถือ)
    local toast = create("Frame", {
        Size = UDim2.fromOffset(280, 40),
        BackgroundColor3 = THEME.panel,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    }, toastHolder)
    corner(toast, 14)
    local s = stroke(toast, THEME.accent, 1, 1)
    local bar = create("Frame", {
        Size = UDim2.new(0, 3, 0, 18), Position = UDim2.new(0, 12, 0.5, -9),
        BackgroundColor3 = THEME.accent, BackgroundTransparency = 1, BorderSizePixel = 0,
    }, toast)
    corner(bar, 2)
    local t = label(toast, text, 12, THEME.white, Enum.Font.GothamMedium)
    t.Position = UDim2.fromOffset(26, 0)
    t.Size = UDim2.new(1, -36, 1, 0)
    t.TextTruncate = Enum.TextTruncate.AtEnd
    t.TextTransparency = 1

    local entry = {toast = toast, stroke = s, bar = bar, text = t, message = text, token = 0, dead = false}
    table.insert(activeToasts, entry)

    tween(toast, 0.18, {BackgroundTransparency = 0.05})
    tween(s, 0.18, {Transparency = 0.5})
    tween(bar, 0.18, {BackgroundTransparency = 0})
    tween(t, 0.18, {TextTransparency = 0})

    task.delay(duration or 1.6, function()
        if entry.token == 0 then removeToast(entry) end
    end)
end

---------------------------------------------------------------------
-- PAGE / COMPONENTS
---------------------------------------------------------------------
local Page = {}
Page.__index = Page

local pages, pageOrder = {}, {}
local currentPage

local ROW_H = 38
local OPT_H = 28

local function ensureGroup(self)
    if not self.group then self:AddSection("") end
    return self.group
end

local function addDivider(row, g)
    if g.order > 1 or g.hasHeader then
        create("Frame", {
            Position = UDim2.fromOffset(14, 0),
            Size = UDim2.new(1, -28, 0, 1),
            BackgroundColor3 = THEME.border,
            BackgroundTransparency = 0.85,
            BorderSizePixel = 0,
        }, row)
    end
end

-- แถวแบบกะทัดรัดอยู่ในกล่อง (groupbox) ปัจจุบันของหน้า
local function newRow(self, height)
    local g = ensureGroup(self)
    g.order = g.order + 1
    local row = create("Frame", {
        Size = UDim2.new(1, 0, 0, height),
        BackgroundColor3 = THEME.accentSoft,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = g.order,
        ClipsDescendants = true,
    }, g.box)
    addDivider(row, g)
    connect(row.MouseEnter, function()
        tween(row, 0.12, {BackgroundColor3 = THEME.white, BackgroundTransparency = 0.965})
    end)
    connect(row.MouseLeave, function() tween(row, 0.18, {BackgroundTransparency = 1}) end)
    return row
end

local function rowLabel(row, text, rightReserve)
    local t = label(row, text or "", 13, THEME.white, Enum.Font.Gotham)
    t.Position = UDim2.fromOffset(14, 0)
    t.Size = UDim2.new(1, -(14 + (rightReserve or 0)), 0, ROW_H)
    t.TextTruncate = Enum.TextTruncate.AtEnd
    return t
end

function Page:_register(row, searchText, title)
    table.insert(self.items, {
        card = row, group = self.group, page = self,
        text = string.lower(searchText or ""), title = title,
    })
end

function Page:ApplyFilter(query)
    query = string.lower(query or "")
    local titleMatch = {}
    for _, g in ipairs(self.groups) do
        titleMatch[g] = query ~= "" and g.titleLower ~= "" and string.find(g.titleLower, query, 1, true) ~= nil
    end
    local shown, groupShown = 0, {}
    for _, item in ipairs(self.items) do
        local match = query == "" or string.find(item.text, query, 1, true) ~= nil
            or (item.group ~= nil and titleMatch[item.group] == true)
        item.card.Visible = match
        if match then
            shown = shown + 1
            if item.group then groupShown[item.group] = true end
        end
    end
    for _, g in ipairs(self.groups) do
        g.box.Visible = (query == "") or groupShown[g] == true
    end
    self.Empty.Visible = (shown == 0)
end

-- เริ่มกล่องใหม่ (หัวข้อ + แถวตัวเลือกด้านใน) — ตัวเลือกที่เพิ่มต่อจากนี้จะอยู่ในกล่องนี้
function Page:AddSection(text)
    text = text or ""
    self.order = self.order + 1
    local box = create("Frame", {
        Size = UDim2.new(1, -6, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = THEME.box,
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
        LayoutOrder = self.order,
    }, self.Scroll)
    corner(box, 16)
    stroke(box, THEME.border, 1, 0.8)
    create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder}, box)
    create("UIPadding", {PaddingBottom = UDim.new(0, 4)}, box)

    local g = {box = box, order = 0, hasHeader = text ~= "", titleLower = string.lower(text)}
    if g.hasHeader then
        local header = create("Frame", {
            Size = UDim2.new(1, 0, 0, 40),
            BackgroundTransparency = 1,
            LayoutOrder = 0,
        }, box)
        local mark = create("Frame", {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 14, 0.5, 1),
            Size = UDim2.fromOffset(4, 14),
            BackgroundColor3 = THEME.accent,
            BorderSizePixel = 0,
        }, header)
        corner(mark, 2)
        local t = label(header, text, 15, THEME.white, Enum.Font.GothamMedium)
        t.Position = UDim2.fromOffset(28, 2)
        t.Size = UDim2.new(1, -42, 1, -2)
        t.TextTruncate = Enum.TextTruncate.AtEnd
    end
    table.insert(self.groups, g)
    self.group = g
    return g
end

function Page:AddInfo(text)
    local g = ensureGroup(self)
    g.order = g.order + 1
    local row = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = g.order,
    }, g.box)
    create("UIPadding", {PaddingBottom = UDim.new(0, 10)}, row)
    addDivider(row, g)
    local t = label(row, text, 12, THEME.muted)
    t.Position = UDim2.fromOffset(14, 10)
    t.Size = UDim2.new(1, -28, 0, 0)
    t.AutomaticSize = Enum.AutomaticSize.Y
    t.TextWrapped = true
    t.TextYAlignment = Enum.TextYAlignment.Top
    self:_register(row, text)
    return row
end

function Page:AddToggle(opts)
    local state = opts.Default == true
    local hasDesc = opts.Description ~= nil and opts.Description ~= ""
    local row = newRow(self, hasDesc and 50 or ROW_H)

    local t = rowLabel(row, opts.Text or "Toggle", 64)
    if hasDesc then
        t.Position = UDim2.fromOffset(14, 6)
        t.Size = UDim2.new(1, -78, 0, 20)
        local d = label(row, opts.Description, 11, THEME.muted)
        d.Position = UDim2.fromOffset(14, 26)
        d.Size = UDim2.new(1, -78, 0, 16)
        d.TextTruncate = Enum.TextTruncate.AtEnd
    end

    local switch = create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0, (hasDesc and 50 or ROW_H) / 2),
        Size = UDim2.fromOffset(42, 24),
        BackgroundColor3 = THEME.off,
        BorderSizePixel = 0,
    }, row)
    corner(switch, 12)
    local knob = create("Frame", {
        Size = UDim2.fromOffset(18, 18),
        Position = UDim2.fromOffset(3, 3),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
    }, switch)
    corner(knob, 9)

    local obj = {kind = "toggle"}
    local pressed = false
    local function render(animate)
        local dur = animate and 0.18 or 0
        local w = pressed and 23 or 18
        local x = state and (42 - 3 - w) or 3
        tween(switch, dur, {BackgroundColor3 = state and THEME.accent or THEME.off})
        tween(knob, animate and 0.14 or 0, {Position = UDim2.fromOffset(x, 3), Size = UDim2.fromOffset(w, 18)})
    end
    function obj:Set(v, silent)
        state = v and true or false
        render(true)
        if not silent then fire(opts.Callback, state) end
    end
    function obj:Get() return state end

    local hit = create("TextButton", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 5,
    }, row)
    connect(hit.MouseButton1Down, function() pressed = true; render(true) end)
    connect(hit.MouseButton1Up, function() pressed = false; render(true) end)
    connect(hit.MouseLeave, function()
        if pressed then pressed = false; render(true) end
    end)
    connect(hit.MouseButton1Click, function() obj:Set(not state) end)

    render(false)
    self:_register(row, (opts.Text or "") .. " " .. (opts.Description or ""), opts.Text)
    return obj
end

function Page:AddSlider(opts)
    local min, max = opts.Min or 0, opts.Max or 100
    local step = opts.Step or 1
    local suffix = opts.Suffix or ""
    local decimals = step < 1 and 2 or 0
    local value = math.clamp(opts.Default or min, min, max)

    local row = newRow(self, ROW_H)
    local t = label(row, opts.Text or "Slider", 13, THEME.white, Enum.Font.Gotham)
    t.Position = UDim2.fromOffset(14, 0)
    t.Size = UDim2.new(0.4, -14, 1, 0)
    t.TextTruncate = Enum.TextTruncate.AtEnd

    local valueBox = create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.fromOffset(50, 22),
        BackgroundColor3 = THEME.panelSoft,
        BorderSizePixel = 0,
    }, row)
    corner(valueBox, 6)
    stroke(valueBox, THEME.border, 1, 0.8)
    local valueLabel = label(valueBox, "", 11, THEME.white, Enum.Font.GothamMedium)
    valueLabel.Size = UDim2.fromScale(1, 1)
    valueLabel.TextXAlignment = Enum.TextXAlignment.Center

    local track = create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0.4, 0, 0.5, 0),
        Size = UDim2.new(0.6, -76, 0, 4),
        BackgroundColor3 = THEME.off,
        BorderSizePixel = 0,
    }, row)
    corner(track, 2)
    local fill = create("Frame", {
        Size = UDim2.fromScale(0, 1), BackgroundColor3 = THEME.accent, BorderSizePixel = 0,
    }, track)
    corner(fill, 2)
    local knob = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0, 0.5),
        Size = UDim2.fromOffset(14, 14),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
    }, track)
    corner(knob, 7)

    local obj = {kind = "slider"}
    local function render(animate)
        local ratio = (max == min) and 0 or (value - min) / (max - min)
        local dur = animate and 0.08 or 0
        tween(fill, dur, {Size = UDim2.fromScale(ratio, 1)}, Enum.EasingStyle.Linear)
        tween(knob, dur, {Position = UDim2.fromScale(ratio, 0.5)}, Enum.EasingStyle.Linear)
        valueLabel.Text = string.format("%." .. decimals .. "f", value) .. suffix
    end
    function obj:Set(v, silent)
        v = math.clamp(v, min, max)
        value = min + math.floor((v - min) / step + 0.5) * step
        value = math.clamp(value, min, max)
        render(true)
        if not silent then fire(opts.Callback, value) end
    end
    function obj:Get() return value end

    local hit = create("TextButton", {
        Position = UDim2.new(0.4, -8, 0, 0),
        Size = UDim2.new(0.6, -66, 1, 0),
        BackgroundTransparency = 1, Text = "", ZIndex = 5,
    }, row)

    local dragging = false
    local function updateFromX(x)
        local ratio = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
        obj:Set(min + (max - min) * ratio)
    end
    connect(hit.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            self.Scroll.ScrollingEnabled = false
            tween(knob, 0.1, {Size = UDim2.fromOffset(18, 18)})
            updateFromX(input.Position.X)
            local endConn
            endConn = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    self.Scroll.ScrollingEnabled = true
                    tween(knob, 0.1, {Size = UDim2.fromOffset(14, 14)})
                    endConn:Disconnect()
                end
            end)
        end
    end)
    connect(UserInputService.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            updateFromX(input.Position.X)
        end
    end)

    render(false)
    self:_register(row, opts.Text, opts.Text)
    return obj
end

function Page:AddButton(opts)
    local hasDesc = opts.Description ~= nil and opts.Description ~= ""
    local H = hasDesc and 50 or ROW_H
    local row = newRow(self, H)
    local t = rowLabel(row, opts.Text or "Button", 40)
    if hasDesc then
        t.Position = UDim2.fromOffset(14, 6)
        t.Size = UDim2.new(1, -54, 0, 20)
        local d = label(row, opts.Description, 11, THEME.muted)
        d.Position = UDim2.fromOffset(14, 26)
        d.Size = UDim2.new(1, -54, 0, 16)
        d.TextTruncate = Enum.TextTruncate.AtEnd
    end
    local arrow = label(row, "›", 20, THEME.muted, Enum.Font.GothamBold)
    arrow.AnchorPoint = Vector2.new(1, 0.5)
    arrow.Position = UDim2.new(1, -14, 0, H / 2 - 1)
    arrow.Size = UDim2.fromOffset(18, 24)
    arrow.TextXAlignment = Enum.TextXAlignment.Center

    local hit = create("TextButton", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 5,
    }, row)
    connect(hit.MouseButton1Down, function() tween(row, 0.08, {BackgroundColor3 = THEME.accentSoft, BackgroundTransparency = 0.6}) end)
    connect(hit.MouseButton1Up, function() tween(row, 0.18, {BackgroundTransparency = 1}) end)
    connect(hit.MouseLeave, function() tween(row, 0.18, {BackgroundTransparency = 1}) end)
    connect(hit.MouseButton1Click, function()
        fire(opts.Callback)
        if opts.Notify ~= false then notify((opts.Text or "Button") .. " ✓") end
    end)
    self:_register(row, (opts.Text or "") .. " " .. (opts.Description or ""), opts.Text)
    return row
end

function Page:AddDropdown(opts)
    local options = opts.Options or {}
    local multi = opts.Multi == true
    local selected
    local chosen = {}
    if multi then
        local d = opts.Default
        if type(d) == "table" then
            for _, n in ipairs(d) do chosen[n] = true end
        elseif d ~= nil then
            chosen[d] = true
        end
    else
        selected = opts.Default or options[1]
    end
    local open = false
    local HEAD = ROW_H

    local row = newRow(self, HEAD)
    rowLabel(row, opts.Text or "Dropdown", 142)

    local pill = create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0, HEAD / 2),
        Size = UDim2.fromOffset(122, 24),
        BackgroundColor3 = THEME.panelSoft,
        BorderSizePixel = 0,
    }, row)
    corner(pill, 6)
    stroke(pill, THEME.border, 1, 0.8)
    local valueLabel = label(pill, "", 11, THEME.white, Enum.Font.GothamMedium)
    valueLabel.Position = UDim2.fromOffset(8, 0)
    valueLabel.Size = UDim2.new(1, -24, 1, 0)
    valueLabel.TextTruncate = Enum.TextTruncate.AtEnd
    local chevron = label(pill, "›", 16, THEME.muted, Enum.Font.GothamBold)
    chevron.Rotation = 90
    chevron.AnchorPoint = Vector2.new(1, 0.5)
    chevron.Position = UDim2.new(1, -6, 0.5, 0)
    chevron.Size = UDim2.fromOffset(12, 18)
    chevron.TextXAlignment = Enum.TextXAlignment.Center

    local optionButtons, indicators = {}, {}
    local obj = {kind = multi and "multi" or "dropdown"}

    local function isSelected(name)
        if multi then return chosen[name] == true end
        return name == selected
    end
    local function getList()
        local list = {}
        for _, n in ipairs(options) do
            if chosen[n] then table.insert(list, n) end
        end
        return list
    end
    local function summary()
        if not multi then return tostring(selected or "") end
        local list = getList()
        if #list == 0 then return "ไม่ได้เลือก" end
        if #list == 1 then return tostring(list[1]) end
        return "เลือก " .. #list .. " รายการ"
    end
    local function refreshOptions()
        valueLabel.Text = summary()
        for name, b in pairs(optionButtons) do
            local sel = isSelected(name)
            local props = {BackgroundColor3 = sel and THEME.accentSoft or THEME.panelSoft}
            if open then props.BackgroundTransparency = sel and 0 or 0.35 end
            tween(b, 0.15, props)
            if indicators[name] then
                tween(indicators[name], 0.15, {BackgroundColor3 = sel and THEME.accent or THEME.off})
            end
        end
    end
    function obj:Set(v, silent)
        if multi then
            chosen = {}
            if type(v) == "table" then
                for _, n in ipairs(v) do chosen[n] = true end
            end
        else
            selected = v
        end
        refreshOptions()
        if not silent then fire(opts.Callback, multi and getList() or selected) end
    end
    function obj:Get()
        if multi then return getList() end
        return selected
    end

    -- ปรับความสูงทันที (ไม่ tween) กันการ์ดข้างล่างตามไม่ทันแล้วซ้อนทับ
    local openToken = 0
    local function expandedHeight() return HEAD + #options * OPT_H + 6 end
    local function setOpen(state)
        open = state
        openToken = openToken + 1
        local token = openToken
        tween(chevron, 0.2, {Rotation = state and -90 or 90})
        if state then
            row.Size = UDim2.new(1, 0, 0, expandedHeight())
            for name, b in pairs(optionButtons) do
                b.Visible = true
                b.BackgroundTransparency = 1
                b.TextTransparency = 1
                tween(b, 0.18, {
                    BackgroundTransparency = isSelected(name) and 0 or 0.35,
                    TextTransparency = 0,
                })
                if indicators[name] then
                    indicators[name].BackgroundTransparency = 1
                    tween(indicators[name], 0.18, {BackgroundTransparency = 0})
                end
            end
        else
            for name, b in pairs(optionButtons) do
                tween(b, 0.1, {BackgroundTransparency = 1, TextTransparency = 1})
                if indicators[name] then
                    tween(indicators[name], 0.1, {BackgroundTransparency = 1})
                end
            end
            task.delay(0.1, function()
                if token == openToken and not open then
                    row.Size = UDim2.new(1, 0, 0, HEAD)
                    for _, b in pairs(optionButtons) do b.Visible = false end
                end
            end)
        end
    end

    local function buildOptions()
        for _, bb in pairs(optionButtons) do bb:Destroy() end
        optionButtons, indicators = {}, {}
        for i, name in ipairs(options) do
            local b = create("TextButton", {
                Position = UDim2.new(0, 10, 0, HEAD + (i - 1) * OPT_H),
                Size = UDim2.new(1, -20, 0, OPT_H - 3),
                BackgroundColor3 = THEME.panelSoft,
                BackgroundTransparency = 0.35,
                BorderSizePixel = 0,
                Text = tostring(name),
                TextColor3 = THEME.white,
                TextSize = 12,
                Font = Enum.Font.Gotham,
                AutoButtonColor = false,
                Visible = open,
            }, row)
            corner(b, 7)
            optionButtons[name] = b
            if multi then
                b.TextXAlignment = Enum.TextXAlignment.Left
                padding(b, 12, 0, 36, 0)
                local box = create("Frame", {
                    AnchorPoint = Vector2.new(1, 0.5),
                    Position = UDim2.new(1, -10, 0.5, 0),
                    Size = UDim2.fromOffset(14, 14),
                    BackgroundColor3 = THEME.off,
                    BorderSizePixel = 0,
                }, b)
                corner(box, 4)
                indicators[name] = box
            end
            connect(b.MouseButton1Click, function()
                if multi then
                    chosen[name] = not chosen[name] or nil
                    refreshOptions()
                    fire(opts.Callback, getList())
                else
                    obj:Set(name)
                    setOpen(false)
                end
            end)
        end
        if open then row.Size = UDim2.new(1, 0, 0, expandedHeight()) end
    end
    buildOptions()

    function obj:SetOptions(list, keep)
        options = list or {}
        if multi then
            local kept = {}
            if keep then
                for _, n in ipairs(options) do
                    if chosen[n] then kept[n] = true end
                end
            end
            chosen = kept
        else
            local found = false
            for _, n in ipairs(options) do
                if n == selected then found = true end
            end
            if not found then selected = options[1] end
        end
        buildOptions()
        refreshOptions()
    end

    local hit = create("TextButton", {
        Size = UDim2.new(1, 0, 0, HEAD), BackgroundTransparency = 1, Text = "", ZIndex = 5,
    }, row)
    connect(hit.MouseButton1Click, function() setOpen(not open) end)

    refreshOptions()
    self:_register(row, (opts.Text or "") .. " " .. table.concat(options, " "), opts.Text)
    return obj
end

function Page:AddColorPicker(opts)
    local HEAD, EXPANDED = ROW_H, ROW_H + 124
    local open = false
    local h, sat, val = (opts.Default or THEME.accent):ToHSV()
    local current = Color3.fromHSV(h, sat, val)

    local row = newRow(self, HEAD)
    rowLabel(row, opts.Text or "Color", 120)

    local swatch = create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0, HEAD / 2),
        Size = UDim2.fromOffset(32, 20),
        BackgroundColor3 = current,
        BorderSizePixel = 0,
    }, row)
    corner(swatch, 6)
    stroke(swatch, THEME.white, 1, 0.7)

    local hexLabel = label(row, "", 11, THEME.muted, Enum.Font.GothamMedium)
    hexLabel.AnchorPoint = Vector2.new(1, 0.5)
    hexLabel.Position = UDim2.new(1, -54, 0, HEAD / 2)
    hexLabel.Size = UDim2.fromOffset(64, 20)
    hexLabel.TextXAlignment = Enum.TextXAlignment.Right

    local panel = create("Frame", {
        Position = UDim2.fromOffset(0, HEAD),
        Size = UDim2.new(1, 0, 0, EXPANDED - HEAD),
        BackgroundTransparency = 1,
        Visible = false,
    }, row)

    local presets = {
        Color3.fromRGB(105, 155, 255), Color3.fromRGB(150, 105, 255), Color3.fromRGB(70, 200, 220),
        Color3.fromRGB(90, 210, 140),  Color3.fromRGB(240, 220, 90),  Color3.fromRGB(255, 160, 80),
        Color3.fromRGB(255, 90, 100),  Color3.fromRGB(255, 120, 170), Color3.fromRGB(245, 247, 255),
        Color3.fromRGB(120, 124, 138),
    }
    local presetRow = create("Frame", {
        Position = UDim2.fromOffset(14, 4),
        Size = UDim2.new(1, -28, 0, 22),
        BackgroundTransparency = 1,
    }, panel)
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 7),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, presetRow)

    local sliders = {}
    local function makeBar(y, onChange)
        local track = create("Frame", {
            Position = UDim2.new(0, 14, 0, y),
            Size = UDim2.new(1, -28, 0, 8),
            BackgroundColor3 = THEME.white,
            BorderSizePixel = 0,
        }, panel)
        corner(track, 4)
        local grad = create("UIGradient", {}, track)
        local knob = create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0, 0.5),
            Size = UDim2.fromOffset(14, 14),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0,
        }, track)
        corner(knob, 7)
        stroke(knob, THEME.black, 1.5, 0.35)

        local hitBar = create("TextButton", {
            Position = UDim2.new(0, 8, 0, y - 9),
            Size = UDim2.new(1, -16, 0, 26),
            BackgroundTransparency = 1, Text = "", ZIndex = 5,
        }, panel)
        local dragging = false
        local function updateFromX(x)
            local ratio = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
            onChange(ratio)
        end
        connect(hitBar.InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                self.Scroll.ScrollingEnabled = false
                updateFromX(input.Position.X)
                local endConn
                endConn = input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                        self.Scroll.ScrollingEnabled = true
                        endConn:Disconnect()
                    end
                end)
            end
        end)
        connect(UserInputService.InputChanged, function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch) then
                updateFromX(input.Position.X)
            end
        end)
        return {grad = grad, knob = knob}
    end

    local function render()
        current = Color3.fromHSV(h, sat, val)
        swatch.BackgroundColor3 = current
        hexLabel.Text = string.format("#%02X%02X%02X",
            math.floor(current.R * 255 + 0.5), math.floor(current.G * 255 + 0.5), math.floor(current.B * 255 + 0.5))
        sliders.hue.knob.Position = UDim2.fromScale(h, 0.5)
        sliders.sat.knob.Position = UDim2.fromScale(sat, 0.5)
        sliders.val.knob.Position = UDim2.fromScale(val, 0.5)
        sliders.sat.grad.Color = ColorSequence.new(Color3.fromHSV(h, 0, val), Color3.fromHSV(h, 1, val))
        sliders.val.grad.Color = ColorSequence.new(Color3.fromHSV(h, sat, 0), Color3.fromHSV(h, sat, 1))
    end
    local function commit()
        render()
        fire(opts.Callback, current)
    end

    sliders.hue = makeBar(44, function(r) h = math.min(r, 0.999); commit() end)
    sliders.sat = makeBar(70, function(r) sat = r; commit() end)
    sliders.val = makeBar(96, function(r) val = r; commit() end)
    sliders.hue.grad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,     Color3.fromHSV(0, 1, 1)),
        ColorSequenceKeypoint.new(1 / 6, Color3.fromHSV(1 / 6, 1, 1)),
        ColorSequenceKeypoint.new(2 / 6, Color3.fromHSV(2 / 6, 1, 1)),
        ColorSequenceKeypoint.new(3 / 6, Color3.fromHSV(3 / 6, 1, 1)),
        ColorSequenceKeypoint.new(4 / 6, Color3.fromHSV(4 / 6, 1, 1)),
        ColorSequenceKeypoint.new(5 / 6, Color3.fromHSV(5 / 6, 1, 1)),
        ColorSequenceKeypoint.new(1,     Color3.fromHSV(0, 1, 1)),
    })

    for i, c in ipairs(presets) do
        local b = create("TextButton", {
            Size = UDim2.fromOffset(22, 22),
            BackgroundColor3 = c,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            LayoutOrder = i,
        }, presetRow)
        corner(b, 6)
        stroke(b, THEME.white, 1, 0.75)
        connect(b.MouseButton1Click, function()
            h, sat, val = c:ToHSV()
            commit()
        end)
    end

    local obj = {kind = "color"}
    function obj:Set(color, silent)
        h, sat, val = color:ToHSV()
        if silent then render() else commit() end
    end
    function obj:Get() return current end

    local hit = create("TextButton", {
        Size = UDim2.new(1, 0, 0, HEAD), BackgroundTransparency = 1, Text = "", ZIndex = 5,
    }, row)
    connect(hit.MouseButton1Click, function()
        open = not open
        panel.Visible = open
        row.Size = UDim2.new(1, 0, 0, open and EXPANDED or HEAD)
    end)

    render()
    self:_register(row, opts.Text, opts.Text)
    return obj
end

function Page:AddInput(opts)
    local row = newRow(self, ROW_H)
    rowLabel(row, opts.Text or "Input", 154)

    local box = create("TextBox", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.fromOffset(134, 24),
        BackgroundColor3 = THEME.panelSoft,
        BorderSizePixel = 0,
        Text = tostring(opts.Default or ""),
        PlaceholderText = opts.Placeholder or "Input",
        PlaceholderColor3 = THEME.muted,
        TextColor3 = THEME.white,
        TextSize = 11,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, row)
    corner(box, 6)
    padding(box, 8, 0, 8, 0)
    local st = stroke(box, THEME.border, 1, 0.8)
    connect(box.Focused, function() tween(st, 0.15, {Color = THEME.accent, Transparency = 0.2}) end)

    local numeric = opts.Numeric == true
    local last = box.Text
    if numeric then
        connect(box:GetPropertyChangedSignal("Text"), function()
            local cleaned = (string.gsub(box.Text, "[^%d%.%-]", ""))
            if cleaned ~= box.Text then box.Text = cleaned end
        end)
    end

    local obj = {kind = "input"}
    local function commit(silent)
        local value = box.Text
        if numeric then
            local n = tonumber(value)
            if n == nil then
                box.Text = last
                return
            end
            if opts.Min then n = math.max(n, opts.Min) end
            if opts.Max then n = math.min(n, opts.Max) end
            box.Text = tostring(n)
            value = n
        end
        last = box.Text
        if not silent then fire(opts.Callback, value) end
    end
    connect(box.FocusLost, function()
        tween(st, 0.15, {Color = THEME.border, Transparency = 0.8})
        commit(false)
    end)
    function obj:Set(v, silent) box.Text = tostring(v); commit(silent) end
    function obj:Get() return numeric and tonumber(box.Text) or box.Text end

    self:_register(row, opts.Text, opts.Text)
    return obj
end

function Page:AddKeybind(opts)
    local key = opts.Default
    local listening = false
    local row = newRow(self, ROW_H)
    rowLabel(row, opts.Text or "Keybind", 90)

    local pill = create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.fromOffset(70, 24),
        BackgroundColor3 = THEME.panelSoft,
        BorderSizePixel = 0,
    }, row)
    corner(pill, 6)
    local pst = stroke(pill, THEME.border, 1, 0.8)
    local pl = label(pill, "", 11, THEME.white, Enum.Font.GothamMedium)
    pl.Size = UDim2.fromScale(1, 1)
    pl.TextXAlignment = Enum.TextXAlignment.Center

    local function render()
        if listening then
            pl.Text = "กดปุ่ม..."
            pl.TextColor3 = THEME.accent
            tween(pst, 0.15, {Color = THEME.accent, Transparency = 0.2})
        else
            pl.Text = key and key.Name or "..."
            pl.TextColor3 = THEME.white
            tween(pst, 0.15, {Color = THEME.border, Transparency = 0.8})
        end
    end

    local obj = {kind = "keybind"}
    function obj:Set(k, silent)
        key = k
        render()
        if not silent then fire(opts.Callback, key) end
    end
    function obj:Get() return key end

    local hit = create("TextButton", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 5,
    }, row)
    connect(hit.MouseButton1Click, function()
        listening = true
        keybindListening = true
        render()
    end)

    connect(UserInputService.InputBegan, function(input, processed)
        if listening then
            if input.UserInputType == Enum.UserInputType.Keyboard then
                listening = false
                task.defer(function() keybindListening = false end)
                if input.KeyCode == Enum.KeyCode.Backspace then
                    obj:Set(nil)
                elseif input.KeyCode ~= Enum.KeyCode.Escape then
                    obj:Set(input.KeyCode)
                else
                    render()
                end
            end
            return
        end
        if not processed and key and input.KeyCode == key then
            fire(opts.OnPress)
        end
    end)

    render()
    self:_register(row, opts.Text, opts.Text)
    return obj
end

function Page:AddSegmented(opts)
    local options = opts.Options or {}
    local selected = opts.Default or options[1]
    local row = newRow(self, 64)
    local t = label(row, opts.Text or "Segmented", 13, THEME.white, Enum.Font.Gotham)
    t.Position = UDim2.fromOffset(14, 6)
    t.Size = UDim2.new(1, -28, 0, 20)
    t.TextTruncate = Enum.TextTruncate.AtEnd

    local bar = create("Frame", {
        Position = UDim2.fromOffset(14, 30),
        Size = UDim2.new(1, -28, 0, 26),
        BackgroundColor3 = THEME.panelSoft,
        BackgroundTransparency = 0.2,
        BorderSizePixel = 0,
    }, row)
    corner(bar, 8)

    local buttons = {}
    local n = math.max(#options, 1)
    local function refresh()
        for name, b in pairs(buttons) do
            local sel = name == selected
            tween(b, 0.15, {
                BackgroundTransparency = sel and 0 or 1,
                TextColor3 = sel and THEME.white or THEME.muted,
            })
        end
    end

    local obj = {kind = "segmented"}
    function obj:Set(v, silent)
        selected = v
        refresh()
        if not silent then fire(opts.Callback, selected) end
    end
    function obj:Get() return selected end

    for i, name in ipairs(options) do
        local b = create("TextButton", {
            Position = UDim2.new((i - 1) / n, 2, 0, 2),
            Size = UDim2.new(1 / n, -4, 1, -4),
            BackgroundColor3 = THEME.accentSoft,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Text = tostring(name),
            TextColor3 = THEME.muted,
            TextSize = 12,
            Font = Enum.Font.GothamMedium,
            AutoButtonColor = false,
        }, bar)
        corner(b, 6)
        buttons[name] = b
        connect(b.MouseButton1Click, function() obj:Set(name) end)
    end

    refresh()
    self:_register(row, (opts.Text or "") .. " " .. table.concat(options, " "), opts.Text)
    return obj
end

function Page:AddProgress(opts)
    local value = math.clamp(opts.Value or 0, 0, 1)
    local row = newRow(self, 46)
    local t = label(row, opts.Text or "Progress", 13, THEME.white, Enum.Font.Gotham)
    t.Position = UDim2.fromOffset(14, 6)
    t.Size = UDim2.new(1, -90, 0, 20)
    t.TextTruncate = Enum.TextTruncate.AtEnd

    local pct = label(row, "", 11, THEME.accent, Enum.Font.GothamBold)
    pct.AnchorPoint = Vector2.new(1, 0)
    pct.Position = UDim2.new(1, -14, 0, 7)
    pct.Size = UDim2.fromOffset(60, 18)
    pct.TextXAlignment = Enum.TextXAlignment.Right

    local track = create("Frame", {
        Position = UDim2.new(0, 14, 0, 32),
        Size = UDim2.new(1, -28, 0, 6),
        BackgroundColor3 = THEME.off,
        BorderSizePixel = 0,
    }, row)
    corner(track, 3)
    local fill = create("Frame", {
        Size = UDim2.fromScale(value, 1), BackgroundColor3 = THEME.accent, BorderSizePixel = 0,
    }, track)
    corner(fill, 3)

    local obj = {}
    local function render(animate)
        tween(fill, animate and 0.25 or 0, {Size = UDim2.fromScale(value, 1)})
        pct.Text = math.floor(value * 100 + 0.5) .. "%"
    end
    function obj:Set(v) value = math.clamp(v, 0, 1); render(true) end
    function obj:Get() return value end

    render(false)
    self:_register(row, opts.Text, opts.Text)
    return obj
end

local Handlers, Controls = {}, {}
local scheduleAutosave   -- กำหนดค่าด้านล่าง (ระบบบันทึกการตั้งค่า)
local function cb(id)
    return function(...)
        local f = Handlers[id]
        local r
        if f then r = f(...) end
        if scheduleAutosave then scheduleAutosave() end
        return r
    end
end

-- ทางลัดแบบมี id: ผูกระบบผ่าน UI.Handlers[id] และควบคุมผ่าน UI.Controls[id]
function Page:Check(id, text, default, desc)
    local c = self:AddToggle({Text = text, Description = desc, Default = default or false, Callback = cb(id)})
    Controls[id] = c
    return c
end
function Page:Slider(id, text, default, min, max, rounding)
    local c = self:AddSlider({
        Text = text, Min = min, Max = max, Default = default,
        Step = 1 / (10 ^ (rounding or 0)), Callback = cb(id),
    })
    Controls[id] = c
    return c
end
function Page:Drop(id, text, values, defaultIndex)
    local c = self:AddDropdown({
        Text = text, Options = values, Default = values[defaultIndex or 1], Callback = cb(id),
    })
    Controls[id] = c
    return c
end
function Page:Btn(text, id)
    return self:AddButton({Text = text, Callback = cb("btn_" .. id)})
end
function Page:Color(id, title, color)
    local c = self:AddColorPicker({Text = title, Default = color, Callback = cb(id)})
    Controls[id] = c
    return c
end
function Page:Input(id, text, placeholder)
    local c = self:AddInput({Text = text, Placeholder = placeholder, Callback = cb(id)})
    Controls[id] = c
    return c
end

local function createPage(name, hint)
    local holder = create("CanvasGroup", {
        Name = "Page_" .. name,
        Position = UDim2.new(0, 0, 0, 80),
        Size = UDim2.new(1, 0, 1, -80),
        BackgroundTransparency = 1,
        GroupTransparency = 1,
        Visible = false,
    }, content)

    local scroll = create("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = THEME.accent,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
    }, holder)
    padding(scroll, 22, 4, 16, 14)
    create("UIListLayout", {
        Padding = UDim.new(0, 10),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, scroll)

    local empty = label(scroll, "ไม่พบผลลัพธ์", 13, THEME.muted)
    empty.Size = UDim2.new(1, -6, 0, 40)
    empty.TextXAlignment = Enum.TextXAlignment.Center
    empty.LayoutOrder = 99999
    empty.Visible = false

    local page = setmetatable({
        Name = name, Hint = hint, Holder = holder, Scroll = scroll,
        Empty = empty, items = {}, order = 0, groups = {}, group = nil,
    }, Page)
    pages[name] = page
    table.insert(pageOrder, name)
    return page
end

---------------------------------------------------------------------
-- TABS
---------------------------------------------------------------------
local tabButtons = {}

local function showTab(name)
    local page = pages[name]
    if not page or page == currentPage then return end
    local old = currentPage
    currentPage = page

    -- sidebar state
    for tabName, t in pairs(tabButtons) do
        local sel = tabName == name
        tween(t.button, 0.2, {BackgroundTransparency = sel and 0.15 or 1})
        tween(t.name, 0.2, {TextColor3 = sel and THEME.white or THEME.muted})
        if t.icon:IsA("ImageLabel") then
            tween(t.icon, 0.2, {ImageColor3 = sel and THEME.accent or THEME.muted})
        else
            tween(t.icon, 0.2, {TextColor3 = sel and THEME.accent or THEME.muted, TextTransparency = sel and 0 or 0.3})
        end
        tween(t.bar, 0.25, {Size = UDim2.fromOffset(3, sel and 18 or 0)})
    end

    -- heading
    contentTitle.Text = name
    contentHint.Text = page.Hint or ""
    contentTitle.TextTransparency, contentHint.TextTransparency = 1, 1
    tween(contentTitle, 0.3, {TextTransparency = 0})
    tween(contentHint, 0.3, {TextTransparency = 0})

    -- old page out
    if old then
        old.Holder.Visible = false
        old.Holder.GroupTransparency = 1
    end

    -- new page in
    searchBox.Text = ""
    page:ApplyFilter("")
    page.Holder.Position = UDim2.new(0, 14, 0, 80)
    page.Holder.GroupTransparency = 1
    page.Holder.Visible = true
    tween(page.Holder, 0.32, {GroupTransparency = 0, Position = UDim2.new(0, 0, 0, 80)})
end

connect(searchBox:GetPropertyChangedSignal("Text"), function()
    if currentPage then currentPage:ApplyFilter(searchBox.Text) end
end)

local function createTab(name, icon, hint)
    local index = #pageOrder + 1
    local page = createPage(name, hint)

    local button = create("TextButton", {
        Name = "Tab_" .. index,
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundColor3 = THEME.accentSoft,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        LayoutOrder = index,
    }, tabList)
    corner(button, 14)

    local bar = create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 3, 0.5, 0),
        Size = UDim2.fromOffset(3, 0),
        BackgroundColor3 = THEME.accent,
        BorderSizePixel = 0,
    }, button)
    corner(bar, 2)

    -- ไอคอนแท็บ: ถ้าเป็นรหัสรูป (ตัวเลข หรือ "rbxassetid://...") ใช้ ImageLabel ไม่งั้นใช้ข้อความ/อีโมจิ
    local iconSource = TAB_ICON_IMAGES[name] or icon
    local asImage = type(iconSource) == "number"
        or (type(iconSource) == "string" and string.sub(iconSource, 1, 13) == "rbxassetid://")
    local iconLabel
    if asImage then
        iconLabel = create("ImageLabel", {
            BackgroundTransparency = 1,
            Image = type(iconSource) == "number" and ("rbxassetid://" .. iconSource) or iconSource,
            ImageColor3 = THEME.muted,
            ScaleType = Enum.ScaleType.Fit,
            Position = UDim2.new(0, 15, 0.5, -9),
            Size = UDim2.fromOffset(18, 18),
        }, button)
    else
        iconLabel = label(button, iconSource, 15, THEME.muted, Enum.Font.GothamBold)
        iconLabel.Position = UDim2.fromOffset(14, 0)
        iconLabel.Size = UDim2.new(0, 22, 1, 0)
        iconLabel.TextXAlignment = Enum.TextXAlignment.Center
        iconLabel.TextTransparency = 0.3
    end

    local nameLabel = label(button, name, 13, THEME.muted, Enum.Font.GothamMedium)
    nameLabel.Position = UDim2.fromOffset(44, 0)
    nameLabel.Size = UDim2.new(1, -52, 1, 0)

    tabButtons[name] = {button = button, bar = bar, icon = iconLabel, name = nameLabel}

    connect(button.MouseEnter, function()
        if currentPage ~= page then tween(button, 0.15, {BackgroundTransparency = 0.6}) end
    end)
    connect(button.MouseLeave, function()
        if currentPage ~= page then tween(button, 0.15, {BackgroundTransparency = 1}) end
    end)
    connect(button.MouseButton1Click, function() showTab(name) end)
    return page
end

---------------------------------------------------------------------
-- THEME (สลับโทนสี/สีหลักสด ๆ โดยเปลี่ยนสีที่ตรงกับโทเคนเดิมทั้งหมด)
---------------------------------------------------------------------
local themeSeg, accentDrop

local function applyTheme(schemeName, accent)
    schemeName = schemeName or themeState.scheme
    accent = accent or themeState.accent
    if not SCHEMES[schemeName] then return false end
    local old = {}
    for _, key in ipairs(THEME_TOKENS) do old[key] = THEME[key] end
    local new = buildTokens(schemeName, accent)
    for _, key in ipairs(THEME_TOKENS) do THEME[key] = new[key] end
    themeState.scheme, themeState.accent = schemeName, accent

    local PROPS = {"BackgroundColor3", "TextColor3", "ImageColor3", "ScrollBarImageColor3", "PlaceholderColor3", "Color"}
    for _, inst in ipairs(gui:GetDescendants()) do
        if inst:IsA("GuiObject") or inst:IsA("UIStroke") then
            for _, prop in ipairs(PROPS) do
                local ok, cur = pcall(function() return inst[prop] end)
                if ok and typeof(cur) == "Color3" then
                    for _, key in ipairs(THEME_TOKENS) do
                        if cur == old[key] then
                            pcall(function() inst[prop] = new[key] end)
                            break
                        end
                    end
                end
            end
        end
    end
    return true
end

---------------------------------------------------------------------
-- COMMAND PALETTE (ค้นหาด่วนข้ามทุกหน้า)
---------------------------------------------------------------------
local paletteOpen = false
local palette = create("Frame", {
    Name = "Palette",
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = THEME.black,
    BackgroundTransparency = 0.45,
    BorderSizePixel = 0,
    Visible = false,
    Active = true,
    ZIndex = 50,
}, canvas)

local pPanel = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.new(0, 400, 0, 340),
    BackgroundColor3 = THEME.card,
    BorderSizePixel = 0,
}, palette)
corner(pPanel, 16)
stroke(pPanel, THEME.border, 1, 0.6)

local pBox = create("TextBox", {
    Position = UDim2.fromOffset(14, 14),
    Size = UDim2.new(1, -28, 0, 38),
    BackgroundColor3 = THEME.panelSoft,
    BorderSizePixel = 0,
    PlaceholderText = "ค้นหาตัวเลือกทั้งหมด...",
    PlaceholderColor3 = THEME.muted,
    Text = "",
    TextColor3 = THEME.white,
    TextSize = 14,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left,
    ClearTextOnFocus = false,
}, pPanel)
corner(pBox, 10)
padding(pBox, 12, 0, 12, 0)

local pList = create("ScrollingFrame", {
    Position = UDim2.fromOffset(14, 62),
    Size = UDim2.new(1, -28, 1, -76),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = THEME.accent,
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, pPanel)
create("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, pList)

local resultRows = {}
local firstResult

local function closePalette()
    paletteOpen = false
    palette.Visible = false
    pBox:ReleaseFocus()
end

local function jumpTo(item)
    closePalette()
    local page = item.page
    showTab(page.Name)
    task.delay(0.35, function()
        local card, scroll = item.card, page.Scroll
        if not card.Parent then return end
        local scale = math.max(windowScale.Scale, 0.01)
        local delta = (card.AbsolutePosition.Y - scroll.AbsolutePosition.Y) / scale
        scroll.CanvasPosition = Vector2.new(0, math.max(scroll.CanvasPosition.Y + delta - 12, 0))
        card.BackgroundColor3 = THEME.accent
        card.BackgroundTransparency = 0.78
        tween(card, 1, {BackgroundTransparency = 1})
    end)
end

local function refreshResults()
    for _, r in ipairs(resultRows) do r:Destroy() end
    resultRows, firstResult = {}, nil
    local q = string.lower(pBox.Text)
    local shown = 0
    for _, pname in ipairs(pageOrder) do
        local page = pages[pname]
        for _, item in ipairs(page.items) do
            if shown >= 30 then break end
            local hay = item.text .. " " .. string.lower(pname)
            if q == "" or string.find(hay, q, 1, true) then
                shown = shown + 1
                if not firstResult then firstResult = item end
                local b = create("TextButton", {
                    Size = UDim2.new(1, -4, 0, 36),
                    BackgroundColor3 = THEME.panelSoft,
                    BackgroundTransparency = 0.4,
                    BorderSizePixel = 0,
                    Text = "",
                    AutoButtonColor = false,
                    LayoutOrder = shown,
                }, pList)
                corner(b, 10)
                local t = label(b, item.title or string.sub(item.text, 1, 30), 13, THEME.white, Enum.Font.Gotham)
                t.Position = UDim2.fromOffset(12, 0)
                t.Size = UDim2.new(1, -112, 1, 0)
                t.TextTruncate = Enum.TextTruncate.AtEnd
                local tag = label(b, pname, 11, THEME.accent, Enum.Font.GothamMedium)
                tag.AnchorPoint = Vector2.new(1, 0)
                tag.Position = UDim2.new(1, -12, 0, 0)
                tag.Size = UDim2.fromOffset(96, 36)
                tag.TextXAlignment = Enum.TextXAlignment.Right
                tag.TextTruncate = Enum.TextTruncate.AtEnd
                connect(b.MouseEnter, function() tween(b, 0.1, {BackgroundTransparency = 0.1}) end)
                connect(b.MouseLeave, function() tween(b, 0.15, {BackgroundTransparency = 0.4}) end)
                connect(b.MouseButton1Click, function() jumpTo(item) end)
                table.insert(resultRows, b)
            end
        end
    end
    if shown == 0 then
        local e = label(pList, "ไม่พบผลลัพธ์", 12, THEME.muted)
        e.Size = UDim2.new(1, 0, 0, 36)
        e.TextXAlignment = Enum.TextXAlignment.Center
        table.insert(resultRows, e)
    end
end

local function openPalette()
    paletteOpen = true
    pBox.Text = ""
    palette.Visible = true
    refreshResults()
    pBox:CaptureFocus()
end

connect(pBox:GetPropertyChangedSignal("Text"), function()
    if paletteOpen then refreshResults() end
end)
connect(pBox.FocusLost, function(enterPressed)
    if enterPressed and firstResult then jumpTo(firstResult) end
end)
connect(palette.InputBegan, function(input)
    -- แตะที่พื้นหลังมืดเพื่อปิด
    if (input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch) then
        local pos = input.Position
        local ap, as = pPanel.AbsolutePosition, pPanel.AbsoluteSize
        if pos.X < ap.X or pos.X > ap.X + as.X or pos.Y < ap.Y or pos.Y > ap.Y + as.Y then
            closePalette()
        end
    end
end)

local quickButton = create("TextButton", {
    Name = "QuickSearch",
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -60, 0.5, 0),
    Size = UDim2.fromOffset(72, 34),
    BackgroundColor3 = THEME.card,
    BorderSizePixel = 0,
    Text = "ค้นหา",
    TextColor3 = THEME.white,
    TextSize = 12,
    Font = Enum.Font.GothamMedium,
    AutoButtonColor = false,
}, header)
corner(quickButton, 12)
connect(quickButton.MouseEnter, function() tween(quickButton, 0.15, {BackgroundColor3 = THEME.accentSoft}) end)
connect(quickButton.MouseLeave, function() tween(quickButton, 0.15, {BackgroundColor3 = THEME.card}) end)
connect(quickButton.MouseButton1Click, function()
    if paletteOpen then closePalette() else openPalette() end
end)

connect(UserInputService.InputBegan, function(input, processed)
    if input.KeyCode == Enum.KeyCode.Escape and paletteOpen then
        closePalette()
    elseif input.KeyCode == Enum.KeyCode.K and not processed
        and (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)) then
        if paletteOpen then closePalette() else openPalette() end
    end
end)

---------------------------------------------------------------------
-- CONFIG (บันทึก/โหลดการตั้งค่าเป็นไฟล์ JSON)
---------------------------------------------------------------------
local HttpService = game:GetService("HttpService")
local CFG_ROOT = "ZeroHub"
local CFG_DIR = CFG_ROOT .. "/" .. (config.Name or "UI")
local canFS = type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
    and type(makefolder) == "function" and type(isfolder) == "function"
local autoSave = config.AutoSave ~= false
local loadingConfig = false
local autosaveToken = 0

local function cfgName(name)
    name = tostring(name or "")
    name = string.gsub(name, '[\\/:*?"<>|%c]', "")
    name = string.gsub(name, "^%s+", "")
    name = string.gsub(name, "%s+$", "")
    return name
end
local function cfgPath(name) return CFG_DIR .. "/" .. name .. ".json" end
local function ensureDir()
    if not canFS then return false end
    pcall(function()
        if not isfolder(CFG_ROOT) then makefolder(CFG_ROOT) end
        if not isfolder(CFG_DIR) then makefolder(CFG_DIR) end
    end)
    return true
end

local function encodeValue(c)
    local v = c:Get()
    if c.kind == "color" then return {v.R, v.G, v.B} end
    if c.kind == "keybind" then return v and v.Name or false end
    return v
end
local function decodeValue(c, v)
    if c.kind == "color" then
        if type(v) == "table" then return Color3.new(v[1] or 0, v[2] or 0, v[3] or 0) end
        return nil
    end
    if c.kind == "keybind" then
        if type(v) == "string" then
            local ok, key = pcall(function() return Enum.KeyCode[v] end)
            return ok and key or nil
        end
        return nil
    end
    return v
end

local Window = {}

function Window:SaveConfig(name)
    name = cfgName(name)
    if name == "" or not ensureDir() then return false end
    local data = {
        version = 1,
        theme = {scheme = themeState.scheme, accent = {themeState.accent.R, themeState.accent.G, themeState.accent.B}},
        values = {},
    }
    for id, c in pairs(Controls) do
        if c.kind and c.Get then
            local ok, v = pcall(encodeValue, c)
            if ok then data.values[id] = v end
        end
    end
    local ok = pcall(function() writefile(cfgPath(name), HttpService:JSONEncode(data)) end)
    return ok
end

function Window:LoadConfig(name, silent)
    name = cfgName(name)
    if name == "" or not canFS then return false end
    local okExists, exists = pcall(isfile, cfgPath(name))
    if not (okExists and exists) then return false end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(cfgPath(name))) end)
    if not ok or type(data) ~= "table" then return false end
    loadingConfig = true
    if type(data.theme) == "table" and SCHEMES[data.theme.scheme] then
        local a = data.theme.accent
        local accent = type(a) == "table" and Color3.new(a[1] or 0, a[2] or 0, a[3] or 0) or themeState.accent
        applyTheme(data.theme.scheme, accent)
        if themeSeg then themeSeg:Set(data.theme.scheme, true) end
    end
    for id, v in pairs(data.values or {}) do
        local c = Controls[id]
        if c and c.Set then
            pcall(function() c:Set(decodeValue(c, v), silent) end)
        end
    end
    loadingConfig = false
    return true
end

function Window:ListConfigs()
    if not canFS or type(listfiles) ~= "function" then return {} end
    ensureDir()
    local out = {}
    local ok, files = pcall(listfiles, CFG_DIR)
    if ok and type(files) == "table" then
        for _, f in ipairs(files) do
            local base = string.match(string.gsub(tostring(f), "\\", "/"), "([^/]+)%.json$")
            if base then table.insert(out, base) end
        end
    end
    table.sort(out)
    return out
end

function Window:DeleteConfig(name)
    name = cfgName(name)
    if name == "" or not canFS or type(delfile) ~= "function" then return false end
    return (pcall(delfile, cfgPath(name)))
end

function Window:SetAutoSave(v) autoSave = v and true or false end

scheduleAutosave = function()
    if not autoSave or loadingConfig or not canFS then return end
    autosaveToken = autosaveToken + 1
    local token = autosaveToken
    task.delay(1.5, function()
        if token == autosaveToken then Window:SaveConfig("auto") end
    end)
end

---------------------------------------------------------------------
-- SHOW / HIDE
---------------------------------------------------------------------
local function finishHide()
    window.Visible = false
    window.Rotation = 0
    windowScale.Scale = normalScale
    canvas.GroupTransparency = 0
    windowStroke.Transparency = 0.25
end

local function setVisible(state)
    visibleToken = visibleToken + 1
    local token = visibleToken
    visible = state
    refreshBackground()

    if state then
        window.Visible = true
        if animationsEnabled then
            canvas.GroupTransparency = 1
            windowStroke.Transparency = 1
            window.Rotation = -2
            windowScale.Scale = normalScale * 0.82
            tween(canvas, 0.38, {GroupTransparency = 0})
            tween(windowStroke, 0.38, {Transparency = 0.25})
            tween(window, 0.42, {Rotation = 0})
            tween(windowScale, 0.5, {Scale = normalScale}, Enum.EasingStyle.Back)
        else
            canvas.GroupTransparency = 0
            windowStroke.Transparency = 0.25
            window.Rotation = 0
            windowScale.Scale = normalScale
        end
    else
        if animationsEnabled then
            tween(canvas, 0.16, {GroupTransparency = 1}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            tween(windowStroke, 0.16, {Transparency = 1})
            local shrink = tween(windowScale, 0.22, {Scale = normalScale * 0.84},
                Enum.EasingStyle.Quint, Enum.EasingDirection.In)
            shrink.Completed:Connect(function()
                if token == visibleToken and not visible then finishHide() end
            end)
        else
            finishHide()
        end
    end
end

local toggleWasDragged = makeDraggable(toggleButton, toggleHolder)
connect(toggleButton.MouseButton1Click, function()
    if toggleWasDragged() then return end -- ลากอยู่ ไม่ใช่คลิก
    tween(toggleButton, 0.08, {Size = UDim2.fromOffset(42, 42), Position = UDim2.fromOffset(8, 8)})
    task.delay(0.08, function()
        tween(toggleButton, 0.1, {Size = UDim2.fromOffset(48, 48), Position = UDim2.fromOffset(5, 5)})
    end)
    setVisible(not visible)
end)
connect(closeButton.MouseButton1Click, function() setVisible(false) end)
makeDraggable(header, window)

connect(UserInputService.InputBegan, function(input, processed)
    if processed then return end
    if input.KeyCode == menuKey and not keybindListening then
        setVisible(not visible)
    end
end)

---------------------------------------------------------------------
-- START / UNLOAD
---------------------------------------------------------------------
window.Visible = false
-- รอให้สคริปต์หลักสร้างแท็บเสร็จก่อน แล้วค่อยเปิดแท็บแรกและแสดงหน้าต่าง
task.defer(function()
    if pageOrder[1] then showTab(pageOrder[1]) end
    setVisible(true)
end)

_G[UNLOAD_KEY] = function()
    for _, c in ipairs(connections) do
        pcall(function() c:Disconnect() end)
    end
    table.clear(connections)
    if gui then gui:Destroy() end
    _G[UNLOAD_KEY] = nil
end


Window.Pages = pages
Window.Handlers = Handlers
Window.Controls = Controls
Window.Notify = notify
Window.Show = function() setVisible(true) end
Window.Hide = function() setVisible(false) end
Window.Unload = _G[UNLOAD_KEY]
Window.Themes = {"graphite", "midnight", "porcelain"}

function Window:AddTab(name, icon, hint)
    return createTab(name, icon, hint)
end

function Window:Select(name)
    showTab(name)
end

-- ตัวเลือกตั้งค่า UI สำเร็จรูป (แอนิเมชัน ปุ่มลอย พื้นหลัง สี ปุ่มลัด ฯลฯ)
function Window:BuildSettings(ui)
ui:AddSection("ธีม")
themeSeg = ui:AddSegmented({
    Text = "โทนสี", Options = {"graphite", "midnight", "porcelain"}, Default = "graphite",
    Callback = function(v) applyTheme(v) end,
})
local accentNames = {}
for _, a in ipairs(ACCENTS) do table.insert(accentNames, a.name) end
accentDrop = ui:AddDropdown({
    Text = "สีหลัก", Options = accentNames, Default = accentNames[1],
    Callback = function(name)
        for _, a in ipairs(ACCENTS) do
            if a.name == name then applyTheme(nil, a.color) end
        end
    end,
})
ui:AddSection("ตั้งค่า UI (ใหม่)")
ui:AddToggle({
    Text = "แอนิเมชันเปิด/ปิดเมนู", Description = "เปิดไว้เพื่อความลื่นไหล", Default = true,
    Callback = function(v) animationsEnabled = v end,
})
ui:AddToggle({
    Text = "แสดงปุ่มลอย", Description = "ปิดแล้วใช้ปุ่มลัดเปิดเมนูแทน", Default = true,
    Callback = function(v) toggleHolder.Visible = v end,
})
ui:AddToggle({
    Text = "พื้นหลังเคลื่อนไหว", Description = "เอฟเฟกต์เบา ๆ • ปิดเพื่อประหยัดเครื่อง", Default = true,
    Callback = function(v) bgEnabled = v; refreshBackground() end,
})
ui:AddSlider({
    Text = "ความโปร่งใสหน้าต่าง", Min = 0, Max = 0.6, Default = 0.08, Step = 0.02,
    Callback = function(v) tween(canvas, 0.1, {BackgroundTransparency = v}) end,
})
ui:AddSlider({
    Text = "ขนาดหน้าต่าง", Min = 0.7, Max = 1.2, Default = 1, Step = 0.05, Suffix = "x",
    Callback = function(v) userScale = v; fitWindow() end,
})
ui:AddColorPicker({
    Text = "สีจุดโลโก้", Default = logoDot.BackgroundColor3,
    Callback = function(c) logoDot.BackgroundColor3 = c end,
})
ui:AddColorPicker({
    Text = "สีลูกแสงพื้นหลัง", Default = THEME.accent,
    Callback = function(c)
        for _, orb in ipairs(orbFrames) do
            for _, layer in ipairs(orb:GetChildren()) do
                if layer:IsA("Frame") then layer.BackgroundColor3 = c end
            end
        end
    end,
})
ui:AddKeybind({
    Text = "ปุ่มลัดเปิด/ปิดเมนู", Default = Enum.KeyCode.RightShift,
    Callback = function(k) menuKey = k end,
})
ui:AddSegmented({
    Text = "ตำแหน่งการแจ้งเตือน", Options = {"ล่าง", "บน"}, Default = "ล่าง",
    Callback = function(v)
        local layout = toastHolder:FindFirstChildOfClass("UIListLayout")
        if v == "บน" then
            toastHolder.AnchorPoint = Vector2.new(0.5, 0)
            toastHolder.Position = UDim2.new(0.5, 0, 0, 24)
            if layout then layout.VerticalAlignment = Enum.VerticalAlignment.Top end
        else
            toastHolder.AnchorPoint = Vector2.new(0.5, 1)
            toastHolder.Position = UDim2.new(0.5, 0, 1, -24)
            if layout then layout.VerticalAlignment = Enum.VerticalAlignment.Bottom end
        end
    end,
})
ui:AddInput({
    Text = "ชื่อในโปรไฟล์", Placeholder = "ชื่อที่ต้องการแสดง",
    Callback = function(v) pName.Text = (v ~= "" and v) or (LocalPlayer and LocalPlayer.DisplayName or "Player") end,
})
end

-- ส่วน "เมนู" (รีเซ็ตตำแหน่ง / ปิดสคริปต์ UI)
function Window:BuildMenuSection(ui)
ui:AddSection("เมนู")
ui:AddButton({
    Text = "รีเซ็ตตำแหน่ง UI", Description = "ดึงหน้าต่างและปุ่มลอยกลับตำแหน่งเดิม",
    Callback = function()
        window.Position = UDim2.fromScale(0.5, 0.5)
        toggleHolder.Position = UDim2.fromOffset(16, 120)
    end,
})
ui:AddButton({
    Text = "ปิดสคริปต์ UI", Description = "ลบ UI ทั้งหมดออก", Notify = false,
    Callback = function() if _G[UNLOAD_KEY] then _G[UNLOAD_KEY]() end end,
})
end

function Window:SetTheme(scheme, accent)
    local ok = applyTheme(scheme, accent)
    if ok and themeSeg then themeSeg:Set(themeState.scheme, true) end
    return ok
end

-- เรียกหลังผูก Handlers เสร็จ: โหลดค่าที่บันทึกอัตโนมัติครั้งล่าสุด
function Window:Ready()
    if config.AutoLoad ~= false then Window:LoadConfig("auto") end
end

-- ส่วนบันทึก/โหลดการตั้งค่า (โปรไฟล์)
function Window:BuildConfigSection(ui)
    ui:AddSection("การตั้งค่าที่บันทึก")
    if not canFS then
        ui:AddInfo("executor นี้ไม่รองรับการเขียนไฟล์ (writefile/readfile) จึงบันทึกการตั้งค่าไม่ได้")
        return
    end
    local nameInput = ui:AddInput({Text = "ชื่อโปรไฟล์", Placeholder = "ตั้งชื่อ"})
    local list = ui:AddDropdown({Text = "โปรไฟล์ที่มี", Options = Window:ListConfigs()})
    local function refresh(select)
        list:SetOptions(Window:ListConfigs())
        if select then list:Set(select, true) end
    end
    local function currentName()
        local n = cfgName(nameInput:Get())
        if n == "" then n = cfgName(list:Get()) end
        return n
    end
    ui:AddButton({Text = "บันทึก", Notify = false, Callback = function()
        local n = currentName()
        if n == "" then notify("ใส่ชื่อโปรไฟล์ก่อน") return end
        if Window:SaveConfig(n) then notify("บันทึก \"" .. n .. "\" แล้ว"); refresh(n) else notify("บันทึกไม่สำเร็จ") end
    end})
    ui:AddButton({Text = "โหลด", Notify = false, Callback = function()
        local n = currentName()
        if n ~= "" and Window:LoadConfig(n) then notify("โหลด \"" .. n .. "\" แล้ว") else notify("ไม่พบโปรไฟล์") end
    end})
    ui:AddButton({Text = "ลบ", Notify = false, Callback = function()
        local n = currentName()
        if n ~= "" and Window:DeleteConfig(n) then notify("ลบ \"" .. n .. "\" แล้ว"); refresh() else notify("ลบไม่สำเร็จ") end
    end})
    ui:AddToggle({
        Text = "บันทึกอัตโนมัติ", Description = "บันทึกค่าทุกครั้งที่เปลี่ยน และโหลดให้ตอนเปิดสคริปต์",
        Default = autoSave, Callback = function(v) autoSave = v end,
    })
end

return Window
end

return Library
