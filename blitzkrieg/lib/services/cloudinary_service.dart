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
  /// Returns a map with 'url', 'secure_url', 'public_id' on success.
  /// Throws an exception on failure.
  static Future<Map<String, dynamic>> uploadImage(
    File imageFile, {
    String? customFolder,
  }) async {
    final uploadFolder = customFolder ?? folder;
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Generate signature for signed upload
    final paramsToSign = 'folder=$uploadFolder&timestamp=$timestamp$apiSecret';
    final signature = sha1.convert(utf8.encode(paramsToSign)).toString();

    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
    );

    final request = http.MultipartRequest('POST', uri)
      ..fields['api_key'] = apiKey
      ..fields['timestamp'] = timestamp.toString()
      ..fields['signature'] = signature
      ..fields['folder'] = uploadFolder
      ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

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
      };
    } else {
      final error = json.decode(response.body);
      throw Exception(
        'Cloudinary upload failed: ${error['error']?['message'] ?? response.body}',
      );
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

  /// Get the URL for a Cloudinary image with optional transformations.
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
