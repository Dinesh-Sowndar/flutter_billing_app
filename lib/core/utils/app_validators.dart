class AppValidators {
  static String? Function(String?) required(String message) {
    return (String? value) {
      if (value == null || value.trim().isEmpty) {
        return message;
      }
      return null;
    };
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a phone number';
    }
    final cleanValue = value.replaceAll(RegExp(r'[\s\-]'), '');
    if (!RegExp(r'^[0-9]{10}$').hasMatch(cleanValue)) {
      return 'Enter a valid 10-digit phone number';
    }
    return null;
  }

  static String? upi(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // UPI is usually optional, but if present it should be validated.
    }
    if (!RegExp(r'^[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z]{2,64}$').hasMatch(value.trim())) {
      return 'Enter a valid UPI ID (e.g. name@bank)';
    }
    return null;
  }

  static String? price(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a price';
    }
    if (double.tryParse(value) == null) {
      return 'Please enter a valid number';
    }
    if (double.parse(value) < 0) {
      return 'Price cannot be negative';
    }
    return null;
  }
}
