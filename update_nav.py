import re

def update_main_screen():
    path = 'd:/AnLin/Desktop/Musly/lib/screens/main_screen.dart'
    with open(path, 'r', encoding='utf-8') as f:
        c = f.read()

    # We need to replace from _buildGlassBottomNav to the end of the class, just before _VersionBadge
    match = re.search(r'  Widget _buildGlassBottomNav\(BuildContext context, bool hasCurrentSong\) \{', c)
    if not match:
        print("Could not find _buildGlassBottomNav")
        return

    start_idx = match.start()
    end_match = re.search(r'class _VersionBadge', c)
    end_idx = end_match.start()

    new_methods = '''  Widget _buildGlassBottomNav(BuildContext context, bool hasCurrentSong) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final l10n = AppLocalizations.of(context)!;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 4, 12, safeBottom > 0 ? safeBottom : 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 28,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.white.withValues(alpha: 0.8),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  _buildNavItem(context, 0, CupertinoIcons.music_house, CupertinoIcons.music_house_fill, l10n.home),
                  if (isLandscape)
                    Expanded(
                      flex: 3,
                      child: hasCurrentSong ? MiniPlayer(onTap: _openNowPlaying, isEmbedded: true) : const SizedBox.shrink(),
                    ),
                  _buildNavItem(context, 1, CupertinoIcons.collections, CupertinoIcons.collections_solid, l10n.library),
                  if (!isLandscape)
                    _buildNavItem(context, 2, CupertinoIcons.search, CupertinoIcons.search, l10n.search),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context, bool hasCurrentSong) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final l10n = AppLocalizations.of(context)!;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Container(
      padding: EdgeInsets.only(bottom: safeBottom),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA),
            width: 0.5,
          ),
        ),
      ),
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            _buildNavItem(context, 0, CupertinoIcons.music_house, CupertinoIcons.music_house_fill, l10n.home),
            if (isLandscape)
              Expanded(
                flex: 3,
                child: hasCurrentSong ? MiniPlayer(onTap: _openNowPlaying, isEmbedded: true) : const SizedBox.shrink(),
              ),
            _buildNavItem(context, 1, CupertinoIcons.collections, CupertinoIcons.collections_solid, l10n.library),
            if (!isLandscape)
              _buildNavItem(context, 2, CupertinoIcons.search, CupertinoIcons.search, l10n.search),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index, IconData icon, IconData activeIcon, String label) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = theme.colorScheme.primary;
    final isSelected = _currentIndex == index;

    return Expanded(
      flex: 1,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          final navigatorState = NavigationHelper.mobileNavigatorKey.currentState;
          navigatorState?.popUntil((route) => route.isFirst);
          
          if (index == 2) {
            final now = DateTime.now();
            if (now.difference(_lastSearchTap).inSeconds > 3) {
              _searchTapCount = 0;
            }
            _searchTapCount++;
            _lastSearchTap = now;
            if (_searchTapCount >= 11) {
              _searchTapCount = 0;
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FantasyScreen()),
              );
              return;
            }
          } else {
            _searchTapCount = 0;
          }
          
          setState(() => _currentIndex = index);
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected
                  ? accent
                  : (isDark ? Colors.white54 : Colors.black54),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? accent
                    : (isDark ? Colors.white54 : Colors.black54),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

'''

    c = c[:start_idx] + new_methods + c[end_idx:]

    with open(path, 'w', encoding='utf-8') as f:
        f.write(c)
    print("Done")

update_main_screen()
