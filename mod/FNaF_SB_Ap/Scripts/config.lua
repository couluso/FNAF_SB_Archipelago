-- FNaF_SB_Ap settings. Restart the game after a change.
local C = {}

C.ap = {
    enabled = true,           -- false: the mod does nothing
    bridge_dir = nil,         -- nil = <this mod>/bridge, must match mod_bridge_folder in host.yaml
    inject = true,            -- give the items received from Archipelago
    notify = true,            -- show the game's "item received" popup
    ready_polls = 3,
    max_awards_per_tick = 3,
    max_award_attempts = 3,
    set_security_level = true,
    battery_drain_fraction = 0.5,   -- share of the battery drained by a Battery Trap
    clock_checks = true,
    send_missions_at_load = true,

    -- Vanilla rewards: Archipelago pickups get a name nobody owns, so they never give their
    -- vanilla item.
    block_vanilla = true,
    swap_prefix = "APX_",
    remove_swap_items = true,
    opened_name = "None",
    reset_opened_presents = true,
    log_swaps = true,
    keep_vanilla = {},
    vanilla_items = { Fazwatch = true, PhotoPass = true },
    remove_vanilla_items = true,
    enforce_security_level = true,

    -- The Daycare flashlight, inside its recharge station.
    extra_pickups = { "MAP_Daycare_Gameplay:PersistentLevel.ChildActor_GEN_VARIABLE_FlashlightCollectible_C_CAT_0" },
    listed_only = { Flashlight = true },
    daycare_flashlight = {
        station = "MAP_Daycare_Gameplay:PersistentLevel.FlashlightRechargeStation_2",
        item = "Flashlight",
        child = "Flashlight",
        condition = "InventoryConditional",
        stash_classes = { SecurityOffice_Daycare_C = true, FlashlightRechargeStation_C = true },
        stash_ms = 5000,
        tries = 3,
        after_take_ms = 2000,
        active_s = 30,
        unequip = { "HasFlashlight" },
    },
    regive_delay = { Flashlight = 25 },   -- seconds before giving back an item the game took
    hold_until_pickup = {},
    condition_swaps = { FazPassUpgradeMachine_C = { HasUpgradedFazPass = "DaycarePass" } },
    voice_lines = {
        { event = "VANESSA_00002", match = { "VANESSA_00002", "supposed to be on lockdown" },
        done_with_mission = "EscapeDaycare" },
    },
    block_story_pickups = { PartyPassChicaRoom = true },
    hold_triggers = {},

    -- Things kept closed until a mission is done, with the message shown when you look at them.
    lock_pickups = {
        ChicaGreenroomCollectible_C = { until_mission = "PartsAndService", why = "it starts the 4 AM blackout",
            message = "Complete Freddy's maintenance first", radius = 600, look = 350, z_offset = 30 },
    },
    arcade_locks = {
        class = "BP_MiniGame_Activator_C", sphere_margin = 170, radius = 600, look = 200, z_offset = 60,
        types = {
            [5] = { item = "Princess Quest I", message = "Princess Quest I required" },
            [6] = { item = "Princess Quest II", message = "Princess Quest II required",
                    before_message = "Beat Princess Quest I before." },
            [7] = { item = "Princess Quest III", message = "Princess Quest III required",
                    before_message = "Beat Princess Quest II before." },
        },
    },
    lock_actors = {
        ElevatorButton_C = { until_mission = "EscapeDaycare", message = "Requires Completing Daycare",
            radius = 600, look = 250, z_offset = 0 },
        ElevatorButton_V2_C = { until_mission = "EscapeDaycare", message = "Requires Completing Daycare",
            radius = 600, look = 250, z_offset = 0 },
        ElevatorButton_V2_PartsService_C = { until_mission = "EscapeDaycare", message = "Requires Completing Daycare",
            radius = 600, look = 250, z_offset = 0 },
    },

    -- Goal: the ending video the game plays tells which ending was reached.
    goal = {
        enabled = true,
        endings = { GregoryInAlleyEnding = "leave", LoadingDockEnding = "loading_dock", VannyEndingDestroy = "rooftop",
                    BurntrapEnding = "afton", VIPEnding = "unmasked", VannyEndingRedeem = "canon" },
        missions = { ["GetOut!"] = "leave" },
        ui_class = "/Game/Cinematics/EndGameCinematicPlayerUI.EndGameCinematicPlayerUI_C", ui_short = "EndGameCinematicPlayerUI_C",
        triggers = { "EndGameVideoCredits", "SetupComicbookSubtitles", "Start Loading Dock Subtitles", "Start Fire Escape Subtitles",
                     "Start Gregory Escapes Subtitles", "Start Vanny Destroyed Subtitles", "Start Vanny Redeemed Subtitles" },
        subtitles = { ["Start Loading Dock Subtitles"] = "loading_dock", ["Start Vanny Destroyed Subtitles"] = "rooftop",
                      ["Start Vanny Redeemed Subtitles"] = "canon" },
        end_game = { "/Game/Blueprints/System/FNAFGameInstance.FNAFGameInstance_C:EndGame" },
        read_delay_ms = 100,
    },

    death_link = {
        enabled = true,
        read_ms = 500,        -- how often the bridge is read for new deaths
        order = { [0] = "chica", [1] = "roxy", [2] = "monty", [3] = "vanny", [4] = "vanessa", [5] = "moon",
                  [9] = "endos", [10] = "freddy", [11] = "staff_bot", [12] = "random", [13] = "random_without_staffbot" },
        kinds = {
            chica = { type = 0 }, roxy = { type = 1 }, monty = { type = 2 },
            endos = { type = 5, wake = { "Wake Endo" }, wake_force = true, behind_first = true },
            vanessa = { type = 3, needs_mission = true, props = { CaughtMissionName = "@completed_mission", CanReceiveAlerts = true },
                        cdo = "/Game/Blueprints/AI/Seeker/Vanessa/Vanessa.Default__Vanessa_C", no_save = true },
            moon = { type = 11, states = { 1, 2, 3 }, moon_seq = true, anywhere = true, random_anywhere = true,
                     actor = false, actor_dist = 120, actor_yaw = 0 },
            staff_bot = { trap_alert_ms = 500, trap_gone_ms = 4000,
                          staff = true, spawn = true, spawner_tries = 3, alert_task = true, world_set = false, spawn_actor = true, load_wait_ms = 2000, general_alert = true, alert_types = { 0, 1, 2 }, alert_count = 1, z_offset = 0,
                          auto_alert = false, real_catch = true, check_ms = 1500, bot_gone_ms = 6000, answer = false,
                          bot_type = 9, catch_dist = 150, alert_after_ms = 1500, gone_after_ms = 500,
                          bot_classes = {}, bot_dist = 250, bot_show_ms = 3000,
                          kill_after_ms = 2500, killers = { "chica", "roxy", "monty", "endos" } },
            vanny = { name = "Vanny", spawn_class = "/Game/Blueprints/AI/Vanny/Vanny.Vanny_C", untested = true,
                      dist = 100, z_offset = 0, load_wait_ms = 2000, life_ms = 20000, catch_delay_ms = 0,
                      methods = { "Jumpscare", "ForceJumpscarePlayer", "LethalJumpscareBPI" } },
            freddy = { freddy = true, untested = true, dist = 150, methods = { "Jumpscare", "LethalJumpscareBPI" } },
        },
        substitutes = { "chica", "roxy", "monty", "endos" },
        after_eject_ms = 10,
        try_untested = true, random_untested = false,
        front_dist = 80,
        instant_delay_ms = 0, instant_retry_ms = 2000,
        trail_tries = 3, trail_max_dist = 1500, round_wait_ms = 1000,
        bad_after_rounds = 2,
        instant_methods = { "OnCaptureOverlap", "ForceJumpscarePlayer", "LethalJumpscareBPI" },
        trace = false,

        -- The "Archipelago Options" page in the pause menu (change the Death Link killer in game).
        -- The texts can be edited freely ("\n" = new line).
        pause_menu = { enabled = true, style = "page", after = "MessagesButton", title = "DEATH LINK",
                       page = { after = "InventoryButton", button = "Archipelago Options", title = "ARCHIPELAGO OPTIONS",
                                row = "Death Link killer", back = "Back",
                                desc_title = "Death Link Behavior",
                                short = "Who comes for you when another player dies.",
                                descriptions = {
                                    Chica = "Chica jumpscares you.",
                                    Roxy = "Roxy jumpscares you.",
                                    Monty = "Monty jumpscares you.",
                                    Vanessa = "Vanessa catches you. (must have completed at least one mission)",
                                    Vanny = "Vanny jumpscares you.",
                                    Moon = "Moon catches you, only when he is free to roam around the building.",
                                    Endos = "An Endo catches you.",
                                    Freddy = "Glamrock Freddy has enough and jumpscares you.",
                                    ["Staff Bot"] = "A staffbot catches you and alert the other animatronics. For a softer deathlink",
                                    Random = "One of them, picked at random each time (Staff Bot included).",
                                    ["Random without Staff Bot"] = "One of them, picked at random each time but can never be the Staff Bot.",
                                    Disabled = "You don't receive deaths nor your deaths are sent to the others",
                                },
                                long_end = "This setting is set to your YAML setting by default and will reset every time the game starts.",
                                disabled_end = "This setting is set to your YAML setting by default and will reset every time the game starts.",
                                desc_width = 650,
                                text_margin = { left = 25, top = 0, right = 25, bottom = 0 },
                                text_width = 575,
                                desc_long_size = 22, desc_short_size = 42,
                                button_font_size = 30,
                                margin = { left = 130, top = 73, right = 0, bottom = 150 },
                                rows_top = 145, row_right = 80, back_top = 40 },
                       place = "top_right", h_align = 3, v_align = 1,
                       in_options = false, options_box = "OptionsVerticalBox", options_after = "GeneralOptionButton",
                       padding = { left = 0, top = 190, right = 120, bottom = 0 },
                       max_tries = 3, look_ms = 250 },
        no_save_s = 120,
        give_up_ms = 30000,
        own_death_s = 60,           -- a death this soon after a Death Link kill is not sent back
        wait_in_freddy = true,
        eject_freddy = true,
        eject_bypass_anim = true,
        retries = 3,
    },

    -- Security Alert trap.
    security_alert = {
        mode = "system", wait_freddy = true, retry_ms = 1000, retries = 120, fallback_own = false,
        alert_name = "StaffbotAlert", types_from_bot = true, alert_types = { 0, 1, 2 }, alert_count = 1,
        voice = { name = "SUN_00007", paths = { "/Game/Audio/Character/VO/SunMan/SUN_00007.SUN_00007" } },
        alarm_after_ms = 5000,
        alarm_sound = { name = "Play_sfx_staffBot_security_alert", paths = {
            "/Game/Audio/Assets/Character/StaffBot/Play_sfx_staffBot_security_alert.Play_sfx_staffBot_security_alert" } },
        alarm_music = true,
        add_spotted = true,
        spawn = true,
        spawn_types = { 0, 1, 2, 3, 5 },
        vanny_type = 100, vanny_wait_ms = 300, vanny_wait_tries = 10,
        type_states = { [11] = { 1, 2, 3 } },
        spawn_props = {
            [3] = { CaughtMissionName = "@completed_mission", CanReceiveAlerts = true },
        },
        capture_off = {},
        scare_dist = 300, scare_retry_ms = 1500,
        scare_methods = { "Jumpscare", "On Jumpscare", "ForceJumpscarePlayer" },
        type_names = { [0] = "Chica", [1] = "Roxy", [2] = "Monty", [3] = "Vanessa", [5] = "Endo", [11] = "Moon", [100] = "Vanny" },
        trail_step = 200, trail_max = 120,
        spawn_min = 1000, spawn_near = 1800, spawn_max = 2500, spawn_max_dz = 250,
        second_alert_ms = 1500,
        spawn_lifetime_s = 90, keep_dist = 1500, force_keep_dist = 500, jump_dist = 3000,
    },

    -- Buffs and traps. `seconds` = how long it lasts; a new copy makes it last longer.
    effects = {
        items = {
            ["Asthma Trap"] = "asthma", ["Energy Drink"] = "energy_drink", ["Caffeine"] = "caffeine",
            ["Busy Freddy Trap"] = "recharge", ["Recharge Trap"] = "recharge",
            ["Stun Trap"] = "stun", ["Reverse Control Trap"] = "reverse",
            ["Shutdown"] = "shutdown", ["SHUT UP FREDDY!!"] = "shut_up",
            ["Foxy Trap"] = "foxy",
        },
        asthma = { seconds = 10 },
        energy_drink = { seconds = 45 },
        caffeine = { seconds = 90, speed_mult = 1.15 },
        recharge = { seconds = 50 },
        stun = { seconds = 5, beep_ms = 900, keys = { "W", "A", "S", "D" },
                 sound = { name = "Play_sfx_freddy_call_unsuccesful", paths = {
                     "/Game/Audio/Assets/Character/Greg/Fazwatch/UI/Play_sfx_freddy_call_unsuccesful.Play_sfx_freddy_call_unsuccesful" } } },
        reverse = { seconds = 15 },
        reverse_axes = { "MoveForward", "MoveRight" },
        shut_up = { seconds = 90, overlap_s = 0.01, fallback_s = 4, volume = 5.0,
            path = "/Game/Audio/Character/VO/Freddy/",
            lines = {
                { "FREDDY_00002", 0.95 }, { "FREDDY_00019", 4.38 }, { "FREDDY_00024a", 1.99 }, { "FREDDY_00026", 3.91 },
                { "FREDDY_00037", 3.05 }, { "FREDDY_00047", 5.05 }, { "FREDDY_00061a", 3.68 }, { "FREDDY_00063", 16.96 },
                { "FREDDY_00065", 2.76 }, { "FREDDY_00071", 2.47 }, { "FREDDY_00074", 2.55 }, { "FREDDY_00075", 0.95 },
                { "FREDDY_00076", 1.24 }, { "FREDDY_00079", 1.13 }, { "FREDDY_00122a", 3.96 }, { "FREDDY_00199", 2.69 },
                { "FREDDY_00200", 1.53 }, { "FREDDY_00201", 1.43 }, { "FREDDY_00202", 1.92 }, { "FREDDY_00211", 10.25 },
            } },
        shutdown = { radius = 2500, stun_s = 60 },
        -- Foxy Trap: the GIF frames on screen. The sound comes from Content/Paks/zzz_APFoxy_P.pak,
        -- which the client builds when it starts.
        foxy = { seconds = 1.72, z_order = 1000, sound = true,
                 frames = "Media/foxy/foxy_%02d.png", frame_count = 17, frame_ms = 50, loop = true,
                 frame_w = 1024, frame_h = 768, fit = "height", tick_ms = 25,
                 game_sound = true, game_event = "Play_mus_foreverAndEver_old", game_sound_s = 1.85,
                 screen_fit = "stretch",
                 play_once = true },
    },

    -- Popup of an opened Archipelago pickup, and the notification for each received item.
    popup = { enabled = true, icon_file = "ap_item.png", other_format = "%s (%s)",
              load_icons = false, trace = false, hook_delay_ms = 10, tick_ms = 33, fresh_s = 0.4,
              icon_files = { progression = "icons/progression.png", useful = "icons/useful.png",
                             filler = "icons/filler.png", trap = "icons/trap.png" },
              unknown_text = "Archipelago item", window_s = 8 },
    received_notify = { enabled = true, icon_file = "icons/proguseful.png", load_icons = false,
               font = "/Game/Fonts/Oxanium_Font.Oxanium_Font", typeface = "Default", font_size = 26,
               icon_size = 64, gap = 14, margin_x = 40, margin_y = 40, shadow = 0.75,
               fade_in_ms = 350, slide_px = 40, hold_s = 3, hold_busy_s = 1.5, busy_queue = 2,
               fade_out_ms = 600, max_queue = 8, z_order = 900, tick_ms = 25,
               sound = true, sound_event = "Play_Fazwatch_NewMessage" },
    show_messages = true,
    look_cos = 0.93,
    event_aliases = { ["inventory DaycarePass"] = "actor FazPassUpgradeMachine_C.MagnetDone?" },
    complete_story_tasks = true,
}

C.poll_ms = 2000            -- how often the game state is read
C.prompt_ms = 200
C.after_pickup_quiet_s = 5
C.hook_retry_ms = 5000
C.hook_retry_max = 720

-- Log file: <this mod>/log.txt, rewritten at each launch.
C.max_log_lines = 5000
C.log_console = false       -- true: every log line also goes to the UE4SS console
C.log_verbose = false       -- true: more details in the log (for bug reports)
C.log_state_details = false
C.read_world_flags = false

C.native_hooks = {
    { path = "/Script/fnaf9.FNAFInventorySystem:AwardItem", snapshot = true },
    { path = "/Script/fnaf9.FNAFInventorySystem:RemoveItem", snapshot = true },
    { path = "/Script/fnaf9.FNAFInventorySystem:AwardMessage", snapshot = true },
    { path = "/Script/fnaf9.FNAFInventorySystem:SetSecurityLevel", snapshot = true },
    { path = "/Script/fnaf9.FNAFInventorySystem:SetPartyLevel", snapshot = true },
    { path = "/Script/fnaf9.FNAFInventorySystem:UsePartyPass", snapshot = true },
    { path = "/Script/fnaf9.FNAFInventorySystem:SetMaxPowerLevel_Fazwatch", snapshot = true },
    { path = "/Script/fnaf9.FNAFInventorySystem:SetMaxPowerLevel_Freddy", snapshot = true },
    { path = "/Script/fnaf9.WorldStateSystem:AddDeath", snapshot = true },
    { path = "/Script/fnaf9.FNAFMissionSystem:CompleteMission", snapshot = true },
    { path = "/Script/fnaf9.FNAFMissionSystem:CompleteMissionTask", snapshot = true },
    { path = "/Script/fnaf9.FNAFCheatManager:UpgradeFreddy", snapshot = true },
    { path = "/Script/fnaf9.FNAFSaveGameSystem:LoadCheckpoint", snapshot = true },
    { path = "/Script/fnaf9.FNAFSaveGameSystem:LoadAutoSave", snapshot = true },
}

local COL = "/Game/Blueprints/Objects/Collectibles/"
local PRE = "/Game/Model_Assets/SetsPRE/"
C.bp_hooks = {
    { path = COL .. "Collectible.Collectible_C:OnPlayerInteract", swap = true },
    { path = COL .. "Collectible.Collectible_C:OnBeginCollect", swap = true },
    { path = COL .. "Collectible.Collectible_C:OnCollect", snapshot = true, check = "collect" },
    { path = COL .. "PresentCollectible.PresentCollectible_C:OnBeginCollect", swap = true },
    { path = COL .. "PresentCollectible.PresentCollectible_C:OnCollect", snapshot = true, check = "collect" },
    { path = COL .. "FlashlightCollectible.FlashlightCollectible_C:OnPlayerInteract", swap = true },
    { path = COL .. "FlashlightCollectible.FlashlightCollectible_C:OnCollect", snapshot = true, check = "collect" },
    { path = COL .. "MessageCollectible.MessageCollectible_C:OnBeginCollect" },
    { path = COL .. "MessageCollectible.MessageCollectible_C:OnCollect", snapshot = true, check = "message" },
    { path = COL .. "CollectibleTape.CollectibleTape_C:OnPlayerInteract", snapshot = true },
    { path = COL .. "ChicaGreenroomCollectible.ChicaGreenroomCollectible_C:OnCollect", snapshot = true, check = "collect" },
    { path = PRE .. "PRE_BadgeHolder.PRE_BadgeHolder_C:Collect_SecurityBadge", snapshot = true },
    { path = PRE .. "PRE_BadgeHolder.PRE_BadgeHolder_C:Anim Sequence Finished", snapshot = true },
}

local SUB = "/Game/Blueprints/UI/Subtitles/"
C.voice_hooks = {
    { path = SUB .. "WI_SubtitlesManager.WI_SubtitlesManager_C:BeginVoiceOverDisplay", voice = true, max_params = 1 },
}
C.voice_widgets = {}

C.real_world_map = "MAP_TheWorld"
C.world_switch_pause_s = 5

C.inventory_scalars = { "SecurityLevel", "CollectedPartyPassCount", "UsedPartyPassCount",
    "FazwatchMaxPowerLevel", "FreddyMaxPowerLevel" }
C.inventory_quiet = { "FazwatchPowerLevel", "FreddyPowerLevel", "NumAvailableFlash" }
C.freddy_state_fields = { "HasPowerUpgrade", "HasMontyClaws", "HasChicaBeak", "HasRoxyEyes" }
C.arcade_games = { "PrincessQuestOne", "PrincessQuestTwo", "PrincessQuestThree" }
C.arcade_fields = { "Played", "Glitched" }
C.game_instance_flags = { "PrincessQuest1Completed", "PrincessQuest2Completed" }
C.watch_actor_props = { FazPassUpgradeMachine_C = { "ComplimentaryPassDone?", "MagnetDone?" } }
C.gregory_props = { "HasFlashlight", "FlashlightInventoryName" }

return C
