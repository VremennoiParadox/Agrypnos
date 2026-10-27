# Fix 3 — V1-DOC-01

STATUS: DONE

Doc only. `prd/v1-scope.md`. No Swift. No test. No commit. Fix 1 and Fix 2 are still in the working tree. Acceptance item 6 was not edited.

## Before

User goal:

The display must actually sleep.

Acceptance item 4:

Engage requests real display sleep, keyboard backlight off, brightness floor. Lid-close while engaged re-applies those, not brightness 0 as the sleep method.

## After

Same four sentences in the user goal and in acceptance item 4:

Lid open: turning Keep awake on does not change the display and does not change the keyboard backlight. Confirmed lid close plus Power A: write the brightness floor, keyboard backlight off, panel stays on. This is not display sleep. Confirmed lid close plus Power B: panel sleep only, keyboard backlight off, Keep awake stays on. Power B does not `pmset sleepnow`. Never write the floor and call `displaysleepnow` on the same close.

`displaysleepnow` appears only in that ban. This fix does not call it.

## Left as written

- User goal still says "The keyboard must go dark." That sentence was not one of the two claims.
- Acceptance item 6 still says "Cursor + Claude Code + Codex only." That is Fix 19.
- The old item 4 clause "not brightness 0 as the sleep method" left with the replaced item. This fix did not add a new sentence for it.
