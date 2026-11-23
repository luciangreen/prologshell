/*  shellog_proofs.pl -- machine-checked properties of Shellog.

    swipl proofs/shellog_proofs.pl      (from the repository root)

    Each theorem is a universally quantified property.  The general
    argument (by structural induction) is in PROOFS.md; here every
    theorem is checked exhaustively over a bounded domain, so a
    counterexample anywhere in that domain would be found.

    Domain D: every list of 0..4 lines drawn from
              ["", "a", "b", "ab", "b a", "A,b"]     (1555 lists)
    Counts    N in -1..6
    Strings   all strings of length 0..5 over {a, \n}
    Quoting   all strings of length 0..3 over {a, ', ", space, $, \, `}
*/

:- initialization(main, main).

:- prolog_load_context(directory, D),
   file_directory_name(D, Root),
   directory_file_path(Root, prolog, Lib),
   asserta(user:file_search_path(library, Lib)),
   asserta(user:shellog_root(Root)).

:- use_module(library(shellog)).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(aggregate)).
:- use_module(library(filesex)).

:- dynamic failed/1.

		 /*******************************
		 *            DOMAINS           *
		 *******************************/

atom_line(L) :- member(L, ["", "a", "b", "ab", "b a", "A,b"]).

line_list(Ls) :- between(0, 4, N), length(Ls, N), maplist(atom_line, Ls).

count(N) :- between(-1, 6, N).

nl_string(S) :-
    between(0, 5, N), length(Cs, N),
    maplist([C]>>member(C, [a, '\n']), Cs),
    string_chars(S, Cs).

quote_string(S) :-
    between(0, 3, N), length(Cs, N),
    maplist([C]>>member(C, [a, '\'', '"', ' ', '$', '\\', '`']), Cs),
    string_chars(S, Cs).

method(M) :- member(M, [tac, rev, sort_lines, sort_u, uniq, upper,
                        grep("a"), grep_v("b"), head_n(2), tail_n(1),
                        sed("a", "x"), tr("ab", "ba"), number_lines]).

		 /*******************************
		 *            HARNESS           *
		 *******************************/

%   theorem(+Name, +Generator, +Property)
%   Check Property for every solution of Generator.
theorem(Name, Gen0, Prop0) :-
    copy_term(Gen0-Prop0, Gen-Prop),       % theorems share no variables
    aggregate_all(count, Gen, Cases),
    (   forall(Gen, catch(Prop, _, fail))
    ->  format("  proved  ~w  (~D cases)~n", [Name, Cases])
    ;   once(( Gen, \+ catch(Prop, _, fail) )),
        format("  FAILED  ~w~n    counterexample: ~q~n", [Name, Gen]),
        assertz(failed(Name))
    ).

		 /*******************************
		 *           THEOREMS           *
		 *******************************/

main :-
    shellog_root(Root),
    format("Shellog proofs~n"),
    % --- the evaluator --------------------------------------------------
    theorem('T1  chains are associative: (A>>M1)>>M2 = A>>(M1>>M2)',
        ( line_list(L), method(M1), method(M2) ),
        ( sh((L >> M1) >> M2, X), sh(L >> (M1 >> M2), Y), X == Y )),
    theorem('T2  a chain is nested application: A>>M1>>M2 = M2(M1(A))',
        ( line_list(L), method(M1), method(M2) ),
        ( sh(L >> M1 >> M2, X), call_m(M1, L, V), call_m(M2, V, Y), X == Y )),
    theorem('T3  literals evaluate to themselves',
        line_list(L), ( sh(L, X), X == L )),
    % --- pipe values ----------------------------------------------------
    theorem('T4  lines(text(L)) = L',
        line_list(L), ( text(L, S), lines(S, L2), L2 == L )),
    theorem('T5  text(lines(S)) = S when S is "" or ends with a newline',
        ( nl_string(S), ( S == "" ; sub_string(S, _, 1, 0, "\n") ) ),
        ( lines(S, L), text(L, S2), S2 == S )),
    theorem('T6  lines is idempotent: lines(lines(X)) = lines(X)',
        nl_string(S), ( lines(S, L), lines(L, L2), L2 == L )),
    % --- involutions and idempotence ------------------------------------
    theorem('T7  tac is an involution', line_list(L),
        ( tac(L, A), tac(A, B), B == L )),
    theorem('T8  rev is an involution', line_list(L),
        ( rev(L, A), rev(A, B), B == L )),
    theorem('T9  sort_lines is an ordered permutation and idempotent', line_list(L),
        ( sort_lines(L, S), msort(L, S), sort_lines(S, S2), S2 == S )),
    theorem('T10 uniq is idempotent and uniq(sort_lines(L)) = sort_u(L)', line_list(L),
        ( uniq(L, U), uniq(U, U2), U2 == U,
          sort_lines(L, S), uniq(S, SU), sort_u(L, SU2), SU == SU2 )),
    theorem('T11 sort_r is the reverse of sort_lines', line_list(L),
        ( sort_r(L, R), sort_lines(L, S), reverse(S, R2), R == R2 )),
    % --- filters ----------------------------------------------------------
    theorem('T12 grep and grep_v partition the lines (as subsequences)',
        ( line_list(L), atom_line(P) ),
        ( grep(P, L, G), grep_v(P, L, V), interleave(L, G, V) )),
    theorem('T13 grep_c = wc_l . grep', ( line_list(L), atom_line(P) ),
        ( grep_c(P, L, C), grep(P, L, G), wc_l(G, C2), C =:= C2 )),
    theorem('T14 head_n(N) is a prefix of length min(max(N,0),len)',
        ( line_list(L), count(N) ),
        ( head_n(N, L, H), append(H, _, L), length(L, Len),
          length(H, K), K =:= max(0, min(N, Len)) )),
    theorem('T15 tail_n(N) is a suffix of length min(max(N,0),len)',
        ( line_list(L), count(N) ),
        ( tail_n(N, L, T), append(_, T, L), length(L, Len),
          length(T, K), K =:= max(0, min(N, Len)) )),
    theorem('T16 head_n(K) ++ tail_n(len-K) = L for 0 =< K =< len',
        ( line_list(L), length(L, Len), between(0, Len, K) ),
        ( head_n(K, L, H), J is Len - K, tail_n(J, L, T), append(H, T, L2), L2 == L )),
    theorem('T17 nth_line(I) = I-th line inside range, "" outside',
        ( line_list(L), count(I) ),
        ( nth_line(I, L, X), ( I >= 1, nth1(I, L, Y) -> X == Y ; X == "" ) )),
    theorem('T18 uniq_c run counts sum to wc_l', line_list(L),
        ( uniq_c(L, C), wc_l(L, N), foldl(add_run, C, 0, N2), N =:= N2 )),
    % --- transforms -------------------------------------------------------
    theorem('T19 sed(X, X) is the identity', ( line_list(L), atom_line(X), X \== "" ),
        ( sed(X, X, L, L2), L2 == L )),
    theorem('T20 sed(Old, New) is the identity when Old does not occur',
        ( line_list(L), atom_line(O), O \== "", grep(O, L, []) ),
        ( sed(O, "zz", L, L2), L2 == L )),
    theorem('T21 tr(F, F) and tr_d("") are the identity', line_list(L),
        ( tr("ab, ", "ab, ", L, L1), L1 == L, tr_d("", L, L2), L2 == L )),
    theorem('T22 upper/lower/rev/tr/sed/cut/number_lines keep the line count',
        ( line_list(L), member(M, [upper, lower, rev, trim, tr("a", "b"),
                                   sed("a", "bb"), cut(",", 2), number_lines]) ),
        ( call_m(M, L, R), length(L, N), length(R, N) )),
    theorem('T23 cut(D, 1) ++ D ++ cut(D, 2) rebuilds a line with one D',
        ( atom_line(A), atom_line(B), \+ sub_string(A, _, _, _, ","),
          \+ sub_string(B, _, _, _, ",") ),
        ( atomics_to_string([A, ",", B], Line),
          cut(",", 1, [Line], [X]), cut(",", 2, [Line], [Y]),
          X == A, Y == B )),
    theorem('T24 wc_c(L) = sum of line lengths + number of lines', line_list(L),
        ( wc_c(L, C), foldl([S, A0, A]>>(string_length(S, K), A is A0+K+1), L, 0, C2),
          C =:= C2 )),
    theorem('T25 xargs(M) = append of map(M) for line methods',
        ( line_list(L), member(M, [rev, upper, echo]) ),
        ( xargs(M, L, X), map(M, L, Ms), append(Ms, X2), X == X2 )),
    % --- files (in a scratch directory) -----------------------------------
    directory_file_path(Root, 'proofs/scratch', Box),
    (exists_directory(Box) -> delete_directory_and_contents(Box) ; true),
    make_directory_path(Box),
    directory_file_path(Box, 'f.txt', F),
    directory_file_path(Box, 'g.txt', G),
    theorem('T26 write_to then cat is the identity', line_list(L),
        ( write_to(F, L, _), cat(F, L2), L2 == L )),
    theorem('T27 append_to adds exactly the new lines at the end',
        ( line_list(L1), length(L1, N1), N1 =< 2, line_list(L2), length(L2, N2), N2 =< 2 ),
        ( write_to(F, L1, _), append_to(F, L2, _), cat(F, L), append(L1, L2, L3), L == L3 )),
    theorem('T28 size(write_to(L)) = wc_c(L)', line_list(L),
        ( write_to(F, L, _), size(F, S), wc_c(L, C), S =:= C )),
    theorem('T29 cp copies content and keeps the source', line_list(L),
        ( write_to(F, L, _), cp(G, F, T), atom_string(G, T), cat(G, LG), LG == L,
          exists(F, true) )),
    theorem('T30 mv moves content and removes the source', line_list(L),
        ( write_to(F, L, _), mv(G, F, _), cat(G, LG), LG == L,
          exists(F, false) )),
    theorem('T31 tee passes its input through and writes it', line_list(L),
        ( tee(F, L, Out), Out == L, cat(F, LF), LF == L )),
    theorem('T32 rm_r leaves nothing; mkdir then is_dir',
        member(Sub, ["d1", "d1/d2", "d1/d2/d3"]),
        ( directory_file_path(Box, Sub, P), mkdir(P, _), is_dir(P, true),
          directory_file_path(Box, "d1", Top), rm_r(Top, _), exists(Top, false) )),
    delete_directory_and_contents(Box),
    % --- quoting and servers ----------------------------------------------
    theorem('T33 shell_quote is sound: sh receives exactly the text',
        quote_string(S),
        ( shell_quote(S, Q), atomics_to_string(["printf %s ", Q], Cmd),
          run_raw(Cmd, Out), Out == S )),
    fake_server(Root),
    theorem('T34 on(Server, C) = sh(C): remote and local runs agree',
        ( member(L, [[], ["a"], ["b a", "a", "b"]]),
          member(M, [tac, grep("a") >> wc_l, sort_u >> join("|")]) ),
        ( sh(L >> M, X), on("test@fake", L >> M, Y), X == Y )),
    % --- Starlog compatibility --------------------------------------------
    (   catch(use_module(library(starlog)), _, fail)
    ->  shellog_starlog,
        theorem('T35 Starlog X is A>>M1>>M2 = sh(A>>M1>>M2)',
            ( line_list(L), length(L, N), N =< 2, method(M1), method(M2) ),
            ( starlog_expand:expand_starlog_goal((X is L >> M1 >> M2), Goal),
              call(user:Goal), sh(L >> M1 >> M2, Y), X == Y ))
    ;   format("  skipped T35 (Starlog not installed)~n")
    ),
    aggregate_all(count, failed(_), NF),
    (   NF =:= 0
    ->  format("All theorems proved.~n"), halt(0)
    ;   format("~w theorem(s) failed.~n", [NF]), halt(1)
    ).

		 /*******************************
		 *            HELPERS           *
		 *******************************/

call_m(M, In, Out) :- sh(In >> M, Out).

add_run(S, A0, A) :-
    split_string(S, " ", "", [NS|_]), number_string(N, NS), A is A0 + N.

% interleave(L, G, V): L interleaves G and V, keeping order.
interleave([], [], []).
interleave([X|Xs], [X|Gs], Vs) :- interleave(Xs, Gs, Vs).
interleave([X|Xs], Gs, [X|Vs]) :- interleave(Xs, Gs, Vs).

% run_raw(+Cmd, -Out): stdout of sh -c Cmd as one string (no line split)
run_raw(Cmd, Out) :-
    setup_call_cleanup(
        process_create(path(sh), ["-c", Cmd], [stdout(pipe(S)), process(P)]),
        read_string(S, _, Out),
        close(S)),
    process_wait(P, exit(0)).

fake_server(Root) :-
    directory_file_path(Root, 'tests/fake_bin', Bin),
    directory_file_path(Root, prolog, Lib),
    getenv('PATH', P0),
    atomic_list_concat([Bin, ':', P0], P),
    setenv('PATH', P),
    setenv('SHELLOG_LIB', Lib).
