Pztk x Glyalith 0.4.1 + Pztk Reminders 0.1.1

Reminder runtime fixes, checked against the user's BigWigs v427.6, LittleWigs v12.1.21 and ExBoss 1.0.0 source archives. The native PZTK1 format and existing profiles remain compatible.

- BigWigs timer stop/pause now matches the provider's text label and module. Resume reschedules from the paused remaining time; one module cannot cancel another module's reminders.
- Mechanic messages no longer cancel countdowns for the same spell or repeat an already predicted defensive. The first bars survive when BigWigs handles encounter start before this addon. Other encounters cannot move the active phase. Boss wipe/disable, zone and specialization changes clear obsolete schedules.
- ExBoss reads existing active trash timers, verifies source/map/deadline before delivery, cancels removed timers and avoids repeating a delivered alert for a correction to the same cast cycle. Fixed timeline advances can start the next cycle.
- Failed callback registration can retry. DBM fallback is not disabled by a failed BigWigs connection.
- Defensive display fields and target flags are validated in both the desktop and addon before entering runtime callbacks. Missing optional spell/voice information falls back safely. Frame glows have independent ownership keys; nameplate glows use nameplates.
- Text reminder exports omit blank optional spell IDs. The desktop and addon also recover this exact empty-field sentinel in 0.4.0 exports, which the original game decoder could refuse.
- /pztkr debug and the Diagnostics button prepare a copyable build/provider/connection report without player or profile names. Send this with the first BugSack error and stack when reporting a game failure.
- Addon ZIP names and BUILD-SOURCES versions now come from the TOC version. The complete Windows bundle includes PztkReminders-0.1.1.zip.

Replace the PztkReminders folder with the new one while WoW is closed. Do not delete PztkRemindersDB SavedVariables; existing profiles are retained. Keep NSR / NSRT / TimelineReminders disabled while testing this separate addon. Retail 12.1.5.70448 and Forever 1.60.1.70425 targets are unchanged.

The supplied ExBoss version requires EXBossData, ExwindCore and EXBOSS-Locale; EXBOSS-Locale requires EXBOSS-LocaleBase. Install complete providers separately. The uploaded provider snapshots include Retail-only interface declarations and do not establish Forever compatibility. No live WoW session was available: source replay and mocked game API tests verify the covered paths, not every in-game behavior or an unreported BugSack stack.
