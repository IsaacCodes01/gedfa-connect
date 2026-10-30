import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/core/constants/firestore_paths.dart';
import 'package:gedfa_connect/core/constants/season.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/features/auth/data/app_user_repository.dart';
import 'package:gedfa_connect/features/notifications/data/notification_writer.dart';
import 'package:gedfa_connect/features/notifications/domain/app_notification.dart';
import 'package:gedfa_connect/features/payments/domain/payment.dart';
import 'package:gedfa_connect/features/teams/data/team_request_repository.dart';

const _timeout = Duration(seconds: 15);
const _uploadTimeout = Duration(seconds: 60);

/// The season fee (2.13c): clubs send payments, the FA confirms each one
/// (receipt number) or marks it not found. Payments are never rejected.
class PaymentRepository {
  PaymentRepository(this._db, this._storage);

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _payments =>
      _db.collection(FirestorePaths.payments);

  DocumentReference<Map<String, dynamic>> get _counterRef =>
      _db.doc(FirestorePaths.receiptCounter);

  DocumentReference<Map<String, dynamic>> _feeRef(
    String season,
    String requestUid,
  ) =>
      _db.doc(FirestorePaths.fee(season, requestUid));

  // ---------- The club ----------

  /// Uploads a screenshot of the payment message.
  Future<String> uploadProof({
    required String uid,
    required Uint8List bytes,
  }) async {
    final name = 'proof-${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = _storage.ref(StoragePaths.paymentProof(uid, name));
    await ref
        .putData(bytes, SettableMetadata(contentType: 'image/jpeg'))
        .timeout(_uploadTimeout);
    return ref.getDownloadURL();
  }

  /// Adds the club's payment to [batch]. Registration sends it in the
  /// same batch as the team request, so both arrive together.
  void addInBatch(
    WriteBatch batch, {
    required String requestUid,
    required String teamName,
    required PaymentDraft draft,
    String? teamId,
    String? proofUrl,
    String season = Season.current,
  }) {
    String? blankToNull(String? value) {
      final trimmed = value?.trim();
      return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    }

    final paidOn = draft.paidOn;
    batch.set(_payments.doc(), {
      'requestUid': requestUid,
      'teamId': teamId,
      'teamName': teamName.trim(),
      'season': season,
      'method': draft.method.name,
      'amount': draft.amount,
      'reference': blankToNull(draft.reference),
      'paidOn': paidOn == null ? null : Timestamp.fromDate(paidOn),
      'paidWhen': blankToNull(draft.paidWhen),
      'paidTo': blankToNull(draft.paidTo),
      'proofUrl': proofUrl,
      'status': PaymentStatus.waiting.name,
      'recordedBy': 'club',
      'createdBy': requestUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// A team adds a payment after approval (More › Season fee). The FA's
  /// bell hears about it in the same batch: "Payment from Golden Unity".
  Future<void> addForTeam({
    required String requestUid,
    required String teamId,
    required String teamName,
    required PaymentDraft draft,
    String? proofUrl,
  }) {
    final batch = _db.batch();
    addInBatch(
      batch,
      requestUid: requestUid,
      teamId: teamId,
      teamName: teamName,
      draft: draft,
      proofUrl: proofUrl,
    );
    final amount = draft.amount;
    NotificationWriter(_db).forFaInBatch(
      batch,
      kind: NotificationKind.paymentSent,
      teamId: teamId,
      teamName: teamName,
      name: amount == null
          ? 'Paid before the app (amount from your records)'
          : '${cedis(amount)} · ${draft.method.shortLabel}',
    );
    return batch.commit().timeout(_timeout);
  }

  /// FA: every club's confirmed total this season, by club account.
  Stream<Map<String, int>> watchSeasonTotals({String season = Season.current}) {
    return _db
        .collection(FirestorePaths.fees)
        .where('season', isEqualTo: season)
        .snapshots()
        .map((snapshot) => {
              for (final doc in snapshot.docs)
                (doc.data()['requestUid'] as String? ?? ''):
                    (doc.data()['confirmed'] as num?)?.toInt() ?? 0,
            });
  }

  /// FA: every payment still waiting this season (the "to confirm" counts).
  Stream<List<Payment>> watchWaiting({String season = Season.current}) {
    return _payments
        .where('season', isEqualTo: season)
        .where('status', isEqualTo: PaymentStatus.waiting.name)
        .snapshots()
        .map((snapshot) => [
              for (final doc in snapshot.docs)
                Payment.fromMap(doc.id, doc.data()),
            ]);
  }

  /// FA: a reminder in the team's bell, "GH₵ 400 left". One a day at
  /// most: a second reminder on the same day updates the first.
  Future<void> sendReminder({
    required String teamId,
    required String teamName,
    required int left,
  }) {
    final batch = _db.batch();
    NotificationWriter(_db).forTeamInBatch(
      batch,
      kind: NotificationKind.feeReminder,
      teamId: teamId,
      teamName: teamName,
      name: cedis(left),
    );
    return batch.commit().timeout(_timeout);
  }

  /// One club's payments for [season], newest first.
  /// Two equality filters only, so Firestore needs no extra index.
  Stream<List<Payment>> watchForClub(
    String requestUid, {
    String season = Season.current,
  }) {
    return _payments
        .where('requestUid', isEqualTo: requestUid)
        .where('season', isEqualTo: season)
        .snapshots()
        .map((snapshot) {
      final payments = [
        for (final doc in snapshot.docs) Payment.fromMap(doc.id, doc.data()),
      ];
      payments.sort((a, b) => (b.createdAt ?? DateTime(3000))
          .compareTo(a.createdAt ?? DateTime(3000)));
      return payments;
    });
  }

  /// The confirmed total so far (0 when nothing is confirmed yet).
  Stream<FeeSummary> watchSummary(
    String requestUid, {
    String season = Season.current,
  }) {
    return _feeRef(season, requestUid).snapshots().map(
          (snapshot) => FeeSummary(
            confirmed:
                (snapshot.data()?['confirmed'] as num?)?.toInt() ?? 0,
            fee: Season.fee,
          ),
        );
  }

  // ---------- The FA ----------

  /// Gives the next receipt number and moves the counter on by 1.
  /// Must run inside a transaction, after every other read.
  Future<String> _nextReceipt(Transaction tx, String season) async {
    final counter = await tx.get(_counterRef);
    final next = (counter.data()?['next'] as num?)?.toInt() ?? 1;
    if (counter.exists) {
      tx.update(_counterRef, {'next': next + 1});
    } else {
      tx.set(_counterRef, {'next': 2}); // the very first receipt
    }
    return receiptNoFor(next, Season.startYear(season));
  }

  /// Adds [amount] to the club's confirmed total, in the transaction.
  void _addToTotal(
    Transaction tx, {
    required String season,
    required String requestUid,
    required String teamName,
    required String? teamId,
    required int amount,
  }) {
    tx.set(
      _feeRef(season, requestUid),
      {
        'season': season,
        'requestUid': requestUid,
        'teamName': teamName,
        'teamId': ?teamId,
        'confirmed': FieldValue.increment(amount),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// FA: confirms a waiting payment and returns its receipt number.
  /// [amount] is needed for "already paid" payments (from the FA's
  /// records); otherwise the club's amount is kept.
  ///
  /// One transaction: the payment, the receipt counter and the club's
  /// confirmed total change together, or not at all.
  Future<String> confirm(
    Payment payment, {
    required String faUid,
    int? amount,
  }) {
    final ref = _payments.doc(payment.id);

    return _db.runTransaction<String>((tx) async {
      final snapshot = await tx.get(ref);
      final data = snapshot.data();
      if (data == null || data['status'] != PaymentStatus.waiting.name) {
        throw const PaymentNotWaitingException();
      }
      final value = amount ?? (data['amount'] as num?)?.toInt();
      if (value == null || value < 1 || value > Season.fee) {
        throw ArgumentError('Enter an amount between 1 and ${Season.fee}.');
      }

      final receipt = await _nextReceipt(tx, payment.season);
      _addToTotal(
        tx,
        season: payment.season,
        requestUid: payment.requestUid,
        teamName: payment.teamName,
        teamId: payment.teamId,
        amount: value,
      );
      tx.update(ref, {
        'status': PaymentStatus.confirmed.name,
        'amount': value,
        'receiptNo': receipt,
        'reviewedBy': faUid,
        'reviewedAt': FieldValue.serverTimestamp(),
      });
      // An approved team hears about it: "GH₵ 400 · receipt GEDFA-…"
      final teamId = payment.teamId;
      if (teamId != null) {
        NotificationWriter(_db).forTeamInTransaction(
          tx,
          kind: NotificationKind.paymentConfirmed,
          teamId: teamId,
          teamName: payment.teamName,
          name: '${cedis(value)} · receipt $receipt',
        );
      }
      return receipt;
    }).timeout(_timeout);
  }

  /// FA: the transaction ID isn't on the FA's statement, or the details
  /// are false. The club sees [reason] and can send it again.
  ///
  /// [rejectRequest]: the registration is still pending and nothing is
  /// confirmed yet, so it goes back to the club in the same batch, with
  // "Payment not found: <reason>", for them to correct.
  Future<void> markNotFound(
    Payment payment, {
    required String faUid,
    required String reason,
    bool rejectRequest = false,
  }) {
    final batch = _db.batch()
      ..update(_payments.doc(payment.id), {
        'status': PaymentStatus.notFound.name,
        'reason': reason.trim(),
        'reviewedBy': faUid,
        'reviewedAt': FieldValue.serverTimestamp(),
      });
    // An approved team hears about it in its bell
    final teamId = payment.teamId;
    if (teamId != null) {
      final amount = payment.amount;
      NotificationWriter(_db).forTeamInBatch(
        batch,
        kind: NotificationKind.paymentNotFound,
        teamId: teamId,
        teamName: payment.teamName,
        name: '${amount == null ? 'Your payment' : cedis(amount)}: '
            '${reason.trim()}',
      );
    }
    if (rejectRequest) {
      batch.update(_db.doc(FirestorePaths.teamRequest(payment.requestUid)), {
        'status': 'rejected',
        'rejectionReason': 'Payment not found: ${reason.trim()}',
        'reviewedBy': faUid,
        'reviewedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    return batch.commit().timeout(_timeout);
  }

  /// FA: fixes the amount of cash it recorded itself (a typing mistake).
  /// The receipt number stays; the club's total changes by the difference.
  Future<void> correctCashAmount(
    Payment payment, {
    required int amount,
    required String faUid,
  }) {
    final ref = _payments.doc(payment.id);

    return _db.runTransaction<void>((tx) async {
      final snapshot = await tx.get(ref);
      final data = snapshot.data();
      if (data == null ||
          data['status'] != PaymentStatus.confirmed.name ||
          data['recordedBy'] != 'fa') {
        throw const PaymentNotWaitingException();
      }
      final old = (data['amount'] as num?)?.toInt() ?? 0;
      tx.set(
        _feeRef(payment.season, payment.requestUid),
        {
          'confirmed': FieldValue.increment(amount - old),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      tx.update(ref, {
        'amount': amount,
        'editedBy': faUid,
        'editedAt': FieldValue.serverTimestamp(),
      });
    }).timeout(_timeout);
  }

  /// FA: cash the FA received in person. Saved as confirmed straight
  /// away, with a receipt number, which it returns.
  Future<String> recordCash({
    required String requestUid,
    required String teamName,
    required int amount,
    required String faUid,
    String? teamId,
    String? note,
    String season = Season.current,
  }) {
    final ref = _payments.doc();
    final trimmed = note?.trim();

    return _db.runTransaction<String>((tx) async {
      final receipt = await _nextReceipt(tx, season);
      _addToTotal(
        tx,
        season: season,
        requestUid: requestUid,
        teamName: teamName,
        teamId: teamId,
        amount: amount,
      );
      tx.set(ref, {
        'requestUid': requestUid,
        'teamId': teamId,
        'teamName': teamName,
        'season': season,
        'method': PaymentMethod.cash.name,
        'amount': amount,
        'paidWhen': (trimmed == null || trimmed.isEmpty) ? null : trimmed,
        'status': PaymentStatus.confirmed.name,
        'receiptNo': receipt,
        'recordedBy': 'fa',
        'createdBy': faUid,
        'createdAt': FieldValue.serverTimestamp(),
        'reviewedBy': faUid,
        'reviewedAt': FieldValue.serverTimestamp(),
      });
      if (teamId != null) {
        NotificationWriter(_db).forTeamInTransaction(
          tx,
          kind: NotificationKind.paymentConfirmed,
          teamId: teamId,
          teamName: teamName,
          name: '${cedis(amount)} cash · receipt $receipt',
        );
      }
      return receipt;
    }).timeout(_timeout);
  }
}

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseStorageProvider),
  );
});

/// One club's payments this season, live (club or FA).
final clubPaymentsProvider =
    StreamProvider.family<List<Payment>, String>((ref, requestUid) {
  return ref.watch(paymentRepositoryProvider).watchForClub(requestUid);
});

/// One club's confirmed total this season, live (club or FA).
final feeSummaryProvider =
    StreamProvider.family<FeeSummary, String>((ref, requestUid) {
  return ref.watch(paymentRepositoryProvider).watchSummary(requestUid);
});

/// FA: confirmed totals this season, by club account (Season fees list).
final seasonTotalsProvider = StreamProvider<Map<String, int>>((ref) {
  return ref.watch(paymentRepositoryProvider).watchSeasonTotals();
});

/// FA: payments still waiting this season.
final waitingPaymentsProvider = StreamProvider<List<Payment>>((ref) {
  return ref.watch(paymentRepositoryProvider).watchWaiting();
});
