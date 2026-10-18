package android.view;
public class KeyEvent {
    public static final int ACTION_DOWN = 0;
    public static final int ACTION_UP = 1;
    public static final int KEYCODE_MUTE = 91;
    private final int action;
    private final int code;
    public KeyEvent(int action, int code) { this.action = action; this.code = code; }
    public int getAction() { return action; }
    public int getKeyCode() { return code; }
}
