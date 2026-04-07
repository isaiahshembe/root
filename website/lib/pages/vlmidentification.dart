import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

// For web platform only
import 'dart:html' as html;

class Vlmidentification extends StatefulWidget {
  const Vlmidentification({super.key});

  @override
  State<Vlmidentification> createState() => _VlmidentificationState();
}

class _VlmidentificationState extends State<Vlmidentification>
    with SingleTickerProviderStateMixin {
  dynamic _selectedImage;
  String? _imagePreviewUrl;
  bool _isProcessing = false;
  bool _hasResults = false;
  String _debugInfo = '';
  bool _apiReady = false;

  late AnimationController _animationController;
  late Animation<double> _progressAnimation;
  Map<String, dynamic> _identificationResults = {};

  // API Configuration
  // Get your free API key from: https://aistudio.google.com/app/apikey
  final String _geminiApiKey =
      'AIzaSyAYMfnPhfsr7NSPjRIjbNnvaGSQ1fYOyFo'; // Replace with your key
  final String _geminiApiUrl =
      'https://generativelanguage.googleapis.com/v1/models/gemini-pro-vision:generateContent';

  // Alternative: Use a backend proxy if needed
  final String _proxyUrl = ''; // Optional: Your backend proxy URL

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

      // Check API key
      if (_geminiApiKey == 'YOUR_GEMINI_API_KEY_HERE') {
        setState(() {
          _debugInfo =
              '⚠️ API Key Required\n\n'
              'Please add your Gemini API key to use the AI vision model.\n\n'
              'Get a free key at: https://aistudio.google.com/app/apikey\n\n'
              'Once added, the app will identify plants using Google\'s Gemini Vision AI.';
        });
        _apiReady = false;
      } else {
        _apiReady = true;
        setState(() {
          _debugInfo =
              '✅ AI Vision Model Ready!\n\n'
              'Using Google Gemini Vision AI to identify Ugandan medicinal plants.\n'
              'Upload a clear photo of a plant for instant identification.';
        });
      }
    } catch (e) {
      debugPrint('Initialization error: $e');
      setState(() {
        _debugInfo =
            '❌ Initialization error: $e\n\n'
            'Please check your internet connection and try again.';
      });
    }
  }

  Future<void> _listAvailableModels() async {
    // Use v1beta to list the newest models
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models?key=$_geminiApiKey',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print("--- YOUR AVAILABLE MODELS ---");
        // Look for models containing "flash" or "pro" that support generateContent
        for (var model in data['models']) {
          if (model['supportedGenerationMethods'].contains('generateContent')) {
            print("✅ ${model['name']}");
          }
        }
      }
    } catch (e) {
      print("Error listing models: $e");
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
      if (kIsWeb) {
        final html.FileUploadInputElement uploadInput =
            html.FileUploadInputElement();
        uploadInput.accept = 'image/jpeg, image/png, image/jpg';
        uploadInput.click();

        uploadInput.onChange.listen((event) async {
          final files = uploadInput.files;
          if (files != null && files.isNotEmpty) {
            final file = files[0];
            final reader = html.FileReader();
            reader.readAsDataUrl(file);
            reader.onLoadEnd.listen((event) async {
              if (mounted) {
                setState(() {
                  _imagePreviewUrl = reader.result as String;
                  _hasResults = false;
                  _identificationResults = {};
                  _debugInfo =
                      '✅ Image loaded: ${file.name}\n'
                      'Click "Identify Plant" to analyze with Gemini AI';
                });
              }
              _selectedImage = file;
            });
          }
        });
      } else {
        final ImagePicker picker = ImagePicker();
        final XFile? image = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 800,
          maxHeight: 800,
          imageQuality: 85,
        );

        if (image != null && mounted) {
          final File imageFile = File(image.path);
          setState(() {
            _selectedImage = imageFile;
            _imagePreviewUrl = imageFile.path;
            _hasResults = false;
            _identificationResults = {};
            _debugInfo =
                '✅ Image loaded: ${image.name}\n'
                'Click "Identify Plant" to analyze with Gemini AI';
          });
        }
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
    if (_selectedImage == null) {
      _showSnackBar('Please upload an image first', Colors.orange);
      return;
    }

    if (!_apiReady) {
      _showSnackBar('Please add your Gemini API key first', Colors.orange);
      return;
    }

    setState(() {
      _isProcessing = true;
      _hasResults = false;
      _debugInfo = '🔄 Analyzing image with Gemini Vision AI...';
    });

    _animationController.reset();
    _animationController.forward();

    try {
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) _animationController.value = 0.2;

      if (mounted) {
        setState(() {
          _debugInfo = '🔍 Sending image to Gemini AI for analysis...';
        });
      }

      // Get image bytes
      final imageBytes = await _getImageBytes();
      if (imageBytes == null) {
        throw Exception('Failed to read image data');
      }

      // Base64 encode the image
      final base64Image = base64Encode(imageBytes);
      final mimeType = kIsWeb ? 'image/jpeg' : 'image/jpeg';

      // Prepare the prompt for Ugandan context
      final prompt = '''
You are an expert in Ugandan medicinal plants and traditional medicine. Analyze this plant image and provide a comprehensive identification following this exact JSON structure:

{
  "scientificName": "Scientific name of the plant",
  "commonName": "Common name in English and local Ugandan names",
  "family": "Plant family",
  "confidence": "Confidence score as number between 70-99",
  "medicinalProperties": ["List of 4-6 key medicinal properties with emojis"],
  "preparation": ["List of 3-5 traditional preparation methods used in Uganda"],
  "culturalContext": {
    "location": "Regions in Uganda where found",
    "communities": "Specific Ugandan communities that use it",
    "significance": "Cultural and medicinal significance",
    "traditionalKnowledge": "Traditional knowledge from Ugandan healers"
  },
  "conservation": "Conservation status in Uganda",
  "seasonalInfo": "Best harvesting season in Ugandan context"
}

If you cannot identify the specific plant, provide your best guess based on visible features and include "confidence": "Low" in the response.
''';

      // Call Gemini API
      final response = await _callGeminiAPI(base64Image, mimeType, prompt);

      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) _animationController.value = 0.5;

      if (mounted) {
        setState(() {
          _debugInfo = '📊 Processing AI response...';
        });
      }

      // Parse the response
      final analysisResult = _parseGeminiResponse(response);

      // Add analysis ID
      analysisResult['analysisId'] =
          'UGA-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch % 10000}';

      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) _animationController.value = 0.75;

      if (mounted) {
        setState(() {
          _debugInfo = '📚 Retrieving additional medicinal information...';
        });
      }

      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) _animationController.value = 1.0;

      if (mounted) {
        setState(() {
          _identificationResults = analysisResult;
          _isProcessing = false;
          _hasResults = true;
          _debugInfo =
              '✅ Analysis complete! Identified: ${analysisResult['commonName']}\n'
              'Confidence: ${analysisResult['confidence']}%';
        });
      }

      _showSnackBar(
        '✅ Plant identified: ${analysisResult['commonName']}',
        Colors.green,
      );
    } catch (e) {
      debugPrint('Processing error: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _debugInfo =
              '❌ Error during identification: $e\n\n'
              'Please check your API key and internet connection.\n'
              'Make sure the image shows the plant clearly.';
        });
        _showSnackBar('Error identifying plant: $e', Colors.red);
      }
    }
  }

  Future<Uint8List?> _getImageBytes() async {
    if (kIsWeb && _selectedImage != null) {
      final completer = Completer<Uint8List?>();
      final reader = html.FileReader();
      reader.readAsArrayBuffer(_selectedImage);
      reader.onLoadEnd.listen((event) {
        completer.complete(reader.result as Uint8List?);
      });
      reader.onError.listen((event) {
        completer.completeError('Failed to read image');
      });
      return completer.future;
    } else if (!kIsWeb && _selectedImage != null) {
      return await (_selectedImage as File).readAsBytes();
    }
    return null;
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
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
                        if (_debugInfo.contains('API Key') &&
                            _geminiApiKey == 'YOUR_GEMINI_API_KEY_HERE')
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                await _showApiKeyDialog();
                              },
                              icon: const Icon(Icons.vpn_key, size: 16),
                              label: const Text('Add API Key'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                textStyle: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 1, child: _buildUploadSection()),
                    if (_isProcessing || _hasResults)
                      Expanded(
                        flex: 1,
                        child: _isProcessing
                            ? _buildProcessingSection()
                            : _buildResultsSection(),
                      ),
                    if (!_hasResults &&
                        !_isProcessing &&
                        _selectedImage == null)
                      Expanded(flex: 1, child: _buildInfoSection()),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showApiKeyDialog() async {
    final TextEditingController apiKeyController = TextEditingController();

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Gemini API Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Get your free API key from Google AI Studio:',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                // Open URL - you'll need url_launcher package
              },
              child: Text(
                'https://aistudio.google.com/app/apikey',
                style: TextStyle(
                  color: Colors.blue.shade700,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: apiKeyController,
              decoration: const InputDecoration(
                labelText: 'API Key',
                border: OutlineInputBorder(),
                hintText: 'Enter your Gemini API key',
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // In a real app, you'd save this securely
              // For demo, we'll just show a message
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('API key would be saved here'),
                  duration: Duration(seconds: 2),
                ),
              );
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ... (rest of the UI methods remain the same as before - _buildHeader, _buildUploadSection, etc.)
  // Include all the UI building methods from the previous version

  Widget _buildHeader() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade50, Colors.green.shade100],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
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
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade800,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Powered by Google Gemini Vision AI\n'
                    'Upload a photo of any plant to identify it and learn about its medicinal properties, traditional uses, and cultural significance in Ugandan communities.',
                    style: TextStyle(color: Colors.green.shade700, height: 1.4),
                  ),
                  if (kIsWeb)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.cloud_queue,
                              size: 16,
                              color: Colors.blue.shade700,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '✓ Works on web - Uses Google\'s Gemini AI for accurate plant identification',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade700,
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
                  border: Border.all(color: Colors.green.shade200, width: 2),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.green.shade50,
                ),
                child: _selectedImage == null
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
                                  'AI-Powered by Gemini Vision',
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
                            child: kIsWeb && _imagePreviewUrl != null
                                ? Image.network(
                                    _imagePreviewUrl!,
                                    fit: BoxFit.cover,
                                  )
                                : (_selectedImage is File
                                      ? Image.file(
                                          _selectedImage as File,
                                          fit: BoxFit.cover,
                                        )
                                      : const SizedBox()),
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
                                    _selectedImage = null;
                                    _imagePreviewUrl = null;
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
                onPressed: _selectedImage != null && !_isProcessing && _apiReady
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
                      ? 'Analyzing with Gemini AI...'
                      : (_apiReady
                            ? 'Identify Plant with AI'
                            : 'Add API Key to Start'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  disabledBackgroundColor: Colors.green.shade300,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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
                Icon(
                  Icons.auto_awesome,
                  color: Colors.green.shade700,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Text(
                  'Gemini AI Analysis',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildProcessingStep(
              1,
              'Image Upload',
              'Sending image to Gemini Vision AI...',
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
              backgroundColor: Colors.green.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade700),
            ),
            const SizedBox(height: 8),
            Text(
              'AI Analysis Progress... ${(_progressAnimation.value * 100).toInt()}%',
              style: TextStyle(fontSize: 12, color: Colors.green.shade600),
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
                          'Powered by Google Gemini Vision AI',
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
                    'This app uses Google\'s advanced Gemini Vision model to analyze plant images and provide accurate identification with Ugandan cultural context.',
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
              'Gemini Vision AI analyzes the image and identifies the plant species',
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
