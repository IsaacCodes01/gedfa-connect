import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/core/widgets/back_to_home.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/features/fixtures/data/fixture_repository.dart';
import 'package:gedfa_connect/features/fixtures/domain/fixture.dart';
import 'package:gedfa_connect/features/officials/data/officials_repository.dart';
import 'package:gedfa_connect/features/officials/domain/match_officials.dart';
import 'package:gedfa_connect/features/team_sheets/data/team_sheet_repository.dart';
import 'package:gedfa_connect/features/team_sheets/domain/official_sheet.dart';
import 'package:gedfa_connect/features/team_sheets/domain/team_sheet.dart';
import 'package:gedfa_connect/features/team_sheets/presentation/official_sheet_pdf.dart';
import 'package:printing/printing.dart';

/// The official team sheet as a PDF (3.3, mockup MC4): both teams with
/// player IDs, kits, the match officials and the captains' signature
/// lines, ready to print or share. The FA any time (a DRAFT before the
/// lock); the appointed officials from the lock, when they can read both
/// sheets (3.5c).
class OfficialSheetScreen extends ConsumerStatefulWidget {
  const OfficialSheetScreen({
    super.key,
    required this.fixtureId,
    required this.isFa,
  });

  final String fixtureId;
  final bool isFa;

  @override
  ConsumerState<OfficialSheetScreen> createState() =>
      _OfficialSheetScreenState();
}

class _OfficialSheetScreenState extends ConsumerState<OfficialSheetScreen> {
  /// What the PDF was last made from; it is made again only when one of
  /// them changes (a team saves, the FA appoints), not on every rebuild.
  (Fixture, TeamSheet?, TeamSheet?, MatchOfficials?)? _madeFrom;
  OfficialSheet? _sheet;
  Future<Uint8List>? _pdf;
  bool _busy = false;

  String get _fallback => widget.isFa
      ? Routes.adminMatch(widget.fixtureId)
      : Routes.refereeMatch(widget.fixtureId);

  void _make(Fixture f, TeamSheet? home, TeamSheet? away, MatchOfficials? o) {
    final last = _madeFrom;
    if (last != null &&
        identical(last.$1, f) &&
        identical(last.$2, home) &&
        identical(last.$3, away) &&
        identical(last.$4, o)) {
      return;
    }
    final now = DateTime.now();
    final sheet = OfficialSheet.of(
      fixture: f,
      homeSheet: home,
      awaySheet: away,
      officials: o,
      now: now,
    );
    _madeFrom = (f, home, away, o);
    _sheet = sheet;
    _pdf = OfficialSheetFonts.load().then(
      (fonts) => officialSheetPdf(sheet, fonts: fonts, printedAt: now),
    );
  }

  Future<void> _run(Future<void> Function(Uint8List bytes) action) async {
    final pdf = _pdf;
    if (pdf == null || _busy) return;
    setState(() => _busy = true);
    try {
      await action(await pdf);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(appErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fixture = ref.watch(fixtureProvider(widget.fixtureId));
    final f = fixture.value;
    final due = f?.sheetDueAt;
    final locked = due != null && !DateTime.now().isBefore(due);

    // Officials read the sheets only from the lock (rules, 3.5c)
    final mayRead = f != null && (widget.isFa || locked);
    final home = mayRead
        ? ref.watch(teamSheetProvider((f.id, f.home.id)))
        : null;
    final away = mayRead
        ? ref.watch(teamSheetProvider((f.id, f.away.id)))
        : null;
    final officials = mayRead
        ? ref.watch(matchOfficialsProvider(widget.fixtureId))
        : null;

    final error =
        fixture.error ?? home?.error ?? away?.error ?? officials?.error;
    Widget body;
    if (error != null) {
      body = ErrorView(message: appErrorMessage(error));
    } else if (fixture.isLoading) {
      body = const LoadingView();
    } else if (f == null) {
      body = const EmptyView(
        icon: Icons.event_busy_outlined,
        title: 'Match not found',
        message: 'This match may have been removed.',
      );
    } else if (!mayRead) {
      body = EmptyView(
        icon: Icons.lock_clock_outlined,
        title: 'Not yet',
        message: due == null
            ? 'The official sheet opens 1 hour before kick-off.'
            : 'The official sheet opens at ${formatTime(due)} on '
                  '${formatShortDate(due)}, 1 hour before kick-off.',
      );
    } else if (home!.isLoading || away!.isLoading || officials!.isLoading) {
      body = const LoadingView();
    } else {
      _make(f, home.value, away.value, officials.value);
      final pdf = _pdf!;
      body = PdfPreview(
        // The same function while nothing changed, so the preview is not
        // drawn again on every rebuild
        key: ValueKey(pdf),
        build: (_) => pdf,
        useActions: false,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        maxPageWidth: 760,
        pdfFileName: _sheet!.fileName,
        loadingWidget: const LoadingView(),
        onError: (_, e) => ErrorView(message: appErrorMessage(e)),
      );
    }

    final sheet = _sheet;
    final ready = sheet != null && _pdf != null && mayRead && error == null;
    return Scaffold(
      appBar: GedfaAppBar(
        title: 'Official team sheet',
        subtitle: 'PDF · A4',
        leading: AppBackButton(fallback: _fallback, close: true),
      ),
      body: body,
      bottomNavigationBar: !ready
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _busy
                            ? null
                            : () => _run(
                                (bytes) => Printing.layoutPdf(
                                  onLayout: (_) async => bytes,
                                  name: sheet.fileName,
                                ),
                              ),
                        icon: const Icon(Icons.print_outlined),
                        label: const Text('Print'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      // On the web, sharing a file means downloading it
                      child: FilledButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _run(
                                (bytes) => Printing.sharePdf(
                                  bytes: bytes,
                                  filename: sheet.fileName,
                                ),
                              ),
                        icon: Icon(
                          kIsWeb ? Icons.download_outlined : Icons.share,
                        ),
                        label: Text(kIsWeb ? 'Download' : 'Share'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
