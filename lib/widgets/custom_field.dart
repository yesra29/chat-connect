import 'package:flutter/material.dart';

class CustomField extends StatelessWidget {
  final String hintText;
  final double height;

  const CustomField({super.key, required this.hintText, required this.height});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: TextFormField(
        validator: (value) {

        },
        decoration: InputDecoration(
            hintText: hintText, border: const OutlineInputBorder()),
      ),
    );
  }
}
