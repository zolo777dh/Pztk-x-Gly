# Pztk x Glyalith 0.3.0 — application capabilities

Pztk x Glyalith is a standalone Windows desktop application for maintaining World of Warcraft addons and preparing defensive reminder profiles. It brings addon files, imported runtime errors, static diagnostics, AI-assisted development, code review, backups, NSR profiles and native NSRT raid profiles into one workspace.

Its primary addon projects are NaowhForever and its separately installed modules, plus Naowh Smart Reminders. The source workflow also works with other connected Lua / TOC / XML addon folders. The application itself runs outside World of Warcraft.

## Game clients and projects

The application has separate target profiles for Retail 12.1.5.70448 and Forever 1.60.1.70425. The selected target is included in diagnostics and AI requests. NSR and NSRT working profile lists are separated by game client; the active NSR draft is separate too.

You can connect several addon folders in one action or select their common parent directory to discover modules. This supports the normal WoW installation layout where NaowhForever, NaowhForever_Combat, NaowhForever_QoL, NaowhForever_JourneysData and other modules live beside each other. Project context can cover several selected modules together.

The Addons list supports Ctrl+A, Ctrl+click, Shift+click and Shift+drag selection. Right-click Refresh rereads connected folders and discovers changes. Delete folder removes the application entry without deleting the addon on disk. The list starts empty each time the application launches, while saved tasks, profiles and backups remain available. Reconnecting the original folder restores its identity for saved tasks.

## Diagnostics and source editing

Scan processes all selected addon projects under the selected client profile and presents findings with their addon, file and line. Current checks cover Lua 5.1 syntax, TOC interface declarations, missing files referenced by TOC/XML loaders and selected legacy API migration candidates. API rules are advisory; a clean scan does not establish complete compatibility with a particular WoW build.

BugSack / BugGrabber error text and saved error data can be imported. The app matches reported paths to connected files and retains the stack trace for investigation. This uses exported data or the game's last saved variables, not live game memory. Ambiguous file matches remain unresolved rather than being assigned to an arbitrary source.

The source editor supports full-file review, validation, diff preview, backup and apply. Ctrl+F searches the open file. Ctrl+Shift+F searches across connected addon folders, with results that open the matching source. Existing editor drafts are retained while navigating between files during the current session. Original encoding markers and line endings are preserved during supported writes.

## AI Workspace

The AI Workspace provides saved tasks and conversations. A task records its selected projects, game target, user messages, prepared requests, assistant replies, proposed changes and application activity. You can discuss an error, request a feature, ask for an explanation or continue an earlier task.

Context preparation indexes connected Lua, TOC and XML files. It considers the selected file, imported stack trace, request keywords, loader dependencies and lexical matches between function definitions and calls. It selects bounded excerpts instead of attaching an entire addon. The Context tab shows source fragments, file locations, loader references, candidate symbol relationships, warnings and the complete outgoing request.

These relationships assist source review. They are not a full runtime model of Lua namespaces, addon initialization or game API availability. The assistant is instructed to distinguish source evidence from assumptions and request missing information when required.

Preparing context does not transmit a request. You inspect it first, then choose browser transfer or explicitly send it to a configured API. Replies can explain the issue without proposing a change, or provide exact anchored edits for multiple files.

## ChatGPT and Claude through your website account

Browser mode can display ChatGPT or Claude in a panel inside the desktop application. You sign in using the provider's website and use the account features available there. The website panel has its own persistent browser session and does not receive the app's filesystem bridge.

The exchange remains manual: copy the prepared request, paste it into the website, then copy the structured JSON reply back into the task or load it from a file. You stay in the application when the provider supports embedded login. An external browser remains available if authentication or site policy prevents that.

Browser mode requires no API key. Your subscription and website limits apply. It does not convert a ChatGPT / Claude subscription into API credit, automate the website account or silently read conversations. Provider login and authenticated conversations were not verified with a user's account during development.

## Local and cloud API modes

Local mode connects to a separately running OpenAI-compatible model server, such as an appropriately configured Ollama server. Cloud mode supports OpenAI, Anthropic and OpenAI-compatible endpoints. Both use the same prepared context, conversation and change-review workflow as browser mode.

Settings can request the supported model list using your endpoint and personal API key. The cloud picker uses the returned list rather than showing a universal hardcoded catalog. Provider account permissions, quotas and generation access still determine whether a request succeeds. A model-list result alone cannot guarantee a successful generation.

The reviewed request pins its provider, endpoint and model. Changing these requires preparing the request again. Cloud API credentials are retained only in memory for the current application session; ordinary settings and model choices persist. Website subscriptions and API billing remain separate services.

## Reviewing and applying code changes

An assistant can propose changes across several selected addon modules and create new Lua, TOC or XML files inside existing directories. Changes identify the exact project, relative file and unique source anchor. New files require complete source. File deletion and directory creation are outside this workflow.

Before applying a proposal, the app checks that the reply targets the selected projects, that existing edits match supplied source excerpts, that anchors are unambiguous and that original source hashes still match. Lua changes are syntax-checked. The Changes tab shows per-file diffs and allows you to select which files to accept.

Backup & apply creates and reads back a ZIP backup before writing. Existing files retain their exact original backup bytes. New files are recorded as previously absent. If a later write fails, earlier writes in the task are rolled back. A file that appears after a new-file preview is not overwritten.

Validate task projects reruns static diagnostics. Restore task backup restores the original files and removes task-created files only when their current contents still match the applied version. Later user edits block recovery instead of being discarded. A recovery snapshot is also saved before task restoration. These mechanisms help recover source changes; they do not prove correct game behavior.

## NSR Defensive Planner: Mythic+

The main workflow is specialization → dungeon → NPC / boss → ability → defensive set. All 40 specialization choices use readable names mapped to their IDs. Spell names are shown where available, with IDs retained for accurate bindings. Unknown names remain explicit rather than invented.

The bundled Retail Mythic+ catalog covers Murder Row, Den of Nalorakk, The Blinding Vale, Voidscar Arena, Altar of Fangs, Ruby Life Pools, Temple of Sethraliss and Kings' Rest. Its source-based associations use the supplied LittleWigs / EXBossData references and documented seasonal sources. The selectable catalog contains 249 NPC entries and 800 NPC–ability associations. Normal / Heroic-only variants are excluded where identified by those sources, and known duplicate mechanic variants are grouped.

The distinction between spell ID, timer key, dungeon encounter ID, instance map ID and Challenge Mode ID is retained. A catalog entry does not create an absent boss-mod event. Mythic+ trash rules require the appropriate NSR / ExBoss integration; the current addon filters these by map and timer key rather than a separate NPC ID.

## Defensive sets and shared NSR profiles

You can import an existing compatible NSRPACK2 profile, import HTML / JSON references containing defensive sets or create sets manually. The importer reads supported structured data and static defensive tables from the document. It is independent of the filename and class: Holy Paladin, Restoration Shaman and other specializations use the same pipeline. An arbitrary web page without identifiable defensive sets is not guaranteed to be importable.

Sets can be named, edited and ordered, including supported Together combinations. Imported notes and labels are retained where represented by the supported schema. A set can be assigned to a selected mechanic and specialization; assignments save locally.

Defensive Planner and Raid Planner edit one shared NSR working profile. Export NSR produces one NSRPACK2 string containing its configured Mythic+ boss, trash and raid rules across the configured specializations. Import that string into Naowh Smart Reminders in game. The application preserves licensing constraints and does not unlock account-licensed packs.

## Raid Planner and native NSRT profiles

The bundled Retail raid reference contains 20 bosses across two supplied Midnight seasons. Heroic and Mythic filters control the mechanics shown. Shared NSR encounter / spell bindings use the same assignment. Source aliases are applied where confirmed; unverified timer relationships still need checking against the installed boss mod.

Native NSRT profile management is available from Raid Planner. It imports and exports the current !NSRT:Profile: and full !NSRT:EncounterAlert: formats using an independent CBOR / Deflate implementation. Imported unknown fields, binary values and numeric Lua keys are preserved. Single / group alert exports can roundtrip, but visual editing requires a full alerts export.

The visual editor supports encounter ID, Heroic / Mythic difficulty, specialization, enabled state, boss mechanic ID metadata, defensive icon spell ID, text and phase-relative reminder times. Leaving the specialization blank retains imported load conditions. Choosing a specific specialization restricts the reminder to it. You can add, modify or remove reminders and restore the previous saved profile version.

Build NSRT profile uses the shared NSR raid assignments and factual phase schedules from the supplied NSRT reference. It creates a separate native profile, optionally copying an existing NSRT profile's settings and other alerts first. The result reports generated reminders and skipped assignments so incomplete coverage can be reviewed before export.

NSRT reminders display the assigned set as text with its first spell icon. They do not recreate NSR's dynamic cooldown-based defensive priority selection. Export NSRT profile creates a separate NSRT string for importing into Northern Sky Raid Tools. Its shared-data import may require confirmation in the addon.

The application can coordinate both addons in one workflow, but NSR and NSRT require their respective native import strings. It does not produce one interchangeable string for both addons.

## Data, compatibility and verification

Tasks, prepared context, imported profiles, history and backups are stored locally. Prepared tasks therefore contain copies of the source excerpts included in those requests. Website sessions persist separately. API keys are session-only. Browser or cloud use sends the context you choose to transfer to that provider; local mode sends it to the configured local endpoint.

The built-in dungeon, boss and schedule catalog is Retail Midnight data. Forever has a separate workspace for source work and imported / manually configured profile data. The app does not assume that Retail mechanics or a particular NSR addon release work unchanged in Forever.

WCL / BGMT parsing, log timing averages and live combat monitoring are absent from this version. The application does not press abilities, inject into WoW, install profiles into live game memory or automatically publish local addon edits to GitHub. Profiles are exported and imported through the addons' own interfaces.

Validation covers source hashing, syntax, multi-file recovery, persistence, HTML/profile handling, UI workflows and native addon decoding/import paths. Runtime behavior, combat restrictions, boss-mod event availability and reminder timing still need testing inside the installed game client.
