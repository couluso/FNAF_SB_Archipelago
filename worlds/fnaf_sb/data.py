"""Areas, items and locations of the FNaF Security Breach world.

The map is a hub: the Main Atrium connects to every other area, each area opening with its
Security Badge level, pass or flashlight, plus the story mission the game needs first.
"""
from __future__ import annotations

from dataclasses import dataclass, replace
from typing import Dict, List, Tuple

try:
    from .location_names import LOCATION_NAMES
except ImportError:
    import importlib.util as _ilu
    import pathlib as _pl
    _spec = _ilu.spec_from_file_location("fnaf_sb_location_names", _pl.Path(__file__).with_name("location_names.py"))
    _mod = _ilu.module_from_spec(_spec)
    _spec.loader.exec_module(_mod)
    LOCATION_NAMES = _mod.LOCATION_NAMES

GAME_NAME = "FNaF Security Breach"

ITEM_BASE_ID = 91_540_000
LOCATION_BASE_ID = 91_541_000

BADGE = "Security Badge"
MAX_BADGE_LEVEL = 8

FLASHLIGHT = "Flashlight"
FAZ_CAM = "Faz-Camera"
FAZ_WATCH = "Faz-Watch"
SCREWDRIVER = "Screwdriver"

CLAWS = "Monty's Claws"
BEAK = "Chica's Beak"
EYES = "Roxy's Eyes"

GOLDEN_SUN = "Golden Sun Plush"
GOLDEN_MOON = "Golden Moon Plush"
GOLDEN_FREDDY = "Golden Freddy Plush"
GOLDEN_CHICA = "Golden Chica Plush"
GOLDEN_MONTY = "Golden Monty Plush"
GOLDEN_ROXY = "Golden Roxy Plush"
GOLDEN_ITEMS: Tuple[str, ...] = (GOLDEN_SUN, GOLDEN_MOON, GOLDEN_FREDDY, GOLDEN_CHICA, GOLDEN_MONTY, GOLDEN_ROXY)

FAZERBLASTER = "Fazerblaster"
PRINCESS_QUEST_1 = "Princess Quest I"
PRINCESS_QUEST_2 = "Princess Quest II"
PRINCESS_QUEST_3 = "Princess Quest III"
GOLDEN_PRESENT_KEY: Dict[str, str] = {
    "golden_sun": GOLDEN_SUN, "golden_moon": GOLDEN_MOON, "golden_freddy": GOLDEN_FREDDY,
    "golden_chica": GOLDEN_CHICA, "golden_monty": GOLDEN_MONTY, "golden_roxy_plush": GOLDEN_ROXY,
}

ENTRY_PASS = "Complimentary Entry Pass"
DAYCARE_PASS = "Daycare Pass"
PHOTO_PASS = "Photo Pass"
BACKSTAGE_PASS = "Backstage Pass"
PARTY_PASS = "Party Pass"
BOWLING_TICKET = "Bowling Ticket"
DANCE_PASS = "Dance Pass"
MAZERCISE_TICKET = "Mazercise Ticket"
MAZERCISE_KEY = "Mazercise Control Key"

MR_HIPPO_MAGNET = "Mr. Hippo Magnet"
MONTY_MYSTERY_MIX = "Monty Mystery Mix"

VICTORY_EVENT = "Victory"

TOKENS_SMALL = "Faz-Tokens (50)"
TOKENS_LARGE = "Faz-Tokens (200)"
BATTERY = "Battery Refill"
TRAP_DRAIN = "Battery Trap"
TRAP_ALARM = "Security Alert"
TRAP_ASTHMA = "Asthma Trap"
BUFF_ENERGY_DRINK = "Energy Drink"
BUFF_CAFFEINE = "Caffeine"
TRAP_RECHARGE = "Busy Freddy Trap"
TRAP_STUN = "Stun Trap"
TRAP_REVERSE = "Reverse Control Trap"
BUFF_SHUTDOWN = "Shutdown"
TRAP_SHUT_UP = "SHUT UP FREDDY!!"
TRAP_FOXY = "Foxy Trap"
EFFECT_ITEMS: Tuple[Tuple[str, str, str], ...] = (
    (TRAP_ASTHMA, "trap", "asthma"),
    (BUFF_ENERGY_DRINK, "filler", "energy_drink"),
    (BUFF_CAFFEINE, "filler", "caffeine"),
    (TRAP_RECHARGE, "trap", "recharge"),
    (TRAP_STUN, "trap", "stun"),
    (TRAP_REVERSE, "trap", "reverse"),
    (BUFF_SHUTDOWN, "filler", "shutdown"),
    (TRAP_SHUT_UP, "trap", "shut_up"),
    (TRAP_FOXY, "trap", "foxy"),
)

PROGRESSIVE_FLASHLIGHT = "Progressive Flashlight"
PROGRESSIVE_FREDDY_BATTERY = "Progressive Freddy Battery"

COLLECTIBLE_ITEM_NAMES: Dict[str, str] = {
    "pizzaplex_logo_shirt": "Pizzaplex Logo Shirt", "monty_name_shirt": "Monty Name Shirt",
    "foxy_plush": "Foxy Plush", "chica_pinata": "Chica Piñata", "chica_name_shirt": "Chica Name Shirt",
    "chica_plush": "Chica Plush", "freddy_name_shirt": "Freddy Name Shirt", "sun_plush": "Sun Plush",
    "old_poster_diner1": "Old Poster (Lucky Stars Gift Shop)", "monty_pinata": "Monty Piñata",
    "star_shirt": "Star Shirt", "freddy_magnet": "Freddy Magnet", "roxy_plush": "Roxy Plush",
    "old_poster_diner2": "Old Poster (Cleaning-Bot Room)", "chica_balloon": "Chica Balloon",
    "monty_mask": "Monty Mask", "frozen_freddy_treat": "Frozen Freddy Treat",
    "roxy_balloon": "Roxy Balloon", "roxy_mask": "Roxy Mask", "frozen_roxy_treat": "Frozen Roxy Treat",
    "roxy_name_shirt": "Roxy Name Shirt", "nightmarionne_plush": "Nightmarionne Plush",
    "glam_roxy_figure": "Glam Roxy Figure", "el_chip_pinata": "El Chip Piñata",
    "glam_chica_figure": "Glam Chica Figure", "four_block_shirt": "Four Block Shirt",
    "chica_mask": "Chica Mask", "pinata": "Atrium Piñata", "freddy_pinata": "Freddy Piñata",
    "freddy_keychain": "Freddy Keychain", "chica_keychain": "Chica Keychain",
    "roxy_keychain": "Roxy Keychain", "freddy_balloon": "Freddy Balloon",
    "old_poster_vintage": "Old Poster (Fazer Blast)", "bonnie_plush": "Bonnie Plush",
    "freddy_face_shirt": "Freddy Face Shirt", "old_poster_diner3": "Old Poster (S.T.A.F.F. Silo)",
    "comedy_mask": "Comedy Mask", "frozen_monty_treat": "Frozen Monty Treat",
    "glam_monty_figure": "Glam Monty Figure", "tragedy_mask": "Tragedy Mask", "go_kart": "Go-Kart",
    "baby_plush": "Baby Plush", "glam_freddy_figure": "Glam Freddy Figure", "freddy_mask": "Freddy Mask",
    "frozen_chica_treat": "Frozen Chica Treat", "moon_plush": "Moon Plush",
    "sun_figure": "Sun Figure", "moon_figure": "Moon Figure", "glam_freddy_plush": "Glam Freddy Plush",
    "chica_magnet": "Chica Magnet", "monty_magnet": "Monty Magnet", "roxy_pinata": "Roxy Piñata",
    "monty_keychain": "Monty Keychain", "monty_balloon": "Monty Balloon", "roxy_magnet": "Roxy Magnet",
    "freddy_icon_shirt": "Freddy Icon Shirt", "monty_plush": "Monty Plush",
    "cupcake_pinata": "Cupcake Piñata",
}
assert len(set(COLLECTIBLE_ITEM_NAMES.values())) == len(COLLECTIBLE_ITEM_NAMES), "duplicate filler item name"
assert not set(GOLDEN_PRESENT_KEY) & set(COLLECTIBLE_ITEM_NAMES), "golden key leaked into filler dict"

FILLER_WEIGHTS: Dict[str, int] = {BATTERY: 3, BUFF_ENERGY_DRINK: 2, BUFF_CAFFEINE: 2, BUFF_SHUTDOWN: 1}

VIP_COLLECTIBLES_NEEDED = 39
TRAP_WEIGHTS: Dict[str, int] = {TRAP_DRAIN: 1, TRAP_ALARM: 1, TRAP_ASTHMA: 1, TRAP_RECHARGE: 1,
                                TRAP_STUN: 1, TRAP_REVERSE: 1, TRAP_SHUT_UP: 1, TRAP_FOXY: 1}


@dataclass(frozen=True)
class Area:
    key: str
    name: str
    always_open: bool = False
    dark: bool = False
    badge: int = 0
    passes: Tuple[str, ...] = ()
    start_eligible: bool = False


BADGE_HOLDERS: Tuple[Tuple[str, str, str, str, str], ...] = (
    ("badge_kitchen", "loading_dock", "Kitchen Security Office badge holder",
     "SecurityBadgeKitchen", "LoadingDock"),
    ("badge_prize_counter", "prize_counter", "Security Office badge holder",
     "SecurityBadgePrizeCounter", "PrizeCounter"),
    ("badge_backstage", "backstage", "Security Office badge holder",
     "SecurityBadgeBackstage", "Backstage"),
    ("badge_warehouse", "warehouse", "Security Office badge holder",
     "SecurityBadgeWarehouse", "Warehouse"),
    ("badge_fazerblast", "fazerblast", "Security Office badge holder",
     "SecurityBadgeFazerBlast", "OfficeToOffice"),
    ("badge_monty_golf", "monty_golf", "Security Office badge holder",
     "SecurityBadgeMontyGolf", "MontyGolf"),
    ("badge_west_arcade", "fazcade", "West Arcade Security Office badge holder",
     "SecurityBadgeWestArcade", "MoonlightSerenade"),
)
BADGE_HOLDER_DAYCARE: Tuple[str, str, str, str, str] = (
    "badge_daycare", "daycare", "Security Office badge holder",
    "SecurityBadgeDaycare", "SlideIntoFun",
)
DAYCARE_FLASHLIGHT: Tuple[str, str, str] = (
    "flashlight", "daycare", "Take the flashlight from its recharge station (Let There Be Light)",
)

AREAS: Tuple[Area, ...] = (
    Area("daycare", "Daycare", passes=(DAYCARE_PASS,)),
    Area("atrium", "Main Atrium", always_open=True),

    Area("prize_counter", "Prize Counter", badge=2),
    Area("loading_dock", "Loading Dock", badge=3),
    Area("rockstar_row", "Rockstar Row", badge=4),
    Area("backstage", "Backstage", badge=4, passes=(BACKSTAGE_PASS,), start_eligible=True),
    Area("parts_service", "Parts & Service", badge=5),
    Area("warehouse", "Warehouse", badge=5),

    Area("fazerblast", "Fazer Blast", badge=6, passes=(PARTY_PASS,), start_eligible=True),
    Area("monty_golf", "Monty's Gator Golf", badge=7, passes=(PARTY_PASS,), start_eligible=True),
    Area("bonnie_bowl", "Bonnie Bowl", badge=6, passes=(BOWLING_TICKET,), start_eligible=True),
    Area("mazercise", "Mazercise", badge=7, passes=(MAZERCISE_TICKET, MAZERCISE_KEY)),
    Area("fazcade", "Fazcade", badge=8, passes=(DANCE_PASS,), start_eligible=True),

    Area("roxy_raceway", "Roxy Raceway", start_eligible=True),
    Area("kids_cove", "Kid's Cove", start_eligible=True),
    Area("beauty_salon", "Glamrock Beauty Salon", start_eligible=True),
    Area("fazbear_theater", "Fazbear Theater", badge=4),
    Area("utility_tunnels", "Utility Tunnels", badge=3, dark=True),
)

AREA_BY_KEY: Dict[str, Area] = {a.key: a for a in AREAS}
AREA_BY_NAME: Dict[str, Area] = {a.name: a for a in AREAS}
LOCKABLE_AREAS: Tuple[Area, ...] = tuple(a for a in AREAS if not a.always_open)


@dataclass(frozen=True)
class LocationDef:
    key: str
    name: str
    area: str
    kind: str
    id: int
    requires: Tuple[str, ...] = ()
    hint: str = ""


def _p(key: str, area: str, hint: str, requires: Tuple[str, ...] = ()) -> Tuple[str, str, str, Tuple[str, ...]]:
    return (key, area, hint, requires)

PRESENTS: Tuple[Tuple[str, str, str, Tuple[str, ...]], ...] = (
    _p("faz_watch", "atrium", "Inside Glamrock Freddy's birthday cake hatch"),
    _p("entry_pass", "atrium", "In front of the large Glamrock band cutout at the entrance"),
    _p("daycare_pass", "atrium", "Use the Upgrade Machine with the Entry Pass and the Mr. Hippo Magnet",
       (ENTRY_PASS, MR_HIPPO_MAGNET)),
    _p("mr_hippo_magnet", "atrium", "On the floor of the Main Lobby"),
    _p("photo_pass", "backstage", "Next to the reception desk by Freddy's door"),
    _p("screwdriver", "loading_dock", "On the floor of Lost and Found"),
    _p("backstage_pass", "rockstar_row", "On the far bleachers in the music room"),
    _p("party_pass_a", "rockstar_row", "Glamrock Chica's green room"),
    _p("party_pass_b", "atrium", "Given by Glamrock Freddy after 6 AM"),
    _p("bowling_ticket", "fazerblast", "In the Fazer Blast security office"),
    _p("win_fazerblaster", "fazerblast", "Win the Fazerblaster prize from the Fazer Blast counter"),
    _p("monty_mystery_mix", "bonnie_bowl", "Left corner of the room behind the Ice Cream stand"),
    _p("faz_camera", "monty_golf", "In Monty's Gator Golf security office (Faz-Camera)"),
    _p("mazercise_ticket", "monty_golf", "In Monty's Gator Golf security office (Mazercise Ticket)"),
    _p("mazercise_key", "fazbear_theater", "Back rooms of the Fazbear Theater basement"),
    _p("dance_pass", "roxy_raceway", "In the Roxy Raceway locker room / office"),
    _p("pirate_hippo_machine", "atrium",
       "Insert the Complimentary Entry Pass into the Upgrade Machine",
       (ENTRY_PASS,)),
    _p("fizzy_faz_chica", "prize_counter", "Office right of the entrance turn-gates"),
    _p("fizzy_faz_freddy", "loading_dock", "Control room, Basement Kitchen"),
    _p("fizzy_faz_monty", "fazbear_theater", "El Chip's themed kitchen"),
    _p("fizzy_faz_roxy", "roxy_raceway", "Top of the scaffolding stairs near the save point"),
    _p("shoes", "beauty_salon", "Back room of the Beauty Salon"),
    _p("hoodie", "rockstar_row", "Staff toilet in Chica's Bakery"),
    _p("pizzaplex_logo_shirt", "rockstar_row", "Behind RWQFSFASXC's cutout"),
    _p("monty_name_shirt", "backstage", "Desk in the staff room near the Photo Pass"),
    _p("foxy_plush", "utility_tunnels", "Behind a box"),
    _p("chica_pinata", "prize_counter", "On the floor outside the first security office"),
    _p("chica_name_shirt", "loading_dock", "Under the ladder left of the main elevator"),
    _p("chica_plush", "atrium", "Kitchen in Faz-Pad"),
    _p("freddy_name_shirt", "daycare", "Moon bathroom door, near a Wet Floor Bot"),
    _p("sun_plush", "daycare", "Right of the artificial waterfall"),
    _p("old_poster_diner1", "daycare", "Back of Lucky Stars Gift Shop"),
    _p("monty_pinata", "rockstar_row", "Inside the Party Check-In desk"),
    _p("golden_chica", "loading_dock", "Behind a counter, broken kitchen near the elevator"),
    _p("star_shirt", "loading_dock", "First changing room, basement locker room"),
    _p("freddy_magnet", "loading_dock", "Business area near the B1 catwalks"),
    _p("roxy_plush", "loading_dock", "Closet in the laundry room, B1"),
    _p("old_poster_diner2", "warehouse", "Storage room before the cleaning-bot room"),
    _p("chica_balloon", "fazcade", "Women's bathroom, Superstar-cade"),
    _p("monty_mask", "prize_counter", "Prize Counter shelf near the Monty plushies"),
    _p("frozen_freddy_treat", "prize_counter", "Behind the VIP desk"),
    _p("roxy_balloon", "roxy_raceway", "Cargo container in front of the entrance"),
    _p("roxy_mask", "atrium", "Scaffolding where Glamrock Freddy broke down"),
    _p("frozen_roxy_treat", "atrium", "Same room, behind a generator"),
    _p("roxy_name_shirt", "monty_golf", "Mini-dining area nearby"),
    _p("nightmarionne_plush", "warehouse", "Dead-end kids room"),
    _p("glam_roxy_figure", "parts_service", "Table near Freddy's upgrade pod"),
    _p("el_chip_pinata", "fazbear_theater", "First room in the back hall"),
    _p("glam_chica_figure", "backstage", "First room after the red security doors near the save point"),
    _p("four_block_shirt", "rockstar_row", "Behind Roxy's green room"),
    _p("golden_freddy", "rockstar_row", "Monty's green room, beside the arcade game"),
    _p("chica_mask", "rockstar_row", "Behind Glamrock Chica's green room"),
    _p("pinata", "atrium", "Behind the pizza counter"),
    _p("freddy_pinata", "fazerblast", "Behind the snack counter"),
    _p("freddy_keychain", "fazerblast", "Next to the ride controls, outside the elevator"),
    _p("chica_keychain", "fazerblast", "Men's bathroom"),
    _p("roxy_keychain", "fazerblast", "Security bathroom"),
    _p("freddy_balloon", "fazerblast", "Instructions room with the talking Staff Bot"),
    _p("old_poster_vintage", "fazerblast", "Storage room, red corner, behind the hiding spot"),
    _p("bonnie_plush", "bonnie_bowl", "Next to a rack of bowling balls"),
    _p("golden_monty", "bonnie_bowl", "Behind the food counter, bottom of the stairs"),
    _p("freddy_face_shirt", "loading_dock", "Conveyor belt in the back kitchen"),
    _p("old_poster_diner3", "warehouse", "S.T.A.F.F. Bot silo"),
    _p("comedy_mask", "utility_tunnels", "First left in the tunnels", (BEAK,)),
    _p("frozen_monty_treat", "monty_golf", "Outside, behind cardboard plants"),
    _p("glam_monty_figure", "monty_golf", "Behind the golfing Chica cutout"),
    _p("tragedy_mask", "monty_golf", "House surrounded by a ball pit"),
    _p("go_kart", "monty_golf", "Trailer on Hole 17"),
    _p("baby_plush", "daycare", "Party Room table outside the Daycare"),
    _p("glam_freddy_figure", "daycare", "Another Party Room table outside the Daycare"),
    _p("freddy_mask", "fazbear_theater", "The theatre kitchen"),
    _p("frozen_chica_treat", "fazbear_theater", "Somewhere in the theater"),
    _p("golden_moon", "daycare", "The Daycare Attendant's room"),
    _p("golden_sun", "kids_cove", "The Lighthouse"),
    _p("moon_plush", "kids_cove", "The pirate ship"),
    _p("golden_roxy_plush", "utility_tunnels", "Behind a gate and pillar", (CLAWS,)),
    _p("sun_figure", "utility_tunnels", "Underground projector room", (CLAWS,)),
    _p("moon_figure", "utility_tunnels", "Conveyor belt near a Save Station", (CLAWS,)),
    _p("glam_freddy_plush", "utility_tunnels", "Behind a gate near the start of the game", (CLAWS,)),
    _p("chica_magnet", "fazcade", "One of the karaoke rooms"),
    _p("monty_magnet", "rockstar_row", "Inside Glamrock Chica's Bakery"),
    _p("roxy_pinata", "beauty_salon", "At the Roxy Raceway observatory"),
    _p("monty_keychain", "roxy_raceway", "Information Register"),
    _p("monty_balloon", "roxy_raceway", "The locker room / office"),
    _p("roxy_magnet", "beauty_salon", "The Green Screen area"),
    _p("freddy_icon_shirt", "backstage", "Storage area, next to blue storage containers"),
    _p("monty_plush", "fazcade", "Crates near West Arcade, under the stairs"),
    _p("cupcake_pinata", "atrium", "Front desk near the entrance"),
)

ABILITY_EVENTS: Tuple[Tuple[str, str, str, str], ...] = (
    ("defeat_monty", "monty_golf", "Defeat Monty and take his claws", CLAWS),
    ("defeat_chica", "fazbear_theater", "Defeat Chica and take her beak", BEAK),
    ("repair_roxy", "parts_service", "Repair Roxy and take her eyes", EYES),
)

PRINCESS_QUEST_EVENTS: Tuple[Tuple[str, str, str, str, Tuple[str, ...]], ...] = (
    ("princess_quest_1", "beauty_salon", "Beat the first Princess Quest arcade machine",
     PRINCESS_QUEST_1, (PRINCESS_QUEST_1,)),
    ("princess_quest_2", "fazcade", "Beat the second Princess Quest arcade machine",
     PRINCESS_QUEST_2, (PRINCESS_QUEST_1, PRINCESS_QUEST_2)),
    ("princess_quest_3", "fazerblast",
     "Beat the third Princess Quest arcade machine, in Vanny's hidden room", PRINCESS_QUEST_3,
     (PRINCESS_QUEST_1, PRINCESS_QUEST_2, PRINCESS_QUEST_3)),
)

FLASHLIGHT_UPGRADE_SPOTS: Tuple[Tuple[str, str, str], ...] = (
    ("flashlight_upgrade_daycare", "daycare", "Top of a castle in the back of the Daycare"),
    ("flashlight_upgrade_rehearsal", "fazbear_theater", "Rehearsal room, pitch black"),
    ("flashlight_upgrade_golf", "monty_golf", "Back room of the food stand"),
)
FREDDY_UPGRADE_SPOTS: Tuple[Tuple[str, str, str], ...] = (
    ("freddy_upgrade_raceway", "roxy_raceway", "Last race-car garage, shelf behind the door"),
    ("freddy_upgrade_atrium", "atrium", "Next to the salad shop, on a table"),
)

BAGS: Tuple[Tuple[str, str, str, Tuple[str, ...]], ...] = (
    _p("bag_party_foul", "atrium", "Duffel bag \"Party Foul\": bench in front of Glamrock Freddy's Green Room"),
    _p("bag_food_storage", "atrium", "Duffel bag \"Food Storage\": table in the back of Faz-Pad, found during Freddy's first recharge"),
    _p("bag_easy_money", "atrium", "Duffel bag \"Easy Money\": edge of the fountain near the Golden Freddy statue"),
    _p("bag_ac_inspection", "atrium", "Duffel bag \"AC Inspection\": table in the back of Faz-Pad"),
    _p("bag_hi_dave", "atrium", "Duffel bag \"Hi Dave\": far left bench next to the lockers in Customer Service"),
    _p("bag_night_terrors", "daycare", "Duffel bag \"Night Terrors\": men's bathroom before the Daycare pick-up area"),
    _p("bag_recycled_pizza", "daycare", "Duffel bag \"Recycled Pizza\": through the green door into Slide into Fun"),
    _p("bag_drink_fizzy_faz", "loading_dock", "Duffel bag \"Drink Fizzy Faz!!\": near where Glamrock Chica gives chase into the Pizza Minigame"),
    _p("bag_compactor_instructions", "loading_dock", "Duffel bag \"Compactor Instructions\": next to the trash compactor, kitchen storage"),
    _p("bag_question", "loading_dock", "Duffel bag \"Question\": back of the showers, changing rooms"),
    _p("bag_happening_again", "roxy_raceway", "Duffel bag \"It Is Happening Again\": found in the Roxy Raceway area"),
    _p("bag_understudy", "rockstar_row", "Duffel bag \"Understudy\": staging area, left of the stage"),
    _p("bag_stolen_property", "warehouse", "Duffel bag \"Stolen Property\": opposite the save point/flashlight recharge at the start of the Warehouse section"),
    _p("bag_chica_upgrade", "parts_service", "Duffel bag \"Chica Upgrade\" (maintenance log): next to Glamrock Chica's upgrade picture"),
    _p("bag_monty_upgrade", "parts_service", "Duffel bag \"Monty Upgrade\" (maintenance log): next to Montgomery's upgrade picture"),
    _p("bag_roxy_upgrade", "parts_service", "Duffel bag \"Roxy Upgrade\" (maintenance log): next to Roxy's upgrade picture"),
    _p("bag_night_shift", "fazcade", "Duffel bag \"Night Shift\": small dining booth at the back of the Super Star-cade"),
    _p("bag_behind_the_maze", "monty_golf", "Duffel bag \"Behind the Maze\": Monty's Gator Golf security office"),
    _p("bag_no_flash_photography", "monty_golf", "Duffel bag \"No Flash Photography\": counter of Monty's Gator Grub"),
    _p("bag_cff_maint_log", "rockstar_row", "Duffel bag \"CFF Maint Log\": tool bench outside the security booth for the 3-minute lockdown"),
    _p("bag_chica_report", "rockstar_row", "Duffel bag \"Chica Report\" (area inferred, not individually sourced)"),
    _p("bag_all_staff_meeting", "loading_dock", "Duffel bag \"All Staff Meeting\": Basement 1 hallway, near a vending machine"),
    _p("bag_better_employees", "loading_dock", "Duffel bag \"Better Employees\" (area inferred, not individually sourced)"),
    _p("bag_false_alarm", "loading_dock", "Duffel bag \"False Alarm\" (area inferred, not individually sourced)"),
    _p("bag_bbw_maint_log", "daycare", "Duffel bag \"BBW Maint Log\": Daycare Theatre"),
    _p("bag_job_security", "mazercise", "Duffel bag \"Job Security\": inside the Mazercise control room"),
    _p("bag_out_of_order", "fazcade", "Duffel bag \"Out Of Order\": the Fazcade near the Daycare"),
    _p("bag_pink_slip", "loading_dock", "Duffel bag \"Pink Slip\": Loading Dock cafeteria"),
    _p("bag_red_flag", "parts_service", "Duffel bag \"Red Flag\" (area inferred, not individually sourced)"),
    _p("bag_the_answer", "daycare", "Duffel bag \"The Answer\": Daycare Theatre"),
    _p("bag_pq2_maint_log", "fazcade", "Duffel bag \"PQ2 Maint Log\" (near the Princess Quest 2 cabinet, now sourced -- see ENDINGS' Canon ending)"),
    _p("bag_missing", "kids_cove", "Duffel bag \"Missing\" (area inferred, not individually sourced)"),
    _p("bag_power_drain", "utility_tunnels", "Duffel bag \"Power Drain\" (area inferred, not individually sourced)"),
    _p("bag_old_elevator", "loading_dock", "Duffel bag \"Old Elevator\" (area inferred, not individually sourced)"),
    _p("bag_re_theme", "rockstar_row", "Duffel bag \"Re-Theme\" (area inferred, not individually sourced)"),
    _p("bag_sinkhole", "warehouse", "Duffel bag \"Sinkhole\" (area inferred, not individually sourced)"),
    _p("bag_sore_winner", "bonnie_bowl", "Duffel bag \"Sore Winner\" (area inferred, not individually sourced)"),
    _p("bag_test_drivers_wanted", "roxy_raceway", "Duffel bag \"Test Drivers Wanted\" (area inferred, not individually sourced)"),
    _p("bag_ultimate_party_host", "rockstar_row", "Duffel bag \"Ultimate Party Host\" (area inferred, not individually sourced)"),
    _p("bag_arcade_conspiracy", "daycare", "Duffel bag \"Arcade Conspiracy\": the Daycare Attendant's room"),
    _p("bag_arcade_maint_log", "atrium", "Duffel bag \"Ar-cade Maint Log\" (area inferred, not individually sourced)"),
    _p("bag_hide_the_mix", "fazerblast", "Duffel bag \"Hide the mix\": Fazer Blast security office"),
    _p("bag_no_questions_asked", "fazerblast", "Duffel bag \"No Questions Asked\": on the way to Vanny's room from the winner's elevator"),
    _p("bag_pq1_maint_log", "beauty_salon", "Duffel bag \"PQ1 Maint Log\" (near the Princess Quest 1 cabinet, now sourced -- see ENDINGS' Canon ending)"),
    _p("bag_safety_check", "utility_tunnels", "Duffel bag \"Safety Check\" (area inferred, not individually sourced)"),
    _p("bag_marked_for_deletion", "utility_tunnels", "Duffel bag \"Marked For Deletion\" (area inferred, not individually sourced)"),
    _p("bag_torn_paper", "utility_tunnels", "Duffel bag \"Torn Paper\" (area inferred, not individually sourced)", (BEAK, CLAWS)),
    _p("bag_monty_mischief", "monty_golf", "Duffel bag \"Monty Mischief\": Monty's Room (story-related message)"),
    _p("bag_chasing_cars", "roxy_raceway", "Duffel bag \"Chasing Cars\": Roxy Raceway (story-related message)"),
)

RETIRED_LOCATION_KEYS = frozenset({"daycare.complete_area"})

COMPLETE_EVENTS: Tuple[Tuple[str, str, str], ...] = (
    ("complete_area", "daycare", "Take the wooden door out after finishing the Daycare"),
    ("escape_chica_chase", "loading_dock", "Escape Glamrock Chica's chase into the Pizza Minigame"),
    ("survive_lockdown", "rockstar_row", "Survive the Security Office's 3-minute lockdown"),
)

STORY_EVENTS: Tuple[Tuple[str, str, str], ...] = (
    ("freddy_lockdown_cutscene", "atrium", "Witness Freddy's \"you're supposed to be on lockdown\" dialogue"),
)


@dataclass(frozen=True)
class MissionDef:
    internal: str
    display: str
    area: str
    extra_areas: Tuple[str, ...] = ()
    requires: Tuple[str, ...] = ()
    deps: Tuple[str, ...] = ()


MISSIONS: Tuple[MissionDef, ...] = (
    MissionDef("FreeFreddy", "Free Freddy", "atrium"),
    MissionDef("GetOut", "Get Out", "atrium", deps=("FreeFreddy",)),
    MissionDef("NoReEntry", "No Re-entry", "daycare", requires=(ENTRY_PASS, MR_HIPPO_MAGNET),
               deps=("GetOut",)),
    MissionDef("SlideIntoFun", "Slide Into Fun", "daycare", deps=("NoReEntry",)),
    MissionDef("LetThereBeLight", "Let There Be Light", "daycare", requires=(PROGRESSIVE_FLASHLIGHT,),
               deps=("SlideIntoFun",)),
    MissionDef("EscapeDaycare", "Escape The Daycare", "daycare", deps=("LetThereBeLight",)),
    MissionDef("TakeMap", "Free Map", "atrium", deps=("EscapeDaycare",)),
    MissionDef("KitchenOffice", "Kitchen Office", "loading_dock", deps=("EscapeDaycare",)),
    MissionDef("LoadingDock", "Loading Dock", "loading_dock", deps=("EscapeDaycare",)),
    MissionDef("PrizeCounter", "Prize Counter", "prize_counter", deps=("EscapeDaycare",)),
    MissionDef("FindFreddy", "Find Freddy", "prize_counter", deps=("PrizeCounter",)),
    MissionDef("LostAndFound", "Lost And Found", "loading_dock", deps=("FindFreddy", "LoadingDock")),
    MissionDef("RehearsalSpace", "Rehearsal Space", "rockstar_row", deps=("LostAndFound",)),
    MissionDef("Backstage", "Backstage", "backstage", requires=(BACKSTAGE_PASS,),
               deps=("RehearsalSpace",)),
    MissionDef("Showtime", "Showtime", "atrium", deps=("Backstage",)),
    MissionDef("PartsAndService", "Parts and Service", "parts_service", deps=("Showtime",)),
    MissionDef("Warehouse", "Warehouse", "warehouse", ("parts_service",), deps=("Showtime",)),
    MissionDef("PartyPass", "Party Pass", "rockstar_row", deps=("PartsAndService",)),
    MissionDef("MoonlightSerenade", "Moonlight Serenade", "rockstar_row", deps=("PartyPass",)),
    MissionDef("MontyGolf", "Monty Golf", "monty_golf", requires=(PARTY_PASS,),
               deps=("PartsAndService",)),
    MissionDef("FazerBlast", "Fazer Blast", "fazerblast", requires=(PARTY_PASS,),
               deps=("PartsAndService",)),
    MissionDef("OfficeToOffice", "Office to Office", "fazerblast", requires=(PARTY_PASS,),
               deps=("PartsAndService",)),
    MissionDef("ThrillSeeker", "Thrill Seeker", "monty_golf", ("mazercise", "parts_service"),
               requires=(MAZERCISE_TICKET, MAZERCISE_KEY), deps=("MoonlightSerenade",)),
    MissionDef("MontyClaws", "Monty's Claws", "monty_golf", deps=("MoonlightSerenade",)),
    MissionDef("MontyMysteryMix", "Monty Mystery Mix", "bonnie_bowl", ("loading_dock",),
               requires=(MONTY_MYSTERY_MIX,), deps=("MoonlightSerenade",)),
    MissionDef("PowerOn", "Power On", "loading_dock", deps=("MoonlightSerenade",)),
    MissionDef("DumpsterDiving", "Dumpster Diving", "loading_dock", ("parts_service",),
               requires=(MONTY_MYSTERY_MIX,), deps=("MoonlightSerenade", "PowerOn")),
    MissionDef("ChicaBeak", "Chica's Beak", "warehouse", ("utility_tunnels",),
               requires=(PROGRESSIVE_FLASHLIGHT,), deps=("MoonlightSerenade",)),
    MissionDef("RoxysWeakness", "Roxy's Weakness", "roxy_raceway", deps=("MoonlightSerenade",)),
    MissionDef("DJMusicMan", "Repair Robot Head", "fazcade", ("roxy_raceway",),
               requires=(DANCE_PASS,), deps=("RoxysWeakness",)),
    MissionDef("StopRoxy", "Stop Roxy", "roxy_raceway", deps=("DJMusicMan",)),
    MissionDef("UpgradeFreddy", "Upgrade Freddy", "parts_service", ("roxy_raceway",),
               deps=("StopRoxy",)),
)
MISSION_BY_INTERNAL: Dict[str, MissionDef] = {m.internal: m for m in MISSIONS}

AREA_STORY_GATE: Dict[str, str] = {
    "prize_counter": "EscapeDaycare", "loading_dock": "EscapeDaycare",
    "rockstar_row": "EscapeDaycare", "utility_tunnels": "EscapeDaycare",
    "roxy_raceway": "LostAndFound", "kids_cove": "LostAndFound",
    "beauty_salon": "LostAndFound", "fazbear_theater": "LostAndFound",
    "backstage": "RehearsalSpace",
    "parts_service": "Showtime", "warehouse": "Showtime",
    "fazerblast": "PartsAndService", "monty_golf": "PartsAndService",
    "bonnie_bowl": "PartsAndService", "mazercise": "PartsAndService", "fazcade": "PartsAndService",
}

FREDDY_INSTALL_EVENTS: Tuple[Tuple[str, str, str, Tuple[str, ...]], ...] = (
    ("upgrade_freddy_claws", "parts_service", "Upgrade Freddy with Monty's Claws", (CLAWS,)),
    ("upgrade_freddy_beak", "parts_service", "Upgrade Freddy with Chica's Voice Box", (BEAK,)),
)

LOCATION_MISSION_GATE: Dict[str, str] = {
    "atrium.party_pass_b": "MoonlightSerenade",
    "rockstar_row.party_pass_a": "PartsAndService",
    "parts_service.upgrade_freddy_claws": "MoonlightSerenade",
    "parts_service.upgrade_freddy_beak": "MoonlightSerenade",
    "monty_golf.defeat_monty": "ThrillSeeker",
    "fazbear_theater.defeat_chica": "DumpsterDiving",
    "parts_service.repair_roxy": "UpgradeFreddy",
    "fazerblast.win_fazerblaster": "FazerBlast",
    "fazerblast.princess_quest_3": "FazerBlast",
    "daycare.complete_area": "EscapeDaycare",
    "loading_dock.escape_chica_chase": "LoadingDock",
    **{f"{area}.{key}": mission for key, area, _, _, mission in BADGE_HOLDERS + (BADGE_HOLDER_DAYCARE,)},
}

ENTRANCE_REGION = "Main Entrance"
ATRIUM_BADGE = 1
ENTRANCE_LOCATION_KEYS = frozenset({
    "atrium.faz_watch",
    "atrium.entry_pass",
    "atrium.mr_hippo_magnet",
    "atrium.daycare_pass",
    "atrium.pirate_hippo_machine",
    "atrium.cupcake_pinata",
    "atrium.bag_easy_money",
    "atrium.bag_hi_dave",
    "atrium.chica_plush",
    "atrium.bag_ac_inspection",
    "atrium.mission_free_freddy",
    "atrium.mission_get_out",
    "atrium.hour_0",
})
DAYCARE_MISSIONS = frozenset({"NoReEntry", "SlideIntoFun", "LetThereBeLight", "EscapeDaycare"})
BEFORE_ATRIUM_MISSIONS = DAYCARE_MISSIONS | {"FreeFreddy", "GetOut"}

LOCATION_EXTRA_NEEDS: Dict[str, Tuple[Tuple[str, ...], Tuple[str, ...], Tuple[str, ...]]] = {
    "atrium.chica_plush": ((), (ENTRY_PASS,), ()),
    "atrium.bag_ac_inspection": ((), (ENTRY_PASS,), ()),
    "atrium.pinata": ((), (ENTRY_PASS,), ()),
    "atrium.freddy_upgrade_atrium": (("LoadingDock",), (), ()),
    "atrium.roxy_mask": (("Showtime",), (), ("roxy_raceway",)),
    "atrium.frozen_roxy_treat": (("Showtime",), (), ("roxy_raceway",)),
    "atrium.bag_food_storage": ((), (), ("utility_tunnels",)),
    "atrium.bag_arcade_maint_log": ((), (), ("rockstar_row",)),
    "atrium.bag_party_foul": ((), (), ("rockstar_row",)),
}

HOURS: Tuple[Tuple[int, str, Tuple[str, ...]], ...] = (
    (0, "12 AM", ("GetOut",)),
    (1, "1 AM", ("LostAndFound",)),
    (2, "2 AM", ("Showtime",)),
    (3, "3 AM", ("PartsAndService",)),
    (4, "4 AM", ("MoonlightSerenade",)),
    (5, "5 AM", ("MoonlightSerenade",)),
    (6, "6 AM", ("MoonlightSerenade",)),
)
SIX_AM_MISSIONS: Tuple[str, ...] = HOURS[-1][2]

COLLECTIBLE_PRESENT_KEYS = frozenset(COLLECTIBLE_ITEM_NAMES)


def _snake(name: str) -> str:
    out = ""
    for i, c in enumerate(name):
        if c.isupper() and i and not name[i - 1].isupper():
            out += "_"
        out += c.lower()
    return out


def mission_closure(missions: Tuple[str, ...]) -> Tuple[frozenset, frozenset]:
    """Every area that must be open and every item that must be held for all `missions` to be done: their own areas/items, their deps', and the story gate of each area involved."""
    areas: set = set()
    items: set = set()
    seen: set = set()

    def visit(name: str, stack: Tuple[str, ...]) -> None:
        if name in stack:
            raise ValueError(f"mission cycle: {' -> '.join(stack + (name,))}")
        if name in seen:
            return
        seen.add(name)
        m = MISSION_BY_INTERNAL[name]
        items.update(m.requires)
        for area in (m.area,) + m.extra_areas:
            areas.add(area)
            gate = AREA_STORY_GATE.get(area)
            if gate:
                visit(gate, stack + (name,))
        for dep in m.deps:
            visit(dep, stack + (name,))

    for name in missions:
        visit(name, ())
    return frozenset(areas), frozenset(items)


def missions_need_atrium(missions: Tuple[str, ...]) -> bool:
    """Does finishing `missions` (with their deps) take the player past the Daycare, into the Main Atrium?"""
    seen: set = set()

    def visit(name: str) -> None:
        if name in seen:
            return
        seen.add(name)
        m = MISSION_BY_INTERNAL[name]
        for area in (m.area,) + m.extra_areas:
            gate = AREA_STORY_GATE.get(area)
            if gate:
                visit(gate)
        for dep in m.deps:
            visit(dep)

    for name in missions:
        visit(name)
    return bool(seen - BEFORE_ATRIUM_MISSIONS)


def _build_locations() -> List[LocationDef]:
    return [replace(loc, name=LOCATION_NAMES.get(loc.key, loc.name)) for loc in _build_raw_locations()]


def _build_raw_locations() -> List[LocationDef]:
    out: List[LocationDef] = []
    next_id = LOCATION_BASE_ID
    for key, area, hint, requires in PRESENTS:
        area_name = AREA_BY_KEY[area].name
        out.append(LocationDef(f"{area}.{key}", f"{area_name}: {hint}", area, "present", next_id, requires, hint))
        next_id += 1
    for key, area, hint, _ in ABILITY_EVENTS:
        area_name = AREA_BY_KEY[area].name
        out.append(LocationDef(f"{area}.{key}", f"{area_name}: {hint}", area, "ability", next_id, (), hint))
        next_id += 1
    for key, area, hint, _, requires in PRINCESS_QUEST_EVENTS:
        area_name = AREA_BY_KEY[area].name
        out.append(LocationDef(f"{area}.{key}", f"{area_name}: {hint}", area, "arcade", next_id, requires, hint))
        next_id += 1
    for key, area, hint in FLASHLIGHT_UPGRADE_SPOTS:
        area_name = AREA_BY_KEY[area].name
        out.append(LocationDef(f"{area}.{key}", f"{area_name}: {hint}", area, "flashlight_upgrade", next_id, (), hint))
        next_id += 1
    for key, area, hint in FREDDY_UPGRADE_SPOTS:
        area_name = AREA_BY_KEY[area].name
        out.append(LocationDef(f"{area}.{key}", f"{area_name}: {hint}", area, "freddy_upgrade", next_id, (), hint))
        next_id += 1
    for key, area, hint, _, _ in BADGE_HOLDERS:
        out.append(LocationDef(f"{area}.{key}", f"{AREA_BY_KEY[area].name}: {hint}",
                               area, "badge", next_id, (), hint))
        next_id += 1
    for key, area, hint, requires in BAGS:
        area_name = AREA_BY_KEY[area].name
        out.append(LocationDef(f"{area}.{key}", f"{area_name}: {hint}", area, "bag", next_id, requires, hint))
        next_id += 1
    for key, area, hint in COMPLETE_EVENTS:
        area_name = AREA_BY_KEY[area].name
        out.append(LocationDef(f"{area}.{key}", f"{area_name}: {hint}", area, "complete", next_id, (), hint))
        next_id += 1
    for key, area, hint in STORY_EVENTS:
        area_name = AREA_BY_KEY[area].name
        out.append(LocationDef(f"{area}.{key}", f"{area_name}: {hint}", area, "story", next_id, (), hint))
        next_id += 1
    for m in MISSIONS:
        out.append(LocationDef(f"{m.area}.mission_{_snake(m.internal)}", f"Mission: {m.display}",
                               m.area, "mission", next_id, (), m.internal))
        next_id += 1
    for hour, label, _ in HOURS:
        out.append(LocationDef(f"atrium.hour_{hour}", f"Clock: {label}", "atrium", "hour", next_id,
                               (), str(hour)))
        next_id += 1
    key, area, hint, _, _ = BADGE_HOLDER_DAYCARE
    out.append(LocationDef(f"{area}.{key}", f"{AREA_BY_KEY[area].name}: {hint}",
                           area, "badge", next_id, (), hint))
    next_id += 1
    key, area, hint = DAYCARE_FLASHLIGHT
    out.append(LocationDef(f"{area}.{key}", f"{AREA_BY_KEY[area].name}: {hint}",
                           area, "story", next_id, (), hint))
    next_id += 1
    for key, area, hint, requires in FREDDY_INSTALL_EVENTS:
        out.append(LocationDef(f"{area}.{key}", f"{AREA_BY_KEY[area].name}: {hint}",
                               area, "ability", next_id, requires, hint))
        next_id += 1
    return out


LOCATIONS: Tuple[LocationDef, ...] = tuple(_build_locations())
LOCATION_NAME_TO_ID: Dict[str, int] = {loc.name: loc.id for loc in LOCATIONS}
LOCATION_BY_KEY: Dict[str, LocationDef] = {loc.key: loc for loc in LOCATIONS}
BADGE_LOCATION_BY_ITEM: Dict[str, str] = {
    game_item: f"{area}.{key}" for key, area, _, game_item, _ in BADGE_HOLDERS + (BADGE_HOLDER_DAYCARE,)
}


@dataclass(frozen=True)
class Ending:
    goal_id: int
    key: str
    area: str
    name: str
    hint: str
    badge: int = 0
    abilities: Tuple[str, ...] = ()
    needs_camera: bool = False
    needs_goldens: bool = False
    needs_items: Tuple[str, ...] = ()
    missions: Tuple[str, ...] = SIX_AM_MISSIONS
    collectibles: int = 0


ENDINGS: Tuple[Ending, ...] = (
    Ending(0, "leave", "atrium", "Leave the Pizzaplex Alone (Bad Ending)",
           "6 AM: choose Leave at the main Lobby entrance", badge=2),
    Ending(1, "loading_dock", "loading_dock", "Escape via the Loading Dock with Freddy (Good Ending)",
           "6 AM: choose Stay, reach Security Badge 7, then Leave through the Loading Dock", badge=7),
    Ending(2, "rooftop", "fazerblast", "Confront Vanny on the Rooftop (Disassembled Ending)",
           "6 AM: choose Stay, win the Fazer Blast game, find Vanny through the vent",
           missions=SIX_AM_MISSIONS + ("FazerBlast",)),
    Ending(3, "afton", "roxy_raceway", "Defeat Springtrap (Afton Ending)",
           "6 AM: choose Stay with all 3 of Freddy's abilities, take the sealed door in Roxy Raceway",
           badge=8, abilities=(CLAWS, BEAK, EYES)),
    Ending(4, "unmasked", "roxy_raceway", "Find All Six Golden Plushies (Unmasked Ending)",
           "6 AM: choose Stay with all 3 abilities, the Faz-Camera, and all 6 Golden Plush toys",
           badge=8, abilities=(CLAWS, BEAK, EYES), needs_camera=True, needs_goldens=True,
           collectibles=VIP_COLLECTIBLES_NEEDED),
    Ending(5, "canon", "fazerblast", "Save Vanessa (Canon Ending)",
           "6 AM: choose Stay, win the Fazerblaster, then all 3 Princess Quest machines in order",
           needs_items=(FAZERBLASTER, PRINCESS_QUEST_1, PRINCESS_QUEST_2, PRINCESS_QUEST_3),
           missions=SIX_AM_MISSIONS + ("FazerBlast",)),
)
ENDING_BY_GOAL: Dict[int, Ending] = {e.goal_id: e for e in ENDINGS}


@dataclass(frozen=True)
class ItemDef:
    name: str
    id: int
    classification: str
    count: int
    kind: str
    param: str = ""


def _build_items() -> List[ItemDef]:
    items: List[ItemDef] = []
    next_id = ITEM_BASE_ID

    items.append(ItemDef(BADGE, next_id, "progression", MAX_BADGE_LEVEL, "badge")); next_id += 1
    items.append(ItemDef(FLASHLIGHT, next_id, "progression", 0, "gadget", "flashlight")); next_id += 1
    items.append(ItemDef(FAZ_CAM, next_id, "progression", 1, "gadget", "faz_cam")); next_id += 1
    items.append(ItemDef(FAZ_WATCH, next_id, "progression", 1, "gadget", "faz_watch")); next_id += 1
    items.append(ItemDef(SCREWDRIVER, next_id, "progression", 1, "gadget", "screwdriver")); next_id += 1

    items.append(ItemDef(PROGRESSIVE_FLASHLIGHT, next_id, "progression", 1 + len(FLASHLIGHT_UPGRADE_SPOTS),
                          "progressive", "flashlight_battery")); next_id += 1
    items.append(ItemDef(PROGRESSIVE_FREDDY_BATTERY, next_id, "useful", len(FREDDY_UPGRADE_SPOTS),
                          "progressive", "freddy_battery")); next_id += 1

    for ability, param in ((CLAWS, "claws"), (BEAK, "beak"), (EYES, "eyes")):
        items.append(ItemDef(ability, next_id, "progression", 1, "ability", param)); next_id += 1

    for golden in GOLDEN_ITEMS:
        items.append(ItemDef(golden, next_id, "progression", 1, "golden")); next_id += 1

    items.append(ItemDef(FAZERBLASTER, next_id, "progression", 1, "collectible")); next_id += 1
    for pq in (PRINCESS_QUEST_1, PRINCESS_QUEST_2, PRINCESS_QUEST_3):
        items.append(ItemDef(pq, next_id, "progression", 1, "arcade")); next_id += 1

    for pass_name, count in ((BACKSTAGE_PASS, 1), (PARTY_PASS, 2), (BOWLING_TICKET, 1),
                              (DANCE_PASS, 1), (MAZERCISE_TICKET, 1), (MAZERCISE_KEY, 1)):
        items.append(ItemDef(pass_name, next_id, "progression", count, "pass")); next_id += 1

    items.append(ItemDef(DAYCARE_PASS, next_id, "progression", 1, "pass")); next_id += 1

    for flavor, classification in ((ENTRY_PASS, "progression"), (PHOTO_PASS, "useful")):
        items.append(ItemDef(flavor, next_id, classification, 1, "collectible")); next_id += 1

    items.append(ItemDef(MR_HIPPO_MAGNET, next_id, "progression", 1, "collectible")); next_id += 1

    for name in COLLECTIBLE_ITEM_NAMES.values():
        items.append(ItemDef(name, next_id, "progression", 1, "collectible")); next_id += 1

    items.append(ItemDef(TOKENS_SMALL, next_id, "filler", 0, "tokens", "50")); next_id += 1
    items.append(ItemDef(TOKENS_LARGE, next_id, "filler", 0, "tokens", "200")); next_id += 1
    items.append(ItemDef(BATTERY, next_id, "filler", 0, "battery", "1")); next_id += 1
    items.append(ItemDef(TRAP_DRAIN, next_id, "trap", 0, "trap", "power_drain")); next_id += 1
    items.append(ItemDef(TRAP_ALARM, next_id, "trap", 0, "trap", "alarm")); next_id += 1

    items.append(ItemDef(MONTY_MYSTERY_MIX, next_id, "progression", 1, "collectible",
                         "MontyMysteryMix")); next_id += 1
    for name, internal in CAMERA_ITEMS:
        items.append(ItemDef(name, next_id, "progression", 1, "camera", internal)); next_id += 1
    for name, internal, count in EXTRA_COLLECTIBLE_ITEMS:
        items.append(ItemDef(name, next_id, "useful", count, "collectible", internal)); next_id += 1
    for name, internal, count in RETRO_CDS:
        items.append(ItemDef(name, next_id, "filler", count, "collectible", internal)); next_id += 1
    for name, classification, effect in EFFECT_ITEMS:
        items.append(ItemDef(name, next_id, classification, 0, "effect", effect)); next_id += 1
    return items


RETRO_CDS: Tuple[Tuple[str, str, int], ...] = tuple(
    (f"Retro CD {n + 1}", f"RetroCDCollectible_{n}", 1) for n in range(16)
)

CAMERA_ITEMS: Tuple[Tuple[str, str], ...] = (
    ("Pizzaplex Cameras", "CamerasOffice_Intro"),
    ("Daycare Cameras", "CamerasOffice_Daycare"),
    ("Kitchen Cameras", "CamerasOffice_Kitchen"),
    ("Prize Counter Cameras", "CamerasOffice_PrizeCounter"),
    ("Backstage Cameras", "CamerasOffice_Backstage"),
    ("Gator Golf Cameras", "CamerasOffice_GatorGolf"),
    ("Office 6 Cameras", "CamerasOffice_WestArcade"),
    ("Office 7 Cameras", "CamerasOffice_7"),
    ("Office 8 Cameras", "CamerasOffice_8"),
)

EXTRA_COLLECTIBLE_ITEMS: Tuple[Tuple[str, str, int], ...] = (
    ("Fizzy Faz - Roxy", "GregoryUpgrade_Stamina_0", 1),
    ("Fizzy Faz - Chica", "GregoryUpgrade_Stamina_1", 1),
    ("Fizzy Faz - Freddy", "GregoryUpgrade_Stamina_2", 1),
    ("Fizzy Faz - Monty", "GregoryUpgrade_Stamina_3", 1),
    ("Shoes", "GregoryUpgrade_Shoes", 1),
    ("Hoodie", "GregoryUpgrade_Stealth", 1),
)

EXTRA_PROGRESSION_SHARE = 0.65
EXTRA_ITEM_NAMES: Tuple[str, ...] = (tuple(n for n, _ in CAMERA_ITEMS)
                                     + tuple(COLLECTIBLE_ITEM_NAMES.values())
                                     + tuple(n for n, _, _ in EXTRA_COLLECTIBLE_ITEMS))


ITEMS: Tuple[ItemDef, ...] = tuple(_build_items())
ITEM_BY_NAME: Dict[str, ItemDef] = {i.name: i for i in ITEMS}
ITEM_NAME_TO_ID: Dict[str, int] = {i.name: i.id for i in ITEMS}

VANILLA_BADGE_KEYS: Tuple[str, ...] = tuple(loc.key for loc in LOCATIONS if loc.kind == "badge")
VANILLA_ABILITY_KEYS: Dict[str, str] = {
    "monty_golf.defeat_monty": CLAWS,
    "fazbear_theater.defeat_chica": BEAK,
    "parts_service.repair_roxy": EYES,
}
PRINCESS_QUEST_ITEMS: Tuple[str, ...] = (PRINCESS_QUEST_1, PRINCESS_QUEST_2, PRINCESS_QUEST_3)
