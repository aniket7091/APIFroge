import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../screens/collections_screen.dart';
import '../screens/history_screen.dart';
import '../screens/settings_screen.dart';

/// Side navigation drawer with links to main app sections.
class SidebarDrawer extends StatelessWidget {
  const SidebarDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final themeProvider = context.watch<AppThemeProvider>();
    final cs = Theme.of(context).colorScheme;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cs.primary, cs.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const ImageIcon(
                      AssetImage("assets/logo/logoApp_rm.png"),
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('APIForge',
                            style: GoogleFonts.abhayaLibre(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 28)),
                        Text(
                          auth.user?.name ?? '',
                          style: GoogleFonts.poppins(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _DrawerItem(
                    icon: CupertinoIcons.home,
                    title: 'Request Builder',
                    onTap: () => Navigator.pop(context),
                  ),
                  _DrawerItem(
                    icon: CupertinoIcons.folder,
                    title: 'Collections',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const CollectionsScreen()));
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.history_outlined,
                    title: 'History',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const HistoryScreen()));
                    },
                  ),
                  _DrawerItem(
                    icon: CupertinoIcons.settings,
                    title: 'Environment & Settings',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SettingsScreen()));
                    },
                  ),
                  const Divider(),
                  // Theme mode selector
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 8),
                          child: Text('Theme',
                              style: Theme.of(context).textTheme.labelMedium),
                        ),
                        SegmentedButton<ThemeMode>(
                          showSelectedIcon: false,
                          segments:  [
                            ButtonSegment(
                              value: ThemeMode.light,
                              icon: const Icon(CupertinoIcons.sun_max_fill, size: 16),
                              label: Text('Light',style: GoogleFonts.abhayaLibre()),
                            ),
                            ButtonSegment(
                              value: ThemeMode.system,
                              icon: const Icon(Icons.brightness_auto_outlined,
                                  size: 16),
                              label: Text('System',style: GoogleFonts.abhayaLibre(),),
                            ),
                            ButtonSegment(
                              value: ThemeMode.dark,
                              icon: const Icon(CupertinoIcons.moon_fill, size: 16),
                              label: Text('Dark',style: GoogleFonts.abhayaLibre()),
                            ),
                          ],
                          selected: {themeProvider.themeMode},
                          onSelectionChanged: (modes) =>
                              themeProvider.setThemeMode(modes.first),
                          style: SegmentedButton.styleFrom(
                            textStyle: const TextStyle(fontSize: 12),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Logout
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout_outlined, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                await context.read<AuthService>().logout();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _DrawerItem(
      {required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }
}
