import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:inventory_manager_flutter/services/database_service.dart';
import 'package:inventory_manager_flutter/views/dashboard_view.dart';
import 'package:inventory_manager_flutter/views/workstations_view.dart';
import 'package:inventory_manager_flutter/views/peripherals_view.dart';
import 'package:inventory_manager_flutter/views/personnel_view.dart';
import 'package:inventory_manager_flutter/views/tags_view.dart';
import 'package:inventory_manager_flutter/views/scanner_view.dart';
import 'package:inventory_manager_flutter/views/logs_view.dart';
import 'package:inventory_manager_flutter/views/settings_view.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, dynamic>> _navItems = [
    {
      'title': 'Dashboard',
      'icon': Icons.grid_view_rounded,
      'view': const DashboardView()
    },
    {
      'title': 'Workstations',
      'icon': Icons.computer_rounded,
      'view': const WorkstationsView()
    },
    {
      'title': 'Peripherals',
      'icon': Icons.mouse_rounded,
      'view': const PeripheralsView()
    },
    {
      'title': 'Personnel',
      'icon': Icons.people_alt_rounded,
      'view': const PersonnelView()
    },
    {
      'title': 'Tag Generator',
      'icon': Icons.qr_code_rounded,
      'view': const TagsView()
    },
    {
      'title': 'QR Scanner',
      'icon': Icons.qr_code_scanner_rounded,
      'view': const ScannerView()
    },
    {
      'title': 'Activity Logs',
      'icon': Icons.list_alt_rounded,
      'view': const LogsView()
    },
    {
      'title': 'Settings',
      'icon': Icons.settings_rounded,
      'view': const SettingsView()
    },
  ];

  void _onSearchChanged(String query) {
    if (_currentIndex != 1 && _currentIndex != 2 && _currentIndex != 3) {
      setState(() {
        _currentIndex = 1;
      });
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= 850;

    Widget currentView = _navItems[_currentIndex]['view'] as Widget;

    // Direct search query injection
    if (currentView is WorkstationsView) {
      currentView = WorkstationsView(searchQuery: _searchController.text);
    } else if (currentView is PeripheralsView) {
      currentView = PeripheralsView(searchQuery: _searchController.text);
    } else if (currentView is PersonnelView) {
      currentView = PersonnelView(searchQuery: _searchController.text);
    }

    return Scaffold(
      appBar: !isDesktop
          ? AppBar(
              backgroundColor: const Color(0xFF111827),
              elevation: 0,
              title: Row(
                children: [
                  const Icon(Icons.hexagon_rounded, color: Color(0xFF6366F1)),
                  const SizedBox(width: 8),
                  Text(
                    'AssetFlow',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontSize: 18),
                  ),
                ],
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(60),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: const InputDecoration(
                        hintText: 'Search assets, serials, personnel...',
                        prefixIcon: Icon(Icons.search, size: 18),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
              ),
            )
          : null,
      drawer: !isDesktop
          ? Drawer(
              backgroundColor: const Color(0xFF111827),
              child: Column(
                children: [
                  DrawerHeader(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.hexagon_rounded,
                            color: Color(0xFF6366F1), size: 36),
                        const SizedBox(width: 12),
                        Text(
                          'AssetFlow',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontSize: 24),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _navItems.length,
                      itemBuilder: (context, index) {
                        final item = _navItems[index];
                        final isSelected = _currentIndex == index;
                        return ListTile(
                          leading: Icon(
                            item['icon'] as IconData,
                            color: isSelected
                                ? const Color(0xFF6366F1)
                                : const Color(0xFF9CA3AF),
                          ),
                          title: Text(
                            item['title'] as String,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF9CA3AF),
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                          selected: isSelected,
                          selectedTileColor: Colors.white.withOpacity(0.05),
                          onTap: () {
                            setState(() {
                              _currentIndex = index;
                            });
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            )
          : null,
      body: Row(
        children: [
          if (isDesktop)
            // Desktop Sidebar Navigation
            Container(
              width: 260,
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                border: Border(
                  right: BorderSide(
                      color: Colors.white.withOpacity(0.08), width: 1),
                ),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 32.0, horizontal: 24.0),
                    child: Row(
                      children: [
                        const Icon(Icons.hexagon_rounded,
                            color: Color(0xFF6366F1), size: 32),
                        const SizedBox(width: 12),
                        Text(
                          'AssetFlow',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontSize: 22),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      itemCount: _navItems.length,
                      itemBuilder: (context, index) {
                        final item = _navItems[index];
                        final isSelected = _currentIndex == index;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6.0),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _currentIndex = index;
                              });
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12.0, horizontal: 16.0),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF6366F1).withOpacity(0.15)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: isSelected
                                    ? Border.all(
                                        color: const Color(0xFF6366F1)
                                            .withOpacity(0.3))
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    item['icon'] as IconData,
                                    color: isSelected
                                        ? const Color(0xFF6366F1)
                                        : const Color(0xFF9CA3AF),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 16),
                                  Text(
                                    item['title'] as String,
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : const Color(0xFF9CA3AF),
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

          // Main Body Content
          Expanded(
            child: Column(
              children: [
                if (isDesktop)
                  // Top Header for Desktop
                  Container(
                    height: 80,
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                            color: Colors.white.withOpacity(0.08), width: 1),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 400,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.08)),
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: _onSearchChanged,
                            decoration: const InputDecoration(
                              hintText:
                                  'Search assets, serial numbers, personnel...',
                              prefixIcon: Icon(Icons.search, size: 20),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding:
                                  EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        // Avatar profile representation
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor:
                                  const Color(0xFF6366F1).withOpacity(0.2),
                              child: const Text(
                                'A',
                                style: TextStyle(
                                    color: Color(0xFF6366F1),
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: Consumer<InventoryProvider>(
                    builder: (context, provider, child) {
                      if (!provider.initialized) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return SafeArea(child: currentView);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: !isDesktop
          ? BottomNavigationBar(
              currentIndex: _currentIndex < 4
                  ? _currentIndex
                  : 0, // Fallback if selected item isn't in bottom nav
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              type: BottomNavigationBarType.fixed,
              backgroundColor: const Color(0xFF111827),
              selectedItemColor: const Color(0xFF6366F1),
              unselectedItemColor: const Color(0xFF9CA3AF),
              selectedFontSize: 12,
              unselectedFontSize: 12,
              items: const [
                BottomNavigationBarItem(
                    icon: Icon(Icons.grid_view_rounded), label: 'Dashboard'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.computer_rounded),
                    label: 'Computers'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.mouse_rounded),
                    label: 'Peripherals'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.people_alt_rounded), label: 'Personnel'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.qr_code_scanner_rounded), label: 'Scan'),
              ],
            )
          : null,
    );
  }
}
