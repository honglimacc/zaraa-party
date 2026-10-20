import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'api.dart';
import 'theme.dart';

/// Pilih file dari perangkat lalu unggah ke server. Mengembalikan URL, atau null bila dibatalkan / gagal.
/// [animation] = true: boleh memilih Lottie JSON (khusus Developer); false: hanya gambar dari galeri.
Future<String?> pickAndUpload(BuildContext context, {bool animation = false}) async {
  try {
    List<int>? bytes;
    if (animation) {
      final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['png', 'jpg', 'jpeg', 'gif', 'webp', 'json'], withData: true);
      bytes = r?.files.single.bytes;
    } else {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1024, imageQuality: 85);
      bytes = await x?.readAsBytes();
    }
    if (bytes == null) return null;
    final res = await Api.i.upload(Uint8List.fromList(bytes));
    return res['url'] as String;
  } catch (e) {
    if (context.mounted) toast(context, '$e');
    return null;
  }
}
