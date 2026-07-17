import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:musly/main.dart' as app;
import 'package:musly/screens/main_screen.dart';
import 'package:musly/widgets/song_tile.dart';
import 'package:musly/providers/player_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Musly App Comprehensive Integration Tests', () {
    setUp(() async {
      // Clear SharedPreferences to guarantee starting in unauthenticated state
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      // Pre-accept privacy policy so the dialog never appears during the test
      await prefs.setBool('privacy_policy_accepted', true);
    });

    testWidgets('Login, play a song, and search for that song', (tester) async {
      // 1. Start the application
      app.main();
      
      // Pump initial frame and wait for any asynchronous initializations
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // 2. Verify that we are on the login screen
      expect(find.text('Musly'), findsWidgets);
      expect(find.text('连接到您的 Subsonic 服务器'), findsOneWidget);

      // Find fields
      final serverField = find.ancestor(
        of: find.text('服务器地址'),
        matching: find.byType(TextFormField),
      );
      final usernameField = find.ancestor(
        of: find.text('用户名'),
        matching: find.byType(TextFormField),
      );
      final passwordField = find.ancestor(
        of: find.text('密码'),
        matching: find.byType(TextFormField),
      );
      final connectButton = find.text('连接');

      expect(serverField, findsOneWidget);
      expect(usernameField, findsOneWidget);
      expect(passwordField, findsOneWidget);
      expect(connectButton, findsOneWidget);

      // 3. Enter credentials provided by user
      await tester.ensureVisible(serverField);
      await tester.enterText(serverField, 'https://nd.anlinlove.cn');
      await tester.pumpAndSettle();

      await tester.ensureVisible(usernameField);
      await tester.enterText(usernameField, 'anlin');
      await tester.pumpAndSettle();

      await tester.ensureVisible(passwordField);
      await tester.enterText(passwordField, '962464@zap');
      await tester.pumpAndSettle();

      // 4. Click the connect button
      await tester.ensureVisible(connectButton);
      await tester.tap(connectButton);
      
      // Wait for authentication and screen transition
      print('Waiting for login and transition to MainScreen...');
      bool loggedIn = false;
      for (int i = 0; i < 15; i++) {
        await tester.pump(const Duration(seconds: 1));
        if (find.byType(MainScreen).evaluate().isNotEmpty) {
          loggedIn = true;
          break;
        }
      }
      expect(loggedIn, true);
      expect(find.byType(MainScreen), findsOneWidget);
      print('Successfully logged in and reached MainScreen!');

      // 5. Wait for home screen songs to load
      print('Waiting for home screen songs to load...');
      bool homeSongsLoaded = false;
      for (int i = 0; i < 15; i++) {
        await tester.pump(const Duration(seconds: 1));
        if (find.byType(SongTile).evaluate().isNotEmpty) {
          homeSongsLoaded = true;
          break;
        }
      }
      expect(homeSongsLoaded, true);
      print('Home screen songs loaded!');

      // 6. Play the first song on the Home screen
      final homeSongTiles = find.byType(SongTile);
      final firstSongTile = homeSongTiles.first;
      final songWidget = tester.widget<SongTile>(firstSongTile);
      final songTitle = songWidget.song.title;
      print('Tapping on the first song: "$songTitle" to start playback...');

      await tester.ensureVisible(firstSongTile);
      await tester.tap(firstSongTile);
      
      // Wait for audio player initialization & network streaming to start
      await tester.pump(const Duration(seconds: 3));

      // Verify playback state via Provider
      final playerProvider = Provider.of<PlayerProvider>(
        tester.element(find.byType(MainScreen)),
        listen: false,
      );
      
      expect(playerProvider.currentSong, isNotNull);
      expect(playerProvider.currentSong!.title, songTitle);
      expect(playerProvider.isPlaying, true);
      print('Playback started successfully for: "${playerProvider.currentSong?.title}"!');

      // Verify mini-player displays the song title
      expect(find.text(songTitle), findsWidgets);

      // 7. Switch to Search tab
      final searchTab = find.text('搜索');
      expect(searchTab, findsOneWidget);
      await tester.tap(searchTab);
      await tester.pump(const Duration(seconds: 1));

      // 8. Locate search text field and perform search using the song title
      final searchField = find.byType(CupertinoSearchTextField);
      expect(searchField, findsOneWidget);

      print('Searching for song with query: "$songTitle"...');
      await tester.enterText(searchField, songTitle);
      // Wait for debounce timer (300ms) + network request
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 3));

      // Verify that search results are displayed and contain the searched song
      final searchSongTiles = find.byType(SongTile);
      expect(searchSongTiles, findsWidgets);
      
      bool foundMatchingSong = false;
      for (final element in searchSongTiles.evaluate()) {
        final widget = element.widget as SongTile;
        if (widget.song.title == songTitle) {
          foundMatchingSong = true;
          break;
        }
      }
      expect(foundMatchingSong, true);
      print('Search succeeded! Found song: "$songTitle" in search results list.');
      print('All comprehensive integration tests passed successfully!');
    });
  });
}
