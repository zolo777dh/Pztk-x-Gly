Pztk x Glyalith 0.6.0 + Puzatik Reminders 0.3.0

The addon now has an in-game workspace for creating and editing Mythic+ and raid reminders. The PztkReminders folder / SavedVariables name remains unchanged; the in-game title is Puzatik Reminders.

- Original charcoal/cyan UI with content navigation, named specialization selection, encounter/mechanic lists and Assignment / Display / Conditions editors. Reusable controls avoid creating a new frame tree on every redraw.
- Independent M+ and raid defensive sets per specialization: ordered abilities, Together groups, enable/disable, copy and protected deletion. Old shared sets become separate copies on the first editor save.
- M+: dungeon → NPC/boss → timer/message ability → defensive set. Raid: raid → Heroic/Mythic → boss → mechanic, time from pull or time from phase. Defensive callouts include the selected spell icon(s) and text. Fixed icons, text, sound, countdown, circle, TTS and supported frame glows are configurable.
- In-game profiles: create/copy/rename/delete/select, PZTK1 import/export, direct unlicensed NSRPACK2 and full current NSRT Profile/EncounterAlert migration. Review notes identify unsupported conditions; original source strings and reports remain local. Licensed packs are not bypassed.
- Bundled Retail reference catalogs contain eight M+ dungeons and twenty raid bosses. All 40 spec names are available. Forever uses imported/manual encounters; manual map/NPC/encounter/spell entry is supported.
- Transactional saves validate before replacing a profile. Combat and active-encounter edits are refused. Public cooldown state flags can select a ready defensive without arithmetic on closed timestamps. Unknown charge counts are not treated as ready.
- Desktop native profiles retain separate content sets, edit their reminder assignments and import HTML/JSON sets into an explicitly chosen content collection. Complete export preserves both collections. Legacy NSR-specific editors remain compatibility tools.

Install the addon by replacing Interface/AddOns/PztkReminders while WoW is closed; retain PztkRemindersDB. Open /puzatik or /pztkr. Disable NSR/NSRT/TimelineReminders while using this separate reminder engine. The desktop ZIP also includes the addon ZIP.

Targets: Retail 12.1.5.70448 and Forever 1.60.1.70425. Boss mods and ExBoss are installed separately. Catalog entries cannot create a missing provider event. cdmGlow and coveredSkip-related behavior remains explicitly unavailable. No live WoW session was available: tests cover codec/model/UI flows and controlled provider events, not every in-game behavior. Report the first BugSack error and /pztkr debug output after testing.
