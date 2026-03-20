// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

Future<bool> exportCsv(String filename, String csvContent) async {
  // Prefix with a UTF-8 BOM so Excel opens CSV content reliably.
  final bytes = Uint8List.fromList([
    0xEF,
    0xBB,
    0xBF,
    ...utf8.encode(csvContent),
  ]);
  final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
  return true;
}
