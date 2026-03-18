import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

/// App sleek dark theme Auth Screen
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _loginFormKey = GlobalKey<FormState>();
  final _signupFormKey = GlobalKey<FormState>();

  // Controllers
  final _nameCtrl = TextEditingController();
  final _loginEmailCtrl = TextEditingController();
  final _loginPassCtrl = TextEditingController();
  final _signupEmailCtrl = TextEditingController();
  final _signupPassCtrl = TextEditingController();

  bool _loginObscure = true;
  bool _signupObscure = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameCtrl.dispose();
    _loginEmailCtrl.dispose();
    _loginPassCtrl.dispose();
    _signupEmailCtrl.dispose();
    _signupPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
  if (!_loginFormKey.currentState!.validate()) return;

  final auth = context.read<AuthService>();

  bool success = await auth.login(
    _loginEmailCtrl.text.trim(),
    _loginPassCtrl.text,
  );

  if (!mounted) return;

  if (success) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Login successful 🚀"),
        backgroundColor: Colors.green,
      ),
    );

    // 👉 Navigate to home screen
    // Navigator.pushReplacement(...)
  } else if (auth.error != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(auth.error!),
        backgroundColor: Colors.red,
      ),
    );
  }
}

  Future<void> _signup() async {
  if (!_signupFormKey.currentState!.validate()) return;

  final auth = context.read<AuthService>();

  bool success = await auth.signup(
    _nameCtrl.text.trim(),
    _signupEmailCtrl.text.trim(),
    _signupPassCtrl.text,
  );

  if (!mounted) return;

  if (success) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Signup successful 🎉"),
        backgroundColor: Colors.green,
      ),
    );

    // 👉 OPTIONAL: switch to login tab
    _tabController.animateTo(0);
  } else if (auth.error != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(auth.error!),
        backgroundColor: Colors.red,
      ),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Overall deep dark background
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 900;
          if (isWide) {
            return Row(
              children: [
                Expanded(child: _buildHeroSection()),
                Expanded(child: _buildAuthSection()),
              ],
            );
          }
          return SingleChildScrollView(
            child: Column(
              children: [
                _buildHeroSection(isMobile: true),
                _buildAuthSection(isMobile: true),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeroSection({bool isMobile = false}) {
    return Container(
      constraints: BoxConstraints(minHeight: isMobile ? 400 : double.infinity),
      decoration: const BoxDecoration(
        color: Color(0xFF0A0F1F),
        // A subtle grid background could be achieved with a CustomPaint or Stacked transparent SVG.
        // For simplicity, we stick to a deep dark radial gradient.
        gradient: RadialGradient(
          center: Alignment.topLeft,
          radius: 1.5,
          colors: [Color(0xFF131D3A), Color(0xFF090C15)],
        ),
      ),
      padding: EdgeInsets.all(isMobile ? 32 : 64),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Logo
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.blueAccent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const ImageIcon(
                    AssetImage('assets/logo/logoApp_rm.png'),
                    color: Colors.white,
                    size: 50),
              ),
              const SizedBox(width: 12),
              Text(
                'APIForge',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Main Headline
          Text(
            'Build better APIs,\nfaster with AI.',
            style: GoogleFonts.inter(
              fontSize: isMobile ? 36 : 48,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Automate your testing workflow, generate\ndocumentation instantly, and catch bugs before\nthey deploy.',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: const Color(0xFF94A3B8), // slate-400
              height: 1.5,
            ),
          ),
          const SizedBox(height: 48),

          // Testimonial
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF334155).withOpacity(0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: List.generate(
                    5,
                    (index) => const Icon(Icons.star, color: Colors.blueAccent, size: 16),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '"APIForge has completely transformed how our team handles endpoint testing. The AI suggestions are uncannily accurate."',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: const Color(0xFFE2E8F0),
                    fontStyle: FontStyle.italic,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.blueGrey.shade800,
                      child: const Icon(Icons.person, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Aniket Kumar, Anchit Sharma",
                          style: GoogleFonts.abhayaLibre(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          // Footer Links
          if (!isMobile)
            Row(
              children: [
                _buildFooterLink('Terms'),
                const SizedBox(width: 24),
                _buildFooterLink('Privacy'),
                const SizedBox(width: 24),
                _buildFooterLink('Docs'),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildFooterLink(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        color: const Color(0xFF64748B),
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildAuthSection({bool isMobile = false}) {
    return Container(
      color: const Color(0xFF0F172A),
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 32 : 80, vertical: 64),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _tabController.index == 0 ? 'Welcome back' : 'Create an account',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _tabController.index == 0
                    ? 'Enter your credentials to access your workspace.'
                    : 'Sign up to start automating your workflows today.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: const Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 48),

              // Custom Header Tabs without standard indicator
              Theme(
                data: Theme.of(context).copyWith(
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                ),
                child: TabBar(
                  controller: _tabController,
                  dividerColor: Colors.transparent,
                  indicatorWeight: 3,
                  indicatorColor: Colors.blueAccent,
                  labelColor: Colors.white,
                  unselectedLabelColor: const Color(0xFF64748B),
                  labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  onTap: (_) => setState(() {}),
                  tabs: const [
                    Tab(text: 'Login'),
                    Tab(text: 'Sign Up'),
                  ],
                ),
              ),
              // Forms inside expanded
              SizedBox(
                height: _tabController.index == 0 ? 350 : 380,
                child: TabBarView(
                  controller: _tabController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildLoginForm(),
                    _buildSignupForm(),
                  ],
                ),
              ),

              const Spacer(),

              const SizedBox(height: 32),


              const Spacer(),
              if (!isMobile)
                Center(
                  child: Text(
                    '© 2024 APIForge Inc.',
                    style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _loginFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildInputField(
            label: 'Email address',
            controller: _loginEmailCtrl,
            hint: 'name@company.com',
            icon: CupertinoIcons.mail,
            type: TextInputType.emailAddress,
            validator: (v) => (v?.contains('@') == true) ? null : 'Enter valid email',
          ),
          const SizedBox(height: 20),
          _buildInputField(
            label: 'Password',
            controller: _loginPassCtrl,
            hint: 'Enter your password',
            icon: CupertinoIcons.lock_fill,
            isObscure: _loginObscure,
            hasToggle: true,
            validator: (v) => (v?.length ?? 0) >= 6 ? null : 'Min 6 chars',
            onToggle: () => setState(() => _loginObscure = !_loginObscure),
          ),
          const SizedBox(height: 32),
          Consumer<AuthService>(
            builder: (_, auth, __) => _buildPrimaryButton(
              text: 'Sign in to Workspace',
              isLoading: auth.isLoading,
              onPressed: _login,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignupForm() {
    return Form(
      key: _signupFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildInputField(
            label: 'Name',
            controller: _nameCtrl,
            hint: 'Alex Chen',
            icon: CupertinoIcons.person_fill,
            validator: (v) => (v?.length ?? 0) >= 2 ? null : 'Min 2 chars',
          ),
          const SizedBox(height: 20),
          _buildInputField(
            label: 'Email address',
            controller: _signupEmailCtrl,
            hint: 'name@company.com',
            icon: CupertinoIcons.mail,
            type: TextInputType.emailAddress,
            validator: (v) => (v?.contains('@') == true) ? null : 'Enter valid email',
          ),
          const SizedBox(height: 20),
          _buildInputField(
            label: 'Password',
            controller: _signupPassCtrl,
            hint: 'Choose a strong password',
            icon: CupertinoIcons.lock_fill,
            isObscure: _signupObscure,
            hasToggle: true,
            validator: (v) => (v?.length ?? 0) >= 6 ? null : 'Min 6 chars',
            onToggle: () => setState(() => _signupObscure = !_signupObscure),
          ),
          const SizedBox(height: 32),
          Consumer<AuthService>(
            builder: (_, auth, __) => _buildPrimaryButton(
              text: 'Create account',
              isLoading: auth.isLoading,
              onPressed: _signup,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isObscure = false,
    bool hasToggle = false,
    VoidCallback? onToggle,
    TextInputType type = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
            if (hasToggle && _tabController.index == 0)
              Text('Forgot password?', style: GoogleFonts.inter(color: Colors.blueAccent, fontSize: 13, fontWeight: FontWeight.w500)), // Simple placeholder
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: isObscure,
          keyboardType: type,
          style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 14),
            prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 18),
            suffixIcon: hasToggle
                ? IconButton(
                    icon: Icon(isObscure ? CupertinoIcons.eye_fill : CupertinoIcons.eye_slash_fill, color: const Color(0xFF64748B), size: 18),
                    onPressed: onToggle,
                  )
                : null,
            filled: true,
            fillColor: const Color(0xFF1E293B).withOpacity(0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF334155)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF334155)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.blueAccent),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.red.shade400),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildPrimaryButton({
    required String text,
    required bool isLoading,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2563EB), // Primary Blue
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Text(
              text,
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
            ),
    );
  }
}
