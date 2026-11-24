"""Makes Tilt Breaker's 19-column 2-player levels from the 11-column ones (D-285,
D-342): each row keeps its 11 columns in the middle, with its edge columns
mirrored out to each side (left: columns 4..1, right: columns 9..6).
Usage: python scripts/tools/gen_breakout_2p_levels.py 11 12 ...   (level numbers)
It overwrites levels/level2p_NN.txt for the numbers given (hand edits are lost)."""
import sys
from pathlib import Path

LV = Path("games/breakout/levels")
for n in map(int, sys.argv[1:]):
    src = (LV / f"level_{n:02d}.txt").read_text(encoding="utf-8").splitlines()
    out = [f"# Tilt Breaker 2-player level {n} (D-285): 19 columns, generated from level {n}",
           "# by scripts/tools/gen_breakout_2p_levels.py (its 11 columns in the middle, its edge columns mirrored out). Edit freely."]
    for line in src:
        s = line.strip()
        if not s or s.startswith("#"):
            continue
        row = s.ljust(11, ".")[:11]
        left = "".join(row[4 - j] for j in range(4))
        right = "".join(row[9 - k] for k in range(4))
        out.append(left + row + right)
    with open(LV / f"level2p_{n:02d}.txt", "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(out) + "\n")
    print("wrote", n)
