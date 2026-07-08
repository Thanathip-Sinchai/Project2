import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:easy_localization/easy_localization.dart'; // ✅ Import ภาษา

import '../services/api_service.dart';
import 'profile_page.dart';

class EditProfilePage extends StatefulWidget {
  final UserProfile initial;
  const EditProfilePage({super.key, required this.initial});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  static const bg = Color(0xFF00C2F3);

  final formKey = GlobalKey<FormState>();
  late final TextEditingController nameCtrl;
  late final TextEditingController emailCtrl;

  final ImagePicker _picker = ImagePicker();
  File? _pickedFile; 
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.initial.name);
    emailCtrl = TextEditingController(text: widget.initial.email);
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 800,
      );
      if (image != null) {
        setState(() {
          _pickedFile = File(image.path);
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _handleSave() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    
    setState(() => _isSaving = true);
    
    try {
      String? currentAvatarUrl = widget.initial.avatarUrl;

      if (_pickedFile != null) {
        final res = await ApiService.updateAvatar(
          imageBytes: await _pickedFile!.readAsBytes(),
          imageFilename: _pickedFile!.path.split('/').last,
        );
        currentAvatarUrl = res['avatar_url']; 
      }

      await ApiService.updateMe(
        name: nameCtrl.text.trim(),
        email: emailCtrl.text.trim(),
        avatarUrl: currentAvatarUrl,
      );

      if (!mounted) return;

      final updatedUser = UserProfile(
        name: nameCtrl.text.trim(),
        email: emailCtrl.text.trim(),
        role: widget.initial.role,
        products: widget.initial.products,
        alerts: widget.initial.alerts,
        avatarUrl: currentAvatarUrl,
      );
      
      Navigator.pop(context, updatedUser);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${'edit_profile.toast_fail'.tr()} $e")), // ✅
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6FBFF),
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        title: Text('edit_profile.title'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)), // ✅
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: formKey,
          child: Column(
            children: [
              const SizedBox(height: 20),
              
              GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: bg, width: 3),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))
                        ]
                      ),
                      child: CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.white,
                        backgroundImage: _pickedFile != null
                            ? FileImage(_pickedFile!)
                            : (widget.initial.avatarUrl != null && widget.initial.avatarUrl!.isNotEmpty
                                ? NetworkImage('${ApiService.baseUrl}${widget.initial.avatarUrl}')
                                : null) as ImageProvider?,
                        child: (_pickedFile == null && (widget.initial.avatarUrl == null || widget.initial.avatarUrl!.isEmpty))
                            ? const Icon(Icons.person, size: 60, color: Colors.grey)
                            : null,
                      ),
                    ),
                    Container(
                      height: 35,
                      width: 35,
                      decoration: BoxDecoration(
                        color: bg,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 30),

              _field(
                controller: nameCtrl, 
                label: 'edit_profile.f_name'.tr(), // ✅
                icon: Icons.person_outline
              ),
              const SizedBox(height: 16),
              _field(
                controller: emailCtrl, 
                label: 'edit_profile.f_email'.tr(), // ✅
                icon: Icons.mail_outline
              ),
              
              const SizedBox(height: 32),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: bg,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                  ),
                  onPressed: _isSaving ? null : _handleSave,
                  child: _isSaving 
                    ? const SizedBox(
                        height: 20, 
                        width: 20, 
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      )
                    : Text(
                        'edit_profile.btn_save'.tr(), // ✅
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({required TextEditingController controller, required String label, required IconData icon}) {
    return TextFormField(
      controller: controller,
      validator: (v) => (v == null || v.trim().isEmpty) ? 'edit_profile.val_empty'.tr(args: [label]) : null, // ✅
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: bg),
        filled: true,
        fillColor: bg.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: bg, width: 2),
        ),
      ),
    );
  }
}