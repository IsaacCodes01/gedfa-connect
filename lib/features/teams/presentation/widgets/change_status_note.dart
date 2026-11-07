import 'package:flutter/material.dart';
import 'package:gedfa_connect/core/constants/approval_status.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';
import 'package:gedfa_connect/features/teams/domain/team_change.dart';

/// How long the team page keeps showing the FA's answer.
const changeAnswerShownFor = Duration(days: 7);

/// True if the team page shows a note for [change]: always while
/// pending, and for a week after the FA decided.
bool showsChangeNote(TeamChange change) {
  if (change.isPending) return true;
  final reviewedAt = change.reviewedAt;
  return reviewedAt != null &&
      DateTime.now().difference(reviewedAt) < changeAnswerShownFor;
}

/// The note on the team page (board P1, 2.10b):
/// - gold while the FA hasn't decided ("Name change pending"),
/// - red when the FA did not approve, with the FA's reason,
/// - green when approved ("Juvenile approved": what to do next).
class ChangeStatusNote extends StatelessWidget {
  const ChangeStatusNote({super.key, required this.change});

  final TeamChange change;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final (Color bg, Color ink, IconData icon) = switch (change.status) {
      ApprovalStatus.pending => isDark
          ? (const Color(0xFF3D3410), const Color(0xFFF5D25B),
              Icons.hourglass_top_rounded)
          : (const Color(0xFFFFF6CC), const Color(0xFF5C4700),
              Icons.hourglass_top_rounded),
      ApprovalStatus.rejected => (
          scheme.error.withValues(alpha: isDark ? 0.22 : 0.10),
          isDark ? const Color(0xFFFF9AA5) : const Color(0xFF8C1022),
          Icons.error_outline_rounded,
        ),
      ApprovalStatus.approved => isDark
          ? (const Color(0xFF123D2B), const Color(0xFF7BE3B0),
              Icons.check_circle_outline_rounded)
          : (const Color(0xFFE3F2EA), const Color(0xFF00502F),
              Icons.check_circle_outline_rounded),
    };

    final body = textTheme.bodySmall?.copyWith(color: ink, height: 1.4);
    final bold = TextStyle(color: ink, fontWeight: FontWeight.w700);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: ink),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title,
                  style: textTheme.titleSmall
                      ?.copyWith(color: ink, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text.rich(_message(bold), style: body),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _competition => change.competition?.label ?? change.to;

  String get _title => switch ((change.status, change.kind)) {
        (ApprovalStatus.pending, TeamChangeKind.competition) =>
          '$_competition request pending',
        (ApprovalStatus.pending, final kind) =>
          '${_capital(kind.noun)} change pending',
        (ApprovalStatus.rejected, TeamChangeKind.competition) =>
          '$_competition request not approved',
        (ApprovalStatus.rejected, final kind) =>
          '${_capital(kind.noun)} change not approved',
        (ApprovalStatus.approved, TeamChangeKind.competition) =>
          '$_competition approved',
        (ApprovalStatus.approved, final kind) => 'New ${kind.noun} approved',
      };

  static String _capital(String text) =>
      text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';

  TextSpan _message(TextStyle bold) {
    final createdAt = change.createdAt;
    final on = createdAt == null ? '' : ' on ${formatDayMonth(createdAt)}';

    switch (change.status) {
      case ApprovalStatus.pending:
        return switch (change.kind) {
          TeamChangeKind.name => TextSpan(children: [
              const TextSpan(text: 'You asked to rename the club to '),
              TextSpan(text: change.to, style: bold),
              TextSpan(
                text: '$on. The old name is used everywhere until the FA '
                    'approves.',
              ),
            ]),
          TeamChangeKind.shortName => TextSpan(children: [
              const TextSpan(text: 'You asked to change the short name to '),
              TextSpan(text: change.to, style: bold),
              TextSpan(
                text: '$on. The old one is used everywhere until the FA '
                    'approves.',
              ),
            ]),
          TeamChangeKind.logo => TextSpan(
              text: 'You sent a new logo$on. The old one is used everywhere '
                  'until the FA approves.',
            ),
          TeamChangeKind.competition => TextSpan(children: [
              const TextSpan(text: 'You asked to add '),
              TextSpan(text: _competition, style: bold),
              TextSpan(
                text: '$on. Until the FA approves, you play only '
                    '${_other(change.competition)}.',
              ),
            ]),
        };
      case ApprovalStatus.rejected:
        return TextSpan(children: [
          TextSpan(text: "The FA's reason: ", style: bold),
          TextSpan(text: change.rejectionReason ?? ''),
          const TextSpan(text: '\nYou can ask again with "Ask to change".'),
        ]);
      case ApprovalStatus.approved:
        return switch (change.kind) {
          TeamChangeKind.name => TextSpan(children: [
              TextSpan(text: change.to, style: bold),
              const TextSpan(
                text: ' is now used everywhere. Your players keep their IDs.',
              ),
            ]),
          TeamChangeKind.shortName => TextSpan(children: [
              TextSpan(text: change.to, style: bold),
              const TextSpan(text: ' is now your short name everywhere.'),
            ]),
          TeamChangeKind.logo =>
            const TextSpan(text: 'Your new logo is now used everywhere.'),
          TeamChangeKind.competition =>
            change.competition == Competition.division
                ? const TextSpan(
                    text: 'Check your Division kits (Kits › Edit), then add '
                        'your Division players in Squad.',
                  )
                : const TextSpan(
                    text: 'Add your Juvenile kits (Kits › Edit), then add '
                        'children for screening in Squad › Juvenile.',
                  ),
        };
    }
  }

  /// The competition the club already plays
  static String _other(Competition? adding) =>
      adding == Competition.division ? 'Juvenile' : 'Division';
}
