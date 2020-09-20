// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// @dart = 2.7

import 'package:expect/expect.dart';

class Class<T> {
  Class();
}

main() {
  /*needsSignature*/
  local1a() {}

  /*needsSignature*/
  local1b() {}

  /*needsSignature*/
  local2(int i, String s) => i;

  Expect.isTrue(local1a.runtimeType == local1b.runtimeType);
  Expect.isFalse(local1a.runtimeType == local2.runtimeType);
  new Class();
}
