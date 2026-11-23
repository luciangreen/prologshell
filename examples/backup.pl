% backup.pl -- a bash script rewritten in Prologshell + Starlog.
%
%     Bash:
%         mkdir -p backup
%         for f in $(find . -name '*.txt'); do cp "$f" backup/; done
%         cat backup/*.txt | grep -v '^#' | sort | uniq -c > backup/summary.txt
%         wc -l < backup/summary.txt
%
%     Run:  swipl examples/backup.pl DIR

:- use_module(library(starlog)).
:- use_module(library(prologshell)).

:- initialization(main, main).

main([Dir]) :-
    _ is Dir >> cd,
    _ is mkdir("backup"),
    Copied is "." >> find_name("*.txt") >> grep_v("backup/") >> map(cp("backup")),
    Summary is "backup" >> find_name("*.txt") >> xargs(cat) >> grep_v("#")
               >> sort_lines >> uniq_c >> write_to("backup/summary.txt"),
    N is Summary >> cat >> wc_l,
    length(Copied, C),
    format("copied ~w files; ~w distinct lines in ~w~n", [C, N, Summary]).
