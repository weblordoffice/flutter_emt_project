import 'package:emtrack/color/app_color.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../routes/app_pages.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView>
    with SingleTickerProviderStateMixin {
  late AnimationController c;
  late Animation<double> fade;

  @override
  void initState() {
    super.initState();
    c = AnimationController(vsync: this, duration: Duration(seconds: 2));
    fade = Tween<double>(begin: 0, end: 1).animate(c);

    c.forward();

    Future.delayed(Duration(seconds: 3), () {
      Get.offNamed(AppPages.LOGIN);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: FadeTransition(
          opacity: fade,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset("assets/images/logo.png", width: 180),
              SizedBox(height: 15),
              Image.asset("assets/images/apk_logo.png", width: 150),
            ],
          ),
        ),
      ),
    );
  }
}
