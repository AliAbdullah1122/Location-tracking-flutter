import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../services/repo/auth_repository.dart';
import '../widgets/custom_textfield.dart';

class Profile extends StatefulWidget {
  const Profile({Key? key}) : super(key: key);

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  String? fName, lName;
  final controller = Get.find<AuthRepository>();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final fNameController = TextEditingController();
  final lNameController = TextEditingController();
  File? image;

  void _clearImage() {
    image = null;
  }

  Future pickImageFromGallery() async {
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (image == null) return;
      final imageTemporary = File(image.path);
      print(imageTemporary);
      setState(
        () {
          this.image = imageTemporary;
        },
      );
    } on PlatformException catch (e) {
      print('$e');
    }
  }

  Future pickImageFromCamera() async {
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.camera);
      if (image == null) return;
      final imageTemporary = File(image.path);
      print(imageTemporary);
      setState(
        () {
          this.image = imageTemporary;
        },
      );
    } on PlatformException catch (e) {
      print('$e');
    }
  }

  @override
  void initState() {
    controller.startService();
    fName = controller.user!.fName;
    lName = controller.user!.lName;
    fNameController.text = fName!;
    lNameController.text = lName!;
    print("${fName} $lName");
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              SizedBox(height: MediaQuery.of(context).size.height / 5),
              Container(
                child: Stack(children: [
                  Container(
                    height: 200,
                    width: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey,
                      image: image != null
                          ? DecorationImage(
                              image: FileImage(image!), fit: BoxFit.cover)
                          : controller.user!.image! == null
                              ? DecorationImage(
                                  image: AssetImage('assets/logo.png'))
                              : DecorationImage(
                                  image: NetworkImage(controller.user!.image!)),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 20,
                    child: InkWell(
                      onTap: () {
                        Get.bottomSheet(Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16.0),
                                topRight: Radius.circular(16.0)),
                          ),
                          child: Wrap(
                            alignment: WrapAlignment.end,
                            crossAxisAlignment: WrapCrossAlignment.end,
                            children: [
                              ListTile(
                                leading: Icon(Icons.camera),
                                title: Text('Camera'),
                                onTap: () {
                                  Get.back();
                                  pickImageFromCamera();
                                },
                              ),
                              ListTile(
                                leading: Icon(Icons.image),
                                title: Text('Gallery'),
                                onTap: () {
                                  Get.back();
                                  pickImageFromGallery();
                                },
                              ),
                            ],
                          ),
                        ));
                      },
                      child: image != null
                          ? InkWell(
                              onTap: () {
                                setState(() {
                                  _clearImage();
                                });
                              },
                              child: Container(
                                  height: 50,
                                  width: 50,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.blue,
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.close,
                                      size: 20,
                                      color: Colors.white,
                                    ),
                                  )),
                            )
                          : Container(
                              height: 50,
                              width: 50,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.blue,
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.edit,
                                  size: 20,
                                  color: Colors.white,
                                ),
                              )),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 20),
              CustomTextField(
                label: 'First Name',
                hint: 'John Doe',
                textEditingController: fNameController,
              ),
              CustomTextField(
                label: 'Last Name',
                hint: 'John Doe',
                textEditingController: lNameController,
              ),
              const SizedBox(height: 20),
              Obx(() {
                return InkWell(
                  onTap: () {
                    if (_formKey.currentState!.validate()) {
                      print(fName);
                      print(lName);

                      if (image == null) {
                        print('no image selected');
                        controller.updateProfile(
                            fNameController.text, lNameController.text);
                      } else {
                        print('File: ${image!.path}');
                        controller.updateUserProfile(fNameController.text,
                            lNameController.text, image!.path);
                      }
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
                      child: Center(
                        child: (controller.updateProfileStatus ==
                                UpdateProfileStatus.Loading)
                            ? const SizedBox(
                                height: 30,
                                width: 30,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            : Text(
                                'Submit',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontFamily: 'PoppinsRegular',
                                    fontWeight: FontWeight.bold),
                              ),
                      )),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
