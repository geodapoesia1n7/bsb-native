// GENERATED CODE BY BUCKLESCRIPT VERSION 0.6.2 , PLEASE EDIT WITH CARE
'use strict';

var Caml_int64  = require("../caml_int64");
var Mt          = require("./mt");
var Block       = require("../block");
var Caml_string = require("../caml_string");

Mt.from_pair_suites("string_get_set_test.ml", /* :: */[
      /* tuple */[
        'File "string_get_set_test.ml", line 8, characters 4-11',
        function () {
          return /* Eq */Block.__(0, [
                    Caml_string.caml_string_get16("2\0", 0),
                    50
                  ]);
        }
      ],
      /* :: */[
        /* tuple */[
          'File "string_get_set_test.ml", line 9, characters 4-11',
          function () {
            return /* Eq */Block.__(0, [
                      Caml_string.caml_string_get16("20", 0),
                      12338
                    ]);
          }
        ],
        /* :: */[
          /* tuple */[
            'File "string_get_set_test.ml", line 10, characters 4-11',
            function () {
              return /* Eq */Block.__(0, [
                        Caml_string.caml_string_get32("0123", 0),
                        858927408
                      ]);
            }
          ],
          /* :: */[
            /* tuple */[
              'File "string_get_set_test.ml", line 11, characters 4-11',
              function () {
                return /* Eq */Block.__(0, [
                          Caml_string.caml_string_get32("0123", 0),
                          858927408
                        ]);
              }
            ],
            /* :: */[
              /* tuple */[
                'File "string_get_set_test.ml", line 12, characters 4-11',
                function () {
                  return /* Eq */Block.__(0, [
                            Caml_string.caml_string_get32("3210", 0),
                            808530483
                          ]);
                }
              ],
              /* :: */[
                /* tuple */[
                  'File "string_get_set_test.ml", line 13, characters 4-11',
                  function () {
                    return /* Eq */Block.__(0, [
                              Caml_int64.get64("12345678", 0),
                              /* int64 */[
                                /* hi */943142453,
                                /* lo */875770417
                              ]
                            ]);
                  }
                ],
                /* :: */[
                  /* tuple */[
                    'File "string_get_set_test.ml", line 14, characters 4-11',
                    function () {
                      return /* Eq */Block.__(0, [
                                Caml_int64.get64("87654321", 0),
                                /* int64 */[
                                  /* hi */825373492,
                                  /* lo */892745528
                                ]
                              ]);
                    }
                  ],
                  /* [] */0
                ]
              ]
            ]
          ]
        ]
      ]
    ]);

/*  Not a pure module */
