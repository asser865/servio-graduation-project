// mobile-app/lib/src/features/booking/booking_strings.dart

class BookingStrings {
  BookingStrings._();

  static const List<String> stepLabels = <String>[
    'Details',
    'Schedule',
    'Payment',
  ];

  static const String pickDateAndTime = 'Pick a Date & Time';
  static const String timeSlots = 'Time Slots';
  static const String timezoneLabel = 'EST';
  static const String serviceAddress = 'Service Address';
  static const String addNewAddress = 'Add New Address';
  static const String continueLabel = 'Continue';
  static const String technicianUnavailable =
      'Technician is not available on this day';
  static const String noAddresses = 'No saved addresses yet.';
  static const String addAddressPrompt =
      'Add an address to continue with this booking.';
  static const String selectAddressError =
      'Select a saved address to continue.';
  static const String retry = 'Retry';
}
