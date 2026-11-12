import logging
import settings
from collections import Counter
from typing import Any, ClassVar, Dict, List

from BaseClasses import Item, ItemClassification, Tutorial
from worlds.AutoWorld import WebWorld, World
from worlds.LauncherComponents import Component, Type, components, launch_subprocess

from . import data
from .data import (AREAS, BADGE, BATTERY, CAMERA_ITEMS, COLLECTIBLE_ITEM_NAMES, DAYCARE_PASS, ENDING_BY_GOAL, ENTRY_PASS, EXTRA_ITEM_NAMES, FAZ_WATCH, PROGRESSIVE_FLASHLIGHT,
                   FILLER_WEIGHTS, GAME_NAME, ITEM_BY_NAME, ITEM_NAME_TO_ID, ITEMS,
                   EXTRA_PROGRESSION_SHARE, LOCATION_NAME_TO_ID, MR_HIPPO_MAGNET, PHOTO_PASS,
                   LOCATION_BY_KEY, PRINCESS_QUEST_ITEMS, TRAP_WEIGHTS, VANILLA_ABILITY_KEYS,
                   VANILLA_BADGE_KEYS, VICTORY_EVENT)
from Options import OptionError

from .options import DEATH_LINK_KILLER, OPTION_GROUPS, BagSanity, FNaFSBOptions, Goal
from .regions import create_regions
from .rules import junk_only_item_rule

CLASSIFICATIONS = {
    "progression": ItemClassification.progression,
    "useful": ItemClassification.useful,
    "filler": ItemClassification.filler,
    "trap": ItemClassification.trap,
}

STARTING_AREA_CANDIDATES = tuple(a for a in AREAS if a.start_eligible and len(a.passes) == 1)


class FNaFSBSettings(settings.Group):
    class ModFolder(settings.FolderPath):
        """Folder used to talk to the game mod: <game>/.../Mods/FNaF_SB_Ap/bridge"""
        description = "FNaF Security Breach mod bridge folder"
        required = False

    mod_bridge_folder: ModFolder = ModFolder("")


def _launch_client(*args: str) -> None:
    from .client import launch
    launch_subprocess(launch, name="FNaFSBClient", args=args)


components.append(Component(
    "FNaF SB Client", func=_launch_client, component_type=Type.CLIENT,
    game_name=GAME_NAME, description="Connects the FNaF Security Breach mod to an Archipelago server.",
))


class FNaFSBItem(Item):
    game = GAME_NAME


class FNaFSBWebWorld(WebWorld):
    theme = "partyTime"
    setup_en = Tutorial(
        "Multiworld Setup Guide",
        "How to set up FNaF Security Breach for Archipelago.",
        "English", "setup_en.md", "setup/en", ["Coulu"],
    )
    tutorials = [setup_en]
    option_groups = OPTION_GROUPS


class FNaFSBWorld(World):
    """Five Nights at Freddy's: Security Breach."""
    game = GAME_NAME
    web = FNaFSBWebWorld()
    options_dataclass = FNaFSBOptions
    options: FNaFSBOptions
    settings: ClassVar[FNaFSBSettings]
    settings_key = "fnaf_sb_options"
    topology_present = True

    item_name_to_id = ITEM_NAME_TO_ID
    location_name_to_id = LOCATION_NAME_TO_ID
    item_name_groups = {
        "Passes": {i.name for i in ITEMS if i.kind == "pass"},
        "Abilities": {i.name for i in ITEMS if i.kind == "ability"},
        "Golden Plushes": {i.name for i in ITEMS if i.kind == "golden"},
        "Gadgets": {i.name for i in ITEMS if i.kind == "gadget"},
        "Cameras": {name for name, _ in CAMERA_ITEMS},
        "Retro CDs": {i.name for i in ITEMS if i.name.startswith("Retro CD ")},
        "Traps": set(TRAP_WEIGHTS),
    }
    location_name_groups = {
        "Presents": {l.name for l in data.LOCATIONS if l.kind == "present"},
        "Bags": {l.name for l in data.LOCATIONS if l.kind == "bag"},
        "Missions": {l.name for l in data.LOCATIONS if l.kind == "mission"},
        "Clock": {l.name for l in data.LOCATIONS if l.kind == "hour"},
        "Badges": {l.name for l in data.LOCATIONS if l.kind == "badge"},
        "Abilities": {l.name for l in data.LOCATIONS if l.kind == "ability"},
        "Complete": {l.name for l in data.LOCATIONS if l.kind == "complete" and l.key not in data.RETIRED_LOCATION_KEYS},
        **{a.name: {l.name for l in data.LOCATIONS if l.area == a.key} for a in AREAS},
    }

    precollected_counts: Counter

    def generate_early(self) -> None:
        self.precollected_counts = Counter()
        if (self.options.goal.value == Goal.option_unmasked and not self.options.present_sanity
                and self.options.bag_sanity.value == BagSanity.option_off):
            raise OptionError(f"FNaF Security Breach ({self.player_name}): the Unmasked goal needs "
                              f"Present Sanity on or Bag Sanity not off (not enough locations).")

        def precollect(name: str) -> None:
            self.precollected_counts[name] += 1
            self.multiworld.push_precollected(self.create_item(name))


        precollect(FAZ_WATCH)

        precollect(PHOTO_PASS)

        self.multiworld.local_early_items[self.player][MR_HIPPO_MAGNET] = 1

        self.multiworld.local_early_items[self.player][ENTRY_PASS] = 1

        self.multiworld.local_early_items[self.player][PROGRESSIVE_FLASHLIGHT] = 1
        self.multiworld.local_early_items[self.player][DAYCARE_PASS] = 1
        if self.options.randomize_security_badges:
            self.multiworld.local_early_items[self.player][BADGE] = 1

        if not self.options.lock_princess_quest:
            for name in PRINCESS_QUEST_ITEMS:
                precollect(name)
        if not self.options.randomize_cameras:
            for name, _ in CAMERA_ITEMS:
                precollect(name)

        self.filler_weights = {n: int(self.options.filler_weights.value.get(n, 0)) for n in FILLER_WEIGHTS}
        self.trap_weights = {n: int(self.options.trap_weights.value.get(n, 0)) for n in TRAP_WEIGHTS}
        if not any(self.filler_weights.values()):
            self.filler_weights = {BATTERY: 1}

        count = min(int(self.options.starting_areas), len(STARTING_AREA_CANDIDATES))
        for area in self.random.sample(STARTING_AREA_CANDIDATES, count):
            precollect(area.passes[0])

    def create_regions(self) -> None:
        create_regions(self)

    def create_item(self, name: str) -> FNaFSBItem:
        item = ITEM_BY_NAME[name]
        return FNaFSBItem(name, CLASSIFICATIONS[item.classification], item.id, self.player)

    def create_event(self, name: str) -> FNaFSBItem:
        return FNaFSBItem(name, ItemClassification.progression, None, self.player)

    def get_filler_item_name(self) -> str:
        weights = getattr(self, "filler_weights", None) or FILLER_WEIGHTS
        names, values = zip(*weights.items())
        return self.random.choices(names, values)[0]

    def vanilla_placements(self) -> Dict[str, str]:
        """Location name -> item name kept on its vanilla spot (locked), from the Randomize Security Badges / Randomize Freddy's Abilities options."""
        placed: Dict[str, str] = {}
        if not self.options.randomize_security_badges:
            for key in VANILLA_BADGE_KEYS:
                placed[LOCATION_BY_KEY[key].name] = BADGE
        if not self.options.randomize_freddys_abilities:
            for key, item in VANILLA_ABILITY_KEYS.items():
                placed[LOCATION_BY_KEY[key].name] = item
        return placed

    def create_items(self) -> None:
        pool: List[FNaFSBItem] = []
        extras = set(EXTRA_ITEM_NAMES)
        locked = Counter()
        for loc_name, item_name in self.vanilla_placements().items():
            self.multiworld.get_location(loc_name, self.player).place_locked_item(self.create_item(item_name))
            locked[item_name] += 1
        for item in ITEMS:
            if item.count <= 0 or item.name in extras:
                continue
            remaining = item.count - self.precollected_counts.get(item.name, 0) - locked[item.name]
            pool.extend(self.create_item(item.name) for _ in range(max(remaining, 0)))

        collectibles = list(COLLECTIBLE_ITEM_NAMES.values())
        self.random.shuffle(collectibles)
        needed = ENDING_BY_GOAL[self.options.goal.value].collectibles
        pool.extend(self.create_item(name) for name in collectibles[:needed])

        free_locations = len(self.multiworld.get_unfilled_locations(self.player))
        if free_locations < len(pool):
            raise Exception(
                f"FNaF Security Breach ({self.player_name}): {len(pool)} items but only "
                f"{free_locations} locations. Turn Present Sanity or Bag Sanity on, or lower "
                f"Starting Areas."
            )

        capable = sum(1 for loc in self.multiworld.get_unfilled_locations(self.player)
                      if loc.item_rule is not junk_only_item_rule)
        max_progression = int(capable * EXTRA_PROGRESSION_SHARE)
        progression = sum(1 for item in pool if item.advancement)
        already = {item.name for item in pool}
        extra_names = [n for n in EXTRA_ITEM_NAMES if n not in COLLECTIBLE_ITEM_NAMES.values()]
        cams = len(CAMERA_ITEMS)
        extra_names = extra_names[:cams] + [n for n in collectibles if n not in already] + extra_names[cams:]
        self.left_out_items: List[str] = []
        for name in extra_names:
            for _ in range(ITEM_BY_NAME[name].count - self.precollected_counts.get(name, 0)):
                item = self.create_item(name)
                if len(pool) < free_locations and (not item.advancement or progression < max_progression):
                    progression += item.advancement
                    pool.append(item)
                else:
                    self.left_out_items.append(name)
        if self.left_out_items:
            logging.warning(f"FNaF Security Breach ({self.player_name}): not enough room (PresentSanity/BagSanity off), "
                            f"left out {len(self.left_out_items)} items: {self.left_out_items}")

        remaining = free_locations - len(pool)

        trap_count = round(remaining * int(self.options.trap_percentage) / 100)
        if not any(self.trap_weights.values()):
            trap_count = 0
        trap_names, trap_weights = zip(*self.trap_weights.items())
        for _ in range(trap_count):
            pool.append(self.create_item(self.random.choices(trap_names, trap_weights)[0]))
        for _ in range(remaining - trap_count):
            pool.append(self.create_item(self.get_filler_item_name()))

        self.multiworld.itempool += pool

    def set_rules(self) -> None:
        self.multiworld.completion_condition[self.player] = lambda state: state.has(VICTORY_EVENT, self.player)

    def fill_slot_data(self) -> Dict[str, Any]:
        return {
            "world_version": 5,
            "lock_areas": True,
            "present_sanity": bool(self.options.present_sanity),
            "bag_sanity": int(self.options.bag_sanity.value),
            "badge_gating": True,
            "lock_daycare": True,
            "goal": self.options.goal.current_key,
            "randomize_security_badges": bool(self.options.randomize_security_badges),
            "randomize_freddys_abilities": bool(self.options.randomize_freddys_abilities),
            "randomize_cameras": bool(self.options.randomize_cameras),
            "lock_princess_quest": bool(self.options.lock_princess_quest),
            "death_link": self.options.death_link.value != 0,
            "death_link_behavior": DEATH_LINK_KILLER.get(self.options.death_link.value, 13),
        }
