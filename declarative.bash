#!/bin/bash

# This is a library, not an executable script. The shebang exists mostly as an
# editor hint.  Expected usage is installation into a location on the PATH,
# such as /usr/local/bin, to allow ''source declarative.bash'' to be run
# without an explicit location.

## globals

# map global variable names to strings containing shell-escaped, eval-safe
# lists of functions providing or modifying those variables.
declare -A _declarative_providers

# maps function names to strings containing shell-escaped, eval-safe lists of
# variables they define. Used for leak testing.
declare -A _declarative_providees

# map containing names of vars and functions invoked by the declarative
# framework as keys.
declare -A _declarative_completed_funcs
declare -A _declarative_completed_vars

declare -A _declarative_leak_test_data

# callback; override me to change behavior
_declarative_leak_detected() {
    echo "ERROR: Leak detected: function $1 leaks definition $2" >&2
}

_declarative_leak_test() {
    local -A initial_vars=()
    local -A final_vars=()
    local -a declared_vars
    local varname
    local REPLY
    while read -r; do : "$REPLY"; initial_vars[$REPLY]=1; done < <(compgen -v)
    "$@"; local _declarative_leak_retval=$?
    while read -r; do : "$REPLY"; final_vars[$REPLY]=1; done < <(compgen -v)

    eval "declared_vars=( ${_declarative_providees[$1]} )"

    # declared variables get a pass
    for varname in "${declared_vars[@]}"; do
        unset "final_vars[$varname]"
    done

    local varname
    for varname in "${!final_vars[@]}"; do
        [[ ${initial_vars[$varname]} ]] && continue
        [[ ${_declarative_providers[$varname]} ]] && continue
        [[ $varname = _declarative_leak_* ]] && continue
        _declarative_leak_detected "$1" "$varname"
    done
    return "$_declarative_leak_retval"
}

provides() {
    local func_name=$1
    local var_name
    local quoted_func_name
    printf -v quoted_func_name "$func_name"

    for var_name; do
        : "var_name=$var_name"
        _declarative_providers[$var_name]+=" $quoted_func_name"
    done
    printf -v "_declarative_providees[$func_name]" '%q ' "$@"
}

needs() {
    local var_name func_name
    local -a pending_funcs
    for var_name; do
        : "var_name=$var_name"
        [[ ${_declarative_completed_vars[$var_name]} ]] && continue
        _declarative_completed_vars[$var_name]=1
        eval "pending_funcs=( ${_declarative_providers[$var_name]} )"
        for func_name in "${pending_funcs[@]}"; do
            : "func_name=$func_name"
            [[ ${_declarative_completed_funcs[$func_name]} ]] && continue
            _declarative_completed_funcs[$func_name]=1
            if [[ $DECLARATIVE_TEST_LEAKS ]]; then
                _declarative_leak_test "$func_name"
            else
                "$func_name"
            fi
        done
    done
}
