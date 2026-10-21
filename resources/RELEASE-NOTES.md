Pztk x Glyalith 0.6.1 + Puzatik Reminders 0.3.1

Fixes the two errors reported when opening the in-game workspace:

- EditBox:SetFont now receives its required flags argument in regular inputs and the profile import/export box. Labels also pass explicit flags, and display text resizing handles fonts without flags.
- Catalog.lua is loaded only once by the TOC, eliminating Duplicate File Load Detected.
- The UI harness now enforces the EditBox font signature and exercises every page for both client workspaces. Packaging refuses duplicate TOC/XML file loads.

Download PztkReminders-0.3.1.zip to update only the addon. Close WoW and replace Interface/AddOns/PztkReminders. Keep PztkRemindersDB SavedVariables and your profiles. Open /puzatik or /pztkr after updating. NSR/NSRT/TimelineReminders remain disabled while using this reminder engine; BigWigs/LittleWigs and ExBoss remain separate providers.

The Windows desktop 0.6.1 ZIP contains the same corrected addon. Targets remain Retail 12.1.5.70448 and Forever 1.60.1.70425. Profile formats are unchanged. Verification uses controlled Lua/UI/provider tests; live-game behavior still needs in-game testing.
