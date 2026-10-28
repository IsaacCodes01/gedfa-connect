import 'package:cloud_firestore/cloud_firestore.dart';

/// How a club paid (2.13c).
enum PaymentMethod {
  momo('MoMo or bank transfer', 'Enter the transaction ID from the message.'),
  cash('Paid in cash',
      "No receipt? That's fine: the FA confirms from its own list."),
  before('Already paid this season',
      'Paid before this app. The FA fills in the amount from its records.');

  const PaymentMethod(this.label, this.description);

  final String label;
  final String description;

  /// Short text for lists: "MoMo", "Cash", "Paid before".
  String get shortLabel => switch (this) {
        PaymentMethod.momo => 'MoMo',
        PaymentMethod.cash => 'Cash',
        PaymentMethod.before => 'Paid before',
      };

  static PaymentMethod fromString(String? value) => PaymentMethod.values
      .firstWhere((m) => m.name == value, orElse: () => PaymentMethod.momo);
}

/// Waiting for the FA, confirmed (with a receipt) or not found.
/// Payments are never rejected: "not found" is only for an ID that isn't
/// on the FA's statement, or details that are false.
enum PaymentStatus {
  waiting,
  confirmed,
  notFound;

  static PaymentStatus fromString(String? value) => PaymentStatus.values
      .firstWhere((s) => s.name == value, orElse: () => PaymentStatus.waiting);
}

/// The receipt number the FA's confirmation gives: 'GEDFA-2026-0014'.
/// The security rules build the same text (receiptNoFor in
/// firestore.rules), so both must stay the same.
String receiptNoFor(int number, int seasonStartYear) =>
    'GEDFA-$seasonStartYear-${number.toString().padLeft(4, '0')}';

/// One payment towards a club's season fee (`payments/{id}`).
class Payment {
  const Payment({
    required this.id,
    required this.requestUid,
    required this.teamName,
    required this.season,
    required this.method,
    required this.status,
    this.teamId,
    this.amount,
    this.reference,
    this.paidOn,
    this.paidWhen,
    this.paidTo,
    this.proofUrl,
    this.receiptNo,
    this.reason,
    this.recordedByFa = false,
    this.createdAt,
    this.reviewedAt,
    this.editedAt,
  });

  final String id;

  /// The club's account (the team request's ID).
  final String requestUid;

  /// Set once the team exists (payments made after approval).
  final String? teamId;
  final String teamName;

  /// '2026-27'
  final String season;
  final PaymentMethod method;
  final PaymentStatus status;

  /// GH₵, whole cedis. Null for "already paid" until the FA fills it in.
  final int? amount;

  /// MoMo / bank transaction ID.
  final String? reference;

  /// MoMo / bank: the day it was paid.
  final DateTime? paidOn;

  /// Cash: "about when", in the club's words (optional).
  final String? paidWhen;

  /// Cash: who received it (optional).
  final String? paidTo;

  /// Screenshot of the payment message (optional).
  final String? proofUrl;

  /// Set when the FA confirms.
  final String? receiptNo;

  /// Set when the FA marks it not found.
  final String? reason;

  /// Cash the FA recorded itself (confirmed straight away).
  final bool recordedByFa;
  final DateTime? createdAt;
  final DateTime? reviewedAt;

  /// Set when the FA corrected the amount of cash it recorded.
  final DateTime? editedAt;

  bool get isWaiting => status == PaymentStatus.waiting;
  bool get isConfirmed => status == PaymentStatus.confirmed;

  /// Waiting or confirmed: still counts. A "not found" one doesn't.
  bool get isActive => status != PaymentStatus.notFound;

  factory Payment.fromMap(String id, Map<String, dynamic> data) => Payment(
        id: id,
        requestUid: data['requestUid'] as String? ?? '',
        teamId: data['teamId'] as String?,
        teamName: data['teamName'] as String? ?? '',
        season: data['season'] as String? ?? '',
        method: PaymentMethod.fromString(data['method'] as String?),
        status: PaymentStatus.fromString(data['status'] as String?),
        amount: (data['amount'] as num?)?.toInt(),
        reference: data['reference'] as String?,
        paidOn: (data['paidOn'] as Timestamp?)?.toDate(),
        paidWhen: data['paidWhen'] as String?,
        paidTo: data['paidTo'] as String?,
        proofUrl: data['proofUrl'] as String?,
        receiptNo: data['receiptNo'] as String?,
        reason: data['reason'] as String?,
        recordedByFa: data['recordedBy'] == 'fa',
        createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
        reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
        editedAt: (data['editedAt'] as Timestamp?)?.toDate(),
      );
}

/// What a club sends from the Payment step, before it has an ID.
class PaymentDraft {
  const PaymentDraft({
    required this.method,
    this.amount,
    this.reference,
    this.paidOn,
    this.paidWhen,
    this.paidTo,
  });

  final PaymentMethod method;
  final int? amount;
  final String? reference;
  final DateTime? paidOn;
  final String? paidWhen;
  final String? paidTo;
}

/// Confirmed total for one club and season (`fees/{season}_{uid}`).
/// Only the FA writes it, in the same transaction as each confirmation.
class FeeSummary {
  const FeeSummary({required this.confirmed, required this.fee});

  final int confirmed;
  final int fee;

  int get left => (fee - confirmed).clamp(0, fee);
  bool get isPaid => confirmed >= fee;
  bool get hasStarted => confirmed > 0;

  /// 0.0 to 1.0, for the progress bar.
  double get progress => fee == 0 ? 1.0 : (confirmed / fee).clamp(0.0, 1.0);
}
