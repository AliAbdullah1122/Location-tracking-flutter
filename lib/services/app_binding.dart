import 'package:get/get.dart';
import 'package:prismatic_app/services/repo/timestamp_repository.dart';
import 'repo/auth_repository.dart';
import 'repo/device_state_repository.dart';

class AppBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(AuthRepository(), permanent: true);
    Get.put(LifeCycleController(), permanent: true);
    Get.put(TimeStampRepository(), permanent: true);
  }
}
