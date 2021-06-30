import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart'; /// For saving video


class VideoUtil {
  static String? workPath;
  static String? appTempDir;

  static Future<void> getAppTempDirectory() async {
    appTempDir = '${(await getTemporaryDirectory()).path}/$workPath';
  }

  static Future<void> saveImageFileToDirectory(Uint8List byteData, String localName) async {
    Directory(appTempDir!).create().then((Directory directory) async {
      final file = File('${directory.path}/$localName');

      await file.writeAsBytesSync(byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
      print("filePath: ${file.path}");
    });
  }
}