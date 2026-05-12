import 'package:flutter/material.dart';
import 'package:dinadrawing/screens/auth/login.dart';
import 'package:dinadrawing/screens/auth/signup.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final List<Map<String, String>> onboardingData = [
    {
      "title_1": "Welcome to\n",
      "title_2": "DiNaDrawing",
      "subtitle": "Start your plan journey with DiNaDrawing —\nyour all-in-one app to plan, budget, and assigned.",
      "image": "images/get-started-pg1.png", 
    },
    {
      "title_1": "Plan in Minutes",
      "title_2": "",
      "subtitle": "Skip the back-and-forth. Finalize your\ndate, time, and activity in just a few taps.",
      "image": "images/get-started-pg2.png",
    },
    {
      "title_1": "Vote & Decide",
      "title_2": "",
      "subtitle": "Let everyone decide!\nVote on venues, schedules, and all the details.",
      "image": "images/get-started-pg3.png",
    },
    {
      "title_1": "Split Expenses",
      "title_2": "",
      "subtitle": "Say goodbye to 'pahirapan' collections.\nTrack your group's budget and settle\nexpenses fairly.",
      "image": "images/get-started-pg4.png",
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, 
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            
            // --- MAIN CONTENT AREA (PageView) ---
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                itemCount: 5, 
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                itemBuilder: (context, index) {
                  if (index == 4) {
                    return _buildGetStartedScreen();
                  }

                  // TINANGGAL NATIN YUNG OVERALL 24px MARGIN DITO
                  return Column(
                    children: [
                      const SizedBox(height: 20),
                      
                      // BINALIK NATIN ANG 24px MARGIN DITO LANG SA TEXTS
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Column(
                          children: [
                            if (index == 0) ...[
                              RichText(
                                textAlign: TextAlign.center,
                                text: TextSpan(
                                  style: const TextStyle(fontFamily: 'Inter'), 
                                  children: [
                                    TextSpan(
                                      text: onboardingData[index]["title_1"]!,
                                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.black, height: 1.2),
                                    ),
                                    TextSpan(
                                      text: onboardingData[index]["title_2"]!,
                                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Color(0xFFF5B335), height: 1.2),
                                    ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              Text(
                                onboardingData[index]["title_1"]!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.black),
                              ),
                            ],
                            
                            const SizedBox(height: 16),
                            
                            Text(
                              onboardingData[index]["subtitle"]!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87, height: 1.5),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // --- FULL WIDTH BIG IMAGE (Walang Margin Restriction!) ---
                      Expanded(
                        child: SizedBox(
                          width: double.infinity,
                          child: Transform.scale(
                            scale: 1.15, // Pinalaki pa natin para masagad talaga!
                            child: Image.asset(
                              onboardingData[index]["image"]!,
                              fit: BoxFit.contain, // Fit to space smoothly
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                },
              ),
            ),

            // --- BOTTOM SECTION (Visible only on pages 1-4) ---
            if (_currentIndex < 4)
              // 24px STRICT MARGIN SA BUTTONS AT DOTS
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        onboardingData.length,
                        (index) => _buildDot(index),
                      ),
                    ),
                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.ease,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _currentIndex == 3 ? const Color(0xFFF5B335) : Colors.white,
                          elevation: 0,
                          side: BorderSide(
                            color: _currentIndex == 3 ? Colors.transparent : Colors.grey.shade300, 
                            width: 1.5
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(
                          _currentIndex == 3 ? "Get Started" : "Next",
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.bold, 
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(right: 6),
      height: 8,
      width: _currentIndex == index ? 24 : 8, 
      decoration: BoxDecoration(
        color: _currentIndex == index ? const Color(0xFFF5B335) : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildGetStartedScreen() {
    // 24px STRICT MARGIN SA PAGE 5
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('images/get-started-pg5.png', height: 24, width: 24), 
              const SizedBox(width: 8),
              const Text(
                "DiNaDrawing",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          const Text("Get Started!", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.black)),
          const SizedBox(height: 12),
          const Text(
            "Sign Up or Log In to start planning activities\nwith your barkada!",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87, height: 1.5),
          ),
          
          const SizedBox(height: 16),
          
          // PAGE 5 FULL WIDTH IMAGE
          Expanded(
            child: SizedBox(
              width: double.infinity,
              child: Transform.scale(
                scale: 1.15,
                child: Image.asset(
                  "images/get-started-pg5.png",
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // --- AUTHENTICATION BUTTONS ---
          
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF5B335),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text("Log In", style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SignUpScreen()));
              },
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text("Sign Up", style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text("or continue with", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
              ),
              Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
            ],
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Google Sign-In coming soon!")));
              },
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                side: BorderSide(color: Colors.grey.shade300, width: 1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.g_mobiledata, color: Colors.black, size: 28),
                  const SizedBox(width: 8),
                  const Text("Continue with Google", style: TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),

          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 11, color: Colors.grey),
              children: [
                const TextSpan(text: "What's this is all about? "),
                TextSpan(text: "Learn more.", style: TextStyle(color: const Color(0xFFF5B335), fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}