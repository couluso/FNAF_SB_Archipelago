# Licensing and credits

This is a free fan project. It isn't affiliated with, endorsed by or sponsored by Steel Wool Studios, Scott Cawthon,
ScottGames or the Archipelago team.

Five Nights at Freddy's, Five Nights at Freddy's: Security Breach, Foxy and every related character, name and asset are
trademarks and copyrights of Scott Cawthon and Steel Wool Studios. You need your own legal copy of the game to play.

## The code

The world (`worlds/fnaf_sb`), the FNaF SB Client, the Lua mod (`mod/FNaF_SB_Ap`) and the docs are made by Coulu and
released under the MIT license, see [LICENSE](LICENSE).

## Assets made by other people

| Files | Author | License |
|---|---|---|
| `icons/progression.png`, `useful.png`, `filler.png`, `trap.png`, `proguseful.png` | pinkcrackshot (Discord: @pinkcrackshot) | Made for this project, all rights belong to the artist
| `Media/foxy/*.png`, `Media/foxy.wav` | From RayDeeUx's [UniversalJumpscare](https://github.com/RayDeeUx/UniversalJumpscare) (`resources/foxy.gif`, `resources/foxy.mp3`) | LGPL-2.1, see [licenses/LGPL-2.1.txt](licenses/LGPL-2.1.txt) |

The UniversalJumpscare files were changed: the GIF was split into 17 PNG frames, and the mp3 was converted to a 16-bit
WAV. The original files are available at the link above. Foxy and his jumpscare come from Five Nights at Freddy's 2, by
Scott Cawthon.

## Software we use but don't include

| Software | License | Link |
|---|---|---|
| Archipelago | MIT, see [licenses/Archipelago-MIT.txt](licenses/Archipelago-MIT.txt) | https://github.com/ArchipelagoMW/Archipelago |
| UE4SS (RE-UE4SS) 3.0.1 | MIT | https://github.com/UE4SS-RE/RE-UE4SS |

The world is loaded by Archipelago and uses its API (`BaseClasses`, `Options`, `CommonClient`...), but no Archipelago
code is redistributed here. Each player downloads UE4SS from its official release page.

## Game files

No file from the game is included in this project.

The Foxy Trap sound file (`zzz_APFoxy_P.pak`) is made on each player's computer by the FNaF SB Client. The client reads
the player's own copy of `MusicStreaming.bnk` from their game install, puts the Foxy sound on one of its unused tracks,
and saves the result in their game folder. That file contains game data, so it's never shipped with the mod, and it
shouldn't be shared or uploaded.
