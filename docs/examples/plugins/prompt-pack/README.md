# Example prompt pack

This is a sample Modu plugin. It contains no executable code: `manifest.json`
declares two `aiSkill` contributions, and Modu materialises them as ordinary AI
prompt templates.

## Build and install

From the repository root:

```bash
dart run scripts/dev/pack_plugin.dart docs/examples/plugins/prompt-pack
```

The command writes `prompt-pack-1.0.0.moduplugin` next to the source directory.
Open **Settings → More settings → Plugins → Install plugin…** and select that
file. Both templates then appear in the AI prompt picker. Disabling or
uninstalling the plugin removes the templates it added.

## Customise

Edit the `prompt` fields in `manifest.json`, bump `version`, repack, and install
again. Keep `id` stable so an upgrade replaces the old prompts instead of
adding duplicates.

## Notes

- The package must stay under 5 MB compressed and 20 MB extracted.
- Every contribution needs a unique, lowercase `id`.
- This sample is released under CC0-1.0 and is not an officially supported
  plugin.
