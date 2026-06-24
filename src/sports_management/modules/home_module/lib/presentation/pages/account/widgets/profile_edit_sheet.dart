import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:server_module/server_module.dart';
import 'package:authentication_module/authentication_module.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:notification_module/notification_module.dart';

class ProfileEditSheet extends StatefulWidget {
  final String userId;
  final VoidCallback onProfileUpdated;

  const ProfileEditSheet({
    super.key,
    required this.userId,
    required this.onProfileUpdated,
  });

  static Future<void> show(
    BuildContext context, {
    required String userId,
    required VoidCallback onProfileUpdated,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProfileEditSheet(
        userId: userId,
        onProfileUpdated: onProfileUpdated,
      ),
    );
  }

  @override
  State<ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends State<ProfileEditSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  
  bool _isLoading = true;
  bool _isSaving = false;
  String? _avatarUrl;

  final List<String> _presetAvatars = [
    'https://api.dicebear.com/7.x/adventurer/png?seed=tennis',
    'https://api.dicebear.com/7.x/adventurer/png?seed=soccer',
    'https://api.dicebear.com/7.x/adventurer/png?seed=basketball',
    'https://api.dicebear.com/7.x/adventurer/png?seed=running',
    'https://api.dicebear.com/7.x/adventurer/png?seed=swimming',
    'https://api.dicebear.com/7.x/adventurer/png?seed=golf',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    try {
      final response = await GetIt.I<UserService>().getUserById(widget.userId);
      if (response.success && response.data != null) {
        // GET /api/v1/user/:id returns { user: { _id, email, role, status, profile: { fullName, phone, avatar } } }
        final data = response.data as Map<String, dynamic>;
        // The response wraps data inside a 'user' key
        final userMap = data['user'] as Map<String, dynamic>? ?? data;
        final profile = userMap['profile'] as Map<String, dynamic>? ?? {};
        
        _nameController.text = profile['fullName']?.toString() ?? 
            userMap['name']?.toString() ?? '';
        _avatarUrl = profile['avatar']?.toString() ?? 
            userMap['avatar']?.toString() ?? userMap['avatarUrl']?.toString();
        _phoneController.text = profile['phone']?.toString() ?? 
            userMap['phone']?.toString() ?? '';
      }
    } catch (e) {
      debugPrint('Error loading user profile from server: $e');
    }

    // Fallback to local data if fields are empty
    try {
      final localUserRes = await GetIt.I<GetLocalUserUseCase>()();
      final localUser = localUserRes.fold((_) => null, (u) => u);
      if (localUser != null) {
        if (_nameController.text.isEmpty) {
          _nameController.text = localUser.name ?? '';
        }
        _avatarUrl ??= localUser.avatarUrl;
      }
    } catch (e) {
      debugPrint('Error loading local user: $e');
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final request = UpdateProfileRequest(
        userId: widget.userId,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        avatar: _avatarUrl,
      );
      final updateProfileUseCase = GetIt.I<UpdateProfileUseCase>();
      final result = await updateProfileUseCase(request);

      if (mounted) {
        result.fold(
          (failure) {
            _showSnackBar('${context.tr(vi: 'Cập nhật thất bại: ', en: 'Update failed: ')}${failure.message}', isError: true);
          },
          (userResult) {
            widget.onProfileUpdated();
            _showSnackBar(context.tr(vi: 'Cập nhật thông tin thành công!', en: 'Profile updated successfully!'), isError: false);
            Navigator.pop(context);
          },
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('${context.tr(vi: 'Có lỗi xảy ra: ', en: 'An error occurred: ')}$e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _deactivateAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          backgroundColor: theme.cardTheme.color ?? theme.colorScheme.surface,
          title: Text(
            context.tr(vi: 'Hủy tài khoản', en: 'Deactivate Account'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            context.tr(vi: 'Bạn có chắc chắn muốn hủy/vô hiệu hóa tài khoản này? Hành động này không thể hoàn tác và bạn sẽ bị đăng xuất ngay lập tức.', en: 'Are you sure you want to deactivate/disable this account? This action is irreversible and you will be logged out immediately.'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                context.tr(vi: 'Hủy bỏ', en: 'Cancel'),
                style: TextStyle(color: theme.textTheme.bodyMedium?.color),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.tr(vi: 'Xác nhận xóa', en: 'Confirm Delete')),
            ),
          ],
        );
      },
    );

    if (confirm == true && mounted) {
      setState(() {
        _isSaving = true;
      });

      try {
        final response = await GetIt.I<UserService>().updateUserStatus(
          widget.userId,
          'INACTIVE',
        );

        if (response.success && mounted) {
          await GetIt.I<ClearLocalSessionUseCase>()();
          if (!mounted) return;
          _showSnackBar(context.tr(vi: 'Tài khoản đã được hủy thành công.', en: 'Account successfully deactivated.'), isError: false);
          Navigator.pop(context); // Close bottom sheet
          context.go('/sign-in'); // Redirect to login
        } else if (mounted) {
          _showSnackBar('${context.tr(vi: 'Hủy tài khoản thất bại: ', en: 'Account deactivation failed: ')}${response.message}', isError: true);
        }
      } catch (e) {
        if (mounted) {
          _showSnackBar('${context.tr(vi: 'Có lỗi xảy ra: ', en: 'An error occurred: ')}$e', isError: true);
        }
      } finally {
        if (mounted) {
          setState(() {
            _isSaving = false;
          });
        }
      }
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openAvatarSelection() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _AvatarSelectionSheet(
          initialAvatarUrl: _avatarUrl,
          presetAvatars: _presetAvatars,
          onAvatarSelected: (selectedUrl) {
            setState(() {
              _avatarUrl = selectedUrl;
            });
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Container(
      height: size.height * 0.9,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Drag handle
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 8),

                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.tr(vi: 'Thông tin cá nhân', en: 'Personal Information'),
                        style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(),

                // Scrollable Form
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Avatar edit section
                        Center(
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 55,
                                backgroundColor: theme.colorScheme.surface,
                                backgroundImage: _avatarUrl != null && _avatarUrl!.isNotEmpty
                                    ? NetworkImage(_avatarUrl!)
                                    : null,
                                child: _avatarUrl == null || _avatarUrl!.isEmpty
                                    ? const Icon(Icons.person, size: 55, color: Colors.grey)
                                    : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: theme.colorScheme.secondary,
                                  child: IconButton(
                                    icon: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                                    onPressed: _openAvatarSelection,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Full Name field
                        Text(
                          context.tr(vi: 'Họ và tên', en: 'Full Name'),
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            hintText: context.tr(vi: 'Nhập họ và tên của bạn', en: 'Enter your full name'),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return context.tr(vi: 'Họ tên không được để trống', en: 'Name cannot be empty');
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Phone Number field
                        Text(
                          context.tr(vi: 'Số điện thoại', en: 'Phone Number'),
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            hintText: context.tr(vi: 'Nhập số điện thoại', en: 'Enter phone number'),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Save changes button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _saveProfile,
                            child: _isSaving
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                  )
                                : Text(context.tr(vi: 'Lưu thay đổi', en: 'Save changes')),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Deactivate button
                        TextButton(
                          onPressed: _isSaving ? null : _deactivateAccount,
                          child: Text(
                            context.tr(vi: 'Hủy tài khoản', en: 'Deactivate Account'),
                            style: TextStyle(
                              color: theme.colorScheme.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _AvatarSelectionSheet extends StatefulWidget {
  final String? initialAvatarUrl;
  final List<String> presetAvatars;
  final ValueChanged<String> onAvatarSelected;

  const _AvatarSelectionSheet({
    required this.initialAvatarUrl,
    required this.presetAvatars,
    required this.onAvatarSelected,
  });

  @override
  State<_AvatarSelectionSheet> createState() => _AvatarSelectionSheetState();
}

class _AvatarSelectionSheetState extends State<_AvatarSelectionSheet> {
  late String? _selectedUrl;
  final _urlController = TextEditingController();
  int _activeTab = 0; // 0: Upload, 1: Presets, 2: URL Link
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _selectedUrl = widget.initialAvatarUrl;
    if (_selectedUrl != null && !widget.presetAvatars.contains(_selectedUrl)) {
      _urlController.text = _selectedUrl!;
      _activeTab = 2; // Default to URL tab if initial is custom URL
    } else if (_selectedUrl != null && widget.presetAvatars.contains(_selectedUrl)) {
      _activeTab = 1; // Default to presets tab if initial is preset
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    final errNoPath = context.tr(
      vi: 'Không tìm thấy đường dẫn ảnh trong phản hồi từ server.',
      en: 'Image path not found in server response.',
    );
    final errUploadFailed = context.tr(
      vi: 'Tải ảnh lên thất bại',
      en: 'Failed to upload image',
    );

    setState(() {
      _isUploading = true;
    });

    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (image == null) {
        setState(() {
          _isUploading = false;
        });
        return;
      }

      final fileName = image.name;
      final fileBytes = await image.readAsBytes();
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          fileBytes,
          filename: fileName,
        ),
      });

      final response = await GetIt.I<UploadService>().uploadSingle(formData);
      if (response.success && response.data != null) {
        final rawData = response.data as Map<String, dynamic>;
        // Supports response format where url can be directly under rawData, inside rawData.data, or rawData.data.path
        final url = (rawData['url']?.toString()) ?? 
                    (rawData['data']?['url']?.toString()) ?? 
                    (rawData['data']?['path']?.toString());
                    
        if (url != null && url.isNotEmpty) {
          setState(() {
            _selectedUrl = url;
            _isUploading = false;
          });
          widget.onAvatarSelected(url);
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.tr(vi: 'Tải ảnh đại diện lên thành công!', en: 'Avatar uploaded successfully!')),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } else {
          throw Exception(errNoPath);
        }
      } else {
        throw Exception(response.message ?? errUploadFailed);
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.tr(vi: 'Lỗi khi tải ảnh: ', en: 'Error uploading image: ')}$e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = const Color(0xFFFF5600);

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Drag Handle & Title
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.tr(vi: 'Cập nhật ảnh đại diện', en: 'Update Avatar'),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),

            // Tab selection (ChoiceChips)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ChoiceChip(
                  label: Text(context.tr(vi: 'Tải ảnh lên', en: 'Upload Photo')),
                  selected: _activeTab == 0,
                  selectedColor: primaryColor.withValues(alpha: 0.15),
                  labelStyle: TextStyle(
                    color: _activeTab == 0 ? primaryColor : theme.textTheme.bodyMedium?.color,
                    fontWeight: _activeTab == 0 ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (selected) {
                    if (selected) setState(() => _activeTab = 0);
                  },
                ),
                ChoiceChip(
                  label: Text(context.tr(vi: 'Ảnh mẫu', en: 'Presets')),
                  selected: _activeTab == 1,
                  selectedColor: primaryColor.withValues(alpha: 0.15),
                  labelStyle: TextStyle(
                    color: _activeTab == 1 ? primaryColor : theme.textTheme.bodyMedium?.color,
                    fontWeight: _activeTab == 1 ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (selected) {
                    if (selected) setState(() => _activeTab = 1);
                  },
                ),
                ChoiceChip(
                  label: Text(context.tr(vi: 'Đường dẫn URL', en: 'URL Link')),
                  selected: _activeTab == 2,
                  selectedColor: primaryColor.withValues(alpha: 0.15),
                  labelStyle: TextStyle(
                    color: _activeTab == 2 ? primaryColor : theme.textTheme.bodyMedium?.color,
                    fontWeight: _activeTab == 2 ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (selected) {
                    if (selected) setState(() => _activeTab = 2);
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Tab Content
            if (_activeTab == 0) ...[
              // Upload tab
              if (_isUploading)
                Column(
                  children: [
                    const CircularProgressIndicator(color: Color(0xFFFF5600)),
                    const SizedBox(height: 16),
                    Text(context.tr(vi: 'Đang tải ảnh lên máy chủ, vui lòng đợi...', en: 'Uploading image to server, please wait...')),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickAndUploadImage(ImageSource.camera),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          decoration: BoxDecoration(
                            border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                            borderRadius: BorderRadius.circular(12),
                            color: theme.colorScheme.surface.withValues(alpha: 0.5),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.camera_alt_outlined, size: 36, color: primaryColor),
                              const SizedBox(height: 8),
                              Text(context.tr(vi: 'Chụp ảnh mới', en: 'Take new photo')),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickAndUploadImage(ImageSource.gallery),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          decoration: BoxDecoration(
                            border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                            borderRadius: BorderRadius.circular(12),
                            color: theme.colorScheme.surface.withValues(alpha: 0.5),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.photo_library_outlined, size: 36, color: primaryColor),
                              const SizedBox(height: 8),
                              Text(context.tr(vi: 'Chọn từ thư viện', en: 'Choose from library')),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ] else if (_activeTab == 1) ...[
              // Presets Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: widget.presetAvatars.length,
                itemBuilder: (context, index) {
                  final avatar = widget.presetAvatars[index];
                  final isSelected = _selectedUrl == avatar;

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedUrl = avatar;
                      });
                      widget.onAvatarSelected(avatar);
                      Navigator.pop(context);
                    },
                    borderRadius: BorderRadius.circular(40),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: theme.colorScheme.surface,
                          backgroundImage: NetworkImage(avatar),
                        ),
                        if (isSelected)
                          Positioned(
                            bottom: 4,
                            right: 4,
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: primaryColor,
                              child: const Icon(Icons.check, size: 14, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ] else if (_activeTab == 2) ...[
              // URL input tab
              Text(
                context.tr(vi: 'Nhập liên kết hình ảnh tự do:', en: 'Enter custom image link:'),
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _urlController,
                decoration: const InputDecoration(
                  hintText: 'https://example.com/avatar.png',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link),
                ),
                onChanged: (val) {
                  setState(() {
                    _selectedUrl = val.trim();
                  });
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _selectedUrl != null && _selectedUrl!.isNotEmpty
                    ? () {
                        widget.onAvatarSelected(_selectedUrl!);
                        Navigator.pop(context);
                      }
                    : null,
                icon: const Icon(Icons.check),
                label: Text(context.tr(vi: 'Xác nhận URL', en: 'Confirm URL')),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
