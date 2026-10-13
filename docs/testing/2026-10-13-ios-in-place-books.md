# iOS in-place books — issue #35

Request: https://github.com/sobranie2406/modureader/issues/35, suggestion by @wangxxisme.

## Implemented scope

- iOS shelf `+` menu offers opt-in file and folder in-place additions. System picker authorization is required; there is no unrestricted scan of “On My iPhone”.
- EPUB/PDF/MOBI/AZW3/FB2 are opened from the authorized original. TXT/Markdown/UMD still use ordinary import because the reader requires a converted EPUB.
- Folder enumeration includes supported files in subfolders, skips symlinks and hidden files, and supports selecting individual books.
- Native security-scoped bookmarks remain device-local. The database stores an opaque `file/ios-linked-…` identity, not a provider path or bookmark. Folder access scopes are shared across linked books.
- Startup restores access, tolerates unavailable providers, and renews stale bookmarks. Missing files require reselection; matching MD5 preserves the existing book identity and reading position.
- Read paths resolve the original; deletion/replacement/sync/backup continue to use owned app-storage paths. Removing a linked book forgets authorization rather than deleting the original. Covers and configured knowledge indexes still consume storage.
- The original is not automatically uploaded or included in Modu backup ZIPs. Synced metadata or restored backups on another device need original-file selection/import again. Explicit user-requested sharing is still available.
- Existing copied books are not automatically migrated or deleted.

## Automated checks

- Dart channel/model tests cover no-copy path resolution, opaque serialized identity, restored/expired authorization, forgetting without source deletion and format filtering.
- Import selection and existing bookshelf-menu tests cover ordinary import, selection and cancellation. Sync-file, sync-status, backup-safety and reading-link regressions are included.
- `flutter analyze --no-pub` passes.
- The complete `BookFolderPlugin` type-checks against the iOS simulator SDK and Flutter framework (minimum target iOS 16). This is not a full app build or runtime permission test.

## Required physical-device verification (not yet performed)

1. From Files → On My iPhone, add an EPUB and PDF in place; confirm original byte hashes and absence of full copies in app storage.
2. Select a folder with nested books; read two of them and confirm cancelling/unselecting does not change sources.
3. Force-quit/relaunch, reopen both books, exercise PDF reading and book-knowledge indexing.
4. Rename/move/delete a source or revoke provider access. Confirm clear failure, then reselect the same bytes and verify saved reading position.
5. Remove a linked shelf item, replace another with a normal import, and confirm external originals are untouched.
6. Export a backup and sync to another device: no original book bytes or security-scoped bookmarks should be included. Reauthorize/import originals on the destination.
7. Test downloaded iCloud/third-party provider files separately. Provider availability and iOS storage caching are outside Modu's control.
