import 'package:flutter_test/flutter_test.dart';

import 'package:servio_mobile_app/src/core/models/booking_model.dart';

void main() {
  test('active booking statuses match backend lifecycle', () {
    expect(BookingStatus.pending.isActive, isTrue);
    expect(BookingStatus.confirmed.isActive, isTrue);
    expect(BookingStatus.enRoute.isActive, isTrue);
    expect(BookingStatus.arrived.isActive, isTrue);
    expect(BookingStatus.inProgress.isActive, isTrue);

    expect(BookingStatus.completed.isActive, isFalse);
    expect(BookingStatus.cancelled.isActive, isFalse);
    expect(BookingStatus.rejected.isActive, isFalse);
    expect(BookingStatus.disputed.isActive, isFalse);
  });
}
