# FNaF Security Breach for Archipelago

An [Archipelago](https://archipelago.gg) randomizer for Five Nights at Freddy's: Security Breach.

Presents, duffel bags, badge holders, missions and clock hours become checks, and the passes, Security Badges,
Freddy's abilities and gadgets you need are shuffled across the multiworld. Get the Bonnie Bowl ticket from someone
playing Ocarina of Time, send them a hookshot from a present in the Daycare, and try not to get caught by Chica on the
way.

This is the first beta. It's playable from start to finish, but expect bugs, and please report them.

## How to play

- [Game page](worlds/fnaf_sb/docs/en_FNaF%20Security%20Breach.md): what gets randomized, the goals, the traps.
- [Setup guide](worlds/fnaf_sb/docs/setup_en.md): installing UE4SS, the mod and the apworld.
- [AI Disclosure](worlds/fnaf_sb/docs/AI_disclosure.md)

You need two files from the release page:

- `fnaf_sb.apworld`: the world and the FNaF SB Client, goes in Archipelago's `custom_worlds` folder.
- `FNaF_SB_Ap.zip`: the UE4SS mod, goes in `fnaf9/Binaries/Win64/Mods`.

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
