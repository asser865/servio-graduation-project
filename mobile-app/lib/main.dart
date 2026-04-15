import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/core/services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await StorageService.init();
  runApp(ServioApp(storage: storage));
}
