Pztk x Glyalith 0.6.2 + Puzatik Reminders 0.3.2

Fixes the editor resetting when opening another page and the empty scroll-list presentation reported in 0.3.1.

- Navigation keeps the selected dungeon/boss, specialization, difficulty, set name/order, pending spell ID, reminder fields, settings draft and scroll position.
- Drafts are local to each client/profile/spec/content section and survive window close and logout/reload. Save set / Save reminder / Save settings explicitly activates a change; unfinished drafts stay outside profile exports.
- UI pools are scoped to the parent. Scroll content has explicit ownership, anchors, visibility and frame levels, and offsets are restored after content sizing.
- Boss-mod source selection updates its visible label. Failed saves preserve inputs and show a plain message. Empty defensive sets cannot be activated.
- Tests exercise all 40 named specialization editors, separate M+/raid sets, Heroic/Mythic mechanic drafts, profile/client isolation, actual SavedVariables serialization with fresh module loading, and native export/import.

Download PztkReminders-0.3.2.zip to update the addon. Close WoW, replace Interface/AddOns/PztkReminders and keep PztkRemindersDB SavedVariables. Open /puzatik or /pztkr. Existing saved profiles stay compatible. NSR/NSRT/TimelineReminders remain disabled while using this engine; BigWigs/LittleWigs and ExBoss remain separate event providers.

The Windows desktop 0.6.2 ZIP includes the same addon. Targets remain Retail 12.1.5.70448 and Forever 1.60.1.70425. No live game session is available: verification covers Lua UI/model/codec/provider scenarios and packaging, not proof of every live encounter.
