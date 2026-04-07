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
    NavigationItem(title: 'Crowdsource', index: 0),
    NavigationItem(title: 'Knowledge Graph', index: 1),
    NavigationItem(title: 'VLM Identification', index: 2),
    NavigationItem(title: 'BI Dashboard', index: 3),
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
      home: Scaffold(
        body: Column(
          children: [
            // Custom App Bar with responsive design
            SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border(
                    bottom: BorderSide(color: Colors.green.shade100, width: 1),
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Responsive layout: column on small screens, row on larger
                    final isSmallScreen = constraints.maxWidth < 800;

                    if (isSmallScreen) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Logo section
                          _buildLogoSection(),
                          const SizedBox(height: 16),
                          // Navigation buttons
                          _buildNavigationButtons(isSmallScreen: true),
                        ],
                      );
                    } else {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Logo section
                          _buildLogoSection(),
                          // Navigation buttons
                          _buildNavigationButtons(isSmallScreen: false),
                        ],
                      );
                    }
                  },
                ),
              ),
            ),
            // Main content area - displays selected page
            Expanded(child: _pages[_selectedIndex]),
          ],
        ),
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
  final int index;

  const NavigationItem({required this.title, required this.index});
}
