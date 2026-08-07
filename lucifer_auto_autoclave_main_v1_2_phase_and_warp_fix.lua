--[[
=====================================================================
LUCIFER AUTO NANOFORGE MAIN V1.0
Target: Lucifer v2.85 / v2.86

WORLD:
- Work    : PALTELE|RAPOL2
- Storage : GIYUSEA|MOMOKS

LAYOUT:
- Nanoforge        : (41,50)
- Nanoforge stand  : (41,51)
- Buffer A         : (25,53) sampai (30,53)
- Buffer B         : (49,53) sampai (54,53)
- Safe storage     : (70,23) sampai (75,23)

FLOW:
1. Ambil seluruh processing tools dari active buffer.
2. Jika suatu tool >= 70, simpan 50 ke passive buffer.
3. Buat dynamic round-robin dari tool yang jumlahnya >= 20.
4. Dynamic round-robin diulang terus selama masih ada source >=20.
5. Setelah SEMUA processing tool di backpack sudah <20:
   - warp GIYUSEA|MOMOKS
   - drop Teleporter Charge dan Tactical Drone
   - kembali PALTELE|RAPOL2
6. Jika ada reserve 50 di passive buffer, ambil reserve tersebut.
7. Ulang round-robin sampai semua processing tool kembali <20.
8. Warp storage sekali lagi untuk menyimpan protected tools.
9. Drop sisa processing ke passive buffer.
10. Tukar active/passive buffer dan menunggu batch berikutnya.

STRICT WARP RECOVERY:
- Work door tile    : PALTELE (41,53)
- Storage door tile : GIYUSEA (70,23)
- Nama world saja tidak dianggap cukup.
- Jika reconnect membuat bot spawn di main door dan area kerja tidak dapat
  dijangkau, script keluar ke world lawan lalu warp ulang memakai door ID.

PROCESSING TOOLS:
- HyperShields
- AI Brain
- Galactibolt
- Space Meds
- Gigablaster
- Quadriscanner
- Stellar Documents
- Star Supplies
- Cyborg Diplomat
- Growton Torpedo

PROTECTED TOOLS:
- Teleporter Charge
- Tactical Drone

PENTING:
- Script memakai raw packet Nanoforge yang sudah terbukti pada mini-test.
- Auto Collect hanya hidup saat sweep buffer.
- Drop memakai batas lunak 3500 item per tile.
- Jika hasil Nanoforge tidak terverifikasi, script STOP dan tidak resend
  secara membabi buta.
- Uji pertama sebaiknya memakai jumlah kecil. Dunia memang suka menemukan
  bug tepat setelah seseorang berkata "harusnya langsung lancar".
=====================================================================
]]

---------------------------------------------------------------------
-- CONFIG
---------------------------------------------------------------------

local C = {
    WORK_WORLD = "PALTELE",
    WORK_DOOR = "RAPOL2",
    WORK_DOOR_TILE_X = 41,
    WORK_DOOR_TILE_Y = 53,
    WORK_ACCESS_X = 41,
    WORK_ACCESS_Y = 51,

    STORAGE_WORLD = "GIYUSEA",
    STORAGE_DOOR = "MOMOKS",
    STORAGE_DOOR_TILE_X = 70,
    STORAGE_DOOR_TILE_Y = 23,
    STORAGE_ACCESS_X = 70,
    STORAGE_ACCESS_Y = 23,

    DOOR_POSITION_TOLERANCE = 2,
    ACCESS_CHECK_TIMEOUT_MS = 8000,
    WRONG_SPAWN_BOUNCE_DELAY_MS = 1800,

    NANOFORGE_X = 41,
    NANOFORGE_Y = 50,
    NANOFORGE_STAND_X = 41,
    NANOFORGE_STAND_Y = 51,

    BUFFER_TILE_COUNT = 6,

    BUFFER_A_START_X = 25,
    BUFFER_A_Y = 53,

    BUFFER_B_START_X = 49,
    BUFFER_B_Y = 53,

    SAFE_START_X = 70,
    SAFE_Y = 23,

    INITIAL_ACTIVE_LANE = "A",

    RESERVE_PER_TOOL = 50,
    RESERVE_MIN_AMOUNT = 70,

    SOFT_TILE_LIMIT = 3500,

    COLLECT_RANGE = 4,
    COLLECT_SWEEP_RETRIES = 3,
    COLLECT_STEP_DELAY_MS = 170,
    COLLECT_SETTLE_MS = 700,

    PATH_TIMEOUT_MS = 12000,
    PATH_POLL_MS = 120,

    WORLD_TIMEOUT_MS = 18000,
    WORLD_POLL_MS = 250,
    WORLD_SETTLE_MS = 1200,
    WARP_RETRIES = 5,
    WARP_RETRY_DELAY_MS = 2500,

    DROP_TIMEOUT_MS = 7000,
    DROP_POLL_MS = 150,
    DROP_RETRIES = 3,
    DROP_SETTLE_MS = 450,

    NANOFORGE_OPEN_DELAY_MS = 1200,
    NANOFORGE_SELECT_DELAY_MS = 650,
    NANOFORGE_RESULT_TIMEOUT_MS = 12000,
    NANOFORGE_RESULT_POLL_MS = 150,
    NANOFORGE_BETWEEN_TOOLS_MS = 500,

    EMPTY_WAIT_MS = 30000,
    CONTINUOUS = true,

    MAX_ROUNDS_PER_BATCH = 200,
    MAX_BATCHES = 0, -- 0 = tanpa batas

    RESET_CHECKPOINT = false,
    CHECKPOINT_PREFIX = "auto_nanoforge_v1_0_",

    LOG_FILE = "AUTO_NANOFORGE_MAIN_V1_0_LOG.txt",
}

C.WORK_WORLD = string.upper(C.WORK_WORLD)
C.STORAGE_WORLD = string.upper(C.STORAGE_WORLD)

---------------------------------------------------------------------
-- ITEM TABLE
---------------------------------------------------------------------

local PROCESSING_TOOLS = {
    {id = 6518, name = "HyperShields"},
    {id = 6520, name = "AI Brain"},
    {id = 6522, name = "Galactibolt"},
    {id = 6524, name = "Space Meds"},
    {id = 6528, name = "Gigablaster"},
    {id = 6530, name = "Quadriscanner"},
    {id = 6534, name = "Stellar Documents"},
    {id = 6536, name = "Star Supplies"},
    {id = 6538, name = "Cyborg Diplomat"},
    {id = 6540, name = "Growton Torpedo"},
}

local PROTECTED_TOOLS = {
    {id = 6526, name = "Teleporter Charge"},
    {id = 6532, name = "Tactical Drone"},
}

local ALL_TOOLS = {
    {id = 6518, name = "HyperShields"},
    {id = 6520, name = "AI Brain"},
    {id = 6522, name = "Galactibolt"},
    {id = 6524, name = "Space Meds"},
    {id = 6526, name = "Teleporter Charge"},
    {id = 6528, name = "Gigablaster"},
    {id = 6530, name = "Quadriscanner"},
    {id = 6532, name = "Tactical Drone"},
    {id = 6534, name = "Stellar Documents"},
    {id = 6536, name = "Star Supplies"},
    {id = 6538, name = "Cyborg Diplomat"},
    {id = 6540, name = "Growton Torpedo"},
}

local PROCESSING_ID_SET = {}
for _, tool in ipairs(PROCESSING_TOOLS) do
    PROCESSING_ID_SET[tool.id] = true
end

local PROTECTED_ID_SET = {}
for _, tool in ipairs(PROTECTED_TOOLS) do
    PROTECTED_ID_SET[tool.id] = true
end

---------------------------------------------------------------------
-- BOT / RUN GUARD
---------------------------------------------------------------------

local bot = getBot()

if bot == nil then
    print("[NANOFORGE V1][FATAL] Bot tidak terdeteksi.")
    return
end

_G.__AUTO_NANOFORGE_MAIN_V1 =
    _G.__AUTO_NANOFORGE_MAIN_V1 or {}

local BOT_NAME = tostring(bot.name or "bot")
local SAFE_BOT_NAME =
    BOT_NAME:gsub("[^%w_%-]", "_")

if _G.__AUTO_NANOFORGE_MAIN_V1[BOT_NAME] == true then
    print(
        "[NANOFORGE V1][STOP] Script untuk bot ini sudah berjalan."
    )
    return
end

_G.__AUTO_NANOFORGE_MAIN_V1[BOT_NAME] = true

local CHECKPOINT =
    C.CHECKPOINT_PREFIX
    .. SAFE_BOT_NAME
    .. ".txt"

---------------------------------------------------------------------
-- LOG
---------------------------------------------------------------------

local function log(tag, ...)
    local parts = {
        "[NANOFORGE V1]",
        "[" .. tostring(tag) .. "]",
    }

    for i = 1, select("#", ...) do
        parts[#parts + 1] =
            tostring(select(i, ...))
    end

    local line = table.concat(parts, " ")
    print(line)

    pcall(function()
        append(C.LOG_FILE, line .. "\n")
    end)
end

local function releaseGuard()
    pcall(function()
        bot.auto_collect = false
        bot.collect_all = false
        bot.collect_range = 0
    end)

    _G.__AUTO_NANOFORGE_MAIN_V1[BOT_NAME] = nil
end

local function fatal(...)
    log("FATAL", ...)
    releaseGuard()
    return false
end

---------------------------------------------------------------------
-- CHECKPOINT
---------------------------------------------------------------------

local cp = {
    stage = "COLLECT_ACTIVE",
    active = C.INITIAL_ACTIVE_LANE,
    reserve_pending = 0,
    cycle = 0,
    round = 0,
    batch_round = 0,
}

local function saveCP()
    local lines = {
        "stage=" .. tostring(cp.stage),
        "active=" .. tostring(cp.active),
        "reserve_pending="
            .. tostring(cp.reserve_pending),
        "cycle=" .. tostring(cp.cycle),
        "round=" .. tostring(cp.round),
        "batch_round="
            .. tostring(cp.batch_round),
    }

    write(CHECKPOINT, table.concat(lines, "\n"))
end

local function loadCP()
    if C.RESET_CHECKPOINT then
        write(CHECKPOINT, "")
        return
    end

    local raw = read(CHECKPOINT)

    if raw == nil or raw == "" then
        return
    end

    for line in tostring(raw):gmatch("[^\r\n]+") do
        local key, value =
            line:match("^([^=]+)=(.*)$")

        if key == "stage" then
            cp.stage = value
        elseif key == "active" then
            cp.active = value
        elseif key == "reserve_pending" then
            cp.reserve_pending =
                tonumber(value) or 0
        elseif key == "cycle" then
            cp.cycle = tonumber(value) or 0
        elseif key == "round" then
            cp.round = tonumber(value) or 0
        elseif key == "batch_round" then
            cp.batch_round =
                tonumber(value) or 0
        end
    end
end

local function setStage(stage)
    cp.stage = stage
    saveCP()

    pcall(function()
        bot.custom_status =
            "NanoForge V1: "
            .. tostring(stage)
            .. " | Lane "
            .. tostring(cp.active)
    end)

    log(
        "STATE",
        stage,
        "| active",
        cp.active,
        "| reserve",
        cp.reserve_pending,
        "| cycle",
        cp.cycle,
        "| round",
        cp.round
    )
end

loadCP()

---------------------------------------------------------------------
-- GENERIC HELPERS
---------------------------------------------------------------------

local function waitUntil(fn, timeoutMs, intervalMs)
    local elapsed = 0

    while elapsed <= timeoutMs do
        local ok, result = pcall(fn)

        if ok and result == true then
            return true
        end

        sleep(intervalMs)
        elapsed = elapsed + intervalMs
    end

    return false
end

local function getWorld()
    local ok, world = pcall(function()
        return bot:getWorld()
    end)

    if ok then
        return world
    end

    return nil
end

local function worldName()
    local world = getWorld()

    if world == nil or world.name == nil then
        return ""
    end

    return string.upper(tostring(world.name))
end

local function getTile(x, y)
    local world = getWorld()

    if world == nil then
        return nil
    end

    local ok, tile = pcall(function()
        return world:getTile(x, y)
    end)

    if ok and tile ~= nil then
        return tile
    end

    local ok2, tile2 = pcall(function()
        return _G.getTile(x, y)
    end)

    if ok2 then
        return tile2
    end

    return nil
end

local function foreground(tile)
    if tile == nil then
        return -1
    end

    return tonumber(
        tile.fg
        or tile.foreground
        or 0
    ) or 0
end

local function botPos()
    local world = getWorld()

    if world == nil then
        return nil, nil
    end

    local ok, player = pcall(function()
        return world:getLocal()
    end)

    if not ok or player == nil then
        return nil, nil
    end

    return
        math.floor((player.posx or 0) / 32),
        math.floor((player.posy or 0) / 32)
end

local function playerPixelPos()
    local world = getWorld()

    if world == nil then
        return nil, nil
    end

    local ok, player = pcall(function()
        return world:getLocal()
    end)

    if not ok or player == nil then
        return nil, nil
    end

    return
        tonumber(player.posx),
        tonumber(player.posy)
end

local function distance(x1, y1, x2, y2)
    return
        math.abs(x1 - x2)
        + math.abs(y1 - y2)
end

local function standable(x, y)
    local tile = getTile(x, y)
    return tile ~= nil and foreground(tile) == 0
end

local function walkExact(x, y)
    local bx, by = botPos()

    if bx == x and by == y then
        return true
    end

    -- V1.1 FIX:
    -- Jangan menolak target berdasarkan tile foreground.
    -- Pada Lucifer v2.85, pembacaan Tile.fg/foreground bisa tidak cocok
    -- dengan koordinat pijakan pemain, sehingga tile yang sebenarnya bisa
    -- dicapai terbaca "tidak standable". Biarkan findPath yang menentukan.
    for attempt = 1, 4 do
        log(
            "MOVE",
            "findPath",
            x,
            y,
            "| attempt",
            attempt
        )

        local ok, err = pcall(function()
            bot:findPath(x, y)
        end)

        if not ok then
            log(
                "MOVE",
                "findPath error:",
                tostring(err)
            )
        else
            local reached = waitUntil(function()
                local cx, cy = botPos()
                return cx == x and cy == y
            end, C.PATH_TIMEOUT_MS, C.PATH_POLL_MS)

            if reached then
                log(
                    "MOVE",
                    "Reached",
                    x,
                    y
                )
                return true
            end
        end

        local cx, cy = botPos()

        log(
            "MOVE",
            "Retry",
            attempt,
            "| target",
            x,
            y,
            "| current",
            tostring(cx),
            tostring(cy)
        )

        sleep(500)
    end

    return false
end

local function connectIfNeeded()
    if BotStatus ~= nil
        and BotStatus.online ~= nil
        and bot.status == BotStatus.online
    then
        return true
    end

    pcall(function()
        bot:connect()
    end)

    sleep(7000)

    return true
end

local function nearPosition(x, y, targetX, targetY, tolerance)
    if x == nil or y == nil then
        return false
    end

    return
        math.abs(x - targetX) <= tolerance
        and math.abs(y - targetY) <= tolerance
end

local function worldRoute(expected)
    expected = string.upper(expected)

    if expected == C.WORK_WORLD then
        return {
            door = C.WORK_DOOR,
            doorX = C.WORK_DOOR_TILE_X,
            doorY = C.WORK_DOOR_TILE_Y,
            accessX = C.WORK_ACCESS_X,
            accessY = C.WORK_ACCESS_Y,
            bounceWorld = C.STORAGE_WORLD,
            bounceDoor = C.STORAGE_DOOR,
        }
    end

    return {
        door = C.STORAGE_DOOR,
        doorX = C.STORAGE_DOOR_TILE_X,
        doorY = C.STORAGE_DOOR_TILE_Y,
        accessX = C.STORAGE_ACCESS_X,
        accessY = C.STORAGE_ACCESS_Y,
        bounceWorld = C.WORK_WORLD,
        bounceDoor = C.WORK_DOOR,
    }
end

local function directWarp(name, door)
    local expected = string.upper(name)

    log(
        "WARP",
        expected,
        door or "",
        "| direct"
    )

    local ok, err = pcall(function()
        if door ~= nil and door ~= "" then
            bot:warp(expected, door)
        else
            bot:warp(expected)
        end
    end)

    if not ok then
        log(
            "WARP",
            "warp error:",
            tostring(err)
        )
        return false
    end

    return waitUntil(function()
        if worldName() ~= expected then
            return false
        end

        local x, y = botPos()
        return x ~= nil and y ~= nil
    end, C.WORLD_TIMEOUT_MS, C.WORLD_POLL_MS)
end

local function accessReachable(route)
    local currentX, currentY = botPos()

    if nearPosition(
        currentX,
        currentY,
        route.doorX,
        route.doorY,
        C.DOOR_POSITION_TOLERANCE
    ) then
        log(
            "WARP",
            "Door ID position verified:",
            currentX,
            currentY
        )
        return true
    end

    log(
        "WARP",
        "Posisi tidak dekat door ID. Tes akses ke",
        route.accessX,
        route.accessY,
        "| current",
        tostring(currentX),
        tostring(currentY)
    )

    local ok = pcall(function()
        bot:findPath(
            route.accessX,
            route.accessY
        )
    end)

    if not ok then
        return false
    end

    local reached = waitUntil(function()
        local x, y = botPos()

        return
            x == route.accessX
            and y == route.accessY
    end, C.ACCESS_CHECK_TIMEOUT_MS, C.PATH_POLL_MS)

    if reached then
        log(
            "WARP",
            "Area target dapat dijangkau."
        )
    end

    return reached
end

local function bounceWrongSpawn(route, expected)
    log(
        "WARP_RECOVERY",
        "Spawn salah/main door terdeteksi di",
        expected,
        ". Bounce ke",
        route.bounceWorld,
        route.bounceDoor
    )

    -- Tunggu sampai benar-benar keluar dari world target.
    -- Tidak langsung mengirim warp balik, karena saat koneksi lambat dua
    -- perintah warp beruntun bisa saling menimpa.
    local bounced = directWarp(
        route.bounceWorld,
        route.bounceDoor
    )

    if not bounced then
        log(
            "WARP_RECOVERY",
            "Bounce world gagal. Akan retry dari loop utama."
        )
        return false
    end

    sleep(C.WRONG_SPAWN_BOUNCE_DELAY_MS)
    return true
end

local function ensureWorld(name, door)
    local expected = string.upper(name)
    local route = worldRoute(expected)

    pcall(function()
        bot.auto_collect = false
        bot.collect_all = false
        bot.collect_range = 0
    end)

    -- Parameter door dipertahankan untuk kompatibilitas caller lama,
    -- tetapi route door yang sudah dikonfigurasi menjadi sumber utama.
    if door ~= nil and door ~= "" then
        route.door = door
    end

    for attempt = 1, C.WARP_RETRIES do
        connectIfNeeded()

        if worldName() == expected then
            if accessReachable(route) then
                return true
            end

            bounceWrongSpawn(route, expected)
        end

        log(
            "WARP",
            expected,
            route.door or "",
            "| strict attempt",
            attempt
        )

        if directWarp(expected, route.door) then
            sleep(C.WORLD_SETTLE_MS)

            if accessReachable(route) then
                return true
            end

            log(
                "WARP_RECOVERY",
                "Masuk world tetapi bukan melalui area door ID."
            )

            bounceWrongSpawn(route, expected)
        end

        sleep(C.WARP_RETRY_DELAY_MS)
    end

    return false
end

local function setCollect(enabled)
    pcall(function()
        bot.auto_collect = enabled
    end)

    pcall(function()
        bot.collect_all = enabled
    end)

    pcall(function()
        if enabled then
            bot.collect_range = C.COLLECT_RANGE
        else
            bot.collect_range = 0
        end
    end)
end

---------------------------------------------------------------------
-- INVENTORY HELPERS
---------------------------------------------------------------------

local function invCount(itemId)
    local inventory = bot:getInventory()

    if inventory == nil then
        return 0
    end

    local ok, amount = pcall(function()
        return inventory:getItemCount(itemId)
    end)

    if ok and amount ~= nil then
        return tonumber(amount) or 0
    end

    local ok2, item = pcall(function()
        return inventory:findItem(itemId)
    end)

    if ok2 and item ~= nil then
        if type(item) == "number" then
            return tonumber(item) or 0
        end

        return tonumber(
            item.amount
            or item.count
            or 0
        ) or 0
    end

    return 0
end

local function snapshotAllTools()
    local data = {}

    for _, tool in ipairs(ALL_TOOLS) do
        data[tool.id] = invCount(tool.id)
    end

    return data
end

local function processingTotal()
    local total = 0

    for _, tool in ipairs(PROCESSING_TOOLS) do
        total = total + invCount(tool.id)
    end

    return total
end

local function protectedTotal()
    local total = 0

    for _, tool in ipairs(PROTECTED_TOOLS) do
        total = total + invCount(tool.id)
    end

    return total
end

local function hasProcessableInventory()
    for _, tool in ipairs(PROCESSING_TOOLS) do
        if invCount(tool.id) >= 20 then
            return true
        end
    end

    return false
end

local function printInventory(label)
    log("INVENTORY", label)

    for _, tool in ipairs(ALL_TOOLS) do
        local amount = invCount(tool.id)

        if amount > 0 then
            log(
                "ITEM",
                tool.name,
                "|",
                tool.id,
                "|",
                amount
            )
        end
    end
end

---------------------------------------------------------------------
-- WORLD OBJECT HELPERS
---------------------------------------------------------------------

local function allObjects()
    local world = getWorld()

    if world == nil then
        return {}
    end

    local ok, objects = pcall(function()
        return world:getObjects()
    end)

    if ok and objects ~= nil then
        return objects
    end

    return {}
end

local function objectItemId(object)
    if object == nil then
        return 0
    end

    return tonumber(
        object.itemid
        or object.item_id
        or object.itemId
        or object.id
        or 0
    ) or 0
end

local function objectAmount(object)
    if object == nil then
        return 0
    end

    return tonumber(
        object.amount
        or object.count
        or object.qty
        or 1
    ) or 1
end

local function objectTile(object)
    if object == nil then
        return nil, nil
    end

    local x =
        object.x
        or object.posx

    local y =
        object.y
        or object.posy

    if object.pos ~= nil then
        x =
            object.pos.x
            or object.pos[1]
            or x

        y =
            object.pos.y
            or object.pos[2]
            or y
    end

    x = tonumber(x)
    y = tonumber(y)

    if x == nil or y == nil then
        return nil, nil
    end

    if x > 100 or y > 60 then
        return
            math.floor(x / 32),
            math.floor(y / 32)
    end

    return math.floor(x), math.floor(y)
end

local function tileFloatingLoad(x, y)
    local total = 0

    for _, object in pairs(allObjects()) do
        local ox, oy = objectTile(object)

        if ox == x and oy == y then
            total = total + objectAmount(object)
        end
    end

    return total
end

---------------------------------------------------------------------
-- LANE HELPERS
---------------------------------------------------------------------

local function buildLane(name)
    local startX
    local y

    if name == "A" then
        startX = C.BUFFER_A_START_X
        y = C.BUFFER_A_Y
    else
        startX = C.BUFFER_B_START_X
        y = C.BUFFER_B_Y
    end

    local tiles = {}

    for index = 0, C.BUFFER_TILE_COUNT - 1 do
        tiles[#tiles + 1] = {
            x = startX + index,
            y = y,
        }
    end

    return {
        name = name,
        tiles = tiles,
        startX = startX,
        endX =
            startX
            + C.BUFFER_TILE_COUNT
            - 1,
        y = y,
    }
end

local function buildSafeLane()
    local tiles = {}

    for index = 0, C.BUFFER_TILE_COUNT - 1 do
        tiles[#tiles + 1] = {
            x = C.SAFE_START_X + index,
            y = C.SAFE_Y,
        }
    end

    return {
        name = "SAFE",
        tiles = tiles,
        startX = C.SAFE_START_X,
        endX =
            C.SAFE_START_X
            + C.BUFFER_TILE_COUNT
            - 1,
        y = C.SAFE_Y,
    }
end

local function activeLane()
    return buildLane(cp.active)
end

local function otherLaneName(name)
    if name == "A" then
        return "B"
    end

    return "A"
end

local function passiveLane()
    return buildLane(
        otherLaneName(cp.active)
    )
end

local SAFE_LANE = buildSafeLane()

local function laneProcessingCounts(lane)
    local counts = {}

    for _, tool in ipairs(PROCESSING_TOOLS) do
        counts[tool.id] = 0
    end

    local tileSet = {}

    for _, position in ipairs(lane.tiles) do
        tileSet[
            tostring(position.x)
            .. ":"
            .. tostring(position.y)
        ] = true
    end

    for _, object in pairs(allObjects()) do
        local id = objectItemId(object)

        if PROCESSING_ID_SET[id] then
            local x, y = objectTile(object)

            if x ~= nil and y ~= nil then
                local key =
                    tostring(x)
                    .. ":"
                    .. tostring(y)

                if tileSet[key] then
                    counts[id] =
                        (counts[id] or 0)
                        + objectAmount(object)
                end
            end
        end
    end

    return counts
end

local function laneHasProcessable(lane)
    local counts = laneProcessingCounts(lane)

    for _, tool in ipairs(PROCESSING_TOOLS) do
        if (counts[tool.id] or 0) >= 20 then
            return true
        end
    end

    return false
end

---------------------------------------------------------------------
-- COLLECT
---------------------------------------------------------------------

local function sweepLane(lane)
    if not ensureWorld(
        C.WORK_WORLD,
        C.WORK_DOOR
    ) then
        return false
    end

    log(
        "COLLECT",
        "Sweep lane",
        lane.name,
        "|",
        lane.startX,
        lane.y,
        "->",
        lane.endX,
        lane.y
    )

    setCollect(false)

    if not walkExact(lane.startX, lane.y) then
        return false
    end

    local previousTotal = processingTotal()

    for sweep = 1, C.COLLECT_SWEEP_RETRIES do
        setCollect(true)

        local leftToRight =
            sweep % 2 == 1

        local startX =
            leftToRight
            and lane.startX
            or lane.endX

        local endX =
            leftToRight
            and lane.endX
            or lane.startX

        local step =
            leftToRight
            and 1
            or -1

        if not walkExact(startX, lane.y) then
            setCollect(false)
            return false
        end

        local x = startX

        while true do
            pcall(function()
                bot:collect(
                    C.COLLECT_RANGE,
                    100
                )
            end)

            if not walkExact(x, lane.y) then
                setCollect(false)
                return false
            end

            sleep(C.COLLECT_STEP_DELAY_MS)

            if x == endX then
                break
            end

            x = x + step
        end

        sleep(C.COLLECT_SETTLE_MS)
        setCollect(false)

        local currentTotal = processingTotal()

        log(
            "COLLECT",
            "Sweep",
            sweep,
            "| before",
            previousTotal,
            "| after",
            currentTotal
        )

        if currentTotal == previousTotal then
            break
        end

        previousTotal = currentTotal
    end

    setCollect(false)
    printInventory(
        "SETELAH COLLECT LANE "
        .. lane.name
    )

    return true
end

---------------------------------------------------------------------
-- DROP
---------------------------------------------------------------------

local function dropVerified(itemId, amount)
    amount = math.min(
        tonumber(amount) or 0,
        invCount(itemId)
    )

    if amount <= 0 then
        return true
    end

    setCollect(false)

    for attempt = 1, C.DROP_RETRIES do
        local before = invCount(itemId)

        if before < amount then
            amount = before
        end

        if amount <= 0 then
            return true
        end

        log(
            "DROP",
            "Item",
            itemId,
            "| amount",
            amount,
            "| attempt",
            attempt
        )

        local ok = pcall(function()
            bot:drop(itemId, amount)
        end)

        if ok then
            local changed = waitUntil(function()
                return
                    invCount(itemId)
                    <= before - amount
            end, C.DROP_TIMEOUT_MS, C.DROP_POLL_MS)

            if changed then
                sleep(C.DROP_SETTLE_MS)
                return true
            end
        end

        sleep(600)
    end

    return false
end

local function chooseDropTile(
    lane,
    amount,
    preferredIndex
)
    local count = #lane.tiles

    if count == 0 then
        return nil, nil
    end

    preferredIndex =
        tonumber(preferredIndex) or 1

    for offset = 0, count - 1 do
        local index =
            ((preferredIndex - 1 + offset)
            % count)
            + 1

        local position = lane.tiles[index]
        local load =
            tileFloatingLoad(
                position.x,
                position.y
            )

        if load + amount
            <= C.SOFT_TILE_LIMIT
        then
            return position, index
        end
    end

    return nil, nil
end

local function dropGroupToLane(
    tools,
    lane,
    amountResolver
)
    local cursor = 1

    for _, tool in ipairs(tools) do
        local amount =
            tonumber(
                amountResolver(tool)
            ) or 0

        amount = math.min(
            amount,
            invCount(tool.id)
        )

        while amount > 0 do
            local chunk =
                math.min(amount, 200)

            local position, index =
                chooseDropTile(
                    lane,
                    chunk,
                    cursor
                )

            if position == nil then
                log(
                    "DROP",
                    "Semua tile lane",
                    lane.name,
                    "mencapai soft limit."
                )
                return false
            end

            if not walkExact(
                position.x,
                position.y
            ) then
                log(
                    "DROP",
                    "Gagal ke tile",
                    position.x,
                    position.y
                )
                return false
            end

            log(
                "DROP",
                tool.name,
                chunk,
                "->",
                lane.name,
                position.x,
                position.y
            )

            if not dropVerified(
                tool.id,
                chunk
            ) then
                log(
                    "DROP",
                    "Gagal drop",
                    tool.name
                )
                return false
            end

            amount = amount - chunk
            cursor = (index % #lane.tiles) + 1
        end
    end

    return true
end

local function dropAllProcessing(lane)
    return dropGroupToLane(
        PROCESSING_TOOLS,
        lane,
        function(tool)
            return invCount(tool.id)
        end
    )
end

local function dropReserve(lane)
    local reservePlan = {}
    local droppedAny = false

    for _, tool in ipairs(PROCESSING_TOOLS) do
        local amount = invCount(tool.id)

        if amount >= C.RESERVE_MIN_AMOUNT then
            reservePlan[tool.id] =
                math.min(
                    C.RESERVE_PER_TOOL,
                    amount - 20
                )

            if reservePlan[tool.id] > 0 then
                droppedAny = true
            end
        else
            reservePlan[tool.id] = 0
        end
    end

    if not droppedAny then
        log(
            "RESERVE",
            "Tidak ada tool yang memenuhi reserve."
        )
        return true, false
    end

    local ok = dropGroupToLane(
        PROCESSING_TOOLS,
        lane,
        function(tool)
            return reservePlan[tool.id] or 0
        end
    )

    return ok, ok and droppedAny
end

---------------------------------------------------------------------
-- NANOFORGE ENGINE
---------------------------------------------------------------------

local function buildRoundQueue()
    local queue = {}

    for _, tool in ipairs(PROCESSING_TOOLS) do
        local amount = invCount(tool.id)

        if amount >= 20 then
            queue[#queue + 1] = {
                id = tool.id,
                name = tool.name,
                amount = amount,
            }
        end
    end

    table.sort(queue, function(a, b)
        if a.amount == b.amount then
            return a.id < b.id
        end

        return a.amount > b.amount
    end)

    return queue
end

local function canNanoforgeSource(sourceId)
    if invCount(sourceId) < 20 then
        return false,
            "source kurang dari 20"
    end

    for _, tool in ipairs(ALL_TOOLS) do
        if tool.id ~= sourceId
            and invCount(tool.id) >= 200
        then
            return false,
                tool.name
                .. " sudah 200"
        end
    end

    return true
end

local function sendRawNanoforgeOpen()
    local posX, posY = playerPixelPos()

    if posX == nil or posY == nil then
        return false
    end

    local packet = GameUpdatePacket.new()

    packet.type = 3
    packet.int_data = 32
    packet.pos_x = posX
    packet.pos_y = posY
    packet.int_x = C.NANOFORGE_X
    packet.int_y = C.NANOFORGE_Y

    log(
        "NANOFORGE",
        "OPEN raw",
        "| pos",
        posX,
        posY,
        "| tile",
        C.NANOFORGE_X,
        C.NANOFORGE_Y
    )

    local ok = pcall(function()
        bot:sendRaw(packet)
    end)

    return ok
end

local function sendNanoforgeSelect(itemId)
    local payload =
        "action|dialog_return\n"
        .. "dialog_name|star tool nanoforge\n"
        .. "tilex|"
        .. tostring(C.NANOFORGE_X)
        .. "|\n"
        .. "tiley|"
        .. tostring(C.NANOFORGE_Y)
        .. "|\n"
        .. "buttonClicked|tool"
        .. tostring(itemId)
        .. "\n"

    bot:sendPacket(2, payload)
end

local function sendNanoforgeVerify(itemId)
    local payload =
        "action|dialog_return\n"
        .. "dialog_name|star tool nanoforge\n"
        .. "tilex|"
        .. tostring(C.NANOFORGE_X)
        .. "|\n"
        .. "tiley|"
        .. tostring(C.NANOFORGE_Y)
        .. "|\n"
        .. "itemID|"
        .. tostring(itemId)
        .. "|\n"
        .. "buttonClicked|verify\n"

    bot:sendPacket(2, payload)
end

local function nanoforgeResultMatches(
    before,
    sourceId
)
    local expectedSource =
        (before[sourceId] or 0) - 20

    if invCount(sourceId)
        ~= expectedSource
    then
        return false
    end

    for _, tool in ipairs(ALL_TOOLS) do
        if tool.id ~= sourceId then
            local expected =
                (before[tool.id] or 0) + 1

            if invCount(tool.id)
                ~= expected
            then
                return false
            end
        end
    end

    return true
end

local function nanoforgeOnce(tool)
    local safe, reason =
        canNanoforgeSource(tool.id)

    if not safe then
        log(
            "NANOFORGE",
            "Tidak aman:",
            tool.name,
            "|",
            reason
        )
        return false
    end

    local before = snapshotAllTools()

    log(
        "NANOFORGE",
        "SELECT",
        tool.name,
        "| before",
        before[tool.id]
    )

    local selectOK = pcall(function()
        sendNanoforgeSelect(tool.id)
    end)

    if not selectOK then
        return false
    end

    sleep(C.NANOFORGE_SELECT_DELAY_MS)

    local verifyOK = pcall(function()
        sendNanoforgeVerify(tool.id)
    end)

    if not verifyOK then
        return false
    end

    local completed = waitUntil(function()
        return nanoforgeResultMatches(
            before,
            tool.id
        )
    end,
    C.NANOFORGE_RESULT_TIMEOUT_MS,
    C.NANOFORGE_RESULT_POLL_MS)

    if not completed then
        local sourceBefore =
            before[tool.id] or 0

        local sourceAfter =
            invCount(tool.id)

        log(
            "NANOFORGE",
            "VERIFICATION FAIL",
            tool.name,
            "| source",
            sourceBefore,
            "->",
            sourceAfter
        )

        log(
            "NANOFORGE",
            "Tidak melakukan resend otomatis."
        )

        return false
    end

    log(
        "NANOFORGE",
        "SUCCESS",
        tool.name,
        "|",
        before[tool.id],
        "->",
        invCount(tool.id)
    )

    sleep(C.NANOFORGE_BETWEEN_TOOLS_MS)
    return true
end

local function goToNanoforge()
    if not ensureWorld(
        C.WORK_WORLD,
        C.WORK_DOOR
    ) then
        return false
    end

    setCollect(false)

    if not walkExact(
        C.NANOFORGE_STAND_X,
        C.NANOFORGE_STAND_Y
    ) then
        return false
    end

    local bx, by = botPos()

    if bx ~= C.NANOFORGE_STAND_X
        or by ~= C.NANOFORGE_STAND_Y
    then
        return false
    end

    return true
end

local function processOneRound(queue)
    if #queue == 0 then
        return true, 0
    end

    if not goToNanoforge() then
        return false, 0
    end

    if not sendRawNanoforgeOpen() then
        return false, 0
    end

    sleep(C.NANOFORGE_OPEN_DELAY_MS)

    local processed = 0

    for _, tool in ipairs(queue) do
        if invCount(tool.id) >= 20 then
            if not nanoforgeOnce(tool) then
                return false, processed
            end

            processed = processed + 1
        end
    end

    return true, processed
end

---------------------------------------------------------------------
-- STORAGE
---------------------------------------------------------------------

local function storeProtected()
    local total = protectedTotal()

    if total <= 0 then
        log(
            "STORAGE",
            "Protected inventory kosong."
        )
        return true
    end

    setCollect(false)

    if not ensureWorld(
        C.STORAGE_WORLD,
        C.STORAGE_DOOR
    ) then
        return false
    end

    log(
        "STORAGE",
        "Drop protected total",
        total
    )

    local ok = dropGroupToLane(
        PROTECTED_TOOLS,
        SAFE_LANE,
        function(tool)
            return invCount(tool.id)
        end
    )

    if not ok then
        return false
    end

    for _, tool in ipairs(PROTECTED_TOOLS) do
        if invCount(tool.id) > 0 then
            log(
                "STORAGE",
                "Masih tersisa:",
                tool.name,
                invCount(tool.id)
            )
            return false
        end
    end

    return ensureWorld(
        C.WORK_WORLD,
        C.WORK_DOOR
    )
end

---------------------------------------------------------------------
-- RESUME SAFETY
---------------------------------------------------------------------

local function recoverInventoryState()
    if protectedTotal() > 0 then
        log(
            "RESUME",
            "Protected ditemukan di inventory. "
            .. "Amankan dulu."
        )

        if not storeProtected() then
            return false
        end
    end

    if processingTotal() > 0 then
        if cp.stage == "COLLECT_ACTIVE" then
            log(
                "RESUME",
                "Processing inventory tidak kosong. "
                .. "Lanjut PROCESS."
            )

            cp.stage = "PROCESS"
            saveCP()
        end
    end

    return true
end

---------------------------------------------------------------------
-- IDLE / LANE CHOICE
---------------------------------------------------------------------

local function maybeSwitchToOtherLane()
    if not ensureWorld(
        C.WORK_WORLD,
        C.WORK_DOOR
    ) then
        return false
    end

    local other = passiveLane()

    if laneHasProcessable(other) then
        cp.active = other.name
        cp.stage = "COLLECT_ACTIVE"
        cp.reserve_pending = 0
        cp.batch_round = 0
        saveCP()

        log(
            "LANE",
            "Switch ke",
            cp.active,
            "karena ada item processable."
        )

        return true
    end

    return false
end

---------------------------------------------------------------------
-- MAIN STATE MACHINE
---------------------------------------------------------------------

local function main()
    log("SYSTEM", "==========================================")
    log("SYSTEM", "AUTO NANOFORGE MAIN V1.0")
    log("SYSTEM", "Bot:", BOT_NAME)
    log(
        "SYSTEM",
        "Work:",
        C.WORK_WORLD .. "|" .. C.WORK_DOOR
    )
    log(
        "SYSTEM",
        "Storage:",
        C.STORAGE_WORLD .. "|" .. C.STORAGE_DOOR
    )
    log(
        "SYSTEM",
        "Checkpoint:",
        CHECKPOINT
    )
    log("SYSTEM", "==========================================")

    if not recoverInventoryState() then
        return fatal(
            "Recovery inventory gagal."
        )
    end

    local batchesCompleted = 0

    while true do
        if C.MAX_BATCHES > 0
            and batchesCompleted >= C.MAX_BATCHES
        then
            log(
                "DONE",
                "Mencapai MAX_BATCHES:",
                C.MAX_BATCHES
            )
            releaseGuard()
            return true
        end

        -------------------------------------------------------------
        -- COLLECT ACTIVE
        -------------------------------------------------------------

        if cp.stage == "COLLECT_ACTIVE" then
            local lane = activeLane()

            if not sweepLane(lane) then
                return fatal(
                    "Gagal collect lane ",
                    lane.name
                )
            end

            if processingTotal() <= 0 then
                log(
                    "EMPTY",
                    "Tidak ada processing tools di lane",
                    lane.name
                )

                if maybeSwitchToOtherLane() then
                    -- langsung loop
                elseif C.CONTINUOUS then
                    log(
                        "WAIT",
                        "Menunggu tools baru selama",
                        C.EMPTY_WAIT_MS,
                        "ms."
                    )
                    sleep(C.EMPTY_WAIT_MS)
                else
                    releaseGuard()
                    return true
                end

            elseif not hasProcessableInventory() then
                log(
                    "IDLE",
                    "Ada tools, tetapi semuanya < 20."
                )

                if not dropAllProcessing(lane) then
                    return fatal(
                        "Gagal mengembalikan residual ke lane ",
                        lane.name
                    )
                end

                if maybeSwitchToOtherLane() then
                    -- langsung loop
                elseif C.CONTINUOUS then
                    sleep(C.EMPTY_WAIT_MS)
                else
                    releaseGuard()
                    return true
                end

            else
                cp.batch_round = 0
                setStage("RESERVE")
            end
        end

        -------------------------------------------------------------
        -- RESERVE
        -------------------------------------------------------------

        if cp.stage == "RESERVE" then
            local lane = passiveLane()

            if not ensureWorld(
                C.WORK_WORLD,
                C.WORK_DOOR
            ) then
                return fatal(
                    "Gagal masuk work world untuk reserve."
                )
            end

            local ok, reserved =
                dropReserve(lane)

            if not ok then
                return fatal(
                    "Gagal drop reserve ke lane ",
                    lane.name
                )
            end

            cp.reserve_pending =
                reserved and 1 or 0

            setStage("PROCESS")
        end

        -------------------------------------------------------------
        -- PROCESS
        -------------------------------------------------------------

        if cp.stage == "PROCESS" then
            local queue = buildRoundQueue()

            if #queue == 0 then
                -- Semua processing tool yang sedang dibawa sudah <20.
                -- Baru sekarang protected tools dikirim ke storage.
                setStage("STORE_PHASE")
            else
                if cp.batch_round
                    >= C.MAX_ROUNDS_PER_BATCH
                then
                    return fatal(
                        "MAX_ROUNDS_PER_BATCH tercapai."
                    )
                end

                log(
                    "ROUND",
                    "Queue size",
                    #queue,
                    "| batch round",
                    cp.batch_round + 1
                )

                for index, tool in ipairs(queue) do
                    log(
                        "ROUND_QUEUE",
                        index,
                        tool.name,
                        tool.amount
                    )
                end

                local ok, processed =
                    processOneRound(queue)

                if not ok then
                    saveCP()

                    return fatal(
                        "Round gagal setelah ",
                        processed,
                        " tool."
                    )
                end

                if processed <= 0 then
                    return fatal(
                        "Round queue ada tetapi tidak ada yang diproses."
                    )
                end

                cp.round = cp.round + 1
                cp.batch_round =
                    cp.batch_round + 1
                saveCP()

                -- Jangan warp storage setelah satu round.
                -- Rebuild queue dan terus forge sampai semua source <20.
                setStage("PROCESS")
            end
        end

        -------------------------------------------------------------
        -- STORE PHASE
        -------------------------------------------------------------

        if cp.stage == "STORE_PHASE" then
            log(
                "STORAGE",
                "Semua processing tool di backpack sudah <20."
            )

            if protectedTotal() > 0 then
                if not storeProtected() then
                    return fatal(
                        "Gagal menyimpan protected setelah phase selesai."
                    )
                end
            else
                -- Meski protected kosong, pastikan kita kembali/berada
                -- di work world melalui akses yang benar sebelum lanjut.
                if not ensureWorld(
                    C.WORK_WORLD,
                    C.WORK_DOOR
                ) then
                    return fatal(
                        "Gagal memastikan akses work world setelah phase."
                    )
                end
            end

            if cp.reserve_pending == 1 then
                setStage("TAKE_RESERVE")
            else
                setStage("FINAL_DROP")
            end
        end

        -------------------------------------------------------------
        -- TAKE RESERVE
        -------------------------------------------------------------

        if cp.stage == "TAKE_RESERVE" then
            local lane = passiveLane()

            log(
                "RESERVE",
                "Ambil reserve dari lane",
                lane.name
            )

            if not sweepLane(lane) then
                return fatal(
                    "Gagal ambil reserve lane ",
                    lane.name
                )
            end

            cp.reserve_pending = 0
            saveCP()

            setStage("PROCESS")
        end

        -------------------------------------------------------------
        -- FINAL DROP
        -------------------------------------------------------------

        if cp.stage == "FINAL_DROP" then
            -- Safety fallback. Normalnya protected sudah kosong karena
            -- FINAL_DROP hanya dicapai setelah STORE_PHASE.
            if protectedTotal() > 0 then
                if not storeProtected() then
                    return fatal(
                        "Gagal menyimpan protected saat final fallback."
                    )
                end
            end

            if not ensureWorld(
                C.WORK_WORLD,
                C.WORK_DOOR
            ) then
                return fatal(
                    "Gagal kembali ke work world saat final."
                )
            end

            local destination = passiveLane()

            log(
                "FINAL",
                "Drop residual processing ke lane",
                destination.name
            )

            if not dropAllProcessing(
                destination
            ) then
                return fatal(
                    "Gagal drop residual ke lane ",
                    destination.name
                )
            end

            if processingTotal() > 0 then
                return fatal(
                    "Processing inventory belum kosong setelah final drop."
                )
            end

            cp.active = destination.name
            cp.reserve_pending = 0
            cp.cycle = cp.cycle + 1
            cp.batch_round = 0
            cp.stage = "COLLECT_ACTIVE"
            saveCP()

            batchesCompleted =
                batchesCompleted + 1

            log(
                "CYCLE",
                "Selesai cycle",
                cp.cycle,
                "| active berikutnya",
                cp.active
            )

            sleep(1200)
        end
    end
end

---------------------------------------------------------------------
-- EXECUTE WITH ERROR GUARD
---------------------------------------------------------------------

local ok, err = xpcall(
    main,
    function(message)
        if debug ~= nil
            and debug.traceback ~= nil
        then
            return debug.traceback(
                tostring(message),
                2
            )
        end

        return tostring(message)
    end
)

if not ok then
    log("CRASH", err)
    releaseGuard()
end
