"""Player options for the FNaF Security Breach world."""
from dataclasses import dataclass
from typing import Dict

from Options import Choice, DefaultOnToggle, OptionDict, OptionGroup, PerGameCommonOptions, Range

from .data import FILLER_WEIGHTS, TRAP_WEIGHTS


class Goal(Choice):
    """Determines which ending you need to reach to complete your goal. The other endings do
    not count. Every ending requires surviving until 6 AM.

    - Leave: At 6 AM, leave the Pizzaplex through the Main Entrance.
    - Loading Dock: Stay after 6 AM, reach Security Badge level 7 and escape with Freddy
      through the Loading Dock.
    - Rooftop: Stay after 6 AM, win Fazer Blast and confront Vanny on the rooftop.
    - Afton: Stay after 6 AM with Security Badge level 8 and Monty's Claws, Chica's Beak and
      Roxy's Eyes installed on Freddy, then defeat Springtrap behind the sealed door in Roxy
      Raceway.
    - Unmasked: The Afton requirements, plus the Faz-Camera, the 6 Golden Plushies and 39 other
      collectibles. Requires Present Sanity enabled or Bag Sanity not set to Off.
    - Canon: Stay after 6 AM, win the Fazerblaster, then beat the 3 Princess Quest arcade
      machines in order.
    """
    display_name = "Goal"
    option_leave = 0
    option_loading_dock = 1
    option_rooftop = 2
    option_afton = 3
    option_unmasked = 4
    option_canon = 5
    default = 0


class PresentSanity(DefaultOnToggle):
    """Adds the 59 collectible presents (plushies, shirts, masks, balloons, posters...) as
    locations. If disabled, they give their vanilla prize.

    Presents holding a key item (passes, gadgets, Fizzy Faz...), Golden Plushies, upgrade
    stations, badge holders, missions and clock hours are always locations.
    """
    display_name = "Present Sanity"


class BagSanity(Choice):
    """Adds the 49 duffel bags (Faz-Watch messages) as locations.

    - Off: Bags are not locations.
    - No Progression: Bags are locations but never hold progression items.
    - On: Bags are locations and can hold any item.
    """
    display_name = "Bag Sanity"
    option_off = 0
    option_no_progression = 1
    option_on = 2
    alias_excluded = 0
    alias_included = 2
    default = 2


class RandomizeSecurityBadges(DefaultOnToggle):
    """Shuffles the 8 Security Badges into the item pool. If disabled, each badge holder
    gives its vanilla badge.

    You start with no Security Badge either way. The Main Atrium needs level 2 when the badges
    are shuffled, so you can always get back out of Chica's kitchen or El Chip's, and level 1
    when they are not. It also needs the Screwdriver, for the Lost and Found that comes after.
    """
    display_name = "Randomize Security Badges"


class RandomizeFreddysAbilities(DefaultOnToggle):
    """Shuffles Monty's Claws, Chica's Beak and Roxy's Eyes into the item pool. If disabled,
    they are obtained as in the vanilla game: defeating Monty gives the Claws, defeating Chica
    gives the Beak and repairing Roxy gives the Eyes.
    """
    display_name = "Randomize Freddy's Abilities"


class RandomizeCameras(DefaultOnToggle):
    """Shuffles the 9 security camera items (one per Security Office) into the item pool. If
    disabled, you start with all of them.
    """
    display_name = "Randomize Cameras"


class LockPrincessQuest(DefaultOnToggle):
    """Locks each of the 3 Princess Quest arcade machines until you receive its item
    (Princess Quest I, II or III). If disabled, you start with the 3 items. The machines must
    still be beaten in order.
    """
    display_name = "Lock Princess Quest"


class StartingAreas(Range):
    """Number of area passes you start with, picked at random from:

    - Backstage Pass (Backstage)
    - Party Pass (Fazer Blast and Monty Golf, the logic also wants the 2nd one)
    - Bowling Ticket (Bonnie Bowl)
    - Dance Pass (Fazcade)

    The required Security Badge level and story progress still apply. You always start with
    the Faz-Watch and the Photo Pass.

    If you don't start with the Backstage Pass, it can be anywhere in the multiworld, but always in the
    late early spheres (not sphere 1), since most of the game is behind it.
    """
    display_name = "Starting Area Passes"
    range_start = 0
    range_end = 5
    default = 1


class TrapPercentage(Range):
    """Percentage of filler items replaced by traps. 0 disables traps."""
    display_name = "Trap Percentage"
    range_start = 0
    range_end = 100
    default = 10


try:
    from Options import OptionCounter as _Counter
except ImportError:
    _Counter = OptionDict


class _Weights(_Counter):
    """Shared checks for Filler Weights and Trap Weights (whole numbers, 0 or more)."""
    min = 0

    def verify(self, world, player_name, plando_options) -> None:
        super().verify(world, player_name, plando_options)
        for key, value in self.value.items():
            if not isinstance(value, int) or isinstance(value, bool) or value < 0:
                raise ValueError(f"{self.display_name} ({player_name}): \"{key}\" must be a whole "
                                 f"number, 0 or more (got {value!r}).")


class FillerWeights(_Weights):
    """Weight of each filler item. A higher weight makes the item more common, 0 removes it.

    - Battery Refill: Fully refills the battery in use: Freddy's while inside him, otherwise
      the flashlight's.
    - Energy Drink: Stamina does not drain for 45 seconds.
    - Caffeine: Gregory moves 15% faster for 90 seconds.
    - Shutdown: Stuns the animatronics within 25 meters for 60 seconds.

    An item missing from the list counts as 0. If every weight is 0, only Battery Refills
    are used.
    """
    display_name = "Filler Weights"
    valid_keys = frozenset(FILLER_WEIGHTS)
    default = dict(FILLER_WEIGHTS)


class TrapWeights(_Weights):
    """Weight of each trap, used when Trap Percentage is above 0. A higher weight makes the
    trap more common, 0 removes it.

    - Battery Trap: Drains half of the battery in use.
    - Security Alert: A Staff Bot sounds the alarm on Gregory.
    - Asthma Trap: Stamina does not refill for 10 seconds.
    - Busy Freddy Trap: Freddy cannot be called for 50 seconds.
    - Stun Trap: Gregory cannot move for 5 seconds.
    - Reverse Control Trap: Movement directions are swapped for 15 seconds.
    - SHUT UP FREDDY!!: Freddy plays random voice lines for 90 seconds.
    - Foxy Trap: Foxy jumpscares the screen.

    A trap missing from the list counts as 0. If every weight is 0, no traps are used.
    """
    display_name = "Trap Weights"
    valid_keys = frozenset(TRAP_WEIGHTS)
    default = dict(TRAP_WEIGHTS)


class FNaFSBDeathLink(Choice):
    """When you die, everyone with Death Link enabled dies. When someone else dies, Gregory
    gets the selected punishment.

    - Disabled: Death Link is off.
    - Random Without Staff Bot: A random animatronic from the list below.
    - Random With Staff Bot: A random animatronic or the Staff Bot.
    - Staff Bot: A Staff Bot sounds the alarm and nearby animatronics come for Gregory. Not
      lethal by itself.
    - Chica, Roxy, Monty, Vanny, Vanessa, Moon, Endos, Freddy: That animatronic jumpscares
      Gregory and he goes back to his last save. If it cannot appear at that moment, another
      one is used.

    Vanny and Freddy are never picked by the random modes. The mode can also be changed in
    game from the pause menu until the game is closed.
    """
    display_name = "Death Link"
    option_disabled = 0
    option_random_without_staff_bot = 1
    option_random_with_staff_bot = 2
    option_staff_bot = 3
    option_chica = 4
    option_roxy = 5
    option_monty = 6
    option_vanny = 7
    option_vanessa = 8
    option_moon = 9
    option_endos = 10
    option_freddy = 11
    alias_false = 0
    alias_off = 0
    alias_true = 1
    alias_on = 1
    alias_random_without_staffbot = 1
    default = 0


DEATH_LINK_KILLER: Dict[int, int] = {
    FNaFSBDeathLink.option_random_without_staff_bot: 13,
    FNaFSBDeathLink.option_random_with_staff_bot: 12,
    FNaFSBDeathLink.option_staff_bot: 11,
    FNaFSBDeathLink.option_chica: 0,
    FNaFSBDeathLink.option_roxy: 1,
    FNaFSBDeathLink.option_monty: 2,
    FNaFSBDeathLink.option_vanny: 3,
    FNaFSBDeathLink.option_vanessa: 4,
    FNaFSBDeathLink.option_moon: 5,
    FNaFSBDeathLink.option_endos: 9,
    FNaFSBDeathLink.option_freddy: 10,
}


@dataclass
class FNaFSBOptions(PerGameCommonOptions):
    goal: Goal
    present_sanity: PresentSanity
    bag_sanity: BagSanity
    randomize_security_badges: RandomizeSecurityBadges
    randomize_freddys_abilities: RandomizeFreddysAbilities
    randomize_cameras: RandomizeCameras
    lock_princess_quest: LockPrincessQuest
    starting_areas: StartingAreas
    trap_percentage: TrapPercentage
    filler_weights: FillerWeights
    trap_weights: TrapWeights
    death_link: FNaFSBDeathLink


OPTION_GROUPS = [
    OptionGroup("Goal", [Goal]),
    OptionGroup("Locations", [PresentSanity, BagSanity]),
    OptionGroup("Items", [RandomizeSecurityBadges, RandomizeFreddysAbilities, RandomizeCameras,
                          LockPrincessQuest, StartingAreas]),
    OptionGroup("Filler & Traps", [TrapPercentage, FillerWeights, TrapWeights]),
    OptionGroup("Death Link", [FNaFSBDeathLink]),
]
