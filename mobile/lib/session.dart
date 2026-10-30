import 'package:flutter/foundation.dart';

import 'models/auth_user.dart';

final ValueNotifier<AuthUser?> currentUser = ValueNotifier<AuthUser?>(null);