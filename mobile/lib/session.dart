import 'package:flutter/foundation.dart';

import 'models/auth_user.dart';

/// Pengguna yang sedang login (null = belum login).
final ValueNotifier<AuthUser?> currentUser = ValueNotifier<AuthUser?>(null);