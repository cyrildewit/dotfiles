# MacsyZones

Layouts and settings are synced. Per-machine state is not, since it keys on
display IDs and Space numbers that mean nothing on another Mac. What is synced
is whatever `home/dot_config/macsyzones/` holds; the symlinks under
`home/private_Library/` are one per file for that reason.

> **Do not give `MeowingCat.MacsyZones/` the `exact_` attribute.** The
> directory holds unsynced files alongside the two symlinks, and `exact_` would
> delete them: `SpaceLayoutPreferences.json`, `UpdateState.json` and
> `OnboardingState.json`.
