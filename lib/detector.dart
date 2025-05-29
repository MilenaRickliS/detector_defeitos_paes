import 'dart:convert';
import 'dart:typed_data';
import 'package:detector_defeitos_paes/model/boundingbox.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:ui' as ui;
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

class UnifiedDetectorPage extends StatefulWidget {
  const UnifiedDetectorPage({super.key});

  @override
  State<UnifiedDetectorPage> createState() => _UnifiedDetectorPageState();
}

class _UnifiedDetectorPageState extends State<UnifiedDetectorPage> {
  ui.Image? _uiImage;
  List<BoundingBox> _boundingBoxes = [];

  Future<ui.Image> bytesToUiImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();

    
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Escolha a origem da imagem',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 116, 64, 21),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.camera_alt, size: 24, color: Colors.white,),
              label: const Text('Usar Câmera', style: TextStyle(fontSize: 16)),
              onPressed: () => Navigator.pop(context, ImageSource.camera),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 14, 69, 124),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.photo, size: 24, color: Colors.white,),
              label: const Text('Escolher da Galeria', style: TextStyle(fontSize: 16)),
              onPressed: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final pickedFile = await picker.pickImage(source: source, imageQuality: 85);
    if (pickedFile == null) return;

    final originalBytes = await pickedFile.readAsBytes();
    
    img.Image? decoded = img.decodeImage(originalBytes);
    if (decoded == null) {
      _showError('Erro ao decodificar imagem');
      return;
    }
    
    img.Image fixed = img.bakeOrientation(decoded);
    
    final fixedBytes = Uint8List.fromList(img.encodeJpg(fixed));

    final uiImage = await bytesToUiImage(fixedBytes);

    setState(() {
      _uiImage = uiImage;
      _boundingBoxes = [];
    });

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('http://192.168.0.6:8000/detect'),
    )..files.add(http.MultipartFile.fromBytes(
        'image',
        fixedBytes,
        filename: pickedFile.name,
      ));

    final response = await request.send();
    final respStr = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      final data = json.decode(respStr) as List<dynamic>;

      final boxes = data.map((box) {
        return BoundingBox(
          label: box['label'],
          confidence: (box['confidence'] as num).toDouble(),
          x: (box['x'] as num).toDouble(),
          y: (box['y'] as num).toDouble(),
          width: (box['width'] as num).toDouble(),
          height: (box['height'] as num).toDouble(),
        );
      }).toList();

      setState(() {
        _boundingBoxes = boxes;
      });
    } else {
      _showError('Erro ${response.statusCode} ao detectar defeitos.');
    }
  }


  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
      floatingActionButton: FloatingActionButton(
        onPressed: _pickAndUploadImage,
        child: const Icon(Icons.add_a_photo, color: Colors.white),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 16),
              if (_uiImage == null) ...[
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Tire uma foto ou selecione da galeria para detectar defeitos em pães',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: Colors.black87),
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: 500,
                  height: 500,
                  child: InteractiveViewer(
                    maxScale: 5.0,
                    child: CustomPaint(
                      painter: ImagePainter(_uiImage!, _boundingBoxes),
                    ),
                  ),
                ),
                const Divider(height: 1),
                if (_boundingBoxes.isNotEmpty)
                  Column(
                    children: _boundingBoxes.map((box) {
                      return ListTile(
                        leading: const Icon(Icons.warning_amber, color: Color.fromARGB(255, 236, 107, 1)),
                        title: Text(box.label),
                        subtitle: Text('Confiança: ${box.confidence.toStringAsFixed(1)}%'),
                      );
                    }).toList(),
                  )
                else
                  const Text(
                    'Nenhum defeito detectado.',
                    style: TextStyle(fontSize: 16, color: Colors.green),
                  ),
              ],
            ],
          ),
        ),
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
    final imgRatio = image.width / image.height;
    final canvasRatio = size.width / size.height;

    double drawWidth, drawHeight;
    double dx = 0, dy = 0;

    if (imgRatio > canvasRatio) {
      drawWidth = size.width;
      drawHeight = drawWidth / imgRatio;
      dy = (size.height - drawHeight) / 2;
    } else {
      drawHeight = size.height;
      drawWidth = drawHeight * imgRatio;
      dx = (size.width - drawWidth) / 2;
    }

    final dstRect = Rect.fromLTWH(dx, dy, drawWidth, drawHeight);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      dstRect,
      Paint(),
    );

    final scaleX = drawWidth / image.width;
    final scaleY = drawHeight / image.height;

    for (var box in boxes) {
      final color = labelColors[box.label.toLowerCase()] ?? Colors.red;

      final paintBox = Paint()
        ..color = color.withAlpha(230)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke;

      final paintLabelBg = Paint()
        ..color = color.withAlpha(230)
        ..style = PaintingStyle.fill;

      final left = dx + box.x * scaleX;
      final top = dy + box.y * scaleY;
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
