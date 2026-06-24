import 'package:server_module/server_module.dart';
import '../datasources/remote/facility_remote_data_source.dart';

class FacilityRepositoryImpl implements FacilityRepository {
  final FacilityRemoteDataSource _remoteDataSource;

  FacilityRepositoryImpl(this._remoteDataSource);

  @override
  Future<BaseResponse<List<FacilityEntity>>> getFacilities() async {
    final response = await _remoteDataSource.getFacilities();
    if (!response.success || response.data == null) {
      return BaseResponse<List<FacilityEntity>>(
        success: response.success,
        message: response.message,
        data: null,
      );
    }

    try {
      final rawData = response.data as Map<String, dynamic>;
      final itemsList = rawData['items'] as List<dynamic>?;
      final facilities = <FacilityEntity>[];

      if (itemsList != null) {
        for (final item in itemsList) {
          if (item is Map<String, dynamic>) {
            facilities.add(
              FacilityEntity(
                id: item['_id']?.toString() ?? item['id']?.toString() ?? '',
                name: item['name']?.toString() ?? '',
                address: _parseAddress(item),
                description: _parseCity(item),
                ownerId: _parseOwnerId(item),
                status: item['active'] == true ? 'ACTIVE' : 'INACTIVE',
              ),
            );
          }
        }
      }

      return BaseResponse<List<FacilityEntity>>(
        success: true,
        message: response.message,
        data: facilities,
      );
    } catch (e) {
      return BaseResponse<List<FacilityEntity>>(
        success: false,
        message: 'Lỗi parse danh sách FacilityEntity: $e',
        data: null,
      );
    }
  }

  @override
  Future<BaseResponse<FacilityEntity>> createFacility(
    Map<String, dynamic> data,
  ) async {
    final response = await _remoteDataSource.createFacility(data);
    return _mapToFacilityResponse(response);
  }

  @override
  Future<BaseResponse<FacilityEntity>> updateFacility(
    String id,
    Map<String, dynamic> data,
  ) async {
    final response = await _remoteDataSource.updateFacility(id, data);
    return _mapToFacilityResponse(response);
  }

  @override
  Future<BaseResponse<dynamic>> deleteFacility(String id) {
    return _remoteDataSource.deleteFacility(id);
  }

  BaseResponse<FacilityEntity> _mapToFacilityResponse(
    BaseResponse<dynamic> response,
  ) {
    if (!response.success || response.data == null) {
      return BaseResponse<FacilityEntity>(
        success: response.success,
        message: response.message,
        data: null,
      );
    }

    try {
      final rawData = response.data as Map<String, dynamic>;
      final facilityMap =
          (rawData['facility'] as Map<String, dynamic>?) ?? rawData;
      final facility = FacilityEntity(
        id:
            facilityMap['_id']?.toString() ??
            facilityMap['id']?.toString() ??
            '',
        name: facilityMap['name']?.toString() ?? '',
        address: _parseAddress(facilityMap),
        description: _parseCity(facilityMap),
        ownerId: _parseOwnerId(facilityMap),
        status: facilityMap['active'] == true ? 'ACTIVE' : 'INACTIVE',
      );
      return BaseResponse<FacilityEntity>(
        success: true,
        message: response.message,
        data: facility,
      );
    } catch (e) {
      return BaseResponse<FacilityEntity>(
        success: false,
        message: 'Lỗi parse FacilityEntity: $e',
        data: null,
      );
    }
  }

  String _parseAddress(dynamic item) {
    if (item == null) return '';
    final fullAddress = item['fullAddress'];
    final address = item['address'];

    return _extractAddressField(fullAddress, 'full') ??
        _extractAddressField(address, 'full') ??
        _extractAddressField(fullAddress, 'fullAddress') ??
        _extractAddressField(address, 'address') ??
        '';
  }

  String _parseCity(dynamic item) {
    if (item == null) return '';
    final fullAddress = item['fullAddress'];
    final address = item['address'];
    final city = item['city'];

    return _extractAddressField(fullAddress, 'city') ??
        _extractAddressField(address, 'city') ??
        city?.toString() ??
        '';
  }

  String? _extractAddressField(dynamic field, String keyName) {
    if (field == null) return null;
    if (field is Map) {
      return field[keyName]?.toString();
    }

    final str = field.toString().trim();
    if (str.startsWith('{') && str.endsWith('}')) {
      final keyPrefix = '$keyName:';
      final startIndex = str.indexOf(keyPrefix);
      if (startIndex != -1) {
        String valuePart = str.substring(startIndex + keyPrefix.length).trim();

        int nextKeyIndex = -1;
        final possibleKeys = [
          ', city:',
          ', full:',
          ', fullAddress:',
          ', address:',
        ];
        for (final pk in possibleKeys) {
          final idx = valuePart.indexOf(pk);
          if (idx != -1) {
            if (nextKeyIndex == -1 || idx < nextKeyIndex) {
              nextKeyIndex = idx;
            }
          }
        }

        if (nextKeyIndex != -1) {
          valuePart = valuePart.substring(0, nextKeyIndex).trim();
        } else {
          if (valuePart.endsWith('}')) {
            valuePart = valuePart.substring(0, valuePart.length - 1).trim();
          }
        }
        return valuePart;
      }
    }

    if (keyName == 'full' || keyName == 'fullAddress' || keyName == 'address') {
      return str;
    }
    return null;
  }

  String? _parseOwnerId(dynamic item) {
    if (item == null) return null;

    // 1. Thử 'ownerId'
    final ownerId = item['ownerId'];
    if (ownerId != null) {
      return _extractHexId(ownerId);
    }

    // 2. Thử 'staffId'
    final staffId = item['staffId'];
    if (staffId != null) {
      return _extractHexId(staffId);
    }

    // 3. Thử 'staff'
    final staff = item['staff'];
    if (staff != null) {
      return _extractHexId(staff);
    }

    // 4. Thử 'staffIds'
    final staffIds = item['staffIds'];
    if (staffIds != null) {
      if (staffIds is List) {
        return staffIds.isNotEmpty ? _extractHexId(staffIds.first) : null;
      }
      return _extractHexId(staffIds);
    }

    // 5. Thử 'staffs'
    final staffs = item['staffs'];
    if (staffs != null) {
      if (staffs is List) {
        return staffs.isNotEmpty ? _extractHexId(staffs.first) : null;
      }
      return _extractHexId(staffs);
    }

    return null;
  }

  String? _extractHexId(dynamic value) {
    if (value == null) return null;
    if (value is Map) {
      final id = value['_id'] ?? value['id'] ?? value['ownerId'];
      return id != null ? _extractHexId(id) : null;
    }
    if (value is List) {
      return value.isNotEmpty ? _extractHexId(value.first) : null;
    }
    final str = value.toString().trim();
    if (str == '[]' || str == 'null') return null;
    final regExp = RegExp(r'[a-fA-F0-9]{24}');
    final match = regExp.firstMatch(str);
    if (match != null) {
      return match.group(0);
    }
    if (RegExp(r'^\d+$').hasMatch(str)) {
      return str;
    }
    return str.isNotEmpty ? str : null;
  }
}
