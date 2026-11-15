# FNaF Security Breach Setup Guide

## Required Software

- Five Nights at Freddy's: Security Breach (PC, Steam)
- [UE4SS 3.0.1](https://github.com/UE4SS-RE/RE-UE4SS/releases/tag/v3.0.1), the `UE4SS_v3.0.1.zip` file
- [Archipelago](https://github.com/ArchipelagoMW/Archipelago/releases) 0.6.0 or newer
- From this project's release page: `fnaf_sb.apworld` and `FNaF_SB_Ap.zip`

## Finding the game folder

In Steam, right-click Five Nights at Freddy's: Security Breach, then Manage > Browse local files. Everything below
happens in the `fnaf9/Binaries/Win64` folder, the one that contains `fnaf9-Win64-Shipping.exe`.

## Installing UE4SS

1. Extract everything in `UE4SS_v3.0.1.zip` into `fnaf9/Binaries/Win64`. You should now see `UE4SS.dll`, `dwmapi.dll`,
   `UE4SS-settings.ini` and a `Mods` folder next to the game's exe.
2. Open `UE4SS-settings.ini` with a text editor, find `bUseUObjectArrayCache` and set it to false:

   ```ini
   bUseUObjectArrayCache = false
   ```

   Without this, crashes are way more frequent than usually.

## Installing the mod

Extract `FNaF_SB_Ap.zip` into `fnaf9/Binaries/Win64/Mods`. You should end up with
`Mods/FNaF_SB_Ap/Scripts/main.lua`.

## Installing the apworld

Copy `fnaf_sb.apworld` into the `custom_worlds` folder of your Archipelago install, then start the Archipelago
Launcher. You can also double-click the file to install it directly.

## Linking the client to the mod

The FNaF SB Client and the mod talk through a few text files in the mod's `bridge` folder, so the client needs to know
where that folder is.

When opening the client for the first time, it will ask you to point to you FNAF SB installation folder.
Select the folder where the fnaf9.exe is located, usually `\SteamLibrary\steamapps\common\Quarters`

If this doesnt work, do this :

1. Open `host.yaml` in your Archipelago folder with a text editor.
2. Find the `fnaf_sb_options` section and set `mod_bridge_folder` to the full path of the mod's `bridge` folder. For
   example:

   ```yaml
   fnaf_sb_options:
     mod_bridge_folder: "C:/Program Files (x86)/Steam/steamapps/common/Quarters/fnaf9/Binaries/Win64/Mods/FNaF_SB_Ap/bridge"
   ```

   Use `/` in the path, not `\`. If the section isn't there yet, restart the Launcher once after installing the
   apworld, or add these two lines at the end of the file.

## Creating your YAML

Open the Archipelago Launcher and click "Options Creator". Pick your options, then export your YAML and give it to
the person generating the multiworld.

## Joining a multiworld

1. Open "FNaF SB Client" from the Archipelago Launcher.
2. Start the game.
3. In the client, connect with `/connect <address>:<port>` and enter your
   slot name.
4. Start a new game.

**IT IS HIGLY RECOMMENDED TO KEEP BACKUPS OF YOU SAVES IN CASE YOU GET STUCK**

Keep the client open while you play. If it closes, nothing is lost: the mod keeps every check you make and sends them
as soon as the client is back.

### About the Foxy Trap sound

The first time the client starts, it sets up the Foxy Trap sound in the game folder (the `zzz_APFoxy_P.pak` file in
`fnaf9/Content/Paks`). It's built from your own game files, so the sound follows the game's Jumpscare volume. That's why
the client should be opened before the game the first time: if the game was already running, the Foxy Trap has no sound
until you restart it.

## Client commands

- `/bridge`: shows the bridge folder the client is using.
- `/resync`: sends the full item list to the mod again.

## Troubleshooting

- The client says `mod_bridge_folder is not set`: check the "Linking the client to the mod" step.
- Nothing happens in game: look for `Mods/FNaF_SB_Ap/log.txt`. If it doesn't exist, the mod isn't loaded, so check the
  UE4SS install and that `enabled.txt` is in the mod folder.
- The game crashes in the Daycare elevator: check `bUseUObjectArrayCache = false` in `UE4SS-settings.ini`.
- An item is missing in game: type `/resync` in the client.
- No Foxy sound: close the game, restart the client, then start the game again.

When you report a bug, send `Mods/FNaF_SB_Ap/log.txt` and the client's log. If the game crashed and you already
started it again, the session that crashed is in `log_previous.txt` instead, and `trace_previous.txt` next to it shows
what the mod was doing right when it went down. Send those two. For a more detailed log, set `C.log_verbose = true` in
`Mods/FNaF_SB_Ap/Scripts/config.lua`, restart the game and do it again.
