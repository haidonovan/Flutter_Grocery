import 'package:flutter/foundation.dart';

import 'csv_export_stub.dart'
    if (dart.library.io) 'csv_export_io.dart'
    if (dart.library.html) 'csv_export_web.dart' as exporter;

String csvFilename(String baseName, {DateTime? now}) {
  final date = (now ?? DateTime.now()).toIso8601String().split('T').first;
  return '${baseName}_$date.csv';
}

String buildCsv(List<List<String>> rows) {
  return rows
      .map(
        (row) => row.map((cell) => '"${cell.replaceAll('"', '""')}"').join(','),
      )
      .join('\n');
}

Future<bool> exportCsv(String filename, String csvContent) {
  return exporter.exportCsv(filename, csvContent);
}

String csvExportSuccessMessage(String label) {
  if (kIsWeb) {
    return '$label CSV downloaded.';
  }
  return '$label CSV ready to save or share.';
}

String csvExportFailureMessage() {
  return 'Could not start CSV export right now.';
}
