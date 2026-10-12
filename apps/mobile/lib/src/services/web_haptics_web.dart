import 'dart:js_interop';

@JS('navigator.vibrate')
external JSAny? _vibrate(JSNumber duration);

void vibrate(int durationMs) {
  try {
    _vibrate(durationMs.toJS);
  } catch (_) {
    // The Web Vibration API is optional and unsupported on desktop browsers.
  }
}
