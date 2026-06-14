#!/usr/bin/env python3
"""Content-quality lint for StackSpeak word data (shared/).

Complements check-words-sync.sh (which only checks bundle copies are in sync).
This guards the *content* against regressions the 2026-06 content review found:

  1. Placeholder stubs            ("... definition needed", "TODO: Add code example")
  2. Self-leaking shortDefinition (the term appears inside its own definition —
     a giveaway, since shortDefinition is the multiple-choice quiz answer)
  3. Index / stack-file drift     (wordCount mismatch, missing/orphan stacks,
     and the dead `minimumLevel` field reappearing in a stack file — the index
     is the single source of truth for a stack's minimum level)
  4. Cross-stack duplicate terms  (same term in two stacks lets the quiz show two
     correct answers; a small allowlist holds the intentional homonyms)

Exit 0 if clean, 1 otherwise. Suitable for CI or a pre-commit hook.
"""
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
INDEX = REPO / "shared" / "words-index.json"
STACKS = REPO / "shared" / "stacks"

# Same-named words that are genuinely DIFFERENT concepts per stack — these are
# allowed to coexist. Keep this list tight; every entry is a deliberate decision.
HOMONYM_ALLOWLIST = {
    "fragment", "gateway", "histogram", "iam", "interfaces", "job", "label",
    "lifecycle", "manifest", "origin", "protocol", "pub sub", "reconciliation",
    "repository", "struct", "tuple", "vpc",
}

PLACEHOLDER_MARKERS = ("definition needed", "todo: add code")


def norm(term: str) -> str:
    term = re.sub(r"\([^)]*\)", "", term).lower()
    return " ".join(re.split(r"[^a-z0-9]+", term)).strip()


def main() -> int:
    problems: list[str] = []

    index = json.loads(INDEX.read_text())
    index_stacks = {s["id"]: s for s in index["stacks"]}

    stack_files = sorted(STACKS.glob("*.json"))
    file_ids = {f.stem for f in stack_files}

    # structural: index <-> files
    for sid in index_stacks:
        if sid not in file_ids:
            problems.append(f"[index] stack '{sid}' listed in index has no file")
    for sid in file_ids:
        if sid not in index_stacks:
            problems.append(f"[index] stack file '{sid}.json' is not listed in the index")

    term_locations: dict[str, list[str]] = {}

    for f in stack_files:
        data = json.loads(f.read_text())
        sid = data.get("stack", f.stem)

        if "minimumLevel" in data:
            problems.append(
                f"[{sid}] stack file carries a dead `minimumLevel` field — "
                f"the index is the source of truth; remove it")

        words = data.get("words", [])

        # wordCount drift
        expected = index_stacks.get(sid, {}).get("wordCount")
        if expected is not None and expected != len(words):
            problems.append(
                f"[{sid}] index wordCount={expected} but file has {len(words)} words")

        for w in words:
            term = w.get("word", "")
            short = w.get("shortDefinition", "")
            blob = json.dumps(w).lower()

            for marker in PLACEHOLDER_MARKERS:
                if marker in blob:
                    problems.append(f"[{sid}] '{term}' contains placeholder text ({marker!r})")
                    break

            nt = norm(term)
            if len(nt) >= 4 and nt in norm(short):
                problems.append(f"[{sid}] '{term}' shortDefinition leaks the term itself")

            term_locations.setdefault(nt, []).append(sid)

    # cross-stack duplicates (outside the allowlist)
    for nt, stacks in sorted(term_locations.items()):
        if len(stacks) > 1 and nt not in HOMONYM_ALLOWLIST:
            problems.append(
                f"[dup] term '{nt}' appears in multiple stacks: {', '.join(sorted(set(stacks)))}")

    if problems:
        print(f"✗ {len(problems)} content problem(s):")
        for p in problems:
            print("  -", p)
        return 1

    total = sum(len(json.loads(f.read_text()).get("words", [])) for f in stack_files)
    print(f"✓ Word content clean: {len(stack_files)} stacks, {total} words, "
          f"no stubs / leaks / drift / unexpected duplicates.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
