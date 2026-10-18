import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.view.KeyEvent;
import android.support.v4.media.session.MediaSessionCompat;
import com.ryanheise.audioservice.ModuMediaNotificationPolicy;
import com.ryanheise.audioservice.ModuNotificationPlay;

public class NotificationPlayTest {
    private static final Context context = new Context();
    private static final MediaSessionCompat.Token token = new MediaSessionCompat.Token();
    private static final Intent play = new Intent(Intent.ACTION_MEDIA_BUTTON,
            new KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_MUTE));

    private static void check(Intent intent, MediaSessionCompat.Token session, boolean expected) {
        int before = token.plays;
        int requests = ModuMediaNotificationPolicy.notificationPlayRequests;
        if (ModuNotificationPlay.handle(context, intent, session) != expected)
            throw new AssertionError("Incorrect interception");
        if (token.plays - before != (expected ? 1 : 0)
                || ModuMediaNotificationPolicy.notificationPlayRequests - requests != (expected ? 1 : 0))
            throw new AssertionError("Must send exactly one play or leave upstream untouched");
    }

    public static void main(String[] args) {
        boolean testBuild = Boolean.parseBoolean(args[0]);
        for (String vendor : new String[] {"vivo", "iQOO", "samsung", "HUAWEI", "HONOR", "google", null}) {
            Build.BRAND = vendor;
            Build.MANUFACTURER = vendor;
            boolean active = testBuild && ("vivo".equals(vendor) || "iQOO".equals(vendor));
            check(play, token, active);
            check(play, token, active); // Repeated pause/resume must remain available.
            check(null, token, false);
            check(play, null, false);
            check(new Intent("notification-delete", new KeyEvent(0, 91)), token, false);
            check(new Intent(Intent.ACTION_MEDIA_BUTTON, null), token, false);
            check(new Intent(Intent.ACTION_MEDIA_BUTTON, new KeyEvent(KeyEvent.ACTION_UP, 91)), token, false);
            // Pause/record, stop, previous/next, headset and real media play stay upstream.
            for (int code : new int[] {130, 86, 87, 88, 79, 85, 126, 127}) {
                check(new Intent(Intent.ACTION_MEDIA_BUTTON, new KeyEvent(0, code)), token, false);
            }
        }
    }
}
