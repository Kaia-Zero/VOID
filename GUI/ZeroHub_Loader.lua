-- ZeroHub Loader — ตัวโหลดไลบรารี UI พร้อมแคชและอัปเดตอัตโนมัติ
--
-- ใช้ในสคริปต์หลัก:
--   local Lib, Loader = loadstring(game:HttpGet("https://raw.githubusercontent.com/YOUR_NAME/YOUR_REPO/main/ZeroHub_Loader.lua"))()
--
-- ทำอะไรบ้าง
--   1) ถามไฟล์ version.json (ไฟล์เล็ก ๆ) ว่ามีเวอร์ชันใหม่ไหม
--   2) ถ้ามีใหม่ (หรือยังไม่เคยโหลด) ดาวน์โหลดไลบรารี + ไฟล์เสริม เก็บไว้ในโฟลเดอร์ ZeroHub/cache/
--   3) ถ้าเวอร์ชันเดิม ใช้ไฟล์ที่เก็บไว้เลย (เร็ว ไม่ต้องโหลดไลบรารีใหม่)
--   4) ถ้าไม่มีเน็ต ใช้ไฟล์ที่เก็บไว้ล่าสุด
-- ไฟล์ที่โหลดมาจะถูกลองคอมไพล์ก่อนเขียนทับแคช ดังนั้นไฟล์เสียจะไม่ทำลายของเดิมที่ใช้ได้
--
-- บังคับอัปเดตทุกครั้ง: ใส่ getgenv().ZeroHubForceUpdate = true ก่อนรัน

local BASE     = "https://raw.githubusercontent.com/Kaia-Zero/VOID/refs/heads/main/"  -- <<< แก้ลิงก์ของคุณ (ต้องลงท้ายด้วย /)
local MANIFEST = "version.json"
local LIB_FILE = "ZeroHubUI_Lib.lua"        -- ชื่อไฟล์ไลบรารีเริ่มต้น (version.json เปลี่ยนได้ด้วย "lib")
local ROOT     = "ZeroHub"
local CACHE    = ROOT .. "/cache"

local Http = game:GetService("HttpService")
local genv = (type(getgenv) == "function" and getgenv()) or _G

local canStore = type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
    and type(makefolder) == "function" and type(isfolder) == "function"

local requester = (type(request) == "function" and request) or (type(http_request) == "function" and http_request)
    or (type(syn) == "table" and type(syn.request) == "function" and syn.request) or nil

-- ---------------------------------------------------------------- ดึงข้อมูล / ไฟล์
local function fetch(url)
    if requester then
        local ok, res = pcall(requester, {Url = url, Method = "GET"})
        if ok and type(res) == "table" then
            local status = tonumber(res.StatusCode) or 0
            if status >= 200 and status < 300 and type(res.Body) == "string" then return res.Body end
            if status >= 400 then return nil, "server answered " .. status end
        end
    end
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if ok and type(body) == "string" then return body end
    return nil, tostring(body)
end

local function has(path)
    if not canStore then return false end
    local ok, present = pcall(isfile, path)
    return ok and present == true
end

local function readFile(path)
    if not has(path) then return nil end
    local ok, data = pcall(readfile, path)
    return ok and type(data) == "string" and data or nil
end

local function writeFile(path, data)
    if not canStore then return false end
    local built = ""
    for part in string.gmatch(path, "([^/]+)/") do
        built = built == "" and part or (built .. "/" .. part)
        local ok, present = pcall(isfolder, built)
        if not (ok and present) then pcall(makefolder, built) end
    end
    return (pcall(writefile, path, data))
end

-- ชื่อไฟล์จาก version.json ต้องเป็นพาธธรรมดาเท่านั้น (กันชื่อแปลก ๆ เช่น ../)
local function plainName(name)
    return type(name) == "string" and string.match(name, "^[%w_%-%./]+$") ~= nil
        and not string.find(name, "..", 1, true) and not string.find(name, "//", 1, true)
        and string.sub(name, 1, 1) ~= "/" and string.sub(name, -1) ~= "/"
end

local function compiles(source, name)
    if type(source) ~= "string" or #source < 200 then return false end
    local chunk = loadstring(source, "=" .. name)
    return type(chunk) == "function"
end

local function decode(body)
    if not body then return nil end
    local ok, data = pcall(function() return Http:JSONDecode(body) end)
    return ok and type(data) == "table" and data or nil
end

-- ---------------------------------------------------------------- ขั้นตอนหลัก
local cachedManifest = decode(readFile(CACHE .. "/" .. MANIFEST))
local cachedLibName  = (cachedManifest and plainName(cachedManifest.lib) and cachedManifest.lib) or LIB_FILE
local cachedLib      = readFile(CACHE .. "/" .. cachedLibName)

local remoteBody = fetch(BASE .. MANIFEST .. "?t=" .. tostring(os.time()))   -- ?t= กันแคชของเซิร์ฟเวอร์
local remote = decode(remoteBody)
if remote and type(remote.version) ~= "string" then remote = nil end

local source, usedVersion, status

local needUpdate = remote ~= nil and (
    genv.ZeroHubForceUpdate == true
    or cachedManifest == nil
    or cachedLib == nil
    or cachedManifest.version ~= remote.version
)

if needUpdate then
    local libName = plainName(remote.lib) and remote.lib or LIB_FILE
    local body, why = fetch(BASE .. libName)
    if body and compiles(body, libName) then
        source, usedVersion, status = body, remote.version, "updated"
        writeFile(CACHE .. "/" .. libName, body)

        -- ไฟล์เสริม (เช่น รูป/ไอคอน) ไม่ใช่เรื่องสำคัญ: โหลดไม่ได้ก็ข้ามได้
        if type(remote.files) == "table" then
            for _, name in ipairs(remote.files) do
                if plainName(name) then
                    local data = fetch(BASE .. name)
                    if data and #data > 0 then writeFile(CACHE .. "/" .. name, data)
                    else warn("[ZeroHub] ดาวน์โหลดไฟล์เสริมไม่ได้: " .. tostring(name)) end
                end
            end
        end
        writeFile(CACHE .. "/" .. MANIFEST, Http:JSONEncode(remote))
    else
        warn("[ZeroHub] อัปเดตไม่สำเร็จ (" .. tostring(why or "ไฟล์ไม่ถูกต้อง") .. ") ใช้ไฟล์เดิมต่อ")
    end
end

if not source and cachedLib and compiles(cachedLib, cachedLibName) then
    source = cachedLib
    usedVersion = cachedManifest and cachedManifest.version or "?"
    status = remote and "cached" or "offline"
end

-- ไม่มีที่เก็บไฟล์ (executor ไม่รองรับ writefile): โหลดสดทุกครั้งโดยไม่เก็บแคช
if not source and not canStore then
    local body = fetch(BASE .. LIB_FILE)
    if body and compiles(body, LIB_FILE) then
        source, usedVersion, status = body, remote and remote.version or "?", "live"
    end
end

if not source then
    error("[ZeroHub] โหลดไลบรารี UI ไม่ได้ — ตรวจลิงก์ BASE ในตัวโหลด และการเชื่อมต่ออินเทอร์เน็ต", 0)
end

local chunk = loadstring(source, "=ZeroHubUI_Lib")
local Lib = chunk()

-- ข้อมูล/ตัวช่วยของตัวโหลด
local Loader = {
    Version = usedVersion,
    Status = status,          -- "updated" | "cached" | "offline" | "live"
    CacheDir = CACHE,
}

-- ขอรหัสรูปจากไฟล์เสริมที่โหลดไว้ เช่น Loader.Asset("icons/tabs.png") (ต้องมี getcustomasset)
function Loader.Asset(name)
    if not plainName(name) or type(getcustomasset) ~= "function" then return nil end
    local path = CACHE .. "/" .. name
    if not has(path) then return nil end
    local ok, id = pcall(getcustomasset, path)
    return ok and id or nil
end

return Lib, Loader
