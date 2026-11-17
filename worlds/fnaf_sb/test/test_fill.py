from Fill import distribute_items_restrictive
from test.general import setup_multiworld, setup_solo_multiworld

from .. import FNaFSBWorld
from ..data import BACKSTAGE_PASS


class TestFullFill(__import__("unittest").TestCase):
    def _run(self, options: dict, seeds: int = 15) -> None:
        for seed in range(seeds):
            mw = setup_solo_multiworld(FNaFSBWorld, steps=("generate_early", "create_regions", "create_items", "set_rules", "connect_entrances", "generate_basic"), seed=seed)
            for name, value in options.items():
                getattr(mw.worlds[1].options, name).value = value
            distribute_items_restrictive(mw)
            self.assertTrue(mw.can_beat_game(mw.get_all_state(False)), f"seed {seed} not beatable")
            self.assertTrue(all(l.item for l in mw.get_locations()), f"seed {seed} has empty locations")

    def test_defaults(self) -> None:
        self._run({})

    def test_max_starting_areas(self) -> None:
        self._run({"starting_areas": 5}, seeds=8)

    def test_goal_loading_dock(self) -> None:
        self._run({"goal": 1}, seeds=8)

    def test_goal_rooftop(self) -> None:
        self._run({"goal": 2}, seeds=8)

    def test_goal_afton(self) -> None:
        self._run({"goal": 3}, seeds=8)

    def test_goal_unmasked(self) -> None:
        self._run({"goal": 4}, seeds=8)

    def test_goal_canon(self) -> None:
        self._run({"goal": 5}, seeds=8)

    def test_no_starting_area_and_alt_goal(self) -> None:
        self._run({"starting_areas": 0, "goal": 3}, seeds=8)

    def test_bags_off(self) -> None:
        self._run({"bag_sanity": 0}, seeds=8)

    def test_presents_off(self) -> None:
        self._run({"present_sanity": 0}, seeds=8)

    def test_presents_and_bags_off(self) -> None:
        self._run({"present_sanity": 0, "bag_sanity": 0}, seeds=8)

    def test_presents_off_bags_no_progression_hardest_goal(self) -> None:
        self._run({"present_sanity": 0, "bag_sanity": 1, "goal": 4}, seeds=8)

    def test_bags_no_progression(self) -> None:
        self._run({"bag_sanity": 1}, seeds=8)


class TestBackstageSpheres(__import__("unittest").TestCase):
    def _run(self, players: int, seeds: int) -> list:
        """Without starting passes, post_fill moves each Backstage Pass into the late early spheres of the multiworld (BACKSTAGE_SPHERES), and the seed still fills and can be beaten."""
        homes = []
        for seed in range(seeds):
            mw = setup_multiworld([FNaFSBWorld] * players, seed=seed, options={"starting_areas": 0})
            distribute_items_restrictive(mw)
            for player, world in mw.worlds.items():
                lo, hi = world.backstage_window(max(world.backstage_spheres().values()))
                world.post_fill()
                spheres = world.backstage_spheres()
                spot = next(l for l in mw.get_filled_locations()
                            if l.item.player == player and l.item.name == BACKSTAGE_PASS)
                where = f"seed {seed} player {player}: sphere {spheres.get(spot)}, window {lo}-{hi}"
                self.assertTrue(lo <= spheres.get(spot, 0) <= hi, where)
                homes.append(spot.player == player)
            self.assertTrue(mw.can_beat_game(mw.get_all_state(False)), f"seed {seed} not beatable")
            self.assertTrue(all(l.item for l in mw.get_locations()), f"seed {seed} has empty locations")
        return homes

    def test_solo(self) -> None:
        self._run(1, 12)

    def test_two_players(self) -> None:
        homes = self._run(2, 10)
        self.assertIn(False, homes)
