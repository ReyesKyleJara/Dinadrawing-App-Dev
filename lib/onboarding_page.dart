import 'package:flutter/material.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int currentIndex = 0;

  final List<String> images = [
    'images/page1.png',
    'images/page2.png',
    'images/page3.png',
    'images/page4.png',
    'images/page5.png',
    'images/page6.png',
    'images/page7.png',
  ];

  void nextPage() {
    if (currentIndex < 4) { // 🔥 STOP at page 5
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void goToPage(int page) {
    _controller.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void signUp() {
    goToPage(5);
  }

  void login() {
    goToPage(6);
  }

  void continueWithGoogle() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Google Sign-In Clicked")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDEAF0),
      body: Center(
        child: Container(
          width: 375,
          color: Colors.white,
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _controller,

                    // 🔥 KEY FIX HERE
                    physics: currentIndex >= 4
                        ? const NeverScrollableScrollPhysics() // stop at page 5
                        : const BouncingScrollPhysics(),

                    itemCount: images.length,
                    onPageChanged: (index) {
                      setState(() => currentIndex = index);
                    },
                    itemBuilder: (context, index) {
                      if (index == 4) return buildPageFive();
                      if (index == 5) return buildSignUpPage();
                      if (index == 6) return buildLoginPage();

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Image.asset(
                          images[index],
                          fit: BoxFit.contain,
                        ),
                      );
                    },
                  ),
                ),

                if (currentIndex < 4)
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          5,
                          (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: currentIndex == i ? 16 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: currentIndex == i
                                  ? Colors.orange
                                  : Colors.grey,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: currentIndex == 3
                                  ? const Color(0xFFF5B335)
                                  : Colors.grey[200],
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            onPressed: nextPage,
                            child: Text(
                              currentIndex == 3
                                  ? "Get Started"
                                  : "Next",
                              style: const TextStyle(color: Colors.black),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🔥 PAGE 5 (BACKGROUND IMAGE + BUTTONS)
  Widget buildPageFive() {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            "images/page5.png",
            fit: BoxFit.cover,
          ),
        ),
        Column(
          children: [
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: buildMainButton("Log In", login),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: buildSecondaryButton("Sign Up", signUp),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: buildGoogleButton(),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ],
    );
  }

  Widget buildSignUpPage() => Container();
  Widget buildLoginPage() => Container();

  Widget buildMainButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF5B335),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        onPressed: onPressed,
        child: Text(text, style: const TextStyle(color: Colors.black)),
      ),
    );
  }

  Widget buildSecondaryButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey[200],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        onPressed: onPressed,
        child: Text(text, style: const TextStyle(color: Colors.black)),
      ),
    );
  }

  Widget buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: continueWithGoogle,
        child: const Text("Continue with Google"),
      ),
    );
  }
}
// ================= HOME PAGE (FINAL PERFECT MATCH) =================
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool showMenu = false;
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDEAF0),

      body: Center(
        child: Container(
          width: 375,
          color: Colors.white,
          child: SafeArea(
            child: Stack(
              children: [

                // 🔥 MAIN CONTENT
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // HEADER
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Hello, User!",
                                  style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold)),
                              SizedBox(height: 4),
                              Text("What are we planning today?",
                                  style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                          const CircleAvatar(
                            radius: 18,
                            backgroundImage:
                                AssetImage("images/avatar.png"),
                          )
                        ],
                      ),

                      const SizedBox(height: 20),

                      // SPIN CARD
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [

                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Can’t decide where to go?"),
                                const Text("Spin the Wheel!",
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 10),

                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        const Color(0xFFF5B335),
                                  ),
                                  onPressed: () {},
                                  child: const Text("Try it now",
                                      style:
                                          TextStyle(color: Colors.black)),
                                )
                              ],
                            ),

                            Image.asset(
                              "images/wheel.png",
                              height: 70,
                            )
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // UPCOMING
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: const [
                          Text("Upcoming Plans",
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                          Text("View all",
                              style: TextStyle(color: Colors.grey))
                        ],
                      ),

                      const SizedBox(height: 10),

                      Expanded(
                        child: ListView(
                          children: [
                            buildPlan(
                                "Dinner sa Japan lang",
                                "Apr 8 • Ramen House, Tokyo, Japan",
                                "Planned",
                                5),
                            buildPlan(
                                "Picnic with Family",
                                "Apr 15 • Kahit saang tabing ilog",
                                "Planned",
                                3),
                            buildPlan(
                                "Birthday ni Kenny",
                                "Apr 29 • Boracay, Philippines",
                                "Ongoing",
                                3),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 🔥 FLOAT ACTION BUTTON + MENU
                Positioned(
                  bottom: 110,
                  right: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [

                      if (showMenu)
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: const [
                              BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 6)
                            ],
                          ),
                          child: Column(
                            children: [
                              menuItem("Create Plan"),
                              menuItem("Join Plan"),
                              menuItem("Quick Decision"),
                            ],
                          ),
                        ),

                      const SizedBox(height: 10),

                      FloatingActionButton(
                        backgroundColor:
                            const Color(0xFFF5B335),
                        onPressed: () {
                          setState(() {
                            showMenu = !showMenu;
                          });
                        },
                        child: const Icon(Icons.add,
                            color: Colors.black),
                      ),
                    ],
                  ),
                ),

                // 🔥 FIXED FLOATING NAV BAR (MATCH FIGMA)
                Positioned(
                  bottom: 10,
                  left: 10,
                  right: 10,
                  child: Container(
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                        )
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceAround,
                      children: [

                        navItem(Icons.home, "Home", 0),
                        navItem(Icons.add_circle_outline, "My Plans", 1),
                        navItem(Icons.notifications_none, "Activity", 2),
                        navItem(Icons.settings, "Settings", 3),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🔥 NAV ITEM (ACTIVE STATE)
  Widget navItem(IconData icon, String label, int index) {
    bool isActive = selectedIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() => selectedIndex = index);
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              color: isActive ? Colors.orange : Colors.grey),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                fontSize: 12,
                color: isActive ? Colors.orange : Colors.grey,
              ))
        ],
      ),
    );
  }

  // PLAN CARD
  Widget buildPlan(
      String title, String subtitle, String status, int users) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.bold)),

          const SizedBox(height: 5),

          Text(subtitle,
              style: const TextStyle(color: Colors.grey)),

          const SizedBox(height: 10),

          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [

              Row(
                children: List.generate(
                  users,
                  (index) => Container(
                    margin: const EdgeInsets.only(right: 5),
                    child: const CircleAvatar(
                      radius: 12,
                      backgroundImage:
                          AssetImage("images/avatar.png"),
                    ),
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: status == "Planned"
                      ? Colors.green[200]
                      : Colors.orange[200],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(status),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget menuItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(text),
    );
  }
}