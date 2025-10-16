import 'package:upmoo25/infrastructure/models/data/help_data.dart';
import 'package:upmoo25/infrastructure/models/data/notification_list_data.dart';

import 'package:upmoo25/domain/handlers/handlers.dart';
import 'package:upmoo25/infrastructure/models/data/translation.dart';
import 'package:upmoo25/infrastructure/models/models.dart';

abstract class SettingsRepositoryFacade {
  Future<ApiResult<GlobalSettingsResponse>> getGlobalSettings();

  Future<ApiResult<MobileTranslationsResponse>> getMobileTranslations();

  Future<ApiResult<LanguagesResponse>> getLanguages();

  Future<ApiResult<NotificationsListModel>> getNotificationList();

  Future<ApiResult<dynamic>> updateNotification(
      List<NotificationData>? notifications);

  Future<ApiResult<HelpModel>> getFaq();

  Future<ApiResult<Translation>> getTerm();

  Future<ApiResult<Translation>> getPolicy();

}
