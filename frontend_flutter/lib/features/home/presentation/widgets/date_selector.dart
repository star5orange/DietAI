import 'package:flutter/material.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';

class DateSelector extends StatelessWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateSelected;

  const DateSelector({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (context, index) {
          final date = DateTime.now().subtract(Duration(days: 3 - index));
          final isSelected = _isSameDay(date, selectedDate);
          
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => onDateSelected(date),
              child: Container(
                width: 60,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _getWeekdayText(date),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      date.day.toString(),
                      style: AppTextStyles.labelLarge.copyWith(
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  String _getWeekdayText(DateTime date) {
    const weekdays = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    return weekdays[date.weekday % 7];
  }
} 