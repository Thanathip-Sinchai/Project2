import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiService {
  // ================= BASE URL =================
  // ✅ ใช้ --dart-define=API_BASE_URL=... เพื่อกำหนด URL ตอนรัน/บิลด์
  // ตัวอย่างมือถือจริง: --dart-define=API_BASE_URL=http://10.50.11.199:3000
  static const String _definedBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');

  static String get baseUrl {
    // ถ้าผู้ใช้กำหนดมาจาก --dart-define ให้ใช้ค่านี้ก่อน
    if (_definedBaseUrl.trim().isNotEmpty) return _definedBaseUrl.trim();

    // web
    if (kIsWeb) return "http://localhost:3000";

    // ✅ FORCE IP: บังคับใช้ IP คอมพิวเตอร์ของคุณสำหรับมือถือจริง
    // แก้ไขจาก 10.0.2.2 เป็น 192.168.1.4 เพื่อแก้ปัญหา Connection Refused
    return "http://10.0.2.2:3000";
  }

  static Uri _u(String path) => Uri.parse('$baseUrl$path');

  // ================= TOKEN STORAGE =================
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _tokenKey = 'access_token';

  // ✅ Selected Shop storage
  static const String _shopIdKey = 'selected_shop_id';
  // ✅ Selected Shop role storage (admin/manager/employee)
  static const String _shopRoleKey = 'selected_shop_role';

  static Future<String?> getToken() => _storage.read(key: _tokenKey);
  static Future<void> setToken(String token) =>
      _storage.write(key: _tokenKey, value: token);
  static Future<void> clearToken() => _storage.delete(key: _tokenKey);

  static Future<int?> getSelectedShopId() async {
    final v = await _storage.read(key: _shopIdKey);
    if (v == null || v.trim().isEmpty) return null;
    return int.tryParse(v.trim());
  }

  static Future<void> setSelectedShopId(int shopId) async {
    await _storage.write(key: _shopIdKey, value: shopId.toString());
  }

  static Future<void> clearSelectedShopId() async {
    await _storage.delete(key: _shopIdKey);
  }

  // ✅ role getter/setter
  static Future<String?> getSelectedShopRole() async {
    final v = await _storage.read(key: _shopRoleKey);
    if (v == null || v.trim().isEmpty) return null;
    return v.trim();
  }

  static Future<void> setSelectedShopRole(String role) async {
    await _storage.write(key: _shopRoleKey, value: role.trim().toLowerCase());
  }

  static Future<void> clearSelectedShopRole() async {
    await _storage.delete(key: _shopRoleKey);
  }

  // ✅ เซ็ต shopId + role พร้อมกัน (ใช้ตอนเลือก shop)
  static Future<void> setSelectedShop({
    required int shopId,
    required String role,
  }) async {
    await setSelectedShopId(shopId);
    await setSelectedShopRole(role);
  }

  static Future<Map<String, String>> _authHeaders({bool json = true}) async {
    final token = await getToken();
    final headers = <String, String>{};
    if (json) headers['Content-Type'] = 'application/json';
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    // ✅ แนบ shop id ให้ทุก request ที่ต้องแยกร้าน
    final shopId = await getSelectedShopId();
    if (shopId != null) {
      headers['X-Shop-Id'] = shopId.toString();
    }

    return headers;
  }

  static Map<String, dynamic> _decodeJson(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
      return {'data': decoded};
    } catch (_) {
      return {'raw': body};
    }
  }

  // ================= URL helpers for images =================
  // ✅ ใช้กับ product_image / group_image / shop_image
  static String fileUrl(String? imagePath) {
    final s = (imagePath ?? '').trim();
    if (s.isEmpty) return '';
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    return '$baseUrl$s';
  }

  static String shopImageUrl(String imagePath) => fileUrl(imagePath);
  static String productImageUrl(String? imagePath) => fileUrl(imagePath);
  static String groupImageUrl(String? imagePath) => fileUrl(imagePath);

  // =========================================================
  // ✅✅ STOCK HISTORY
  // =========================================================
  static Future<List<dynamic>> fetchStockHistory({
    required String range,
    String q = '',
  }) async {
    final res = await http.get(
      Uri.parse(
        '$baseUrl/stock/history?range=${Uri.encodeComponent(range)}&q=${Uri.encodeComponent(q)}',
      ),
      headers: await _authHeaders(json: false),
    );

    if (res.statusCode == 401) throw Exception('UNAUTHORIZED');
    if (res.statusCode == 403) throw Exception('FORBIDDEN');

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final decoded = jsonDecode(res.body);
      if (decoded is List) return decoded;
      throw Exception('Stock history response is not a List');
    }

    throw Exception('GET /stock/history failed: ${res.statusCode} ${res.body}');
  }

  static Future<List<dynamic>> fetchStockHistoryByQuery({
    required String range,
    String query = '',
  }) {
    return fetchStockHistory(range: range, q: query);
  }

  static Future<List<dynamic>> fetchStockHistoryLegacy({
    required String range,
    String query = '',
  }) {
    return fetchStockHistory(range: range, q: query);
  }

  // ================= AUTH =================
  static Future<Map<String, dynamic>> login({
    required String emailOrUsername,
    required String password,
  }) async {
    final res = await http.post(
      _u('/auth/login'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'emailOrUsername': emailOrUsername.trim(),
        'password': password,
      }),
    );

    final decoded = _decodeJson(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final token = (decoded['access_token'] ?? '').toString();
      if (token.isNotEmpty) {
        await setToken(token);
      }

      await clearSelectedShopId();
      await clearSelectedShopRole();

      return decoded;
    }

    final msg = (decoded['error'] ?? 'Login failed').toString();
    throw Exception(msg);
  }

  static Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    final res = await http.post(
      _u('/auth/register'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username.trim(),
        'email': email.trim(),
        'password': password,
        'confirmPassword': confirmPassword,
      }),
    );

    final decoded = _decodeJson(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return decoded;

    final msg = (decoded['error'] ?? 'Register failed').toString();
    throw Exception(msg);
  }

  // ================= PROFILE =================
  static Future<Map<String, dynamic>> fetchMe() async {
    final res = await http.get(_u('/me'), headers: await _authHeaders());
    if (res.statusCode == 401) throw Exception('UNAUTHORIZED');
    if (res.statusCode >= 200 && res.statusCode < 300) return _decodeJson(res.body);
    throw Exception('Fetch profile failed: ${res.statusCode} ${res.body}');
  }

  static Future<Map<String, dynamic>> updateMe({
    required String name,
    required String email,
    String? avatarUrl,
  }) async {
    final res = await http.put(
      _u('/me'),
      headers: await _authHeaders(),
      body: jsonEncode({'username': name, 'email': email, 'avatar_url': avatarUrl}),
    );

    if (res.statusCode == 401) throw Exception('UNAUTHORIZED');
    if (res.statusCode >= 200 && res.statusCode < 300) return _decodeJson(res.body);
    throw Exception('Update profile failed: ${res.statusCode} ${res.body}');
  }

  static Future<Map<String, dynamic>> updateAvatar({
    required Uint8List imageBytes,
    required String imageFilename,
  }) async {
    final req = http.MultipartRequest('PUT', _u('/me/avatar'));

    final headers = await _authHeaders(json: false);
    req.headers.addAll(headers);

    req.files.add(http.MultipartFile.fromBytes(
      'image',
      imageBytes,
      filename: imageFilename,
    ));

    final streamed = await req.send();
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
      return _decodeJson(body);
    }
    throw Exception('Update avatar failed: ${streamed.statusCode} $body');
  }

  // ================= SHOPS (Multi shop) =================
  static Future<List<dynamic>> fetchMyShops() async {
    final res = await http.get(_u('/shops'), headers: await _authHeaders());
    if (res.statusCode == 401) throw Exception('UNAUTHORIZED');
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final decoded = jsonDecode(res.body);
      if (decoded is List) return decoded;
      throw Exception('Shops response is not a List');
    }
    throw Exception('GET /shops failed: ${res.statusCode} ${res.body}');
  }

  static Future<Map<String, dynamic>> createShop({required String shopName}) async {
    final res = await http.post(
      _u('/shops'),
      headers: await _authHeaders(),
      body: jsonEncode({'shop_name': shopName.trim()}),
    );
    final decoded = _decodeJson(res.body);
    if (res.statusCode == 401) throw Exception('UNAUTHORIZED');
    if (res.statusCode >= 200 && res.statusCode < 300) return decoded;
    throw Exception((decoded['error'] ?? 'Create shop failed').toString());
  }

  // ================= EMPLOYEES (Shop Members) =================
  static Future<List<dynamic>> fetchShopMembers() async {
    final shopId = await getSelectedShopId();
    if (shopId == null) throw Exception('NO_SHOP_SELECTED');

    final res = await http.get(_u('/shop/members'), headers: await _authHeaders(json: false));
    if (res.statusCode == 401) throw Exception('UNAUTHORIZED');
    if (res.statusCode == 403) throw Exception('FORBIDDEN');

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final decoded = jsonDecode(res.body);
      if (decoded is List) return decoded;
      throw Exception('members response is not a List');
    }
    throw Exception('GET /shop/members failed: ${res.statusCode} ${res.body}');
  }

  static Future<List<dynamic>> searchUsersForShop({required String query}) async {
    final shopId = await getSelectedShopId();
    if (shopId == null) throw Exception('NO_SHOP_SELECTED');

    final res = await http.get(
      Uri.parse('$baseUrl/users/search?q=${Uri.encodeComponent(query)}'),
      headers: await _authHeaders(json: false),
    );

    if (res.statusCode == 401) throw Exception('UNAUTHORIZED');
    if (res.statusCode == 403) throw Exception('FORBIDDEN');

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final decoded = jsonDecode(res.body);
      if (decoded is List) return decoded;
      throw Exception('search response is not a List');
    }

    throw Exception('GET /users/search failed: ${res.statusCode} ${res.body}');
  }

  static Future<void> addShopMember({required int userId, required String role}) async {
    final shopId = await getSelectedShopId();
    if (shopId == null) throw Exception('NO_SHOP_SELECTED');

    final res = await http.post(
      _u('/shop/members'),
      headers: await _authHeaders(),
      body: jsonEncode({'user_id': userId, 'role': role}),
    );

    if (res.statusCode == 401) throw Exception('UNAUTHORIZED');
    if (res.statusCode == 403) throw Exception('FORBIDDEN');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Add member failed: ${res.statusCode} ${res.body}');
    }
  }

  static Future<void> updateShopMemberRole({required int userId, required String role}) async {
    final shopId = await getSelectedShopId();
    if (shopId == null) throw Exception('NO_SHOP_SELECTED');

    final res = await http.put(
      _u('/shop/members/$userId/role'),
      headers: await _authHeaders(),
      body: jsonEncode({'role': role}),
    );

    if (res.statusCode == 401) throw Exception('UNAUTHORIZED');
    if (res.statusCode == 403) throw Exception('FORBIDDEN');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Update role failed: ${res.statusCode} ${res.body}');
    }
  }

  static Future<void> removeShopMember(int userId) async {
    final shopId = await getSelectedShopId();
    if (shopId == null) throw Exception('NO_SHOP_SELECTED');

    final res = await http.delete(
      _u('/shop/members/$userId'),
      headers: await _authHeaders(json: false),
    );

    if (res.statusCode == 401) throw Exception('UNAUTHORIZED');
    if (res.statusCode == 403) throw Exception('FORBIDDEN');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Remove member failed: ${res.statusCode} ${res.body}');
    }
  }

  // ================= PRODUCTS (LOTS) =================
  static Future<List<dynamic>> fetchProducts() async {
    final res = await http.get(_u('/products'), headers: await _authHeaders(json: false));
    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      if (decoded is List) return decoded;
      throw Exception('Products response is not a List');
    }
    throw Exception('GET /products failed: ${res.statusCode} ${res.body}');
  }

  static Future<List<dynamic>> fetchProductLotsByName(String productName) async {
    final uri = Uri.parse('${baseUrl}/products?name=${Uri.encodeComponent(productName)}');
    final res = await http.get(uri, headers: await _authHeaders(json: false));
    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      if (decoded is List) return decoded;
      throw Exception('Lots response is not a List');
    }
    throw Exception('GET /products?name= failed: ${res.statusCode} ${res.body}');
  }

  static Future<List<dynamic>> fetchProductSummary() async {
    final res = await http.get(_u('/products/summary'), headers: await _authHeaders(json: false));
    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      if (decoded is List) return decoded;
      throw Exception('Summary response is not a List');
    }
    throw Exception('GET /products/summary failed: ${res.statusCode} ${res.body}');
  }

  static Map<String, dynamic> _productBody({
    required String name,
    required String code,
    required String size,
    required int quantity,
    required double price,
    required String productionDate,
  }) {
    return {
      "product_name": name,
      "barcode": code,
      "size": size,
      "unit_price": price,
      "quantity": quantity,
      "productionDate": productionDate,
    };
  }

  static Future<void> createProduct({
    required String name,
    required String code,
    required String size,
    required int quantity,
    required double price,
    required String productionDate,
  }) async {
    final res = await http.post(
      _u('/products'),
      headers: await _authHeaders(),
      body: jsonEncode(_productBody(
        name: name,
        code: code,
        size: size,
        quantity: quantity,
        price: price,
        productionDate: productionDate,
      )),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Create product failed: ${res.statusCode} ${res.body}');
    }
  }

  static Future<void> createProductWithImage({
    required String name,
    required String code,
    required String size,
    required int quantity,
    required double price,
    required String productionDate,
    required Uint8List imageBytes,
    required String imageFilename,
    String imageFieldName = 'image',
  }) async {
    final req = http.MultipartRequest('POST', _u('/products'));
    req.headers.addAll(await _authHeaders(json: false));

    req.fields['product_name'] = name;
    req.fields['barcode'] = code;
    req.fields['size'] = size;
    req.fields['unit_price'] = price.toString();
    req.fields['quantity'] = quantity.toString();
    req.fields['productionDate'] = productionDate;

    req.files.add(http.MultipartFile.fromBytes(imageFieldName, imageBytes, filename: imageFilename));

    final streamed = await req.send();
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw Exception('Create (multipart) failed: ${streamed.statusCode} $body');
    }
  }

  static Future<void> updateProduct({
    required int id,
    required String name,
    required String code,
    required String size,
    required int quantity,
    required double price,
    required String productionDate,
  }) async {
    final res = await http.put(
      _u('/products/$id'),
      headers: await _authHeaders(),
      body: jsonEncode(_productBody(
        name: name,
        code: code,
        size: size,
        quantity: quantity,
        price: price,
        productionDate: productionDate,
      )),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Update product failed: ${res.statusCode} ${res.body}');
    }
  }

  static Future<void> updateProductWithImage({
    required int id,
    required String name,
    required String code,
    required String size,
    required int quantity,
    required double price,
    required String productionDate,
    required Uint8List imageBytes,
    required String imageFilename,
    String imageFieldName = 'image',
  }) async {
    final req = http.MultipartRequest('PUT', _u('/products/$id'));
    req.headers.addAll(await _authHeaders(json: false));

    req.fields['product_name'] = name;
    req.fields['barcode'] = code;
    req.fields['size'] = size;
    req.fields['unit_price'] = price.toString();
    req.fields['quantity'] = quantity.toString();
    req.fields['productionDate'] = productionDate;

    req.files.add(http.MultipartFile.fromBytes(imageFieldName, imageBytes, filename: imageFilename));

    final streamed = await req.send();
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw Exception('Update (multipart) failed: ${streamed.statusCode} $body');
    }
  }

  static Future<void> deleteProduct(int id) async {
    final res = await http.delete(_u('/products/$id'), headers: await _authHeaders(json: false));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Delete product failed: ${res.statusCode} ${res.body}');
    }
  }

  static Future<void> updateGroupImage({
    required String productName,
    required Uint8List imageBytes,
    required String imageFilename,
    String imageFieldName = 'image',
  }) async {
    final req = http.MultipartRequest('PUT', _u('/products/group-image'));
    req.headers.addAll(await _authHeaders(json: false));

    req.fields['product_name'] = productName;
    req.files.add(http.MultipartFile.fromBytes(imageFieldName, imageBytes, filename: imageFilename));

    final streamed = await req.send();
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw Exception('Update group image failed: ${streamed.statusCode} $body');
    }
  }

  // ================= STOCK IN/OUT =================
  static Future<Map<String, dynamic>> stockIn({
    required String barcode,
    required int qty,
  }) async {
    final res = await http.post(
      _u('/stock/in'),
      headers: await _authHeaders(),
      body: jsonEncode({'barcode': barcode, 'qty': qty}),
    );
    final decoded = _decodeJson(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return decoded;
    throw Exception((decoded['error'] ?? 'stockIn failed').toString());
  }

  static Future<Map<String, dynamic>> stockOut({
    required String barcode,
    required int qty,
  }) async {
    final res = await http.post(
      _u('/stock/out'),
      headers: await _authHeaders(),
      body: jsonEncode({'barcode': barcode, 'qty': qty}),
    );
    final decoded = _decodeJson(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return decoded;
    throw Exception((decoded['error'] ?? 'stockOut failed').toString());
  }

  // ================= ✅ SALES HISTORY (Real) =================
  static Future<List<dynamic>> fetchSalesHistory({
    required String range, // today | 7d | 30d | all
    String query = '',
  }) async {
    final res = await http.get(
      Uri.parse('$baseUrl/sales?range=${Uri.encodeComponent(range)}&q=${Uri.encodeComponent(query)}'),
      headers: await _authHeaders(json: false),
    );

    if (res.statusCode == 401) throw Exception('UNAUTHORIZED');
    if (res.statusCode == 403) throw Exception('FORBIDDEN');

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final decoded = jsonDecode(res.body);
      if (decoded is List) return decoded;
      throw Exception('Sales response is not a List');
    }
    throw Exception('GET /sales failed: ${res.statusCode} ${res.body}');
  }

  static Future<Map<String, dynamic>> fetchSaleDetail(int saleId) async {
    final res = await http.get(
      _u('/sales/$saleId'),
      headers: await _authHeaders(json: false),
    );

    if (res.statusCode == 401) throw Exception('UNAUTHORIZED');
    if (res.statusCode == 403) throw Exception('FORBIDDEN');

    if (res.statusCode >= 200 && res.statusCode < 300) return _decodeJson(res.body);
    throw Exception('GET /sales/:id failed: ${res.statusCode} ${res.body}');
  }

  static Future<Map<String, dynamic>> createSale({
    String customerName = 'Walk-in',
    String paymentMethod = 'Cash',
    required List<Map<String, dynamic>> items, // [{barcode:"...", qty:2}]
  }) async {
    final res = await http.post(
      _u('/sales'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'customer_name': customerName,
        'payment_method': paymentMethod,
        'items': items,
      }),
    );

    final decoded = _decodeJson(res.body);
    if (res.statusCode == 401) throw Exception('UNAUTHORIZED');
    if (res.statusCode >= 200 && res.statusCode < 300) return decoded;
    throw Exception((decoded['error'] ?? 'Create sale failed').toString());
  }

  // ================= SHOP AVATAR (Shop logo) =================
  static Future<Map<String, dynamic>> updateShopAvatar({
    required int shopId,
    required Uint8List imageBytes,
    required String imageFilename,
    String imageFieldName = 'image',
  }) async {
    final req = http.MultipartRequest('PUT', _u('/shops/$shopId/avatar'));

    // ✅ แนบ token (+ x-shop-id ถ้ามี ก็ไม่เป็นไร เพราะ route นี้ไม่ใช้ shopRequired)
    req.headers.addAll(await _authHeaders(json: false));

    req.files.add(http.MultipartFile.fromBytes(
      imageFieldName,
      imageBytes,
      filename: imageFilename,
    ));

    final streamed = await req.send();
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
      return _decodeJson(body);
    }
    throw Exception('Update shop avatar failed: ${streamed.statusCode} $body');
  }

  // ================= SHOPS: UPDATE SHOP NAME (Admin only) =================
  static Future<Map<String, dynamic>> updateShopName({
    required int shopId,
    required String shopName,
  }) async {
    final res = await http.put(
      _u('/shops/$shopId'),
      headers: await _authHeaders(),
      body: jsonEncode({'shop_name': shopName.trim()}),
    );

    final decoded = _decodeJson(res.body);
    if (res.statusCode == 401) throw Exception('UNAUTHORIZED');
    if (res.statusCode == 403) throw Exception('FORBIDDEN');
    if (res.statusCode >= 200 && res.statusCode < 300) return decoded;

    throw Exception((decoded['error'] ?? 'Update shop name failed').toString());
  }
}