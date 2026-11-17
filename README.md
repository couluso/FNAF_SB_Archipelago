# FNaF Security Breach for Archipelago

An [Archipelago](https://archipelago.gg) randomizer for Five Nights at Freddy's: Security Breach.

Presents, duffel bags, badge holders, missions and clock hours become checks, and the passes, Security Badges,
Freddy's abilities and gadgets you need are shuffled across the multiworld. Get the Bonnie Bowl ticket from someone
playing Ocarina of Time, send them a hookshot from a present in the Daycare, and try not to get caught by Chica on the
way.

This is the third beta. It's playable from start to finish, but expect bugs, and please report them. What changed
since the last one is in the patch notes on the release page.

## How to play

- [Game page](worlds/fnaf_sb/docs/en_FNaF%20Security%20Breach.md): what gets randomized, the goals, the traps.
- [Setup guide](worlds/fnaf_sb/docs/setup_en.md): installing UE4SS, the mod and the apworld.
- [AI Disclosure](worlds/fnaf_sb/docs/AI_disclosure.md)

You need two files from the release page:

- `fnaf_sb.apworld`: the world and the FNaF SB Client, goes in Archipelago's `custom_worlds` folder.
- `FNaF_SB_Ap.zip`: the UE4SS mod, goes in `fnaf9/Binaries/Win64/Mods`.

## What changes from the vanilla game

- Every check gives an Archipelago item instead of its vanilla one: presents, duffel bags, badge holders, Freddy's
  upgrades, the Faz-Watch, the Photo Pass... The pickup popup shows the item you found and who it's for.
- Your Security Level only goes up when you receive a Security Badge. Badge holders just give their Archipelago item.
  (unless Randomize Security Badges is off)
- Passes, gadgets, cameras and Freddy's abilities come from the multiworld. The game's doors still check them like
  usual, so the Bonnie Bowl door stays shut until someone sends you the Bowling Ticket.
- Beating Monty, Chica or Roxy is a check, and so is taking their Claws, Voice Box or Eyes from them. Those parts are
  items like any other, and you still bring them to Parts & Service to upgrade Freddy. You can always take them from
  the beaten animatronic, even if you already received them.
- The elevators out of the lobby stay off until you've escaped the Daycare ("Requires Completing Daycare"), so the
  story can't be skipped by accident.
- The Princess Quest machines need their Princess Quest item, and the act before them beaten.
- The present in Chica's green room stays closed until Freddy's maintenance is done, since picking it up starts the
  4 AM blackout.
- The lobby security office: after doing the intro chase and going to the main entrance, the door stays open so you can go back to pick up items you might have missed
- No tooltips by default: the game's instruction cards never show. An item received inside Freddy or in a cutscene
  could open one that can't be closed. They can be turned back on from the pause menu.
- An "Archipelago Options" page in the pause menu, for the Death Link behavior and the tooltips. It also shows how many
  collectibles you have out of the 39 the Fire ending needs.
- Received items show up in the bottom left corner. Filler items and traps (Caffeine, Stun Trap, Foxy...) are new
  effects, they don't exist in the base game.
- Only the ending set as your goal completes your game. The other endings still play, they just don't count.

## What's in this repository

```
worlds/fnaf_sb/     the Archipelago world, the FNaF SB Client and the world tests
  docs/             game page and setup guide
mod/FNaF_SB_Ap/     the UE4SS Lua mod
licenses/           third-party licenses
build_release.py    makes the two release files in release/  (NOT RECOMMENDED - UNSTABLE)
```

## Credits

- Coulu: the world, the client and the mod.
- @lmecraft (Discord) : Understanding the architecture of Security Breach
- @pinkcrackshot (Discord): the custom item icons.
- RayDeeUx: the Foxy jumpscare picture and sound, from
  [UniversalJumpscare](https://github.com/RayDeeUx/UniversalJumpscare).
- The Archipelago and UE4SS teams, for the tools all of this is built on.

See [LICENSING.md](LICENSING.md) for the licenses. This is a fan project, not affiliated with Steel Wool Studios or
Scott Cawthon. You need your own copy of the game.
