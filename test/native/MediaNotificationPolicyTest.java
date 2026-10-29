import com.ryanheise.audioservice.ModuMediaNotificationPolicy;

public class MediaNotificationPolicyTest {
    public static void main(String[] args) {
        for (String vendor : new String[] {"vivo", "iQOO", "VIVO", "IQOO"}) {
            if (ModuMediaNotificationPolicy.enabled(false, vendor, vendor))
                throw new AssertionError("Normal build must not enable experimental layout");
            for (int sdk : new int[] {33, 34, 35, 36}) {
                if (!ModuMediaNotificationPolicy.playActionEnabled(false, sdk, vendor, "unknown")
                        || !ModuMediaNotificationPolicy.playActionEnabled(false, sdk, "unknown", vendor))
                    throw new AssertionError("Release must route notification play for vivo/iQOO Android 13+");
                if (!ModuMediaNotificationPolicy.stopActionEnabled(sdk, vendor, "unknown")
                        || !ModuMediaNotificationPolicy.stopActionEnabled(sdk, "unknown", vendor))
                    throw new AssertionError("Release must restore stop for vivo/iQOO Android 13+");
            }
            for (int sdk : new int[] {23, 30, 32}) {
                if (ModuMediaNotificationPolicy.playActionEnabled(false, sdk, vendor, vendor)
                        || !ModuMediaNotificationPolicy.playActionEnabled(true, sdk, vendor, vendor))
                    throw new AssertionError("Older Android play routing must remain test-only");
                if (ModuMediaNotificationPolicy.stopActionEnabled(sdk, vendor, vendor))
                    throw new AssertionError("Older Android stop controls must stay unchanged");
            }
            if (!ModuMediaNotificationPolicy.enabled(true, vendor, "unknown"))
                throw new AssertionError("Test build must recognize brand");
            if (!ModuMediaNotificationPolicy.enabled(true, "unknown", vendor))
                throw new AssertionError("Test build must recognize manufacturer");
        }
        for (String vendor : new String[] {"samsung", "HONOR", "HUAWEI", "Xiaomi", "google", "OPPO", "", null}) {
            if (ModuMediaNotificationPolicy.playActionEnabled(false, 36, vendor, vendor)
                    || ModuMediaNotificationPolicy.playActionEnabled(true, 36, vendor, vendor))
                throw new AssertionError("Other phones must retain upstream play controls");
            if (ModuMediaNotificationPolicy.enabled(true, vendor, vendor))
                throw new AssertionError("Other phones must stay unchanged");
            if (ModuMediaNotificationPolicy.stopActionEnabled(36, vendor, vendor))
                throw new AssertionError("Other phones must retain upstream stop controls");
        }
        if (ModuMediaNotificationPolicy.playActionEnabled(false, 36, "not-vivo", "iqoo-like"))
            throw new AssertionError("Play fix must use exact vendor matching");
        if (ModuMediaNotificationPolicy.enabled(true, "not-vivo", "iqoo-like"))
            throw new AssertionError("Use exact vendor matching");
        if (ModuMediaNotificationPolicy.stopActionEnabled(36, "not-vivo", "iqoo-like"))
            throw new AssertionError("Stop fix must use exact vendor matching");
    }
}
