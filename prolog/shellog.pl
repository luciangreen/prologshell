/*  shellog.pl -- replace bash with Prolog.

    Shellog provides shell commands as value-returning Prolog predicates
    that follow the Starlog convention:

        Out is cmd(Args...)           ==>  cmd(Args..., Out)
        Out is In >> cmd(Args...)     ==>  cmd(Args..., In, Out)

    so every command can be used
      * directly from Prolog            cat("a.txt", Lines)
      * as a Starlog method chain       X is cat("a.txt") >> grep("an") >> wc_l
      * with Shellog's own evaluator    sh(cat("a.txt") >> grep("an") >> wc_l, X)
      * on a server                     sh(on("me@host", ls("/var/www")), X)

    Pipe values
      Line-oriented commands take and return a list of strings (one per
      line), the Prolog form of a bash pipe.  Any string, atom or number
      given as input is first split into lines with lines/2, so
      "a\nb" >> wc_l works as expected.  Counts are numbers, paths are
      strings.

    Author: Lucian Green.  License: BSD-3-Clause.
*/

:- module(shellog, [
    % evaluator
    sh/2, sh/1, shellog_command/2, shellog_starlog/0,
    % pipe values
    lines/2, text/2, echo/2, join/3, seq/2, range/3,
    % files and directories
    pwd/1, cd/2, ls/2, ls_a/2, find_files/2, find_name/3,
    cat/2, touch/2, mkdir/2, rmdir/2, rm/2, rm_r/2,
    cp/3, mv/3, write_to/3, append_to/3, tee/3,
    exists/2, is_dir/2, is_file/2, size/2,
    basename/2, dirname/2, ext/2,
    % text filters
    grep/3, grep_v/3, grep_i/3, grep_c/3, grep_glob/3,
    head_n/3, tail_n/3, nth_line/3,
    sort_lines/2, sort_r/2, sort_n/2, sort_u/2,
    uniq/2, uniq_c/2, wc_l/2, wc_w/2, wc_c/2,
    number_lines/2, tr/4, tr_d/3, sed/4, cut/4,
    rev/2, tac/2, upper/2, lower/2, trim/2,
    map/3, xargs/3,
    % processes, environment and servers
    run/2, env/2, on/3, on/4, ssh/3, scp_put/4, scp_get/4,
    shell_quote/2
]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(filesex)).
:- use_module(library(readutil)).
:- use_module(library(process)).
:- use_module(library(aggregate)).

% Starlog uses >> (yfx) for method chains.  Declaring it here as well
% means Shellog chains parse identically with or without Starlog loaded.
:- op(650, yfx, user:(>>)).
:- op(650, yfx, (>>)).

		 /*******************************
		 *           EVALUATOR          *
		 *******************************/

%!  sh(+Chain) is det.
%   Evaluate Chain and print the result as bash would (one line each).
sh(Chain) :-
    sh(Chain, Out),
    print_value(Out).

print_value(Out) :-
    (   is_list(Out)
    ->  forall(member(L, Out), (write_text(L), nl))
    ;   write_text(Out), nl
    ).

write_text(X) :- string(X), !, write(X).
write_text(X) :- atom(X), !, write(X).
write_text(X) :- print(X).

%!  sh(+Chain, -Out) is det.
%   Evaluate a Starlog-style method chain without needing Starlog.
%   A >> M evaluates A, then applies method M to its value.
%   A base command cmd(Args) is called as cmd(Args..., Out).
%   Literal values (strings, numbers, lists) evaluate to themselves.
sh(Chain, _) :-
    var(Chain), !,
    instantiation_error(Chain).
sh(no_eval(Chain), Out) :- !,         % Starlog's quoting wrapper
    sh(Chain, Out).
sh(A >> M, Out) :- !,
    sh(A, V),
    apply_method(M, V, Out).
sh(Value, Out) :-
    literal(Value), !,
    Out = Value.
sh(Cmd, Out) :-
    callable(Cmd),
    Cmd =.. [Name|Args],
    length(Args, N),
    N1 is N + 1,
    (   shellog_command(Name, N1)
    ->  append(Args, [Out], All),
        G =.. [Name|All],
        call(G)
    ;   atom(Cmd)
    ->  Out = Cmd                       % a bare atom is a value
    ;   append(Args, [Out], All),       % user-defined value predicate
        G =.. [Name|All],
        call(user:G)
    ).

literal(V) :- string(V), !.
literal(V) :- number(V), !.
literal(V) :- is_list(V), !.

%   apply_method(+Method, +In, -Out)
%   Method may itself be a chain, as in  X >> (grep("a") >> wc_l).
apply_method(M, _, _) :-
    var(M), !,
    instantiation_error(M).
apply_method(no_eval(M), In, Out) :- !,
    apply_method(M, In, Out).
apply_method(M1 >> M2, In, Out) :- !,
    apply_method(M1, In, Mid),
    apply_method(M2, Mid, Out).
apply_method(M, In, Out) :-
    callable(M),
    M =.. [Name|Args],
    append(Args, [In, Out], All),
    G =.. [Name|All],
    length(All, Arity),
    (   shellog_command(Name, Arity)
    ->  call(G)
    ;   call(user:G)
    ).

%!  shellog_command(?Name, ?Arity) is nondet.
%   True if Name/Arity is an exported Shellog command.
shellog_command(Name, Arity) :-
    atom(Name), integer(Arity), !,
    functor(H, Name, Arity),
    predicate_property(shellog:H, exported),
    \+ evaluator(Name).
shellog_command(Name, Arity) :-
    module_property(shellog, exports(Es)),
    member(Name/Arity, Es),
    \+ evaluator(Name).

evaluator(sh).
evaluator(shellog_command).
evaluator(shell_quote).
evaluator(shellog_starlog).

		 /*******************************
		 *          PIPE VALUES         *
		 *******************************/

%!  lines(+In, -Lines) is det.
%   Normalise a pipe value to a list of strings.  A trailing newline does
%   not create an empty last line, so lines(text(L)) == L.
lines(In, _) :-
    var(In), !,
    instantiation_error(In).
lines(In, Lines) :-
    is_list(In), !,
    maplist(to_string, In, Lines).
lines(In, Lines) :-
    to_string(In, S),
    (   S == ""
    ->  Lines = []
    ;   split_string(S, "\n", "", Parts),
        (   append(Lines0, [""], Parts)
        ->  Lines = Lines0
        ;   Lines = Parts
        )
    ).

to_string(X, S) :- string(X), !, S = X.
to_string(X, S) :- atom(X), !, atom_string(X, S).
to_string(X, S) :- number(X), !, number_string(X, S).
to_string(X, S) :- term_string(X, S).

%!  text(+In, -String) is det.
%   Join lines with "\n", ending with a newline as bash output does.
text(In, S) :-
    lines(In, Ls),
    (   Ls == []
    ->  S = ""
    ;   atomic_list_concat(Ls, '\n', A),
        atom_string(A, S0),
        string_concat(S0, "\n", S)
    ).

%!  echo(+X, -Lines) is det.
echo(X, Lines) :- lines(X, Lines).

%!  join(+Sep, +In, -String) is det.
join(Sep, In, S) :-
    lines(In, Ls),
    to_string(Sep, Sep1),
    atomic_list_concat(Ls, Sep1, A),
    atom_string(A, S).

%!  seq(+N, -Lines) is det.        (seq N)
%!  range(+From, +To, -Lines) is det.   (seq From To)
seq(N, Lines) :- range(1, N, Lines).
range(From, To, Lines) :-
    (   From > To
    ->  Lines = []
    ;   numlist(From, To, Ns),
        maplist(number_string, Ns, Lines)
    ).

		 /*******************************
		 *     FILES AND DIRECTORIES    *
		 *******************************/

path_string(P, S) :- to_string(P, S).

%!  pwd(-Dir) is det.
pwd(Dir) :-
    working_directory(D, D),
    path_string(D, Dir).

%!  cd(+Dir, -NewDir) is det.
cd(Dir, New) :-
    path_string(Dir, D),
    working_directory(_, D),
    pwd(New).

%!  ls(+Dir, -Names) is det.
%   Sorted entries of Dir without hidden files.  ls of a file is [File].
ls(Dir, Names) :-
    ls_(Dir, false, Names).

%!  ls_a(+Dir, -Names) is det.
%   As ls/2 but including hidden entries (not "." or "..").
ls_a(Dir, Names) :-
    ls_(Dir, true, Names).

ls_(Dir, Hidden, Names) :-
    path_string(Dir, D),
    (   exists_directory(D)
    ->  directory_files(D, Es0),
        maplist(to_string, Es0, Es),
        exclude(skip_entry(Hidden), Es, Es1),
        msort(Es1, Names)
    ;   exists_file(D)
    ->  Names = [D]
    ;   existence_error(file, D)
    ).

skip_entry(_, ".").
skip_entry(_, "..").
skip_entry(false, E) :- sub_string(E, 0, 1, _, ".").

%!  find_files(+Dir, -Paths) is det.
%   All regular files below Dir (recursively), sorted, as Dir/... paths.
find_files(Dir, Paths) :-
    path_string(Dir, D),
    findall(P, file_below(D, P), Ps),
    msort(Ps, Paths).

file_below(D, P) :-
    directory_files(D, Es),
    member(E0, Es),
    to_string(E0, E),
    E \== ".", E \== "..",
    join_path(D, E, F),
    (   exists_directory(F)
    ->  file_below(F, P)
    ;   P = F
    ).

join_path(".", E, E) :- !.
join_path(D, E, F) :-
    (   sub_string(D, _, 1, 0, "/")
    ->  string_concat(D, E, F)
    ;   atomics_to_string([D, "/", E], F)
    ).

%!  find_name(+Pattern, +Dir, -Paths) is det.
%   Files below Dir whose base name matches the wildcard Pattern (*.pl).
find_name(Pattern, Dir, Paths) :-
    to_string(Pattern, Pat),
    find_files(Dir, All),
    include(base_matches(Pat), All, Paths).

base_matches(Pat, P) :-
    file_base_name(P, B),
    wildcard_match(Pat, B).

%!  cat(+FileOrFiles, -Lines) is det.
cat(Files, Lines) :-
    is_list(Files), !,
    maplist(cat, Files, Ls),
    append(Ls, Lines).
cat(File, Lines) :-
    path_string(File, F),
    read_file_to_string(F, S, []),
    lines(S, Lines).

%!  touch(+File, -File) is det.
touch(File, F) :-
    path_string(File, F),
    (   exists_file(F)
    ->  get_time(T),
        catch(set_time_file(F, _, [modified(T)]), _, true)
    ;   setup_call_cleanup(open(F, write, S), true, close(S))
    ).

%!  mkdir(+Dir, -Dir) is det.   (mkdir -p)
mkdir(Dir, D) :-
    path_string(Dir, D),
    make_directory_path(D).

%!  rmdir(+Dir, -Dir) is det.   (empty directories only)
rmdir(Dir, D) :-
    path_string(Dir, D),
    delete_directory(D).

%!  rm(+File, -File) is det.
rm(File, F) :-
    path_string(File, F),
    delete_file(F).

%!  rm_r(+Path, -Path) is det.  (rm -rf)
rm_r(Path, P) :-
    path_string(Path, P),
    (   exists_directory(P)
    ->  delete_directory_and_contents(P)
    ;   exists_file(P)
    ->  delete_file(P)
    ;   true
    ).

%   target(+Src, +Dest, -Target): copying into a directory keeps the name.
target(Src, Dest, T) :-
    (   exists_directory(Dest)
    ->  file_base_name(Src, B0),
        to_string(B0, B),
        join_path(Dest, B, T)
    ;   T = Dest
    ).

%!  cp(+Dest, +Src, -Target) is det.
%   As a method:  "a.txt" >> cp("backup/")
cp(Dest, Src, T) :-
    path_string(Src, S),
    path_string(Dest, D),
    target(S, D, T),
    copy_file(S, T).

%!  mv(+Dest, +Src, -Target) is det.
mv(Dest, Src, T) :-
    path_string(Src, S),
    path_string(Dest, D),
    target(S, D, T),
    rename_file(S, T).

%!  write_to(+File, +In, -File) is det.     (In > File)
write_to(File, In, F) :-
    write_lines(File, write, In, F).

%!  append_to(+File, +In, -File) is det.    (In >> File)
append_to(File, In, F) :-
    write_lines(File, append, In, F).

write_lines(File, Mode, In, F) :-
    path_string(File, F),
    text(In, S),
    setup_call_cleanup(open(F, Mode, Out), write(Out, S), close(Out)).

%!  tee(+File, +In, -Lines) is det.
tee(File, In, Lines) :-
    lines(In, Lines),
    write_to(File, Lines, _).

%!  exists(+Path, -Bool) is det.
exists(Path, B) :-
    path_string(Path, P),
    (   ( exists_file(P) ; exists_directory(P) ) -> B = true ; B = false ).

%!  is_dir(+Path, -Bool) is det.
is_dir(Path, B) :-
    path_string(Path, P),
    ( exists_directory(P) -> B = true ; B = false ).

%!  is_file(+Path, -Bool) is det.
is_file(Path, B) :-
    path_string(Path, P),
    ( exists_file(P) -> B = true ; B = false ).

%!  size(+File, -Bytes) is det.
size(File, N) :-
    path_string(File, F),
    size_file(F, N).

%!  basename(+Path, -Base) is det.
basename(Path, B) :-
    path_string(Path, P),
    file_base_name(P, B0), to_string(B0, B).

%!  dirname(+Path, -Dir) is det.
dirname(Path, D) :-
    path_string(Path, P),
    file_directory_name(P, D0), to_string(D0, D).

%!  ext(+Path, -Ext) is det.
ext(Path, E) :-
    path_string(Path, P),
    file_name_extension(_, E0, P), to_string(E0, E).

		 /*******************************
		 *          TEXT FILTERS        *
		 *******************************/

%!  grep(+Pattern, +In, -Lines) is det.  Lines containing Pattern.
grep(Pat, In, Out) :-
    to_string(Pat, P), lines(In, Ls),
    include(contains(P), Ls, Out).

%!  grep_v(+Pattern, +In, -Lines) is det.  Lines not containing Pattern.
grep_v(Pat, In, Out) :-
    to_string(Pat, P), lines(In, Ls),
    exclude(contains(P), Ls, Out).

%!  grep_i(+Pattern, +In, -Lines) is det.  Case-insensitive grep.
grep_i(Pat, In, Out) :-
    to_string(Pat, P0), string_lower(P0, P), lines(In, Ls),
    include(contains_i(P), Ls, Out).

%!  grep_c(+Pattern, +In, -Count) is det.  (grep -c)
grep_c(Pat, In, N) :-
    grep(Pat, In, Out),
    length(Out, N).

%!  grep_glob(+Wildcard, +In, -Lines) is det.  Whole-line wildcard match.
grep_glob(Pat, In, Out) :-
    to_string(Pat, P), lines(In, Ls),
    include(glob(P), Ls, Out).

contains(P, L) :- sub_string(L, _, _, _, P), !.
contains_i(P, L) :- string_lower(L, L1), contains(P, L1).
glob(P, L) :- wildcard_match(P, L).

%!  head_n(+N, +In, -Lines) is det.  First N lines.
head_n(N, In, Out) :-
    lines(In, Ls),
    length(Ls, Len),
    K is max(0, min(N, Len)),
    length(Out, K),
    append(Out, _, Ls).

%!  tail_n(+N, +In, -Lines) is det.  Last N lines.
tail_n(N, In, Out) :-
    lines(In, Ls),
    length(Ls, Len),
    K is max(0, min(N, Len)),
    length(Out, K),
    append(_, Out, Ls).

%!  nth_line(+N, +In, -Line) is det.  1-based; "" when out of range.
nth_line(N, In, L) :-
    lines(In, Ls),
    (   integer(N), N >= 1, nth1(N, Ls, L0) -> L = L0 ; L = "" ).

%!  sort_lines(+In, -Lines) is det.  (sort, keeps duplicates)
sort_lines(In, Out) :- lines(In, Ls), msort(Ls, Out).

%!  sort_r(+In, -Lines) is det.  (sort -r)
sort_r(In, Out) :- sort_lines(In, S), reverse(S, Out).

%!  sort_u(+In, -Lines) is det.  (sort -u)
sort_u(In, Out) :- lines(In, Ls), sort(Ls, Out).

%!  sort_n(+In, -Lines) is det.  (sort -n, stable; non-numbers count as 0)
sort_n(In, Out) :-
    lines(In, Ls),
    map_list_to_pairs(line_number_key, Ls, Ps),
    keysort(Ps, Sorted),
    pairs_values(Sorted, Out).

line_number_key(L, K) :-
    split_string(L, "", " \t", [T]),
    (   catch(number_string(K0, T), _, fail) -> K = K0 ; K = 0 ).

%!  uniq(+In, -Lines) is det.  Drop adjacent duplicates.
uniq(In, Out) :- lines(In, Ls), uniq_(Ls, Out).

uniq_([], []).
uniq_([X|Xs], [X|Ys]) :- drop_same(X, Xs, Rest), uniq_(Rest, Ys).

drop_same(X, [Y|Ys], R) :- X == Y, !, drop_same(X, Ys, R).
drop_same(_, R, R).

%!  uniq_c(+In, -Lines) is det.  "Count Line" for each adjacent run.
uniq_c(In, Out) :- lines(In, Ls), runs(Ls, Out).

runs([], []).
runs([X|Xs], [S|Ss]) :-
    count_same(X, Xs, 1, N, Rest),
    atomics_to_string([N, " ", X], S),
    runs(Rest, Ss).

count_same(X, [Y|Ys], N0, N, R) :- X == Y, !, N1 is N0+1, count_same(X, Ys, N1, N, R).
count_same(_, R, N, N, R).

%!  wc_l(+In, -N) is det.  Number of lines.
wc_l(In, N) :- lines(In, Ls), length(Ls, N).

%!  wc_w(+In, -N) is det.  Number of whitespace-separated words.
wc_w(In, N) :-
    lines(In, Ls),
    foldl(add_words, Ls, 0, N).

add_words(L, N0, N) :-
    split_string(L, " \t", " \t", Ws0),
    exclude(==(""), Ws0, Ws),
    length(Ws, K),
    N is N0 + K.

%!  wc_c(+In, -N) is det.  Characters of the text, newlines included.
wc_c(In, N) :- text(In, S), string_length(S, N).

%!  number_lines(+In, -Lines) is det.  "N\tLine" (cat -n / nl -ba).
number_lines(In, Out) :-
    lines(In, Ls),
    length(Ls, Len),
    (   Len =:= 0 -> Ns = [] ; numlist(1, Len, Ns) ),
    maplist(numbered, Ns, Ls, Out).

numbered(N, L, S) :- atomics_to_string([N, "\t", L], S).

%!  tr(+From, +To, +In, -Lines) is det.
%   Map each char of From to the char at the same place in To (the last
%   char of To is repeated if To is shorter, as in bash).
tr(From, To, In, Out) :-
    to_string(From, F), to_string(To, T),
    string_chars(F, Fs), string_chars(T, Ts0),
    (   Ts0 == []
    ->  Ts = Fs
    ;   length(Fs, LF), pad_last(Ts0, LF, Ts)
    ),
    lines(In, Ls),
    maplist(tr_line(Fs, Ts), Ls, Out).

pad_last(Ts, N, Ts) :- length(Ts, L), L >= N, !.
pad_last(Ts0, N, Ts) :- last(Ts0, C), length(Ts0, L), K is N-L,
    length(Pad, K), maplist(=(C), Pad), append(Ts0, Pad, Ts).

tr_line(Fs, Ts, L, S) :-
    string_chars(L, Cs),
    maplist(tr_char(Fs, Ts), Cs, Cs1),
    string_chars(S, Cs1).

tr_char(Fs, Ts, C, D) :-
    (   last_index(C, Fs, I) -> nth1(I, Ts, D) ; D = C ).

% bash tr uses the last mapping for a repeated char in From
last_index(C, Fs, I) :-
    findall(I0, nth1(I0, Fs, C), Is), Is \== [], last(Is, I).

%!  tr_d(+Chars, +In, -Lines) is det.  (tr -d)
tr_d(Chars, In, Out) :-
    to_string(Chars, Cs0), string_chars(Cs0, Cs),
    lines(In, Ls),
    maplist(del_chars(Cs), Ls, Out).

del_chars(Cs, L, S) :-
    string_chars(L, Ls), exclude([C]>>memberchk(C, Cs), Ls, Ks),
    string_chars(S, Ks).

%!  sed(+Old, +New, +In, -Lines) is det.  (sed 's/Old/New/g', literal)
sed(Old, New, In, Out) :-
    to_string(Old, O), to_string(New, N),
    lines(In, Ls),
    (   O == "" -> Out = Ls ; maplist(replace_all(O, N), Ls, Out) ).

replace_all(O, N, L, S) :-
    atomic_list_concat(Parts, O, L),
    atomic_list_concat(Parts, N, A),
    atom_string(A, S).

%!  cut(+Delim, +Field, +In, -Lines) is det.  (cut -d Delim -f Field)
%   Lines without Delim are passed through whole, as in bash.
cut(Delim, Field, In, Out) :-
    to_string(Delim, D),
    lines(In, Ls),
    maplist(cut_line(D, Field), Ls, Out).

cut_line(D, F, L, S) :-
    (   sub_string(L, _, _, _, D)
    ->  atomic_list_concat(Parts, D, L),
        (   nth1(F, Parts, P) -> to_string(P, S) ; S = "" )
    ;   S = L
    ).

%!  rev(+In, -Lines) is det.  Reverse the characters of each line.
rev(In, Out) :- lines(In, Ls), maplist(rev_line, Ls, Out).
rev_line(L, S) :- string_chars(L, Cs), reverse(Cs, Rs), string_chars(S, Rs).

%!  tac(+In, -Lines) is det.  Reverse the order of lines.
tac(In, Out) :- lines(In, Ls), reverse(Ls, Out).

%!  upper(+In, -Lines) is det.
upper(In, Out) :- lines(In, Ls), maplist(string_upper, Ls, Out).

%!  lower(+In, -Lines) is det.
lower(In, Out) :- lines(In, Ls), maplist(string_lower, Ls, Out).

%!  trim(+In, -Lines) is det.  Strip surrounding whitespace on each line.
trim(In, Out) :- lines(In, Ls), maplist(trim_line, Ls, Out).
trim_line(L, S) :- split_string(L, "", " \t\r", [S]).

%!  map(+Method, +In, -Results) is det.
%   Apply Method to every line; collect one result per line.
%   "." >> ls >> map(size)
map(M, In, Out) :-
    lines(In, Ls),
    maplist(apply_method(M), Ls, Out).

%!  xargs(+Method, +In, -Lines) is det.
%   Apply Method to every line and concatenate the resulting lines.
%   "." >> find_name("*.txt") >> xargs(cat)
xargs(M, In, Out) :-
    lines(In, Ls),
    maplist(apply_method(M), Ls, Rs),
    maplist(lines, Rs, Lss),
    append(Lss, Out).

		 /*******************************
		 *   PROCESSES AND SERVERS      *
		 *******************************/

%!  run(+Command, -Lines) is det.
%   Escape hatch: run Command with /bin/sh and return its stdout lines.
%   Throws shellog_exit(Status, Command) if the exit status is not 0.
run(Cmd, Lines) :-
    to_string(Cmd, C),
    run_process(path(sh), ["-c", C], C, Lines).

run_process(Exe, Args, Label, Lines) :-
    setup_call_cleanup(
        process_create(Exe, Args, [stdout(pipe(Out)), process(Pid)]),
        read_string(Out, _, S),
        close(Out)),
    process_wait(Pid, Status),
    (   Status == exit(0)
    ->  lines(S, Lines)
    ;   throw(error(shellog_exit(Status, Label), _))
    ).

%!  env(+Name, -Value) is det.  "" when unset.
env(Name, V) :-
    to_string(Name, N),
    (   getenv(N, V0) -> to_string(V0, V) ; V = "" ).

%!  on(+Host, +Chain, -Out) is det.
%   Evaluate a Shellog chain on Host ("user@server") over ssh, running
%   swipl with library(shellog) there.  Host local evaluates here.
%       sh(on("me@web", ls("/var/www") >> grep("html")), Pages)
on(Host, Chain, Out) :-
    (   local_host(Host)
    ->  sh(Chain, Out)
    ;   remote_goal(Chain, Goal),
        to_string(Host, H),
        run_process(path(ssh), [H, Goal], H, Ls),
        atomic_list_concat(Ls, '\n', A),
        term_string(Out, A)
    ).

%!  on(+Host, +Chain, +In, -Out) is det.
%   Method form: send the pipe value In to Host and continue Chain there.
%       cat("local.txt") >> on("me@web", sort_lines >> uniq)
on(Host, Chain, In, Out) :-
    on(Host, In >> Chain, Out).

local_host(H) :- var(H), !, instantiation_error(H).
local_host(local).
local_host("local").
local_host(localhost).
local_host("localhost").

remote_goal(Chain, Cmd) :-
    format(string(G),
           "use_module(library(shellog)),sh(~q,O),write_canonical(O),nl",
           [Chain]),
    shell_quote(G, QG),
    atomics_to_string(["swipl -q -g ", QG, " -t halt"], Cmd).

%!  ssh(+Host, +Command, -Lines) is det.
%   Run a raw shell command on Host.  Host local runs it here.
ssh(Host, Cmd, Lines) :-
    (   local_host(Host)
    ->  run(Cmd, Lines)
    ;   to_string(Host, H), to_string(Cmd, C),
        run_process(path(ssh), [H, C], C, Lines)
    ).

%!  scp_put(+Host, +Remote, +Local, -Remote) is det.
%   Upload Local to Remote on Host.   "site.html" >> scp_put("me@web", "/var/www/")
scp_put(Host, Remote, Local, R) :-
    to_string(Remote, R),
    (   local_host(Host)
    ->  cp(R, Local, _)
    ;   to_string(Host, H), path_string(Local, L),
        atomics_to_string([H, ":", R], Dest),
        run_process(path(scp), ["-q", L, Dest], Dest, _)
    ).

%!  scp_get(+Host, +Local, +Remote, -Local) is det.
%   Download Remote from Host to Local.  "/var/log/x.log" >> scp_get("me@web", "x.log")
scp_get(Host, Local, Remote, L) :-
    path_string(Local, L),
    (   local_host(Host)
    ->  cp(L, Remote, _)
    ;   to_string(Host, H), to_string(Remote, R),
        atomics_to_string([H, ":", R], Src),
        run_process(path(scp), ["-q", Src, L], Src, _)
    ).

%!  shell_quote(+Text, -Quoted) is det.
%   Single-quote Text for /bin/sh so it reaches the program unchanged.
shell_quote(T, Q) :-
    to_string(T, S),
    atomic_list_concat(Parts, '\'', S),
    atomic_list_concat(Parts, '\'"\'"\'', Inner),
    atomics_to_string(["'", Inner, "'"], Q).

		 /*******************************
		 *      STARLOG INTEGRATION     *
		 *******************************/

%!  shellog_starlog is det.
%   Register each Shellog command name with Starlog as a value builtin,
%   using its smallest arity A >= 2 as Name/(A-1), so
%   X is cat("f") >> grep("a")  calls  cat("f", V), grep("a", V, X).
%   Only one arity per name is registered: Starlog looks a name up with
%   an unbound arity and commits to the first entry, so a second arity
%   would hide the first.  Larger arities (on/4) still work as methods
%   through Starlog's user-predicate fallback.  Runs automatically when
%   Starlog is installed; calling it again gives the same registry.
shellog_starlog :-
    (   current_predicate(starlog:starlog_register_value_builtin/3)
    ->  findall(Name, ( shellog_command(Name, A), A >= 2 ), Ns0),
        sort(Ns0, Ns),
        forall(member(Name, Ns),
               ( aggregate_all(min(A), ( shellog_command(Name, A), A >= 2 ), Min),
                 forall(( shellog_command(Name, A2), A2 >= 2 ),
                        ( B is A2 - 1,
                          starlog:starlog_unregister_value_builtin(Name, B) )),
                 A1 is Min - 1,
                 starlog:starlog_register_value_builtin(Name, A1, Name) ))
    ;   true
    ).

:- if(exists_source(library(starlog))).
:- use_module(library(starlog), []).
:- initialization(shellog_starlog).
:- endif.

:- multifile prolog:error_message//1.
prolog:error_message(shellog_exit(Status, Cmd)) -->
    [ 'shellog: ~w failed with ~w'-[Cmd, Status] ].
