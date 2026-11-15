from test.bases import WorldTestBase

from ..data import (AREA_BY_KEY, BACKSTAGE_PASS, BADGE, BAGS, BEAK, BOWLING_TICKET, CAMERA_ITEMS, CLAWS,
                    COLLECTIBLE_ITEM_NAMES, RETRO_CDS, VIP_COLLECTIBLES_NEEDED,
                    COMPLETE_EVENTS, DAYCARE_PASS, ENTRY_PASS, EXTRA_COLLECTIBLE_ITEMS, EYES,
                    FAZ_CAM, FAZ_WATCH, FAZERBLASTER, FLASHLIGHT, FLASHLIGHT_UPGRADE_SPOTS,
                    FREDDY_UPGRADE_SPOTS, GOLDEN_ITEMS, HOURS, ITEM_BY_NAME, LOCATION_BY_KEY, LOCATION_NAME_TO_ID,
                    MAZERCISE_KEY, MAZERCISE_TICKET, MISSIONS, MONTY_MYSTERY_MIX, MR_HIPPO_MAGNET,
                    PARTY_PASS, PHOTO_PASS, PRINCESS_QUEST_1, PRINCESS_QUEST_2, PRINCESS_QUEST_3,
                    PROGRESSIVE_FLASHLIGHT, PROGRESSIVE_FREDDY_BATTERY, SCREWDRIVER, TRAP_ALARM, TRAP_DRAIN)

DAYCARE_ITEMS = [ENTRY_PASS, MR_HIPPO_MAGNET, DAYCARE_PASS, PROGRESSIVE_FLASHLIGHT, SCREWDRIVER]
STORY_ITEMS = DAYCARE_ITEMS + [BACKSTAGE_PASS]
SIX_AM_ITEMS = STORY_ITEMS + [PARTY_PASS, "Dance Pass"]

PARTY_FOUL = LOCATION_BY_KEY["atrium.bag_party_foul"].name


class FNaFSBTestBase(WorldTestBase):
    game = "FNaF Security Breach"

    def badges_to(self, level: int) -> None:
        """Collect Security Badge copies until the total (0 at the start) is `level`."""
        have = self.multiworld.state.count(BADGE, self.player)
        for item in self.get_items_by_name(BADGE)[:max(level - have, 0)]:
            self.multiworld.state.collect(item)

    def reach(self, name: str) -> bool:
        return self.multiworld.get_location(name, self.player).can_reach(self.multiworld.state)

    def region(self, name: str) -> bool:
        return self.multiworld.get_region(name, self.player).can_reach(self.multiworld.state)


class TestDefaults(FNaFSBTestBase):
    options = {"starting_areas": 0}

    def test_start_in_main_entrance_with_no_badge(self) -> None:
        self.assertTrue(self.region("Main Entrance"))
        self.assertEqual(self.multiworld.state.count(BADGE, self.player), 0)
        precollected = [i for i in self.multiworld.precollected_items[self.player] if i.name == BADGE]
        self.assertEqual(precollected, [])
        self.assertEqual(len(self.get_items_by_name(BADGE)), 8)

    def test_atrium_needs_daycare_escape_and_two_badges(self) -> None:
        self.assertFalse(self.region("Main Atrium"))
        self.collect_by_name(DAYCARE_ITEMS)
        self.assertFalse(self.region("Main Atrium"))
        self.assertTrue(self.reach("Mission: Escape The Daycare"))
        self.badges_to(1)
        self.assertFalse(self.region("Main Atrium"))
        self.badges_to(2)
        self.assertTrue(self.region("Main Atrium"))

    def test_atrium_needs_the_screwdriver(self) -> None:
        self.collect_by_name([name for name in DAYCARE_ITEMS if name != SCREWDRIVER])
        self.badges_to(8)
        self.assertFalse(self.region("Main Atrium"))
        self.assertFalse(self.region("Prize Counter"))
        self.collect_by_name(SCREWDRIVER)
        self.assertTrue(self.region("Main Atrium"))
        self.assertTrue(self.region("Prize Counter"))
        self.assertTrue(self.region("Loading Dock"))

    def test_fill_hook_places_badges_and_screwdriver_first(self) -> None:
        pool = [self.world.create_item(n) for n in (BADGE, PARTY_PASS, SCREWDRIVER, DAYCARE_PASS)]
        type(self.world).stage_fill_hook(self.multiworld, pool, [], [], [])
        self.assertEqual([i.name for i in pool], [PARTY_PASS, DAYCARE_PASS, BADGE, SCREWDRIVER])

    def test_lobby_past_the_entrance_needs_the_entry_pass(self) -> None:
        names = [LOCATION_BY_KEY[k].name for k in ("atrium.bag_hi_dave", "atrium.bag_easy_money",
                                                   "atrium.mr_hippo_magnet", "atrium.cupcake_pinata")]
        for name in names:
            self.assertFalse(self.reach(name), name)
        self.collect_by_name(ENTRY_PASS)
        for name in names:
            self.assertTrue(self.reach(name), name)

    def test_start_spots_are_before_the_entry_pass(self) -> None:
        reachable = {l.name for l in self.multiworld.get_reachable_locations(self.multiworld.state, self.player)
                     if l.address is not None}
        expected = {LOCATION_BY_KEY[k].name for k in ("atrium.faz_watch", "atrium.entry_pass",
                                                       "atrium.mission_free_freddy", "atrium.mission_get_out",
                                                       "atrium.hour_0", "atrium.lobby_office_cameras")}
        self.assertEqual(reachable, expected)

    def test_entrance_restaurants_need_the_entry_pass(self) -> None:
        name = LOCATION_BY_KEY["atrium.chica_plush"].name
        self.assertFalse(self.reach(name))
        self.collect_by_name(ENTRY_PASS)
        self.assertTrue(self.reach(name))

    def test_salad_tables_need_chicas_chase(self) -> None:
        name = LOCATION_BY_KEY["atrium.freddy_upgrade_atrium"].name
        self.collect_by_name(DAYCARE_ITEMS)
        self.badges_to(2)
        self.assertTrue(self.region("Main Atrium"))
        self.assertFalse(self.reach(name))
        self.badges_to(3)
        self.assertTrue(self.reach("Mission: Loading Dock"))
        self.assertTrue(self.reach(name))

    def test_daycare_needs_pass_and_flashlight(self) -> None:
        self.assertFalse(self.region("Daycare"))
        self.collect_by_name(DAYCARE_PASS)
        self.assertFalse(self.region("Daycare"))
        self.collect_by_name(PROGRESSIVE_FLASHLIGHT)
        self.assertTrue(self.region("Daycare"))

    def test_daycare_pass_is_always_progression(self) -> None:
        self.assertTrue(self.world.create_item(DAYCARE_PASS).advancement)

    def test_faz_watch_and_photo_pass_precollected(self) -> None:
        for name in (FAZ_WATCH, PHOTO_PASS):
            precollected = [i for i in self.multiworld.precollected_items[self.player] if i.name == name]
            self.assertEqual(len(precollected), 1, name)
            in_pool = [i for i in self.multiworld.itempool if i.player == self.player and i.name == name]
            self.assertEqual(len(in_pool), 0, name)

    def test_early_items_any_world(self) -> None:
        for name in (MR_HIPPO_MAGNET, ENTRY_PASS, PROGRESSIVE_FLASHLIGHT, DAYCARE_PASS, BADGE):
            self.assertEqual(self.multiworld.early_items[self.player].get(name), 1, name)
            self.assertFalse(self.multiworld.local_early_items[self.player].get(name), name)
        for name in (MR_HIPPO_MAGNET, ENTRY_PASS, PROGRESSIVE_FLASHLIGHT, DAYCARE_PASS):
            in_pool = [i for i in self.multiworld.itempool if i.player == self.player and i.name == name]
            self.assertGreaterEqual(len(in_pool), 1, name)

    def test_badge_area_needs_badge_and_daycare_escape(self) -> None:
        self.badges_to(2)
        self.assertFalse(self.region("Prize Counter"))
        self.collect_by_name(DAYCARE_ITEMS)
        self.assertTrue(self.region("Prize Counter"))

    def test_pass_area_needs_pass_badge_and_story(self) -> None:
        self.collect_by_name(STORY_ITEMS + [PARTY_PASS])
        self.badges_to(6)
        self.assertFalse(self.region("Fazer Blast"))
        self.badges_to(7)
        self.assertTrue(self.region("Fazer Blast"))

    def test_fazer_blast_needs_both_party_passes(self) -> None:
        self.collect_by_name(STORY_ITEMS)
        self.badges_to(7)
        party = self.get_items_by_name(PARTY_PASS)
        self.assertEqual(len(party), 2)
        self.collect(party[0])
        self.assertFalse(self.region("Fazer Blast"))
        self.collect(party[1])
        self.assertTrue(self.region("Fazer Blast"))

    def test_fazer_blast_needs_parts_and_service_story(self) -> None:
        self.collect_by_name(DAYCARE_ITEMS + [PARTY_PASS])
        self.badges_to(7)
        self.assertFalse(self.region("Fazer Blast"))
        self.collect_by_name(BACKSTAGE_PASS)
        self.assertTrue(self.region("Fazer Blast"))

    def test_dark_area(self) -> None:
        self.collect_by_name(DAYCARE_ITEMS)
        self.badges_to(2)
        self.assertFalse(self.region("Utility Tunnels"))
        self.badges_to(3)
        self.assertTrue(self.region("Utility Tunnels"))

    def test_ability_gated_location(self) -> None:
        self.collect_by_name(DAYCARE_ITEMS)
        self.badges_to(3)
        name = LOCATION_BY_KEY["utility_tunnels.golden_roxy_plush"].name
        self.assertFalse(self.reach(name))
        self.collect_by_name(CLAWS)
        self.assertTrue(self.reach(name))

    def test_upgrade_machine_comp_pass_step(self) -> None:
        name = "Main Entrance: Upgrade Machine, insert the Complimentary Entry Pass"
        self.assertFalse(self.reach(name))
        self.collect_by_name(ENTRY_PASS)
        self.assertTrue(self.reach(name))

    def test_daycare_pass_needs_entry_pass_and_magnet(self) -> None:
        name = "Main Entrance: Upgrade Machine, hack it with the Mr. Hippo Magnet"
        self.assertFalse(self.reach(name))
        self.collect_by_name(MR_HIPPO_MAGNET)
        self.assertFalse(self.reach(name))
        self.collect_by_name(ENTRY_PASS)
        self.assertTrue(self.reach(name))

    def test_hippo_magnet_location_needs_the_entry_pass(self) -> None:
        name = LOCATION_BY_KEY["atrium.mr_hippo_magnet"].name
        self.assertFalse(self.reach(name))
        self.collect_by_name(ENTRY_PASS)
        self.assertTrue(self.reach(name))

    def test_all_missions_and_hours_exist(self) -> None:
        missions = [l for l in self.multiworld.get_locations(self.player) if l.name.startswith("Mission: ")]
        hours = [l for l in self.multiworld.get_locations(self.player) if l.name.startswith("Clock: ")]
        self.assertEqual(len(missions), len(MISSIONS))
        self.assertEqual(len(hours), len(HOURS))

    def test_first_missions_at_start(self) -> None:
        self.assertTrue(self.reach("Mission: Free Freddy"))
        self.assertTrue(self.reach("Mission: Get Out"))
        self.assertFalse(self.reach("Mission: No Re-entry"))

    def test_mission_chain(self) -> None:
        self.collect_by_name(DAYCARE_ITEMS)
        self.badges_to(5)
        self.assertTrue(self.reach("Mission: Escape The Daycare"))
        self.assertFalse(self.reach("Mission: Showtime"))
        self.collect_by_name(BACKSTAGE_PASS)
        self.assertTrue(self.reach("Mission: Showtime"))

    def test_six_am_needs_roxys_eyes(self) -> None:
        self.collect_by_name(SIX_AM_ITEMS)
        self.badges_to(8)
        self.assertTrue(self.reach(LOCATION_BY_KEY["parts_service.repair_roxy"].name))
        for name in ("Mission: Upgrade Freddy", "Clock: 5 AM", "Clock: 6 AM"):
            self.assertFalse(self.reach(name), name)
        self.collect_by_name(EYES)
        self.assertTrue(self.reach("Clock: 6 AM"))

    def test_freddy_party_pass_after_6_am(self) -> None:
        name = "Main Atrium: Party Pass given by Glamrock Freddy after 6 AM"
        self.collect_by_name(SIX_AM_ITEMS)
        self.badges_to(8)
        self.assertFalse(self.reach(name))
        self.collect_by_name(EYES)
        self.assertTrue(self.reach(name))

    def test_defeat_monty_needs_thrill_seeker(self) -> None:
        name = "Monty Golf: Defeat Glamrock Monty (Monty's Claws)"
        self.collect_by_name(SIX_AM_ITEMS + [PARTY_PASS])
        self.badges_to(7)
        self.assertFalse(self.reach(name))
        self.collect_by_name([MAZERCISE_TICKET, MAZERCISE_KEY])
        self.assertTrue(self.reach(name))

    def test_dumpster_diving_needs_monty_mystery_mix(self) -> None:
        self.collect_by_name(SIX_AM_ITEMS + [BADGE])
        self.assertFalse(self.reach("Mission: Dumpster Diving"))
        self.collect_by_name(MONTY_MYSTERY_MIX)
        self.assertTrue(self.reach("Mission: Dumpster Diving"))

    def test_all_49_bags_present_by_default(self) -> None:
        self.assertEqual(len(BAGS), 49)
        bag_names = {l.name for l in LOCATION_BY_KEY.values() if l.kind == "bag"}
        bag_locs = [l for l in self.multiworld.get_locations(self.player)
                    if l.address is not None and l.name in bag_names]
        self.assertEqual(len(bag_locs), 49)

    def test_complete_and_story_locations(self) -> None:
        self.assertEqual(len(COMPLETE_EVENTS), 3)
        for key in ("loading_dock.escape_chica_chase", "rockstar_row.survive_lockdown",
                    "atrium.freddy_lockdown_cutscene"):
            self.assertIsNotNone(self.multiworld.get_location(LOCATION_BY_KEY[key].name, self.player))
        names = {l.name for l in self.multiworld.get_locations(self.player)}
        self.assertNotIn(LOCATION_BY_KEY["daycare.complete_area"].name, names)

    def test_daycare_castle_upgrade_never_progression(self) -> None:
        badge_item = self.world.create_item(BADGE)
        filler_item = self.world.create_item("Battery Refill")
        loc = self.multiworld.get_location(LOCATION_BY_KEY["daycare.flashlight_upgrade_daycare"].name, self.player)
        self.assertFalse(loc.item_rule(badge_item))
        self.assertTrue(loc.item_rule(filler_item))

    def test_daycare_presents_allow_progression(self) -> None:
        badge_item = self.world.create_item(BADGE)
        loc = self.multiworld.get_location(LOCATION_BY_KEY["daycare.freddy_name_shirt"].name, self.player)
        self.assertTrue(loc.item_rule(badge_item))

    def test_daycare_missions_and_complete_allow_progression(self) -> None:
        badge_item = self.world.create_item(BADGE)
        for name in (LOCATION_BY_KEY["daycare.flashlight"].name, "Mission: Let There Be Light"):
            self.assertTrue(self.multiworld.get_location(name, self.player).item_rule(badge_item), name)

    def test_upgrade_locations_exist(self) -> None:
        for key, area, hint in FLASHLIGHT_UPGRADE_SPOTS + FREDDY_UPGRADE_SPOTS:
            self.assertIsNotNone(self.multiworld.get_location(LOCATION_BY_KEY[f"{area}.{key}"].name, self.player))

    def test_progressive_items_in_pool_match_spot_counts(self) -> None:
        pool = [i.name for i in self.multiworld.itempool if i.player == self.player]
        self.assertEqual(pool.count(PROGRESSIVE_FLASHLIGHT), 1 + len(FLASHLIGHT_UPGRADE_SPOTS))
        self.assertNotIn(FLASHLIGHT, pool)
        self.assertEqual(pool.count(PROGRESSIVE_FREDDY_BATTERY), len(FREDDY_UPGRADE_SPOTS))

    def test_cameras_and_extra_collectibles_in_pool(self) -> None:
        pool = [i.name for i in self.multiworld.itempool if i.player == self.player]
        for name, _ in CAMERA_ITEMS:
            self.assertEqual(pool.count(name), 1, name)
            self.assertTrue(self.world.create_item(name).advancement)
        for name, _, count in EXTRA_COLLECTIBLE_ITEMS + RETRO_CDS:
            self.assertEqual(pool.count(name), count, name)
        self.assertEqual(pool.count(MONTY_MYSTERY_MIX), 1)

    def test_collectibles_are_progression_once_each(self) -> None:
        pool = [i.name for i in self.multiworld.itempool if i.player == self.player]
        for name in COLLECTIBLE_ITEM_NAMES.values():
            self.assertEqual(pool.count(name), 1, name)
            self.assertTrue(self.world.create_item(name).advancement)
        self.assertTrue(self.world.create_item(FAZERBLASTER).advancement)

    def test_golden_plushes_are_progression(self) -> None:
        for name in GOLDEN_ITEMS:
            self.assertTrue(self.world.create_item(name).advancement, name)

    def test_trap_items(self) -> None:
        self.assertEqual(ITEM_BY_NAME[TRAP_DRAIN].kind, "trap")
        self.assertEqual(ITEM_BY_NAME[TRAP_ALARM].kind, "trap")

    def test_default_goal_is_leave_and_needs_6_am(self) -> None:
        self.assertIsNotNone(self.multiworld.get_location("Leave the Pizzaplex Alone (Bad Ending)", self.player))
        self.collect_by_name(SIX_AM_ITEMS)
        self.badges_to(8)
        self.assertFalse(self.multiworld.can_beat_game(self.multiworld.state))
        self.collect_by_name(EYES)
        self.assertTrue(self.multiworld.can_beat_game(self.multiworld.state))


class TestDaycareDoors(FNaFSBTestBase):
    options = {"starting_areas": 0}

    def test_front_door_needs_pass_and_flashlight(self) -> None:
        entrance = self.multiworld.get_entrance("Main Entrance -> Daycare (metal door + slide)", self.player)
        self.assertFalse(entrance.can_reach(self.multiworld.state))
        self.collect_by_name([DAYCARE_PASS, PROGRESSIVE_FLASHLIGHT])
        self.assertTrue(entrance.can_reach(self.multiworld.state))

    def test_wooden_door_exit_open_once_inside(self) -> None:
        entrance = self.multiworld.get_entrance("Daycare -> Main Entrance (wooden door)", self.player)
        self.assertFalse(entrance.can_reach(self.multiworld.state))
        self.collect_by_name([DAYCARE_PASS, PROGRESSIVE_FLASHLIGHT])
        self.assertTrue(entrance.can_reach(self.multiworld.state))


class TestDaycareNeedsPass(FNaFSBTestBase):
    def test_daycare_needs_pass(self) -> None:
        self.collect_by_name(PROGRESSIVE_FLASHLIGHT)
        self.assertFalse(self.region("Daycare"))
        self.collect_by_name(DAYCARE_PASS)
        self.assertTrue(self.region("Daycare"))


class TestGoalLoadingDock(FNaFSBTestBase):
    options = {"goal": "loading_dock"}

    def test_needs_6_am(self) -> None:
        self.collect_by_name(SIX_AM_ITEMS + [EYES])
        self.badges_to(7)
        self.assertFalse(self.multiworld.can_beat_game(self.multiworld.state))
        self.badges_to(8)
        self.assertTrue(self.multiworld.can_beat_game(self.multiworld.state))


class TestGoalRooftop(FNaFSBTestBase):
    options = {"goal": "rooftop"}

    def test_needs_6_am_and_fazer_blast(self) -> None:
        self.collect_by_name(SIX_AM_ITEMS)
        self.badges_to(8)
        self.assertFalse(self.multiworld.can_beat_game(self.multiworld.state))
        self.collect_by_name(EYES)
        self.assertTrue(self.multiworld.can_beat_game(self.multiworld.state))


class TestGoalAfton(FNaFSBTestBase):
    options = {"goal": "afton"}

    def test_needs_badge_8_and_all_abilities(self) -> None:
        self.collect_by_name(SIX_AM_ITEMS)
        self.badges_to(8)
        self.collect_by_name([CLAWS, BEAK])
        self.assertFalse(self.multiworld.can_beat_game(self.multiworld.state))
        self.collect_by_name(EYES)
        self.assertTrue(self.multiworld.can_beat_game(self.multiworld.state))


class TestGoalCanon(FNaFSBTestBase):
    options = {"goal": "canon"}

    def test_needs_fazerblaster_and_all_three_princess_quests(self) -> None:
        self.collect_by_name(SIX_AM_ITEMS + [EYES, FAZERBLASTER, PRINCESS_QUEST_1, PRINCESS_QUEST_2])
        self.badges_to(8)
        self.assertFalse(self.multiworld.can_beat_game(self.multiworld.state))
        self.collect_by_name(PRINCESS_QUEST_3)
        self.assertTrue(self.multiworld.can_beat_game(self.multiworld.state))

    def test_princess_quest_locations_require_playing_in_order(self) -> None:
        name = "Arcade: Beat Princess Quest, Act 2"
        self.collect_by_name(SIX_AM_ITEMS)
        self.badges_to(8)
        self.assertFalse(self.reach(name))
        self.collect_by_name(PRINCESS_QUEST_1)
        self.assertFalse(self.reach(name))
        self.collect_by_name(PRINCESS_QUEST_2)
        self.assertTrue(self.reach(name))


class TestGoalUnmasked(FNaFSBTestBase):
    options = {"goal": "unmasked"}

    def test_needs_abilities_camera_goldens_and_vip_collectibles(self) -> None:
        collectibles = list(COLLECTIBLE_ITEM_NAMES.values())
        self.collect_by_name(SIX_AM_ITEMS + [CLAWS, BEAK, EYES, FAZ_CAM])
        self.collect_by_name(collectibles[:VIP_COLLECTIBLES_NEEDED])
        self.badges_to(8)
        self.assertFalse(self.multiworld.can_beat_game(self.multiworld.state))
        self.collect_by_name(list(GOLDEN_ITEMS)[:-1])
        self.assertFalse(self.multiworld.can_beat_game(self.multiworld.state))
        self.collect_by_name(list(GOLDEN_ITEMS)[-1])
        self.assertTrue(self.multiworld.can_beat_game(self.multiworld.state))

    def test_vip_collectible_count(self) -> None:
        collectibles = list(COLLECTIBLE_ITEM_NAMES.values())
        self.collect_by_name(SIX_AM_ITEMS + [CLAWS, BEAK, EYES, FAZ_CAM] + list(GOLDEN_ITEMS))
        self.badges_to(8)
        self.collect_by_name(collectibles[:VIP_COLLECTIBLES_NEEDED - 1])
        self.assertFalse(self.multiworld.can_beat_game(self.multiworld.state))
        self.collect_by_name(collectibles[VIP_COLLECTIBLES_NEEDED - 1])
        self.assertTrue(self.multiworld.can_beat_game(self.multiworld.state))


class TestStartingAreas(FNaFSBTestBase):
    options = {"starting_areas": 3}

    def test_start_passes_precollected(self) -> None:
        pass_names = {i.name for i in ITEM_BY_NAME.values() if i.kind == "pass"}
        precollected = [i.name for i in self.multiworld.precollected_items[self.player] if i.name in pass_names]
        self.assertEqual(len(precollected), 3)
        self.assertEqual(len(set(precollected)), 3)


class TestAreaNeedsPassAndBadge(FNaFSBTestBase):
    options = {"starting_areas": 0}

    def test_area_needs_pass_and_badge(self) -> None:
        self.collect_by_name(STORY_ITEMS)
        self.badges_to(5)
        self.assertFalse(self.region("Bonnie Bowl"))
        self.badges_to(6)
        self.assertFalse(self.region("Bonnie Bowl"))
        self.collect_by_name(BOWLING_TICKET)
        self.assertTrue(self.region("Bonnie Bowl"))


class TestBagSanityOff(FNaFSBTestBase):
    options = {"bag_sanity": "off"}

    def test_no_bag_locations_created(self) -> None:
        bag_names = {l.name for l in LOCATION_BY_KEY.values() if l.kind == "bag"}
        bag_locs = [l for l in self.multiworld.get_locations(self.player) if l.name in bag_names]
        self.assertEqual(len(bag_locs), 0)

    def test_bag_names_still_registered_statically(self) -> None:
        self.assertTrue(all(l.name in LOCATION_NAME_TO_ID for l in LOCATION_BY_KEY.values() if l.kind == "bag"))


class TestBagSanityNoProgression(FNaFSBTestBase):
    options = {"bag_sanity": "no_progression"}

    def test_bags_exist_but_cannot_hold_progression(self) -> None:
        loc = self.multiworld.get_location(PARTY_FOUL, self.player)
        self.assertFalse(loc.item_rule(self.world.create_item(BADGE)))
        self.assertTrue(loc.item_rule(self.world.create_item("Battery Refill")))


class TestBagSanityOn(FNaFSBTestBase):
    options = {"bag_sanity": "on"}

    def test_bags_outside_daycare_allow_progression(self) -> None:
        loc = self.multiworld.get_location(PARTY_FOUL, self.player)
        self.assertTrue(loc.item_rule(self.world.create_item(BADGE)))

    def test_daycare_bags_allow_progression(self) -> None:
        loc = self.multiworld.get_location(
            LOCATION_BY_KEY["daycare.bag_night_terrors"].name, self.player)
        self.assertTrue(loc.item_rule(self.world.create_item(BADGE)))


class TestPresentSanityOff(FNaFSBTestBase):
    options = {"present_sanity": False}

    def test_collectible_presents_removed_key_presents_kept(self) -> None:
        names = {l.name for l in self.multiworld.get_locations(self.player)}
        self.assertNotIn(LOCATION_BY_KEY["utility_tunnels.foxy_plush"].name, names)
        self.assertIn(LOCATION_BY_KEY["kids_cove.golden_sun"].name, names)
        self.assertIn(LOCATION_BY_KEY["rockstar_row.backstage_pass"].name, names)
        self.assertIn("Mission: Free Freddy", names)


class TestDeathLinkDisabledByDefault(FNaFSBTestBase):
    def test_slot_data(self) -> None:
        data = self.world.fill_slot_data()
        self.assertFalse(data["death_link"])
        self.assertEqual(data["death_link_behavior"], 13)


class TestDeathLinkChica(FNaFSBTestBase):
    options = {"death_link": "chica"}

    def test_slot_data_keeps_the_mods_numbers(self) -> None:
        data = self.world.fill_slot_data()
        self.assertTrue(data["death_link"])
        self.assertEqual(data["death_link_behavior"], 0)


class TestDeathLinkOldYamlTrue(FNaFSBTestBase):
    options = {"death_link": "true"}

    def test_old_true_means_random_without_staff_bot(self) -> None:
        data = self.world.fill_slot_data()
        self.assertTrue(data["death_link"])
        self.assertEqual(data["death_link_behavior"], 13)


def _pool_names(test) -> list:
    return [i.name for i in test.multiworld.itempool if i.player == test.player]


def _precollected_names(test) -> list:
    return [i.name for i in test.multiworld.precollected_items[test.player]]


class TestVanillaBadges(FNaFSBTestBase):
    options = {"randomize_security_badges": False}

    def test_every_holder_gives_its_badge(self) -> None:
        from ..data import VANILLA_BADGE_KEYS
        for key in VANILLA_BADGE_KEYS:
            loc = self.multiworld.get_location(LOCATION_BY_KEY[key].name, self.player)
            self.assertEqual(loc.item.name, BADGE, key)
            self.assertTrue(loc.locked, key)
        self.assertNotIn(BADGE, _pool_names(self))

    def test_atrium_needs_level_1(self) -> None:
        from ..rules import atrium_badge
        self.assertEqual(atrium_badge(self.world), 1)

    def test_party_pass_fork_stays_one_level_lower(self) -> None:
        from ..rules import area_badge_need
        self.assertEqual(area_badge_need(self.world, AREA_BY_KEY["fazerblast"]), 5)
        self.assertEqual(area_badge_need(self.world, AREA_BY_KEY["monty_golf"]), 6)

    def test_area_opens_one_level_lower(self) -> None:
        from ..rules import area_access_rule
        rule = area_access_rule(self.world, AREA_BY_KEY["prize_counter"])
        state = self.multiworld.state.copy()
        state.collect(self.world.create_item(SCREWDRIVER))
        self.assertFalse(rule(state))
        state.collect(self.world.create_item(BADGE))
        self.assertTrue(rule(state))


class TestShuffledBadgesKeepTheirLevels(FNaFSBTestBase):
    def test_prize_counter_needs_level_2(self) -> None:
        from ..rules import area_access_rule
        rule = area_access_rule(self.world, AREA_BY_KEY["prize_counter"])
        state = self.multiworld.state.copy()
        state.collect(self.world.create_item(SCREWDRIVER))
        state.collect(self.world.create_item(BADGE))
        self.assertFalse(rule(state))
        state.collect(self.world.create_item(BADGE))
        self.assertTrue(rule(state))


class TestVanillaAbilities(FNaFSBTestBase):
    options = {"randomize_freddys_abilities": False}

    def test_abilities_on_their_bosses(self) -> None:
        from ..data import VANILLA_ABILITY_KEYS
        for key, item in VANILLA_ABILITY_KEYS.items():
            loc = self.multiworld.get_location(LOCATION_BY_KEY[key].name, self.player)
            self.assertEqual(loc.item.name, item, key)
        pool = _pool_names(self)
        for item in (CLAWS, BEAK, EYES):
            self.assertNotIn(item, pool)


class TestCamerasNotRandomized(FNaFSBTestBase):
    options = {"randomize_cameras": False}

    def test_cameras_are_starting_items(self) -> None:
        pre, pool = _precollected_names(self), _pool_names(self)
        for name, _ in CAMERA_ITEMS:
            self.assertIn(name, pre)
            self.assertNotIn(name, pool)


class TestPrincessQuestUnlocked(FNaFSBTestBase):
    options = {"lock_princess_quest": False, "goal": "canon"}

    def test_princess_quest_items_are_starting_items(self) -> None:
        pre, pool = _precollected_names(self), _pool_names(self)
        for name in (PRINCESS_QUEST_1, PRINCESS_QUEST_2, PRINCESS_QUEST_3):
            self.assertIn(name, pre)
            self.assertNotIn(name, pool)


class TestEverythingVanilla(FNaFSBTestBase):
    options = {"randomize_security_badges": False, "randomize_freddys_abilities": False,
               "randomize_cameras": False, "lock_princess_quest": False, "goal": "afton"}

    def test_slot_data_flags(self) -> None:
        data = self.world.fill_slot_data()
        self.assertFalse(data["randomize_security_badges"])
        self.assertFalse(data["randomize_freddys_abilities"])
        self.assertFalse(data["randomize_cameras"])
        self.assertFalse(data["lock_princess_quest"])


class TestNoTrapsByWeight(FNaFSBTestBase):
    options = {"trap_percentage": 100, "trap_weights": {name: 0 for name in
                                                         ("Battery Trap", "Security Alert", "Asthma Trap",
                                                          "Busy Freddy Trap", "Stun Trap", "Reverse Control Trap",
                                                          "SHUT UP FREDDY!!", "Foxy Trap")}}

    def test_no_trap_in_pool(self) -> None:
        from ..data import TRAP_WEIGHTS
        pool = _pool_names(self)
        for name in TRAP_WEIGHTS:
            self.assertNotIn(name, pool)


class TestOnlyBatteryFiller(FNaFSBTestBase):
    options = {"trap_percentage": 0,
               "filler_weights": {"Battery Refill": 0, "Energy Drink": 0, "Caffeine": 0, "Shutdown": 0}}

    def test_only_battery_refills(self) -> None:
        from ..data import FILLER_WEIGHTS
        pool = _pool_names(self)
        for name in FILLER_WEIGHTS:
            if name != "Battery Refill":
                self.assertNotIn(name, pool)
        self.assertIn("Battery Refill", pool)


class TestOnlyFoxyTraps(FNaFSBTestBase):
    options = {"trap_percentage": 100, "trap_weights": {"Foxy Trap": 1}}

    def test_only_foxy(self) -> None:
        from ..data import TRAP_WEIGHTS
        pool = _pool_names(self)
        self.assertIn("Foxy Trap", pool)
        for name in TRAP_WEIGHTS:
            if name != "Foxy Trap":
                self.assertNotIn(name, pool)
