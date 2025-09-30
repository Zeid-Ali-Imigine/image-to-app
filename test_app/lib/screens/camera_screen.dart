import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:test_app/screens/preview_screen.dart';
import 'package:test_app/screens/ar_measure_screen.dart';
import 'package:test_app/screens/captures_screen.dart';
import 'package:test_app/services/background_removal_service.dart';
import 'package:test_app/models/processed_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';

import '../main.dart';

class CameraScreen extends StatefulWidget {
  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? controller;
  VideoPlayerController? videoController;

  File? _imageFile;
  File? _videoFile;

  // Initial values
  bool _isCameraInitialized = false;
  bool _isCameraPermissionGranted = false;
  // Only rear camera and photo mode are supported
  bool _isRecordingInProgress = false;
  double _minAvailableExposureOffset = 0.0;
  double _maxAvailableExposureOffset = 0.0;
  // Zoom disabled in this app

  // Current values
  double _currentExposureOffset = 0.0;
  FlashMode? _currentFlashMode;
  bool _showExposureControls = false;

  List<File> allFileList = [];
  List<ProcessedImage> processedImages = [];

  List<String> _products = [];

  // Background removal toggle
  bool _removeBackground = true;

  // Guidance frame configuration
  static const double _guideSize = 250.0; // Adjust size as needed
  GuideShape _guideShape = GuideShape.rectangle; // Change to circle if desired

  ResolutionPreset currentResolutionPreset = ResolutionPreset.max;

  Future<void> _loadProducts() async {
    try {
      final String rawJson = await rootBundle.loadString(
        'assets/products.json',
      );
      final List<dynamic> decoded = json.decode(rawJson) as List<dynamic>;
      setState(() {
        _products = decoded
            .map((dynamic e) => (e as Map<String, dynamic>)['name'] as String)
            .toList();
      });
    } catch (e) {
      log('Failed to load products: $e');
    }
  }

  Future<Map<String, dynamic>?> _showConfirmationDialog(
    File tempImage,
    DateTime captureTime,
    {double? initialDistance}
  ) async {
    String? selectedProduct;
    String weightText = '';
    double? measuredDistance = initialDistance;
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text('Confirmer la capture'),
          content: StatefulBuilder(
            builder: (BuildContext context, void Function(void Function()) setSt) {
              return SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      AspectRatio(
                        aspectRatio: 4 / 3,
                        child: Image.file(tempImage, fit: BoxFit.cover),
                      ),
                      SizedBox(height: 12),
                      if (measuredDistance != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Text(
                            'Distance mesurée: ${measuredDistance!.toStringAsFixed(2)} m',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      SizedBox(height: 12),
                      Text(
                        'Date: ${captureTime.toString()}',
                        style: TextStyle(fontSize: 14),
                      ),
                      SizedBox(height: 12),
                      TextFormField(
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Poids',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (val) => setSt(() => weightText = val),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Champ requis';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        items: _products
                            .map(
                              (String name) => DropdownMenuItem<String>(
                                value: name,
                                child: Text(name),
                              ),
                            )
                            .toList(),
                        onChanged: (val) => setSt(() => selectedProduct = val),
                        value: selectedProduct,
                        decoration: InputDecoration(
                          labelText: 'Produit',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return 'Champ requis';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop({'validated': false});
              },
              child: Text('Rejeter'),
            ),
            ElevatedButton(
              onPressed: () {
                if (!(formKey.currentState?.validate() ?? false)) {
                  formKey.currentState?.validate();
                  return;
                }
                Navigator.of(context).pop({
                  'validated': true,
                  'product': selectedProduct,
                  'weight': weightText,
                  'distance_m': measuredDistance,
                  'timestamp': captureTime.millisecondsSinceEpoch,
                });
              },
              child: Text('Valider'),
            ),
          ],
        );
      },
    );
  }

  getPermissionStatus() async {
    await Permission.camera.request();
    var status = await Permission.camera.status;

    if (status.isGranted) {
      log('Camera Permission: GRANTED');
      setState(() {
        _isCameraPermissionGranted = true;
      });
      // Set and initialize the new camera
      onNewCameraSelected(cameras[0]);
      refreshAlreadyCapturedImages();
    } else {
      log('Camera Permission: DENIED');
    }
  }

  refreshAlreadyCapturedImages() async {
    final directory = await getApplicationDocumentsDirectory();
    final List<FileSystemEntity> entries = await directory.list().toList();

    allFileList.clear();

    // Conserver uniquement les fichiers image/vidéo pertinents
    final List<File> files = entries.whereType<File>().where((f) {
      final p = f.path.toLowerCase();
      return p.endsWith('.jpg') || p.endsWith('.png') || p.endsWith('.mp4');
    }).toList();

    allFileList.addAll(files);

    if (files.isNotEmpty) {
      // Sélectionner le fichier le plus récent par date de modification
      files.sort((a, b) {
        final am = a.statSync().modified;
        final bm = b.statSync().modified;
        return bm.compareTo(am); // plus récent en premier
      });

      final File recent = files.first;
      final String recentName = recent.path.split('/').last;

      if (recentName.toLowerCase().endsWith('.mp4')) {
        _videoFile = File('${directory.path}/$recentName');
        _imageFile = null;
        _startVideoPlayer();
      } else {
        _imageFile = File('${directory.path}/$recentName');
        _videoFile = null;
      }

      setState(() {});
    }
  }

  Future<XFile?> takePicture() async {
    final CameraController? cameraController = controller;

    if (cameraController!.value.isTakingPicture) {
      // A capture is already pending, do nothing.
      return null;
    }

    try {
      XFile file = await cameraController.takePicture();
      return file;
    } on CameraException catch (e) {
      print('Error occured while taking picture: $e');
      return null;
    }
  }

  Future<void> _startVideoPlayer() async {
    if (_videoFile != null) {
      videoController = VideoPlayerController.file(_videoFile!);
      await videoController!.initialize().then((_) {
        // Ensure the first frame is shown after the video is initialized,
        // even before the play button has been pressed.
        setState(() {});
      });
      await videoController!.setLooping(true);
      await videoController!.play();
    }
  }

  Future<void> startVideoRecording() async {
    final CameraController? cameraController = controller;

    if (controller!.value.isRecordingVideo) {
      // A recording has already started, do nothing.
      return;
    }

    try {
      await cameraController!.startVideoRecording();
      setState(() {
        _isRecordingInProgress = true;
        print(_isRecordingInProgress);
      });
    } on CameraException catch (e) {
      print('Error starting to record video: $e');
    }
  }

  Future<XFile?> stopVideoRecording() async {
    if (!controller!.value.isRecordingVideo) {
      // Recording is already is stopped state
      return null;
    }

    try {
      XFile file = await controller!.stopVideoRecording();
      setState(() {
        _isRecordingInProgress = false;
      });
      return file;
    } on CameraException catch (e) {
      print('Error stopping video recording: $e');
      return null;
    }
  }

  Future<void> pauseVideoRecording() async {
    if (!controller!.value.isRecordingVideo) {
      // Video recording is not in progress
      return;
    }

    try {
      await controller!.pauseVideoRecording();
    } on CameraException catch (e) {
      print('Error pausing video recording: $e');
    }
  }

  Future<void> resumeVideoRecording() async {
    if (!controller!.value.isRecordingVideo) {
      // No video recording was in progress
      return;
    }

    try {
      await controller!.resumeVideoRecording();
    } on CameraException catch (e) {
      print('Error resuming video recording: $e');
    }
  }

  void resetCameraValues() async {
    _currentExposureOffset = 0.0;
  }

  void onNewCameraSelected(CameraDescription cameraDescription) async {
    final previousCameraController = controller;

    final CameraController cameraController = CameraController(
      cameraDescription,
      currentResolutionPreset,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await previousCameraController?.dispose();

    resetCameraValues();

    if (mounted) {
      setState(() {
        controller = cameraController;
      });
    }

    // Update UI if controller updated
    cameraController.addListener(() {
      if (mounted) setState(() {});
    });

    try {
      await cameraController.initialize();
      await Future.wait([
        cameraController.getMinExposureOffset().then(
          (value) => _minAvailableExposureOffset = value,
        ),
        cameraController.getMaxExposureOffset().then(
          (value) => _maxAvailableExposureOffset = value,
        ),
        // Zoom levels are not used
      ]);

      _currentFlashMode = controller!.value.flashMode;
    } on CameraException catch (e) {
      print('Error initializing camera: $e');
    }

    if (mounted) {
      setState(() {
        _isCameraInitialized = controller!.value.isInitialized;
      });
    }
  }

  void onViewFinderTap(TapDownDetails details, BoxConstraints constraints) {
    if (controller == null) {
      return;
    }

    final offset = Offset(
      details.localPosition.dx / constraints.maxWidth,
      details.localPosition.dy / constraints.maxHeight,
    );
    controller!.setExposurePoint(offset);
    controller!.setFocusPoint(offset);
  }

  @override
  void initState() {
    // Hide the status bar in Android
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    getPermissionStatus();
    _loadProducts();
    super.initState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = controller;

    // App state changed before we got the chance to initialize.
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      onNewCameraSelected(cameraController.description);
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _isCameraPermissionGranted
            ? _isCameraInitialized
                  ? Stack(
                      children: [
                        Positioned.fill(
                          child: AspectRatio(
                            aspectRatio: 1 / controller!.value.aspectRatio,
                            child: Stack(
                              children: [
                                CameraPreview(
                                  controller!,
                                  child: LayoutBuilder(
                                    builder:
                                        (
                                          BuildContext context,
                                          BoxConstraints constraints,
                                        ) {
                                          return GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTapDown: (details) =>
                                                onViewFinderTap(
                                                  details,
                                                  constraints,
                                                ),
                                          );
                                        },
                                  ),
                                ),
                                // Centered guidance frame overlay (transparent fill, green border)
                                Center(
                                  child: IgnorePointer(
                                    child: SizedBox(
                                      width: _guideSize,
                                      height: _guideSize,
                                      child: _GuideFrame(shape: _guideShape),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16.0,
                                    8.0,
                                    16.0,
                                    8.0,
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      SizedBox.shrink(),
                                      // Spacer(),
                                      if (_showExposureControls)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            right: 8.0,
                                            top: 16.0,
                                          ),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(10.0),
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.all(
                                                8.0,
                                              ),
                                              child: Text(
                                                _currentExposureOffset
                                                        .toStringAsFixed(1) +
                                                    ' EV',
                                                style: TextStyle(
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      if (_showExposureControls)
                                        Expanded(
                                          child: RotatedBox(
                                            quarterTurns: 3,
                                            child: Container(
                                              height: 30,
                                              child: Slider(
                                                value: _currentExposureOffset,
                                                min:
                                                    _minAvailableExposureOffset,
                                                max:
                                                    _maxAvailableExposureOffset,
                                                activeColor: Colors.white,
                                                inactiveColor: Colors.white30,
                                                onChanged: (value) async {
                                                  setState(() {
                                                    _currentExposureOffset =
                                                        value;
                                                  });
                                                  await controller!
                                                      .setExposureOffset(value);
                                                },
                                              ),
                                            ),
                                          ),
                                        ),
                                      // Preview thumbnail moved to bottom bar
                                      InkWell(
                                        onTap:
                                            _imageFile != null ||
                                                _videoFile != null
                                            ? () {
                                                Navigator.of(context).push(
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        PreviewScreen(
                                                          imageFile:
                                                              _imageFile!,
                                                          fileList: allFileList,
                                                        ),
                                                  ),
                                                );
                                              }
                                            : null,
                                        child: Container(
                                          width: 60,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            color: Colors.black,
                                            borderRadius: BorderRadius.circular(
                                              10.0,
                                            ),
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 2,
                                            ),
                                            image: _imageFile != null
                                                ? DecorationImage(
                                                    image: FileImage(
                                                      _imageFile!,
                                                    ),
                                                    fit: BoxFit.cover,
                                                  )
                                                : null,
                                          ),
                                          child:
                                              videoController != null &&
                                                  videoController!
                                                      .value
                                                      .isInitialized
                                              ? ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        8.0,
                                                      ),
                                                  child: AspectRatio(
                                                    aspectRatio:
                                                        videoController!
                                                            .value
                                                            .aspectRatio,
                                                    child: VideoPlayer(
                                                      videoController!,
                                                    ),
                                                  ),
                                                )
                                              : Container(),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Bottom controls - simplified layout
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 120,
                            color: Colors.black.withOpacity(0.8),
                            child: Column(
                              children: [
                                // Top row: Toggle suppression fond
                                Container(
                                  height: 30,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.auto_fix_high,
                                        color: Colors.green,
                                        size: 16,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Suppression fond',
                                        style: TextStyle(
                                          color: Colors.green,
                                          fontSize: 10,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Switch(
                                        value: _removeBackground,
                                        onChanged: (value) {
                                          setState(() {
                                            _removeBackground = value;
                                          });
                                        },
                                        activeColor: Colors.green,
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ],
                                  ),
                                ),
                                // Bottom row: Capture button
                                Expanded(
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      // Flash Off
                                      IconButton(
                                        onPressed: () async {
                                          await controller?.setFlashMode(
                                            FlashMode.off,
                                          );
                                          setState(
                                            () => _currentFlashMode =
                                                FlashMode.off,
                                          );
                                        },
                                        icon: Icon(
                                          Icons.flash_off,
                                          color:
                                              _currentFlashMode == FlashMode.off
                                              ? Colors.amber
                                              : Colors.white,
                                          size: 24,
                                        ),
                                      ),
                                      // Capture Button - BIG AND VISIBLE
                                      InkWell(
                                        onTap: () async {
                                          XFile? rawImage = await takePicture();
                                          if (rawImage == null) return;
                                          final File tempImage = File(
                                            rawImage.path,
                                          );
                                          final DateTime now = DateTime.now();
                                          // Get distance automatically via AR screen first
                                          final double? d = await Navigator.of(context).push<double>(
                                            MaterialPageRoute(
                                              builder: (_) => const ARMeasureScreen(),
                                            ),
                                          );
                                          final Map<String, dynamic>? result =
                                              await _showConfirmationDialog(
                                                tempImage,
                                                now,
                                                initialDistance: d,
                                              );
                                          if (result == null) return;
                                          if (result['validated'] == true) {
                                            await _processAndSaveImage(
                                              tempImage,
                                              now,
                                              result,
                                            );
                                          } else {
                                            try {
                                              await tempImage.delete();
                                            } catch (_) {}
                                          }
                                        },
                                        child: Container(
                                          width: 70,
                                          height: 70,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.white,
                                            border: Border.all(
                                              color: Colors.white38,
                                              width: 3,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.camera_alt,
                                            color: Colors.black,
                                            size: 35,
                                          ),
                                        ),
                                      ),
                                      // Flash On
                                      IconButton(
                                        onPressed: () async {
                                          await controller?.setFlashMode(
                                            FlashMode.always,
                                          );
                                          setState(
                                            () => _currentFlashMode =
                                                FlashMode.always,
                                          );
                                        },
                                        icon: Icon(
                                          Icons.flash_on,
                                          color:
                                              _currentFlashMode ==
                                                  FlashMode.always
                                              ? Colors.amber
                                              : Colors.white,
                                          size: 24,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Center(
                      child: Text(
                        'LOADING',
                        style: TextStyle(color: Colors.white),
                      ),
                    )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(),
                  Text(
                    'Permission denied',
                    style: TextStyle(color: Colors.white, fontSize: 24),
                  ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      getPermissionStatus();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'Give permission',
                        style: TextStyle(color: Colors.white, fontSize: 24),
                      ),
                    ),
                  ),
                ],
              ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => CapturesScreen(
                  imageFileList: allFileList,
                  processedImages: processedImages,
                ),
              ),
            );
          },
          backgroundColor: Colors.blue,
          child: Icon(Icons.photo_library, color: Colors.white),
        ),
      ),
    );
  }

  /// Traite et sauvegarde une image avec suppression optionnelle du fond
  Future<void> _processAndSaveImage(
    File tempImage,
    DateTime captureTime,
    Map<String, dynamic> result,
  ) async {
    try {
      final Directory directory = await getApplicationDocumentsDirectory();
      final String fileFormat = tempImage.path.split('.').last;
      final int ts =
          (result['timestamp'] as int?) ?? captureTime.millisecondsSinceEpoch;

      // Sauvegarder l'image originale
      final String originalPath =
          '${directory.path}/${ts}_original.$fileFormat';
      final File originalFile = await tempImage.copy(originalPath);

      ProcessedImage processedImage = ProcessedImage(
        originalImage: originalFile,
      );

      if (_removeBackground) {
        // Ajouter l'image en cours de traitement
        setState(() {
          processedImage = processedImage.copyWith(isProcessing: true);
          processedImages.insert(0, processedImage);
        });

        try {
          // Traiter l'image pour supprimer le fond
          final String processedPath =
              '${directory.path}/${ts}_processed.$fileFormat';
          final File processedFile =
              await BackgroundRemovalService.processImage(
                originalFile,
                processedPath,
              );

          // Mettre à jour avec l'image traitée
          setState(() {
            final index = processedImages.indexWhere(
              (img) => img.originalImage.path == originalFile.path,
            );
            if (index != -1) {
              processedImages[index] = processedImage.copyWith(
                processedImage: processedFile,
                isProcessing: false,
              );
            }
          });
        } catch (e) {
          // En cas d'erreur, garder seulement l'image originale
          setState(() {
            final index = processedImages.indexWhere(
              (img) => img.originalImage.path == originalFile.path,
            );
            if (index != -1) {
              processedImages[index] = processedImage.copyWith(
                isProcessing: false,
                error: 'Erreur suppression fond: $e',
              );
            }
          });
        }
      } else {
        // Sans suppression de fond, ajouter directement l'image originale
        setState(() {
          processedImages.insert(0, processedImage);
        });
      }

      await refreshAlreadyCapturedImages();
    } catch (e) {
      print('Erreur lors de la sauvegarde: $e');
    }
  }
}

enum GuideShape { rectangle, circle }

class _GuideFrame extends StatelessWidget {
  final GuideShape shape;

  const _GuideFrame({required this.shape});

  @override
  Widget build(BuildContext context) {
    switch (shape) {
      case GuideShape.circle:
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.greenAccent, width: 3),
          ),
        );
      case GuideShape.rectangle:
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.greenAccent, width: 3),
            borderRadius: BorderRadius.circular(12),
          ),
        );
    }
  }
}
