part of 'budget_tab.dart';

// -----------------------------------------------------------------------------
// Draft Models
// -----------------------------------------------------------------------------

class _ExpenseDraft {
  _ExpenseDraft({String name = '', String note = '', double amount = 0})
    : nameController = TextEditingController(text: name),
      noteController = TextEditingController(text: note),
      amountController = TextEditingController(
        text: amount > 0 ? amount.toStringAsFixed(2) : '',
      );

  final TextEditingController nameController;
  final TextEditingController noteController;
  final TextEditingController amountController;

  void dispose() {
    nameController.dispose();
    noteController.dispose();
    amountController.dispose();
  }
}

class _MemberAllocationDraft {
  _MemberAllocationDraft({
    required this.userId,
    required this.name,
    required this.username,
    required this.profilePhotoUrl,
    required this.isPlanAdmin,
    required this.isIncluded,
    required double plannedShare,
  }) : shareController = TextEditingController(
         text: plannedShare.toStringAsFixed(2),
       );

  final int userId;
  final String name;
  final String? username;
  final String? profilePhotoUrl;
  final bool isPlanAdmin;

  bool isIncluded;

  final TextEditingController shareController;

  void dispose() {
    shareController.dispose();
  }
}

// -----------------------------------------------------------------------------
// Input and Formatting Helpers
// -----------------------------------------------------------------------------

class MoneyTextInputFormatter extends TextInputFormatter {
  const MoneyTextInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;

    if (text.isEmpty) {
      return newValue;
    }

    final valid = RegExp(r'^\d{0,10}(\.\d{0,2})?$').hasMatch(text);

    return valid ? newValue : oldValue;
  }
}

InputDecoration _tableInputDecoration(
  BuildContext context, {
  required String hint,
  String? prefixText,
  IconData? prefixIcon,
}) {
  final colors = Theme.of(context).colorScheme;

  return InputDecoration(
    hintText: hint,
    prefixText: prefixText,
    prefixIcon: prefixIcon == null
        ? null
        : Icon(prefixIcon, size: 17, color: colors.onSurfaceVariant),
    prefixIconConstraints: prefixIcon == null
        ? null
        : const BoxConstraints(minWidth: 34, minHeight: 34),
    filled: true,
    fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.42),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
    hintStyle: TextStyle(
      color: colors.onSurfaceVariant.withValues(alpha: 0.75),
      fontSize: 13,
      fontWeight: FontWeight.w500,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: colors.outlineVariant),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: colors.outlineVariant),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _budgetYellow, width: 1.4),
    ),
  );
}

void _normalizeMoneyController(TextEditingController controller) {
  final value = _parseAmount(controller.text);

  controller.value = TextEditingValue(
    text: value.toStringAsFixed(2),
    selection: TextSelection.collapsed(offset: value.toStringAsFixed(2).length),
  );
}

List<Map<String, dynamic>> _asMapList(dynamic value) {
  if (value is! List) {
    return <Map<String, dynamic>>[];
  }

  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

bool _asBool(dynamic value, {bool fallback = false}) {
  if (value == null) {
    return fallback;
  }

  if (value is bool) {
    return value;
  }

  if (value is num) {
    return value != 0;
  }

  final text = value.toString().trim().toLowerCase();

  return text == 'true' || text == '1';
}

int? _asInt(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is int) {
    return value;
  }

  return int.tryParse(value.toString());
}

double _asDouble(dynamic value) {
  if (value == null) {
    return 0;
  }

  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value.toString()) ?? 0;
}

double _parseAmount(String value) {
  return double.tryParse(value.trim()) ?? 0;
}

int _toCents(double value) {
  return (value * 100).round();
}

double _fromCents(int cents) {
  return cents / 100;
}

String _formatPeso(double value) {
  final negative = value < 0;
  final absolute = value.abs();

  final fixed = absolute.toStringAsFixed(2);
  final parts = fixed.split('.');

  final whole = parts.first;
  final decimal = parts.last;

  final buffer = StringBuffer();

  for (var index = 0; index < whole.length; index++) {
    final remaining = whole.length - index;

    buffer.write(whole[index]);

    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(',');
    }
  }

  return '${negative ? '-' : ''}₱${buffer.toString()}.$decimal';
}

String _formatDateTime(dynamic value) {
  final dateTime = DateTime.tryParse(value.toString())?.toLocal();

  if (dateTime == null) {
    return value.toString();
  }

  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  final hour = dateTime.hour == 0
      ? 12
      : dateTime.hour > 12
      ? dateTime.hour - 12
      : dateTime.hour;

  final minute = dateTime.minute.toString().padLeft(2, '0');

  final period = dateTime.hour >= 12 ? 'PM' : 'AM';

  return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year} • $hour:$minute $period';
}
