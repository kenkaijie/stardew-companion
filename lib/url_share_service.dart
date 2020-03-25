import 'package:share/share.dart';

import 'bloc_base.dart';

abstract class IStringSharingService extends BlocBase {

  Future<void> shareString(String message);

}

class StringSharingService implements IStringSharingService {

  @override
  Future<void> shareString(String message) async {
    await Share.share(message);
  }

  void dispose() {

  }

}