import 'package:intl/intl.dart';

/// Web'deki `useDateFilter`/`dateRange.ts` ile aynı mantık — iş emirleri
/// sayfası sınırsız uzamasın diye varsayılan olarak "Bugün" gösterilir,
/// istenirse hafta/ay/tüm zamanlar/özel aralık seçilebilir.
enum Period { bugun, hafta, ay, tumZamanlar, ozel }

const Map<Period, String> periodLabels = {
  Period.bugun: 'Bugün',
  Period.hafta: 'Bu Hafta',
  Period.ay: 'Bu Ay',
  Period.tumZamanlar: 'Tüm Zamanlar',
  Period.ozel: 'Tarih Aralığı',
};

class DateRange {
  final DateTime? from;
  final DateTime? to;
  const DateRange({this.from, this.to});
}

DateRange periodRange(Period period, {DateTime? customFrom, DateTime? customTo}) {
  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day);

  switch (period) {
    case Period.bugun:
      return DateRange(from: startOfDay);
    case Period.hafta:
      final dayIndex = (now.weekday - 1) % 7; // Pazartesi = 0
      return DateRange(from: startOfDay.subtract(Duration(days: dayIndex)));
    case Period.ay:
      return DateRange(from: DateTime(now.year, now.month, 1));
    case Period.ozel:
      final from = customFrom != null ? DateTime(customFrom.year, customFrom.month, customFrom.day) : null;
      final to = customTo != null ? DateTime(customTo.year, customTo.month, customTo.day, 23, 59, 59, 999) : null;
      return DateRange(from: from, to: to);
    case Period.tumZamanlar:
      return const DateRange();
  }
}

String periodDisplayLabel(Period period, {DateTime? customFrom, DateTime? customTo}) {
  if (period != Period.ozel) return periodLabels[period]!;
  if (customFrom == null || customTo == null) return periodLabels[Period.ozel]!;
  final fmt = DateFormat('dd.MM.yyyy');
  return '${fmt.format(customFrom)} — ${fmt.format(customTo)}';
}
