# Windows permission startup fix

Based on permission_handler_windows 0.2.1 (Baseflow, MIT).
The upstream constructor creates a Geolocator and subscribes to PositionChanged
with an empty callback. Flutter registers it at startup even when the app never
requests location; this can cause Windows to report Modu accessing location.

This adapter removes the locator member and the unused event subscription.
A locator is constructed only inside an explicit location-service status query;
Modu has no such caller. Other method-channel behavior is unchanged.

windows/cmake/modu_permissions.cmake replaces only this plugin's C++ source,
retaining upstream headers, WinRT generation and linking. It does not modify the
pub cache, generated registration files, or Android/macOS implementations.
Review the adapter when upgrading permission_handler_windows.

Run python3 test/windows_permission_startup_test.py for source/build guards.
Native Windows x64/ARM64 builds and a runtime check of Windows location activity
are still required; source guards do not substitute for those checks. Historical
Windows location activity may remain visible after upgrading.
