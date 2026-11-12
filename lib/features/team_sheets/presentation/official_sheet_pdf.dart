import 'dart:typed_data';

import 'package:flutter/painting.dart' show Color;
import 'package:flutter/services.dart' show rootBundle;
import 'package:gedfa_connect/core/utils/color_hex.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/features/team_sheets/domain/official_sheet.dart';
import 'package:gedfa_connect/features/teams/domain/kit.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// The fonts of the paper: Noto Sans, bundled in `assets/fonts/` so the
/// PDF works with no internet at the ground, and Twi letters (ɛ, ɔ) print.
class OfficialSheetFonts {
  const OfficialSheetFonts({required this.regular, required this.bold});

  final pw.Font regular;
  final pw.Font bold;

  static OfficialSheetFonts? _loaded;

  /// Loaded once, then kept.
  static Future<OfficialSheetFonts> load() async {
    if (_loaded case final f?) return f;
    final regular = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    final bold = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
    return _loaded = OfficialSheetFonts(
      regular: pw.Font.ttf(regular),
      bold: pw.Font.ttf(bold),
    );
  }
}

const _ink = PdfColor.fromInt(0xFF1A1C1E);
const _grey = PdfColor.fromInt(0xFF5F6368);
const _line = PdfColor.fromInt(0xFFC4C7C5);
const _band = PdfColor.fromInt(0xFFEFF1F3);
const _green = PdfColor.fromInt(0xFF00703F);
const _gold = PdfColor.fromInt(0xFFFFF4D6);
const _goldInk = PdfColor.fromInt(0xFF7A5200);

/// The official team sheet as A4 PDF bytes (3.3, MC4): one page, both
/// teams side by side, then the match officials and the captains'
/// signature lines. No QR code (Isaac).
Future<Uint8List> officialSheetPdf(
  OfficialSheet s, {
  required OfficialSheetFonts fonts,
  required DateTime printedAt,
}) {
  final doc = pw.Document(
    title: '${s.matchLine}, official team sheet',
    author: 'GEDFA Connect',
  );
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(28, 26, 28, 22),
      theme: pw.ThemeData.withFont(base: fonts.regular, bold: fonts.bold)
          .copyWith(
            defaultTextStyle: pw.TextStyle(
              font: fonts.regular,
              fontBold: fonts.bold,
              fontSize: 8.5,
              color: _ink,
            ),
          ),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _header(s),
          if (s.draftNote case final note?) ...[
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 5,
              ),
              decoration: const pw.BoxDecoration(
                color: _gold,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Text(
                note,
                style: pw.TextStyle(
                  color: _goldInk,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ],
          pw.SizedBox(height: 10),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: _team(s.home)),
              pw.SizedBox(width: 12),
              pw.Expanded(child: _team(s.away)),
            ],
          ),
          pw.SizedBox(height: 10),
          _officials(s.officials),
          pw.SizedBox(height: 26),
          _signatures(s),
          pw.Spacer(),
          pw.Divider(color: _line, thickness: 0.5),
          pw.Text(
            'GEDFA Connect · printed ${formatDateTime(printedAt)}',
            style: const pw.TextStyle(fontSize: 7, color: _grey),
          ),
        ],
      ),
    ),
  );
  return doc.save();
}

pw.Widget _header(OfficialSheet s) => pw.Row(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            s.heading,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: _green,
              letterSpacing: 0.4,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'Official team sheet',
            style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            s.matchLine,
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(s.whenWhere, style: const pw.TextStyle(fontSize: 9.5)),
        ],
      ),
    ),
    pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _ink, width: 0.8),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Text(
        s.roundLabel,
        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
      ),
    ),
  ],
);

pw.Widget _label(String text) => pw.Container(
  margin: const pw.EdgeInsets.only(top: 8, bottom: 2),
  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
  color: _band,
  child: pw.Text(
    text,
    style: pw.TextStyle(
      fontSize: 7.5,
      fontWeight: pw.FontWeight.bold,
      letterSpacing: 0.5,
    ),
  ),
);

pw.Widget _team(OfficialSheetTeam t) => pw.Container(
  padding: const pw.EdgeInsets.all(8),
  decoration: pw.BoxDecoration(
    border: pw.Border.all(color: _line, width: 0.8),
    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
  ),
  child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          // A kit made from photos has no colours to draw
          if (!t.kit.isPhotos) ...[
            pw.SvgImage(svg: kitSvg(t.kit), height: 42),
            pw.SizedBox(width: 3),
          ],
          if (!t.goalkeeperKit.isPhotos) ...[
            pw.SvgImage(svg: kitSvg(t.goalkeeperKit), height: 28),
            pw.SizedBox(width: 8),
          ],
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  t.name.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 10.5,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  '${t.sideLabel} · ${t.kitLabel}'
                  '${t.kit.isPhotos ? ' (photos in the app)' : ''}',
                  style: const pw.TextStyle(fontSize: 8, color: _grey),
                ),
                pw.Text(
                  t.goalkeeperKitLabel +
                      (t.goalkeeperKit.isPhotos ? ' (photos in the app)' : ''),
                  style: const pw.TextStyle(fontSize: 8, color: _grey),
                ),
              ],
            ),
          ),
        ],
      ),
      if (!t.saved)
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 16),
          child: pw.Text(
            'No team sheet saved.',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 10, color: _grey),
          ),
        )
      else ...[
        _label('STARTING 11'),
        _players(t.starters),
        if (t.bench.isNotEmpty) ...[
          _label('SUBSTITUTES (${t.bench.length})'),
          _players(t.bench),
        ],
        if (t.teamOfficials.isNotEmpty) ...[
          _label('TEAM OFFICIALS'),
          for (final (role, name) in t.teamOfficials)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 1.2,
              ),
              child: pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(
                      text: '$role: ',
                      style: const pw.TextStyle(color: _grey),
                    ),
                    pw.TextSpan(text: name),
                  ],
                ),
              ),
            ),
        ],
      ],
    ],
  ),
);

pw.Widget _players(List<OfficialSheetLine> lines) => pw.Table(
  columnWidths: const {
    0: pw.FixedColumnWidth(18),
    1: pw.FlexColumnWidth(),
    2: pw.FixedColumnWidth(24),
    3: pw.FixedColumnWidth(56),
  },
  border: const pw.TableBorder(
    horizontalInside: pw.BorderSide(color: _line, width: 0.4),
  ),
  children: [
    for (final l in lines)
      pw.TableRow(
        verticalAlignment: pw.TableCellVerticalAlignment.middle,
        children: [
          _cell('${l.number ?? ''}', bold: true, align: pw.TextAlign.right),
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(5, 2.2, 2, 2.2),
            child: pw.RichText(
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(
                    text: l.nameWithRoles,
                    style: l.roles.contains('C')
                        ? pw.TextStyle(fontWeight: pw.FontWeight.bold)
                        : null,
                  ),
                  if (l.ageGroup case final g?)
                    pw.TextSpan(
                      text: '  $g',
                      style: const pw.TextStyle(fontSize: 7, color: _grey),
                    ),
                  if (l.usual case final u?)
                    pw.TextSpan(
                      text: '  usual $u',
                      style: const pw.TextStyle(fontSize: 7, color: _grey),
                    ),
                ],
              ),
            ),
          ),
          _cell(l.position, color: _grey),
          _cell(l.code ?? '', size: 7.5),
        ],
      ),
  ],
);

pw.Widget _cell(
  String text, {
  bool bold = false,
  PdfColor? color,
  double? size,
  pw.TextAlign align = pw.TextAlign.left,
}) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2.2),
  child: pw.Text(
    text,
    textAlign: align,
    style: pw.TextStyle(
      fontWeight: bold ? pw.FontWeight.bold : null,
      color: color,
      fontSize: size,
    ),
  ),
);

pw.Widget _officials(List<(String, String?)> places) {
  pw.Widget place((String, String?) p) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 3),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.SizedBox(
          width: 70,
          child: pw.Text(p.$1, style: const pw.TextStyle(color: _grey)),
        ),
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 1),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: _line, width: 0.6),
              ),
            ),
            child: pw.Text(
              p.$2 ?? ' ',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
        ),
      ],
    ),
  );
  final half = (places.length + 1) ~/ 2;
  return pw.Container(
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _line, width: 0.8),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text(
          'MATCH OFFICIALS',
          style: pw.TextStyle(
            fontSize: 7.5,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                children: [for (final p in places.take(half)) place(p)],
              ),
            ),
            pw.SizedBox(width: 16),
            pw.Expanded(
              child: pw.Column(
                children: [for (final p in places.skip(half)) place(p)],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

pw.Widget _signatures(OfficialSheet s) {
  pw.Widget one(OfficialSheetTeam t) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Container(
        height: 0.8,
        color: _ink,
        margin: const pw.EdgeInsets.only(bottom: 3),
      ),
      pw.Text(
        "Captain's signature · ${t.name}",
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      ),
      pw.Text(t.captain ?? ' ', style: const pw.TextStyle(color: _grey)),
    ],
  );
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(child: one(s.home)),
      pw.SizedBox(width: 24),
      pw.Expanded(child: one(s.away)),
    ],
  );
}

/// A small drawing of [kit] (shirt with its pattern, shorts, socks) as SVG
/// for the PDF. Not for a kit made from photos (it has no colours).
String kitSvg(Kit kit) {
  String hex(Color c) => colorToHex(c);
  const shirt =
      'M13 3 L27 3 L38 10 L34 18 L29.5 15.5 L29.5 35 L10.5 35 L10.5 15.5 '
      'L6 18 L2 10 Z';
  final second = kit.secondary;
  final pattern = second == null
      ? ''
      : switch (kit.pattern) {
          KitPattern.plain => '',
          KitPattern.stripes =>
            '<rect x="7" y="0" width="4" height="40"/>'
                '<rect x="15" y="0" width="4" height="40"/>'
                '<rect x="23" y="0" width="4" height="40"/>'
                '<rect x="31" y="0" width="4" height="40"/>',
          KitPattern.hoops =>
            '<rect x="0" y="10" width="40" height="4"/>'
                '<rect x="0" y="19" width="40" height="4"/>'
                '<rect x="0" y="28" width="40" height="4"/>',
          KitPattern.halves => '<rect x="20" y="0" width="20" height="40"/>',
          KitPattern.sash => '<polygon points="8,3 15,3 33,36 26,36"/>',
        };
  const outline = 'stroke="#555555" stroke-width="0.7"';
  return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 40 61">'
      '<defs><clipPath id="s"><path d="$shirt"/></clipPath></defs>'
      '<path d="$shirt" fill="${hex(kit.primary)}"/>'
      '${pattern.isEmpty ? '' : '<g clip-path="url(#s)" fill="${hex(second!)}">$pattern</g>'}'
      '<path d="$shirt" fill="none" $outline/>'
      '<path d="M10.5 37 L29.5 37 L30.5 48 L21 48 L20 43 L19 48 L9.5 48 Z" '
      'fill="${hex(kit.shorts)}" $outline/>'
      '<rect x="11.5" y="50" width="6" height="10" fill="${hex(kit.socks)}" '
      '$outline/>'
      '<rect x="22.5" y="50" width="6" height="10" fill="${hex(kit.socks)}" '
      '$outline/>'
      '</svg>';
}
