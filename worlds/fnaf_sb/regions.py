from typing import TYPE_CHECKING

from BaseClasses import Location, Region

from .data import (AREAS, COLLECTIBLE_PRESENT_KEYS, DAYCARE_JUNK_ONLY_KEYS, ENDING_BY_GOAL, ENTRANCE_LOCATION_KEYS, ENTRANCE_REGION, HOURS,
                   LOCATION_EXTRA_NEEDS, LOCATION_MISSION_GATE, RETIRED_LOCATION_KEYS,
                   LOCATIONS, LOCATION_NAME_TO_ID, MISSION_BY_INTERNAL, VICTORY_EVENT)
from .rules import (area_entrance_rule, atrium_rule, daycare_door_rule, ending_exit_rule, junk_only_item_rule,
                    location_extra_rule, location_requires_rule, missions_rule)

HOUR_MISSIONS = {str(hour): missions for hour, _, missions in HOURS}


def location_is_enabled(world: "FNaFSBWorld", loc) -> bool:
    """PresentSanity / BagSanity: whether this seed creates the location at all."""
    if loc.key in RETIRED_LOCATION_KEYS:
        return False
    if loc.kind == "bag":
        return world.options.bag_sanity.value != 0
    if loc.kind == "present" and loc.key.split(".", 1)[1] in COLLECTIBLE_PRESENT_KEYS:
        return bool(world.options.present_sanity)
    return True


def _location_rule(world: "FNaFSBWorld", loc):
    """Item requirements of the location plus, for missions/hours/gated events, everything the game needs done before it."""
    rules = []
    if loc.requires:
        rules.append(location_requires_rule(world, loc.requires))
    if loc.kind == "mission":
        m = MISSION_BY_INTERNAL[loc.hint]
        rules.append(missions_rule(world, (m.internal,)))
    elif loc.kind == "hour":
        rules.append(missions_rule(world, HOUR_MISSIONS[loc.hint]))
    elif loc.key in LOCATION_MISSION_GATE:
        rules.append(missions_rule(world, (LOCATION_MISSION_GATE[loc.key],)))
    if loc.key in LOCATION_EXTRA_NEEDS:
        rules.append(location_extra_rule(world, LOCATION_EXTRA_NEEDS[loc.key]))
    if not rules:
        return None
    if len(rules) == 1:
        return rules[0]
    return lambda state: all(r(state) for r in rules)

if TYPE_CHECKING:
    from . import FNaFSBWorld


class FNaFSBLocation(Location):
    game = "FNaF Security Breach"


def create_regions(world: "FNaFSBWorld") -> None:
    mw, player = world.multiworld, world.player

    menu = Region("Menu", player, mw)
    mw.regions.append(menu)

    regions = {}
    for area in AREAS:
        region = Region(area.name, player, mw)
        regions[area.key] = region
        mw.regions.append(region)
    entrance = Region(ENTRANCE_REGION, player, mw)
    mw.regions.append(entrance)

    bag_mode = world.options.bag_sanity.value

    for loc in LOCATIONS:
        if not location_is_enabled(world, loc):
            continue
        region = entrance if loc.key in ENTRANCE_LOCATION_KEYS else regions[loc.area]
        location = FNaFSBLocation(player, loc.name, LOCATION_NAME_TO_ID[loc.name], region)
        rule = _location_rule(world, loc)
        if rule:
            location.access_rule = rule
        if loc.key in DAYCARE_JUNK_ONLY_KEYS or (loc.kind == "bag" and bag_mode == 1):
            location.item_rule = junk_only_item_rule
        region.locations.append(location)

    menu.connect(entrance, "Start Game")
    entrance.connect(regions["daycare"], "Main Entrance -> Daycare (metal door + slide)",
                     daycare_door_rule(world))
    regions["daycare"].connect(entrance, "Daycare -> Main Entrance (wooden door)")
    regions["daycare"].connect(regions["atrium"], "Daycare -> Main Atrium", atrium_rule(world))
    entrance.connect(regions["atrium"], "Main Entrance -> Main Atrium", atrium_rule(world))
    regions["atrium"].connect(entrance, "Main Atrium -> Main Entrance")

    for area in AREAS:
        if area.always_open or area.key == "daycare":
            continue
        regions["atrium"].connect(
            regions[area.key],
            f"Main Atrium -> {area.name}",
            area_entrance_rule(world, area),
        )

    ending = ENDING_BY_GOAL[world.options.goal.value]
    exit_region = Region("Pizzaplex Exit", player, mw)
    mw.regions.append(exit_region)
    regions[ending.area].connect(exit_region, f"{regions[ending.area].name} -> {ending.name}",
                                  ending_exit_rule(world, ending))
    victory = FNaFSBLocation(player, ending.name, None, exit_region)
    victory.place_locked_item(world.create_event(VICTORY_EVENT))
    exit_region.locations.append(victory)
