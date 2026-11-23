/*  run_tests.pl -- run the 200 Prologshell input/output pairs.

    swipl tests/run_tests.pl            (from the repository root)

    Every pair runs in a fresh sandbox, once through sh/2 and, if
    Starlog is installed, once more as the Starlog goal  X is Chain.
    Exits 0 only if every run gives exactly the expected output.
*/

:- initialization(main, main).

:- prolog_load_context(directory, D),
   file_directory_name(D, Root),
   directory_file_path(Root, prolog, Lib),
   asserta(user:file_search_path(library, Lib)),
   asserta(user:prologshell_root(Root)).

:- use_module(library(prologshell)).
:- use_module(fixture).
:- use_module(io_pairs).

:- dynamic starlog_mode/0.

main :-
    prologshell_root(Root),
    setup_env(Root),
    directory_file_path(Root, 'tests/sandbox', Box),
    (   catch(use_module(library(starlog)), _, fail),
        prologshell_starlog
    ->  assertz(starlog_mode), Modes = [sh, starlog]
    ;   Modes = [sh]
    ),
    findall(C-E, io(C, E), Pairs),
    length(Pairs, N),
    format("Prologshell: ~w input/output pairs, modes ~w~n", [N, Modes]),
    working_directory(Old, Old),
    findall(F, ( nth1(I, Pairs, C-E), member(M, Modes),
                 \+ run_pair(Box, M, I, C, E), F = I-M ), Fails),
    working_directory(_, Old),
    delete_directory_and_contents(Box),
    length(Fails, NF),
    length(Modes, NM),
    Total is N * NM,
    Passed is Total - NF,
    format("~w/~w runs passed~n", [Passed, Total]),
    (   NF =:= 0 -> halt(0) ; halt(1) ).

setup_env(Root) :-
    directory_file_path(Root, 'tests/fake_bin', Bin),
    directory_file_path(Root, prolog, Lib),
    getenv('PATH', P0),
    atomic_list_concat([Bin, ':', P0], P),
    setenv('PATH', P),
    setenv('PROLOGSHELL_LIB', Lib),
    setenv('PROLOGSHELL_TEST', yes).

run_pair(Box, Mode, I, Chain, Expected) :-
    working_directory(_, '/'),
    make_sandbox(Box),
    working_directory(_, Box),
    (   catch(eval(Mode, Chain, Out0), Err, Out0 = error(Err))
    ->  Out = Out0
    ;   Out = failed
    ),
    (   Out == Expected
    ->  true
    ;   format("FAIL ~w [~w] ~q~n   expected ~q~n   got      ~q~n",
               [I, Mode, Chain, Expected, Out]),
        fail
    ).

eval(sh, Chain, Out) :-
    sh(Chain, Out).
eval(starlog, Chain, Out) :-          % as a file would: expand, call in user
    starlog_expand:expand_starlog_goal((Out is Chain), Goal),
    call(user:Goal).
