# Third-party components

This prototype bundles Electron and npm dependencies with their original package license files. Electron/Chromium distribution notices are retained beside the executable.

- **LibStub**, by Kaelten, Cladhaire, ckknight, Mikk, Ammo, Nevcairiel and joshborke: public domain, as declared in `resources/codec/LibStub.lua`.
- **LibSerialize**, copyright (c) 2020 Ross Nichols: MIT license. The complete permission and warranty notice remains at the top of `resources/codec/LibSerialize.lua`. Used inside Fengari to encode/decode the existing Smart Reminders wire format.
- **LibDeflate**, Haoqian He / SafeteeWoW: its complete license is retained in `resources/codec/LibDeflate-LICENSE.txt` and its source notices remain unchanged. The original library is retained for compatibility testing; application compression uses Node's standard raw DEFLATE.
- **Fengari**, Lua in JavaScript: MIT.
- **React**, **lucide-react**, **luaparse**, **fflate**, **htmlparser2**, **diff**: their notices are included with the installed production packages.
- **bgmt x warcraftlogs lab**: not bundled by this repository's build. Do not add this third-party executable to a release unless its author has given permission to redistribute it.

The supplied addon source code is not redistributed as part of the executable's working data. Only the independently licensed codec libraries above and a disposable demonstration addon are bundled. The supplied Holy Paladin HTML is included as an example of reference-document parsing, not as verified game data or normative cooldown advice. Original addon license and pack-license restrictions are not changed by this application.

## In-game addon (addon/NaowhDefensivePlanner)

The addon bundles only LibStub (public domain), LibSerialize (MIT), LibDeflate (zlib) and LibCustomGlow-1.0 (MIT), each with its notice, and the URW Gothic fonts (AGPL with font exception). LibGetFrame-1.0 (GPL-2.0) and CallbackHandler-1.0 were removed in 0.7.2; raid frames are now found by the addon's own code. The seven NSR voice clips were removed in 0.7.2 in favour of the game's text-to-speech and built-in sounds. Encounter facts used from BigWigs, LittleWigs, EXBoss, Mythic Dungeon Tools and Raider.IO are credited in `addon/NaowhDefensivePlanner/CREDITS.txt`; none of their code is included. Since 0.8.0 the addon bundles no Timeline Reminders or Northern Sky Raid Tools data: the expected timelines, ability categories and the NSRT-derived raid boss list were removed, and raid bosses, abilities and categories are read from the game's Encounter Journal. The desktop planner's `resources/raid-catalog.json` is still built from NSRT BossData and is not shipped in the addon.
