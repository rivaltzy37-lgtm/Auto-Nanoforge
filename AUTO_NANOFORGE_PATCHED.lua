--[[
LUCIFER AUTO NANOFORGE PATCHED LAUNCHER

Launcher ini membaca main Nanoforge yang sudah ada, memperbaiki state
Buffer B -> Buffer A di memory, lalu menjalankan source yang sudah dipatch.
Tidak mengubah file main asli.
]]

local MAIN_FILE = "lucifer_auto_autoclave_main_v1_2_phase_and_warp_fix.lua"

-- Bersihkan stale guard sebelum source utama dimuat.
_G.__AUTO_NANOFORGE_MAIN_V1 = {}
_G.__AUTO_NANOFORGE_MAIN_V1_2 = {}

local source = read(MAIN_FILE)

if source == nil or source == "" then
    print("[NANOFORGE PATCH][FATAL] Tidak bisa membaca " .. MAIN_FILE)
    return
end

local patched = source

local old_take = [[        if cp.stage == "TAKE_RESERVE" then
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
        end]]

local new_take = [[        if cp.stage == "TAKE_RESERVE" then
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

            -- BUFFER B DIRECT-A FIX:
            -- Setelah reserve diambil, cek queue langsung.
            -- Kalau semua reserve <20, residual dikembalikan ke Buffer B
            -- dan bot langsung mengambil batch berikutnya dari Buffer A.
            if #buildRoundQueue() == 0 then
                log(
                    "RESERVE",
                    "Semua reserve <20. Langsung lanjut ke buffer berikutnya."
                )

                if processingTotal() > 0 then
                    if not dropAllProcessing(lane) then
                        return fatal(
                            "Gagal mengembalikan residual reserve ke lane ",
                            lane.name
                        )
                    end
                end

                cp.active = otherLaneName(lane.name)
                cp.batch_round = 0
                cp.stage = "COLLECT_ACTIVE"
                saveCP()
            else
                setStage("PROCESS")
            end
        end]]

if not patched:find(old_take, 1, true) then
    print("[NANOFORGE PATCH][FATAL] TAKE_RESERVE block tidak ditemukan.")
    return
end

patched = patched:gsub(
    old_take:gsub("([%%%^%$%(%)%.%[%]%*%+%-%?])", "%%%1"),
    function() return new_take end,
    1
)

local old_process = [[            if #queue == 0 then
                -- Semua processing tool yang sedang dibawa sudah <20.
                -- Baru sekarang protected tools dikirim ke storage.
                setStage("STORE_PHASE")
            else]]

local new_process = [[            if #queue == 0 then
                -- Defense-in-depth: jika reserve sudah selesai dan queue kosong,
                -- jangan masuk storage/nanoforge lagi. Langsung batch berikutnya.
                if cp.reserve_pending == 0 then
                    local lane = passiveLane()

                    log(
                        "RESERVE",
                        "Queue kosong setelah reserve. Skip Nanoforge dan lanjut batch berikutnya."
                    )

                    if processingTotal() > 0 then
                        if not dropAllProcessing(lane) then
                            return fatal(
                                "Gagal drop residual reserve ke lane ",
                                lane.name
                            )
                        end
                    end

                    cp.active = otherLaneName(lane.name)
                    cp.batch_round = 0
                    cp.stage = "COLLECT_ACTIVE"
                    saveCP()
                else
                    -- Semua processing tool yang sedang dibawa sudah <20.
                    -- Baru sekarang protected tools dikirim ke storage.
                    setStage("STORE_PHASE")
                end
            else]]

if not patched:find(old_process, 1, true) then
    print("[NANOFORGE PATCH][FATAL] PROCESS queue-empty block tidak ditemukan.")
    return
end

patched = patched:gsub(
    old_process:gsub("([%%%^%$%(%)%.%[%]%*%+%-%?])", "%%%1"),
    function() return new_process end,
    1
)

print("[NANOFORGE PATCH] State Buffer B -> Buffer A berhasil dipatch di memory.")
print("[NANOFORGE PATCH] Menjalankan main Nanoforge...")

local loader = loadstring or load

if loader == nil then
    print("[NANOFORGE PATCH][FATAL] Lua loader tidak tersedia.")
    return
end

local chunk, err = loader(patched)

if chunk == nil then
    print("[NANOFORGE PATCH][FATAL] Compile patched source gagal: " .. tostring(err))
    return
end

local ok, runErr = pcall(chunk)

if not ok then
    print("[NANOFORGE PATCH][FATAL] Runtime error: " .. tostring(runErr))
end
