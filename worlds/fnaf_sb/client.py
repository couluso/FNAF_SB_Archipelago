"""Archipelago client for FNaF Security Breach.

The UE4SS mod can't open a WebSocket, so this client talks to the server and passes everything
through text files in the mod's bridge folder:

to_game.txt (client -> mod)
    S <seed>-<run> <slot>      header, one save state per room and slot
    O <key> <value>            slot options
    A <area_key>               starting area
    I <index> <item_id>        every item received so far, in order
    K <location_id>            locations the server already counts as checked
    D <n>                      deaths received through Death Link

scouts.txt (client -> mod)
    S <seed>-<run> <slot>
    L<TAB><location><TAB><item id><TAB><flags><TAB><own 0|1><TAB><item name><TAB><player name>

from_game.txt (mod -> client)
    S <seed> <slot>            header the mod is using
    C <location_id>            location checked
    G                          goal reached
    D <n>                      number of deaths
"""
from __future__ import annotations

import asyncio
import os
import threading
import time
import typing
import uuid

import Utils
from CommonClient import ClientCommandProcessor, CommonContext, get_base_parser, gui_enabled, logger, server_loop
from NetUtils import ClientStatus

from .data import GAME_NAME

POLL_SECONDS = 0.5
MOD_NAME = "FNaF_SB_Ap"
DEFAULT_GAME_DIR = "C:/Program Files (x86)/Steam/steamapps/common/Quarters"


def find_bridge_in(folder: str) -> str:
    """Finds Mods/FNaF_SB_Ap/bridge from the game folder, or from any folder on the way to it."""
    folder = os.path.normpath(folder)
    if os.path.basename(folder) == "bridge" and os.path.isfile(os.path.join(folder, "..", "Scripts", "main.lua")):
        return folder
    tail =["fnaf9", "Binaries", "Win64", "Mods", MOD_NAME]
    for start in range(len(tail) + 1):
        if start and os.path.basename(folder).lower() != tail[start - 1].lower():
            continue
        mod = os.path.join(folder, *tail[start:])
        if os.path.isfile(os.path.join(mod, "Scripts", "main.lua")):
            return os.path.join(mod, "bridge")
    for root, dirs, _ in os.walk(folder):
        if os.path.basename(root) == MOD_NAME and os.path.isfile(os.path.join(root, "Scripts", "main.lua")):
            return os.path.join(root, "bridge")
        if root[len(folder):].count(os.sep) >= 6:
            dirs[:] = []
    return ""


def replace_file(tmp: str, path: str, tries: int = 10, delay: float = 0.02) -> bool:
    """os.replace, retried a few times: Windows refuses it while the mod is reading the file."""
    for attempt in range(tries):
        try:
            os.replace(tmp, path)
            return True
        except PermissionError:
            if attempt + 1 < tries:
                time.sleep(delay)
    return False


class FNaFSBCommandProcessor(ClientCommandProcessor):
    def _cmd_bridge(self) -> None:
        """Show the bridge folder currently used to talk to the mod."""
        self.output(f"Bridge folder: {self.ctx.bridge_dir or '<not set>'}")

    def _cmd_resync(self) -> None:
        """Rewrite to_game.txt from the items received so far."""
        self.ctx.write_to_game()
        self.output("Resynced.")


class FNaFSBContext(CommonContext):
    command_processor = FNaFSBCommandProcessor
    game = GAME_NAME
    items_handling = 0b111

    def __init__(self, server_address: typing.Optional[str], password: typing.Optional[str]) -> None:
        super().__init__(server_address, password)
        self.bridge_dir = self._find_bridge_dir()
        if not self.bridge_dir:
            logger.error(
                "FNaF SB Client: the mod's bridge folder wasn't found. Restart this client and select your "
                "FNaF Security Breach folder, or set 'fnaf_sb_options: mod_bridge_folder' in host.yaml to "
                "<game>/fnaf9/Binaries/Win64/Mods/FNaF_SB_Ap/bridge."
            )
        else:
            logger.info(f"FNaF SB Client: using bridge folder {self.bridge_dir}")
            threading.Thread(target=self.install_foxy_sound, daemon=True).start()
        self.slot_data: dict = {}
        self.deaths_received = 0
        self.deaths_sent = 0
        self.deaths_synced = False
        self.checked_sent: set[int] = set()
        self.goal_sent = False
        self.rewrite_pending: set[str] = set()
        self.watcher: typing.Optional[asyncio.Task] = None
        self.run_id: typing.Optional[str] = None

    @staticmethod
    def _find_bridge_dir() -> str:
        """The bridge folder from host.yaml. If it's not set or gone, asks for the game folder,
        looks for the mod's bridge folder inside it and saves it to host.yaml."""
        from . import FNaFSBWorld
        options = FNaFSBWorld.settings
        folder = str(options.mod_bridge_folder or "")
        if folder and os.path.isdir(folder):
            return folder
        if folder:
            logger.warning(f"FNaF SB Client: the bridge folder in host.yaml doesn't exist any more: {folder}")
        game = Utils.open_directory("Select your FNaF Security Breach folder", DEFAULT_GAME_DIR
                                    if os.path.isdir(DEFAULT_GAME_DIR) else "")
        if not game:
            return ""
        found = find_bridge_in(game)
        if not found:
            logger.error(f"FNaF SB Client: no {MOD_NAME} mod found in {game}. Is it in fnaf9/Binaries/Win64/Mods?")
            return ""
        os.makedirs(found, exist_ok=True)
        found = found.replace("\\", "/")
        options.mod_bridge_folder = type(options.mod_bridge_folder)(found)
        try:
            import settings
            settings.get_settings().save()
            logger.info(f"FNaF SB Client: bridge folder saved to host.yaml: {found}")
        except Exception as e:
            logger.warning(f"FNaF SB Client: bridge folder found but not saved to host.yaml ({e}): {found}")
        return found

    def install_foxy_sound(self) -> None:
        """Builds the Foxy Trap sound pak in the game folder if it is missing or out of date."""
        from . import foxy_pak
        mod_dir = os.path.dirname(os.path.normpath(self.bridge_dir))
        try:
            if foxy_pak.install(mod_dir):
                logger.info("FNaF SB Client: Foxy Trap sound installed. If the game is already running, "
                            "restart it to hear it.")
        except Exception as e:
            logger.warning(f"FNaF SB Client: could not install the Foxy Trap sound ({e}). "
                           "The trap still works, just without sound.")

    @property
    def to_game_path(self) -> str:
        return os.path.join(self.bridge_dir, "to_game.txt")

    @property
    def from_game_path(self) -> str:
        return os.path.join(self.bridge_dir, "from_game.txt")

    def header(self) -> str:
        slot = (self.auth or "unknown").replace(" ", "_")
        seed = getattr(self, "room_seed_name", None) or self.seed_name or "unknown"
        run = f"-{self.run_id}" if self.run_id else ""
        return f"S {str(seed).replace(' ', '_')}{run} {slot}"

    def run_key(self) -> str:
        return f"fnaf_sb_run_{self.team}_{self.slot}"

    async def server_auth(self, password_requested: bool = False) -> None:
        if password_requested and not self.password:
            await super().server_auth(password_requested)
        await self.get_username()
        await self.send_connect()

    def on_package(self, cmd: str, args: dict) -> None:
        if cmd == "RoomInfo":
            self.room_seed_name = args.get("seed_name")
        elif cmd == "Connected":
            self.slot_data = args.get("slot_data", {})
            self.checked_sent = set(self.checked_locations)
            self.goal_sent = False
            self.deaths_synced = False
            if self.slot_data.get("death_link"):
                asyncio.create_task(self.update_death_link(True))
            self.run_id = None
            asyncio.create_task(self.send_msgs([{
                "cmd": "Set", "key": self.run_key(), "default": uuid.uuid4().hex[:8],
                "want_reply": True, "operations": [{"operation": "default", "value": None}],
            }]))
            if self.watcher is None or self.watcher.done():
                self.watcher = asyncio.create_task(self.watch_game())
            locations = sorted(getattr(self, "server_locations", None)
                               or set(self.missing_locations) | set(self.checked_locations))
            if locations:
                asyncio.create_task(self.send_msgs([{
                    "cmd": "LocationScouts", "locations": locations, "create_as_hint": 0}]))
        elif cmd == "SetReply" and args.get("key") == self.run_key():
            self.run_id = str(args.get("value") or "")[:16] or None
            logger.info(f"FNaF SB Client: room id {self.run_id}, header {self.header()}")
            self.write_to_game()
            self.write_scouts()
        elif cmd == "LocationInfo":
            self.write_scouts()
        elif cmd == "ReceivedItems":
            self.write_to_game()
        elif cmd == "RoomUpdate" and "checked_locations" in args:
            self.write_to_game()

    def on_deathlink(self, data: dict) -> None:
        self.deaths_received += 1
        self.write_to_game()
        super().on_deathlink(data)

    def on_package_disconnect(self) -> None:
        pass

    async def shutdown(self) -> None:
        for path in (self.to_game_path, os.path.join(self.bridge_dir or "", "scouts.txt")):
            try:
                if self.bridge_dir and os.path.exists(path):
                    os.remove(path)
            except OSError as e:
                logger.warning(f"could not remove {path}: {e}")
        await super().shutdown()

    def write_to_game(self) -> None:
        if not self.bridge_dir:
            logger.error("mod_bridge_folder is not set in host.yaml (fnaf_sb_options).")
            return
        if not self.run_id:
            return
        os.makedirs(self.bridge_dir, exist_ok=True)
        lines = [self.header()]
        for key in ("lock_areas", "badge_gating", "lock_daycare", "death_link"):
            lines.append(f"O {key} {int(bool(self.slot_data.get(key, False)))}")
        lines.append(f"O present_sanity {int(bool(self.slot_data.get('present_sanity', True)))}")
        lines.append(f"O death_link_behavior {int(self.slot_data.get('death_link_behavior', 13))}")
        lines.append(f"O bag_sanity {int(self.slot_data.get('bag_sanity', 2))}")
        lines.append(f"O goal {self.slot_data.get('goal', 'leave')}")
        for area_key in self.slot_data.get("start_areas", []):
            lines.append(f"A {area_key}")
        for index, item in enumerate(self.items_received):
            lines.append(f"I {index} {item.item}")
        for location in sorted(self.checked_locations):
            lines.append(f"K {location}")
        lines.append(f"D {self.deaths_received}")
        tmp = self.to_game_path + ".tmp"
        with open(tmp, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(lines) + "\n")
        if replace_file(tmp, self.to_game_path):
            self.rewrite_pending.discard("to_game")
        else:
            self.rewrite_pending.add("to_game")
            logger.warning("FNaF SB Client: to_game.txt busy (the game was reading it), written again shortly")

    def scout_lines(self) -> typing.List[str]:
        def clean(s: object) -> str:
            return str(s).replace("\t", " ").replace("\r", " ").replace("\n", " ")
        lines = [self.header()]
        for location, item in sorted(getattr(self, "locations_info", {}).items()):
            try:
                name = self.item_names.lookup_in_slot(item.item, item.player)
            except Exception:
                name = f"Item {item.item}"
            player = self.player_names.get(item.player, f"Player {item.player}")
            own = 1 if item.player == self.slot else 0
            lines.append(f"L\t{location}\t{item.item}\t{item.flags}\t{own}\t{clean(name)}\t{clean(player)}")
        return lines

    def write_scouts(self) -> None:
        """Writes scouts.txt, used by the pickup popup."""
        if not self.bridge_dir or not self.run_id or not getattr(self, "locations_info", None):
            return
        os.makedirs(self.bridge_dir, exist_ok=True)
        path = os.path.join(self.bridge_dir, "scouts.txt")
        tmp = path + ".tmp"
        with open(tmp, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(self.scout_lines()) + "\n")
        if not replace_file(tmp, path):
            self.rewrite_pending.add("scouts")
            logger.warning("FNaF SB Client: scouts.txt busy (the game was reading it), written again shortly")
            return
        self.rewrite_pending.discard("scouts")
        logger.info(f"FNaF SB Client: {len(self.locations_info)} locations scouted for the pickup popups")

    def read_from_game(self) -> typing.Optional[dict]:
        try:
            with open(self.from_game_path, "r", encoding="utf-8") as f:
                raw = f.read().splitlines()
        except (FileNotFoundError, PermissionError, OSError):
            return None
        result = {"header": None, "checks": set(), "goal": False, "deaths": 0}
        for line in raw:
            parts = line.split()
            if not parts:
                continue
            tag = parts[0]
            try:
                if tag == "S":
                    result["header"] = line.strip()
                elif tag == "C":
                    result["checks"].add(int(parts[1]))
                elif tag == "G":
                    result["goal"] = True
                elif tag == "D":
                    result["deaths"] = int(parts[1])
            except (IndexError, ValueError):
                continue
        return result

    async def watch_game(self) -> None:
        while not self.exit_event.is_set():
            await asyncio.sleep(POLL_SECONDS)
            if "to_game" in self.rewrite_pending:
                self.write_to_game()
            if "scouts" in self.rewrite_pending:
                self.write_scouts()
            if self.server is None or self.server.socket.closed:
                continue
            data = self.read_from_game()
            if not self.run_id or not data or data["header"] != self.header():
                continue

            new = data["checks"] - self.checked_sent - set(self.checked_locations)
            if new:
                self.checked_sent |= new
                await self.send_msgs([{"cmd": "LocationChecks", "locations": sorted(new)}])
            if data["goal"] and not self.goal_sent:
                self.goal_sent = True
                await self.send_msgs([{"cmd": "StatusUpdate", "status": ClientStatus.CLIENT_GOAL}])
            if not self.deaths_synced:
                self.deaths_sent = data["deaths"]
                self.deaths_synced = True
            if data["deaths"] < self.deaths_sent:
                self.deaths_sent = data["deaths"]
            if data["deaths"] > self.deaths_sent:
                self.deaths_sent = data["deaths"]
                if "DeathLink" in self.tags:
                    await self.send_death("Gregory was caught by an animatronic.")

    def run_gui(self) -> None:
        from kvui import GameManager

        class FNaFSBManager(GameManager):
            logging_pairs = [("Client", "Archipelago")]
            base_title = "Archipelago FNaF Security Breach Client"

        self.ui = FNaFSBManager(self)
        self.ui_task = asyncio.create_task(self.ui.async_run(), name="UI")


def launch(*launch_args: str) -> None:
    async def main(args) -> None:
        ctx = FNaFSBContext(args.connect, args.password)
        ctx.server_task = asyncio.create_task(server_loop(ctx), name="ServerLoop")
        if gui_enabled:
            ctx.run_gui()
        ctx.run_cli()
        await ctx.exit_event.wait()
        await ctx.shutdown()

    Utils.init_logging("FNaFSBClient", exception_logger="Client")
    import colorama
    parser = get_base_parser(description="FNaF Security Breach Archipelago client")
    args = parser.parse_args(launch_args)
    colorama.just_fix_windows_console()
    asyncio.run(main(args))
    colorama.deinit()
