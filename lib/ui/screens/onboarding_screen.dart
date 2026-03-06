/// Onboarding-skärm – visas vid första start
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../providers/app_providers.dart';
import '../../ui/theme/app_theme.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _page = 0;
  final _controller = PageController();

  static const _pages = [
    _OnboardingPage(
      icon: Icons.directions_bus_rounded,
      title: 'Välkommen till ReseAgenten',
      body: 'Din intelligenta kollektivtrafikassistent för hela Sverige.\n\n'
          'Hitta hållplatser, planera resor och boka biljetter – '
          'allt med hjälp av naturliga frågor på svenska.',
      color: AppTheme.brandBlue,
    ),
    _OnboardingPage(
      icon: Icons.search_rounded,
      title: 'Sök med ord',
      body: 'Skriv vad du vill göra med dina egna ord:\n\n'
          '• "Närmaste hållplats från Flogsta"\n'
          '• "Rutter till Uppsala Central kl 08.30"\n'
          '• "Boka biljett med en vuxen och ett barn"',
      color: Color(0xFF1565C0),
    ),
    _OnboardingPage(
      icon: Icons.map_outlined,
      title: 'Se resan på kartan',
      body: 'Varje resa visas på en interaktiv karta med '
          'start, stopp, byten och rutt.\n\n'
          'Kartan använder öppna OpenStreetMap-data.',
      color: AppTheme.successColor,
    ),
    _OnboardingPage(
      icon: Icons.lock_outline_rounded,
      title: 'Integritet och säkerhet',
      body: 'ReseAgenten använder:\n\n'
          '• Din plats (om du tillåter) – för att hitta närmaste hållplats.\n'
          '• Trafiklab-data – för rutter och avgångar.\n'
          '• Azure OpenAI – för att förstå dina förfrågningar.\n\n'
          'Inga personuppgifter lagras efter sessionen.',
      color: Color(0xFF6A1B9A),
    ),
  ];

  void _next() {
    if (_page < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _markDone();
    }
  }

  Future<void> _markDone() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool('onboarding_done', true);
    ref.read(onboardingDoneProvider.notifier).state = true;
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              onPageChanged: (i) => setState(() => _page = i),
              itemCount: _pages.length,
              itemBuilder: (ctx, i) => _buildPage(_pages[i], ctx),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
            child: Row(
              children: [
                // Sidindikator
                Row(
                  children: List.generate(
                    _pages.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _page ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _page
                            ? AppTheme.brandBlue
                            : AppTheme.brandBlue.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                if (_page > 0)
                  TextButton(
                    onPressed: () => _controller.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    ),
                    child: const Text('Tillbaka'),
                  ),
                const Gap(8),
                FilledButton.icon(
                  onPressed: _next,
                  icon: Icon(
                    _page == _pages.length - 1
                        ? Icons.check_rounded
                        : Icons.arrow_forward_rounded,
                    size: 18,
                  ),
                  label: Text(
                    _page == _pages.length - 1 ? 'Kom igång' : 'Nästa',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(_OnboardingPage page, BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: page.color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(page.icon, size: 48, color: page.color),
              ),
              const Gap(32),
              Text(
                page.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const Gap(16),
              Text(
                page.body,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.7,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage {
  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color color;
}
