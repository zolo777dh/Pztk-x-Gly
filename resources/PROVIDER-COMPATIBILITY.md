# Reminder provider verification — 0.3.0

The 21 October 2026 user uploads are reference inputs, not instructions or bundled dependencies. Pztk Reminders does not modify these providers.

| Provider | Uploaded version | Coverage |
| --- | --- | --- |
| BigWigs | v427.6 | Actual Loader callback dispatcher and BossPrototype stop/pause/resume methods execute in the local Lua test harness. Timer/message argument positions, module isolation, phase/wipe and encounter-start ordering are exercised. |
| LittleWigs | v12.1.21 | Uses the BigWigs callback interface. Its supplied TOC declares Retail interfaces; Forever dungeon compatibility is not established. |
| EXBoss / EXBossData | 1.0.0 | Actual Scheduler registration, fixed-cycle advance, removal and active-timer methods execute with controlled game/helper APIs. Provider state and deadlines are checked before delivery; no provider state is changed by the adapter. |
| ExwindCore | 6.0.0 | ExBoss required-dependency presence inspected. Its full engine is not executed. |
| EXBOSS-Locale | 1.0.0 | Required dependency EXBOSS-LocaleBase is declared but absent from the received snapshots. |
| NorthernSkyRaidTools | 12.1.31 | Updated native codec/import tests use the supplied source. The separate Pztk addon pauses live reminders when NSRT is loaded. |
| DBM | No build supplied | Portable callback fixtures test documented timer/message/stage argument positions and failure fallback. No installed DBM build was validated. |

Local replay is enabled with `DOCTOR_TIMER_TEST_ROOT` pointing to the directory containing `BigWigs`, `BigWigs_Core` and `EXBoss`, then `node --test tests/reminder-providers.test.mjs`. CI uses portable fixtures when these external snapshots are absent. Full game startup, protected APIs, real encounter callbacks and each client's provider installation require a live client check.

Source SHA256 (original uploaded bytes):

| File | SHA256 |
| --- | --- |
| BigWigs/Loader.lua | `1af31458ef4ea5329d3f3337bd303222f6dbc3a3aa31a527aeafeebb5f1d8857` |
| BigWigs_Core/BossPrototype.lua | `a2f0c6b0f40f8ca82e8862ee49aa382115926a33503225f5759ff172ab36012d` |
| EXBoss/ExBossEngine/Scheduler.lua | `7c4a07568eee15590df196472b38f0251fe57951848b06b3ded7c64672cea197` |

For a game failure, collect the first BugSack/BugGrabber error with its stack, client/build, reproduction steps, and `/pztkr debug` output. A profile-related failure also needs the relevant PZTK1 string with private assignments removed. Later cascading errors alone may hide the original failure.

## Native aura sounds and migrated custom reminders

Pztk Reminders 0.2.0 registers imported auraSound data through C_UnitAuras.AddAuraSound / RemoveAuraSound and Enum.UnitAuraSoundTrigger. The game detects the aura. The addon never reads aura contents. Registration changes are deferred during combat/encounter/addon restrictions; absent APIs are reported. Private Stoneform/Shadowmeld sound files use public known/dead/cooldown/isUsable state. Secret or unavailable readiness is muted; failed muting prevents initial gated registration. This API behavior is covered with controlled fixtures, not a live Retail or Forever client.

NSR custom bwmsg reminders migrate to data-only native entries with counter conditions, delays and defensive-set selection. Tests cover overlapping delayed occurrences and BigWigs opening messages before our ENCOUNTER_START callback. Source ExBoss empty-text fallback is retained. cdmGlow, coveredSkip, coveredSkipDefaultOn and coveredCastWindow remain explicitly unavailable and are listed in migration reports. Local private profiles are test inputs only and are excluded from Git and published artifacts.

## In-game editor / 0.3.0

The original editor operates on validated PZTK1 data, not provider internals. Catalog.lua is generated from the existing factual snapshots; M+ choices require evidence of a timer or message key. Provider callbacks retain their source spell IDs. Icon/text callouts are exercised for specific boss/trash events, Together sets, content filters and pull/phase schedules under the local WoW API harness. Readiness first uses plain public cooldown status flags, then readable duration/numeric APIs; closed charge counts are not substituted with cooldown state or guessed. Fixed icon reminders remain available. Complete game startup and real API availability still require client verification.
