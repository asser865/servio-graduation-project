class BookingFlowData {
  const BookingFlowData({
    this.serviceName = 'Plumbing Repair Visit',
    this.category = 'Home Maintenance',
    this.technicianName = 'Ahmed Nabil',
    this.specialty = 'Plumbing Specialist',
    this.priceLabel = '850 EGP - 1,200 EGP',
    this.hourlyRate = '350 EGP / hour',
    this.date = '26/03/2026',
    this.time = '10:00 AM - 11:00 AM',
    this.location = 'New Cairo, Cairo, Egypt',
    this.paymentMethod = 'Cash on Completion',
    this.reference = '#SRV-2026-8823',
    this.amount = '1,050 EGP',
  });

  final String serviceName;
  final String category;
  final String technicianName;
  final String specialty;
  final String priceLabel;
  final String hourlyRate;
  final String date;
  final String time;
  final String location;
  final String paymentMethod;
  final String reference;
  final String amount;

  BookingFlowData copyWith({
    String? serviceName,
    String? category,
    String? technicianName,
    String? specialty,
    String? priceLabel,
    String? hourlyRate,
    String? date,
    String? time,
    String? location,
    String? paymentMethod,
    String? reference,
    String? amount,
  }) {
    return BookingFlowData(
      serviceName: serviceName ?? this.serviceName,
      category: category ?? this.category,
      technicianName: technicianName ?? this.technicianName,
      specialty: specialty ?? this.specialty,
      priceLabel: priceLabel ?? this.priceLabel,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      date: date ?? this.date,
      time: time ?? this.time,
      location: location ?? this.location,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      reference: reference ?? this.reference,
      amount: amount ?? this.amount,
    );
  }
}
