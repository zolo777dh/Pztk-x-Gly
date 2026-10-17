# Third-party components

This prototype bundles Electron and npm dependencies with their original package license files. Electron/Chromium distribution notices are retained beside the executable.

- **LibStub**, by Kaelten, Cladhaire, ckknight, Mikk, Ammo, Nevcairiel and joshborke: public domain, as declared in `resources/codec/LibStub.lua`.
- **LibSerialize**, copyright (c) 2020 Ross Nichols: MIT license. The complete permission and warranty notice remains at the top of `resources/codec/LibSerialize.lua`. Used inside Fengari to encode/decode the existing Smart Reminders wire format.
- **LibDeflate**, Haoqian He / SafeteeWoW: its complete license is retained in `resources/codec/LibDeflate-LICENSE.txt` and its source notices remain unchanged. The original library is retained for compatibility testing; application compression uses Node's standard raw DEFLATE.
- **Fengari**, Lua in JavaScript: MIT.
- **React**, **lucide-react**, **luaparse**, **fflate**, **htmlparser2**, **diff**: their notices are included with the installed production packages.

The supplied addon source code is not redistributed as part of the executable's working data. Only the independently licensed codec libraries above and a disposable demonstration addon are bundled. The supplied Holy Paladin HTML is included as an example of reference-document parsing, not as verified game data or normative cooldown advice. Original addon license and pack-license restrictions are not changed by this application.
