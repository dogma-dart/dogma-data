// Copyright (c) 2015, the Dogma Project Authors.
// Please see the AUTHORS file for details. All rights reserved.
// Use of this source code is governed by a zlib license that can be found in
// the LICENSE file.

library dogma_data.test.test_mirrors;

import 'package:dogma_data/mirrors.dart';

import 'test_suite.dart' as suite;

void main() {
  useMirrors();

  // Run the tests
  suite.runTests();
}