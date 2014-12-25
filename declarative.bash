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

declare -A _declarative_assertions_for_var

declare -A _declarative_leak_test_data

# callback; override me to change behavior
_declarative_leak_detected() {
    echo "ERROR: Leak detected: function $1 leaks definition $2" >&2
}

_declarative_assertion_failed() {
    echo "ERROR: Assertion $1 about variable $2 failed after invoking $3 with status $4" >&2
    exit 1
}

_declarative_run_assertions_for_var() {
    local func_name var_name assertion assertion_retval
    local -a assertions_to_run
    var_name=$1
    func_name=$2
    eval "assertions_to_run=( ${_declarative_assertions_for_var[$var_name]} )"
    for assertion in "${assertions_to_run[@]}"; do
        if [[ $DECLARATIVE_TEST_LEAKS ]]; then
            _declarative_leak_test "$assertion" "$var_name"
        else
            "$assertion" "$var_name"
        fi
        assertion_retval=$?
        if (( assertion_retval != 0 )); then
            _declarative_assertion_failed "$assertion" "$var_name" "$func_name" "$assertion_retval"
        fi
    done
}

_declarative_run_assertions_for_func() {
    local func_name var_name
    local -a vars_to_check
    for func_name; do
        eval "vars_to_check=( ${_declarative_providees[$func_name]} )"
        for var_name in "${vars_to_check[@]}"; do
            _declarative_run_assertions_for_var "$var_name" "$func_name"
        done
    done
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
    local func_name=$1; shift
    local var_name
    local quoted_func_name
    printf -v quoted_func_name '%q' "$func_name"

    for var_name; do
        : "var_name=$var_name"
        _declarative_providers[$var_name]+=" $quoted_func_name"
    done
    printf -v "_declarative_providees[$func_name]" '%q ' "$@"
}

needs() {
    local var_name func_name retval
    local -a pending_funcs
    retval=0
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
            (( retval |= $? ))
            _declarative_run_assertions_for_func "$func_name"
        done
    done
    return "$retval"
}

declare_assertions() {
    local -a vars=()
    local var_name assertion_name quoted_assertion_name
    while [[ $1 != -- ]]; do
        vars+=( "$1" )
        shift
    done
    [[ $1 = -- ]] && shift
    for var_name in "${vars[@]}"; do
        for assertion_name; do
            printf -v quoted_assertion_name '%q' "$assertion_name"
            for assertion_name; do
                : assertion_name="$assertion_name"
                _declarative_assertions_for_var[$var_name]+=" $quoted_assertion_name"
            done
        done
    done
}
