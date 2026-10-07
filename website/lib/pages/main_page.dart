import 'package:flutter/material.dart';
import 'package:website/pages/bidashboard.dart';
import 'package:website/pages/crowdsource.dart';
import 'package:website/pages/knowledgegraph.dart';
import 'package:website/pages/vlmidentification.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  // Use late initialization or getter methods instead of creating instances directly
  late final List<Widget> _pages;

  // Navigation items data
  final List<NavigationItem> _navItems = const [
    NavigationItem(
      title: 'Crowdsource',
      label: 'Collect',
      icon: Icons.add_location_alt_outlined,
      index: 0,
    ),
    NavigationItem(
      title: 'Knowledge Graph',
      label: 'Graph',
      icon: Icons.hub_outlined,
      index: 1,
    ),
    NavigationItem(
      title: 'VLM Identification',
      label: 'Identify',
      icon: Icons.image_search_outlined,
      index: 2,
    ),
    NavigationItem(
      title: 'BI Dashboard',
      label: 'Insights',
      icon: Icons.insights_outlined,
      index: 3,
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Initialize pages in initState to ensure proper context
    _pages = [
      const Crowdsource(),
      const Knowledgegraph(),
      const Vlmidentification(),
      const Bidashboard(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 800;
          return Scaffold(
            backgroundColor: const Color(0xFFF5F2E9),
            appBar: isMobile
                ? AppBar(
                    toolbarHeight: 56,
                    backgroundColor: const Color(0xFFF5F2E9),
                    foregroundColor: const Color(0xFF24473C),
                    elevation: 0,
                    title: Text(
                      _navItems[_selectedIndex].title,
                      style: const TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                : null,
            body: Column(
              children: [
                if (!isMobile)
                  SafeArea(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F2E9),
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.green.shade100,
                            width: 1,
                          ),
                        ),
                      ),
                      child: LayoutBuilder(
                        builder: (context, headerConstraints) {
                          final isSmallScreen =
                              headerConstraints.maxWidth < 800;
                          if (isSmallScreen) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLogoSection(),
                                const SizedBox(height: 16),
                                _buildNavigationButtons(isSmallScreen: true),
                              ],
                            );
                          }
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildLogoSection(),
                              _buildNavigationButtons(isSmallScreen: false),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                Expanded(child: _pages[_selectedIndex]),
              ],
            ),
            bottomNavigationBar: isMobile
                ? NavigationBar(
                    height: 68,
                    backgroundColor: const Color(0xFFFBFAF6),
                    indicatorColor: const Color(0xFFE5E9DF),
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: (index) {
                      setState(() => _selectedIndex = index);
                    },
                    destinations: _navItems
                        .map(
                          (item) => NavigationDestination(
                            icon: Icon(item.icon),
                            label: item.label,
                          ),
                        )
                        .toList(),
                  )
                : null,
          );
        },
      ),
    );
  }

  Widget _buildLogoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Uganda Heritage Data Warehouse',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.green.shade800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Semantic-Aware Multimodal Knowledge Graph',
          style: TextStyle(
            fontSize: 12,
            color: Colors.green.shade600,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationButtons({required bool isSmallScreen}) {
    if (isSmallScreen) {
      // Wrap buttons for small screens
      return Wrap(
        spacing: 12,
        runSpacing: 8,
        children: _navItems.map((item) {
          return _buildNavButton(item);
        }).toList(),
      );
    } else {
      // Row layout for larger screens
      return Row(
        children: _navItems.map((item) {
          return _buildNavButton(item);
        }).toList(),
      );
    }
  }

  Widget _buildNavButton(NavigationItem item) {
    final isSelected = _selectedIndex == item.index;

    return TextButton(
      onPressed: () {
        setState(() {
          _selectedIndex = item.index;
        });
      },
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        backgroundColor: isSelected
            ? Colors.green.shade100
            : Colors.transparent,
        foregroundColor: isSelected
            ? Colors.green.shade800
            : Colors.green.shade700,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
          side: BorderSide(
            color: isSelected ? Colors.green.shade300 : Colors.transparent,
            width: 1,
          ),
        ),
        elevation: 0,
      ),
      child: Text(
        item.title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color: isSelected ? Colors.green.shade800 : Colors.green.shade700,
        ),
      ),
    );
  }
}

class NavigationItem {
  final String title;
  final String label;
  final IconData icon;
  final int index;

  const NavigationItem({
    required this.title,
    required this.label,
    required this.icon,
    required this.index,
  });
}
