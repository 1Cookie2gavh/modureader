package com.ryanheise.audioservice;

/** Vendor-scoped notification fixes; experimental compact layout stays opt-in. */
public final class ModuMediaNotificationPolicy {
    public static final boolean TEST_BUILD = false;
    // Process-lifetime counters only; no intent, metadata or token contents.
    public static int notificationPlayRequests = 0;
    public static int sessionPlayCallbacks = 0;
    public static boolean enabled(boolean testBuild, String brand, String manufacturer) {
        return testBuild && isVivo(brand, manufacturer);
    }
    public static boolean playActionEnabled(boolean testBuild, int sdk, String brand, String manufacturer) {
        return (testBuild || sdk >= 33) && isVivo(brand, manufacturer);
    }
    public static boolean stopActionEnabled(int sdk, String brand, String manufacturer) {
        return sdk >= 33 && isVivo(brand, manufacturer);
    }
    private static boolean isVivo(String brand, String manufacturer) {
        return "vivo".equalsIgnoreCase(brand)
                || "iqoo".equalsIgnoreCase(brand)
                || "vivo".equalsIgnoreCase(manufacturer)
                || "iqoo".equalsIgnoreCase(manufacturer);
    }
}
