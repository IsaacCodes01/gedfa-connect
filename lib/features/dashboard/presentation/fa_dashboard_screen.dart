import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/features/dashboard/data/dashboard_providers.dart';
import 'package:gedfa_connect/features/dashboard/presentation/widgets/dashboard_header.dart';
import 'package:gedfa_connect/features/dashboard/presentation/widgets/needs_you_card.dart';

/// FA: the Home tab, the first screen after signing in (2.12, mockup
/// 2.12-fa-dashboard). 2.12a: the header and "Needs you". 2.12b adds
/// League at a glance, the two charts, Season stats and Coming later.
///
/// Phones: one column. Tablets and laptops: up to 1,100 px wide, with
/// "Needs you" on the left and the charts on the right (2.12b).
class FaDashboardScreen extends ConsumerWidget {
  const FaDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = screenSizeOf(context) != ScreenSize.compact;
    final waitingAsync = ref.watch(faWaitingProvider);

    final needs = waitingAsync.when(
      loading: () => const _LoadingCard(),
      error: (error, _) => DashboardCard(
        padding: const EdgeInsets.all(18),
        child: Text(appErrorMessage(error)),
      ),
      data: (waiting) => waiting.isEmpty
          ? const AllCaughtUpCard()
          : NeedsYouCard(waiting: waiting),
    );

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(
          title: 'Needs you',
          trailing: switch (waitingAsync.value) {
            final w? when !w.isEmpty => '${w.total} waiting',
            _ => null,
          },
        ),
        needs,
      ],
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // White status bar icons over the blue header
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            DashboardHeader(wide: wide),
            Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Padding(
                  padding: wide
                      ? const EdgeInsets.fromLTRB(28, 22, 28, 30)
                      : const EdgeInsets.fromLTRB(14, 16, 14, 22),
                  child: wide
                      // Left column (5 of 12); the charts fill the right
                      // one in 2.12b
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 5, child: body),
                            const SizedBox(width: 16),
                            const Expanded(flex: 7, child: SizedBox()),
                          ],
                        )
                      : body,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Needs you" … "33 waiting"
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

/// Grey rows of the same shape while the numbers load.
class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    final grey = dashboardBorder(context);

    Widget block(double width, double height, double radius) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: grey,
            borderRadius: BorderRadius.circular(radius),
          ),
        );

    return DashboardCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  block(38, 38, 12),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        block(120, 12, 6),
                        const SizedBox(height: 6),
                        block(180, 10, 5),
                      ],
                    ),
                  ),
                  block(30, 26, 99),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
