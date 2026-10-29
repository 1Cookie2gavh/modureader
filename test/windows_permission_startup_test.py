"""Source/build guards; Windows runtime verification is still required."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
ADAPTER = ROOT / 'third_party/permission_handler_windows/permission_handler_windows_plugin.cpp'


class WindowsPermissionStartupTest(unittest.TestCase):
    def test_registration_has_no_locator_or_position_subscription(self):
        source = ADAPTER.read_text()
        startup = source.split('void PermissionHandlerWindowsPlugin::HandleMethodCall', 1)[0]
        self.assertIn('PermissionHandlerWindowsPlugin::PermissionHandlerWindowsPlugin() = default;', startup)
        self.assertNotRegex(startup, r'\bGeolocator\b')
        self.assertNotIn('PositionChanged', source)
        self.assertNotIn('GetGeopositionAsync', source)
        self.assertNotIn('RequestAccessAsync', source)

    def test_locator_is_scoped_to_explicit_service_query(self):
        source = ADAPTER.read_text()
        method = source.split('void PermissionHandlerWindowsPlugin::IsLocationServiceEnabled(', 1)[1]
        method = method.split('winrt::fire_and_forget', 1)[0]
        self.assertIn('const Geolocator geolocator;', method)
        self.assertIn('geolocator.LocationStatus()', method)
        self.assertEqual(len(re.findall(r'\bGeolocator\b', source)), 1)
        # The reader itself must never request location through this channel.
        for path in (ROOT / 'lib').rglob('*.dart'):
            self.assertNotRegex(path.read_text(), r'Permission\.location(?:Always|WhenInUse)?\b', str(path))

    def test_build_replaces_upstream_source_after_target_creation(self):
        cmake = (ROOT / 'windows/CMakeLists.txt').read_text()
        self.assertLess(cmake.index('include(flutter/generated_plugins.cmake)'),
                        cmake.index('include(cmake/modu_permissions.cmake)'))
        patch = (ROOT / 'windows/cmake/modu_permissions.cmake').read_text()
        self.assertIn('if(NOT TARGET permission_handler_windows_plugin)', patch)
        self.assertIn('set_property(TARGET permission_handler_windows_plugin PROPERTY SOURCES', patch)
        self.assertIn('third_party/permission_handler_windows/permission_handler_windows_plugin.cpp', patch)
        self.assertIn('"${MODU_PERMISSION_SOURCE_DIR}"', patch)
        self.assertIn('"${MODU_PERMISSION_SOURCE_DIR}/include"', patch)

    def test_existing_permission_protocol_and_license_remain(self):
        source = ADAPTER.read_text()
        for token in ['flutter.baseflow.com/permissions/methods',
                      'PermissionHandlerWindowsPluginRegisterWithRegistrar',
                      'checkServiceStatus', 'checkPermissionStatus',
                      'requestPermissions', 'IsBluetoothServiceEnabled',
                      'openAppSettings']:
            self.assertIn(token, source)
        self.assertIn('Copyright (c) 2018 Baseflow', (ADAPTER.parent / 'LICENSE').read_text())


if __name__ == '__main__':
    unittest.main()
