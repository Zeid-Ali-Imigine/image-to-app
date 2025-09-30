import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class BackgroundRemovalService {
  static bool get isConfigured =>
      ApiConfig.isApiKeyConfigured || ApiConfig.isHuggingFaceConfigured;

  static Future<String> removeBackground(File imageFile) async {
    if (ApiConfig.demoMode) {
      print('[RMBG][DEMO] Pas d\'appel réseau.');
      await Future.delayed(Duration(seconds: 1));
      return imageFile.path;
    }

    if (ApiConfig.useHuggingFace && ApiConfig.isHuggingFaceConfigured) {
      return _removeWithHuggingFace(imageFile);
    }

    if (ApiConfig.isApiKeyConfigured) {
      return _removeWithBria(imageFile);
    }

    throw Exception('Aucune configuration API valide (HF ou BRIA).');
  }

  static Future<String> _removeWithBria(File imageFile) async {
    try {
      final uri = Uri.parse(ApiConfig.backgroundRemovalUrl);
      print('[BRIA] POST ${uri.toString()}');
      final request = http.MultipartRequest('POST', uri);
      request.headers['api_token'] = ApiConfig.briaApiKey;
      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );
      final res = await request.send();
      print('[BRIA] STATUS ${res.statusCode}');
      final body = await res.stream.bytesToString();
      if (res.statusCode == 200) {
        print('[BRIA] BODY $body');
        final data = json.decode(body);
        final url = data['result_url'] as String?;
        if (url == null || url.isEmpty)
          throw Exception('Réponse BRIA sans result_url');
        return url;
      }
      print('[BRIA][ERROR] BODY $body');
      throw Exception('Erreur BRIA: ${res.statusCode}');
    } catch (e) {
      print('[BRIA][EXCEPTION] $e');
      rethrow;
    }
  }

  static Future<String> _removeWithHuggingFace(File imageFile) async {
    try {
      final uri = Uri.parse(ApiConfig.huggingFaceModelEndpoint);
      print('[HF] POST ${uri.toString()}');
      final bytes = await imageFile.readAsBytes();
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer ${ApiConfig.huggingFaceToken}',
          'Accept': 'image/png',
          'Content-Type': 'application/octet-stream',
        },
        body: bytes,
      );
      print('[HF] STATUS ${response.statusCode}');
      if (response.statusCode == 200) {
        // Sauvegarder le PNG renvoyé (image avec fond transparent)
        final Directory dir = await Directory.systemTemp.createTemp('rmbg');
        final String outPath =
            '${dir.path}/${DateTime.now().millisecondsSinceEpoch}_rmbg.png';
        final outFile = File(outPath);
        await outFile.writeAsBytes(response.bodyBytes);
        print('[HF] PNG saved -> $outPath');
        // Retourner un file:// path pour le pipeline existant (download step bypassé)
        return outFile.uri.toString();
      }
      // En cas d'erreur, Hugging Face renvoie du JSON
      print('[HF][ERROR] BODY ${response.body}');
      // Fallback automatique vers BRIA si token HF insuffisant et BRIA est configuré
      if ((response.statusCode == 401 || response.statusCode == 403) &&
          ApiConfig.isApiKeyConfigured) {
        print('[HF] ${response.statusCode} -> Fallback BRIA');
        return _removeWithBria(imageFile);
      }
      throw Exception('Erreur HF: ${response.statusCode}');
    } catch (e) {
      print('[HF][EXCEPTION] $e');
      rethrow;
    }
  }

  static Future<File> downloadImage(String imageUrl, String localPath) async {
    try {
      if (imageUrl.startsWith('file://')) {
        // Cas Hugging Face: on a déjà un PNG local
        final src = File(Uri.parse(imageUrl).toFilePath());
        return await src.copy(localPath);
      }
      print('[DL] $imageUrl -> $localPath');
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        final file = File(localPath);
        await file.writeAsBytes(response.bodyBytes);
        print('[DL] OK ${response.bodyBytes.length} bytes');
        return file;
      } else {
        print('[DL][ERROR] ${response.statusCode}');
        throw Exception('Erreur téléchargement: ${response.statusCode}');
      }
    } catch (e) {
      print('[DL][EXCEPTION] $e');
      rethrow;
    }
  }

  static Future<File> processImage(
    File originalImageFile,
    String outputPath,
  ) async {
    final processedImageUrl = await removeBackground(originalImageFile);
    if (processedImageUrl.startsWith('file://')) {
      // Copie du PNG local vers outputPath
      final src = File(Uri.parse(processedImageUrl).toFilePath());
      return await src.copy(outputPath);
    }
    return await downloadImage(processedImageUrl, outputPath);
  }
}
