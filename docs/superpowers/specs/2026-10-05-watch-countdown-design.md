# Watch countdown

The user replaces the remembered-only duration policy with timed auto-off.

- 1h, 3h, and custom minutes create a real deadline when Keep the watch turns on.
- Selecting a duration while off does not start a timer. Changing it while on starts a fresh interval, matching the existing duration selection behavior.
- Opening and closing the lid does not pause, cancel, or restart the deadline.
- At expiry, clear the wake hold and turn Keep the watch off. Preserve the selected duration.
- Request Mac sleep only after kernel release is verified. Recheck the lid immediately before sleep: known open skips sleep; closed or unavailable requests sleep, as explicitly requested by the user.
- This timer-only fallback does not weaken stable-close hygiene or user/inbound off gates.
- Show a seconds countdown in the existing How long card, driven by the same deadline; refresh once per second while the popover is visible. Off shows that arming starts the timer. Agents and infinity have no countdown.
- Use a native deadline timer for expiry, with the existing poll as a fallback. A disarm failure restores the original deadline rather than granting a fresh interval.
- Existing outbound opt-in and saved destinations also apply to expiry. Timer text is “Agrypnos: your watch timer ended.” Agents retains its idle-after-wait text. A bounded POST precedes sleep so the Mac can transmit it. Do not claim sleep or successful disarm in the POST.
- Telegram/Discord status includes actual remaining time only for an armed timed watch.
- Remove the Grok model mandate. Update active product documentation and rules to match this change; keep historical specifications intact.

Automated tests prove decisions and native command ordering. Physical closed-lid sleep, live bot delivery, and popover appearance remain separate Mac checks.
