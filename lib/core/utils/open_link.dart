// Opens a web link (e.g. WhatsApp's share link) outside the app.
//
// Same idea as phone_call.dart: Dart picks ONE of the two files below.
// - open_link_web.dart on the web
// - open_link_io.dart on Android and iOS apps
import 'open_link_io.dart'
    if (dart.library.js_interop) 'open_link_web.dart' as platform;

/// Opens [url] in a new tab (web) or the right app (phone).
///
/// Call this DIRECTLY in a button's onPressed, with no `await` before it:
/// iPhone Safari blocks new tabs that don't come straight from a tap.
Future<bool> openLink(String url) => platform.openLink(url);

/// WhatsApp's "share this text" link. WhatsApp opens and lets you pick
/// the chat.
String whatsAppShareLink(String text) =>
    'https://wa.me/?text=${Uri.encodeComponent(text)}';
