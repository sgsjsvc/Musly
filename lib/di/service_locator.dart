import 'package:get_it/get_it.dart';

import '../services/storage_service.dart';
import '../services/subsonic_service.dart';
import '../services/offline_service.dart';
import '../services/recommendation_service.dart';
import '../services/local_music_service.dart';
import '../services/cast_service.dart';
import '../services/locale_service.dart';
import '../services/upnp_service.dart';
import '../services/theme_service.dart';
import '../services/now_playing_theme_service.dart';
import '../services/transcoding_service.dart';
import '../services/audio_handler.dart';
import '../services/android_auto_integration.dart';

import '../services/queue_persistence_manager.dart';
import '../services/queue_manager.dart';

final GetIt locator = GetIt.instance;

void setupLocator() {
  locator.registerLazySingleton<StorageService>(() => StorageService());
  locator.registerLazySingleton<QueuePersistenceManager>(() => QueuePersistenceManager());
  locator.registerLazySingleton<QueueManager>(() => QueueManager(
    locator<StorageService>(),
    locator<QueuePersistenceManager>(),
  ));
  locator.registerLazySingleton<SubsonicService>(() => SubsonicService());
  locator.registerLazySingleton<OfflineService>(() => OfflineService());
  locator.registerLazySingleton<RecommendationService>(() => RecommendationService());
  locator.registerLazySingleton<LocalMusicService>(() => LocalMusicService());
  locator.registerLazySingleton<CastService>(() => CastService());
  locator.registerLazySingleton<LocaleService>(() => LocaleService());
  locator.registerLazySingleton<UpnpService>(() => UpnpService());
  locator.registerLazySingleton<ThemeService>(() => ThemeService());
  locator.registerLazySingleton<NowPlayingThemeService>(() => NowPlayingThemeService());
  locator.registerLazySingleton<TranscodingService>(() => TranscodingService());
  locator.registerLazySingleton<AndroidAutoIntegrationService>(() => AndroidAutoIntegrationService(
    locator<SubsonicService>(),
    locator<OfflineService>(),
  ));
}
