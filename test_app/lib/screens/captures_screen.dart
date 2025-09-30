import 'dart:io';

import 'package:flutter/material.dart';
import 'package:test_app/screens/preview_screen.dart';
import 'package:test_app/models/processed_image.dart';

class CapturesScreen extends StatelessWidget {
  final List<File> imageFileList;
  final List<ProcessedImage>? processedImages;

  const CapturesScreen({required this.imageFileList, this.processedImages});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        physics: BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Captures',
                style: TextStyle(fontSize: 32.0, color: Colors.white),
              ),
            ),
            GridView.count(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              children: [
                // Afficher les images traitées si disponibles
                if (processedImages != null && processedImages!.isNotEmpty)
                  ...processedImages!.map(
                    (processedImg) =>
                        _buildProcessedImageCard(context, processedImg),
                  )
                else
                  // Fallback vers les images originales
                  ...imageFileList.map(
                    (imageFile) => _buildOriginalImageCard(context, imageFile),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessedImageCard(
    BuildContext context,
    ProcessedImage processedImg,
  ) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Stack(
        children: [
          // Image principale (traitée si disponible, sinon originale)
          InkWell(
            onTap: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => PreviewScreen(
                    fileList: imageFileList,
                    imageFile: processedImg.hasProcessedImage
                        ? processedImg.processedImage!
                        : processedImg.originalImage,
                  ),
                ),
              );
            },
            child: Image.file(
              processedImg.hasProcessedImage
                  ? processedImg.processedImage!
                  : processedImg.originalImage,
              fit: BoxFit.cover,
            ),
          ),
          // Indicateurs d'état
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: _buildStatusIndicator(processedImg),
            ),
          ),
          // Bouton pour basculer entre original et traité
          if (processedImg.hasProcessedImage)
            Positioned(
              bottom: 4,
              right: 4,
              child: InkWell(
                onTap: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => PreviewScreen(
                        fileList: imageFileList,
                        imageFile: processedImg.originalImage,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(Icons.swap_horiz, color: Colors.white, size: 16),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOriginalImageCard(BuildContext context, File imageFile) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) =>
                  PreviewScreen(fileList: imageFileList, imageFile: imageFile),
            ),
          );
        },
        child: Image.file(imageFile, fit: BoxFit.cover),
      ),
    );
  }

  Widget _buildStatusIndicator(ProcessedImage processedImg) {
    if (processedImg.isProcessing) {
      return SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
        ),
      );
    } else if (processedImg.hasError) {
      return Icon(Icons.error_outline, color: Colors.red, size: 16);
    } else if (processedImg.hasProcessedImage) {
      return Icon(Icons.auto_fix_high, color: Colors.green, size: 16);
    } else {
      return Icon(Icons.image, color: Colors.white, size: 16);
    }
  }
}
