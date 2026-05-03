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

  final nameController = TextEditingController();
  final usernameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final loginController = TextEditingController();
  final loginPasswordController = TextEditingController();

  bool obscurePassword = true;
  bool obscureLoginPassword = true;
  bool rememberMe = false;

  void nextPage() {
    if (currentIndex < 5) {
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
    if (nameController.text.isEmpty ||
        usernameController.text.isEmpty ||
        emailController.text.isEmpty ||
        passwordController.text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields correctly")),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Sign Up Successful")),
    );

    goToPage(6);
  }

  void login() {
    if (loginController.text.isEmpty ||
        loginPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter credentials")),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Login Successful")),
    );
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
                    physics: currentIndex >= 5
                        ? const NeverScrollableScrollPhysics()
                        : const BouncingScrollPhysics(),
                    itemCount: images.length,
                    onPageChanged: (index) {
                      setState(() => currentIndex = index);
                    },
                    itemBuilder: (context, index) {
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

                if (currentIndex < 5)
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
                              backgroundColor: Colors.grey[200],
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            onPressed: nextPage,
                            child: const Text(
                              "Next",
                              style: TextStyle(color: Colors.black),
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

  // 🔥 MAS MALAKING LOGO (FINAL FIX)
  Widget buildLogoHeader() {
    return Center(
      child: Image.asset(
        'images/logo.png',
        height: 44, // 🔥 FINAL SIZE (perfect match sa design)
        fit: BoxFit.contain,
      ),
    );
  }

  // ================= SIGN UP =================
  Widget buildSignUpPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 25),

          buildLogoHeader(),

          const SizedBox(height: 20),

          const Text("Sign Up",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),

          const SizedBox(height: 10),

          const Text(
            "Create an account to start planning\nwith your barkada!",
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 30),

          buildTextField("Name", nameController),
          buildTextField("Username", usernameController),
          buildTextField("Email", emailController),

          buildPasswordField(passwordController, () {
            setState(() => obscurePassword = !obscurePassword);
          }, obscurePassword),

          const SizedBox(height: 20),

          buildMainButton("Sign Up", signUp),

          const SizedBox(height: 20),

          buildDivider(),

          const SizedBox(height: 20),

          buildGoogleButton(),

          const SizedBox(height: 20),

          GestureDetector(
            onTap: () => goToPage(6),
            child: const Text("Already have an account? Log In"),
          )
        ],
      ),
    );
  }

  // ================= LOGIN =================
  Widget buildLoginPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 25),

          buildLogoHeader(),

          const SizedBox(height: 20),

          const Text("Log In",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),

          const SizedBox(height: 10),

          const Text(
            "Welcome Back!\nLet’s log in to your account.",
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 30),

          buildTextField("Username or Email", loginController),

          buildPasswordField(loginPasswordController, () {
            setState(() => obscureLoginPassword = !obscureLoginPassword);
          }, obscureLoginPassword),

          Row(
            children: [
              Checkbox(
                value: rememberMe,
                onChanged: (value) {
                  setState(() => rememberMe = value!);
                },
              ),
              const Text("Remember Me"),
            ],
          ),

          const SizedBox(height: 10),

          buildMainButton("Log In", login),

          const SizedBox(height: 20),

          buildDivider(),

          const SizedBox(height: 20),

          buildGoogleButton(),

          const SizedBox(height: 20),

          GestureDetector(
            onTap: () => goToPage(5),
            child: const Text("Don't have an account? Sign Up"),
          )
        ],
      ),
    );
  }

  // ================= REUSABLE =================
  Widget buildTextField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: "Enter your $label",
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15)),
          ),
        ),
        const SizedBox(height: 15),
      ],
    );
  }

  Widget buildPasswordField(
      TextEditingController controller, VoidCallback toggle, bool obscure) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Password"),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          obscureText: obscure,
          decoration: InputDecoration(
            hintText: "Enter your password",
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15)),
            suffixIcon: IconButton(
              icon: Icon(obscure
                  ? Icons.visibility_off
                  : Icons.visibility),
              onPressed: toggle,
            ),
          ),
        ),
        const SizedBox(height: 15),
      ],
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
              borderRadius: BorderRadius.circular(15)),
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

  Widget buildDivider() {
    return Row(
      children: const [
        Expanded(child: Divider()),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Text("or continue with"),
        ),
        Expanded(child: Divider()),
      ],
    );
  }
}