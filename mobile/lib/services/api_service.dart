import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  static const _base = 'http://167.99.161.64:3001';

  static Future<List<dynamic>> getNearbyDrops(double lat, double lng, double km) async {
    final res = await http.get(Uri.parse('$_base/drops/nearby?lat=$lat&lng=$lng&radius=$km'))
        .timeout(const Duration(seconds: 10));
    return (jsonDecode(res.body)['drops'] ?? []) as List;
  }

  static Future<Map<String, dynamic>> verifyLocation({
    required String dropId, required double lat, required double lng, required String wallet,
  }) async {
    final res = await http.post(Uri.parse('$_base/verify'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'dropId': dropId, 'lat': lat, 'lng': lng, 'walletAddress': wallet,
        'timestamp': DateTime.now().millisecondsSinceEpoch}));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> mintNFT(String token) async {
    final res = await http.post(Uri.parse('$_base/mint'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'claimToken': token}));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> createDrop({
    required String name, required String description, required String creatorWallet,
    required double lat, required double lng, required int radiusMeters,
    required int supply, required String endsAt, required File image,
  }) async {
    final req = http.MultipartRequest('POST', Uri.parse('$_base/drops'));
    req.fields.addAll({'name': name, 'description': description, 'creatorWallet': creatorWallet,
      'lat': '$lat', 'lng': '$lng', 'radiusMeters': '$radiusMeters', 'supply': '$supply', 'endsAt': endsAt});
    req.files.add(await http.MultipartFile.fromPath('image', image.path));
    final res = await http.Response.fromStream(await req.send());
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<List<dynamic>> getWalletClaims(String wallet) async {
    final res = await http.get(Uri.parse('$_base/claims?wallet=$wallet'));
    return (jsonDecode(res.body)['claims'] ?? []) as List;
  }
}
