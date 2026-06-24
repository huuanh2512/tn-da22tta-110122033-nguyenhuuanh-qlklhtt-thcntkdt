import 'package:authentication_module/authentication_module.dart';
import 'package:dio/dio.dart';
import 'package:facility_module/facility_module.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:image_picker/image_picker.dart';
import 'package:notification_module/notification_module.dart';
import 'package:server_module/server_module.dart';

class StaffPersonalInformationPage extends StatefulWidget {
  const StaffPersonalInformationPage({super.key, required this.facilityId});

  final String? facilityId;

  @override
  State<StaffPersonalInformationPage> createState() =>
      _StaffPersonalInformationPageState();
}

class _StaffPersonalInformationPageState
    extends State<StaffPersonalInformationPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _facilityNameController = TextEditingController();
  final _facilityAddressController = TextEditingController();

  UserResult? _user;
  FacilityEntity? _facility;
  String? _avatarUrl;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isAvatarBusy = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _facilityNameController.dispose();
    _facilityAddressController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final localUserResult = await GetIt.I<GetLocalUserUseCase>()();
    final localUser = localUserResult.fold((_) => null, (user) => user);
    _user = localUser;

    if (localUser?.userId != null) {
      try {
        final response = await GetIt.I<UserService>().getUserById(
          localUser!.userId!,
        );
        if (response.success && response.data != null) {
          final data = response.data as Map<String, dynamic>;
          final userMap = data['user'] as Map<String, dynamic>? ?? data;
          final profile = userMap['profile'] as Map<String, dynamic>? ?? {};

          _nameController.text =
              profile['fullName']?.toString() ??
              profile['name']?.toString() ??
              userMap['name']?.toString() ??
              localUser.name ??
              '';
          _phoneController.text =
              profile['phone']?.toString() ??
              userMap['phone']?.toString() ??
              '';
          _avatarUrl =
              profile['avatarUrl']?.toString() ??
              profile['avatar']?.toString() ??
              userMap['avatarUrl']?.toString() ??
              userMap['avatar']?.toString();
        }
      } catch (error) {
        debugPrint('Error loading staff profile: $error');
      }
    }

    if (_nameController.text.isEmpty) {
      _nameController.text = localUser?.name ?? '';
    }
    _avatarUrl ??= localUser?.avatarUrl;

    try {
      final response = await GetIt.I<GetFacilitiesUseCase>()();
      if (response.success && response.data != null) {
        final matches = response.data!
            .where((facility) => facility.id == widget.facilityId)
            .toList();
        if (matches.isNotEmpty) {
          _facility = matches.first;
          _facilityNameController.text = _facility?.name ?? '';
          _facilityAddressController.text = _facility?.address ?? '';
        }
      }
    } catch (error) {
      debugPrint('Error loading managed facility: $error');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateInformation() async {
    if (!_formKey.currentState!.validate() || _user?.userId == null) {
      return;
    }

    final facilityUpdateError = context.tr(
      vi: 'Không thể cập nhật khu liên hợp.',
      en: 'Unable to update facility.',
    );
    final updateSuccess = context.tr(
      vi: 'Cập nhật thông tin thành công.',
      en: 'Information updated successfully.',
    );
    final errorPrefix = context.tr(
      vi: 'Có lỗi xảy ra: ',
      en: 'An error occurred: ',
    );

    setState(() => _isSaving = true);
    try {
      final profileResult = await GetIt.I<UpdateProfileUseCase>()(
        UpdateProfileRequest(
          userId: _user!.userId!,
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          avatar: _avatarUrl,
        ),
      );

      final profileFailure = profileResult.fold((failure) => failure.message, (
        user,
      ) {
        _user = user;
        _avatarUrl = user.avatarUrl ?? _avatarUrl;
        return null;
      });
      if (profileFailure != null) {
        _showMessage(profileFailure, isError: true);
        return;
      }

      if (_facility != null) {
        final facilityResponse = await GetIt.I<UpdateFacilityUseCase>()(
          id: _facility!.id,
          name: _facilityNameController.text.trim(),
          address: _facilityAddressController.text.trim(),
        );
        if (!mounted) return;
        if (!facilityResponse.success || facilityResponse.data == null) {
          _showMessage(
            facilityResponse.message ?? facilityUpdateError,
            isError: true,
          );
          return;
        }
        _facility = facilityResponse.data;
      }

      setState(() => _isEditing = false);
      _showMessage(updateSuccess);
    } catch (error) {
      _showMessage('$errorPrefix$error', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _chooseAvatarSource() async {
    if (_user?.userId == null || _isAvatarBusy) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: Text(context.tr(vi: 'Chụp ảnh mới', en: 'Take photo')),
                onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(
                  context.tr(vi: 'Chọn từ thư viện', en: 'Choose from library'),
                ),
                onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );
    if (source == null) return;
    await _pickUploadAndSaveAvatar(source);
  }

  Future<void> _pickUploadAndSaveAvatar(ImageSource source) async {
    final userId = _user?.userId;
    if (userId == null) return;
    final uploadFailedMessage = context.tr(
      vi: 'Tải ảnh đại diện thất bại.',
      en: 'Unable to upload avatar.',
    );
    final missingUrlMessage = context.tr(
      vi: 'Không tìm thấy đường dẫn ảnh từ máy chủ.',
      en: 'Image URL was not returned by server.',
    );
    final avatarUpdatedMessage = context.tr(
      vi: 'Đã cập nhật ảnh đại diện.',
      en: 'Avatar updated.',
    );
    final errorPrefix = context.tr(
      vi: 'Có lỗi xảy ra: ',
      en: 'An error occurred: ',
    );

    setState(() => _isAvatarBusy = true);
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 900,
        maxHeight: 900,
      );
      if (image == null) return;

      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          await image.readAsBytes(),
          filename: image.name,
        ),
      });
      final uploadResponse = await GetIt.I<UploadService>().uploadSingle(
        formData,
      );
      if (!uploadResponse.success || uploadResponse.data == null) {
        _showMessage(
          uploadResponse.message ?? uploadFailedMessage,
          isError: true,
        );
        return;
      }

      final rawData = uploadResponse.data as Map<String, dynamic>;
      final nestedData = rawData['data'];
      final avatarUrl =
          rawData['url']?.toString() ??
          (nestedData is Map ? nestedData['url']?.toString() : null) ??
          (nestedData is Map ? nestedData['path']?.toString() : null);
      if (avatarUrl == null || avatarUrl.isEmpty) {
        _showMessage(missingUrlMessage, isError: true);
        return;
      }

      final result = await GetIt.I<UpdateProfileUseCase>()(
        UpdateProfileRequest(
          userId: userId,
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          avatar: avatarUrl,
        ),
      );
      if (!mounted) return;
      result.fold((failure) => _showMessage(failure.message, isError: true), (
        user,
      ) {
        setState(() {
          _user = user;
          _avatarUrl = avatarUrl;
          _isEditing = true;
        });
        _showMessage(avatarUpdatedMessage);
      });
    } catch (error) {
      _showMessage('$errorPrefix$error', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isAvatarBusy = false);
      }
    }
  }

  Future<void> _deleteAvatar() async {
    final userId = _user?.userId;
    if (userId == null || _isAvatarBusy) return;
    final avatarDeletedMessage = context.tr(
      vi: 'Đã xóa ảnh đại diện.',
      en: 'Avatar deleted.',
    );
    final errorPrefix = context.tr(
      vi: 'Có lỗi xảy ra: ',
      en: 'An error occurred: ',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr(vi: 'Xóa ảnh đại diện?', en: 'Delete avatar?')),
        content: Text(
          context.tr(
            vi: 'Ảnh đại diện hiện tại sẽ được gỡ khỏi tài khoản nhân viên.',
            en: 'The current avatar will be removed from this staff account.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr(vi: 'Hủy', en: 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.tr(vi: 'Xóa ảnh', en: 'Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isAvatarBusy = true);
    try {
      final result = await GetIt.I<DeleteUserAvatarUseCase>()(userId);
      if (!mounted) return;
      result.fold((failure) => _showMessage(failure.message, isError: true), (
        user,
      ) {
        setState(() {
          _user = user;
          _avatarUrl = null;
          _isEditing = true;
        });
        _showMessage(avatarDeletedMessage);
      });
    } catch (error) {
      _showMessage('$errorPrefix$error', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isAvatarBusy = false);
      }
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr(vi: 'Thông tin cá nhân', en: 'Personal Information'),
        ),
        actions: [
          if (!_isLoading && !_isEditing)
            IconButton(
              tooltip: context.tr(vi: 'Chỉnh sửa', en: 'Edit'),
              onPressed: () => setState(() => _isEditing = true),
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Center(
                    child: Column(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CircleAvatar(
                              radius: 48,
                              backgroundColor: Colors.orange.shade50,
                              backgroundImage:
                                  _avatarUrl != null && _avatarUrl!.isNotEmpty
                                  ? NetworkImage(_avatarUrl!)
                                  : null,
                              child: _avatarUrl == null || _avatarUrl!.isEmpty
                                  ? Icon(
                                      Icons.person,
                                      size: 48,
                                      color: Colors.orange.shade900,
                                    )
                                  : null,
                            ),
                            if (_isEditing)
                              Positioned(
                                right: -2,
                                bottom: -2,
                                child: Material(
                                  color: theme.colorScheme.primary,
                                  shape: const CircleBorder(),
                                  child: IconButton(
                                    constraints: const BoxConstraints(
                                      minWidth: 38,
                                      minHeight: 38,
                                    ),
                                    icon: _isAvatarBusy
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.camera_alt_outlined,
                                            size: 18,
                                            color: Colors.white,
                                          ),
                                    onPressed: _isAvatarBusy
                                        ? null
                                        : _chooseAvatarSource,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (_isEditing &&
                            _avatarUrl != null &&
                            _avatarUrl!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _isAvatarBusy ? null : _deleteAvatar,
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: Text(
                              context.tr(
                                vi: 'Xóa ảnh đại diện',
                                en: 'Delete avatar',
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSection(
                    title: context.tr(
                      vi: 'Thông tin nhân viên',
                      en: 'Staff Information',
                    ),
                    children: [
                      _buildField(
                        controller: _nameController,
                        label: context.tr(vi: 'Họ và tên', en: 'Full name'),
                        icon: Icons.person_outline,
                        requiredField: true,
                      ),
                      _buildField(
                        initialValue: _user?.email ?? '',
                        label: 'Email',
                        icon: Icons.email_outlined,
                        alwaysReadOnly: true,
                      ),
                      _buildField(
                        controller: _phoneController,
                        label: context.tr(
                          vi: 'Số điện thoại',
                          en: 'Phone number',
                        ),
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    title: context.tr(
                      vi: 'Khu liên hợp đang quản lý',
                      en: 'Managed Facility',
                    ),
                    children: _facility == null
                        ? [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                context.tr(
                                  vi: 'Chưa được phân công khu liên hợp.',
                                  en: 'No facility has been assigned.',
                                ),
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          ]
                        : [
                            _buildField(
                              controller: _facilityNameController,
                              label: context.tr(
                                vi: 'Tên khu liên hợp',
                                en: 'Facility name',
                              ),
                              icon: Icons.business_outlined,
                              requiredField: true,
                            ),
                            _buildField(
                              controller: _facilityAddressController,
                              label: context.tr(vi: 'Địa chỉ', en: 'Address'),
                              icon: Icons.location_on_outlined,
                              requiredField: true,
                              maxLines: 3,
                            ),
                          ],
                  ),
                  if (_isEditing) ...[
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: _isSaving ? null : _updateInformation,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(context.tr(vi: 'Cập nhật', en: 'Update')),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    TextEditingController? controller,
    String? initialValue,
    required String label,
    required IconData icon,
    bool requiredField = false,
    bool alwaysReadOnly = false,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        initialValue: controller == null ? initialValue : null,
        readOnly: alwaysReadOnly || !_isEditing,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          filled: !_isEditing || alwaysReadOnly,
        ),
        validator: requiredField
            ? (value) {
                if (value == null || value.trim().isEmpty) {
                  return context.tr(
                    vi: 'Thông tin này không được để trống.',
                    en: 'This field cannot be empty.',
                  );
                }
                return null;
              }
            : null,
      ),
    );
  }
}
