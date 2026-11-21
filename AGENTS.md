# perfREV — RS ecosystem

## Platform and scope
- Lua 5.3+ ReaScript for REAPER 6+, native `gfx`; no mandatory extension.
- Keep the app a non-destructive calculator. Never apply values to plugins,
  audio, routing or project tempo without explicit authorization.
- Read `README.md`, `docs/RELEASES.md` and the existing tests before changes.
- Preserve user changes, local materials, old packages and Git history.

## UI and version
- Keep `RS ecosystem` small, centered and non-clickable in the fixed footer.
- Display name/version/build discreetly; authoritative metadata:
  `lib/perfrev_version.lua`. Generated README/header must remain aligned.
- The cathedral theme is local vector drawing, static, without external images
  or animation. Legibility and separation of controls come before decoration.
- RVerb is an example, not a required plugin. Distinguish exact calculations,
  editable choices and plugin-specific advice. Do not invent universal mappings.

## Git and release safety
- Never stage, commit, tag, push, change repository visibility or publish without
  explicit authorization. A push request is not a GitHub Release authorization.
- Track sources, tests, tools, instructions and necessary resources only.
  `materiale/`, `dist/`, build output, caches, credentials and local data stay out.
- Never modify `.git` manually or discard unknown user work.
- Update source release notes for features; packaging/publication is separate.
- Archive new authorized packages under `dist/releases/vX.Y.Z/`, with the
  version/build in the ZIP name, actual `.zip.sha256` and `release.json`.
  Keep historical ZIPs in their original paths; do not move them retroactively.
- `release.json` records version/build, artifact name/size/SHA-256 and
  `source_commit: null` unless exact provenance has been verified.
- `tools/prepare_release.py` prepares an archive from an existing package only;
  it must not build, run Git, use the network or overwrite differing archives.
  See `docs/RELEASES.md`. Tests may create temporary fixtures only.
- Source version and latest actually packaged version can differ. Do not claim
  a build, installer, checksum, visual REAPER test or upload that did not happen.

## Verification
- Run Lua calculation/UI tests and Python tooling tests. Report actual outcomes.
- Test cancellation, invalid inputs, range warnings and preserved preferences.
- Check Git diffs, ignored local data and version coherence before finishing.
