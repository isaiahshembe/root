import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
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
      } else if (imageFile is XFile) {
        await _client.storage
            .from('heritage-images')
            .uploadBinary(filePath, await imageFile.readAsBytes());
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
  static const _paper = Color(0xFFF7F9F6);
  static const _forest = Color(0xFF174A3B);
  static const _clay = Color(0xFFCE342E);
  static const _ink = Color(0xFF202622);
  static const _rule = Color(0xFFD8DFD9);
  static const _sun = Color(0xFFFFC928);

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
  Uint8List? _imagePreviewBytes;
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
      if (kIsWeb) {
        final input = html.FileUploadInputElement()..accept = 'image/*';
        input.click();

        input.onChange.listen((event) {
          final files = input.files;
          if (files == null || files.isEmpty) return;
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
        });
      } else {
        final image = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
        );
        if (image == null) return;
        final bytes = await image.readAsBytes();
        if (bytes.length > 5 * 1024 * 1024) {
          _showSnackBar('Image too large (max 5MB)', Colors.orange);
          return;
        }
        setState(() {
          _selectedImage = image;
          _imagePreviewBytes = bytes;
        });
      }
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
      _imagePreviewBytes = null;
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
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(
          context,
        ).textTheme.apply(fontFamily: GoogleFonts.manrope().fontFamily),
      ),
      child: Scaffold(
        backgroundColor: _paper,
        body: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                constraints.maxWidth < 600 ? 20 : 40,
                28,
                constraints.maxWidth < 600 ? 20 : 40,
                40,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: _buildForm(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _flagMark(_clay),
            const SizedBox(width: 3),
            _flagMark(_sun),
            const SizedBox(width: 3),
            _flagMark(_ink),
            const SizedBox(width: 10),
            Text(
              'LIVING HERITAGE  /  UGANDA',
              style: GoogleFonts.spaceGrotesk(
                color: _forest,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Share what you know',
          style: GoogleFonts.newsreader(
            color: _forest,
            fontSize: 32,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Help preserve the knowledge held in your community.',
          style: TextStyle(color: _ink, fontSize: 15, height: 1.45),
        ),
        const SizedBox(height: 24),
        const Divider(height: 1, color: _rule),
        const SizedBox(height: 28),
        _sectionTitle('', 'Place'),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _selectedSiteId,
                isExpanded: true,
                decoration: _fieldDecoration(
                  _isLoading ? 'Loading sites...' : 'Heritage site',
                ),
                items: _heritageSites.map((site) {
                  return DropdownMenuItem<String>(
                    value: site.id,
                    child: Text(site.name, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedSiteId = value),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'Add a heritage site',
              onPressed: _showAddSiteDialog,
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFE5E9DF),
                foregroundColor: _forest,
                fixedSize: const Size(56, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              icon: const Icon(Icons.add_location_alt_outlined),
            ),
          ],
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final latitude = TextField(
              controller: _latitudeCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: _fieldDecoration('Latitude', hint: '0.3136'),
            );
            final longitude = TextField(
              controller: _longitudeCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: _fieldDecoration('Longitude', hint: '32.5811'),
            );
            if (constraints.maxWidth < 360) {
              return Column(
                children: [latitude, const SizedBox(height: 10), longitude],
              );
            }
            return Row(
              children: [
                Expanded(child: latitude),
                const SizedBox(width: 12),
                Expanded(child: longitude),
              ],
            );
          },
        ),
        const SizedBox(height: 28),
        _sectionTitle('', 'Photo'),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: _selectedImage == null ? _pickImage : null,
          child: Container(
            height: 156,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFECE9DF),
              border: Border.all(color: _rule),
              borderRadius: BorderRadius.circular(6),
            ),
            child: _selectedImage == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo_outlined,
                        color: _forest,
                        size: 28,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Add a photo',
                        style: TextStyle(
                          color: _forest,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Optional  ·  JPG or PNG, up to 5 MB',
                        style: TextStyle(
                          color: Color(0xFF6E746E),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: kIsWeb && _imageUrl != null
                            ? Image.network(_imageUrl!, fit: BoxFit.cover)
                            : (_imagePreviewBytes != null
                                  ? Image.memory(
                                      _imagePreviewBytes!,
                                      fit: BoxFit.cover,
                                    )
                                  : const SizedBox.shrink()),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton.filled(
                          tooltip: 'Remove photo',
                          onPressed: _removeImage,
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black54,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.close),
                        ),
                      ),
                      if (_isUploading)
                        const ColoredBox(
                          color: Color(0x88000000),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 28),
        _sectionTitle('', 'Story'),
        const SizedBox(height: 14),
        TextField(
          controller: _narrativeCtrl,
          minLines: 4,
          maxLines: 6,
          decoration: _fieldDecoration(
            'Cultural story *',
            hint: 'What should future generations know?',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _traditionalCtrl,
          minLines: 2,
          maxLines: 4,
          decoration: _fieldDecoration(
            'Traditional use (optional)',
            hint: 'Preparation, use, or related practices',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _userNameCtrl,
          decoration: _fieldDecoration('Your name (optional)'),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: (_isSubmitting || _isUploading) ? null : _submitForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: _forest,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _forest.withValues(alpha: 0.55),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            icon: (_isSubmitting || _isUploading)
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.arrow_upward, size: 18),
            label: Text(
              (_isSubmitting || _isUploading)
                  ? 'Submitting...'
                  : 'Submit contribution',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration(String label, {String? hint}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFFBFAF6),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: _rule),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: _rule),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: _forest, width: 1.5),
        ),
      );

  Widget _flagMark(Color color) => Container(
    width: 14,
    height: 5,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(2),
    ),
  );

  Widget _sectionTitle(String number, String title) => Row(
    children: [
      Text(
        number,
        style: GoogleFonts.spaceGrotesk(
          color: _clay,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(width: 10),
      Text(
        title,
        style: GoogleFonts.newsreader(
          color: _forest,
          fontSize: 20,
          fontWeight: FontWeight.w700,
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
