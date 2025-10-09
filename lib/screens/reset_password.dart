import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../widgets/custom_textfield.dart';
import 'nav_bar.dart';

class ResetPassword extends StatefulWidget {
  const ResetPassword({Key? key}) : super(key: key);

  @override
  State<ResetPassword> createState() => _ResetPasswordState();
}

class _ResetPasswordState extends State<ResetPassword> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool isHiddenPassword = true;

  void _togglePasswordView() {
    setState(() {
      isHiddenPassword = !isHiddenPassword;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.white,
        body: SingleChildScrollView(
          child: Form(
              key: _formKey,
              child: Column(children: [
                SizedBox(height: MediaQuery.of(context).size.height / 5),
                const Text(
                  'Enter your email below and we will send you a reset email',
                  style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'PoppinsSemiBold'),
                ),
                const SizedBox(height: 20),
                const CustomTextField(
                  label: 'Email Address',
                  hint: 'johndoe@yourmail.com',
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () {
                    if (_formKey.currentState!.validate()) {
                      Get.offAll(() => const HomeNavigation());
                    }
                  },
                  child: Container(
                      height: 55,
                      margin: EdgeInsets.symmetric(
                          horizontal:
                              MediaQuery.of(context).size.height * 0.03),
                      decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(10)),
                      child: const Center(
                        child: Text(
                          'Submit',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontFamily: 'PoppinsRegular',
                              fontWeight: FontWeight.bold),
                        ),
                      )),
                ),
                const SizedBox(height: 20),
              ])),
        ));
  }
}
