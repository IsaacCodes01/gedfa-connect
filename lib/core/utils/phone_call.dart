// Starts a phone call, the right way for each platform.
//
// Dart picks ONE of the two files below when the app is built:
// - phone_call_web.dart on the web (dart.library.js_interop exists there)
// - phone_call_io.dart on Android and iOS apps
import 'phone_call_io.dart'
    if (dart.library.js_interop) 'phone_call_web.dart' as platform;

/// Opens the phone's dialler with [phone] (e.g. "+233241234567").
/// Returns false if this device can't make calls.
///
/// Call this DIRECTLY in a button's onPressed, with no `await` before it:
/// iPhone Safari only allows a call link straight from a tap.
Future<bool> callPhone(String phone) {
  // Spaces, dashes and brackets are fine for showing numbers, not for calling
  final number = phone.replaceAll(RegExp(r'[\s\-()]'), '');
  return platform.callPhone(number);
}
