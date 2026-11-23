/*  fixture.pl -- builds the sandbox directory used by the tests.

    sandbox/
      a.txt        apple banana cherry
      b.txt        one two three two two
      nums.txt     10 9 100 -1 3
      csv.txt      name,age ann,31 bob,27 cat,45
      words.txt    the quick brown fox / jumps over / the lazy dog
      empty.txt    (empty)
      .hidden      secret
      sub/c.pl     x. y.
      sub/deep/d.txt  deep
*/

:- module(fixture, [make_sandbox/1, sandbox_files/1]).

:- use_module(library(filesex)).

sandbox_files([
    "a.txt"-"apple\nbanana\ncherry\n",
    "b.txt"-"one\ntwo\nthree\ntwo\ntwo\n",
    "nums.txt"-"10\n9\n100\n-1\n3\n",
    "csv.txt"-"name,age\nann,31\nbob,27\ncat,45\n",
    "words.txt"-"the quick brown fox\njumps over\nthe lazy dog\n",
    "empty.txt"-"",
    ".hidden"-"secret\n",
    "sub/c.pl"-"x.\ny.\n",
    "sub/deep/d.txt"-"deep\n"
]).

%!  make_sandbox(+Dir) is det.
%   (Re)create Dir with exactly the files above.
make_sandbox(Dir) :-
    (   exists_directory(Dir) -> delete_directory_and_contents(Dir) ; true ),
    make_directory_path(Dir),
    sandbox_files(Fs),
    forall(member(Rel-Text, Fs),
           ( directory_file_path(Dir, Rel, Path),
             file_directory_name(Path, D),
             make_directory_path(D),
             setup_call_cleanup(open(Path, write, S),
                                write(S, Text), close(S)) )).
