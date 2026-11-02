import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('medications');
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0B131E), Colors.black],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
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
      ),
    );
  }
}

// 2. التبويبات الرئيسية
class MainTabView extends StatelessWidget {
  const MainTabView({super.key});
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF0B131E),
          title: const Text('PharmaSync'),
          bottom: const TabBar(
            indicatorColor: Colors.cyan,
            tabs: [
              Tab(icon: Icon(Icons.list), text: 'الأدوية'),
              Tab(icon: Icon(Icons.style), text: 'الحفظ السريع'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            MedicationListScreen(),
            FlashcardScreen(),
          ],
        ),
      ),
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
          return const Center(child: Text('لا توجد أدوية. أضف دواءً جديداً.', style: TextStyle(color: Colors.grey)));
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
                    ? Image.file(File(med['imagePath']), width: 50, height: 50, fit: BoxFit.cover)
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
                  Navigator.push(context, MaterialPageRoute(builder: (_) => DetailsScreen(med: med, key: meds[index])));
                },
              ),
            );
          },
        );
      },
    );
  }
}

// 4. شاشة التفاصيل والنطق
class DetailsScreen extends StatefulWidget {
  final Map med;
  final dynamic keyId;
  const DetailsScreen({super.key, required this.med, this.keyId});
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
      appBar: AppBar(title: const Text('التفاصيل'), backgroundColor: const Color(0xFF0B131E)),
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
                Text(widget.med['nameEn'], style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
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

// 5. شاشة البطاقات التعليمية
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
    if (box.isEmpty) return const Center(child: Text('أضف أدوية أولاً', style: TextStyle(color: Colors.grey)));

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
                  ? Text('الاستخدام: ${med['indications']}\n\nالجرعة: ${med['dosage']}', style: const TextStyle(color: Colors.white, fontSize: 18), textAlign: TextAlign.center)
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

// 6. شاشة إضافة دواء
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('دواء جديد'), backgroundColor: const Color(0xFF0B131E)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: nameEn, decoration: const InputDecoration(labelText: 'الاسم بالإنجليزي')),
          TextField(controller: phoneticAr, decoration: const InputDecoration(labelText: 'النطق بالعربي')),
          TextField(controller: phoneticEn, decoration: const InputDecoration(labelText: 'النطق بالإنجليزي')),
          TextField(controller: similar, decoration: const InputDecoration(labelText: 'يتشابه مع (تحذير)')),
          TextField(controller: indications, decoration: const InputDecoration(labelText: 'المؤشرات (لمن نعطيه)')),
          TextField(controller: dosage, decoration: const InputDecoration(labelText: 'الجرعة (كيف نعطيه)')),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: pickImage,
            icon: const Icon(Icons.image),
            label: Text(image == null ? 'إضافة صورة' : 'تغيير الصورة'),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: save,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan),
            child: const Text('حفظ الدواء', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }
}
