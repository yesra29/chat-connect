import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:tuneup_task/const.dart';
import 'package:tuneup_task/services/auth_service.dart';
import 'package:tuneup_task/services/media_service.dart';
import 'package:tuneup_task/services/navigation_service.dart';
import 'package:tuneup_task/widgets/custom_field.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final GetIt _getIt = GetIt.instance;
  final GlobalKey<FormState> _registerFormKey = GlobalKey();
  late MediaService _mediaService;
  late AuthService _authService;
  late NavigationService _navigationService;
  String? email, password, name;
  File? selectedImage;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _mediaService = _getIt.get<MediaService>();
    _navigationService = _getIt.get<NavigationService>();
    _authService = _getIt.get<AuthService>();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
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
              if(!isLoading)_registerForm(),
              if(!isLoading)_loginAccountLink(),
            if(isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator(),))]),
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
            "Let's, get going!",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          Text(
            "Register ana ccount using the form below",
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w500, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _registerForm() {
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.60,
      margin: EdgeInsets.symmetric(
          vertical: MediaQuery.sizeOf(context).height * 0.05),
      child: Form(
        key: _registerFormKey,
        child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _profileSelection(),
              CustomField(
                  hintText: "Name",
                  height: MediaQuery.sizeOf(context).height * 0.1,
                  validationRegEx: NAME_VALIDATION_REGEX,
                  onSaved: (value) {
                    setState(() {
                      name = value;
                    });
                  }),
              CustomField(
                  hintText: "Email",
                  height: MediaQuery.sizeOf(context).height * 0.1,
                  validationRegEx: EMAIL_VALIDATOR_REGEX,
                  onSaved: (value) {
                    setState(() {
                      email = value;
                    });
                  }),
              CustomField(
                  hintText: "Password",
                  height: MediaQuery.sizeOf(context).height * 0.1,
                  validationRegEx: PASSWORD_VALIDATOR_REGEX,
                  obscureText: true,
                  onSaved: (value) {
                    setState(() {
                      password = value;
                    });
                  }),
              _registerButton(),
            ]),
      ),
    );
  }

  Widget _profileSelection() {
    return GestureDetector(
      onTap: () async {
        File? file = await _mediaService.getImageFromGallery();
        if (file != null) {
          setState(() {
            selectedImage = file;
          });
        }
      },
      child: Center(
        child: CircleAvatar(
          radius: MediaQuery.of(context).size.width * 0.15,
          backgroundImage: selectedImage != null
              ? FileImage(selectedImage!)
              : const NetworkImage(PLACEHOLDER_PFP) as ImageProvider,
        ),
      ),
    );
  }

  Widget _registerButton() {
    return SizedBox(
      width: MediaQuery.sizeOf(context).width,
      child: MaterialButton(
        color: Theme.of(context).colorScheme.primary,
        onPressed: () async{
          setState(() {
            isLoading= true;
          });
          try {
            if ((_registerFormKey.currentState?.validate() ?? false) && selectedImage != null) {
              _registerFormKey.currentState?.save();
              bool result = await _authService.signUp(email!, password!);
              if(result) {
                print(result);
              }
            }
          } catch (e) {
            print(e);
          }
          setState(() {
            isLoading=false;
          });
        },
        child: const Text(
          "Register",
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }


  Widget _loginAccountLink() {
    return Expanded(
        child: Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Text(
          "Already have an account?",
        ),
        GestureDetector(
          onTap: () {
            _navigationService.goBack();
          },
          child: const Text(
            "Login Up?",
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ));
  }
}
