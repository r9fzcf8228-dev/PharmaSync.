void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  final box = await Hive.openBox('medications');
  
  // إذا كان الصندوق فارغاً، نقوم بتحميل الأدوية من قاعدة البيانات
  if (box.isEmpty) {
    for (var med in DatabaseSeed.medicines) {
      await box.add(med);
    }
  }
  
  runApp(const PharmaSyncApp());
}
