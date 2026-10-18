package android.content;
public class Intent {
    public static final String ACTION_MEDIA_BUTTON = "android.intent.action.MEDIA_BUTTON";
    public static final String EXTRA_KEY_EVENT = "android.intent.extra.KEY_EVENT";
    private final String action;
    private final Object event;
    public Intent(String action, Object event) { this.action = action; this.event = event; }
    public String getAction() { return action; }
    @SuppressWarnings("unchecked")
    public <T> T getParcelableExtra(String name) {
        if (!EXTRA_KEY_EVENT.equals(name)) throw new AssertionError("Unexpected extra");
        return (T) event;
    }
}
