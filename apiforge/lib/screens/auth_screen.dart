import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

/// Login and Signup screen with tab switching.
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
    await auth.login(_loginEmailCtrl.text.trim(), _loginPassCtrl.text);
    if (mounted && auth.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error!), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _signup() async {
    if (!_signupFormKey.currentState!.validate()) return;
    final auth = context.read<AuthService>();
    await auth.signup(_nameCtrl.text.trim(), _signupEmailCtrl.text.trim(),
        _signupPassCtrl.text);
    if (mounted && auth.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error!), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                const SizedBox(height: 32),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [cs.primary, cs.secondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: cs.primary.withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const ImageIcon(
                      AssetImage('assets/logo/logoApp_rm.png'),
                      color: Colors.white,
                      size: 50),
                ),
                const SizedBox(height: 20),
                Text('APIForge',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.primary,
                        )),
                const SizedBox(
                  height: 10,
                ),
                Text('Your developer API toolkit',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 40),

                // Tab bar
                Card(
                  child: Column(
                    children: [
                      TabBar(
                        controller: _tabController,
                        tabs: const [Tab(text: 'Login'), Tab(text: 'Sign Up')],
                      ),
                      SizedBox(
                        height: 320,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            // Login form
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Form(
                                key: _loginFormKey,
                                child: Column(
                                  children: [
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _loginEmailCtrl,
                                      keyboardType: TextInputType.emailAddress,
                                      decoration: const InputDecoration(
                                        labelText: 'Email',
                                        prefixIcon: Icon(CupertinoIcons.mail),
                                      ),
                                      validator: (v) =>
                                          (v?.contains('@') == true)
                                              ? null
                                              : 'Enter valid email',
                                    ),
                                    const SizedBox(height: 14),
                                    TextFormField(
                                      controller: _loginPassCtrl,
                                      obscureText: _loginObscure,
                                      decoration: InputDecoration(
                                        labelText: 'Password',
                                        prefixIcon:
                                            const Icon(CupertinoIcons.lock),
                                        suffixIcon: IconButton(
                                          icon: Icon(_loginObscure
                                              ? CupertinoIcons.eye_fill
                                              : CupertinoIcons.eye_slash_fill),
                                          onPressed: () => setState(() =>
                                              _loginObscure = !_loginObscure),
                                        ),
                                      ),
                                      validator: (v) => (v?.length ?? 0) >= 6
                                          ? null
                                          : 'Min 6 chars',
                                    ),
                                    const SizedBox(height: 40),
                                    Consumer<AuthService>(
                                      builder: (_, auth, __) => SizedBox(
                                        width: double.infinity,
                                        child: SizedBox(
                                          height: 45,
                                          child: ElevatedButton(
                                            onPressed:
                                                auth.isLoading ? null : _login,
                                            child: auth.isLoading
                                                ? const SizedBox(
                                                    height: 18,
                                                    width: 18,
                                                    child:
                                                        CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            color: Colors.white))
                                                : const Text('Login'),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Signup form
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Form(
                                key: _signupFormKey,
                                child: Column(
                                  children: [
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _nameCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Name',
                                        prefixIcon: Icon(CupertinoIcons.person),
                                      ),
                                      validator: (v) => (v?.length ?? 0) >= 2
                                          ? null
                                          : 'Min 2 chars',
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _signupEmailCtrl,
                                      keyboardType: TextInputType.emailAddress,
                                      decoration: const InputDecoration(
                                        labelText: 'Email',
                                        prefixIcon: Icon(CupertinoIcons.mail),
                                      ),
                                      validator: (v) =>
                                          (v?.contains('@') == true)
                                              ? null
                                              : 'Enter valid email',
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _signupPassCtrl,
                                      obscureText: _signupObscure,
                                      decoration: InputDecoration(
                                        labelText: 'Password',
                                        prefixIcon:
                                            const Icon(CupertinoIcons.lock),
                                        suffixIcon: IconButton(
                                          icon: Icon(_signupObscure
                                              ? CupertinoIcons.eye_fill
                                              : CupertinoIcons.eye_slash_fill),
                                          onPressed: () => setState(() =>
                                              _signupObscure = !_signupObscure),
                                        ),
                                      ),
                                      validator: (v) => (v?.length ?? 0) >= 6
                                          ? null
                                          : 'Min 6 chars',
                                    ),
                                    const SizedBox(height: 18),
                                    Consumer<AuthService>(
                                      builder: (_, auth, __) => SizedBox(
                                        width: double.infinity,
                                        child: SizedBox(
                                          height: 43,
                                          child: ElevatedButton(
                                            onPressed:
                                                auth.isLoading ? null : _signup,
                                            child: auth.isLoading
                                                ? const SizedBox(
                                                    height: 18,
                                                    width: 18,
                                                    child:
                                                        CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            color: Colors.white))
                                                : const Text('Create Account'),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
