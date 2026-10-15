class FirestorePaths {
  FirestorePaths._();

  static const districtId = 'gomoa-east';
  static const district = 'districts/$districtId';

  static String user(String uid) => '$district/users/$uid';
}