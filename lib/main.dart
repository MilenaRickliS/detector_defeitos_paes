import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:detector_defeitos_paes/model/boundingbox.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter_exif_rotation/flutter_exif_rotation.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const DetectorPage(),
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF6D4C41),
          elevation: 4,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF6D4C41),
        ),
      ),
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

    // Corrige a rotação da imagem
    final rotatedFile = await FlutterExifRotation.rotateImage(path: picked.path);
    _imageFile = rotatedFile;
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
      Uri.parse('http://192.168.0.7:8000/detect'), // Altere se necessário
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
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        leading: const Icon(Icons.bakery_dining, color: Colors.white),
        title: const Text(
          'Detector de Defeitos em Pães',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: _imageFile == null
            ? const Text(
                'Tire uma foto para detectar defeitos em pães',
                style: TextStyle(fontSize: 18, color: Colors.black87),
              )
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
        child: const Icon(Icons.camera_alt, color: Colors.white),
      ),
    );
  }
}

class ImagePainter extends CustomPainter {
  final ui.Image image;
  final List<BoundingBox> boxes;

  ImagePainter(this.image, this.boxes);

  final Map<String, Color> labelColors = {
    'buraco': Colors.blue,
    'contaminado': const Color.fromARGB(255, 83, 1, 104),
    'mofo': const Color.fromARGB(255, 175, 76, 170),
    'pao': const Color.fromARGB(255, 72, 158, 1),
    'queimado': const Color.fromARGB(255, 133, 38, 4),
  };

  @override
  void paint(Canvas canvas, Size size) {
    // Desenha a imagem
    paintImage(canvas: canvas, rect: Offset.zero & size, image: image, fit: BoxFit.contain);

    // Proporção da imagem para canvas
    final scaleX = size.width / image.width;
    final scaleY = size.height / image.height;

    for (var box in boxes) {
      final color = labelColors[box.label.toLowerCase()] ?? Colors.red;

      final paintBox = Paint()
        ..color = color.withAlpha(230)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke;

      final paintLabelBg = Paint()
        ..color = color.withAlpha(230)
        ..style = PaintingStyle.fill;

      final left = box.x * scaleX;
      final top = box.y * scaleY;
      final width = box.width * scaleX;
      final height = box.height * scaleY;

      final rect = Rect.fromLTWH(left, top, width, height);
      canvas.drawRect(rect, paintBox);

      final textSpan = TextSpan(
        text: '${box.label} (${box.confidence.toStringAsFixed(1)}%)',
        style: const TextStyle(color: Colors.white, fontSize: 16),
      );

      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
      tp.layout();

      final labelRect = Rect.fromLTWH(left, top - tp.height, tp.width + 6, tp.height);
      canvas.drawRect(labelRect, paintLabelBg);
      tp.paint(canvas, Offset(left + 3, top - tp.height));
    }
  }

  @override
  bool shouldRepaint(covariant ImagePainter oldDelegate) =>
      image != oldDelegate.image || boxes != oldDelegate.boxes;
}
