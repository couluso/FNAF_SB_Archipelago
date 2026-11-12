from typing import TYPE_CHECKING, Callable

from BaseClasses import CollectionState

from .data import (AREA_BY_KEY, AREA_STORY_GATE, ATRIUM_BADGE, BADGE, COLLECTIBLE_ITEM_NAMES, DAYCARE_PASS,
                   FAZ_CAM, GOLDEN_ITEMS, PROGRESSIVE_FLASHLIGHT, Area, Ending, mission_closure,
                   missions_need_atrium)

COLLECTIBLES = tuple(COLLECTIBLE_ITEM_NAMES.values())

if TYPE_CHECKING:
    from . import FNaFSBWorld


def area_entrance_rule(world: "FNaFSBWorld", area: Area) -> Callable[[CollectionState], bool]:
    """Full rule to enter an area from the Atrium hub: its badge/pass/flashlight rule AND the mission the game needs done before that area opens (data.AREA_STORY_GATE)."""
    base = area_access_rule(world, area)
    gate = AREA_STORY_GATE.get(area.key)
    if not gate:
        return base
    story = missions_rule(world, (gate,))
    return lambda state: base(state) and story(state)


def _area_open_rule(world: "FNaFSBWorld", area_key: str) -> Callable[[CollectionState], bool]:
    """Badge/pass/flashlight part only (story gates are already folded into mission_closure)."""
    if area_key == "atrium":
        return lambda state: True
    if area_key == "daycare":
        return daycare_door_rule(world)
    return area_access_rule(world, AREA_BY_KEY[area_key])


def missions_rule(world: "FNaFSBWorld", missions: tuple) -> Callable[[CollectionState], bool]:
    """True once everything needed to finish all `missions` is held: every area they (and their prerequisites) take place in can be entered, and every item the game needs for them is held."""
    player = world.player
    areas, items = mission_closure(tuple(missions))
    area_rules = [_area_open_rule(world, key) for key in sorted(areas)]
    items = sorted(items)
    badge = ATRIUM_BADGE if missions_need_atrium(tuple(missions)) else 0

    def rule(state: CollectionState) -> bool:
        if badge and state.count(BADGE, player) < badge:
            return False
        return all(state.has(name, player) for name in items) and all(r(state) for r in area_rules)

    return rule


def atrium_rule(world: "FNaFSBWorld") -> Callable[[CollectionState], bool]:
    """The Main Atrium (everything past the Main Entrance and the Daycare) needs the Daycare finished ("Escape The Daycare") and Security Badge level 1."""
    player = world.player
    daycare = missions_rule(world, ("EscapeDaycare",))

    def rule(state: CollectionState) -> bool:
        return state.count(BADGE, player) >= ATRIUM_BADGE and daycare(state)

    return rule


def location_extra_rule(world: "FNaFSBWorld", needs) -> Callable[[CollectionState], bool]:
    """Data.LOCATION_EXTRA_NEEDS (missions, items, areas) of one location."""
    player = world.player
    missions, items, areas = needs
    story = missions_rule(world, tuple(missions)) if missions else None
    area_rules = [area_entrance_rule(world, AREA_BY_KEY[key]) for key in areas]

    def rule(state: CollectionState) -> bool:
        if story and not story(state):
            return False
        return all(state.has(name, player) for name in items) and all(r(state) for r in area_rules)

    return rule


def area_access_rule(world: "FNaFSBWorld", area: Area) -> Callable[[CollectionState], bool]:
    """Badge/pass/flashlight rule to ENTER an area from the Atrium hub (without its story gate, see area_entrance_rule)."""
    player = world.player
    need_badge = max(area.badge - vanilla_badge_shift(world), ATRIUM_BADGE)
    need_passes = area.passes
    need_light = area.dark

    def rule(state: CollectionState) -> bool:
        if need_badge and state.count(BADGE, player) < need_badge:
            return False
        for pass_name in need_passes:
            if not state.has(pass_name, player):
                return False
        if need_light and not state.has(PROGRESSIVE_FLASHLIGHT, player):
            return False
        return True

    return rule


def vanilla_badge_shift(world: "FNaFSBWorld") -> int:
    """Each area's badge level (data.AREAS) is the level you have AFTER its badge holder in the normal game (Prize Counter = 2, and its holder gives the 2nd badge)."""
    option = getattr(world.options, "randomize_security_badges", None)
    return 0 if option is None or option.value else 1


def location_requires_rule(world: "FNaFSBWorld", requires: tuple) -> Callable[[CollectionState], bool]:
    """Extra rule for a single location on top of its area's access rule (e.g. Monty's Claws)."""
    player = world.player

    def rule(state: CollectionState) -> bool:
        return all(state.has(name, player) for name in requires)

    return rule


def junk_only_item_rule(item) -> bool:
    """A location restricted to this can never hold a progression item, for any player."""
    return not item.advancement


def daycare_door_rule(world: "FNaFSBWorld") -> Callable[[CollectionState], bool]:
    """Rule for entering the Daycare through its own front door (metal door + slide)."""
    player = world.player

    def rule(state: CollectionState) -> bool:
        return state.has(DAYCARE_PASS, player) and state.has(PROGRESSIVE_FLASHLIGHT, player)

    return rule


def ending_exit_rule(world: "FNaFSBWorld", ending: Ending) -> Callable[[CollectionState], bool]:
    """Rule for the single ending selected by the Goal option (see regions.py -- only one Ending's entrance/location is ever built per seed, so this never needs to check which goal is active)."""
    player = world.player
    story = missions_rule(world, ending.missions)

    def rule(state: CollectionState) -> bool:
        if not story(state):
            return False
        if state.count(BADGE, player) < ending.badge:
            return False
        for ability in ending.abilities:
            if not state.has(ability, player):
                return False
        if ending.needs_camera and not state.has(FAZ_CAM, player):
            return False
        if ending.needs_goldens:
            for golden in GOLDEN_ITEMS:
                if not state.has(golden, player):
                    return False
        for item_name in ending.needs_items:
            if not state.has(item_name, player):
                return False
        if ending.collectibles:
            held = sum(1 for name in COLLECTIBLES if state.has(name, player))
            if held < ending.collectibles:
                return False
        return True

    return rule
