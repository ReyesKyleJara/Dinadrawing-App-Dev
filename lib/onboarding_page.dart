import 'screens/home/home_page.dart';
import 'package:flutter/material.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';

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

  // CONTROLLERS
  final name = TextEditingController();
  final username = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();

  final loginUser = TextEditingController();
  final loginPass = TextEditingController();

  bool obscure = true;
  bool obscureLogin = true;
  bool rememberMe = false;

  void nextPage() {
    if (currentIndex < 4) {
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

  void signUp() => goToPage(5);
  void login() => goToPage(6);

  void submitSignUp() {
    if (name.text.isEmpty ||
        username.text.isEmpty ||
        email.text.isEmpty ||
        password.text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Complete all fields")),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Sign Up Success")),
    );
  }

  void submitLogin() {
  if (loginUser.text.isEmpty || loginPass.text.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Enter credentials")),
    );
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text("Login Success")),
  );

  // 🔥 ADD THIS
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (_) => const HomePage()),
  );
}

  void continueWithGoogle() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Google Clicked")),
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
                    physics: currentIndex >= 4
                        ? const NeverScrollableScrollPhysics()
                        : const BouncingScrollPhysics(),
                    itemCount: images.length,
                    onPageChanged: (index) {
                      setState(() => currentIndex = index);
                    },
                    itemBuilder: (context, index) {
                          if (index == 4) return buildPageFive();

                          if (index == 5) {
                            return SignUpScreen(
                              onSwitchToLogin: () => goToPage(6),
                            );
                          }

                          if (index == 6) {
                            return LoginScreen(
                              onSwitchToSignup: () => goToPage(5),
                            );
  }
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Image.asset(images[index]),
                      );
                    },
                  ),
                ),

                if (currentIndex < 4)
                  Column(
                    children: [
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: currentIndex == 3
                                  ? const Color(0xFFF5B335)
                                  : Colors.grey[200],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            onPressed: nextPage,
                            child: Text(
                              currentIndex == 3 ? "Get Started" : "Next",
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

  // PAGE 5
  Widget buildPageFive() {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset("images/page5.png", fit: BoxFit.cover),
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
        )
      ],
    );
  }

  // SIGN UP (FIXED ALIGNMENT)
  Widget buildSignUpUI() {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset("images/page6.png", fit: BoxFit.cover),
        ),
        Center(
          child: SingleChildScrollView(
            child: Container(
              width: 300,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 160),

                  textField("Name", name),
                  textField("Username", username),
                  textField("Email", email),

                  passwordField(password, () {
                    setState(() => obscure = !obscure);
                  }, obscure),

                  const SizedBox(height: 5),

                  const Text(
                    "Must be at least 8 characters.",
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),

                  const SizedBox(height: 20),

                  buildMainButton("Sign Up", submitSignUp),

                  const SizedBox(height: 20),

                  Row(
                    children: const [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text("or continue with"),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),

                  const SizedBox(height: 15),

                  buildGoogleButton(),

                  const SizedBox(height: 15),

                  GestureDetector(
                    onTap: () => goToPage(6),
                    child: const Text(
                      "Already have an account? Log In",
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // LOGIN (FIXED ALIGNMENT)
  Widget buildLoginUI() {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset("images/page7.png", fit: BoxFit.cover),
        ),
        Center(
          child: SingleChildScrollView(
            child: Container(
              width: 300,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 170),

                  textField("Username or Email", loginUser),

                  passwordField(loginPass, () {
                    setState(() => obscureLogin = !obscureLogin);
                  }, obscureLogin),

                  Row(
                    children: [
                      Checkbox(
                        value: rememberMe,
                        onChanged: (v) {
                          setState(() => rememberMe = v!);
                        },
                      ),
                      const Text("Remember Me")
                    ],
                  ),

                  const SizedBox(height: 10),

                  buildMainButton("Log In", submitLogin),

                  const SizedBox(height: 20),

                  Row(
                    children: const [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text("or continue with"),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),

                  const SizedBox(height: 15),

                  buildGoogleButton(),

                  const SizedBox(height: 15),

                  GestureDetector(
                    onTap: () => goToPage(5),
                    child: const Text(
                      "Don't have an account? Sign Up",
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // COMPONENTS
  Widget textField(String hint, TextEditingController c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        decoration: InputDecoration(
          hintText: hint,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget passwordField(
      TextEditingController c, VoidCallback toggle, bool hide) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        obscureText: hide,
        decoration: InputDecoration(
          hintText: "Password",
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          suffixIcon: IconButton(
            icon: Icon(hide ? Icons.visibility_off : Icons.visibility),
            onPressed: toggle,
          ),
        ),
      ),
    );
  }

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
    return OutlinedButton(
      onPressed: continueWithGoogle,
      child: const Text("Continue with Google"),
    );
  }
}
