import 'package:flutter/foundation.dart';

import '../api/api_exception.dart';
import '../api/users_api.dart';
import '../models/customer_address.dart';

class CustomerAddressesProvider extends ChangeNotifier {
  CustomerAddressesProvider(this._usersApi);

  final UsersApi _usersApi;

  final List<CustomerAddress> _addresses = <CustomerAddress>[];
  bool _loading = false;
  bool _saving = false;
  String? _error;

  List<CustomerAddress> get addresses =>
      List<CustomerAddress>.unmodifiable(_addresses);
  bool get loading => _loading;
  bool get saving => _saving;
  String? get error => _error;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _refresh();
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Could not load addresses. Check your connection.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<CustomerAddress?> addAddress({
    String label = '',
    required String street,
    String city = '',
    String state = '',
    String zipCode = '',
  }) async {
    return _write(() async {
      final saved = await _usersApi.addAddress(
        label: label,
        street: street,
        city: city,
        state: state,
        zipCode: zipCode,
      );
      await _refresh();
      return saved;
    });
  }

  Future<CustomerAddress?> updateAddress(
    String id, {
    String label = '',
    required String street,
    String city = '',
    String state = '',
    String zipCode = '',
  }) async {
    return _write(() async {
      final saved = await _usersApi.updateAddress(
        id,
        label: label,
        street: street,
        city: city,
        state: state,
        zipCode: zipCode,
      );
      await _refresh();
      return saved;
    });
  }

  Future<bool> deleteAddress(String id) async {
    final deleted = await _write(() async {
      await _usersApi.deleteAddress(id);
      await _refresh();
      return const CustomerAddress(id: '');
    });
    return deleted != null;
  }

  Future<void> _refresh() async {
    final fresh = await _usersApi.getSavedAddresses();
    _addresses
      ..clear()
      ..addAll(fresh);
  }

  Future<CustomerAddress?> _write(
    Future<CustomerAddress> Function() action,
  ) async {
    _saving = true;
    _error = null;
    notifyListeners();
    try {
      return await action();
    } on ApiException catch (e) {
      _error = e.message;
      return null;
    } catch (_) {
      _error = 'Could not save address. Check your connection.';
      return null;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }
}
