import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class OcrApi {
  // ✅ ใช้ --dart-define=OCR_BASE_URL=... เพื่อกำหนด OCR API ตอนรัน/บิลด์
  // ตัวอย่างมือถือจริง: --dart-define=OCR_BASE_URL=http://10.50.11.199:8000
  static const String _definedBaseUrl = String.fromEnvironment(
    'OCR_BASE_URL',
    defaultValue: '',
  );

  static String get baseUrl {
    if (_definedBaseUrl.trim().isNotEmpty) return _definedBaseUrl.trim();

    // web
    if (kIsWeb) return "http://localhost:8000";

    // ✅ FORCE IP: บังคับใช้ IP คอมพิวเตอร์ของคุณสำหรับมือถือจริง
    // แก้ไขจาก 10.0.2.2 เป็น 192.168.1.4 เพื่อให้เชื่อมต่อได้ชัวร์
    return "http://10.0.2.2:8000";
  }

  static Map<String, dynamic> _extractFields(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      final f = decoded["fields"];
      if (f is Map<String, dynamic>) return f;

      final data = decoded["data"];
      if (data is Map<String, dynamic>) {
        final f2 = data["fields"];
        if (f2 is Map<String, dynamic>) return f2;

        final looksLike = data.containsKey("name") ||
            data.containsKey("barcode") ||
            data.containsKey("size") ||
            data.containsKey("price") ||
            data.containsKey("mfg");
        if (looksLike) return data;
      }

      final looksLike = decoded.containsKey("name") ||
          decoded.containsKey("barcode") ||
          decoded.containsKey("size") ||
          decoded.containsKey("price") ||
          decoded.containsKey("mfg");
      if (looksLike) return decoded;

      return <String, dynamic>{};
    }
    return <String, dynamic>{};
  }

  static Future<Map<String, dynamic>> runOcr(File imageFile) async {
    final uri = Uri.parse("$baseUrl/ocr");
    final request = http.MultipartRequest("POST", uri);
    request.files.add(await http.MultipartFile.fromPath("image", imageFile.path));

    final streamed = await request.send();
    final bytes = await streamed.stream.toBytes();
    final body = utf8.decode(bytes);

    if (streamed.statusCode != 200) {
      throw Exception("OCR failed (${streamed.statusCode}): $body");
    }

    final decoded = jsonDecode(body);
    final fields = _extractFields(decoded);

    return <String, dynamic>{
      "raw": decoded,
      "fields": fields,
    };
  }

  static Future<bool> ping() async {
    final uri = Uri.parse("$baseUrl/ping");
    final res = await http.get(uri);
    return res.statusCode == 200;
  }
}