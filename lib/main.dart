import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:detector_defeitos_paes/model/boundingbox.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: DetectorPage(),
      debugShowCheckedModeBanner: false,
      );
  }
}

class DetectorPage extends StatefulWidget {
  const DetectorPage({super.key});
  @override
  DetectorPageState createState() => DetectorPageState();
}

class DetectorPageState extends State<DetectorPage> {
  File? _imageFile;
  List<BoundingBox> _boxes = [];
  ui.Image? _uiImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.camera);
    if (picked == null) return;

    _imageFile = File(picked.path);
    _boxes = [];
    _uiImage = await loadUiImage(_imageFile!);

    setState(() {});
    await _sendImageToAPI(_imageFile!);
  }

  Future<ui.Image> loadUiImage(File file) async {
    final data = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(data);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  Future<void> _sendImageToAPI(File imageFile) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('http://192.168.0.7:8000/detect'), 
    );
    request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
    var response = await request.send();

    if (response.statusCode == 200) {
      var respStr = await response.stream.bytesToString();
      var jsonResp = json.decode(respStr);
      setState(() {
        _boxes = (jsonResp as List).map((e) => BoundingBox.fromJson(e)).toList();
      });
    } else {
      print('Erro na API: ${response.statusCode}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detector de Defeitos em Pães')),
      body: Center(
        child: _imageFile == null
            ? const Text('Tire uma foto para detectar defeitos em pães')
            : InteractiveViewer(
                panEnabled: true,
                scaleEnabled: true,
                minScale: 0.5,
                maxScale: 4.0,
                child: FittedBox(
                  child: SizedBox(
                    width: _uiImage?.width.toDouble() ?? 300,
                    height: _uiImage?.height.toDouble() ?? 300,
                    child: CustomPaint(
                      painter: ImagePainter(_uiImage!, _boxes),
                    ),
                  ),
                ),
              ),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: _pickImage,
        child: const Icon(Icons.camera_alt),
      ),
    );
  }
}


class ImagePainter extends CustomPainter {
  final ui.Image image;
  final List<BoundingBox> boxes;

  ImagePainter(this.image, this.boxes);

  @override
  void paint(Canvas canvas, Size size) {
    paintImage(canvas: canvas, rect: Offset.zero & size, image: image, fit: BoxFit.contain);

    final paintBox = Paint()
      ..color = Colors.red.withOpacity(0.7)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final paintLabelBg = Paint()
      ..color = Colors.red.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    for (var box in boxes) {
      final rect = Rect.fromLTWH(box.x, box.y, box.width, box.height);
      canvas.drawRect(rect, paintBox);

      final textSpan = TextSpan(
        text: box.label,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      );
      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
      tp.layout();

      final labelRect = Rect.fromLTWH(box.x, box.y - tp.height, tp.width + 6, tp.height);
      canvas.drawRect(labelRect, paintLabelBg);
      tp.paint(canvas, Offset(box.x + 3, box.y - tp.height));
    }
  }

  @override
  bool shouldRepaint(covariant ImagePainter oldDelegate) =>
      image != oldDelegate.image || boxes != oldDelegate.boxes;
}
