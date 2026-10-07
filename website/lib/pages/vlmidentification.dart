import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:website/src/heritage_theme.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

class Vlmidentification extends StatefulWidget {
  const Vlmidentification({super.key});

  @override
  State<Vlmidentification> createState() => _VlmidentificationState();
}

class _VlmidentificationState extends State<Vlmidentification>
    with SingleTickerProviderStateMixin {
  Uint8List? _selectedImageBytes;
  bool _isProcessing = false;
  bool _hasResults = false;
  String _debugInfo = '';
  bool _apiReady = false;
  bool _geminiFallbackEnabled = false;
  bool _usedGeminiFallback = false;
  String _questionType = 'general';

  late AnimationController _animationController;
  late Animation<double> _progressAnimation;
  Map<String, dynamic> _identificationResults = {};

  static const String _geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const String _huggingFaceApiUrl =
      'https://andro777-med-tourism-vlm.hf.space/gradio_api/predict';

  static const Map<String, String> _questionTypes = {
    'general': 'General',
    'caption': 'Caption',
    'culture': 'Culture',
    'material': 'Material',
    'primary_use': 'Primary use',
    'cultural_significance': 'Cultural significance',
  };

  List<String>? _classNames;
  Map<String, dynamic>? _medicinalData;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _progressAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(_animationController);

    _initializeApp();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    setState(() {
      _debugInfo = '🔄 Initializing Ugandan Medicinal Plants Identifier...';
    });

    try {
      // Load class names for reference
      try {
        final classNamesString = await rootBundle.loadString(
          'assets/labels/class_names.txt',
        );
        _classNames = classNamesString
            .split('\n')
            .where((name) => name.isNotEmpty)
            .toList();
        debugPrint('✅ Loaded ${_classNames?.length} reference class names');
      } catch (e) {
        debugPrint('No class names file found, using default categories');
        _classNames = [
          'Artemisia annua',
          'Aloe vera',
          'Moringa oleifera',
          'Azadirachta indica',
          'Prunus africana',
          'Warburgia ugandensis',
        ];
      }

      // Load medicinal plant data for fallback
      try {
        final medicinalDataString = await rootBundle.loadString(
          'assets/metadata/medicinal_plants_data.json',
        );
        _medicinalData = json.decode(medicinalDataString);
        debugPrint('✅ Loaded medicinal plants database');
      } catch (e) {
        debugPrint('No medicinal data file found, using built-in database');
        _medicinalData = _getBuiltInMedicinalDatabase();
      }

      _apiReady = true;
      setState(() {
        _debugInfo =
            '✅ Hugging Face VLM ready. Choose a question and upload an image.';
      });
    } catch (e) {
      debugPrint('Initialization error: $e');
      setState(() {
        _debugInfo =
            '❌ Initialization error: $e\n\n'
            'Please check your internet connection and try again.';
      });
    }
  }

  Map<String, dynamic> _getBuiltInMedicinalDatabase() {
    return {
      'artemisia_annua': {
        'commonName': 'Sweet Wormwood',
        'family': 'Asteraceae',
        'medicinalProperties': [
          '🌿 Treats malaria effectively',
          '🌿 Reduces fever',
          '🌿 Anti-inflammatory properties',
          '🌿 Boosts immune system',
        ],
        'preparation': [
          'Steep dried leaves in hot water for tea',
          'Prepare tincture with alcohol',
          'Use in capsules as supplement',
        ],
        'culturalContext': {
          'location': 'Eastern and Central Uganda',
          'communities': 'Baganda, Basoga, Bagisu',
          'significance': 'Primary treatment for malaria in many communities',
          'traditionalKnowledge':
              'Known as "Aswa" in Luganda, used for generations',
        },
        'conservation': 'Commonly cultivated, not threatened',
        'seasonalInfo': 'Best harvested just before flowering',
      },
      'aloe_vera': {
        'commonName': 'Aloe Vera',
        'family': 'Asphodelaceae',
        'medicinalProperties': [
          '🌿 Heals burns and wounds',
          '🌿 Treats skin conditions',
          '🌿 Aids digestion',
          '🌿 Reduces inflammation',
        ],
        'preparation': [
          'Apply fresh gel directly to skin',
          'Mix gel with honey for internal use',
          'Blend into smoothies',
        ],
        'culturalContext': {
          'location': 'Throughout Uganda',
          'communities': 'All communities',
          'significance': 'First-aid plant for burns and wounds',
          'traditionalKnowledge':
              'Known as "Kigaji" in Luganda, "Ekigaji" in Runyankole',
        },
        'conservation': 'Widely cultivated, sustainable',
        'seasonalInfo': 'Harvest leaves year-round',
      },
      'moringa_oleifera': {
        'commonName': 'Moringa/Drumstick Tree',
        'family': 'Moringaceae',
        'medicinalProperties': [
          '🌿 Rich in vitamins and minerals',
          '🌿 Boosts energy and immunity',
          '🌿 Reduces blood pressure',
          '🌿 Anti-aging properties',
        ],
        'preparation': [
          'Dry and powder leaves for tea',
          'Add fresh leaves to soups',
          'Use seed oil for cooking',
        ],
        'culturalContext': {
          'location': 'Northern and Eastern Uganda',
          'communities': 'Acholi, Iteso, Karamojong',
          'significance': 'Nutritional supplement during food scarcity',
          'traditionalKnowledge':
              'Known as "Kelor" in Acholi, "Mlonge" in Luganda',
        },
        'conservation': 'Abundant, easily grown',
        'seasonalInfo': 'Leaves best harvested young',
      },
    };
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        final imageBytes = await image.readAsBytes();
        if (!mounted) return;

        setState(() {
          _selectedImageBytes = imageBytes;
          _hasResults = false;
          _identificationResults = {};
          _debugInfo =
              '✅ Image loaded: ${image.name}\n'
              'Choose a question and analyze with the Hugging Face VLM.';
        });
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error picking image: $e', Colors.red);
        setState(() {
          _debugInfo = '❌ Image picker error: $e';
        });
      }
    }
  }

  Future<void> _processImage() async {
    if (_selectedImageBytes == null) {
      _showSnackBar('Please upload an image first', Colors.orange);
      return;
    }

    setState(() {
      _isProcessing = true;
      _hasResults = false;
      _usedGeminiFallback = false;
      _debugInfo = '🔄 Sending image to the Hugging Face VLM...';
    });

    _animationController.reset();
    _animationController.forward();

    try {
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) _animationController.value = 0.2;

      if (mounted) {
        setState(() {
          _debugInfo =
              '🔍 Sending image and question to the Hugging Face VLM...';
        });
      }

      final imageBytes = _selectedImageBytes;
      if (imageBytes == null) {
        throw Exception('Failed to read image data');
      }

      final base64Image = base64Encode(imageBytes);
      final mimeType = _getImageMimeType(imageBytes);
      String answer;
      Map<String, dynamic>? geminiResult;
      try {
        answer = await _callHuggingFaceAPI(
          base64Image,
          mimeType,
          _questionType,
        );
      } catch (error) {
        if (!_geminiFallbackEnabled || _geminiApiKey.isEmpty) rethrow;

        _usedGeminiFallback = true;
        final prompt =
            '''
You are an expert in Ugandan cultural heritage and medicinal plants. Analyze the image and answer this request: ${_questionTypes[_questionType]}.
Provide a concise, evidence-based answer. State uncertainty rather than inventing details.
''';
        final response = await _callGeminiAPI(base64Image, mimeType, prompt);
        answer = response;
        geminiResult = _parseGeminiResponse(response);
      }

      final analysisResult = geminiResult ?? <String, dynamic>{};
      analysisResult['provider'] = _usedGeminiFallback
          ? 'Gemini (experimental fallback)'
          : 'Hugging Face VLM';
      analysisResult['questionType'] = _questionType;
      analysisResult['answer'] = answer;

      analysisResult['analysisId'] =
          'UGA-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch % 10000}';

      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) _animationController.value = 0.75;

      if (mounted) {
        setState(() {
          _debugInfo = '📚 Finalizing the model response...';
        });
      }

      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) _animationController.value = 1.0;

      if (mounted) {
        setState(() {
          _identificationResults = analysisResult;
          _isProcessing = false;
          _hasResults = true;
          _debugInfo = '✅ Analysis complete via ${analysisResult['provider']}';
        });
      }

      _showSnackBar('Analysis complete', Colors.green);
    } catch (e) {
      debugPrint('Processing error: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _debugInfo =
              '❌ Error during identification: $e\n\n'
              'Check your internet connection and try again.\n'
              'The hosted inference Space may be unavailable or starting up.';
        });
        _showSnackBar('Error identifying plant: $e', Colors.red);
      }
    }
  }

  String _getImageMimeType(Uint8List bytes) {
    if (bytes.length >= 8 &&
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
    throw Exception(
      'Unsupported image format. Please choose PNG, JPEG, or WebP.',
    );
  }

  Future<String> _callHuggingFaceAPI(
    String base64Image,
    String mimeType,
    String questionType,
  ) async {
    final response = await http
        .post(
          Uri.parse(_huggingFaceApiUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'data': ['data:$mimeType;base64,$base64Image', questionType],
          }),
        )
        .timeout(const Duration(seconds: 120));

    if (response.statusCode != 200) {
      throw Exception(
        'Hugging Face inference failed (${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> ||
        decoded['data'] is! List ||
        (decoded['data'] as List).isEmpty ||
        (decoded['data'] as List).first is! String) {
      throw const FormatException(
        'Unexpected response from the Hugging Face VLM.',
      );
    }

    final answer = (decoded['data'] as List).first as String;
    if (answer.trim().isEmpty) {
      throw const FormatException(
        'The Hugging Face VLM returned an empty answer.',
      );
    }
    return answer;
  }

  Future<String> _callGeminiAPI(
    String base64Image,
    String mimeType,
    String prompt,
  ) async {
    // Use v1beta endpoint with a working model
    final String modelName = "gemini-2.5-flash-lite"; // or "gemini-2.5-flash"
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$_geminiApiKey',
    );

    final requestBody = {
      "contents": [
        {
          "parts": [
            {"text": prompt},
            {
              "inline_data": {"mime_type": mimeType, "data": base64Image},
            },
          ],
        },
      ],
      "generationConfig": {
        "temperature": 0.4,
        "topK": 32,
        "topP": 1,
        "maxOutputTokens": 2048,
      },
    };

    print('Calling API with model: $modelName'); // Debug log

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(requestBody),
    );

    print('Response status: ${response.statusCode}'); // Debug log

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final text = data['candidates'][0]['content']['parts'][0]['text'];
      return text;
    } else {
      throw Exception('API Error: ${response.statusCode} - ${response.body}');
    }
  }

  Map<String, dynamic> _parseGeminiResponse(String response) {
    try {
      // Try to extract JSON from the response
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(response);
      if (jsonMatch != null) {
        final jsonStr = jsonMatch.group(0)!;
        return json.decode(jsonStr);
      }
    } catch (e) {
      debugPrint('JSON parsing error: $e');
    }

    // Fallback response if parsing fails
    return {
      'scientificName': 'Unknown Plant',
      'commonName': 'Unable to identify',
      'family': 'Unknown',
      'confidence': '50',
      'medicinalProperties': [
        '🌿 Please try with a clearer image',
        '🌿 Ensure good lighting',
        '🌿 Show leaves and flowers clearly',
      ],
      'preparation': [
        'Upload a clearer image for better identification',
        'Include different parts of the plant',
      ],
      'culturalContext': {
        'location': 'Uganda',
        'communities': 'Various',
        'significance': 'Unable to determine from this image',
        'traditionalKnowledge': 'Please upload a clearer photo',
      },
      'conservation': 'Unknown - please try again',
      'seasonalInfo': 'Unknown - upload clearer image',
    };
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HeritagePalette.canvas,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: EdgeInsets.all(constraints.maxWidth < 600 ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const HeritageTricolorBand(height: 5),
                const SizedBox(height: 14),
                _buildHeader(),
                const SizedBox(height: 24),
                if (_debugInfo.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _debugInfo.contains('❌')
                          ? Colors.red.shade50
                          : (_debugInfo.contains('✅')
                                ? Colors.green.shade50
                                : (_debugInfo.contains('⚠️')
                                      ? Colors.orange.shade50
                                      : Colors.blue.shade50)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _debugInfo.contains('❌')
                            ? Colors.red.shade200
                            : (_debugInfo.contains('✅')
                                  ? Colors.green.shade200
                                  : (_debugInfo.contains('⚠️')
                                        ? Colors.orange.shade200
                                        : Colors.blue.shade200)),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _debugInfo.contains('❌')
                                  ? Icons.error
                                  : (_debugInfo.contains('✅')
                                        ? Icons.check_circle
                                        : (_debugInfo.contains('⚠️')
                                              ? Icons.warning
                                              : Icons.info)),
                              color: _debugInfo.contains('❌')
                                  ? Colors.red
                                  : (_debugInfo.contains('✅')
                                        ? Colors.green
                                        : (_debugInfo.contains('⚠️')
                                              ? Colors.orange
                                              : Colors.blue)),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _debugInfo.contains('❌')
                                  ? 'Error'
                                  : (_debugInfo.contains('✅')
                                        ? 'Success'
                                        : (_debugInfo.contains('⚠️')
                                              ? 'Warning'
                                              : 'AI Status')),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _debugInfo.contains('❌')
                                    ? Colors.red.shade800
                                    : (_debugInfo.contains('✅')
                                          ? Colors.green.shade800
                                          : (_debugInfo.contains('⚠️')
                                                ? Colors.orange.shade800
                                                : Colors.blue.shade800)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _debugInfo,
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (constraints.maxWidth < 900)
                  Column(
                    children: [
                      _buildUploadSection(),
                      if (_isProcessing || _hasResults) ...[
                        const SizedBox(height: 16),
                        _isProcessing
                            ? _buildProcessingSection()
                            : _buildResultsSection(),
                      ] else if (_selectedImageBytes == null) ...[
                        const SizedBox(height: 16),
                        _buildInfoSection(),
                      ],
                    ],
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildUploadSection()),
                      if (_isProcessing || _hasResults) ...[
                        const SizedBox(width: 20),
                        Expanded(
                          child: _isProcessing
                              ? _buildProcessingSection()
                              : _buildResultsSection(),
                        ),
                      ],
                      if (!_hasResults &&
                          !_isProcessing &&
                          _selectedImageBytes == null) ...[
                        const SizedBox(width: 20),
                        Expanded(child: _buildInfoSection()),
                      ],
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ... (rest of the UI methods remain the same as before - _buildHeader, _buildUploadSection, etc.)
  // Include all the UI building methods from the previous version

  Widget _buildHeader() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: HeritagePalette.canvas,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        color: Colors.green.shade800,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Ugandan Medicinal Plants Identifier',
                          style: GoogleFonts.newsreader(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: HeritagePalette.forest,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Powered by the hosted Ugandan Artifact VLM.\n'
                    'Upload an image and ask about its caption, culture, material, primary use, or cultural significance.',
                    style: GoogleFonts.manrope(
                      color: HeritagePalette.muted,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _questionType,
                    decoration: const InputDecoration(
                      labelText: 'Question type',
                      border: OutlineInputBorder(),
                    ),
                    items: _questionTypes.entries
                        .map(
                          (entry) => DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _questionType = value);
                      }
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Gemini experimental fallback'),
                    subtitle: Text(
                      _geminiApiKey.isEmpty
                          ? 'Not configured. Configure only for development; production keys belong on a server.'
                          : 'Try Gemini only if the Hugging Face Space request fails.',
                    ),
                    value: _geminiFallbackEnabled,
                    onChanged: _geminiApiKey.isEmpty
                        ? null
                        : (enabled) =>
                              setState(() => _geminiFallbackEnabled = enabled),
                  ),
                  if (kIsWeb)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: HeritagePalette.forest.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.cloud_queue,
                              size: 16,
                              color: HeritagePalette.forest,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Inference runs remotely through the Hugging Face Space',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: HeritagePalette.forest,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadSection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.cloud_upload,
                  color: Colors.green.shade700,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Text(
                  'Upload Plant Image',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 300,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: HeritagePalette.forest, width: 1.5),
                  borderRadius: BorderRadius.circular(6),
                  color: HeritagePalette.canvas,
                ),
                child: _selectedImageBytes == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.photo_camera,
                            size: 64,
                            color: Colors.green.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Click to upload plant image',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.green.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Supports JPG, PNG (Max 10MB)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade400,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.auto_awesome,
                                  size: 14,
                                  color: Colors.blue.shade700,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Hugging Face VLM',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              _selectedImageBytes!,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _selectedImageBytes = null;
                                    _hasResults = false;
                                    _identificationResults = {};
                                  });
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    _selectedImageBytes != null && !_isProcessing && _apiReady
                    ? _processImage
                    : null,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(
                  _isProcessing
                      ? 'Analyzing image...'
                      : (_apiReady ? 'Analyze image' : 'Inference unavailable'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: HeritagePalette.forest,
                  disabledBackgroundColor: HeritagePalette.forest.withValues(
                    alpha: 0.45,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Include the remaining UI methods (_buildProcessingSection, _buildResultsSection, etc.)
  // from the previous version - they remain largely the same

  Widget _buildProcessingSection() {
    // Same as before
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: HeritagePalette.forest,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Text(
                  _usedGeminiFallback
                      ? 'Gemini Experimental Fallback'
                      : 'Hugging Face VLM Analysis',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: HeritagePalette.forest,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildProcessingStep(
              1,
              'Image Upload',
              'Sending image to hosted inference...',
            ),
            _buildProcessingStep(
              2,
              'AI Vision Analysis',
              'Analyzing plant features...',
            ),
            _buildProcessingStep(
              3,
              'Knowledge Retrieval',
              'Accessing medicinal plant database...',
            ),
            _buildProcessingStep(
              4,
              'Complete',
              'Preparing results with cultural context...',
            ),
            const SizedBox(height: 24),
            LinearProgressIndicator(
              value: _progressAnimation.value,
              backgroundColor: HeritagePalette.rule,
              valueColor: const AlwaysStoppedAnimation<Color>(
                HeritagePalette.forest,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'AI Analysis Progress... ${(_progressAnimation.value * 100).toInt()}%',
              style: const TextStyle(
                fontSize: 12,
                color: HeritagePalette.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingStep(int step, String title, String description) {
    final isActive = _progressAnimation.value >= (step - 1) * 0.25;
    final isCompleted = _progressAnimation.value >= step * 0.25;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted
                  ? Colors.green.shade600
                  : (isActive ? Colors.green.shade300 : Colors.green.shade100),
            ),
            child: Center(
              child: isCompleted
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : Text(
                      step.toString(),
                      style: TextStyle(
                        color: isActive
                            ? Colors.green.shade800
                            : Colors.green.shade400,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isActive || isCompleted
                        ? Colors.green.shade800
                        : Colors.green.shade400,
                  ),
                ),
                if (isActive && !isCompleted)
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsSection() {
    final plant = _identificationResults;
    if (plant.isEmpty) return const SizedBox();

    if (plant['answer'] is String) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _usedGeminiFallback
                    ? 'Gemini experimental fallback'
                    : 'Hugging Face VLM answer',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: HeritagePalette.forest,
                ),
              ),
              const SizedBox(height: 8),
              Text('Question: ${_questionTypes[plant['questionType']]}'),
              const SizedBox(height: 16),
              SelectableText(
                plant['answer'] as String,
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 12),
              Text(
                'Provider: ${plant['provider']}  |  ID: ${plant['analysisId']}',
                style: const TextStyle(
                  fontSize: 12,
                  color: HeritagePalette.muted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    color: Colors.green.shade700,
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'AI Identification Results',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade50, Colors.green.shade100],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      plant['scientificName'] ?? 'Unknown',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      plant['commonName'] ?? 'Medicinal Plant',
                      style: TextStyle(
                        fontSize: 18,
                        fontStyle: FontStyle.italic,
                        color: Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      plant['family'] ?? 'Plant Family',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade700,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.verified,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'AI Confidence: ${plant['confidence'] ?? 85}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade700,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.fingerprint,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'ID: ${plant['analysisId'] ?? 'N/A'}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildSection(
                title: 'Medicinal Properties',
                icon: Icons.local_hospital,
                color: Colors.red,
                children:
                    (plant['medicinalProperties'] as List?)?.map((property) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.healing,
                              size: 16,
                              color: Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(property)),
                          ],
                        ),
                      );
                    }).toList() ??
                    [],
              ),
              const SizedBox(height: 20),
              _buildSection(
                title: 'Traditional Preparation Methods',
                icon: Icons.kitchen,
                color: Colors.orange,
                children:
                    (plant['preparation'] as List?)?.map((method) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              size: 16,
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(method)),
                          ],
                        ),
                      );
                    }).toList() ??
                    [],
              ),
              const SizedBox(height: 20),
              _buildSection(
                title: 'Cultural Context & Traditional Knowledge',
                icon: Icons.article,
                color: Colors.purple,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 16,
                              color: Colors.purple.shade700,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '📍 ${plant['culturalContext']?['location'] ?? 'Uganda'}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.purple.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.people,
                              size: 16,
                              color: Colors.purple.shade700,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '👥 Communities: ${plant['culturalContext']?['communities'] ?? 'Various Ugandan communities'}',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.psychology,
                              size: 16,
                              color: Colors.purple.shade700,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '📖 ${plant['culturalContext']?['traditionalKnowledge'] ?? 'Traditional knowledge preserved by elders'}',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required MaterialColor color,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: color.shade700),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color.shade800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildInfoSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info, color: Colors.green.shade700, size: 28),
                const SizedBox(width: 8),
                Text(
                  'How It Works',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, color: Colors.blue.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Powered by a fine-tuned BLIP VLM hosted on Hugging Face',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Images are sent to the Hugging Face Space for remote image question-answering. Select a question type to guide the model.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildInfoBullet(
              'Step 1: Upload Photo',
              'Take a clear photo of the plant showing leaves, flowers, or distinctive features',
            ),
            const SizedBox(height: 12),
            _buildInfoBullet(
              'Step 2: AI Analysis',
              'The VLM answers the selected question about the image',
            ),
            const SizedBox(height: 12),
            _buildInfoBullet(
              'Step 3: Get Results',
              'Receive detailed information about medicinal properties, preparation methods, and cultural significance in Uganda',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBullet(String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: Colors.green.shade700,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
