import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_screen.dart';
import 'add_modify_screen.dart';
import 'user_profile_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const AddModifyScreen(),
    const UserProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final photoUrl = user?.photoURL;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 800;

        if (isWide) {
          // ─── Desktop / Tablet: NavigationRail + Content ───
          return Scaffold(
            body: Row(
              children: [
                // Navigation Rail
                Container(
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                        color: isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade200,
                        width: 1,
                      ),
                    ),
                  ),
                  child: NavigationRail(
                    selectedIndex: _currentIndex,
                    onDestinationSelected: (index) =>
                        setState(() => _currentIndex = index),
                    extended: constraints.maxWidth >= 1100,
                    minExtendedWidth: 200,
                    backgroundColor: isDark
                        ? const Color(0xFF1C1C1E)
                        : Colors.white,
                    indicatorColor: isDark
                        ? Colors.grey.shade700
                        : Colors.grey.shade200,
                    labelType: constraints.maxWidth >= 1100
                        ? NavigationRailLabelType.none
                        : NavigationRailLabelType.all,
                    selectedLabelTextStyle: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    unselectedLabelTextStyle: GoogleFonts.inter(
                      fontWeight: FontWeight.w400,
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                    selectedIconTheme: IconThemeData(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    unselectedIconTheme: const IconThemeData(
                      color: Colors.grey,
                    ),
                    leading: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Image.asset('images/knp_logo.png',
                                height: 36),
                          ),
                          if (constraints.maxWidth >= 1100) ...[
                            const SizedBox(height: 8),
                            Text(
                              'KNP Inventory',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Divider(
                            indent: 12,
                            endIndent: 12,
                            color: isDark
                                ? Colors.grey.shade800
                                : Colors.grey.shade200,
                          ),
                        ],
                      ),
                    ),
                    destinations: [
                      const NavigationRailDestination(
                        icon: Icon(Icons.inventory_2_outlined),
                        selectedIcon: Icon(Icons.inventory_2),
                        label: Text('Inventory'),
                      ),
                      const NavigationRailDestination(
                        icon: Icon(Icons.add_circle_outline),
                        selectedIcon: Icon(Icons.add_circle),
                        label: Text('Add/Modify'),
                      ),
                      NavigationRailDestination(
                        icon: photoUrl != null
                            ? CircleAvatar(
                                radius: 14,
                                backgroundImage: NetworkImage(photoUrl),
                              )
                            : const Icon(Icons.person_outline),
                        selectedIcon: photoUrl != null
                            ? Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDark ? Colors.white : Colors.black,
                                    width: 2,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 14,
                                  backgroundImage: NetworkImage(photoUrl),
                                ),
                              )
                            : const Icon(Icons.person),
                        label: const Text('Profile'),
                      ),
                    ],
                  ),
                ),

                // Page Content
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _screens[_currentIndex],
                  ),
                ),
              ],
            ),
          );
        }

        // ─── Mobile: BottomNavigationBar ───
        return Scaffold(
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _screens[_currentIndex],
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(15),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
              items: [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.inventory_2_outlined),
                  activeIcon: Icon(Icons.inventory_2),
                  label: 'Inventory',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.add_circle_outline),
                  activeIcon: Icon(Icons.add_circle),
                  label: 'Add/Modify',
                ),
                BottomNavigationBarItem(
                  icon: photoUrl != null
                      ? CircleAvatar(
                          radius: 13,
                          backgroundImage: NetworkImage(photoUrl),
                        )
                      : const Icon(Icons.person_outline),
                  activeIcon: photoUrl != null
                      ? Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).primaryColor,
                              width: 2,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 13,
                            backgroundImage: NetworkImage(photoUrl),
                          ),
                        )
                      : const Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
