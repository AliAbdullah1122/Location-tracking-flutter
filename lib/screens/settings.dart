// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:prismatic_app/screens/forgot_password.dart';
// import 'package:prismatic_app/screens/profile.dart';
// import 'package:prismatic_app/screens/reset_password.dart';
// import '../services/repo/auth_repository.dart';
// import '../widgets/alert_dialog.dart';

// class Settings extends StatefulWidget {
//   const Settings({Key? key}) : super(key: key);

//   @override
//   State<Settings> createState() => _SettingsState();
// }

// class _SettingsState extends State<Settings> {
//   final controller = Get.find<AuthRepository>();

//   @override
//   void initState() {
//     controller.startService();
//     super.initState();
//   }

//   @override
//   void dispose() {
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       body: SafeArea(
//         child: Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 30.0),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               const SizedBox(height: 40),
//               InkWell(
//                   onTap: () {
//                     Get.to(() => const ResetPassword());
//                   },
//                   child: const BuildSettings(name: 'Change Password')),
//               const SizedBox(height: 30),
//               InkWell(
//                   onTap: () {
//                     controller.logout();
//                   },
//                   child: const BuildSettings(name: 'Update Profile')),
//               const SizedBox(height: 30),
//               // const BuildSettings(name: 'Privacy & Policy'),
//               // const SizedBox(height: 30),
//               // const BuildSettings(name: 'Help'),
//               // const SizedBox(height: 30),
//               InkWell(
//                 onTap: () async {
//                   print('logging out');
//                   final action = await AlertDialogs.yesCancelDialog(
//                       context, 'Logout', 'are you sure ?');
//                   if (action == DialogsAction.yes) {
//                     controller.logout();
//                   } else {
//                     return;
//                   }
//                 },
//                 child: Container(
//                   padding: const EdgeInsets.only(right: 10),
//                   child: const Text(
//                     'Logout',
//                     style: TextStyle(
//                         color: Colors.grey, fontWeight: FontWeight.bold),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// class BuildSettings extends StatelessWidget {
//   final String? name;
//   const BuildSettings({Key? key, this.name}) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       children: [
//         Text(
//           name!,
//           style:
//               const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
//         ),
//         const Icon(Icons.arrow_forward_ios, color: Colors.grey)
//       ],
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/repo/auth_repository.dart';

class Settings extends StatefulWidget {
  const Settings({Key? key}) : super(key: key);

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  final controller = Get.find<AuthRepository>();

  @override
  void initState() {
    controller.startService();
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),

              // You can keep or add other visible options here.
              // Example:
              // const BuildSettings(name: 'Privacy & Policy'),
              // const SizedBox(height: 30),
              // const BuildSettings(name: 'Help'),

              // 🔒 Hiding Change Password, Update Profile, and Logout
              // (You can re-enable later if needed)
            ],
          ),
        ),
      ),
    );
  }
}

class BuildSettings extends StatelessWidget {
  final String? name;
  const BuildSettings({Key? key, this.name}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          name!,
          style:
              const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
        ),
        const Icon(Icons.arrow_forward_ios, color: Colors.grey)
      ],
    );
  }
}
