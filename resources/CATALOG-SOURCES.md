# NPC and dungeon catalog

The bundled JSON contains factual NPC names/IDs, NPC-to-spell associations, English spell labels when available, and independently identified dungeonEncounterIDs. It excludes executable addon code, routes, coordinates, maps and textures. No downloaded Lua is executed by the generator or application.

- Mythic Dungeon Tools: https://github.com/Nnoggie/MythicDungeonTools, revision `2a2df3bb28471ec9900942f1856215f85fdefe31`, eight current `Midnight/*.lua` dungeon enemy tables.
- LittleWigs: https://github.com/BigWigsMods/LittleWigs, revision `0463cc620b4da7c4cd1df155fe082f2dc5589ce2`, corresponding Midnight, Dragonflight and BfA modules. `SetEncounterID` is separate from the journal encounter argument of `NewBoss`; explicitly registered NPCs identify multi-creature bosses. Numeric Bar/CDBar calls are evidence in that source snapshot, not a guarantee for another client or installation.
- Raider.IO: https://github.com/RaiderIO/raiderio-addon/blob/master/db/db_dungeons.lua, generated 2026-10-18, season-mn-2. Instance map IDs and Challenge Mode IDs are stored separately in `core/dungeons.mjs`.

Reproduce from those source checkouts with `node tools/build-npc-catalog.mjs /path/to/MythicDungeonTools /path/to/LittleWigs`. JSON includes exact upstream revisions and source filenames. The snapshot has 248 distinct NPC entries across eight dungeons and 1,029 NPC/spell associations, including non-timer/damage/aura spell variants. Unknown English spell names remain explicit IDs. This is not a complete game database or proof that a cast deserves a defensive.

NSR boss rules use dungeonEncounterID plus timer spell key. ExBoss trash rules use instance map ID plus timer spell key; the current addon does not filter these rules by creature ID. Selection in the catalog cannot create a missing timer. Verify provider and client versions in game.

Method reference URLs are recorded per dungeon. The user-supplied Altar of Fangs screenshot establishes seven important ability/NPC names but no numeric spell IDs. Those rows remain unverified until the user supplies a mapping. The cloud network gateway denied the eight Method pages (HTTP 403); their complete current contents and markup were not validated here. Saved HTML parsing is tested on controlled structural fixtures, never by executing page scripts. No strategy article text is bundled. Local markings are stored outside the application install folder.
