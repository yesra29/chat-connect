import 'package:flutter/material.dart';
import 'package:tuneup_task/const.dart';
import 'package:tuneup_task/services/alert_service.dart';
import 'package:tuneup_task/services/auth_service.dart';
import 'package:tuneup_task/services/navigation_service.dart';
import 'package:tuneup_task/widgets/custom_field.dart';
import 'package:get_it/get_it.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final GetIt getIt = GetIt.instance;
  final GlobalKey<FormState> _loginFormKey = GlobalKey();
  late AuthService _authService;
  late NavigationService _navigationService;
  late AlertService _alertService;
  String? email, password;

  @override
  void initState() {
    super.initState();
    _authService = getIt.get<AuthService>();
    _navigationService = getIt.get<NavigationService>();
    _alertService = getIt.get<AlertService>();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.white,
      body: _buildUI(),
    );
  }

  Widget _buildUI() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _headerText(),
            _loginForm(),
            _createAccountLink(),
          ],
        ),
      ),
    );
  }

  Widget _headerText() {
    return SizedBox(
      width: MediaQuery.sizeOf(context).width,
      child: const Column(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Hi, Welcome Back!",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          Text(
            "Hello again, you have been missed",
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w500, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _loginForm() {
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.40,
      margin: EdgeInsets.symmetric(
          vertical: MediaQuery.sizeOf(context).height * 0.05),
      child: Form(
          key: _loginFormKey,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CustomField(
                height: MediaQuery.sizeOf(context).height * 0.1,
                hintText: "Email",
                validationRegEx: EMAIL_VALIDATOR_REGEX,
                onSaved: (value) {
                  setState(() {
                    email = value;
                  });
                },
              ),
              CustomField(
                height: MediaQuery.sizeOf(context).height * 0.1,
                hintText: "Password",
                validationRegEx: PASSWORD_VALIDATOR_REGEX,
                obscureText: true,
                onSaved: (value) {
                  setState(() {
                    password = value;
                  });
                },
              ),
              _loginButton(),
            ],
          )),
    );
  }

  Widget _loginButton() {
    return SizedBox(
      width: MediaQuery.sizeOf(context).width,
      child: MaterialButton(
        onPressed: () async {
          if (_loginFormKey.currentState?.validate() ?? false) {
            _loginFormKey.currentState?.save();
            AuthResult result = await _authService.login(email!, password!);
            if (result == AuthResult.success) {
              _navigationService.pushReplacementNamed("/home");
            } else {
              String errorMessage = _getErrorMessage(result);
              _alertService.showToast(
                text: errorMessage,
                icon: Icons.error,
              );
            }
          }
        },
        color: Theme.of(context).colorScheme.primary,
        child: const Text(
          "Login",
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  String _getErrorMessage(AuthResult result) {
    switch (result) {
      case AuthResult.invalidEmail:
        return "Invalid email address";
      case AuthResult.userDisabled:
        return "This account has been disabled";
      case AuthResult.userNotFound:
        return "No account found with this email";
      case AuthResult.wrongPassword:
        return "Incorrect password";
      case AuthResult.operationNotAllowed:
        return "This operation is not allowed";
      default:
        return "Failed to login, Please try again!";
    }
  }

  Widget _createAccountLink() {
    return Expanded(
        child: Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Text(
          "Don't have an account?",
        ),
        GestureDetector(
          onTap: () {
            _navigationService.pushNamed("/register");
          },
          child: const Text(
            "Sign Up?",
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ));
  }
}
