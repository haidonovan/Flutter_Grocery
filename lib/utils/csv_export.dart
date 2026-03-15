import 'csv_export_stub.dart'
    if (dart.library.html) 'csv_export_web.dart'
    as exporter;

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
