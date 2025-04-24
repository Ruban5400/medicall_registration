import 'package:flutter/material.dart';

class CustomTextFieldDesign extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final FocusNode? focusNode;

  const CustomTextFieldDesign({
    super.key,
    required this.label,
    required this.controller,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          SizedBox(
            width: MediaQuery.sizeOf(context).width * .5,
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                labelText: label,
                border: OutlineInputBorder(),
              ),
            ),
          )
        ],
      ),
    );
  }
}

