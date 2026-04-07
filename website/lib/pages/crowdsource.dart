import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

// Conditional import for web
import 'package:website/src/html_stub.dart'
    if (dart.library.html) 'dart:html'
    as html;

// Supabase Service Class
class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  final SupabaseClient _client = Supabase.instance.client;
  SupabaseClient get client => _client;

  Future<String?> uploadImage(dynamic imageFile) async {
    try {
      final uuid = const Uuid();
      final fileName = '${uuid.v4()}.jpg';
      final filePath = 'plant_images/$fileName';

      print('Starting image upload to: $filePath');

      if (kIsWeb && imageFile is html.File) {
        final reader = html.FileReader();
        final completer = Completer<Uint8List>();

        reader.onLoadEnd.listen((_) {
          final result = reader.result;
          if (result is ByteBuffer) {
            completer.complete(Uint8List.view(result));
          } else if (result is List<int>) {
            completer.complete(Uint8List.fromList(result));
          } else {
            completer.completeError('Unsupported result type');
          }
        });

        reader.onError.listen((error) {
          print('FileReader error: $error');
          completer.completeError(error);
        });

        reader.readAsArrayBuffer(imageFile);
        final bytes = await completer.future;

        print('Image bytes read: ${bytes.length} bytes');

        await _client.storage
            .from('heritage-images')
            .uploadBinary(filePath, bytes);

        print('Upload successful');
      } else {
        await _client.storage
            .from('heritage-images')
            .upload(filePath, imageFile);
      }

      final publicUrl = _client.storage
          .from('heritage-images')
          .getPublicUrl(filePath);

      print('Public URL: $publicUrl');
      return publicUrl;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getHeritageSites() async {
    try {
      final response = await _client
          .from('heritage_sites')
          .select('id, name, description')
          .order('name');
      final sitesWithCounts = <Map<String, dynamic>>[];
      for (var site in response) {
        final artifactsResp = await _client
            .from('artifacts')
            .select('id')
            .eq('heritage_site_id', site['id']);
        sitesWithCounts.add({
          'id': site['id'],
          'name': site['name'],
          'description': site['description'],
          'artifacts': (artifactsResp as List).length,
        });
      }
      return sitesWithCounts;
    } catch (e) {
      print('Error getting heritage sites: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> addHeritageSite(
    String name,
    String? description,
  ) async {
    try {
      final resp = await _client.from('heritage_sites').insert({
        'name': name,
        'description': description ?? '',
        'created_at': DateTime.now().toIso8601String(),
      }).select();
      return (resp as List).isNotEmpty ? resp.first : null;
    } catch (e) {
      print('Error adding heritage site: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> submitArtifact({
    required String heritageSiteId,
    required double latitude,
    required double longitude,
    required String culturalNarrative,
    String? traditionalUse,
    String? userName,
    String? plantImageUrl,
  }) async {
    try {
      print('Submitting artifact with image URL: $plantImageUrl');

      final response = await _client.from('artifacts').insert({
        'heritage_site_id': heritageSiteId,
        'latitude': latitude,
        'longitude': longitude,
        'cultural_narrative': culturalNarrative,
        'traditional_use': traditionalUse,
        'user_name': userName,
        'plant_image_url': plantImageUrl,
        'status': 'pending',
        'submitted_at': DateTime.now().toIso8601String(),
      }).select();

      print('Artifact submitted successfully');
      return response.first;
    } catch (e) {
      print('Error submitting artifact: $e');
      return null;
    }
  }
}

class Crowdsource extends StatefulWidget {
  const Crowdsource({super.key});

  @override
  State<Crowdsource> createState() => _CrowdsourceState();
}

class _CrowdsourceState extends State<Crowdsource> {
  final SupabaseService _supabase = SupabaseService();
  final _latitudeCtrl = TextEditingController();
  final _longitudeCtrl = TextEditingController();
  final _narrativeCtrl = TextEditingController();
  final _traditionalCtrl = TextEditingController();
  final _userNameCtrl = TextEditingController();

  List<HeritageSite> _heritageSites = [];
  String? _selectedSiteId;
  dynamic _selectedImage;
  String? _imageUrl;
  bool _isUploading = false;
  bool _isSubmitting = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHeritageSites();
    _latitudeCtrl.text = '0.0000';
    _longitudeCtrl.text = '0.0000';
  }

  @override
  void dispose() {
    _latitudeCtrl.dispose();
    _longitudeCtrl.dispose();
    _narrativeCtrl.dispose();
    _traditionalCtrl.dispose();
    _userNameCtrl.dispose();
    if (_imageUrl != null && _imageUrl!.startsWith('blob:')) {
      html.Url.revokeObjectUrl(_imageUrl!);
    }
    super.dispose();
  }

  Future<void> _loadHeritageSites() async {
    setState(() => _isLoading = true);
    try {
      final sites = await _supabase.getHeritageSites();
      _heritageSites = sites
          .map(
            (s) => HeritageSite(
              id: s['id'],
              name: s['name'],
              artifacts: s['artifacts'] ?? 0,
            ),
          )
          .toList();
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showAddSiteDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Heritage Site'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Site name'),
            ),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(context);
              setState(() => _isLoading = true);
              try {
                await _supabase.addHeritageSite(
                  nameCtrl.text.trim(),
                  descCtrl.text.trim(),
                );
                await _loadHeritageSites();
                _showSnackBar('Site added!', Colors.green);
              } catch (e) {
                _showSnackBar('Error: $e', Colors.red);
              } finally {
                setState(() => _isLoading = false);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final input = html.FileUploadInputElement()..accept = 'image/*';
      input.click();

      input.onChange.listen((event) {
        final files = input.files;
        if (files != null && files.isNotEmpty) {
          final file = files[0];
          if (file.size > 5 * 1024 * 1024) {
            _showSnackBar('Image too large (max 5MB)', Colors.orange);
            return;
          }

          if (!file.type.startsWith('image/')) {
            _showSnackBar('Please select an image file', Colors.orange);
            return;
          }

          setState(() {
            _selectedImage = file;
            if (_imageUrl != null && _imageUrl!.startsWith('blob:')) {
              html.Url.revokeObjectUrl(_imageUrl!);
            }
            _imageUrl = html.Url.createObjectUrl(file);
          });

          _showSnackBar('Image loaded: ${file.name}', Colors.green);
        }
      });
    } catch (e) {
      print('Error picking image: $e');
      _showSnackBar('Error picking image: $e', Colors.red);
    }
  }

  void _removeImage() {
    if (_imageUrl != null && _imageUrl!.startsWith('blob:')) {
      html.Url.revokeObjectUrl(_imageUrl!);
    }
    setState(() {
      _selectedImage = null;
      _imageUrl = null;
    });
  }

  Future<void> _submitForm() async {
    if (_selectedSiteId == null) {
      _showSnackBar('Select a heritage site', Colors.orange);
      return;
    }

    if (_narrativeCtrl.text.isEmpty) {
      _showSnackBar('Provide cultural narrative', Colors.orange);
      return;
    }

    double lat, lon;
    try {
      lat = double.parse(_latitudeCtrl.text);
      lon = double.parse(_longitudeCtrl.text);
    } catch (e) {
      _showSnackBar('Enter valid latitude/longitude numbers', Colors.orange);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      String? uploadedUrl;

      if (_selectedImage != null) {
        setState(() => _isUploading = true);
        _showSnackBar('Uploading image...', Colors.blue);

        uploadedUrl = await _supabase.uploadImage(_selectedImage!);

        setState(() => _isUploading = false);

        if (uploadedUrl == null) {
          _showSnackBar(
            'Failed to upload image. Continuing without image.',
            Colors.orange,
          );
        } else {
          _showSnackBar('Image uploaded successfully!', Colors.green);
        }
      }

      _showSnackBar('Submitting artifact...', Colors.blue);

      final result = await _supabase.submitArtifact(
        heritageSiteId: _selectedSiteId!,
        latitude: lat,
        longitude: lon,
        culturalNarrative: _narrativeCtrl.text,
        traditionalUse: _traditionalCtrl.text.isNotEmpty
            ? _traditionalCtrl.text
            : null,
        userName: _userNameCtrl.text.isNotEmpty ? _userNameCtrl.text : null,
        plantImageUrl: uploadedUrl,
      );

      if (result != null) {
        _showSnackBar('Artifact submitted successfully!', Colors.green);
        _clearForm();
        await _loadHeritageSites();
      } else {
        _showSnackBar('Failed to submit artifact', Colors.red);
      }
    } catch (e) {
      print('Error in submit: $e');
      _showSnackBar('Error: $e', Colors.red);
    } finally {
      setState(() {
        _isSubmitting = false;
        _isUploading = false;
      });
    }
  }

  void _clearForm() {
    _narrativeCtrl.clear();
    _traditionalCtrl.clear();
    _userNameCtrl.clear();
    _removeImage();
    _selectedSiteId = null;
    _latitudeCtrl.text = '0.0000';
    _longitudeCtrl.text = '0.0000';
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
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
          final isSmall = constraints.maxWidth < 1200;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: isSmall
                ? Column(
                    children: [
                      _buildForm(),
                      const SizedBox(height: 24),
                      _buildSteps(),
                      const SizedBox(height: 24),
                      _buildSites(),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: _buildForm()),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 1,
                        child: Column(
                          children: [
                            _buildSteps(),
                            const SizedBox(height: 24),
                            _buildSites(),
                          ],
                        ),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }

  Widget _buildForm() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    'Multimodal Crowdsourcing Interface',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Submit botanical artifacts with cultural narratives from Uganda\'s heritage sites.',
                    style: TextStyle(color: Colors.green.shade700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _sectionTitle('Plant Image Upload *', Icons.image),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.green.shade200, width: 2),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.green.shade50,
                ),
                child: _imageUrl == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.cloud_upload,
                            size: 48,
                            color: Colors.green.shade400,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Click to upload plant image',
                            style: TextStyle(color: Colors.green.shade600),
                          ),
                          Text(
                            'JPG, PNG (Max 5MB)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade400,
                            ),
                          ),
                        ],
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(_imageUrl!, fit: BoxFit.cover),
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
                                ),
                                onPressed: _removeImage,
                              ),
                            ),
                          ),
                          if (_isUploading)
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),

            _sectionTitle('Heritage Site Location *', Icons.location_on),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.green.shade200),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedSiteId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Select a heritage site...',
                      ),
                      items: _heritageSites.map((s) {
                        return DropdownMenuItem<String>(
                          value: s.id,
                          child: Row(
                            children: [
                              Icon(
                                Icons.forest,
                                size: 20,
                                color: Colors.green.shade600,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  s.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${s.artifacts}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _selectedSiteId = v),
                    ),
                  ),
                  Tooltip(
                    message: 'Add new heritage site',
                    child: InkWell(
                      onTap: _showAddSiteDialog,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.add_location_alt,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _latitudeCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'GPS Latitude',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: Icon(
                        Icons.pin_drop,
                        color: Colors.green.shade600,
                      ),
                      hintText: 'e.g., 0.3136',
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _longitudeCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'GPS Longitude',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: Icon(
                        Icons.pin_drop,
                        color: Colors.green.shade600,
                      ),
                      hintText: 'e.g., 32.5811',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Enter coordinates manually. You can get coordinates from Google Maps.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _sectionTitle('Cultural Narrative *', Icons.description),
            const SizedBox(height: 12),
            TextField(
              controller: _narrativeCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText:
                    'Describe cultural significance, traditional stories, or indigenous knowledge...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 24),

            _sectionTitle('Traditional Preparation', Icons.medical_services),
            const SizedBox(height: 12),
            TextField(
              controller: _traditionalCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText:
                    'How is this plant prepared and used in traditional medicine?',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 24),

            _sectionTitle('Your Name (Optional)', Icons.person),
            const SizedBox(height: 12),
            TextField(
              controller: _userNameCtrl,
              decoration: InputDecoration(
                hintText: 'Tourist, guide, healer, or researcher name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: Icon(
                  Icons.person_outline,
                  color: Colors.green.shade600,
                ),
              ),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_isSubmitting || _isUploading) ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: (_isSubmitting || _isUploading)
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Text(
                        'Submit to Knowledge Graph',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSteps() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                  'VLM-Assisted Processing',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _step(
              '1',
              'Multimodal Ingestion',
              'Image, GPS metadata, and text collected',
            ),
            _step(
              '2',
              'Cryptographic Hashing',
              'Provenance tracking for epistemic trust',
            ),
            _step(
              '3',
              'VLM Semantic Extraction',
              'Entities extracted from media',
            ),
            _step(
              '4',
              'Ontological Alignment',
              'Cross-referenced with botanical vocabularies',
            ),
          ],
        ),
      ),
    );
  }

  Widget _step(String step, String title, String desc) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.green.shade600,
          ),
          child: Center(
            child: Text(
              step,
              style: const TextStyle(
                color: Colors.white,
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
                  color: Colors.green.shade800,
                ),
              ),
              Text(
                desc,
                style: TextStyle(fontSize: 12, color: Colors.green.shade600),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildSites() {
    if (_isLoading) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Center(
            child: Column(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 12),
                Text(
                  'Loading heritage sites...',
                  style: TextStyle(color: Colors.green.shade600),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.forest, color: Colors.green.shade700, size: 28),
                const SizedBox(width: 8),
                Text(
                  'Heritage Sites',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _heritageSites.length,
              separatorBuilder: (_, __) =>
                  Divider(color: Colors.green.shade100),
              itemBuilder: (_, i) {
                final site = _heritageSites[i];
                final isSelected = _selectedSiteId == site.id;
                return Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.green.shade50
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green.shade100,
                      child: Icon(Icons.forest, color: Colors.green.shade700),
                    ),
                    title: Text(
                      site.name,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w600,
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${site.artifacts}',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    onTap: () => setState(() => _selectedSiteId = site.id),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) => Row(
    children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.green.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: Colors.green.shade700),
      ),
      const SizedBox(width: 8),
      Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.green.shade800,
        ),
      ),
    ],
  );
}

class HeritageSite {
  final String id;
  final String name;
  final int artifacts;
  HeritageSite({required this.id, required this.name, required this.artifacts});
}
