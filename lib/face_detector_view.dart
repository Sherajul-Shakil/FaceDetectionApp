import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
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
  int faceCount = 2;

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
    });
    final pickedFile = await _imagePicker?.pickImage(
      source: ImageSource.camera,
      // imageQuality: 100,
      preferredCameraDevice: CameraDevice.front,
    );
    if (pickedFile != null) {
      _inputImage = await _processPickedFile(pickedFile);
      // log("inputImage: $_inputImage");
      processImage(_inputImage!);
    }
    setState(() {});
  }

  Future<InputImage> _processPickedFile(XFile? pickedFile) async {
    final path = pickedFile?.path;
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

        var leftEarPos = leftEar!.position.y;
        var rightEarPos = rightEar!.position.y;

        if (face.rightEyeOpenProbability != null &&
            face.leftEyeOpenProbability != null &&
            leftEarPos != null &&
            rightEarPos != null &&
            (leftEarPos - rightEarPos).abs() <= 10) {
          setState(() {
            isSuccess = (face.rightEyeOpenProbability! > 0.98 &&
                face.leftEyeOpenProbability! > 0.98 &&
                face.headEulerAngleY! >= -2 &&
                face.headEulerAngleY! <= 2);
          });

          log("isSuccesssssssssssssssssssssssssssssss: $isSuccess");
        } else {
          setState(() {
            isSuccess = false;
          });
          log("isSuccesssssssssssssssssssssssssssssss: $isSuccess");
        }
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
          ElevatedButton(
              onPressed: () {
                _getImage();
              },
              child: const Text("Take a picture")),
          if (isSuccess == true && faceCount == 1)
            const Text("Image is Valid")
          else if (isSuccess == false)
            const Text("Image is not Valid")
          else if (faceCount < 1)
            const Text("No face detected")
          else
            const Text(""),
        ],
      ),
    ));
  }
}
