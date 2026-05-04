class BookingFlowData {
  const BookingFlowData({
    this.serviceName = 'Plumbing Repair Visit',
    this.category = 'Home Maintenance',
    this.technicianName = 'Ahmed Nabil',
    this.technicianId = '',
    this.serviceId = '',
    this.specialty = 'Plumbing Specialist',
    this.priceLabel = '850 EGP - 1,200 EGP',
    this.hourlyRate = '350 EGP / hour',
    this.date = '26/03/2026',
    this.time = '10:00 AM - 11:00 AM',
    this.scheduledDateTime,
    this.location = 'New Cairo, Cairo, Egypt',
    this.addressCity = '',
    this.addressStreet = '',
    this.notes = '',
    this.paymentMethod = 'Cash on Completion',
    this.reference = '#SRV-2026-8823',
    this.amount = '1,050 EGP',
  });

  final String serviceName;
  final String category;
  final String technicianName;
  final String technicianId;
  final String serviceId;
  final String specialty;
  final String priceLabel;
  final String hourlyRate;
  final String date;
  final String time;
  final DateTime? scheduledDateTime;
  final String location;
  final String addressCity;
  final String addressStreet;
  final String notes;
  final String paymentMethod;
  final String reference;
  final String amount;

  BookingFlowData copyWith({
    String? serviceName,
    String? category,
    String? technicianName,
    String? technicianId,
    String? serviceId,
    String? specialty,
    String? priceLabel,
    String? hourlyRate,
    String? date,
    String? time,
    DateTime? scheduledDateTime,
    String? location,
    String? addressCity,
    String? addressStreet,
    String? notes,
    String? paymentMethod,
    String? reference,
    String? amount,
  }) {
    return BookingFlowData(
      serviceName: serviceName ?? this.serviceName,
      category: category ?? this.category,
      technicianName: technicianName ?? this.technicianName,
      technicianId: technicianId ?? this.technicianId,
      serviceId: serviceId ?? this.serviceId,
      specialty: specialty ?? this.specialty,
      priceLabel: priceLabel ?? this.priceLabel,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      date: date ?? this.date,
      time: time ?? this.time,
      scheduledDateTime: scheduledDateTime ?? this.scheduledDateTime,
      location: location ?? this.location,
      addressCity: addressCity ?? this.addressCity,
      addressStreet: addressStreet ?? this.addressStreet,
      notes: notes ?? this.notes,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      reference: reference ?? this.reference,
      amount: amount ?? this.amount,
    );
  }
}
