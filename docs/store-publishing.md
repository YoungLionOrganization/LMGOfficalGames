# Publish to the LeoMiniGames store

From the repository root, check all local versions against the public catalog.

```sh
python tools/publish_games.py
```

To publish new games and newer versions, run

```sh
python tools/publish_games.py --publish --rcc /path/to/rcc
```

Pass a game folder such as `harvest_pocket` to check or publish just that game.
On Windows, give `--rcc` the path to `rcc.exe`. You can omit it if `rcc` is on
`PATH` or `LMG_RCC` points to it.

The command reads `raw_admin_token` from the directory beside the repository
when there is a release to publish. Use `--token-file` for a different location.
A version check uses the public catalog and requires neither the token nor Qt.

Versions are compared numerically as `major.minor.patch`. The command skips
equal or older local versions. Pocket Factory Community is distributed through GitHub and is excluded from store publishing.

For each pending release, the command validates and builds the RCC, uploads it
and its icon, updates the store listing, and confirms the version and SHA-256.
If a release fails, the command exits with an error. Rerun the version check
to see which releases are still pending.
