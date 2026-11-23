# Shellog

Shellog replaces bash with Prolog. Shell commands such as `ls`, `cat`, `grep`, `sort`, `cp` and `ssh` become value-returning Prolog predicates. They chain left to right with Starlog's `>>` method-chain operator, so a bash pipeline becomes a Prolog expression, and the same chain can run on a server.

```prolog
% bash:  cat a.txt | grep an | wc -l
N is cat("a.txt") >> grep("an") >> wc_l.

% bash:  ssh me@web 'ls /var/www | grep html'
Pages is no_eval(ls("/var/www") >> grep("html")) >> on("me@web").
```

## Installation

```prolog
?- pack_install(shellog, [url('https://github.com/luciangreen/shellog.git')]).
?- pack_install(starlog, [url('https://github.com/luciangreen/starlog.git')]).   % optional, for X is ... syntax
```

```prolog
?- use_module(library(shellog)).
```

Starlog is optional. Without it, use Shellog's own evaluator `sh/2`, which runs the same chains:

```prolog
?- sh(cat("a.txt") >> grep("an") >> wc_l, N).
?- sh("." >> ls).                 % sh/1 prints the result like bash
```

If Starlog is installed, Shellog registers its commands with Starlog when it loads, so `X is ...` works in your files and at the REPL (load `library(starlog)` before your own code).

## How a chain runs

Shellog follows the Starlog convention for value-returning predicates:

| Form | Calls |
|---|---|
| `X is cmd(A, B)` | `cmd(A, B, X)` |
| `X is In >> cmd(A)` | `cmd(A, In, X)` |
| `X is In >> cmd` | `cmd(In, X)` |
| `X is A >> M1 >> M2` | `M1` applied to `A`, then `M2` applied to that result |

**Pipe values.** Line-oriented commands take and return a list of strings, one per line. A string, atom or number given as input is split into lines first, so `"a\nb" >> wc_l` gives `2`. Counts come back as numbers, and paths as strings. `text/2` turns lines back into one newline-terminated string.

## Bash to Shellog

| bash | Shellog |
|---|---|
| `pwd` | `pwd(D)` |
| `cd dir` | `_ is "dir" >> cd` |
| `ls dir` / `ls -a dir` | `ls("dir")` / `ls_a("dir")` |
| `find dir -type f` | `find_files("dir")` |
| `find dir -name '*.pl'` | `find_name("*.pl", "dir")` |
| `cat f` / `cat f g` | `cat("f")` / `cat(["f","g"])` |
| `echo hi` | `echo("hi")` |
| `seq 5` / `seq 2 4` | `seq(5)` / `range(2, 4)` |
| `touch f` | `touch("f")` |
| `mkdir -p a/b` | `mkdir("a/b")` |
| `rm f` / `rm -rf d` / `rmdir d` | `rm("f")` / `rm_r("d")` / `rmdir("d")` |
| `cp f dest` | `"f" >> cp("dest")` |
| `mv f dest` | `"f" >> mv("dest")` |
| `... > f` / `... >> f` | `... >> write_to("f")` / `... >> append_to("f")` |
| `... \| tee f` | `... >> tee("f")` |
| `grep p` / `-v` / `-i` / `-c` | `grep("p")` / `grep_v("p")` / `grep_i("p")` / `grep_c("p")` |
| `head -n 3` / `tail -n 3` | `head_n(3)` / `tail_n(3)` |
| `sed -n 3p` | `nth_line(3)` |
| `sort` / `-r` / `-n` / `-u` | `sort_lines` / `sort_r` / `sort_n` / `sort_u` |
| `uniq` / `uniq -c` | `uniq` / `uniq_c` |
| `wc -l` / `-w` / `-c` | `wc_l` / `wc_w` / `wc_c` |
| `nl -ba` | `number_lines` |
| `tr ab xy` / `tr -d ab` | `tr("ab", "xy")` / `tr_d("ab")` |
| `sed 's/old/new/g'` | `sed("old", "new")` (literal text) |
| `cut -d, -f2` | `cut(",", 2)` |
| `rev` / `tac` | `rev` / `tac` |
| `tr a-z A-Z` | `upper` (and `lower`, `trim`) |
| `paste -sd,` | `join(",")` |
| `xargs cat` | `xargs(cat)` |
| `for x in ...; do cmd; done` | `map(cmd)` |
| `[ -e p ]` / `[ -d p ]` / `[ -f p ]` | `exists("p")` / `is_dir("p")` / `is_file("p")` |
| `stat -c %s f` | `size("f")` |
| `basename` / `dirname` | `basename(P)` / `dirname(P)` / `ext(P)` |
| `$HOME` | `env("HOME")` |
| `sh -c 'cmd'` | `run("cmd")` (escape hatch; throws on a non-zero exit) |

You can use the commands as ordinary predicates too: `cat("a.txt", Lines)`, `grep("x", Lines, Hits)`.

## Servers

| bash | Shellog |
|---|---|
| `ssh host 'cmd'` | `ssh("me@host", "cmd")` |
| `scp f host:/path` | `"f" >> scp_put("me@host", "/path")` |
| `scp host:/path f` | `"/path" >> scp_get("me@host", "f")` |
| run a whole pipeline on host | `on("me@host", Chain)` |
| send local data to host and continue there | `In >> on("me@host", Chain)` |

`on/3` serialises the chain, runs it with `swipl` and `library(shellog)` on the server over `ssh`, and reads the result back as a Prolog term. That means remote results are real lists and numbers, not text to re-parse. The server needs SWI-Prolog with Shellog installed. Use the host `local` to run the same code locally; the proofs check that both give the same results.

Arguments to `ssh` are passed as an argument vector, not through a local shell. The remote goal is quoted with `shell_quote/2`, which the proofs check against `/bin/sh`.

**With Starlog**, wrap a chain that should run remotely in `no_eval(...)`, so that Starlog doesn't evaluate it locally first:

```prolog
X is no_eval(cat("/etc/hostname")) >> on("me@web").
Y is cat("local.txt") >> on("me@web", no_eval(sort_u >> join(","))).
```

## Example script

`examples/backup.pl` is a bash backup script rewritten as a Shellog program:

```prolog
main([Dir]) :-
    _ is Dir >> cd,
    _ is mkdir("backup"),
    Copied is "." >> find_name("*.txt") >> grep_v("backup/") >> map(cp("backup")),
    Summary is "backup" >> find_name("*.txt") >> xargs(cat) >> grep_v("#")
               >> sort_lines >> uniq_c >> write_to("backup/summary.txt"),
    N is Summary >> cat >> wc_l,
    length(Copied, C),
    format("copied ~w files; ~w distinct lines in ~w~n", [C, N, Summary]).
```

```
swipl examples/backup.pl ~/notes
```

## Tests: 200 input/output pairs

```
swipl tests/run_tests.pl
```

`tests/io_pairs.pl` holds 200 `io(Chain, Expected)` pairs that cover every command. Each pair runs in a fresh sandbox (`tests/fixture.pl`) through `sh/2`. If Starlog is installed, it runs a second time as the Starlog goal `X is Chain`, giving 400 runs. The server pairs use `tests/fake_bin/ssh` and `scp`, which run the command locally as `sshd` would, so the full serialise → remote `swipl` → read-back path is exercised without a real server.

## Proofs

```
swipl proofs/shellog_proofs.pl
```

The proof script checks 35 theorems exhaustively over bounded domains (over 600,000 cases in all). They cover chain associativity, chains as nested application, `lines`/`text` round trips, involutions (`tac`, `rev`), the idempotence of `sort_lines` and `uniq`, the partition of lines by `grep`/`grep_v`, and the `head_n`/`tail_n` laws. They also cover file round trips (`write_to`/`cat`, `cp`, `mv`, `tee`), the soundness of `shell_quote` against `/bin/sh`, agreement between local and remote runs, and Starlog/`sh` equivalence. [PROOFS.md](PROOFS.md) gives the general induction argument for each theorem.

## Notes

- Starlog finds a value builtin by name without its arity and commits to the first entry it finds. Registering two arities of one name would hide one of them, so Shellog registers each name once. This is why `seq 2 4` is `range(2, 4)` rather than `seq(2, 4)`. Fixing `compile_starlog_expr` in Starlog to compute the arity before looking up the name would remove this limit.
- `sed/4` and `grep/3` match literal text, and `grep_glob/3` matches whole lines against a wildcard.
- See also [List Prolog Interpreter](https://github.com/luciangreen/listprologinterpreter), whose `shell`, `open_file_s`, `directory_files` and `exists_file` commands Shellog's file commands follow, and [Starlog](https://github.com/luciangreen/starlog).

## License

BSD-3-Clause. Author: Lucian Green.
