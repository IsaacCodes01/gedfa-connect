import 'package:web/web.dart' as web;

/// Web version: point the page itself at the tel: link.
///
/// iPhone Safari (and apps added to the Home Screen) ignore tel: links opened
/// as a new window, and can miss Flutter's invisible link. Changing
/// `location.href` during the tap is the plain browser way, the same as
/// tapping <a href="tel:...">, and Safari then shows "Call +233…".
/// The page does not navigate away: the browser hands tel: to the phone app.
Future<bool> callPhone(String number) async {
  web.window.location.href = 'tel:$number';
  return true;
}
