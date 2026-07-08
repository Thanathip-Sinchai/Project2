import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'pages/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('th')],
      path: 'assets/langs', // Path ของไฟล์ JSON
      fallbackLocale: const Locale('th'), // ภาษาเริ่มต้นถ้าระบบพัง
      startLocale: const Locale('th'), // เปิดแอปครั้งแรกเป็นภาษาไทย
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // ✅ เพิ่มบรรทัดนี้: ปิดแถบแดง DEBUG มุมขวาบน
      debugShowCheckedModeBanner: false,
      
      title: 'Stocknova',
      // ผูกระบบแปลภาษาเข้ากับ MaterialApp
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,

      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Roboto', // หรือฟอนต์ที่คุณใช้
      ),
      home: const LoginPage(),
    );
  }
}