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
import 'package:gedfa_connect/features/teams/data/team_repository.dart';
import 'package:printing/printing.dart';

/// Who opened the PDF: what they may read decides what it shows.
enum SheetViewer {
  /// Both teams any time (a DRAFT before the lock).
  fa,

  /// The appointed officials: both teams from the lock (3.5c).
  official,

  /// A team: its own sheet only (3.3b); the officials' names from 24 h
  /// before, like Match details.
  team,
}

/// The team sheet as a PDF (3.3, mockup MC4), ready to print or share:
/// the official sheet with both teams for the FA and the officials, or a
/// team's own sheet (3.3b). Player IDs, kits (drawn or their photos), the
/// match officials and the captains' signature lines.
class OfficialSheetScreen extends ConsumerStatefulWidget {
  const OfficialSheetScreen({
    super.key,
    required this.fixtureId,
    required this.viewer,
  });

  final String fixtureId;
  final SheetViewer viewer;

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

  String get _fallback => switch (widget.viewer) {
    SheetViewer.fa => Routes.adminMatch(widget.fixtureId),
    SheetViewer.official => Routes.refereeMatch(widget.fixtureId),
    SheetViewer.team => Routes.teamMatch(widget.fixtureId),
  };

  void _make(
    Fixture f,
    TeamSheet? home,
    TeamSheet? away,
    MatchOfficials? o, {
    String? onlyTeamId,
  }) {
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
      onlyTeamId: onlyTeamId,
    );
    _madeFrom = (f, home, away, o);
    _sheet = sheet;
    _pdf = () async {
      // Fonts and kit photos first, then the page
      final (fonts, photos) = await (
        OfficialSheetFonts.load(),
        loadKitPhotos(sheet),
      ).wait;
      try {
        return await officialSheetPdf(
          sheet,
          fonts: fonts,
          photos: photos,
          printedAt: now,
        );
      } catch (e, st) {
        if (photos.isEmpty) rethrow;
        // A kit photo the PDF can't use: the sheet without the photos
        debugPrint('Team sheet PDF with kit photos failed: $e\n$st');
        return officialSheetPdf(sheet, fonts: fonts, printedAt: now);
      }
    }();
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

  /// Share (phone) or Download (web): on an iPhone the browser opens the
  /// PDF in its own viewer.
  void _download() {
    final name = _sheet?.fileName;
    if (name == null) return;
    _run((bytes) => Printing.sharePdf(bytes: bytes, filename: name));
  }

  @override
  Widget build(BuildContext context) {
    final viewer = widget.viewer;
    final isTeam = viewer == SheetViewer.team;
    final fixture = ref.watch(fixtureProvider(widget.fixtureId));
    final myTeam = isTeam ? ref.watch(myTeamProvider) : null;
    final f = fixture.value;
    final now = DateTime.now();
    final due = f?.sheetDueAt;
    final locked = due != null && !now.isBefore(due);

    // A team reads only its own sheet; the officials only from the lock
    final myTeamId = myTeam?.value?.id;
    final mine = f == null || myTeamId == null
        ? null
        : f.home.id == myTeamId || f.away.id == myTeamId
        ? myTeamId
        : null;
    final mayRead =
        f != null &&
        switch (viewer) {
          SheetViewer.fa => true,
          SheetViewer.official => locked,
          SheetViewer.team => mine != null,
        };
    bool reads(FixtureSide side) => mayRead && (!isTeam || side.id == mine);
    final home = f != null && reads(f.home)
        ? ref.watch(teamSheetProvider((f.id, f.home.id)))
        : null;
    final away = f != null && reads(f.away)
        ? ref.watch(teamSheetProvider((f.id, f.away.id)))
        : null;
    // The clubs see the officials only from 24 h before (3.5a)
    final officials = mayRead && (!isTeam || MatchOfficials.clubsMaySee(f, now))
        ? ref.watch(matchOfficialsProvider(widget.fixtureId))
        : null;
    final ownSheet = isTeam ? (home ?? away)?.value : null;

    final error =
        fixture.error ??
        myTeam?.error ??
        home?.error ??
        away?.error ??
        officials?.error;
    Widget body;
    if (error != null) {
      body = ErrorView(message: appErrorMessage(error));
    } else if (fixture.isLoading || (myTeam?.isLoading ?? false)) {
      body = const LoadingView(message: 'Getting the official sheet…');
    } else if (f == null || (isTeam && mine == null)) {
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
    } else if ((home?.isLoading ?? false) ||
        (away?.isLoading ?? false) ||
        (officials?.isLoading ?? false)) {
      body = const LoadingView(message: 'Getting the official sheet…');
    } else if (isTeam && ownSheet == null) {
      body = const EmptyView(
        icon: Icons.assignment_outlined,
        title: 'No team sheet yet',
        message: 'Save your team sheet first, then print it from here.',
      );
    } else {
      _make(
        f,
        home?.value,
        away?.value,
        officials?.value,
        onlyTeamId: isTeam ? mine : null,
      );
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
        loadingWidget: const LoadingView(message: 'Getting the official sheet…'),
        onError: (_, e) {
          debugPrint('Team sheet PDF preview failed: $e');
          final text = e.toString();
          final details = text.length > 300 ? text.substring(0, 300) : text;
          // Made but not shown: the browser can't draw the preview (older
          // Safari, e.g. iPhone 8). The PDF is fine, so offer to open it.
          // Not made at all: a real fault, with the reason in small print.
          return FutureBuilder<Uint8List>(
            future: pdf,
            builder: (context, made) => made.hasData
                ? _PreviewUnavailable(
                    details: details,
                    onOpen: _busy ? null : _download,
                  )
                : made.hasError
                ? ErrorView(
                    message:
                        '${appErrorMessage(made.error!)}\n\nDetails: '
                        '${made.error}',
                  )
                : const LoadingView(message: 'Getting the official sheet…'),
          );
        },
      );
    }

    final sheet = _sheet;
    final ready =
        sheet != null &&
        _pdf != null &&
        mayRead &&
        error == null &&
        (!isTeam || ownSheet != null);
    return Scaffold(
      appBar: GedfaAppBar(
        title: isTeam ? 'Team sheet' : 'Official team sheet',
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
                        onPressed: _busy ? null : _download,
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

/// The PDF is made but this browser can't draw the preview (older Safari,
/// e.g. iPhone 8 / iOS 16): say so calmly and open the PDF in the
/// browser's own viewer instead.
class _PreviewUnavailable extends StatelessWidget {
  const _PreviewUnavailable({required this.details, required this.onOpen});

  final String details;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.picture_as_pdf_outlined,
                size: 56,
                color: scheme.primary,
              ),
              const SizedBox(height: 14),
              Text(
                'Your sheet is ready',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                "This browser can't show the preview here, but the PDF "
                'is fine. Open it to see, save or print it.',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open the PDF'),
              ),
              const SizedBox(height: 18),
              Text(
                'Details: $details',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
