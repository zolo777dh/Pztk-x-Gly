# Transfer and build

The generated ZIPs exist in the cloud workspace and passed archive integrity checks. Workspace links in chat were not downloadable in the user's interface; no binary-attachment upload tool is exposed in this session.

An alternative is an application repository containing this source tree. Its **Actions → Build Windows application → Run workflow** creates a downloadable **Pztk-x-Glyalith-Windows-x64** artifact containing the Windows bundle and checksum. It runs only when manually dispatched, has read-only repository permissions and does not publish a release. Hosting on GitHub still requires a repository destination and write access; the workflow has not run there yet.

For a local Windows source checkout, install Node.js 22+, open PowerShell in the project folder and run `./Build-Windows.ps1`. This also produces the complete Windows ZIP. The external real-addon codec test requires Lua and the addon checkout and is explicitly skipped without those prerequisites; it passed in the original cloud environment.

Do not copy the generated EXE alone: it requires the DLLs and resources beside it. Do not upload the workspace's `.data`, backups, keys, node_modules or test-results directories.
