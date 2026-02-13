import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class CloudinaryService {
  static String get cloudName => dotenv.env['CLOUD_NAME'] ?? '';
  static String get apiKey => dotenv.env['CLOUDINARY_API_KEY'] ?? '';
  static String get apiSecret => dotenv.env['CLOUDINARY_API_SECRET'] ?? '';
  static String get folder =>
      dotenv.env['CLOUDINARY_UPLOAD_FOLDER'] ?? 'blitzkrieg_bereal';

  /// Upload an image to Cloudinary using signed upload.
  /// [subfolder] is appended to the base folder (e.g., 'back' or 'front').
  static Future<Map<String, dynamic>> uploadImage(
    File imageFile, {
    String? subfolder,
    String? publicId,
    String? caption,
  }) async {
    final uploadFolder = subfolder != null ? '$folder/$subfolder' : folder;
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Generate signature for signed upload
    // Parameters must be sorted alphabetically
    final Map<String, String> params = {
      'folder': uploadFolder,
      'timestamp': timestamp.toString(),
    };
    if (publicId != null) {
      params['public_id'] = publicId;
    }
    if (caption != null && caption.isNotEmpty) {
      // Escape special characters for Cloudinary context
      final sanitizedCaption = caption
          .replaceAll('|', '\\|')
          .replaceAll('=', '\\=');
      params['context'] = 'caption=$sanitizedCaption';
    }

    // Sort and join
    final sortedKeys = params.keys.toList()..sort();
    final paramsToSign =
        sortedKeys.map((key) => '$key=${params[key]}').join('&') + apiSecret;

    final signature = sha1.convert(utf8.encode(paramsToSign)).toString();

    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
    );

    final request = http.MultipartRequest('POST', uri)
      ..fields['api_key'] = apiKey
      ..fields['timestamp'] = timestamp.toString()
      ..fields['signature'] = signature
      ..fields['folder'] = uploadFolder;

    if (publicId != null) {
      request.fields['public_id'] = publicId;
    }
    if (params.containsKey('context')) {
      request.fields['context'] = params['context']!;
    }

    request.files.add(
      await http.MultipartFile.fromPath('file', imageFile.path),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return {
        'url': data['url'],
        'secure_url': data['secure_url'],
        'public_id': data['public_id'],
        'created_at': data['created_at'],
        'width': data['width'],
        'height': data['height'],
        'format': data['format'],
        'bytes': data['bytes'],
        'context': data['context'],
      };
    } else {
      final error = json.decode(response.body);
      throw Exception(
        'Upload failed: ${error['error']?['message'] ?? response.body}',
      );
    }
  }

  /// List all images in the BeReal folder from Cloudinary.
  /// Uses the Admin API with basic auth.
  static Future<List<Map<String, dynamic>>> listImages({
    int maxResults = 30,
  }) async {
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/resources/search',
    );

    final basicAuth =
        'Basic ${base64Encode(utf8.encode('$apiKey:$apiSecret'))}';

    final response = await http.post(
      uri,
      headers: {'Authorization': basicAuth, 'Content-Type': 'application/json'},
      body: json.encode({
        'expression': 'folder:$folder/*',
        'sort_by': [
          {'created_at': 'desc'},
        ],
        'max_results': maxResults,
        'with_field': ['context'],
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final resources = data['resources'] as List<dynamic>? ?? [];
      return resources.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to fetch images: ${response.body}');
    }
  }

  /// Delete an image from Cloudinary by public_id.
  static Future<bool> deleteImage(String publicId) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final paramsToSign = 'public_id=$publicId&timestamp=$timestamp$apiSecret';
    final signature = sha1.convert(utf8.encode(paramsToSign)).toString();

    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/image/destroy',
    );

    final response = await http.post(
      uri,
      body: {
        'public_id': publicId,
        'api_key': apiKey,
        'timestamp': timestamp.toString(),
        'signature': signature,
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['result'] == 'ok';
    }
    return false;
  }

  /// Build a Cloudinary URL with optional transformations.
  static String getImageUrl(
    String publicId, {
    int? width,
    int? height,
    String? crop,
  }) {
    String transformation = '';
    if (width != null || height != null || crop != null) {
      final parts = <String>[];
      if (width != null) parts.add('w_$width');
      if (height != null) parts.add('h_$height');
      if (crop != null) parts.add('c_$crop');
      transformation = '${parts.join(',')}/';
    }
    return 'https://res.cloudinary.com/$cloudName/image/upload/$transformation$publicId';
  }
}
