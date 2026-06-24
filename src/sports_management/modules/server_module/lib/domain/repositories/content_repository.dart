import 'package:server_module/data/models/base_response.dart';
import 'package:server_module/domain/entities/emoji_entity.dart';
import 'package:server_module/domain/entities/helpdesk_entity.dart';

abstract class ContentRepository {
  Future<BaseResponse<List<EmojiEntity>>> getEmojis({Map<String, dynamic>? queryParams});
  
  Future<BaseResponse<List<HelpdeskEntity>>> getHelpdesks({Map<String, dynamic>? queryParams});
}