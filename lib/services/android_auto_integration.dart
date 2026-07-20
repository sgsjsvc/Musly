import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'subsonic_service.dart';
import 'offline_service.dart';
import '../providers/library_provider.dart';

class AndroidAutoIntegrationService {
  final SubsonicService _subsonicService;
  final OfflineService _offlineService;
  
  AndroidAutoIntegrationService(this._subsonicService, this._offlineService);

  Future<List<Map<String, String>>> getAlbumSongs(String albumId, LibraryProvider? libraryProvider) async {
    if (_offlineService.isOfflineMode && libraryProvider != null) {
      await _offlineService.initialize();
      final downloadedIds = _offlineService.getDownloadedSongIds().toSet();
      final offlineSongs = libraryProvider.cachedAllSongs
          .where((s) => s.albumId == albumId && downloadedIds.contains(s.id))
          .toList();
      if (offlineSongs.isNotEmpty) {
        return offlineSongs
            .map((song) => {
                  'id': song.id,
                  'title': song.title,
                  'artist': song.artist ?? '',
                  'album': song.album ?? '',
                  'artworkUrl': _offlineService.getLocalCoverArtPath(song.id) != null
                      ? Uri.file(_offlineService.getLocalCoverArtPath(song.id)!).toString()
                      : _subsonicService.getCoverArtUrl(song.coverArt, size: 300),
                  'duration': (song.duration ?? 0).toString(),
                })
            .toList();
      }
    }
    try {
      final songs = await _subsonicService.getAlbumSongs(albumId);
      return songs
          .map((song) => {
                'id': song.id,
                'title': song.title,
                'artist': song.artist ?? '',
                'album': song.album ?? '',
                'artworkUrl': _subsonicService.getCoverArtUrl(song.coverArt, size: 300),
                'duration': (song.duration ?? 0).toString(),
              })
          .toList();
    } catch (e) {
      debugPrint('Error getting album songs for Android Auto: $e');
      return [];
    }
  }

  Future<List<Map<String, String>>> getArtistAlbums(String artistId, LibraryProvider? libraryProvider) async {
    if (_offlineService.isOfflineMode && libraryProvider != null) {
      await _offlineService.initialize();
      final downloadedIds = _offlineService.getDownloadedSongIds().toSet();
      final albumIdsWithDownloads = libraryProvider.cachedAllSongs
          .where((s) => s.artistId == artistId && downloadedIds.contains(s.id))
          .map((s) => s.albumId)
          .whereType<String>()
          .toSet();
      final offlineAlbums = libraryProvider.cachedAllAlbums
          .where((a) => albumIdsWithDownloads.contains(a.id))
          .toList();
      if (offlineAlbums.isNotEmpty) {
        return offlineAlbums
            .map((album) => {
                  'id': album.id,
                  'name': album.name,
                  'artist': album.artist ?? '',
                  'artworkUrl': _subsonicService.getCoverArtUrl(album.coverArt, size: 300),
                })
            .toList();
      }
    }
    try {
      final albums = await _subsonicService.getArtistAlbums(artistId);
      return albums
          .map((album) => {
                'id': album.id,
                'name': album.name,
                'artist': album.artist ?? '',
                'artworkUrl': _subsonicService.getCoverArtUrl(album.coverArt, size: 300),
              })
          .toList();
    } catch (e) {
      debugPrint('Error getting artist albums for Android Auto: $e');
      return [];
    }
  }

  Future<List<Map<String, String>>> getPlaylistSongs(String playlistId, LibraryProvider? libraryProvider) async {
    if (_offlineService.isOfflineMode && libraryProvider != null) {
      await _offlineService.initialize();
      final downloadedIds = _offlineService.getDownloadedSongIds().toSet();
      final cachedPlaylist = libraryProvider.playlists.where((p) => p.id == playlistId).firstOrNull;
      if (cachedPlaylist?.songs != null && cachedPlaylist!.songs!.isNotEmpty) {
        final offlineSongs = cachedPlaylist.songs!.where((s) => downloadedIds.contains(s.id)).toList();
        if (offlineSongs.isNotEmpty) {
          return offlineSongs
              .map((song) => {
                    'id': song.id,
                    'title': song.title,
                    'artist': song.artist ?? '',
                    'album': song.album ?? '',
                    'artworkUrl': _offlineService.getLocalCoverArtPath(song.id) != null
                        ? Uri.file(_offlineService.getLocalCoverArtPath(song.id)!).toString()
                        : _subsonicService.getCoverArtUrl(song.coverArt, size: 300),
                    'duration': (song.duration ?? 0).toString(),
                  })
              .toList();
        }
      }
    }
    try {
      final playlist = await _subsonicService.getPlaylist(playlistId);
      final songs = playlist.songs ?? [];
      return songs
          .map((song) => {
                'id': song.id,
                'title': song.title,
                'artist': song.artist ?? '',
                'album': song.album ?? '',
                'artworkUrl': _subsonicService.getCoverArtUrl(song.coverArt, size: 300),
                'duration': (song.duration ?? 0).toString(),
              })
          .toList();
    } catch (e) {
      debugPrint('Error getting playlist songs for Android Auto: $e');
      return [];
    }
  }

  Future<List<Map<String, String>>> search(String query, LibraryProvider? libraryProvider) async {
    if (_offlineService.isOfflineMode && libraryProvider != null) {
      await _offlineService.initialize();
      final downloadedIds = _offlineService.getDownloadedSongIds().toSet();
      final lowerQuery = query.toLowerCase();
      final offlineResults = libraryProvider.cachedAllSongs
          .where((s) =>
              downloadedIds.contains(s.id) &&
              (s.title.toLowerCase().contains(lowerQuery) ||
                  (s.artist?.toLowerCase().contains(lowerQuery) ?? false) ||
                  (s.album?.toLowerCase().contains(lowerQuery) ?? false)))
          .take(20)
          .toList();
      return offlineResults
          .map((song) => {
                'id': song.id,
                'title': song.title,
                'artist': song.artist ?? '',
                'album': song.album ?? '',
                'artworkUrl': _offlineService.getLocalCoverArtPath(song.id) != null
                    ? Uri.file(_offlineService.getLocalCoverArtPath(song.id)!).toString()
                    : _subsonicService.getCoverArtUrl(song.coverArt, size: 300),
                'duration': (song.duration ?? 0).toString(),
              })
          .toList();
    }
    try {
      final results = await _subsonicService.search(
        query,
        songCount: 20,
        albumCount: 0,
        artistCount: 0,
      );
      return results.songs
          .map((song) => {
                'id': song.id,
                'title': song.title,
                'artist': song.artist ?? '',
                'album': song.album ?? '',
                'artworkUrl': _subsonicService.getCoverArtUrl(song.coverArt, size: 300),
                'duration': (song.duration ?? 0).toString(),
              })
          .toList();
    } catch (e) {
      debugPrint('Android Auto search error: $e');
      return [];
    }
  }
}
