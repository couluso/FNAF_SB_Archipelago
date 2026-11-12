# FNaF Security Breach

## Where is the options page?

The [player options page for this game](../options.py) contains all the options you need to configure and export a
config file. Using the Options Creator in the Archipelago Launcher is recommended.

## What does randomization do to this game?

The pickups and objectives of the Pizzaplex become locations, and the items you need to progress are shuffled into the
multiworld. Opening a present can give an item to another player, and the pass you need for Bonnie Bowl can be in
someone else's game.

- Locations: presents, duffel bags, badge holders, Freddy's upgrade stations, Golden Plushies, defeating or repairing
  Monty, Chica and Roxy, missions and clock hours.
- Items: area passes, Security Badges, Freddy's abilities, Golden Plushies, gadgets, security cameras, the Princess
  Quest machines, filler and traps.

Each area needs a Security Badge level, its pass, or both. Once an area is open, it stays open, except the Daycare
(see below).

## What is a location check?

- Completing a mission (Free Freddy, Slide Into Fun, Showtime, Thrill Seeker...).
- The clock reaching each hour, from 12 AM to 6 AM.
- Picking up a key item (passes, gadgets, Fizzy Faz, upgrades, Golden Plushies).
- Defeating Monty, Chica or Roxy, and a few story events.
- With Present Sanity: every collectible present.
- With Bag Sanity: every duffel bag.

## What happens when I receive an item?

A notification shows up in the bottom left corner and the item is applied right away: the area opens, your Security
Badge level goes up, the gadget is added to your inventory, your battery is refilled, or a buff or trap starts.

When you open a present that holds an Archipelago item, the pickup popup shows what it was and who it was for. See [LICENSING](../LICENSING.md) for credits to the person who made the icons.

## The Main Entrance and the Daycare

You start in Freddy's room with no Security Badge.

- The Daycare front door needs the Daycare Pass, because the game keeps you inside until the lights
  are back on.
- The Main Atrium needs Security Badge level 1 and the Escape The Daycare mission as finishing Chica's kitchen or El Chip's first would
  break the Daycare.
- Progression items are never placed in the Daycare play area, so you can't
  get stuck if the slide closes behind you (An option is planned for future release).

## Story logic

The logic follows the game's mission order: an area is only in logic once the mission that opens it is done, and every
ending requires reaching 6 AM.

You always start with the Faz-Watch and the Photo Pass. The Complimentary Entry Pass, the Mr. Hippo Magnet, the
Flashlight, the Daycare Pass and, when badges are shuffled, one Security Badge are always placed early.

## Goal

The Goal option sets the ending you need to reach. All 6 endings are available, and they all happen after 6 AM:

- Leave: leave the Pizzaplex through the Main Entrance.
- Loading Dock: reach Security Badge level 7 and escape through the Loading Dock.
- Rooftop: win Fazer Blast and confront Vanny on the rooftop.
- Afton: Security Badge level 8 and all 3 of Freddy's abilities, then defeat Springtrap.
- Unmasked: the Afton requirements, plus the Faz-Camera, the 6 Golden Plushies and 39 other collectibles.
- Canon: win the Fazerblaster, then beat the 3 Princess Quest machines in order.

Only the ending set by the Goal option completes your game. The other ones can still be watched but will not release.

## Vanilla options

These options are enabled by default. Disable them to keep that part of the game vanilla:

- Randomize Security Badges: each badge holder gives its vanilla badge.
- Randomize Freddy's Abilities: defeating Monty gives the Claws, defeating Chica gives the Beak and repairing Roxy gives
  the Eyes.
- Randomize Cameras: you start with every security camera.
- Lock Princess Quest: you start with Princess Quest I, II and III, so the machines are playable from the start.

## Filler items

- Battery Refill: refills flashlight or Freddy's battery depending on which one is used at the moment.
- Energy Drink: refills your stamina, and it doesn't drain for 45 seconds.
- Caffeine: Gregory moves 15% faster for 90 seconds.
- Shutdown: stuns the animatronics near Gregory.

## Traps

- Battery Trap: drains half of the flashlight or Freddy's battery depending on which one is used at the moment.
- Security Alert: An alarm is sent and nearby animatronics come for Gregory.
- Asthma Trap: Greg's stamina doesn't refill for 10 seconds.
- Busy Freddy Trap: Freddy can't be called for 50 seconds.
- Stun Trap: Gregory can't move for 5 seconds.
- Reverse Control Trap: your movement controls are reversed for 15 seconds.
- SHUT UP FREDDY!!: Freddy says random voicelines for 90 seconds.
- Foxy Trap: Foxy jumpscares you. The jumpscare does not kill.

Trap Percentage sets how many filler items are replaced by traps. Filler Weights and Trap Weights set how common each one
is, and a weight of 0 removes it.

## Death Link

Death Link is disabled by default. When it's enabled, every time Gregory gets caught, everyone with Death Link dies too.
When someone else dies, Gregory gets the punishment you picked: a chosen or random animatronic jumpscares him, or a
Staff Bot sounds the alarm. This setting can be changed from the pause menu, the setting will reset everytime the came is closed.

## Known issues

This is a beta, expect glitches/bugs/crashed:

- The Pizzaplex is modeled as a hub: the logic doesn't follow every corridor of the real map.
- The duffel bag locations are an approximation of where the bags are.

If something goes wrong, the setup guide explains where to find the log to send your bug report into the thread.
