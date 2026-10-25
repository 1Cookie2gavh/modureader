# Independent font colours and translation panels

- Updated 2026-10-25: removed the duplicate body colour control and override at user request. Body text uses the existing Style palette, including night and E-Ink behaviour; obsolete override preferences are ignored.
- Separate language and Classical Chinese output colours, in their existing appearance models. Existing output and preview update without new translation requests or source-text changes. Colour validation is limited to opaque RGB hex values.
- Theme-style picker, hex input, eight presets including teal #287D75 and blue #287FA3. Cancel discards changes. Reset requires confirmation and changes only colour.
- Reader translation panels use vertical settings rows in the existing rounded group. Both expose a translation-appearance shortcut; the language panel also exposes translation-service configuration. Controls are shared by ordinary and reflow readers.
- Both translation appearance preferences are included in the translation settings-transfer module.

## Validation

- 103 Flutter tests passed for translation appearance, reading appearance, font selection and reflow reading.
- After fixing the narrow picker layout: 64 tests passed for appearance, reader translation settings, global settings transfer, scope transfer and document panel themes.
- After the final panel layout adjustment: 11 tests passed for reader translation settings, translation settings and independent translation controls.
- 10 JavaScript translation lifecycle tests passed, including colour changes / reset without source mutations or repeated requests.
- Targeted Dart analysis and git diff whitespace checks passed. The production reader bundle rebuilt successfully using the existing installed dependencies.
- Initial 2026-10-24 validation did not include packaging or device installation.

## 2026-10-25 body-colour rollback and Android test package

- Removed the duplicate body font-colour preference, UI control, theme override and settings-transfer key. Existing Style palettes remain the source of body text colour. Separate translation colours and shortcuts remain available.
- 154 targeted Flutter tests passed, including obsolete body override handling, translation independence, reflow, and settings transfer. Targeted Dart analysis and whitespace checks passed.
- Built Android ARM64 1.3.3-beta.5 (10162), using the original signing identity. Verified package/version, signature equality with beta.4, ONNX JNI, all seven native libraries and 16 KB ELF/ZIP alignment.
- Delivered `Modu-1.3.3-beta.5-10162-android-arm64.apk` and its SHA-256 file to the user's download folder. No simulator or physical-device installation was performed.
