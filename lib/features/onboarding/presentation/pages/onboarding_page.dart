import 'package:airfiles_app/core/theme/app_colors.dart';
import 'package:airfiles_app/core/theme/app_theme.dart';
import 'package:airfiles_app/core/widgets/airfiles_logo.dart';
import 'package:flutter/material.dart';


class OnboardingData {
  final String title;
  final String description;
  final IconData icon;

  const OnboardingData({
    required this.title,
    required this.description,
    required this.icon,
  });
}

class OnboardingPage extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingPage({super.key, required this.onComplete});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingData> _pages = const [
    OnboardingData(
      title: 'Welcome to AirFiles',
      description: 'Share files seamlessly between devices on the same network.',
      icon: Icons.air,
    ),
    OnboardingData(
      title: 'Select Your Files',
      description: 'Pick files or folders from your device to share with others.',
      icon: Icons.folder_open_rounded,
    ),
    OnboardingData(
      title: 'No App Required',
      description: 'Recipients don\'t need to install anything. Files are accessible through any web browser.',
      icon: Icons.web_rounded,
    ),
    OnboardingData(
      title: 'Start Sharing',
      description: 'Start the server and share the link or QR code with anyone on your network.',
      icon: Icons.qr_code_rounded,
    ),
    OnboardingData(
      title: 'Access Anywhere',
      description: 'Open the shared link in any browser to download files instantly.',
      icon: Icons.devices_rounded,
    ),
  ];

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      widget.onComplete();
    }
  }

  void _skip() {
    widget.onComplete();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDarkMode ? AppTheme.darkGradient : AppTheme.primaryGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Skip button
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextButton(
                    onPressed: _skip,
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        color: isDarkMode ? AppColors.darkAccent : Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
              
              // Page content
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    return _buildPage(_pages[index], isDarkMode);
                  },
                ),
              ),

              // Page indicators
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pages.length,
                    (index) => _buildDotIndicator(index, isDarkMode),
                  ),
                ),
              ),

              // Next/Get Started button
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDarkMode ? AppColors.darkAccent : Colors.white,
                      foregroundColor: isDarkMode ? AppColors.darkBackground : AppColors.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _currentPage == _pages.length - 1 ? 'Get Started' : 'Next',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingData data, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Logo on first page, icon on others
          if (data.icon == Icons.air)
            const AirFilesLogo(size: 100, showText: false)
          else
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: (isDarkMode ? AppColors.darkAccent : Colors.white).withOpacity(0.2),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Icon(
                data.icon,
                size: 60,
                color: isDarkMode ? AppColors.darkAccent : Colors.white,
              ),
            ),
          const SizedBox(height: 48),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            data.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: (isDarkMode ? Colors.white : Colors.white).withOpacity(0.85),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDotIndicator(int index, bool isDarkMode) {
    final isActive = index == _currentPage;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive
            ? (isDarkMode ? AppColors.darkAccent : Colors.white)
            : (isDarkMode ? AppColors.darkAccent : Colors.white).withOpacity(0.4),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
