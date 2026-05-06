import 'package:flutter/material.dart';
import '../home/home_page.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onSwitchToSignup;

  const LoginScreen({super.key, required this.onSwitchToSignup});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final user = TextEditingController();
  final pass = TextEditingController();

  bool obscure = true;
  bool rememberMe = false;

  void login() {
    if (user.text.isEmpty || pass.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter credentials")),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset("images/page7.png", fit: BoxFit.cover),
        ),
        Center(
          child: SingleChildScrollView(
            child: SizedBox(
              width: 300,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 170),

                  field("Username or Email", user),

                  passwordField(),

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

                  mainBtn("Log In", login),

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

                  OutlinedButton(
                    onPressed: () {},
                    child: const Text("Continue with Google"),
                  ),

                  const SizedBox(height: 15),

                  GestureDetector(
                    onTap: widget.onSwitchToSignup,
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

  Widget field(String hint, TextEditingController c) {
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

  Widget passwordField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: pass,
        obscureText: obscure,
        decoration: InputDecoration(
          hintText: "Password",
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          suffixIcon: IconButton(
            icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
            onPressed: () {
              setState(() => obscure = !obscure);
            },
          ),
        ),
      ),
    );
  }

  Widget mainBtn(String text, VoidCallback onPressed) {
    return SizedBox(
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
}