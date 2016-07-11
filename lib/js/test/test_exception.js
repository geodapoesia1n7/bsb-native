// GENERATED CODE BY BUCKLESCRIPT VERSION 0.8.0 , PLEASE EDIT WITH CARE
'use strict';

var Caml_builtin_exceptions = require("../caml_builtin_exceptions");
var Caml_exceptions         = require("../caml_exceptions");
var Test_common             = require("./test_common");

var Local = Caml_exceptions.create("Test_exception.Local");

function f() {
  throw [
        Local,
        3
      ];
}

function g() {
  throw Caml_builtin_exceptions.not_found;
}

function h() {
  throw [
        Test_common.U,
        3
      ];
}

function x() {
  throw Test_common.H;
}

function xx() {
  throw [
        Caml_builtin_exceptions.invalid_argument,
        "x"
      ];
}

exports.Local = Local;
exports.f     = f;
exports.g     = g;
exports.h     = h;
exports.x     = x;
exports.xx    = xx;
/* No side effect */
