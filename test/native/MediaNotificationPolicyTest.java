import com.ryanheise.audioservice.ModuMediaNotificationPolicy;

public class MediaNotificationPolicyTest {
    public static void main(String[] args) {
        for (String vendor : new String[] {"vivo", "iQOO", "VIVO", "IQOO"}) {
            if (ModuMediaNotificationPolicy.enabled(false, vendor, vendor))
                throw new AssertionError("Normal build must not enable workaround");
            if (!ModuMediaNotificationPolicy.enabled(true, vendor, "unknown"))
                throw new AssertionError("Test build must recognize brand");
            if (!ModuMediaNotificationPolicy.enabled(true, "unknown", vendor))
                throw new AssertionError("Test build must recognize manufacturer");
        }
        for (String vendor : new String[] {"samsung", "HONOR", "HUAWEI", "Xiaomi", "google", "OPPO", "", null}) {
            if (ModuMediaNotificationPolicy.enabled(true, vendor, vendor))
                throw new AssertionError("Other phones must stay unchanged");
        }
        if (ModuMediaNotificationPolicy.enabled(true, "not-vivo", "iqoo-like"))
            throw new AssertionError("Use exact vendor matching");
    }
}
