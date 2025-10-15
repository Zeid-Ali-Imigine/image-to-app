import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

class ImageValidationResult {
  final bool isValid;
  final List<String> errors;
  final Map<String, dynamic> metrics;

  ImageValidationResult({
    required this.isValid,
    required this.errors,
    required this.metrics,
  });
}

class ImageValidationService {
  /// Valide une image selon les critères définis
  static Future<ImageValidationResult> validateImage(File imageFile) async {
    List<String> errors = [];
    Map<String, dynamic> metrics = {};

    try {
      // Charger l'image
      final Uint8List bytes = await imageFile.readAsBytes();
      final img.Image? image = img.decodeImage(bytes);

      if (image == null) {
        errors.add('Impossible de lire l\'image');
        return ImageValidationResult(
          isValid: false,
          errors: errors,
          metrics: metrics,
        );
      }

      // 1. Vérifier la clarté de l'image (netteté)
      final double sharpness = _calculateSharpness(image);
      metrics['sharpness'] = sharpness;
      if (sharpness < 50.0) {
        errors.add('Image floue - veuillez reprendre la photo');
      }

      // 2. Vérifier si l'objet est coupé (détection des bords)
      final bool isCropped = _detectCroppedObject(image);
      metrics['is_cropped'] = isCropped;
      if (isCropped) {
        errors.add('Objet coupé - assurez-vous que l\'objet soit entièrement visible');
      }

      // 3. Vérifier qu'il y a un seul objet (comptage approximatif)
      final int objectCount = _estimateObjectCount(image);
      metrics['object_count'] = objectCount;
      if (objectCount == 0) {
        errors.add('Aucun objet détecté dans l\'image');
      } else if (objectCount > 1) {
        errors.add('Plusieurs objets détectés - veuillez photographier un seul objet');
      }

      // 4. Vérifier la qualité de présentation (contraste et luminosité)
      final Map<String, double> quality = _checkPresentationQuality(image);
      metrics['contrast'] = quality['contrast'];
      metrics['brightness'] = quality['brightness'];
      
      if (quality['contrast']! < 30.0) {
        errors.add('Contraste insuffisant - améliorez l\'éclairage');
      }
      
      if (quality['brightness']! < 80.0 || quality['brightness']! > 200.0) {
        errors.add('Luminosité inadéquate - ajustez l\'éclairage');
      }

      return ImageValidationResult(
        isValid: errors.isEmpty,
        errors: errors,
        metrics: metrics,
      );
    } catch (e) {
      errors.add('Erreur lors de la validation: $e');
      return ImageValidationResult(
        isValid: false,
        errors: errors,
        metrics: metrics,
      );
    }
  }

  /// Calcule la netteté de l'image (détection des contours Laplacien)
  static double _calculateSharpness(img.Image image) {
    // Convertir en niveaux de gris
    final img.Image gray = img.grayscale(image);
    
    double laplacianVariance = 0.0;
    int count = 0;

    // Appliquer un filtre Laplacien simplifié
    for (int y = 1; y < gray.height - 1; y++) {
      for (int x = 1; x < gray.width - 1; x++) {
        final int center = gray.getPixel(x, y).r.toInt();
        final int top = gray.getPixel(x, y - 1).r.toInt();
        final int bottom = gray.getPixel(x, y + 1).r.toInt();
        final int left = gray.getPixel(x - 1, y).r.toInt();
        final int right = gray.getPixel(x + 1, y).r.toInt();

        final int laplacian = (4 * center - top - bottom - left - right).abs();
        laplacianVariance += laplacian * laplacian;
        count++;
      }
    }

    return count > 0 ? laplacianVariance / count : 0.0;
  }

  /// Détecte si l'objet est coupé en vérifiant les bords
  static bool _detectCroppedObject(img.Image image) {
    // 1) Binariser via seuillage automatique (Otsu)
    final List<List<bool>> mask = _binarizeForeground(image);

    // 2) Trouver la plus grande composante connectée de premier plan
    final _ComponentInfo mainComp = _findLargestComponent(mask);

    // 3) Si la composante principale touche un des bords, l'objet est probablement coupé
    return mainComp.touchesBorder;
  }

  static bool _isEdgePixel(img.Image image, int x, int y, int threshold) {
    if (x <= 0 || x >= image.width - 1 || y <= 0 || y >= image.height - 1) {
      return false;
    }

    final int center = image.getPixel(x, y).luminance.toInt();
    final int top = image.getPixel(x, y - 1).luminance.toInt();
    final int bottom = image.getPixel(x, y + 1).luminance.toInt();
    final int left = image.getPixel(x - 1, y).luminance.toInt();
    final int right = image.getPixel(x + 1, y).luminance.toInt();

    final int gradient = ((center - top).abs() +
            (center - bottom).abs() +
            (center - left).abs() +
            (center - right).abs()) ~/
        4;

    return gradient > threshold;
  }

  static List<List<bool>> _binarizeForeground(img.Image image) {
    // Histogramme de luminance
    final List<int> hist = List.filled(256, 0);
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final int l = image.getPixel(x, y).luminance.toInt().clamp(0, 255);
        hist[l]++;
      }
    }

    // Seuil d'Otsu
    final int total = image.width * image.height;
    int sumAll = 0;
    for (int i = 0; i < 256; i++) {
      sumAll += i * hist[i];
    }
    int sumB = 0;
    int wB = 0;
    double maxVar = -1;
    int threshold = 128;
    for (int t = 0; t < 256; t++) {
      wB += hist[t];
      if (wB == 0) continue;
      final int wF = total - wB;
      if (wF == 0) break;
      sumB += t * hist[t];
      final double mB = sumB / wB;
      final double mF = (sumAll - sumB) / wF;
      final double betweenVar = wB * wF * (mB - mF) * (mB - mF);
      if (betweenVar > maxVar) {
        maxVar = betweenVar;
        threshold = t;
      }
    }

    // Premier plan = pixels plus sombres que le seuil (par défaut)
    List<List<bool>> mask = List.generate(
      image.height,
      (_) => List.filled(image.width, false),
    );
    int foregroundCount = 0;
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final int l = image.getPixel(x, y).luminance.toInt();
        final bool isFg = l < threshold;
        mask[y][x] = isFg;
        if (isFg) foregroundCount++;
      }
    }

    // Si la majorité est premier plan, inverser (on suppose l'objet minoritaire)
    if (foregroundCount > (total / 2)) {
      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          mask[y][x] = !mask[y][x];
        }
      }
    }

    return mask;
  }

  static _ComponentInfo _findLargestComponent(List<List<bool>> mask) {
    final int height = mask.length;
    final int width = mask.isEmpty ? 0 : mask[0].length;
    List<List<bool>> visited = List.generate(
      height,
      (_) => List.filled(width, false),
    );

    int bestSize = 0;
    bool bestTouchesBorder = false;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (!mask[y][x] || visited[y][x]) continue;
        final _ComponentInfo info = _floodFillMask(mask, visited, x, y);
        if (info.size > bestSize) {
          bestSize = info.size;
          bestTouchesBorder = info.touchesBorder;
        }
      }
    }

    return _ComponentInfo(size: bestSize, touchesBorder: bestTouchesBorder);
  }

  static _ComponentInfo _floodFillMask(
    List<List<bool>> mask,
    List<List<bool>> visited,
    int startX,
    int startY,
  ) {
    final int height = mask.length;
    final int width = mask.isEmpty ? 0 : mask[0].length;
    List<List<int>> stack = [[startX, startY]];
    int size = 0;
    bool touchesBorder = false;

    while (stack.isNotEmpty) {
      final List<int> p = stack.removeLast();
      final int x = p[0];
      final int y = p[1];
      if (x < 0 || x >= width || y < 0 || y >= height) continue;
      if (visited[y][x]) continue;
      if (!mask[y][x]) continue;
      visited[y][x] = true;
      size++;
      if (x == 0 || y == 0 || x == width - 1 || y == height - 1) {
        touchesBorder = true;
      }

      // Parcours 4-connexe
      stack.add([x + 1, y]);
      stack.add([x - 1, y]);
      stack.add([x, y + 1]);
      stack.add([x, y - 1]);
    }

    return _ComponentInfo(size: size, touchesBorder: touchesBorder);
  }

  

  /// Estime le nombre d'objets dans l'image (algorithme simplifié)
  static int _estimateObjectCount(img.Image image) {
    // Binariser via Otsu
    final List<List<bool>> mask = _binarizeForeground(image);

    // Compter les composantes connectées significatives
    final int height = mask.length;
    final int width = height == 0 ? 0 : mask[0].length;
    List<List<bool>> visited = List.generate(
      height,
      (_) => List.filled(width, false),
    );

    int objectCount = 0;
    final int minObjectSize = (width * height * 0.01).round(); // 1% de l'image

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (!mask[y][x] || visited[y][x]) continue;
        final _ComponentInfo info = _floodFillMask(mask, visited, x, y);
        if (info.size >= minObjectSize) {
          objectCount++;
        }
      }
    }

    return objectCount;
  }

  /// Vérifie la qualité de présentation (contraste et luminosité)
  static Map<String, double> _checkPresentationQuality(img.Image image) {
    int totalBrightness = 0;
    List<int> brightnesses = [];

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final int brightness = image.getPixel(x, y).luminance.toInt();
        totalBrightness += brightness;
        brightnesses.add(brightness);
      }
    }

    final int pixelCount = image.width * image.height;
    final double avgBrightness = totalBrightness / pixelCount;

    // Calculer l'écart-type pour le contraste
    double variance = 0.0;
    for (int brightness in brightnesses) {
      variance += (brightness - avgBrightness) * (brightness - avgBrightness);
    }
    final double stdDev = variance > 0 ? (variance / pixelCount).abs().sqrt() : 0.0;

    return {
      'brightness': avgBrightness,
      'contrast': stdDev,
    };
  }
}

class _ComponentInfo {
  final int size;
  final bool touchesBorder;
  _ComponentInfo({required this.size, required this.touchesBorder});
}

extension on int {
  double sqrt() => this < 0 ? 0.0 : this.toDouble().abs().sqrt();
}

extension on double {
  double sqrt() {
    if (this <= 0) return 0.0;
    double x = this;
    double prev;
    do {
      prev = x;
      x = (x + this / x) / 2;
    } while ((x - prev).abs() > 0.0001);
    return x;
  }
}