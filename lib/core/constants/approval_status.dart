enum ApprovalStatus {
  pending,
  approved,
  rejected;

  static ApprovalStatus fromString(String value) {
    return ApprovalStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => ApprovalStatus.pending,
    );
  }
}