String? normalizeGhanaPhone(String input) {
  final digits = input.replaceAll(RegExp(r'[\s\-()]'), '');

  String? local;
  if (digits.startsWith('+233')) {
    local = digits.substring(4);
  } else if (digits.startsWith('233')) {
    local = digits.substring(3);
  } else if (digits.startsWith('0')) {
    local = digits.substring(1);
  }

  if (local == null) return null;
  if (!RegExp(r'^[1-9]\d{8}$').hasMatch(local)) return null;

  return '+233$local';
}