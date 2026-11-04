# What each fix did

Nothing is committed.

Send answers needs the two user ids. Until a Telegram user id and a Discord user id are saved, a question is not offered on that bot. A missing id does not mean everyone in the chat.

1. An unanswered question turns Keep awake off. The lid open leaves the Mac awake. A confirmed closed lid asks the Mac to sleep. No answer is submitted.
2. A Telegram command that arrived while the Mac was asleep is not applied after wake.
3. The scope doc no longer says turning Keep awake on sleeps the display.
4. Quitting with the lid confirmed closed asks the Mac to sleep. Quitting with the lid open does not.
5. If the Mac does not go to sleep, the screen brightness and the keyboard backlight come back.
6. A missing lid reading no longer counts as the lid being open.
7. Only the saved Telegram user and the saved Discord user can Send answers. Those two ids are dotted fields on the Notif card, empty until you fill them in.
8. When a timer or the wait after agent signals stop also asks the Mac to sleep, the Telegram message adds “Asking the Mac to sleep.” Battery, heat, Low Power Mode, and turning Keep awake off yourself still do not send a Telegram message.
9. The Watch-end POST help no longer says Telegram is messaged every time the Mac is asked to sleep. Telegram is the timer and the wait after agent signals stop. Discord also messages when that turn-off will ask the Mac to sleep.
10. Keep awake now says that turning it off with the lid confirmed closed sends the Mac to sleep, and that an open or unconfirmed lid only turns Keep awake off.
11. The question card says the Mac is asked to sleep only when the lid is confirmed closed.
12. Question help no longer says this works in desktop apps.
13. If the app starts again after sleep, a command that arrived while the Mac was asleep still gets “Missed while asleep” and is not applied.
14. Discord can resume on the regional host Discord sends, and still refuses every other host.
15. A slash command in the wrong Discord channel says the command was not applied, and does not turn Keep awake on or off.
16. A question that does not fit on Discord stays on the Mac, and one message says it did not fit.
17. Sleep panel says brightness return only applies when restoring from the floor path.
18. The Discord inbound and Telegram inbound switches now show their names.
19. The scope doc lists OpenCode with the other agents, as local process and session files only, not CPU.
