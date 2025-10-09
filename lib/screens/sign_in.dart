import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/repo/auth_repository.dart';
import '../widgets/custom_textfield.dart';
import '../widgets/screen_util.dart';
import 'forgot_password.dart';

class SignIn extends StatefulWidget {
  const SignIn({Key? key}) : super(key: key);

  @override
  State<SignIn> createState() => _SignInState();
}

class _SignInState extends State<SignIn> {
  final controller = Get.find<AuthRepository>();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool isHiddenPassword = true;

  void _togglePasswordView() {
    setState(() {
      isHiddenPassword = !isHiddenPassword;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      WidgetsBinding.instance!.addPostFrameCallback((_) {
        if (controller.status == Status.Error) {
          ScreenUtils.showAlertDialog(
              context,
              "Login Failed",
              controller.errorMessage.length > 60
                  ? 'Login failed, please try again!'
                  : controller.errorMessage);
          controller.updateStatus(Status.Empty);
        } else if (controller.status == Status.Unknown_Error) {
          ScreenUtils.showAlertDialog(
              context,
              "Login Failed",
              controller.errorMessage.length > 60
                  ? 'Login failed, please try again!'
                  : controller.errorMessage);
          controller.updateStatus(Status.Empty);
        }
      });
      return Scaffold(
          backgroundColor: Colors.white,
          body: SingleChildScrollView(
            child: Form(
                key: _formKey,
                child: Column(children: [
                  SizedBox(height: MediaQuery.of(context).size.height / 5),
                  Center(
                    child: Image.asset(
                      'assets/logo.png',
                      height: 100,
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height / 7),
                  const Text(
                    'Sign in to your account',
                    style: TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'PoppinsSemiBold'),
                  ),
                  const SizedBox(height: 20),
                  CustomTextField(
                    label: 'Username Address',
                    hint: 'John Doe',
                    textEditingController: controller.emailController,
                   
                   
                  ),
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.01,
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: MediaQuery.of(context).size.height * 0.03,
                    ),
                    child: TextFormField(
                      autofocus: true,
                      controller: controller.passwordController,
                      obscureText: isHiddenPassword,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        fillColor: const Color(0xffF2F2F2),
                        filled: true,
                        isDense: true,
                        suffixIcon: InkWell(
                          onTap: _togglePasswordView,
                          child: Icon(
                            isHiddenPassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: isHiddenPassword
                                ? Colors.grey.withOpacity(0.5)
                                : Colors.blue,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                            borderSide:
                                const BorderSide(color: Colors.grey, width: 1),
                            borderRadius: BorderRadius.circular(10)),
                        enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide.none,
                            borderRadius: BorderRadius.circular(10)),
                        border: const OutlineInputBorder(
                            borderSide:
                                BorderSide(color: Colors.grey, width: 2),
                            borderRadius:
                                BorderRadius.all(Radius.circular(10))),
                        label: const Text('Password'),
                        hintText: 'Password',
                        labelStyle: Theme.of(context)
                            .textTheme
                            .headline4!
                            .copyWith(
                                color: Colors.grey.withOpacity(0.5),
                                fontFamily: 'PoppinsRegular',
                                fontWeight: FontWeight.bold,
                                fontSize: 14),
                        hintStyle:
                            Theme.of(context).textTheme.headline4!.copyWith(
                                  color: Colors.grey.withOpacity(0.5),
                                  fontFamily: 'PoppinsRegular',
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      validator: (String? value) {
                        if (value!.isEmpty) {
                          return 'enter your password';
                        }
                        return null;
                      },
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(
                      right: MediaQuery.of(context).size.height * 0.03,
                    ),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Get.to(() => const ForgotPassword());
                        },
                        child: const Text(
                          'Forgot your password?',
                          style: TextStyle(
                              color: Colors.blue,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'PoppinsRegular'),
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      if (_formKey.currentState!.validate()) {
                        print(controller.emailController.text);
                        print(controller.passwordController.text);
                        controller.login(
                          controller.emailController.text,
                          controller.passwordController.text,
                        );
                      }
                    },
                    child: Container(
                        height: 55,
                        margin: EdgeInsets.symmetric(
                          horizontal: MediaQuery.of(context).size.height * 0.03,
                        ),
                        decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(10)),
                        child: Center(
                          child: (controller.status == Status.Loading)
                              ? Container(
                                  child: const CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Sign In',
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
    });
  }
}
