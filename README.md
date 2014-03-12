declarative.bash
================
A simple library for declarative shell scripts
----------------

Ever wanted to have confidence that your shell programs would stay modular and componentized, even as they grow?

Ever wanted to add a plugin framework to your shell script, while keeping it simple?

Ever wanted to indulge your functional-programming side, even when writing code for OS-level automation?

Now you can!


Installation
============

Install into your `PATH`. Do not set the execute bit; instead, use the `source` builtin to incorporate the library's functions into your script.


Usage
=====

Break your script down into small functions. Before each function, use a `provides` line to list the variables or functionality provided by that function; inside each function, use a `needs` line to list the variables which need to be evaluated before invocation.

    #!/bin/bash
    #      ^^^^ important! /bin/sh scripts are NOT SUPPORTED

    source declarative.bash              # load the library

    is_not_empty() { [[ ${!1} ]]; }      # define any assertions

    declare_assertions varA varB -- is_not_empty # declare which variables your
                                                 # ...assertions apply to.

    provides function_name varA varB     # declare variables each function sets
    function_name() {
      declare -g varA varB               # ..declare those as globals
      needs varC varD                    # ..and declare which variables you consume
      # ... put your logic here ...
    }

Some points to note:

- While usage for `provides` and `needs` suggests using variable names for dependency names, and the provided leak checker whitelists any dependency names as global variables, it is not necessary to do so. For instance, anything which describes itself as providing tests could be invoked by a `needs tests` call, even if no `tests` variable exists.

- More than one function can define itself as providing the same feature / setting the same variable.  If this is the case, all defined setters will be invoked by a related `needs` call. A suggested use case for this is to allow "plugins" sourced in from configuration files to be run in addition to built-in functions.

- Loops are silently broken. If `A->B->C->A`, the `C->A` link will be discarded.

- If `DECLARATIVE_TEST_LEAKS` is set, any variables leaked into global scope by functions invoked via `needs` will be detected and reported. This is important, as all variables are global in bash unless explicitly declared otherwise; `local` or `declare` (without `-g`) must be used to prevent this behavior).

- If you make assertions about variables, these assertions will be checked after each function which declares that it writes to those variables. Be aware of the caveat this implies -- if multiple functions are used to build up a single variable, assertions will be enforced after each of them.

Requirements
============

- bash 4.1 or newer.
