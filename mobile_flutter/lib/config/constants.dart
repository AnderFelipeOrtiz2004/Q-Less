import '../services/server_config_service.dart';

export 'api_config.dart';

String getBaseUrl() => ServerConfigService.currentBaseUrl;

String get storageUrl => '${getBaseUrl()}storage/';
String get productsStorageUrl => '${storageUrl}products/';
String get avatarsStorageUrl => '${storageUrl}avatars/';
