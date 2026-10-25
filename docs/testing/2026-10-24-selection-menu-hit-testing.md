# Cross-page handle blocked by transparent menu layout

## Evidence

- User's beta.3 Android recording: selection returns from page 2 to page 1; the leading handle remains at the bottom right, while the visible action menu sits at the left. No successful subsequent extension is visible.
- An isolated Chromium page using the current smart-selection and selection-navigation modules, a horizontally paginated iframe, and browser-dispatched touch events can turn backward, release, and drag the landing handle again. This checks browser behavior only, not the complete app or the user's WebView.
- The Flutter menu uses an expanded layout to allocate action capacity. Its outer transparent-colored container and PointerInterceptor covered that entire allocation, including unpainted space beside the actual toolbar. This can intercept a visible WebView handle even when no painted button overlaps it.
- Regression against the pre-fix hit-testing layout failed for both horizontal and vertical menus: dragging outside the painted buttons but within the menu allocation delivered zero drag updates to the reader underneath.

## Change and verification

- Remove the outer colored hit target; retain menu sizing and placement.
- Move native pointer interception onto the actual action, annotation, and note surfaces, preserving shielding for their controls on iOS/web as well as Flutter hit testing.
- Exercise the production overlay in a widget test: blank-area gestures reach the underlying reader; native interceptor rectangles exclude the same point; painted buttons still block reader drags; Copy still dispatches the selected text and closes the menu.
- Keep the existing selection/navigation logic unchanged in this fix.
- All 48 targeted widget tests passed (menu hit testing, toolbar settings/actions, annotation deletion, note conflict handling and annotation colors). Targeted Flutter analysis reported no issues; `git diff --check` passed.

No simulator or physical device was operated. The user's Xiaomi result still needs verification with a new APK; beta.3 does not contain this menu fix. No package, install, push, or release is part of this change.
