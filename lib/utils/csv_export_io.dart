import 'dart:convert';
import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

Future<bool> exportCsv(String filename, String csvContent) async {
  final bytes = Uint8List.fromList([
    0xEF,
    0xBB,
    0xBF,
    ...utf8.encode(csvContent),
  ]);

  try {
    final result = await SharePlus.instance.share(
      ShareParams(
        title: filename,
        subject: filename,
        text: 'Save or share this CSV export.',
        files: [
          XFile.fromData(
            bytes,
            mimeType: 'text/csv',
          ),
        ],
        fileNameOverrides: [filename],
      ),
    );
    return result.status != ShareResultStatus.unavailable;
  } catch (_) {
    return false;
  }
}
