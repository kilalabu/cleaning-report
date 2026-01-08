import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../history/providers/history_provider.dart';

class DashboardScreen extends HookConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get current month for dashboard
    final now = DateTime.now();
    final currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final historyAsync = ref.watch(historyProvider(currentMonth));

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.go('/login'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Action Cards Grid
                Row(
                  children: [
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.cleaning_services,
                        iconColor: Theme.of(context).colorScheme.primary,
                        title: '清掃報告',
                        subtitle: '日々の清掃業務を報告',
                        onTap: () => context.go('/report/cleaning'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.receipt_long,
                        iconColor: Colors.green,
                        title: '立替費用',
                        subtitle: '備品購入などの立替',
                        onTap: () => context.go('/report/expense'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // History Preview Card
                Card(
                  child: InkWell(
                    onTap: () => context.go('/history'),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '今月の履歴',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              Text(
                                '履歴一覧',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          historyAsync.when(
                            data: (items) {
                              if (items.isEmpty) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(24),
                                    child: Text('履歴がありません', style: TextStyle(color: Colors.grey)),
                                  ),
                                );
                              }
                              final preview = items.take(8).toList();
                              return Column(
                                children: preview.map((item) => _HistoryTile(item: item)).toList(),
                              );
                            },
                            loading: () => const Center(child: Padding(
                              padding: EdgeInsets.all(24),
                              child: CircularProgressIndicator(),
                            )),
                            error: (e, _) => Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text('エラー: $e', style: const TextStyle(color: Colors.red)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 1,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 32),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final Map<String, dynamic> item;

  const _HistoryTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final isWork = item['type'] == 'work';
    final icon = isWork ? Icons.cleaning_services : Icons.receipt_long;
    final color = isWork ? Theme.of(context).colorScheme.primary : Colors.green;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['item'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '${item['date'] ?? ''}${item['note'] != null && item['note'].isNotEmpty ? ' ・ ${item['note']}' : ''}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '¥${(item['amount'] ?? 0).toString()}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
