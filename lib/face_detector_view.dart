import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

class FaceDetectorView extends StatefulWidget {
  @override
  State<FaceDetectorView> createState() => _FaceDetectorViewState();
}

class _FaceDetectorViewState extends State<FaceDetectorView> {
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableClassification: true,
      enableLandmarks: true,
    ),
  );
  bool _canProcess = true;
  bool _isBusy = false;
  CustomPaint? _customPaint;
  String? _text;

  //For camera
  File? _image;
  String? _path;
  ImagePicker? _imagePicker;
  InputImage? _inputImage;
  bool? isSuccess;
  int faceCount = 9;
  double eyeCenter = 1250.0;
  bool isLoading = false;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _imagePicker = ImagePicker();
  }

  @override
  void dispose() {
    _canProcess = false;
    _faceDetector.close();
    super.dispose();
  }

  Future _getImage() async {
    setState(() {
      _image = null;
      _path = null;
      isLoading = true;
    });
    try {
      final pickedFile = await _imagePicker?.pickImage(
        source: ImageSource.camera,
        imageQuality: 100,
        preferredCameraDevice: CameraDevice.front,
      );
      if (pickedFile != null) {
        _cropImage(imagePath: pickedFile);
      }
    } catch (e) {
      print("Error from camera: $e");
    }
  }

  void _cropImage({required XFile imagePath}) async {
    CroppedFile? croppedFile = await ImageCropper().cropImage(
      sourcePath: imagePath.path,
      aspectRatio: const CropAspectRatio(ratioX: 4, ratioY: 5),
      uiSettings: [
        AndroidUiSettings(
            toolbarTitle: 'Crop Image',
            toolbarColor: Colors.blue,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: true),
        IOSUiSettings(
          title: 'Crop Image',
        ),
        WebUiSettings(
          context: context,
        ),
      ],
    );

    if (croppedFile != null) {
      _inputImage = await _processPickedFile(pickedFile: croppedFile.path);

      processImage(_inputImage!);
    }
    setState(() {});
  }

  Future<InputImage> _processPickedFile({required String pickedFile}) async {
    final path = pickedFile;
    if (path == null) {
      return InputImage.fromFilePath('');
    }
    setState(() {
      _image = File(path);
    });
    _path = path;
    final inputImage = InputImage.fromFilePath(path);
    // widget.onImage(inputImage);
    return inputImage;
  }

  Future<void> processImage(InputImage inputImage) async {
    if (!_canProcess) return;
    if (_isBusy) return;
    _isBusy = true;
    setState(() {
      _text = '';
    });
    final faces = await _faceDetector.processImage(inputImage);
    if (inputImage.inputImageData?.size != null &&
        inputImage.inputImageData?.imageRotation != null) {
      log("inputImage.inputImageData!.size: ${inputImage.inputImageData!.size}");
    } else {
      String text = 'Faces found: ${faces.length}\n\n';
      setState(() {
        faceCount = faces.length;
      });

      for (final face in faces) {
        text += 'face: ${face.boundingBox}\n\n';

        var leftEar = face.landmarks[FaceLandmarkType.leftEar];
        var rightEar = face.landmarks[FaceLandmarkType.rightEar];
        var leftEye = face.landmarks[FaceLandmarkType.leftEye];
        var rightEye = face.landmarks[FaceLandmarkType.rightEye];

        var leftEarPos = leftEar!.position.y;
        var rightEarPos = rightEar!.position.y;
        var leftEyePos = leftEye!.position.y;
        var rightEyePos = rightEye!.position.y;
        var leftEyePosX = leftEye.position.x;
        var rightEyePosX = rightEye.position.x;
        setState(() {
          eyeCenter = (leftEyePosX + rightEyePosX) / 2;
        });

        log("leftEyePosY: $leftEyePos rightEyePosY: $rightEyePos");
        log("leftEyePosX: $leftEyePosX rightEyePosX: $rightEyePosX");
        log("Center: $eyeCenter");

        if (face.rightEyeOpenProbability != null &&
            face.leftEyeOpenProbability != null &&
            (leftEyePos - rightEyePos).abs() <= 15 &&
            eyeCenter >= 1100 &&
            eyeCenter <= 1400) {
          setState(() {
            isSuccess = (face.rightEyeOpenProbability! > 0.98 &&
                face.leftEyeOpenProbability! > 0.98 &&
                face.headEulerAngleY! >= -2 &&
                face.headEulerAngleY! <= 2);
          });

          log("isSuccesssssssssssssssssssssssssssssss: $isSuccess");
        } else if (eyeCenter <= 1100 || eyeCenter >= 1400) {
          setState(() {
            isSuccess = false;
          });
          log("isSuccesssssssssssssssssssssssssssssss: $isSuccess");
        } else {
          setState(() {
            isSuccess = false;
          });
          log("isSuccesssssssssssssssssssssssssssssss: $isSuccess");
        }

        setState(() {
          isLoading = false;
        });
      }
      _text = text;
      // TODO: set _customPaint to draw boundingRect on top of image
      _customPaint = null;
    }
    _isBusy = false;
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    log("hhhhhhhhhhhhhhhhhhhhhhhhh $faceCount $isSuccess");
    return Scaffold(
        body: Container(
      height: MediaQuery.of(context).size.height,
      width: MediaQuery.of(context).size.width,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _image != null
              ? SizedBox(
                  height: 400,
                  width: 400,
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      Image.file(_image!),
                      // if (widget.customPaint != null) widget.customPaint!,
                    ],
                  ),
                )
              : const Icon(
                  Icons.image,
                  size: 200,
                ),
          const SizedBox(
            height: 20,
          ),
          ElevatedButton(
              onPressed: () {
                _getImage();
              },
              child: const Text("Take a picture")),
          const SizedBox(
            height: 20,
          ),
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.5),
                        spreadRadius: 5,
                        blurRadius: 7,
                        offset:
                            const Offset(0, 3), // changes position of shadow
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      if (isSuccess == true && faceCount == 1)
                        const Text("Image is Valid",
                            style: TextStyle(color: Colors.green, fontSize: 15))
                      else if (eyeCenter <= 1100 ||
                          eyeCenter >= 1400 && faceCount == 1)
                        const Text("Keep your face in the center of the screen",
                            style: TextStyle(color: Colors.red, fontSize: 15))
                      else if (isSuccess == false)
                        const Text("Image is not Valid",
                            style: TextStyle(color: Colors.red, fontSize: 15))
                      else if (faceCount < 1)
                        const Text("No face detected",
                            style: TextStyle(color: Colors.red, fontSize: 15))
                      else
                        const Text(""),
                    ],
                  ),
                ),
        ],
      ),
    ));
  }
}
