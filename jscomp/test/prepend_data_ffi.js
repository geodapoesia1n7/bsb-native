'use strict';


var v1 = {
  stdio: "inherit",
  v: 3
};

var v2 = {
  stdio: 1,
  v: 2
};

process.on("exit", function (exit_code) {
      return "" + exit_code;
    });

process.on(1, function () {
      return /* () */0;
    });

process.on(function (i) {
      return "" + i;
    }, "exit");

process.on(function (i) {
      return "" + i;
    }, 1);

xx(3, 3, "xxx", "a", "b");

function f(x) {
  x.xx(104, /* int array */[
        1,
        2,
        3
      ]);
  x.xx(105, 3, "xxx", /* int array */[
        1,
        2,
        3
      ]);
  x.xx(106, 3, "xxx", 1, 2, 3);
  x.xx(107, 3, "xxx", 0, "b", 1, 2, 3, 4, 5);
  x.xx(108, 3, "xxx", 0, "yyy", "b", 1, 2, 3, 4, 5);
  return /* () */0;
}

process.on("exit", function (exit_code) {
      console.log("error code: " + exit_code);
      return /* () */0;
    });

function register(p) {
  p.on("exit", function (i) {
        console.log(i);
        return /* () */0;
      });
  return /* () */0;
}

var config = {
  stdio: "inherit",
  cwd: "."
};

exports.v1       = v1;
exports.v2       = v2;
exports.f        = f;
exports.register = register;
exports.config   = config;
/*  Not a pure module */
