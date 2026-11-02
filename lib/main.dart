import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'database_seed.dart'; // تأكد من وجود هذا الملف

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  final box = await Hive.openBox('medications');
  
  // تحميل قاعدة البيانات الأولية إذا كان التطبيق فارغاً
  if (box.isEmpty) {
    for (var med in DatabaseSeed.medicines) {
      await box.add(med);
    }
  }
  
  runApp(const PharmaSyncApp());
}

class PharmaSyncApp extends StatelessWidget {
  const PharmaSyncApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PharmaSync',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.cyan,
        scaffoldBackgroundColor: const Color(0xFF0B131E),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF0B131E), elevation: 0),
      ),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      home: const SplashScreen(),
    );
  }
}

// 1. شاشة البداية
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainTabView()));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.medication, size: 120, color: Colors.cyan),
            const SizedBox(height: 20),
            const Text('PharmaSync', style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 10),
            Text('دليل الأدوية الذكي', style: TextStyle(color: Colors.grey[400], fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

// 2. التبويبات الرئيسية (مع زر الإضافة)
class MainTabView extends StatefulWidget {
  const MainTabView({super.key});
  @override
  State<MainTabView> createState() => _MainTabViewState();
}

class _MainTabViewState extends State<MainTabView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PharmaSync', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.cyan)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.cyan,
          tabs: const [
            Tab(icon: Icon(Icons.list), text: 'الأدوية'),
            Tab(icon: Icon(Icons.style), text: 'الحفظ السريع'),
            Tab(icon: Icon(Icons.star), text: 'المفضلة'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          MedicationListScreen(),
          FlashcardScreen(),
          FavoritesScreen(),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              backgroundColor: Colors.cyan,
              child: const Icon(Icons.add, color: Colors.black, size: 30),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AddMedicationScreen()));
              },
            )
          : null,
    );
  }
}

// 3. شاشة عرض الأدوية
class MedicationListScreen extends StatefulWidget {
  const MedicationListScreen({super.key});
  @override
  State<MedicationListScreen> createState() => _MedicationListScreenState();
}

class _MedicationListScreenState extends State<MedicationListScreen> {
  final box = Hive.box('medications');

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: box.listenable(),
      builder: (context, Box box, _) {
        if (box.isEmpty) {
          return const Center(child: Text('لا توجد أدوية. اضغط على زر + للإضافة.', style: TextStyle(color: Colors.grey)));
        }

        final meds = box.keys.toList();
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: meds.length,
          itemBuilder: (context, index) {
            final med = box.get(meds[index]);
            return Card(
              color: Colors.white.withOpacity(0.05),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.cyan.withOpacity(0.3))),
              child: ListTile(
                leading: med['imagePath'] != null 
                    ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(med['imagePath']), width: 50, height: 50, fit: BoxFit.cover))
                    : const Icon(Icons.medication, color: Colors.cyan, size: 40),
                title: Text(med['nameEn'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text(med['phoneticAr'], style: const TextStyle(color: Colors.cyan)),
                trailing: IconButton(
                  icon: Icon(med['isFav'] ? Icons.star : Icons.star_border, color: Colors.yellow),
                  onPressed: () {
                    med['isFav'] = !med['isFav'];
                    box.put(meds[index], med);
                  },
                ),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => DetailsScreen(med: med)));
                },
              ),
            );
          },
        );
      },
    );
  }
}

// 4. شاشة المفضلة
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final box = Hive.box('medications');
    return ValueListenableBuilder(
      valueListenable: box.listenable(),
      builder: (context, Box box, _) {
        final favs = box.keys.where((k) => box.get(k)['isFav'] == true).toList();
        if (favs.isEmpty) return const Center(child: Text('لا توجد أدوية في المفضلة', style: TextStyle(color: Colors.grey)));
        
        return ListView.builder(
          itemCount: favs.length,
          itemBuilder: (context, index) {
            final med = box.get(favs[index]);
            return ListTile(
              leading: const Icon(Icons.star, color: Colors.yellow),
              title: Text(med['nameEn'], style: const TextStyle(color: Colors.white)),
              subtitle: Text(med['phoneticAr'], style: const TextStyle(color: Colors.cyan)),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailsScreen(med: med))),
            );
          },
        );
      },
    );
  }
}

// 5. شاشة التفاصيل والنطق
class DetailsScreen extends StatefulWidget {
  final Map med;
  const DetailsScreen({super.key, required this.med});
  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  final FlutterTts tts = FlutterTts();

  Future<void> speak(String text) async {
    await tts.setLanguage("en-US");
    await tts.speak(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('التفاصيل')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.volume_up, color: Colors.cyan, size: 40),
                  onPressed: () => speak(widget.med['nameEn']),
                ),
                Expanded(child: Text(widget.med['nameEn'], style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.right)),
              ],
            ),
            const SizedBox(height: 20),
            if (widget.med['imagePath'] != null)
              Center(child: ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.file(File(widget.med['imagePath']), height: 200, fit: BoxFit.cover))),
            const SizedBox(height: 20),
            _buildCard('النطق', 'بالعربي: ${widget.med['phoneticAr']}\nبالإنجليزي: ${widget.med['phoneticEn']}'),
            if (widget.med['similar'] != '')
              _buildCard('تحذير التشابه', widget.med['similar'], isDanger: true),
            _buildCard('المؤشرات (لمن نعطيه)', widget.med['indications']),
            _buildCard('الجرعة (كيف نعطيه)', widget.med['dosage']),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(String title, String content, {bool isDanger = false}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDanger ? Colors.red.withOpacity(0.2) : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: isDanger ? Colors.red : Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(title, style: TextStyle(color: isDanger ? Colors.red : Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text(content, style: const TextStyle(color: Colors.white, fontSize: 16), textAlign: TextAlign.right),
        ],
      ),
    );
  }
}

// 6. شاشة إضافة دواء (مع ميزة استيراد CSV)
class AddMedicationScreen extends StatefulWidget {
  const AddMedicationScreen({super.key});
  @override
  State<AddMedicationScreen> createState() => _AddMedicationScreenState();
}

class _AddMedicationScreenState extends State<AddMedicationScreen> {
  final nameEn = TextEditingController();
  final phoneticEn = TextEditingController();
  final phoneticAr = TextEditingController();
  final similar = TextEditingController();
  final indications = TextEditingController();
  final dosage = TextEditingController();
  File? image;

  Future<void> pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => image = File(picked.path));
  }

  void save() {
    if (nameEn.text.isEmpty) return;
    final box = Hive.box('medications');
    box.add({
      'nameEn': nameEn.text,
      'phoneticEn': phoneticEn.text,
      'phoneticAr': phoneticAr.text,
      'similar': similar.text,
      'indications': indications.text,
      'dosage': dosage.text,
      'isFav': false,
      'imagePath': image?.path,
    });
    Navigator.pop(context);
  }

  // دالة استيراد ملف CSV
  Future<void> importCSV() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null) {
        File file = File(result.files.single.path!);
        String content = await file.readAsString(encoding: utf8);
        
        List<String> lines = content.split('\n');
        final box = Hive.box('medications');
        
        int addedCount = 0;
        // تخطي السطر الأول (العناوين)
        for (var line in lines.skip(1)) {
          if (line.trim().isEmpty) continue;
          // تقسيم السطر بناءً على الفاصلة
          List<String> parts = line.split(',');
          
          if (parts.length >= 4) {
            box.add({
              'nameEn': parts[0].trim(),
              'phoneticAr': parts.length > 1 ? parts[1].trim() : '',
              'phoneticEn': parts.length > 2 ? parts[2].trim() : '',
              'similar': parts.length > 3 ? parts[3].trim() : '',
              'indications': parts.length > 4 ? parts[4].trim() : '',
              'dosage': parts.length > 5 ? parts[5].trim() : '',
              'isFav': false,
              'imagePath': null,
            });
            addedCount++;
          }
        }
        
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تم استيراد $addedCount دواء بنجاح!'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء الاستيراد: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إضافة دواء جديد')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: nameEn, decoration: const InputDecoration(labelText: 'الاسم بالإنجليزي (إجباري)', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: phoneticAr, decoration: const InputDecoration(labelText: 'النطق بالعربي', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: phoneticEn, decoration: const InputDecoration(labelText: 'النطق بالإنجليزي', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: similar, decoration: const InputDecoration(labelText: 'يتشابه مع (تحذير)', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: indications, decoration: const InputDecoration(labelText: 'المؤشرات (لمن نعطيه)', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: dosage, decoration: const InputDecoration(labelText: 'الجرعة (كيف نعطيه)', border: OutlineInputBorder())),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: pickImage,
            icon: const Icon(Icons.image),
            label: Text(image == null ? 'إضافة صورة للعلبة' : 'تغيير الصورة'),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(15)),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: save,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan, padding: const EdgeInsets.all(15)),
            child: const Text('حفظ الدواء', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 30),
          const Divider(color: Colors.grey),
          const SizedBox(height: 10),
          const Text('أو قم بإضافة أدوية بكميات كبيرة:', style: TextStyle(color: Colors.grey, fontSize: 16), textAlign: TextAlign.center),
          const SizedBox(height: 10),
          // زر استيراد ملف CSV
          ElevatedButton.icon(
            onPressed: importCSV,
            icon: const Icon(Icons.file_upload),
            label: const Text('استيراد أدوية من ملف CSV'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: const EdgeInsets.all(15)),
          ),
        ],
      ),
    );
  }
}

// 7. شاشة البطاقات التعليمية
class FlashcardScreen extends StatefulWidget {
  const FlashcardScreen({super.key});
  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen> {
  int _index = 0;
  bool _flipped = false;

  @override
  Widget build(BuildContext context) {
    final box = Hive.box('medications');
    if (box.isEmpty) return const Center(child: Text('أضف أدوية أولاً لتظهر هنا', style: TextStyle(color: Colors.grey)));

    final med = box.get(box.keys.toList()[_index]);
    return Column(
      children: [
        const SizedBox(height: 20),
        Text('بطاقة ${_index + 1} من ${box.length}', style: const TextStyle(color: Colors.grey)),
        const Spacer(),
        GestureDetector(
          onTap: () => setState(() => _flipped = !_flipped),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            height: 400,
            width: 300,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: _flipped 
                ? const LinearGradient(colors: [Color(0xFF1A2A3A), Color(0xFF0B131E)]) 
                : const LinearGradient(colors: [Colors.blue, Colors.cyan]),
              boxShadow: [BoxShadow(color: Colors.cyan.withOpacity(0.3), blurRadius: 20)],
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: _flipped 
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('الاستخدام:', style: TextStyle(color: Colors.cyan[200], fontWeight: FontWeight.bold)),
                        Text(med['indications'], style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
                        const SizedBox(height: 10),
                        Text('الجرعة:', style: TextStyle(color: Colors.cyan[200], fontWeight: FontWeight.bold)),
                        Text(med['dosage'], style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
                      ],
                    )
                  : Text(med['nameEn'], style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              ),
            ),
          ),
        ),
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.cyan, size: 40),
              onPressed: _index > 0 ? () => setState(() { _index--; _flipped = false; }) : null,
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios, color: Colors.cyan, size: 40),
              onPressed: _index < box.length - 1 ? () => setState(() { _index++; _flipped = false; }) : null,
            ),
          ],
        ),
        const SizedBox(height: 50),
      ],
    );
  }
}
