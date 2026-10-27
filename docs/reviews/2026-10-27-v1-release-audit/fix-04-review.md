# Fix 4 review

Two delegated reviews stalled before a verdict. Parent read the quit path.

- spec: PASS
- quality: Approved

`userOffSleepDecided` is set only when a user-off defers for a send that will sleep (`WatchRuntime+Poll.swift:397`). It is cleared when that task applies the sleep (`:408`), when the user-off does not defer (`:417`), on every `prepareForTermination` exit (`WatchRuntime+Kernel.swift:76`, `:83`, `:88`), on a new arm (`WatchRuntime.swift:377`), and when a wake-hold reassertion fails (`:443`). A later arm cannot inherit it.

Confirmed-closed quit applies `[.requestSleep]` through the existing `apply` path after the kernel clear, and only if `userOffLidCloseConfirmed` is still true. Open or unconfirmed does not. A failed kernel clear does not sleep. No sudo. No second sleep function.

`ownsWakeHold` is settable so the Mac test can enter terminate. `start()` is still the production writer. Not a second sleep stack.

The failed-`sleepnow` brightness drop is Fix 5 and was left alone.
