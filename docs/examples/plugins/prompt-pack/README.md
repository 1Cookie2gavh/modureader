# Example prompt pack

This is a sample Modu plugin. It contains no executable code: `manifest.json`
declares two `aiSkill` contributions, one `selectionAction`, and a small set of
plugin settings. Modu materialises the prompt templates in the AI prompt picker
and the selection action in the selection toolbar.

## Build and install

From the repository root:

```bash
dart run scripts/dev/pack_plugin.dart docs/examples/plugins/prompt-pack
```

The command writes `prompt-pack-1.1.0.moduplugin` next to the source directory.
Open **Settings → Experimental features**, confirm the plugin warning,
then open **Manage plugins → Install plugin…** and select that
file. The two templates then appear in the AI prompt picker, and the selection
action appears in the selection toolbar. Disabling or uninstalling the plugin
removes the contributions it added.

## What is included

- `deep-summary` and `socratic-questions`: AI prompt templates.
- `explain-selection`: a selection-toolbar AI command using `{selection}`.
- Settings: a select, a toggle, a number and a help-only tip. They demonstrate
  the plugin settings form and settings backup. This declarative sample does
  not execute code, so the values are stored but do not change the prompts yet.

## Customise

Modified packages cannot be installed until the project reviews them and ships
their exact ID, version and file SHA-256 fingerprints in its built-in trusted
catalog. Neither an official-looking author URL nor a matching package name
grants trust. To change a prompt for personal use, edit its ordinary AI skill
instead of modifying the package.

## Notes

- The package must stay under 5 MB compressed and 20 MB extracted.
- Every contribution needs a unique, lowercase `id`.
- Selection actions share the 24 custom-toolbar slots with your own commands.
- This repository sample is released under CC0-1.0 and is the initial reviewed
  catalog entry. It is experimental, not a guarantee that AI output is safe.
