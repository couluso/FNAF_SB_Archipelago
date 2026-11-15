from typing import TYPE_CHECKING, Callable

from BaseClasses import CollectionState

from .data import (AREA_BY_KEY, AREA_STORY_GATE, ATRIUM_BADGE, BADGE, BADGE_FORKS, COLLECTIBLE_ITEM_NAMES,
                   ATRIUM_ITEMS, DAYCARE_PASS, FAZ_CAM, GOLDEN_ITEMS, PASS_COUNTS, PROGRESSIVE_FLASHLIGHT,
                   SHUFFLED_ATRIUM_BADGE, Area, Ending, mission_closure, missions_need_atrium)

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
    need_atrium = missions_need_atrium(tuple(missions))
    badge = atrium_badge(world) if need_atrium else 0

    def rule(state: CollectionState) -> bool:
        if badge and state.count(BADGE, player) < badge:
            return False
        if need_atrium and not state.has_all(ATRIUM_ITEMS, player):
            return False
        return all(state.has(name, player) for name in items) and all(r(state) for r in area_rules)

    return rule


def atrium_badge(world: "FNaFSBWorld") -> int:
    """Security Level the Main Atrium needs: 2 with shuffled badges, as Chica's kitchen and El Chip's (where the story goes next) both need level 2 to get back out. 1 with vanilla badges, the holders inside give the rest."""
    return SHUFFLED_ATRIUM_BADGE if badges_shuffled(world) else ATRIUM_BADGE


def atrium_rule(world: "FNaFSBWorld") -> Callable[[CollectionState], bool]:
    """The Main Atrium (everything past the Main Entrance and the Daycare) needs the Daycare finished ("Escape The Daycare"), its Security Level (atrium_badge) and the Screwdriver for the Lost and Found vent."""
    player = world.player
    daycare = missions_rule(world, ("EscapeDaycare",))
    need = atrium_badge(world)

    def rule(state: CollectionState) -> bool:
        return state.count(BADGE, player) >= need and state.has_all(ATRIUM_ITEMS, player) and daycare(state)

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
    need_badge = max(area_badge_need(world, area), atrium_badge(world))
    need_passes = [(name, PASS_COUNTS.get(name, 1)) for name in area.passes]
    need_light = area.dark

    def rule(state: CollectionState) -> bool:
        if need_badge and state.count(BADGE, player) < need_badge:
            return False
        if not state.has_all(ATRIUM_ITEMS, player):
            return False
        for pass_name, count in need_passes:
            if not state.has(pass_name, player, count):
                return False
        if need_light and not state.has(PROGRESSIVE_FLASHLIGHT, player):
            return False
        return True

    return rule


def badges_shuffled(world: "FNaFSBWorld") -> bool:
    option = getattr(world.options, "randomize_security_badges", None)
    return option is None or bool(option.value)


def area_badge_need(world: "FNaFSBWorld", area: Area) -> int:
    """Security Level the logic asks for before an area, so the player can also get back out of it.
    - Shuffled badges (default): the area's full level, and where the story lets the player pick a path (data.BADGE_FORKS) the higher level of the two.
    - Vanilla badges: one level lower, the holder inside (or the next one on the way) gives the rest, like in the game."""
    if not badges_shuffled(world):
        return area.badge - 1
    for fork in BADGE_FORKS:
        if area.key in fork:
            return max(AREA_BY_KEY[key].badge for key in fork)
    return area.badge


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
