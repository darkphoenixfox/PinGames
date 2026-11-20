## Pure high-score table logic. A table is an Array of [initials: String, score: int],
## sorted best first.
extends RefCounted

const DEFAULT_NAMES := ["PIN", "ARC", "DMD", "TLT", "BAL", "FLP", "LNC", "SPN", "RMP", "JKP"]


static func defaults(size: int) -> Array:
	var t := []
	for i in size:
		t.append([DEFAULT_NAMES[i % DEFAULT_NAMES.size()], 50000 - i * 5000])
	return t


static func qualifies(table: Array, score: int, size: int) -> bool:
	if score <= 0:
		return false
	return table.size() < size or score > int(table[table.size() - 1][1])


## Inserts in place. Returns the 0-based rank, or -1 if the score did not qualify.
static func insert(table: Array, initials: String, score: int, size: int) -> int:
	if not qualifies(table, score, size):
		return -1
	var idx := table.size()
	for i in table.size():
		if score > int(table[i][1]):
			idx = i
			break
	table.insert(idx, [initials, score])
	while table.size() > size:
		table.pop_back()
	return idx


## 1234567 -> "1,234,567"
static func format_score(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if n < 0 else "") + s + out
