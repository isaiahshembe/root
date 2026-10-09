import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:website/src/heritage_theme.dart';
import 'package:flutter/foundation.dart';

class Vlmidentification extends StatefulWidget {
  const Vlmidentification({super.key});

  @override
  State<Vlmidentification> createState() => _VlmidentificationState();
}

class _VlmidentificationState extends State<Vlmidentification> {
  // static const String _inferenceUrl =
  //     'https://proxy-server-8445892d.ahumain.cranecloud.io/predict';
  // Use relative path on Web to bypass CORS, but keep absolute URL on iOS/Android
  static const String _inferenceUrl = kIsWeb
      ? '/api/predict'
      : 'https://proxy-server-8445892d.ahumain.cranecloud.io/predict';

  static const Map<String, String> _questionLabels = {
    'caption': 'Detailed Caption',
    'culture': 'Cultural Origin',
    'material': 'Crafting Material',
    'technique': 'Creation Technique',
    'primary_use': 'Primary Use Case',
    'category': 'Artifact Category',
    'size': 'Size & Scale',
    'condition': 'Physical Condition',
    'cultural_significance': 'Cultural Value',
    'general': 'General Overview',
  };

  static const Map<String, String> _questionPrompts = {
    'caption': 'Describe this Ugandan artifact in detail:',
    'category': 'What category does this artifact belong to?',
    'culture': 'Which Ugandan culture created this artifact?',
    'primary_use': 'What is the primary use of this artifact?',
    'material': 'What material is this artifact made from?',
    'size': 'What is the size of this artifact?',
    'technique': 'What technique was used to create this artifact?',
    'condition': 'What is the condition of this artifact?',
    'cultural_significance':
        'What is the cultural significance of this artifact?',
    'general': 'Tell me about this Ugandan cultural artifact:',
  };

  static const Map<String, IconData> _questionIcons = {
    'caption': Icons.subject_outlined,
    'culture': Icons.account_balance_outlined,
    'material': Icons.handyman_outlined,
    'technique': Icons.construction_outlined,
    'primary_use': Icons.track_changes_outlined,
    'category': Icons.category_outlined,
    'size': Icons.straighten_outlined,
    'condition': Icons.healing_outlined,
    'cultural_significance': Icons.auto_awesome_outlined,
    'general': Icons.info_outline,
  };

  Uint8List? _imageBytes;
  String? _imageName;
  String? _activeQuestionType;
  String? _answer;
  String? _errorMessage;
  bool _isLoading = false;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 88,
      );
      if (image == null) return;

      final bytes = await image.readAsBytes();
      if (bytes.length > 10 * 1024 * 1024) {
        setState(() => _errorMessage = 'Choose an image under 10 MB.');
        return;
      }
      if (!mounted) return;

      setState(() {
        _imageBytes = bytes;
        _imageName = image.name;
        _activeQuestionType = null;
        _answer = null;
        _errorMessage = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = 'Could not open that image. $error');
      }
    }
  }

  void _clearImage() {
    setState(() {
      _imageBytes = null;
      _imageName = null;
      _activeQuestionType = null;
      _answer = null;
      _errorMessage = null;
      _isLoading = false;
    });
  }

  String _mimeType(Uint8List bytes) {
    if (bytes.length >= 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
      return 'image/webp';
    }
    throw const FormatException('Choose a PNG, JPEG or WebP image.');
  }

  Future<void> _askQuestion(String questionType) async {
    final bytes = _imageBytes;
    if (bytes == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _answer = null;
      _activeQuestionType = questionType;
    });

    try {
      final uri = Uri.parse(_inferenceUrl);
      final request = http.MultipartRequest('POST', uri);

      // Add the text field for the question category
      request.fields['question_type'] = questionType;

      // Infer file extension from mime type
      String ext = 'png';
      try {
        final mime = _mimeType(bytes);
        ext = mime.split('/').last;
      } catch (_) {}

      // Add the bytes as a file inside multipart request
      request.files.add(
        http.MultipartFile.fromBytes(
          'image', // Key matching our flask app: request.files.get("image")
          bytes,
          filename: 'image.$ext',
        ),
      );

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 120),
      );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        throw Exception('Inference failed (${response.statusCode}).');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> || decoded['success'] != true) {
        throw const FormatException(
          'Unexpected response or failure status from proxy server.',
        );
      }

      // Extract the result text
      var answer = (decoded['result'] as String).trim();
      final prompt = _questionPrompts[questionType]!;
      if (answer.toLowerCase().startsWith(prompt.toLowerCase())) {
        answer = answer.substring(prompt.length).trim();
      }
      if (answer.isEmpty) {
        throw const FormatException('The model returned an empty answer.');
      }
      if (mounted) setState(() => _answer = answer);
    } catch (error) {
      if (mounted) setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HeritagePalette.canvas,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 700;
          return SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildMasthead(),
                    const SizedBox(height: 18),
                    if (_imageBytes == null)
                      _buildCaptureHub(isMobile)
                    else
                      _buildDiscoveryDashboard(isMobile),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMasthead() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HeritageTricolorBand(height: 6),
          Container(
            color: HeritagePalette.forest,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LIVING HERITAGE  /  ARTIFACT DISCOVERY',
                  style: GoogleFonts.spaceGrotesk(
                    color: HeritagePalette.sun,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Discover an artifact',
                  style: GoogleFonts.newsreader(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaptureHub(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: HeritagePalette.rule),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            height: isMobile ? 210 : 260,
            decoration: BoxDecoration(
              color: HeritagePalette.canvas,
              border: Border.all(color: HeritagePalette.forest, width: 1.5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.center_focus_strong,
                  size: 48,
                  color: HeritagePalette.forest,
                ),
                const SizedBox(height: 10),
                Text(
                  'Frame an artifact',
                  style: GoogleFonts.newsreader(
                    color: HeritagePalette.forest,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final scanButton = SizedBox(
                height: 50,
                child: FilledButton.icon(
                  onPressed: _isLoading
                      ? null
                      : () => _pickImage(ImageSource.camera),
                  style: FilledButton.styleFrom(
                    backgroundColor: HeritagePalette.forest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Scan Artifact'),
                ),
              );
              final galleryButton = SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _isLoading
                      ? null
                      : () => _pickImage(ImageSource.gallery),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: HeritagePalette.forest,
                    side: const BorderSide(color: HeritagePalette.forest),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Choose from Gallery'),
                ),
              );
              if (constraints.maxWidth < 420) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    scanButton,
                    const SizedBox(height: 10),
                    galleryButton,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: scanButton),
                  const SizedBox(width: 12),
                  Expanded(child: galleryButton),
                ],
              );
            },
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            _buildErrorMessage(),
          ],
        ],
      ),
    );
  }

  Widget _buildDiscoveryDashboard(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                _imageBytes!,
                width: double.infinity,
                height: isMobile ? 230 : 320,
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton.filled(
                tooltip: 'Choose another image',
                onPressed: _isLoading ? null : _clearImage,
                icon: const Icon(Icons.close),
              ),
            ),
            if (_imageName != null)
              Positioned(
                left: 10,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _imageName!,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Text(
                'Explore this artifact',
                style: GoogleFonts.newsreader(
                  color: HeritagePalette.forest,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '10 questions',
              style: GoogleFonts.spaceGrotesk(
                color: HeritagePalette.muted,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _questionLabels.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isMobile ? 2 : 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            mainAxisExtent: 76,
          ),
          itemBuilder: (context, index) {
            final questionType = _questionLabels.keys.elementAt(index);
            return _buildQuestionCard(questionType);
          },
        ),
        if (_isLoading || _answer != null || _errorMessage != null) ...[
          const SizedBox(height: 18),
          _buildAnswerPanel(),
        ],
      ],
    );
  }

  Widget _buildQuestionCard(String questionType) {
    final selected = _activeQuestionType == questionType;
    return Material(
      color: selected ? HeritagePalette.forest : Colors.white,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: _isLoading ? null : () => _askQuestion(questionType),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? HeritagePalette.forest : HeritagePalette.rule,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(
                _questionIcons[questionType],
                size: 20,
                color: selected ? HeritagePalette.sun : HeritagePalette.forest,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  _questionLabels[questionType]!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    color: selected ? Colors.white : HeritagePalette.ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (_isLoading && selected)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: HeritagePalette.sun,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnswerPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: HeritagePalette.rule),
        borderRadius: BorderRadius.circular(8),
      ),
      child: _isLoading
          ? Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: HeritagePalette.forest,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Asking ${_questionLabels[_activeQuestionType]}…',
                  style: const TextStyle(color: HeritagePalette.forest),
                ),
              ],
            )
          : (_errorMessage != null
                ? _buildErrorMessage()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _questionLabels[_activeQuestionType] ?? 'Answer',
                        style: GoogleFonts.newsreader(
                          color: HeritagePalette.forest,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SelectableText(
                        _answer ?? '',
                        style: GoogleFonts.manrope(
                          color: HeritagePalette.ink,
                          fontSize: 14,
                          height: 1.55,
                        ),
                      ),
                    ],
                  )),
    );
  }

  Widget _buildErrorMessage() {
    return Text(
      _errorMessage ?? '',
      style: const TextStyle(color: HeritagePalette.red, fontSize: 13),
    );
  }
}
