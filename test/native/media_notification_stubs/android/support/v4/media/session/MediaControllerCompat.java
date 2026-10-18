package android.support.v4.media.session;
import android.content.Context;
public class MediaControllerCompat {
    private final MediaSessionCompat.Token token;
    public MediaControllerCompat(Context context, MediaSessionCompat.Token token) { this.token = token; }
    public TransportControls getTransportControls() { return new TransportControls(); }
    public class TransportControls {
        public void play() { token.plays++; }
    }
}
