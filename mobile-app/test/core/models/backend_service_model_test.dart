import 'package:flutter_test/flutter_test.dart';
import 'package:servio_mobile_app/src/core/models/backend_service_model.dart';

void main() {
  group('BackendService.fromJson', () {
    test('parses all fields from full backend response', () {
      final json = {
        '_id': 'svc1',
        'title': 'Pipe Repair',
        'titleAr': 'إصلاح الأنابيب',
        'category': 'plumbing',
        'basePrice': 150,
        'priceUnit': 'per_hour',
        'estimatedDurationMin': 90,
        'description': 'Fix leaking pipes',
        'descriptionAr': 'إصلاح الأنابيب المتسربة',
        'isActive': true,
        'averageRating': 4.5,
        'totalReviews': 12,
        'images': ['https://example.com/img.jpg'],
      };

      final svc = BackendService.fromJson(json);

      expect(svc.id, 'svc1');
      expect(svc.name, 'Pipe Repair');
      expect(svc.nameAr, 'إصلاح الأنابيب');
      expect(svc.category, 'plumbing');
      expect(svc.basePrice, 150.0);
      expect(svc.priceUnit, 'per_hour');
      expect(svc.estimatedDurationMin, 90);
      expect(svc.description, 'Fix leaking pipes');
      expect(svc.descriptionAr, 'إصلاح الأنابيب المتسربة');
      expect(svc.isActive, true);
      expect(svc.averageRating, 4.5);
      expect(svc.totalReviews, 12);
      expect(svc.images, ['https://example.com/img.jpg']);
    });

    test('uses safe defaults for missing optional fields', () {
      final json = {
        '_id': 'svc2',
        'title': 'Cleaning',
        'category': 'cleaning',
        'basePrice': 80,
        'priceUnit': 'fixed',
      };

      final svc = BackendService.fromJson(json);

      expect(svc.nameAr, '');
      expect(svc.descriptionAr, '');
      expect(svc.estimatedDurationMin, 0);
      expect(svc.isActive, true);
      expect(svc.averageRating, 0.0);
      expect(svc.totalReviews, 0);
      expect(svc.images, isEmpty);
    });

    test('priceUnitLabel returns correct label', () {
      final hourly = BackendService.fromJson({
        '_id': 'a', 'title': 'T', 'category': 'c', 'basePrice': 10, 'priceUnit': 'per_hour',
      });
      final sqm = BackendService.fromJson({
        '_id': 'b', 'title': 'T', 'category': 'c', 'basePrice': 10, 'priceUnit': 'per_sqm',
      });
      final fixed = BackendService.fromJson({
        '_id': 'c', 'title': 'T', 'category': 'c', 'basePrice': 10, 'priceUnit': 'fixed',
      });

      expect(hourly.priceUnitLabel, 'EGP/hr');
      expect(sqm.priceUnitLabel, 'EGP/m²');
      expect(fixed.priceUnitLabel, 'EGP');
    });
  });
}
