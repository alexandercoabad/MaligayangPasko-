"""Cycle-exact reference model of tt_um_XmasTree_MaligayangPasko, written from the
description of the picture (cell grid, tree table, glyphs), not from the RTL expressions."""

H_TOTAL, V_TOTAL = 800, 525

# half-width in cells of tree rows 5..20 (rows 5-8, 9-13 and 14-20 are the three tiers)
TREE = [0, 1, 2, 3, 1, 2, 3, 4, 5, 2, 3, 4, 5, 6, 7, 8]
GLYPHS = {  # 3x5 cells, one string per row
    "P": ["###", "#.#", "###", "#..", "#.."],
    "A": ["###", "#.#", "###", "#.#", "#.#"],
    "S": ["###", "#..", "###", "..#", "###"],
    "K": ["#.#", "#.#", "##.", "#.#", "#.#"],
    "O": ["###", "#.#", "#.#", "#.#", "###"],
}
WORD = "PASKO"

RED, YELLOW, WHITE, CYAN = 0b110000, 0b111100, 0b111111, 0b001111
LIGHTS = [RED, YELLOW, WHITE, CYAN]


def pack(rgb):
    """rgb = RRGGBB (two bits each) -> uo_out = {hs, B0, G0, R0, vs, B1, G1, R1} without the sync bits"""
    r1, r0, g1, g0, b1, b0 = [(rgb >> s) & 1 for s in (5, 4, 3, 2, 1, 0)]
    return (b0 << 6) | (g0 << 5) | (r0 << 4) | (b1 << 2) | (g1 << 1) | r1


def colour(hc, vc, t):
    cx, cy = hc // 16, vc // 16
    dx = (19 - cx) if cx < 20 else (cx - 20)
    hw = TREE[cy - 5] if 5 <= cy <= 20 else None
    in_tree = hw is not None and dx <= hw
    edge = in_tree and dx == hw
    if cy == 4 and dx == 0:                                   # star
        return YELLOW if (t >> 4) & 1 else WHITE
    if in_tree and not edge and ((cx ^ cy) & 1) and (((cx >> 2) ^ (cy >> 2)) & 1):   # light
        lc = (((cx >> 1) & 1) << 1 | ((cy >> 1) & 1)) ^ ((t >> 4) & 3)
        return LIGHTS[lc]
    if edge:
        return 0b000100
    if in_tree:
        return 0b001000
    if 21 <= cy <= 23 and dx == 0:                            # trunk
        return 0b100100
    if cy >= 24:                                              # snow, with the word on it
        if 25 <= cy <= 29 and 10 <= cx < 29:
            letter, col = divmod(cx - 10, 4)
            if col < 3 and GLYPHS[WORD[letter]][cy - 25][col] == "#":
                return RED
        return WHITE
    x8, y8 = hc // 8, vc // 8                                 # falling snow, 4x4 flakes
    ph = ((x8 >> 3) & 15) ^ (((x8 >> 3) & 3) << 2 | ((x8 >> 5) & 3))
    if (x8 & 3) == 1 and not (hc & 4) and not (vc & 4) and ((y8 & 15) + ph) & 15 == (t >> 2) & 15:
        return WHITE
    return 0b000001


class Model:
    def __init__(self):
        self.hc = self.vc = self.t = 0

    def step(self, ui):
        """One rising clock edge (reset released): returns uo_out after the edge."""
        hc, vc, t = self.hc, self.vc, self.t
        active = hc < 640 and vc < 480
        hs_n = 0 if 656 <= hc < 752 else 1
        vs_n = 0 if vc in (490, 491) else 1
        out = pack(colour(hc, vc, t)) if active else 0
        out |= (hs_n << 7) | (vs_n << 3)
        if hc == H_TOTAL - 1:
            self.hc = 0
            if vc == V_TOTAL - 1:
                self.vc = 0
                if not (ui & 1):
                    self.t = (t + 1) & 63
            else:
                self.vc = vc + 1
        else:
            self.hc = hc + 1
        return out
