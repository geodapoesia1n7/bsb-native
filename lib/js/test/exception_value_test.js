// GENERATED CODE BY BUCKLESCRIPT VERSION 0.6.2 , PLEASE EDIT WITH CARE
'use strict';

var Caml_builtin_exceptions = require("../caml_builtin_exceptions");

function f() {
  throw Caml_builtin_exceptions.not_found;
}

function assert_f(x) {
  if (x <= 3) {
    throw [
          Caml_builtin_exceptions.assert_failure,
          [
            "exception_value_test.ml",
            9,
            12
          ]
        ];
  }
  return 3;
}

function hh() {
  throw Caml_builtin_exceptions.not_found;
}

exports.f        = f;
exports.assert_f = assert_f;
exports.hh       = hh;
/* No side effect */
