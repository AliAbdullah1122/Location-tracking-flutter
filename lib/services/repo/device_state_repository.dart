import 'package:get/get.dart';

class LifeCycleController extends SuperController {
  final _deviceState = "".obs;
  String get deviceState => _deviceState.value;
  @override
  void onDetached() {
    print('background');
    _deviceState('background');
  }

  @override
  void onInactive() {
    print('background');
    _deviceState('background');
  }

  @override
  void onPaused() {
    print('background');
    _deviceState('background');
  }

  @override
  void onResumed() {
    print('foreground');
    _deviceState('foreground');
  }
}
