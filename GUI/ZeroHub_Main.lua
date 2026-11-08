-- Zero HUB — สคริปต์หลัก (โหลด UI ผ่านตัวโหลดที่มีแคชและอัปเดตอัตโนมัติ)
-- 1) อัปโหลด 3 ไฟล์นี้ไว้ที่เดียวกัน (GitHub / ที่ที่เปิดเป็น raw ได้):
--      ZeroHub_Loader.lua, ZeroHubUI_Lib.lua, version.json
-- 2) แก้ BASE ใน ZeroHub_Loader.lua และ LOADER_URL ด้านล่างให้เป็นลิงก์ของคุณ
-- 3) ทุกครั้งที่แก้ไลบรารี ให้เพิ่มเลข "version" ใน version.json เพื่อให้เครื่องอื่นอัปเดตตาม

local LOADER_URL = "https://raw.githubusercontent.com/Kaia-Zero/VOID/main/GUI/ZeroHub_Loader.lua"

local Lib, Loader = loadstring(game:HttpGet(LOADER_URL))()
-- ทดสอบจากไฟล์ในเครื่อง: local Lib, Loader = loadstring(readfile("ZeroHub_Loader.lua"))()

local UI = Lib.new({
    Name       = "ZeroHubUI",
    Title      = "Zero HUB",
    Subtitle   = "Violence District  •  Mobile Ready  •  v3.3.0",
    ToggleIcon = 101603563351741,            -- รูปปุ่มลอย (asset id)
    MenuKey    = Enum.KeyCode.RightShift,    -- ปุ่มลัดเปิด/ปิดเมนู
    TabIcons   = {},                         -- รูปไอคอนแท็บ เช่น ["ภาพ"] = 1234567890
})

-- ===================== แท็บและตัวเลือก =====================
local info   = UI:AddTab("ข้อมูล",        "📋", "ข้อมูลสคริปต์และผู้พัฒนา")
local visual = UI:AddTab("ภาพ",          "👀", "แสดงข้อมูลผู้เล่นและวัตถุในแมพ")
local combat = UI:AddTab("ต่อสู้",        "🥊", "ฟังก์ชันช่วยเหลือและการเคลื่อนที่")
local main   = UI:AddTab("หลัก",         "🎯", "เล็ง ปั่นไฟ และปัดป้อง")
local killer = UI:AddTab("ฆาตกร",        "💀", "ความสามารถสำหรับฝั่งฆาตกร")
local follow = UI:AddTab("ติดตามผู้เล่น",   "📍", "ติดตาม วาร์ป และระบบบิน")
local music  = UI:AddTab("เพลง",         "🎵", "เครื่องเล่นเพลง")
local ui     = UI:AddTab("ตั้งค่า UI",     "🔧", "ปรับแต่งหน้าตาและตัวเลือกของเมนู")

-- ---------- ข้อมูล ----------
info:AddSection("ข้อมูล")
info:AddInfo("เวอร์ชัน : 3.1.0\nสคริปต์ : Zero_HUB\nเกม : Violence District")
info:AddInfo("ฉันอยากให้คุณเข้าร่วมด้วยดิสคอร์ดกับเรา")
info:Btn("ดิสคอร์ด", "Discord")
info:AddSection("ผู้พัฒนา")
info:AddInfo("ความจากผู้พัฒนา ขอบคุณที่ใช้สคริปของเรา:>\nผู้พัฒนา : Niza\nรายละเอียด : เพิ่มระบบ ชื่อปลอม (แนะอย่าเปิดตอนเล่นเกม)")

-- ---------- หลัก (Main) ----------
main:AddSection("เล็งเงียบ (ชะตาพลิกผัน)")
main:Check("SilentAimEnabled", "เล็งเงียบ")
main:Drop("SilentAimTargetType", "เลือกเป้าหมาย", {"ฆาตกร", "ผู้รอดชีวิต", "ซอมบี้"})

main:AddSection("เล็งอัตโนมัติ")
main:Check("aimbotEnabled", "ล็อคเป้า")
main:Check("aimbotThroughWall", "เช็คกำแพง")
main:Check("aimbotPredict", "การทำนาย/เคลื่อนที่", true)
main:Drop("aimbotTargetMode", "เป้าหมายเล็งอัตโนมัติ", {"ฆาตกร", "ผู้รอดชีวิต", "SCP"})
main:Slider("aimbotFOV", "ระยะวงมุมมอง", 250, 50, 600, 0)
main:Slider("aimbotStrength", "ดูด ล็อค", 1, 0.1, 1, 2)

main:AddSection("ล็อกเป้าด้วยไฟฉาย")
main:Check("aimlockFlashlightEnabled", "ล็อกเป้าด้วยไฟฉาย")
main:Slider("aimlockFlashlightSmooth", "ความนุ่มนวล", 0.35, 0.1, 1, 2)

main:AddSection("เป้าเล็ง")
main:Check("crosshairEnabled", "เป้าเล็ง")
main:Color("crosshairColor", "สีเป้าเล็ง", Color3.fromRGB(255, 255, 255))
main:Drop("crosshairStyle", "รูปแบบเป้าเล็ง",
    {"จุด", "วงกลม", "วงกลม + จุด", "บวก", "กากบาท (X)", "รูปตัว T", "สี่เหลี่ยม"}, 4)
main:Slider("crosshairSize", "ขนาดเป้าเล็ง", 1, 1, 10, 0)
main:Slider("crosshairOpacity", "ความโปร่งใสเป้าเล็ง", 1, 0.1, 1, 2)

main:AddSection("ฟังก์ชันสำคัญ")
main:Check("AutoSkillcheck", "ปั่นไฟอัตโนมัติ", true)
main:Check("HideSkillUI", "ซ่อนหน้าต่างปั่นไฟ")
main:Check("BoostGenBypass", "ข้ามข้อจำกัดเครื่องปั่นไฟ (ซ่อมเร็ว)")
main:Drop("SkillcheckModeDropdown", "โหมดปั่นไฟ", {"ปกติ", "สมบูรณ์แบบ", "ทันที"})
main:Check("AutoParry", "ปัดป้องอัตโนมัติ")
main:Check("ShowParryCircle", "แสดงระยะปัดป้อง")
main:Drop("ParryModeDropdown", "โหมดปัดป้อง", {"ปกติ", "ดุดัน"})
main:Slider("ParryDistance", "ระยะปัดป้อง", 8, 4, 20, 0)


-- ---------- ต่อสู้ (Combat) ----------
combat:AddSection("ข้ามสิ่งกีดขวางเร็ว")
combat:Check("alwaysFastVault", "ข้ามหน้าต่างไว")
combat:Check("flowstateEnabled", "ข้ามหน้าต่างไว รุ่น 2")

combat:AddSection("ระบบสิทธิพิเศษปลอม")
combat:Check("fakePerksEnabled", "เปิดใช้งาน (สวิตช์หลัก)")
combat:Check("flowstateBoostEnabled", "บูทความเร็ว: ปีนข้าม เปิดคู่กับ ตกจากที่สูง")
combat:Check("quickRecoveryEnabled", "บูทความเร็ว: ถูกรักษาเสร็จ")
combat:Check("perfectLandingEnabled", "บูทความเร็ว: ตกจากที่สูง")
combat:Check("killerHitEnabled", "บูทความเร็ว: เมื่อดิ้นออกจากฆาตกร")
combat:Check("adrenalineRushEnabled", "อะดรีนาลีนพลุ่งพล่าน เพิ่มความเร็ว")

combat:AddSection("แสงและสภาพอากาศ")
combat:Drop("WeatherThemeDropdown", "ธีมอากาศและท้องฟ้า", {
    "ค่าเริ่มต้น", "คริสต์มาส (หิมะ)", "ฝนตกหนัก (พายุ)",
    "ซากุระ", "พระจันทร์สีเลือด (น่ากลัว)", "เที่ยงคืน (มืดสนิท)",
})
combat:Check("FullbrightToggle", "สว่างทั่วแมพ")
combat:Check("NoFogToggle", "ลบหมอก")
combat:Check("FPSBoosterToggle", "เพิ่ม FPS (โหมดลื่นขึ้น)")
combat:Check("ClayModeToggle", "โหมดภาพดินน้ำมัน")

combat:AddSection("ฮีลทันที")
combat:Check("InstantHealToggle", "ฮีลตัวเอง (ไม่เต็ม) (G)")

combat:AddSection("ฟังก์ชันช่วยเหลือ")
combat:Check("NoclipToggle", "เดินทะลุ")
combat:Check("godMode", "กันล้ม/น็อคดาวน์")
combat:Check("AntiFallDamageToggle", "ป้องกันความเสียหายจากการตก")
combat:Check("VaultSpeedToggle", "ข้ามสิ่งกีดขวางไว")
combat:Check("SpeedHackToggle", "วิ่งเร็ว")
combat:Slider("VaultSpeedSlider", "ความเร็วการปีนข้าม", 1.5, 1.0, 3.0, 1)
combat:Slider("SpeedValueSlider", "วิ่งเร็วระดับความเร็ว", 32, 16, 60, 0)

combat:AddSection("ระบบล่องหน")
combat:Check("InvisibleToggle", "ระบบล่องหน")

combat:AddSection("เดินถอยหลัง")
combat:Check("moonwalkEnabled", "เปิดใช้การเดินมูนวอล์ก")
combat:Drop("moonwalkMode", "โหมดการเดินมูนวอล์ก", {"คลาสสิก", "แกว่ง"})
combat:Slider("moonwalkSwayAmp", "ความกว้างการแกว่ง", 0.55, 0.1, 1.5, 2)
combat:Slider("moonwalkSwaySpeed", "ความเร็วการแกว่ง", 6, 1, 12, 1)

combat:AddSection("ย่อตัวอัตโนมัติ (Abyss)")
combat:Check("autoCrouchEnabled", "ย่อตัวอัตโนมัติ")
combat:Slider("autoCrouchRadius", "รัศมีการย่อตัว", 18, 5, 40, 0)

combat:AddSection("ล็อกมุมมอง")
combat:Check("lockFovEnabled", "ล็อกมุมมอง")
combat:Slider("customFovValue", "ค่ามุมมอง", 70, 40, 120, 0)


-- ---------- ฆาตกร (Killer) ----------
killer:AddSection("หอกเงียบ (Veil)")
killer:Check("spearEnabled", "หอกเงียบ")
killer:Check("spearFovCircleEnabled", "วงมุมมอง")
killer:Check("spearIndicatorEnabled", "ตัวชี้เป้าหมาย")
killer:Check("spearSnapLineEnabled", "เส้นชี้")
killer:Check("spearSnaplineShowText", "แสดงชื่อ/ระยะ", true)
killer:Slider("spearFovRadius", "รัศมีมุมมองของหอก", 150, 30, 500, 0)
killer:Slider("spearSnaplineMaxDistance", "ระยะเส้นชี้สูงสุด", 400, 100, 800, 0)
killer:Check("spearPrediction", "คาดการณ์เป้าหมายอัตโนมัติ", true)
killer:Check("spearDamping", "ป้องกันการหลบซ้ายขวา", true)

killer:AddSection("ควบคุมพลัง (หน้ากาก)")
killer:Btn("หน้ากากงู", "MaskCobra")
killer:Btn("หน้ากากหมีม่วง", "MaskBrandon")
killer:Btn("หน้ากากเป็ด", "MaskAlex")
killer:Btn("หน้ากากกระต่าย", "MaskRabbit")
killer:Btn("หน้ากากเสือ", "MaskTony")
killer:Btn("ปิดหน้ากาก (ปกติ)", "MaskOff")

killer:AddSection("Killer")
killer:Btn("พับไม้ทั้งหมดในแมพ", "DropPallets")
killer:Btn("บล็อกหน้าต่างทั้งหมด", "BlockWindows")
killer:Check("KILLER_AntiBlind", "ป้องกันตาพร่ามัว (ไฟสาย)")

killer:AddSection("ความสามารถฆาตกร")
killer:Check("ZeroAutoAttack", "โจมตีอัตโนมัติ")
killer:Slider("ZeroAttackRange", "ระยะโจมตี", 12, 5, 20, 0)
killer:Check("ZeroHitboxExpand", "ขยายขอบเขตการโจมตี")
killer:Slider("ZeroHitboxSize", "ขนาดขอบเขตการโจมตี", 15, 5, 40, 0)
killer:Check("ZeroBeatKiller", "ฆ้าผู้เล่นทั้งหมด")
killer:Check("ZeroInfAbyss", "สกิล Abyeeal ใช้ได้ไม่จำกัด (Abyee)")
killer:Check("ZeroInfHidden", "Skill ใช้ได้ไม่จำกัด (Hidden)")
killer:Check("ZeroInfVeil", "ข้ามคูลดาวน์ (เวล)")
killer:Check("ZeroInfPursuit", "การไล่ล่าใช้ได้ไม่จำกัด (Jason)")
killer:Check("ZeroInfGrab", "จับได้ไม่จำกัด (Myers)")


-- ---------- ภาพ (Visual) ----------
visual:AddSection("แสดงข้อมูลสิ่งมีชีวิต")
visual:Check("killerShowName", "ฆาตกร: แสดงชื่อ")
visual:Check("killerShowOutline", "ฆาตกร: แสดงเส้นขอบ", true)
visual:Color("killerColor", "สีฆาตกร", Color3.fromRGB(255, 60, 60))
visual:Check("survivorShowName", "ผู้รอดชีวิต: แสดงชื่อ")
visual:Check("survivorShowOutline", "ผู้รอดชีวิต: แสดงเส้นขอบ", true)
visual:Color("survivorColor", "สีผู้รอดชีวิต", Color3.fromRGB(60, 200, 255))
visual:Check("espScpEnabled", "ซอมบี้: เปิดการแสดงข้อมูล")
visual:Color("espScpColor", "สีซอมบี้", Color3.fromRGB(200, 60, 255))
visual:Check("espScpShowName", "ซอมบี้: แสดงชื่อ", true)
visual:Slider("killerMaxDistance", "ระยะสูงสุดของฆาตกร", 500, 100, 500, 0)
visual:Slider("survivorMaxDistance", "ระยะสูงสุดของผู้รอดชีวิต", 500, 100, 500, 0)
visual:Slider("espScpDistance", "ระยะสูงสุดของซอมบี้", 500, 100, 500, 0)

visual:AddSection("ตั้งค่าการแสดงข้อมูลผู้เล่น")
visual:Slider("fillTransparency", "ความโปร่งใสพื้น", 0.5, 0, 1, 2)

visual:AddSection("แสดงข้อมูลวัตถุ")
visual:Check("espGeneratorEnabled", "แสดงข้อมูลเครื่องปั่นไฟ")
visual:Color("espGeneratorColor", "สีเครื่องปั่นไฟ", Color3.fromRGB(200, 100, 0))
visual:Check("espGeneratorProgressGen", "ความคืบหน้าเครื่องปั่นไฟ")
visual:Check("espGenShowPK", "แสดงจำนวนผู้เล่น/ฆาตกร")
visual:Check("espWindowEnabled", "แสดงข้อมูลหน้าต่าง")
visual:Color("espWindowColor", "สีหน้าต่าง", Color3.fromRGB(255, 223, 0))
visual:Check("espPalletEnabled", "แสดงข้อมูลแผงไม้")
visual:Color("espPalletColor", "สีแผงไม้", Color3.fromRGB(53, 189, 166))
visual:Check("espHookEnabled", "แสดงข้อมูลตะขอ")
visual:Color("espHookColor", "สีตะขอ", Color3.fromRGB(252, 116, 116))
visual:Check("espGateEnabled", "แสดงข้อมูลประตูทางออก")
visual:Color("espGateColor", "สีประตู", Color3.fromRGB(255, 255, 255))


-- ---------- ติดตามผู้เล่น (Follow) ----------
follow:AddSection("ติดตาม / วาร์ป")
follow:Drop("FollowPlayerSelect", "เลือกผู้เล่น", {"ไม่มีผู้เล่นอื่น"})
follow:Btn("ติดตาม / หยุด", "FollowToggle")
follow:Btn("วาร์ปไปหาผู้เล่น", "Teleport")
follow:Btn("รีเฟรชรายชื่อผู้เล่น", "RefreshPlayers")
follow:AddInfo("ติดตาม = บินเข้าหาผู้เล่น + ทะลุสิ่งกีดขวาง")
follow:AddInfo("หยุด = หยุดบินและคืนค่าการชนเดิม")
-- อัปเดตรายชื่อผู้เล่นภายหลังด้วย: UI.Controls.FollowPlayerSelect:SetOptions({ ...ชื่อ... })

follow:AddSection("ระบบบิน")
follow:Check("ZeroFlyMenuToggle", "แสดงปุ่มบิน")
follow:Slider("ZeroFlySpeed", "ความเร็วบิน", 50, 10, 100, 0)
follow:AddInfo("เปิดเมนู = แสดงปุ่มบินเท่านั้น")
follow:AddInfo("บิน = เปิด/ปิดการบิน")
follow:AddInfo("ปุ่มขึ้น / ลง = ขึ้น / ลง 2 หน่วย")


-- ---------- เพลง (Music) ----------
music:AddSection("เครื่องเล่นเพลง")
music:Input("MusicAudioId", "รหัสเสียง Roblox", "ใส่รหัสเสียง")
music:Btn("เล่น", "MusicPlay")
music:Btn("หยุดชั่วคราว", "MusicPause")
music:Btn("หยุด", "MusicStop")
music:Check("MusicLoop", "วนซ้ำ")
music:Slider("MusicVolume", "ระดับเสียง", 0.5, 0, 1, 2)

-- ---------- ตั้งค่า UI ----------
UI:BuildSettings(ui)   -- แอนิเมชัน ปุ่มลอย พื้นหลัง สี ปุ่มลัด ฯลฯ (มาจากไลบรารี)
ui:AddSection("ชื่อปลอม (HUD)")
ui:Input("ZeroHubFakeNameInput", "ชื่อปลอม", "ใส่ชื่อที่ต้องการ")
ui:Btn("Apply ชื่อปลอม", "FakeNameApply")
ui:Btn("Reset ชื่อเดิม", "FakeNameReset")

ui:AddSection("ตกแต่ง")
ui:Check("JerkToolToggle", "ไอเทม ช.ว")
ui:Check("KorbloxLegToggle", "สกินขาหาย")
ui:Check("HeadlessToggle", "สกินไร้หัว")
UI:BuildConfigSection(ui)  -- บันทึก/โหลดโปรไฟล์การตั้งค่า (มาจากไลบรารี)
UI:BuildMenuSection(ui)

-- ===================== ผูกระบบเกม =====================
-- ใส่ฟังก์ชันตาม id ของตัวเลือก (ปุ่มใช้ id ขึ้นต้น btn_) เช่น
-- UI.Handlers.godMode = function(v) print("godMode", v) end
-- UI.Handlers.btn_DropPallets = function() end
-- UI.Controls.FollowPlayerSelect:SetOptions({"ชื่อ1", "ชื่อ2"})

-- โหลดค่าที่บันทึกอัตโนมัติครั้งล่าสุด (เรียกหลังผูก Handlers ทั้งหมดแล้ว)
UI:Ready()

return UI
