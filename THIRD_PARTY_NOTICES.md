# Third-party components

This prototype bundles Electron and npm dependencies with their original package license files. Electron/Chromium distribution notices are retained beside the executable.

- **LibStub**, by Kaelten, Cladhaire, ckknight, Mikk, Ammo, Nevcairiel and joshborke: public domain, as declared in `resources/codec/LibStub.lua`.
- **LibSerialize**, copyright (c) 2020 Ross Nichols: MIT license. The complete permission and warranty notice remains at the top of `resources/codec/LibSerialize.lua`. Used inside Fengari to encode/decode the existing Smart Reminders wire format.
- **LibDeflate**, Haoqian He / SafeteeWoW: its complete license is retained in `resources/codec/LibDeflate-LICENSE.txt` and its source notices remain unchanged. The original library is retained for compatibility testing; application compression uses Node's standard raw DEFLATE.
- **Fengari**, Lua in JavaScript: MIT.
- **React**, **lucide-react**, **luaparse**, **fflate**, **htmlparser2**, **diff**: their notices are included with the installed production packages.
- **bgmt x warcraftlogs lab 0.13.0**: the Windows x64 executable supplied for this integration is bundled unchanged as a compressed resource. It is invoked through its existing headless CLI; no ownership or license change is asserted. Its original SHA256 is `e6112185b625dd4e3caf595a0e6ae33f9e344459df27308764a469560300ea16`. The self-contained .NET runtime and original application resources remain in that executable.

The supplied addon source code is not redistributed as part of the executable's working data. Only the independently licensed codec libraries above and a disposable demonstration addon are bundled. The supplied Holy Paladin HTML is included as an example of reference-document parsing, not as verified game data or normative cooldown advice. Original addon license and pack-license restrictions are not changed by this application.
