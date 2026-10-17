# Transfer and build

The generated ZIPs exist in the cloud workspace and passed archive integrity checks. Workspace links in chat were not downloadable in the user's interface; no binary-attachment upload tool is exposed in this session.

An alternative is the application repository `zolo777dh/Pztk-x-Gly`. A push to `main`, or **Actions → Build Windows application → Run workflow**, creates a downloadable **Pztk-x-Glyalith-Windows-x64** artifact containing the Windows bundle and checksum. A successful build publishes the version's Windows ZIP to GitHub Releases using the workflow's repository-scoped token. Existing release assets are preserved; bump the application version for a new release. Hosting still requires repository write access; the workflow has not run there yet. Public visibility enabled read access, but a Git push dry run still returned HTTP 403 permission denied.

For a local Windows source checkout, install Node.js 22+, open PowerShell in the project folder and run `./Build-Windows.ps1`. This also produces the complete Windows ZIP. The external real-addon codec test requires Lua and the addon checkout and is explicitly skipped without those prerequisites; it passed in the original cloud environment.

Do not copy the generated EXE alone: it requires the DLLs and resources beside it. Do not upload the workspace's `.data`, backups, keys, node_modules or test-results directories.
