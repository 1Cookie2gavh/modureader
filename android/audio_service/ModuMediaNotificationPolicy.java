package com.ryanheise.audioservice;

/** Test-build workaround only; do not change other vendors' media surfaces. */
public final class ModuMediaNotificationPolicy {
    public static final boolean TEST_BUILD = false;
    // Process-lifetime counters only; no intent, metadata or token contents.
    public static int notificationPlayRequests = 0;
    public static int sessionPlayCallbacks = 0;
    public static boolean enabled(boolean testBuild, String brand, String manufacturer) {
        return testBuild && ("vivo".equalsIgnoreCase(brand)
                || "iqoo".equalsIgnoreCase(brand)
                || "vivo".equalsIgnoreCase(manufacturer)
                || "iqoo".equalsIgnoreCase(manufacturer));
    }
}
