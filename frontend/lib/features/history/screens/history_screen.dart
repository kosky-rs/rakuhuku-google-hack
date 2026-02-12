import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../../config/theme.dart';
import '../../../config/router.dart';
import '../providers/history_provider.dart';

/// History screen with real data
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  late DateTime _focusedDay;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    Future.microtask(() {
      ref.read(historyProvider.notifier).fetchHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final historyState = ref.watch(historyProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            // App bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.backgroundDark : Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.account_circle_outlined,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                    onPressed: () => context.goSettings(),
                  ),
                  Expanded(
                    child: Text(
                      '履歴',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.h3.copyWith(
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _buildContent(historyState, isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(HistoryState state, bool isDark) {
    // Loading
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Error
    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text(
                '履歴の読み込みに失敗しました',
                style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                state.error!,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => ref.read(historyProvider.notifier).refresh(),
                child: const Text('再試行'),
              ),
            ],
          ),
        ),
      );
    }

    // Empty
    if (state.entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_note_outlined, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(
              'コーデ履歴がまだありません',
              style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              'おすすめコーデの「これを着る」で\n履歴が追加されます',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Calendar view
    return RefreshIndicator(
      onRefresh: () => ref.read(historyProvider.notifier).refresh(),
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Calendar
            Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
              child: TableCalendar(
                firstDay: DateTime.utc(2024, 1, 1),
                lastDay: DateTime.now(),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                eventLoader: (day) => _getEventsForDay(day, state.entries),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                calendarStyle: CalendarStyle(
                  // Selected day
                  selectedDecoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  selectedTextStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  // Today
                  todayDecoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  todayTextStyle: TextStyle(
                    color: isDark ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  // Marker (events)
                  markerDecoration: BoxDecoration(
                    color: AppColors.secondary,
                    shape: BoxShape.circle,
                  ),
                  markerSize: 6,
                  markersMaxCount: 1,
                  // Default days
                  defaultTextStyle: TextStyle(
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                  weekendTextStyle: TextStyle(
                    color: isDark ? Colors.white70 : AppColors.textSecondary,
                  ),
                  outsideTextStyle: TextStyle(
                    color: AppColors.textMuted,
                  ),
                ),
                headerStyle: HeaderStyle(
                  titleTextStyle: AppTextStyles.h3.copyWith(
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                  formatButtonVisible: false,
                  titleCentered: true,
                  leftChevronIcon: Icon(
                    Icons.chevron_left,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                  rightChevronIcon: Icon(
                    Icons.chevron_right,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  weekendStyle: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),

            // Selected day outfits
            if (_selectedDay != null)
              _buildOutfitsForDay(_selectedDay!, state, isDark),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getEventsForDay(
    DateTime day,
    List<Map<String, dynamic>> entries,
  ) {
    final dateKey = DateFormat('yyyy-MM-dd').format(day);
    return entries.where((e) => e['worn_date'] == dateKey).toList();
  }

  Widget _buildOutfitsForDay(
    DateTime day,
    HistoryState state,
    bool isDark,
  ) {
    final outfits = _getEventsForDay(day, state.entries);

    if (outfits.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.event_busy_outlined,
                size: 48,
                color: AppColors.textMuted,
              ),
              const SizedBox(height: 12),
              Text(
                DateFormat('M月d日').format(day),
                style: AppTextStyles.h3.copyWith(
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'この日のコーデ履歴はありません',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                DateFormat('M月d日のコーデ').format(day),
                style: AppTextStyles.h3.copyWith(
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),

        // Outfit cards
        ...outfits.map((outfit) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: _HistoryEntryCard(entry: outfit),
            )),

        const SizedBox(height: 16),
      ],
    );
  }
}

class _HistoryEntryCard extends StatelessWidget {
  final Map<String, dynamic> entry;

  const _HistoryEntryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = (entry['items'] as List<dynamic>?) ?? [];
    final weather = entry['weather'] as Map<String, dynamic>?;
    final score = (entry['score'] as num?)?.toDouble();
    final feedback = entry['feedback'] as String?;
    final wornDate = entry['worn_date'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date and score row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      wornDate,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                if (score != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _scoreColor(score).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${score.round()}点',
                      style: TextStyle(
                        color: _scoreColor(score),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Weather info
            if (weather != null) ...[
              Row(
                children: [
                  Icon(Icons.wb_sunny_outlined, size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    weather['description'] as String? ?? '',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Items as chips
            if (items.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: items.whereType<Map<String, dynamic>>().map<Widget>((item) {
                  final name = item['name'] as String? ?? '';
                  final color = item['color'] as String? ?? '';
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      name.isNotEmpty ? name : color,
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),

            // Feedback
            if (feedback != null && feedback.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                feedback,
                style: AppTextStyles.bodySmall.copyWith(
                  color: isDark ? Colors.white70 : AppColors.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _scoreColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return AppColors.error;
  }
}
