class FirestorePaths {
  FirestorePaths._();

  static const districtId = 'gomoa-east';
  static const district = 'districts/$districtId';

  static String user(String uid) => '$district/users/$uid';

  static String teamRequest(String uid) => '$district/teamRequests/$uid';
  static String teamName(String key) => '$district/teamNames/$key';
}

class StoragePaths {
  StoragePaths._();

  static String teamRequestLogo(String uid) =>
  '${FirestorePaths.district}/teamRequests/$uid/logo.jpg';
}