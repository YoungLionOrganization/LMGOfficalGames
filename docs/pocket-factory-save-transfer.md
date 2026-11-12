# Transfer a Pocket Factory GPL 3.2 desktop save

Install Pocket Factory Community 4.0 and close LeoMiniGames before opening the game.
Install the Python dependency and run the transfer from the repository root.

```sh
python -m pip install cbor2
python tools/transfer_pocket_factory_save.py /path/to/saves/pocket_factory/autosave.lmgsave /path/to/saves
```

Use the LeoMiniGames profile's actual saves directory. The tool validates the original
schema-2 GPL save and its checksum before copying it into
`pocket_factory_community/autosave.lmgsave`. It preserves the source file and
refuses to replace a Community autosave or backup. The destination filesystem
must support hard links. Open Community to finish the schema migration.

Megafactory saves remain under `pocket_factory`.
