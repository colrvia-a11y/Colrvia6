// lib/services/painter_pack_service.dart
import 'dart:typed_data';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import '../models/color_plan.dart';
import '../models/schema.dart' as schema;

class PainterPackService {
  int lastPageCount = 0;

  Future<Uint8List> buildPdf(
      ColorPlan plan, Map<String, schema.PaletteColor> skuMap) async {
    final doc = pw.Document();

    PdfColor? parseColor(String? hex) {
      if (hex == null || hex.isEmpty) return null;
      try {
        return PdfColor.fromHex(hex);
      } catch (_) {
        return null;
      }
    }

    final swatchWidgets = plan.paletteColorIds.map((id) {
      final info = skuMap[id];
      final color = parseColor(info?.hex);
      return pw.Container(
        width: 60,
        padding: const pw.EdgeInsets.all(4),
        child: pw.Column(
          children: [
            pw.Container(
              width: double.infinity,
              height: 40,
              color: color ?? PdfColors.grey300,
            ),
            if (info != null)
              pw.Text('${info.name}\n${info.code}',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 8)),
          ],
        ),
      );
    }).toList();

    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text('Painter Pack: ${plan.name}',
              style: pw.TextStyle(fontSize: 24)),
          pw.SizedBox(height: 16),
          pw.Text('SKUs & Sheens', style: pw.TextStyle(fontSize: 18)),
          pw.TableHelper.fromTextArray(
            headers: const ['Area', 'Color', 'Brand', 'Code', 'Sheen'],
            data: plan.placementMap.map((p) {
              final info = skuMap[p.colorId];
              return [
                p.area,
                info?.name ?? p.colorId,
                info?.brand ?? '',
                info?.code ?? '',
                p.sheen,
              ];
            }).toList(),
          ),
          pw.SizedBox(height: 16),
          pw.Text('Placements', style: pw.TextStyle(fontSize: 18)),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: plan.placementMap
                .map((p) => pw.Bullet(
                    text:
                        '${p.area}: ${skuMap[p.colorId]?.name ?? p.colorId}'))
                .toList(),
          ),
          pw.SizedBox(height: 16),
          pw.Text("Do / Don't", style: pw.TextStyle(fontSize: 18)),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: plan.doDont
                .map((e) => pw.Bullet(
                    text: 'Do: ${e.doText}\nDon\'t: ${e.dontText}'))
                .toList(),
          ),
          pw.SizedBox(height: 16),
          pw.Text('Swatch Cards', style: pw.TextStyle(fontSize: 18)),
          pw.Wrap(
            spacing: 8,
            runSpacing: 8,
            children: swatchWidgets,
          ),
        ],
      ),
    );

    // pdf package exposes pages via pdfPageList; use length for page count
    // Pdf package internals vary; attempt to read pagesCount, fallback to 0
    try {
      final dynamic list = doc.document.pdfPageList;
      if (list == null) {
        lastPageCount = 0;
      } else if (list is int) {
        lastPageCount = list;
      } else {
        try {
          lastPageCount = (list as dynamic).pagesCount as int? ?? (list as dynamic).length as int? ?? 0;
        } catch (_) {
          try {
            lastPageCount = (list as dynamic).length as int;
          } catch (_) {
            lastPageCount = 0;
          }
        }
      }
    } catch (_) {
      lastPageCount = 0;
    }
    return doc.save();
  }
}
