import 'dart:io';

class ProcessedImage {
  final File originalImage;
  final File? processedImage; // Image sans fond
  final bool isProcessing;
  final String? error;
  final DateTime timestamp;

  ProcessedImage({
    required this.originalImage,
    this.processedImage,
    this.isProcessing = false,
    this.error,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  ProcessedImage copyWith({
    File? originalImage,
    File? processedImage,
    bool? isProcessing,
    String? error,
    DateTime? timestamp,
  }) {
    return ProcessedImage(
      originalImage: originalImage ?? this.originalImage,
      processedImage: processedImage ?? this.processedImage,
      isProcessing: isProcessing ?? this.isProcessing,
      error: error ?? this.error,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  bool get hasProcessedImage => processedImage != null;
  bool get hasError => error != null;
}



