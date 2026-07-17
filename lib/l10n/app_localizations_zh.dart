// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => 'Musly';

  @override
  String get emulatorDetected => '检测到模拟器';

  @override
  String get emulatorNotAllowed => '此应用无法在模拟器上运行。\\n请使用实体设备。';

  @override
  String get goodMorning => '早上好';

  @override
  String get goodAfternoon => '下午好';

  @override
  String get goodEvening => '晚上好';

  @override
  String get forYou => '为你推荐';

  @override
  String get quickPicks => '快速选择';

  @override
  String get discoverMix => '发现混音';

  @override
  String get recentlyPlayed => '最近播放';

  @override
  String get yourPlaylists => '你的歌单';

  @override
  String get favoritePlaylists => '收藏歌单';

  @override
  String get sectionAlbums => '专辑';

  @override
  String get sectionEPs => 'EP';

  @override
  String get sectionSingles => '单曲';

  @override
  String get madeForYou => '为你制作';

  @override
  String get topRated => '评分最高';

  @override
  String get noContentAvailable => '暂无内容';

  @override
  String get tryRefreshing => '请刷新或检查服务器连接';

  @override
  String get refresh => '刷新';

  @override
  String get errorLoadingSongs => '加载歌曲出错';

  @override
  String get noSongsInGenre => '该分类没有歌曲';

  @override
  String get errorLoadingAlbums => '加载专辑出错';

  @override
  String get noTopRatedAlbums => '暂无评分最高的专辑';

  @override
  String get login => '登录';

  @override
  String get serverUrl => '服务器地址';

  @override
  String get username => '用户名';

  @override
  String get password => '密码';

  @override
  String get selectCertificate => '选择 TLS/SSL 证书';

  @override
  String failedToSelectCertificate(String error) {
    return '选择证书失败：$error';
  }

  @override
  String get serverUrlMustStartWith => '服务器地址必须以 http:// 或 https:// 开头';

  @override
  String get failedToConnect => '连接失败';

  @override
  String get library => '音乐库';

  @override
  String get search => '搜索';

  @override
  String get settings => '设置';

  @override
  String get albums => '专辑';

  @override
  String get artists => '艺术家';

  @override
  String get songs => '歌曲';

  @override
  String get playlists => '歌单';

  @override
  String get genres => '分类';

  @override
  String get years => '年份';

  @override
  String get favorites => '收藏';

  @override
  String get nowPlaying => '正在播放';

  @override
  String get queue => '播放队列';

  @override
  String get lyrics => '歌词';

  @override
  String get play => '播放';

  @override
  String get pause => '暂停';

  @override
  String get next => '下一首';

  @override
  String get previous => '上一首';

  @override
  String get shuffle => '随机播放';

  @override
  String get repeat => '循环';

  @override
  String get repeatOne => '单曲循环';

  @override
  String get repeatOff => '关闭循环';

  @override
  String get addToPlaylist => '添加到歌单';

  @override
  String get removeFromPlaylist => '从歌单移除';

  @override
  String get addToFavorites => '添加到收藏';

  @override
  String get removeFromFavorites => '从收藏移除';

  @override
  String get download => '下载';

  @override
  String get delete => '删除';

  @override
  String get cancel => '取消';

  @override
  String get ok => '确定';

  @override
  String get save => '保存';

  @override
  String get close => '关闭';

  @override
  String get general => '通用';

  @override
  String get appearance => '外观';

  @override
  String get playback => '播放';

  @override
  String get storage => '存储';

  @override
  String get about => '关于';

  @override
  String get darkMode => '深色模式';

  @override
  String get language => '语言';

  @override
  String get version => '版本';

  @override
  String get madeBy => '由 dddevid 开发';

  @override
  String get githubRepository => 'GitHub 仓库';

  @override
  String get reportIssue => '报告问题';

  @override
  String get joinDiscord => '加入 Discord 社区';

  @override
  String get unknownArtist => '未知艺术家';

  @override
  String get unknownAlbum => '未知专辑';

  @override
  String get playAll => '播放全部';

  @override
  String get shuffleAll => '随机播放全部';

  @override
  String get sortBy => '排序方式';

  @override
  String get sortByName => '名称';

  @override
  String get sortByArtist => '艺术家';

  @override
  String get sortByAlbum => '专辑';

  @override
  String get sortByDate => '日期';

  @override
  String get sortByDuration => '时长';

  @override
  String get ascending => '升序';

  @override
  String get descending => '降序';

  @override
  String get noLyricsAvailable => '暂无歌词';

  @override
  String get loading => '加载中...';

  @override
  String get error => '错误';

  @override
  String get retry => '重试';

  @override
  String get noResults => '无结果';

  @override
  String get searchHint => '搜索歌曲、专辑、艺术家...';

  @override
  String get allSongs => '全部歌曲';

  @override
  String get allAlbums => '全部专辑';

  @override
  String get allArtists => '全部艺术家';

  @override
  String trackNumber(int number) {
    return '第 $number 首';
  }

  @override
  String songsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 首歌曲',
      one: '1 首歌曲',
      zero: '无歌曲',
    );
    return '$_temp0';
  }

  @override
  String albumsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 张专辑',
      one: '1 张专辑',
      zero: '无专辑',
    );
    return '$_temp0';
  }

  @override
  String get logout => '退出登录';

  @override
  String get confirmLogout => '确定要退出登录吗？';

  @override
  String get yes => '是';

  @override
  String get no => '否';

  @override
  String get offlineMode => '离线模式';

  @override
  String get radio => '电台';

  @override
  String get changelog => '更新日志';

  @override
  String get platform => '平台';

  @override
  String get server => '服务器';

  @override
  String get display => '显示';

  @override
  String get playerInterface => '播放器界面';

  @override
  String get smartRecommendations => '智能推荐';

  @override
  String get showVolumeSlider => '显示音量滑块';

  @override
  String get showVolumeSliderSubtitle => '在正在播放界面显示音量控制';

  @override
  String get showStarRatings => '显示星级评分';

  @override
  String get showStarRatingsSubtitle => '为歌曲评分并查看评分';

  @override
  String get showMiniPlayerHeart => '显示收藏按钮';

  @override
  String get showMiniPlayerHeartSubtitle => '在迷你播放器中添加收藏';

  @override
  String get showMiniPlayerRepeat => '显示循环按钮';

  @override
  String get showMiniPlayerRepeatSubtitle => '在迷你播放器中切换循环模式';

  @override
  String get showMiniPlayerShuffle => '显示随机按钮';

  @override
  String get showMiniPlayerShuffleSubtitle => '在迷你播放器中切换随机播放';

  @override
  String get enableRecommendations => '启用推荐';

  @override
  String get enableRecommendationsSubtitle => '获取个性化音乐推荐';

  @override
  String get listeningData => '收听数据';

  @override
  String totalPlays(int count) {
    return '共播放 $count 次';
  }

  @override
  String get clearListeningHistory => '清除收听历史';

  @override
  String get confirmClearHistory => '这将重置您的所有收听数据和推荐。确定吗？';

  @override
  String get historyCleared => '收听历史已清除';

  @override
  String get discordStatus => 'Discord 状态';

  @override
  String get discordStatusSubtitle => '在 Discord 个人资料上显示正在播放的歌曲';

  @override
  String get selectLanguage => '选择语言';

  @override
  String get systemDefault => '跟随系统';

  @override
  String get communityTranslations => '社区翻译';

  @override
  String get communityTranslationsSubtitle => '在 Crowdin 上帮助翻译 Musly';

  @override
  String get yourLibrary => '你的音乐库';

  @override
  String get filterAll => '全部';

  @override
  String get faves => '收藏';

  @override
  String get filterPlaylists => '歌单';

  @override
  String get filterAlbums => '专辑';

  @override
  String get filterArtists => '艺术家';

  @override
  String get likedSongs => '喜欢的歌曲';

  @override
  String get likedAlbums => '喜欢的专辑';

  @override
  String get noLikedAlbums => '还没有喜欢的专辑';

  @override
  String get localMusicLibrary => '本地音乐库';

  @override
  String get mergeLocalLibrary => '与服务器库合并';

  @override
  String get mergeLocalLibrarySubtitle => '将本地音乐与服务器音乐库一起显示';

  @override
  String get localMusicStats => '本地音乐文件';

  @override
  String get addMusicFolder => '添加音乐文件夹';

  @override
  String get rescanLocalMusic => '重新扫描本地音乐';

  @override
  String get localLibraryEmpty => '您的音乐库为空';

  @override
  String get localLibraryEmptySubtitle => '未找到本地音乐文件。点击下方按钮重新扫描。';

  @override
  String get libraryEmpty => '您的音乐库为空';

  @override
  String get libraryEmptySubtitle => '添加一些歌曲开始使用吧。';

  @override
  String get scanForMusic => '扫描音乐';

  @override
  String get radioStations => '电台';

  @override
  String get playlist => '歌单';

  @override
  String get internetRadio => '网络电台';

  @override
  String get newPlaylist => '新建歌单';

  @override
  String get playlistName => '歌单名称';

  @override
  String get create => '创建';

  @override
  String get deletePlaylist => '删除歌单';

  @override
  String deletePlaylistConfirmation(String name) {
    return '确定要删除歌单「$name」吗？';
  }

  @override
  String playlistDeleted(String name) {
    return '歌单「$name」已删除';
  }

  @override
  String errorCreatingPlaylist(Object error) {
    return '创建歌单出错：$error';
  }

  @override
  String errorDeletingPlaylist(Object error) {
    return '删除歌单出错：$error';
  }

  @override
  String playlistCreated(String name) {
    return '歌单「$name」已创建';
  }

  @override
  String get searchTitle => '搜索';

  @override
  String get searchPlaceholder => '艺术家、歌曲、专辑';

  @override
  String get tryDifferentSearch => '尝试不同的搜索';

  @override
  String get noSuggestions => '无建议';

  @override
  String get browseCategories => '浏览分类';

  @override
  String get liveSearchSection => '搜索';

  @override
  String get liveSearch => '实时搜索';

  @override
  String get liveSearchSubtitle => '输入时实时更新结果，而不是显示下拉菜单';

  @override
  String get categoryMadeForYou => '为你制作';

  @override
  String get categoryNewReleases => '新歌首发';

  @override
  String get categoryTopRated => '评分最高';

  @override
  String get categoryGenres => '分类';

  @override
  String get categoryFavorites => '收藏';

  @override
  String get categoryRadio => '电台';

  @override
  String get settingsTitle => '设置';

  @override
  String get tabPlayback => '播放';

  @override
  String get tabStorage => '存储';

  @override
  String get tabServer => '服务器';

  @override
  String get tabDisplay => '显示';

  @override
  String get tabSupport => '支持';

  @override
  String get tabAbout => '关于';

  @override
  String get sectionAutoDj => '自动播放';

  @override
  String get autoDjMode => '自动播放模式';

  @override
  String songsToAdd(int count) {
    return '添加歌曲数：$count';
  }

  @override
  String get sectionReplayGain => '音量标准化 (REPLAYGAIN)';

  @override
  String get replayGainMode => '模式';

  @override
  String preamp(String value) {
    return '前置增益：$value dB';
  }

  @override
  String get preventClipping => '防止削波';

  @override
  String fallbackGain(String value) {
    return '备用增益：$value dB';
  }

  @override
  String get sectionStreamingQuality => '流媒体质量';

  @override
  String get enableTranscoding => '启用转码';

  @override
  String get qualityWifi => 'WiFi 质量';

  @override
  String get qualityMobile => '移动网络质量';

  @override
  String get format => '格式';

  @override
  String get transcodingSubtitle => '降低质量以减少数据使用';

  @override
  String get modeOff => '关闭';

  @override
  String get modeTrack => '单曲';

  @override
  String get modeAlbum => '专辑';

  @override
  String get sectionServerConnection => '服务器连接';

  @override
  String get serverType => '服务器类型';

  @override
  String get notConnected => '未连接';

  @override
  String get unknown => '未知';

  @override
  String get sectionMusicFolders => '音乐文件夹';

  @override
  String get musicFolders => '音乐文件夹';

  @override
  String get noMusicFolders => '未找到音乐文件夹';

  @override
  String get sectionSavedProfiles => '已保存的配置';

  @override
  String get switchProfile => '切换配置';

  @override
  String get switchServer => '切换服务器';

  @override
  String get addProfile => '添加配置';

  @override
  String switchProfileConfirmation(String profile) {
    return '连接到「$profile」？';
  }

  @override
  String get sectionAccount => '账户';

  @override
  String get logoutConfirmation => '确定要退出登录吗？这也将清除所有缓存数据。';

  @override
  String get sectionCacheSettings => '缓存设置';

  @override
  String get imageCache => '图片缓存';

  @override
  String get musicCache => '音乐缓存';

  @override
  String get bpmCache => 'BPM 缓存';

  @override
  String get saveAlbumCovers => '本地保存专辑封面';

  @override
  String get saveSongMetadata => '本地保存歌曲元数据';

  @override
  String get saveBpmAnalysis => '本地保存 BPM 分析';

  @override
  String get sectionCacheCleanup => '缓存清理';

  @override
  String get clearAllCache => '清除所有缓存';

  @override
  String get allCacheCleared => '所有缓存已清除';

  @override
  String get sectionOfflineDownloads => '离线下载';

  @override
  String get downloadedSongs => '已下载歌曲';

  @override
  String downloadingLibrary(int progress, int total) {
    return '正在下载音乐库... $progress/$total';
  }

  @override
  String get downloadAllLibrary => '下载全部音乐库';

  @override
  String downloadLibraryConfirm(int count) {
    return '这将下载 $count 首歌曲到您的设备。这可能需要一段时间并占用大量存储空间。\n\n是否继续？';
  }

  @override
  String get keepScreenOnDuringDownload => '保持屏幕常亮';

  @override
  String get keepScreenOnDuringDownloadSubtitle => '防止设备锁屏时下载失败';

  @override
  String get parallelDownloads => '并行下载';

  @override
  String get parallelDownloadsSubtitle => '同时下载多首歌曲';

  @override
  String get downloadSingular => '次下载';

  @override
  String get downloadPlural => '次下载';

  @override
  String get slowerButStable => '较慢但更稳定';

  @override
  String get fasterButMoreData => '较快但消耗更多流量';

  @override
  String get libraryDownloadStarted => '音乐库下载已开始';

  @override
  String get deleteDownloads => '删除所有下载';

  @override
  String get downloadsDeleted => '所有下载已删除';

  @override
  String get noSongsAvailable => '没有可用歌曲。请先加载您的音乐库。';

  @override
  String get sectionBpmAnalysis => 'BPM 分析';

  @override
  String get cachedBpms => '已缓存的 BPM';

  @override
  String get cacheAllBpms => '缓存所有 BPM';

  @override
  String get clearBpmCache => '清除 BPM 缓存';

  @override
  String get bpmCacheCleared => 'BPM 缓存已清除';

  @override
  String downloadedStats(int count, String size) {
    return '$count 首歌曲 • $size';
  }

  @override
  String get sectionInformation => '信息';

  @override
  String get sectionDeveloper => '开发者';

  @override
  String get sectionLinks => '链接';

  @override
  String get githubRepo => 'GitHub 仓库';

  @override
  String get playingFrom => '正在播放来自';

  @override
  String get live => '直播';

  @override
  String get streamingLive => '正在直播';

  @override
  String get stopRadio => '停止电台';

  @override
  String get removeFromLiked => '从喜欢的歌曲中移除';

  @override
  String get addToLiked => '添加到喜欢的歌曲';

  @override
  String get playNext => '下一首播放';

  @override
  String get addToQueue => '添加到队列';

  @override
  String get goToAlbum => '前往专辑';

  @override
  String get goToArtist => '前往艺术家';

  @override
  String get rateSong => '为歌曲评分';

  @override
  String rateSongValue(int rating, String stars) {
    return '为歌曲评分（$rating $stars）';
  }

  @override
  String get ratingRemoved => '评分已移除';

  @override
  String rated(int rating, String stars) {
    return '已评分 $rating $stars';
  }

  @override
  String get removeRating => '移除评分';

  @override
  String get downloaded => '已下载';

  @override
  String downloading(int percent) {
    return '正在下载... $percent%';
  }

  @override
  String get removeDownload => '移除下载';

  @override
  String get removeDownloadConfirm => '从离线存储中移除这首歌曲？';

  @override
  String get downloadRemoved => '下载已移除';

  @override
  String downloadedTitle(String title) {
    return '已下载「$title」';
  }

  @override
  String get downloadFailed => '下载失败';

  @override
  String downloadError(Object error) {
    return '下载错误：$error';
  }

  @override
  String addedToPlaylist(String title, String playlist) {
    return '已将「$title」添加到 $playlist';
  }

  @override
  String errorAddingToPlaylist(Object error) {
    return '添加到歌单出错：$error';
  }

  @override
  String get noPlaylists => '没有可用的歌单';

  @override
  String get createNewPlaylist => '创建新歌单';

  @override
  String artistNotFound(String name) {
    return '未找到艺术家「$name」';
  }

  @override
  String errorSearchingArtist(Object error) {
    return '搜索艺术家出错：$error';
  }

  @override
  String get selectArtist => '选择艺术家';

  @override
  String get removedFromFavorites => '已从收藏中移除';

  @override
  String get addedToFavorites => '已添加到收藏';

  @override
  String get star => '星';

  @override
  String get stars => '星';

  @override
  String get albumNotFound => '未找到专辑';

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '$hours 小时 $minutes 分钟';
  }

  @override
  String durationMinutes(int minutes) {
    return '$minutes 分钟';
  }

  @override
  String get topSongs => '热门歌曲';

  @override
  String get connected => '已连接';

  @override
  String get noSongPlaying => '当前无歌曲播放';

  @override
  String get internetRadioUppercase => '网络电台';

  @override
  String get playingNext => '即将播放';

  @override
  String get createPlaylistTitle => '创建歌单';

  @override
  String get playlistNameHint => '歌单名称';

  @override
  String playlistCreatedWithSong(String name) {
    return '已创建歌单「$name」并添加了这首歌曲';
  }

  @override
  String errorLoadingPlaylists(Object error) {
    return '加载歌单出错：$error';
  }

  @override
  String get playlistNotFound => '未找到歌单';

  @override
  String get noSongsInPlaylist => '该歌单中没有歌曲';

  @override
  String get noFavoriteSongsYet => '还没有喜欢的歌曲';

  @override
  String get noFavoriteAlbumsYet => '还没有喜欢的专辑';

  @override
  String get listeningHistory => '收听历史';

  @override
  String get noListeningHistory => '没有收听历史';

  @override
  String get songsWillAppearHere => '您播放的歌曲将显示在这里';

  @override
  String get sortByTitleAZ => '标题 (A-Z)';

  @override
  String get sortByTitleZA => '标题 (Z-A)';

  @override
  String get sortByArtistAZ => '艺术家 (A-Z)';

  @override
  String get sortByArtistZA => '艺术家 (Z-A)';

  @override
  String get sortByAlbumAZ => '专辑 (A-Z)';

  @override
  String get sortByAlbumZA => '专辑 (Z-A)';

  @override
  String get recentlyAdded => '最近添加';

  @override
  String get noSongsFound => '未找到歌曲';

  @override
  String get noAlbumsFound => '未找到专辑';

  @override
  String get noHomepageUrl => '没有可用的首页链接';

  @override
  String get playStation => '播放电台';

  @override
  String get openHomepage => '打开首页';

  @override
  String get copyStreamUrl => '复制流地址';

  @override
  String get failedToLoadRadioStations => '加载电台失败';

  @override
  String get noRadioStations => '没有电台';

  @override
  String get noRadioStationsHint => '在您的 Navidrome 服务器设置中添加电台以在此处查看。';

  @override
  String get connectToServerSubtitle => '连接到您的 Subsonic 服务器';

  @override
  String get pleaseEnterServerUrl => '请输入服务器地址';

  @override
  String get invalidUrlFormat => 'URL 必须以 http:// 或 https:// 开头';

  @override
  String get pleaseEnterUsername => '请输入用户名';

  @override
  String get pleaseEnterPassword => '请输入密码';

  @override
  String get legacyAuthentication => '旧版认证';

  @override
  String get legacyAuthSubtitle => '用于较旧的 Subsonic 服务器';

  @override
  String get allowSelfSignedCerts => '允许自签名证书';

  @override
  String get allowSelfSignedSubtitle => '用于具有自定义 TLS/SSL 证书的服务器';

  @override
  String get advancedOptions => '高级选项';

  @override
  String get customTlsCertificate => '自定义 TLS/SSL 证书';

  @override
  String get customCertificateSubtitle => '为使用非标准 CA 的服务器上传自定义证书';

  @override
  String get selectCertificateFile => '选择证书文件';

  @override
  String get clientCertificate => '客户端证书 (mTLS)';

  @override
  String get clientCertificateSubtitle => '使用证书对此客户端进行身份验证（需要支持 mTLS 的服务器）';

  @override
  String get selectClientCertificate => '选择客户端证书';

  @override
  String get clientCertPassword => '证书密码（可选）';

  @override
  String failedToSelectClientCert(String error) {
    return '选择客户端证书失败：$error';
  }

  @override
  String get connect => '连接';

  @override
  String get or => '或者';

  @override
  String get useLocalFiles => '使用本地文件';

  @override
  String get startingScan => '正在开始扫描...';

  @override
  String get storagePermissionRequired => '需要存储权限才能扫描本地文件';

  @override
  String get noMusicFilesFound => '在您的设备上未找到音乐文件';

  @override
  String get remove => '移除';

  @override
  String failedToSetRating(Object error) {
    return '设置评分失败：$error';
  }

  @override
  String get home => '首页';

  @override
  String get playlistsSection => '歌单';

  @override
  String get collapse => '收起';

  @override
  String get expand => '展开';

  @override
  String get createPlaylist => '创建歌单';

  @override
  String get likedSongsSidebar => '喜欢的歌曲';

  @override
  String playlistSongsCount(int count) {
    return '歌单 • $count 首歌曲';
  }

  @override
  String get failedToLoadLyrics => '加载歌词失败';

  @override
  String get lyricsNotFoundSubtitle => '无法找到这首歌曲的歌词';

  @override
  String get backToCurrent => '返回当前';

  @override
  String get exitFullscreen => '退出全屏';

  @override
  String get fullscreen => '全屏';

  @override
  String get noLyrics => '无歌词';

  @override
  String get internetRadioMiniPlayer => '网络电台';

  @override
  String get liveBadge => '直播';

  @override
  String get localFilesModeBanner => '本地文件模式';

  @override
  String get offlineModeBanner => '离线模式 - 仅播放已下载的音乐';

  @override
  String get updateAvailable => '有可用更新';

  @override
  String get updateAvailableSubtitle => '新版本的 Musly 已可用！';

  @override
  String updateCurrentVersion(String version) {
    return '当前版本：v$version';
  }

  @override
  String updateLatestVersion(String version) {
    return '最新版本：v$version';
  }

  @override
  String get whatsNew => '更新内容';

  @override
  String get downloadUpdate => '下载';

  @override
  String get remindLater => '稍后提醒';

  @override
  String get seeAll => '查看全部';

  @override
  String get artistDataNotFound => '未找到艺术家';

  @override
  String get addedArtistToQueue => '已将艺术家添加到队列';

  @override
  String get addedArtistToQueueError => '将艺术家添加到队列失败';

  @override
  String get casting => '投射中';

  @override
  String get dlna => 'DLNA';

  @override
  String get castDlnaBeta => '投射 / DLNA（测试版）';

  @override
  String get chromecast => 'Chromecast';

  @override
  String get dlnaUpnp => 'DLNA / UPnP';

  @override
  String get disconnect => '断开连接';

  @override
  String get searchingDevices => '正在搜索设备';

  @override
  String get castWifiHint => '请确保您的投射/DLNA设备\n处于同一 Wi-Fi 网络上';

  @override
  String connectedToDevice(String name) {
    return '已连接到 $name';
  }

  @override
  String failedToConnectDevice(String name) {
    return '连接到 $name 失败';
  }

  @override
  String get removedFromLikedSongs => '已从喜欢的歌曲中移除';

  @override
  String get addedToLikedSongs => '已添加到喜欢的歌曲';

  @override
  String get enableShuffle => '启用随机播放';

  @override
  String get enableRepeat => '启用循环';

  @override
  String get connecting => '正在连接';

  @override
  String get closeLyrics => '关闭歌词';

  @override
  String errorStartingDownload(Object error) {
    return '开始下载出错：$error';
  }

  @override
  String get errorLoadingGenres => '加载分类出错';

  @override
  String get noGenresFound => '未找到分类';

  @override
  String get noAlbumsInGenre => '该分类中没有专辑';

  @override
  String genreTooltip(int songCount, int albumCount) {
    return '$songCount 首歌曲 • $albumCount 张专辑';
  }

  @override
  String get sectionJukebox => '点唱机模式';

  @override
  String get jukeboxMode => '点唱机模式';

  @override
  String get jukeboxModeSubtitle => '通过服务器而非本设备播放音频';

  @override
  String get openJukeboxController => '打开点唱机控制器';

  @override
  String get jukeboxClearQueue => '清空队列';

  @override
  String get jukeboxShuffleQueue => '随机排序队列';

  @override
  String get jukeboxQueueEmpty => '队列中没有歌曲';

  @override
  String get jukeboxNowPlaying => '正在播放';

  @override
  String get jukeboxQueue => '播放队列';

  @override
  String get jukeboxVolume => '音量';

  @override
  String get playOnJukebox => '在点唱机上播放';

  @override
  String get addToJukeboxQueue => '添加到点唱机队列';

  @override
  String get jukeboxNotSupported =>
      '此服务器不支持点唱机模式。请在服务器配置中启用（例如在 Navidrome 中设置 EnableJukebox = true）。';

  @override
  String get musicFoldersDialogTitle => '选择音乐文件夹';

  @override
  String get musicFoldersHint => '保持全部启用以使用所有文件夹（默认）。';

  @override
  String get musicFoldersSaved => '音乐文件夹选择已保存';

  @override
  String get artworkStyleSection => '封面样式';

  @override
  String get artworkCornerRadius => '圆角';

  @override
  String get artworkCornerRadiusSubtitle => '调整专辑封面的圆角程度';

  @override
  String get artworkCornerRadiusNone => '无';

  @override
  String get artworkShape => '形状';

  @override
  String get artworkShapeRounded => '圆角矩形';

  @override
  String get artworkShapeCircle => '圆形';

  @override
  String get artworkShapeSquare => '方形';

  @override
  String get artworkShadow => '阴影';

  @override
  String get artworkShadowNone => '无';

  @override
  String get artworkShadowSoft => '柔和';

  @override
  String get artworkShadowMedium => '中等';

  @override
  String get artworkShadowStrong => '强烈';

  @override
  String get artworkShadowColor => '阴影颜色';

  @override
  String get artworkShadowColorBlack => '黑色';

  @override
  String get artworkShadowColorAccent => '强调色';

  @override
  String get artworkPreview => '预览';

  @override
  String artworkCornerRadiusLabel(int value) {
    return '$value像素';
  }

  @override
  String get noArtwork => '无封面';

  @override
  String get serverUnreachableTitle => '无法连接服务器';

  @override
  String get serverUnreachableSubtitle => '请检查您的连接或服务器设置。';

  @override
  String get openOfflineMode => '以离线模式打开';

  @override
  String get appearanceSection => '外观';

  @override
  String get themeLabel => '主题';

  @override
  String get accentColorLabel => '强调色';

  @override
  String get circularDesignLabel => '圆形设计';

  @override
  String get circularDesignSubtitle => '浮动、圆角的 UI，带有半透明面板和玻璃模糊效果，适用于播放器和导航栏。';

  @override
  String get themeModeSystem => '跟随系统';

  @override
  String get themeModeLight => '浅色';

  @override
  String get themeModeDark => '深色';

  @override
  String get liveLabel => '直播';

  @override
  String get discordStatusText => 'Discord 状态文本';

  @override
  String get discordStatusTextSubtitle => 'Discord 活动中显示的第二行文字';

  @override
  String get discordRpcStyleArtist => '艺术家名称';

  @override
  String get discordRpcStyleSong => '歌曲标题';

  @override
  String get discordRpcStyleApp => '应用名称 (Musly)';

  @override
  String get sectionVolumeNormalization => 'VOLUME NORMALIZATION (REPLAYGAIN)';

  @override
  String get sectionFadeInOut => '淡入/淡出';

  @override
  String get fadeInOutEnable => '启用淡入/淡出';

  @override
  String get fadeInOutSubtitle => '播放或暂停时平滑淡入淡出音频';

  @override
  String fadeDuration(int duration) {
    return '淡入淡出时长：$duration毫秒';
  }

  @override
  String get replayGainModeOff => '关闭';

  @override
  String get replayGainModeTrack => '单曲';

  @override
  String get replayGainModeAlbum => '专辑';

  @override
  String replayGainPreamp(String value) {
    return '前置增益：$value dB';
  }

  @override
  String get replayGainPreventClipping => '防止削波';

  @override
  String replayGainFallbackGain(String value) {
    return '备用增益：$value dB';
  }

  @override
  String autoDjSongsToAdd(int count) {
    return '添加歌曲数：$count';
  }

  @override
  String get transcodingEnable => '启用转码';

  @override
  String get transcodingEnableSubtitle => '降低质量以减少数据使用';

  @override
  String get smartTranscoding => '智能转码';

  @override
  String get smartTranscodingSubtitle => '根据网络连接自动调整质量（WiFi 与移动数据）';

  @override
  String get smartTranscodingDetectedNetwork => '检测到的网络：';

  @override
  String smartTranscodingActiveBitrate(String bitrate) {
    return '当前码率：$bitrate';
  }

  @override
  String get transcodingWifiQuality => 'WiFi 质量';

  @override
  String get transcodingWifiQualitySubtitleSmart => 'WiFi 下自动使用';

  @override
  String get transcodingWifiQualitySubtitle => 'WiFi 下的码率';

  @override
  String get transcodingMobileQuality => '移动网络质量';

  @override
  String get transcodingMobileQualitySubtitleSmart => '在移动数据上自动使用';

  @override
  String get transcodingMobileQualitySubtitle => '移动数据下的码率';

  @override
  String get transcodingFormat => '格式';

  @override
  String get transcodingFormatSubtitle => '用于流媒体的音频编解码器';

  @override
  String get transcodingBitrateOriginal => '原始（不转码）';

  @override
  String get transcodingFormatOriginal => '原始';

  @override
  String get imageCacheTitle => '图片缓存';

  @override
  String get imageCacheSubtitle => '本地保存专辑封面';

  @override
  String get musicCacheTitle => '音乐缓存';

  @override
  String get musicCacheSubtitle => '本地保存歌曲元数据';

  @override
  String get bpmCacheTitle => 'BPM 缓存';

  @override
  String get bpmCacheSubtitle => '本地保存 BPM 分析';

  @override
  String get sectionAboutInformation => '信息';

  @override
  String get sectionAboutDeveloper => '开发者';

  @override
  String get sectionAboutLinks => '链接';

  @override
  String get aboutVersion => '版本';

  @override
  String get aboutPlatform => '平台';

  @override
  String get aboutMadeBy => '由 dddevid 开发';

  @override
  String get aboutGitHub => 'github.com/dddevid';

  @override
  String get aboutLinkGitHub => 'GitHub 仓库';

  @override
  String get aboutLinkChangelog => '更新日志';

  @override
  String get aboutLinkReportIssue => '报告问题';

  @override
  String get aboutLinkDiscord => '加入 Discord 社区';

  @override
  String get sectionAnalyticsPrivacy => '数据分析与隐私';

  @override
  String get anonymousAnalytics => '匿名分析';

  @override
  String get anonymousAnalyticsSubtitle => '通过匿名崩溃报告和使用统计帮助改进 Musly';

  @override
  String get deviceId => '设备 ID';

  @override
  String deviceIdAnonymous(String id) {
    return '匿名 ID：$id';
  }

  @override
  String get deviceIdDisabled => '启用分析以查看您的匿名设备 ID';

  @override
  String get aboutDeviceId => '关于设备 ID';

  @override
  String get aboutDeviceIdSubtitle => '这是应用生成的匿名标识符。它无法与您的个人身份关联，仅用于分析。';

  @override
  String get supportGreeting => '你好！👋';

  @override
  String get supportParagraph1 =>
      '我是 Devid，Musly 的开发者。我开发这个应用是因为我热爱音乐，相信每个人都值得拥有一个漂亮的免费音乐播放器。';

  @override
  String get supportParagraph2 =>
      'Musly 完全免费且开源。没有广告，没有订阅费。我在空闲时间开发它，因为我真心享受为像你这样的人创造有用的东西。';

  @override
  String get supportParagraph3 =>
      '但服务器、开发工具和咖啡都不是免费的 😅 如果 Musly 已经成为你日常生活的一部分，你想说「谢谢」，一笔小小的捐赠对我来说意义重大。它帮助覆盖成本并激励我添加新功能。';

  @override
  String get supportParagraph4 => '不过完全没有压力——你享受这个应用已经是最好的回报了！💙';

  @override
  String get supportDonationTitle => '通过捐赠支持';

  @override
  String get supportDonationSubtitle => '通过 Revolut - 任何金额都有帮助！';

  @override
  String get supportDiscordTitle => '加入我们的 Discord';

  @override
  String get supportDiscordSubtitle => '获取帮助、建议功能或只是聊天';

  @override
  String get supportWaysTitle => '其他支持方式';

  @override
  String get supportWayRate => '在应用商店留下评价';

  @override
  String get supportWayShare => '告诉你的朋友关于 Musly';

  @override
  String get supportWayBugs => '报告错误或建议功能';

  @override
  String get supportWayEnjoy => '享受音乐就好！🎵';

  @override
  String get supportMadeWithLove => '在意大利用 💙 制作';

  @override
  String get playbackSpeed => '播放速度';

  @override
  String get normalSpeed => '正常 (1×)';

  @override
  String get preservePitch => '保持音调';

  @override
  String get preservePitchSubtitle => '变速时保持原始音调';

  @override
  String get pitch => '音调';

  @override
  String get pitchPreserved => '音调已保持';

  @override
  String speedTooltipWithPitch(String speed, String pitch) {
    return '速度 $speed · 音调 $pitch×';
  }

  @override
  String speedTooltipPitchPreserved(String speed) {
    return '速度 $speed · 音调已保持';
  }

  @override
  String get sleepTimer => '睡眠定时器';

  @override
  String get sleepTimerActive => '睡眠定时器已激活';

  @override
  String get fadeOut => '淡出';

  @override
  String fadeOutSubtitle(int seconds) {
    return '在最后 $seconds 秒逐渐降低音量';
  }

  @override
  String get finishCurrentSong => '播放完当前歌曲';

  @override
  String get finishCurrentSongSubtitle => '当前曲目结束后停止';

  @override
  String sleepTimerMinutes(int count) {
    return '$count 分钟';
  }

  @override
  String sleepTimerHours(int count) {
    return '$count 小时';
  }

  @override
  String sleepTimerSetFor(String duration) {
    return '睡眠定时器已设置为 $duration';
  }

  @override
  String get customDuration => '自定义时长…';

  @override
  String get cancelTimer => '取消定时器';

  @override
  String get customSleepTimer => '自定义睡眠定时器';

  @override
  String get set => '设置';

  @override
  String get addToPlaylistTitle => '添加到歌单';

  @override
  String get yourPlaylistsLabel => '你的歌单';

  @override
  String get enableLrcLibFallback => '从 LRCLIB 获取歌词';

  @override
  String get lrcLibFallbackSubtitle => '当服务器未提供歌词时自动从 LRCLIB 搜索';

  @override
  String get themeSaved => '主题已保存';

  @override
  String get themeUnsavedChanges => '未保存的更改';

  @override
  String get themeUnsavedChangesTitle => '未保存的更改';

  @override
  String get themeUnsavedChangesBody => '您有未保存的更改。是否在离开前保存？';

  @override
  String get discard => '丢弃';

  @override
  String get done => '完成';

  @override
  String pickColor(String label) {
    return '选择$label';
  }

  @override
  String get titleStyle => '标题样式';

  @override
  String get artistStyle => '艺术家样式';

  @override
  String get themeActive => '使用中';

  @override
  String get themeSafeMode => '安全模式';

  @override
  String get themeCodeMode => '代码模式';

  @override
  String get themeAnimBadge => '动画';

  @override
  String themeAuthor(String author) {
    return '作者 $author';
  }

  @override
  String get exitApp => '退出应用';
}
