import 'package:gedfa_connect/core/utils/phone.dart';


class Validators {
  Validators._();

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter your email';
    if (!_emailPattern.hasMatch(text)) {
      return "That email address doesn't look right";
    }
    return null;
  }

  static String? newPassword(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Enter a password';
    if (text.length < 8) return 'Use at least 8 characters';
    return null;
  }

  static String? requiredField(String? value, String label) {
    if (value == null || value.trim().isEmpty) return 'Enter $label';
    return null;
  }

    static String? ghanaPhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter a phone number';
    }
    if (normalizeGhanaPhone(value) == null) {
      return 'Enter a valid Ghana number, e.g. 024 123 4567';
    }
    return null;
  }
}