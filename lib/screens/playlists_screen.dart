import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import 'playlist_screen.dart';

class PlaylistsScreen extends StatelessWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final libraryProvider = Provider.of<LibraryProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('歌单'),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.add),
            onPressed: () => _showCreatePlaylistDialog(context),
          ),
        ],
      ),
      body: libraryProvider.playlists.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.music_note_list,
                    size: 64,
                    color: AppTheme.lightSecondaryText,
                  ),
                  const SizedBox(height: 16),
                  Text('没有歌单', style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Text(
                    '创建一个歌单开始使用',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.lightSecondaryText,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showCreatePlaylistDialog(context),
                    icon: const Icon(CupertinoIcons.add),
                    label: const Text('新建歌单'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.appleMusicRed,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(padding: const EdgeInsets.only(bottom: 150),
              itemCount: libraryProvider.playlists.length,
              itemBuilder: (context, index) {
                final playlist = libraryProvider.playlists[index];
                return _PlaylistTile(
                  playlist: playlist,
                  onTap: () => _openPlaylist(context, playlist),
                  onLongPress: () => _showPlaylistOptions(context, playlist),
                );
              },
            ),
    );
  }

  void _openPlaylist(BuildContext context, Playlist playlist) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlaylistScreen(
          playlistId: playlist.id,
          playlistName: playlist.name,
        ),
      ),
    );
  }

  Future<void> _showCreatePlaylistDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => _CreatePlaylistDialog(
        title: '新建歌单',
        hintText: '歌单名称',
        cancelText: '取消',
        createText: '创建',
        onCreate: (name) async {
          final libraryProvider = Provider.of<LibraryProvider>(
            context,
            listen: false,
          );
          await libraryProvider.createPlaylist(name);
        },
      ),
    );
  }

  void _showPlaylistOptions(BuildContext context, Playlist playlist) {
    final libraryProvider = Provider.of<LibraryProvider>(
      context,
      listen: false,
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(CupertinoIcons.trash, color: Colors.red),
                title: const Text('删除歌单'),
                onTap: () async {
                  Navigator.pop(context);
                  await libraryProvider.deletePlaylist(playlist.id);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaylistTile extends StatelessWidget {
  final Playlist playlist;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _PlaylistTile({required this.playlist, this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppTheme.appleMusicRed.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: playlist.coverArt != null
            ? AlbumArtwork(
                coverArt: playlist.coverArt,
                size: 56,
                borderRadius: 8,
              )
            : const Icon(
                CupertinoIcons.music_note_list,
                color: AppTheme.appleMusicRed,
                size: 28,
              ),
      ),
      title: Text(
        playlist.name,
        style: theme.textTheme.bodyLarge,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${playlist.songCount ?? 0} 首歌曲',
        style: theme.textTheme.bodySmall,
      ),
      trailing: const Icon(
        CupertinoIcons.chevron_right,
        size: 18,
        color: AppTheme.lightSecondaryText,
      ),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

class _CreatePlaylistDialog extends StatefulWidget {
  final Future<void> Function(String) onCreate;
  final String title;
  final String hintText;
  final String cancelText;
  final String createText;

  const _CreatePlaylistDialog({
    required this.onCreate,
    required this.title,
    required this.hintText,
    required this.cancelText,
    required this.createText,
  });

  @override
  State<_CreatePlaylistDialog> createState() => _CreatePlaylistDialogState();
}

class _CreatePlaylistDialogState extends State<_CreatePlaylistDialog> {
  late final TextEditingController _controller;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      title: Text(widget.title),
      content: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: TextField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: widget.hintText,
            filled: true,
            fillColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: Text(widget.cancelText),
        ),
        TextButton(
          onPressed: _submitting
              ? null
              : () async {
                  final name = _controller.text.trim();
                  if (name.isNotEmpty) {
                    setState(() {
                      _submitting = true;
                    });
                    try {
                      await widget.onCreate(name);
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    } catch (e) {
                      if (mounted) {
                        setState(() {
                          _submitting = false;
                        });
                      }
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(e.toString()),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  }
                },
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.createText),
        ),
      ],
    );
  }
}
