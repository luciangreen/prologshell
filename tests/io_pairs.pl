/*  io_pairs.pl -- 200 input/output pairs for Prologshell.

    io(Chain, Expected): evaluating Chain inside a fresh sandbox (see
    fixture.pl) must give exactly Expected (compared with ==).
    Each pair runs twice: with Prologshell's sh/2 and, when Starlog is
    installed, as the Starlog goal  X is Chain.
    Remote pairs use the host "test@fake", served by tests/fake_bin/ssh
    and scp, which run the command locally exactly as a server would.
*/

:- module(io_pairs, [io/2]).

:- op(650, yfx, user:(>>)).

% ---- 1. pipe values: lines, text, echo, join, seq (20) ----------------
io("a\nb" >> lines, ["a","b"]).
io("a\nb\n" >> lines, ["a","b"]).
io("" >> lines, []).
io("\n" >> lines, [""]).
io("a\n\nb" >> lines, ["a","","b"]).
io(["x","y"] >> text, "x\ny\n").
io([] >> text, "").
io([""] >> text, "\n").
io(echo("hi"), ["hi"]).
io(echo(42), ["42"]).
io(echo(hello), ["hello"]).
io(["a","b","c"] >> join(","), "a,b,c").
io(["a"] >> join("-"), "a").
io([] >> join(","), "").
io(seq(3), ["1","2","3"]).
io(seq(0), []).
io(range(2, 4), ["2","3","4"]).
io(range(5, 4), []).
io(seq(3) >> join("+"), "1+2+3").
io("p\nq" >> text, "p\nq\n").

% ---- 2. listing and finding (15) --------------------------------------
io(ls("."), ["a.txt","b.txt","csv.txt","empty.txt","nums.txt","sub","words.txt"]).
io("." >> ls, ["a.txt","b.txt","csv.txt","empty.txt","nums.txt","sub","words.txt"]).
io(ls("sub"), ["c.pl","deep"]).
io(ls("a.txt"), ["a.txt"]).
io(ls_a("."), [".hidden","a.txt","b.txt","csv.txt","empty.txt","nums.txt","sub","words.txt"]).
io(ls("sub/deep"), ["d.txt"]).
io(ls(".") >> wc_l, 7).
io(ls_a(".") >> wc_l, 8).
io(find_files("sub"), ["sub/c.pl","sub/deep/d.txt"]).
io(find_files("sub/deep"), ["sub/deep/d.txt"]).
io(find_name("*.pl", "."), ["sub/c.pl"]).
io(find_name("*.txt", "sub"), ["sub/deep/d.txt"]).
io("." >> find_name("*.txt") >> wc_l, 7).
io("." >> find_name("d*") >> map(basename), ["d.txt"]).
io(ls(".") >> grep(".txt") >> wc_l, 6).

% ---- 3. reading files (15) --------------------------------------------
io(cat("a.txt"), ["apple","banana","cherry"]).
io("a.txt" >> cat, ["apple","banana","cherry"]).
io(cat("empty.txt"), []).
io(cat(["a.txt","sub/c.pl"]), ["apple","banana","cherry","x.","y."]).
io(cat("sub/deep/d.txt"), ["deep"]).
io(cat(".hidden"), ["secret"]).
io(cat("a.txt") >> text, "apple\nbanana\ncherry\n").
io(cat("b.txt"), ["one","two","three","two","two"]).
io(cat("nums.txt") >> wc_l, 5).
io(cat("csv.txt") >> head_n(1), ["name,age"]).
io(cat('a.txt') >> wc_l, 3).
io(cat('sub/c.pl') >> join(" "), "x. y.").
io(cat("words.txt") >> nth_line(2), "jumps over").
io(["a.txt","b.txt"] >> cat >> wc_l, 8).
io(cat("empty.txt") >> text, "").

% ---- 4. grep family (25) ----------------------------------------------
io(cat("a.txt") >> grep("an"), ["banana"]).
io(cat("a.txt") >> grep("e"), ["apple","cherry"]).
io(cat("a.txt") >> grep("z"), []).
io(cat("a.txt") >> grep(""), ["apple","banana","cherry"]).
io(cat("a.txt") >> grep_v("e"), ["banana"]).
io(cat("a.txt") >> grep_v(""), []).
io(cat("b.txt") >> grep("two"), ["two","two","two"]).
io(cat("b.txt") >> grep_c("two"), 3).
io(cat("b.txt") >> grep_c("o"), 4).
io(cat("b.txt") >> grep_c("four"), 0).
io("Apple\napple\nAPPLE" >> grep("apple"), ["apple"]).
io("Apple\napple\nAPPLE" >> grep_i("apple"), ["Apple","apple","APPLE"]).
io("Apple\nbanana" >> grep_i("APP"), ["Apple"]).
io(cat("a.txt") >> grep_glob("*rr*"), ["cherry"]).
io(cat("a.txt") >> grep_glob("b*"), ["banana"]).
io(cat("a.txt") >> grep_glob("*"), ["apple","banana","cherry"]).
io(cat("a.txt") >> grep_glob("a"), []).
io(cat("words.txt") >> grep("the"), ["the quick brown fox","the lazy dog"]).
io(cat("words.txt") >> grep("the") >> wc_l, 2).
io(cat("csv.txt") >> grep_v("name"), ["ann,31","bob,27","cat,45"]).
io(cat("csv.txt") >> grep(",4"), ["cat,45"]).
io(cat("a.txt") >> grep("a") >> grep("n"), ["banana"]).
io(cat("a.txt") >> grep(a), ["apple","banana"]).
io(cat("nums.txt") >> grep("-"), ["-1"]).
io(cat("nums.txt") >> grep("0"), ["10","100"]).

% ---- 5. head, tail, nth_line (20) -------------------------------------
io(cat("b.txt") >> head_n(2), ["one","two"]).
io(cat("b.txt") >> head_n(0), []).
io(cat("b.txt") >> head_n(10), ["one","two","three","two","two"]).
io(cat("b.txt") >> tail_n(2), ["two","two"]).
io(cat("b.txt") >> tail_n(0), []).
io(cat("b.txt") >> tail_n(9), ["one","two","three","two","two"]).
io(cat("b.txt") >> head_n(3) >> tail_n(1), ["three"]).
io(cat("empty.txt") >> head_n(3), []).
io(cat("empty.txt") >> tail_n(3), []).
io(cat("b.txt") >> head_n(-1), []).
io(cat("a.txt") >> nth_line(1), "apple").
io(cat("a.txt") >> nth_line(3), "cherry").
io(cat("a.txt") >> nth_line(4), "").
io(cat("a.txt") >> nth_line(0), "").
io(seq(100) >> head_n(3), ["1","2","3"]).
io(seq(100) >> tail_n(2), ["99","100"]).
io(seq(10) >> head_n(5) >> wc_l, 5).
io(seq(10) >> tail_n(3) >> join(","), "8,9,10").
io("only" >> head_n(1), ["only"]).
io("only" >> tail_n(1), ["only"]).

% ---- 6. sort and uniq (20) --------------------------------------------
io(cat("b.txt") >> sort_lines, ["one","three","two","two","two"]).
io(cat("b.txt") >> sort_u, ["one","three","two"]).
io(cat("b.txt") >> sort_r, ["two","two","two","three","one"]).
io(cat("nums.txt") >> sort_lines, ["-1","10","100","3","9"]).
io(cat("nums.txt") >> sort_n, ["-1","3","9","10","100"]).
io("b\n2\na\n1" >> sort_n, ["b","a","1","2"]).
io(cat("b.txt") >> uniq, ["one","two","three","two"]).
io(cat("b.txt") >> sort_lines >> uniq, ["one","three","two"]).
io(cat("b.txt") >> uniq_c, ["1 one","1 two","1 three","2 two"]).
io(cat("b.txt") >> sort_lines >> uniq_c, ["1 one","1 three","3 two"]).
io(cat("empty.txt") >> uniq, []).
io(cat("empty.txt") >> sort_lines, []).
io("a\na\na" >> uniq, ["a"]).
io("a\na\na" >> uniq_c, ["3 a"]).
io(cat("a.txt") >> sort_r >> head_n(1), ["cherry"]).
io(cat("b.txt") >> sort_u >> wc_l, 3).
io("c\nB\na" >> sort_lines, ["B","a","c"]).
io("c\nB\na" >> lower >> sort_lines, ["a","b","c"]).
io(" 5\n4" >> sort_n, ["4"," 5"]).
io("2.5\n2\n10" >> sort_n, ["2","2.5","10"]).

% ---- 7. counting (15) -------------------------------------------------
io(cat("a.txt") >> wc_l, 3).
io(cat("empty.txt") >> wc_l, 0).
io(cat("words.txt") >> wc_w, 9).
io(cat("a.txt") >> wc_w, 3).
io(cat("a.txt") >> wc_c, 20).
io(cat("empty.txt") >> wc_c, 0).
io(cat("empty.txt") >> wc_w, 0).
io("a  b\t c" >> wc_w, 3).
io("" >> wc_w, 0).
io("x" >> wc_c, 2).
io(["",""] >> wc_c, 2).
io(cat("csv.txt") >> wc_c, 30).
io(cat("words.txt") >> wc_l, 3).
io(seq(12) >> wc_l, 12).
io(cat(["a.txt","b.txt"]) >> wc_w, 8).

% ---- 8. text transforms (30) ------------------------------------------
io(cat("a.txt") >> upper, ["APPLE","BANANA","CHERRY"]).
io("MiXeD" >> lower, ["mixed"]).
io(cat("a.txt") >> rev, ["elppa","ananab","yrrehc"]).
io(cat("a.txt") >> tac, ["cherry","banana","apple"]).
io(cat("a.txt") >> tac >> tac, ["apple","banana","cherry"]).
io(cat("a.txt") >> rev >> rev, ["apple","banana","cherry"]).
io("  pad  \n\tx" >> trim, ["pad","x"]).
io(cat("a.txt") >> number_lines, ["1\tapple","2\tbanana","3\tcherry"]).
io(cat("empty.txt") >> number_lines, []).
io(cat("a.txt") >> tr("a", "A"), ["Apple","bAnAnA","cherry"]).
io("hello" >> tr("lo", "01"), ["he001"]).
io("abc" >> tr("abc", "x"), ["xxx"]).
io("abc" >> tr("", "x"), ["abc"]).
io(cat("a.txt") >> tr_d("ae"), ["ppl","bnn","chrry"]).
io("a-b-c" >> tr_d("-"), ["abc"]).
io(cat("a.txt") >> sed("an", "AN"), ["apple","bANANa","cherry"]).
io("aaa" >> sed("a", "bb"), ["bbbbbb"]).
io("abc" >> sed("", "x"), ["abc"]).
io("a.b.c" >> sed(".", ""), ["abc"]).
io("x" >> sed("y", "z"), ["x"]).
io(cat("csv.txt") >> cut(",", 1), ["name","ann","bob","cat"]).
io(cat("csv.txt") >> cut(",", 2), ["age","31","27","45"]).
io(cat("csv.txt") >> cut(",", 3), ["","","",""]).
io("no delim\na:b" >> cut(":", 2), ["no delim","b"]).
io(cat("csv.txt") >> tail_n(3) >> cut(",", 2) >> sort_n, ["27","31","45"]).
io(cat("words.txt") >> cut(" ", 2), ["quick","over","lazy"]).
io(cat("words.txt") >> head_n(1) >> tr(" ", "_"), ["the_quick_brown_fox"]).
io(cat("a.txt") >> upper >> grep("AN"), ["BANANA"]).
io(cat("a.txt") >> map(rev), [["elppa"],["ananab"],["yrrehc"]]).
io(cat("a.txt") >> xargs(rev), ["elppa","ananab","yrrehc"]).

% ---- 9. changing files (25) -------------------------------------------
io(touch("new.txt") >> exists, true).
io(touch("new.txt") >> cat, []).
io(touch("a.txt") >> cat, ["apple","banana","cherry"]).
io(mkdir("x/y/z") >> is_dir, true).
io(mkdir("x/y") >> ls, []).
io(rm("a.txt") >> exists, false).
io(rm_r("sub") >> exists, false).
io(rm_r("missing") >> exists, false).
io(mkdir("e") >> rmdir >> exists, false).
io("a.txt" >> cp("c.txt") >> cat, ["apple","banana","cherry"]).
io("a.txt" >> cp("sub"), "sub/a.txt").
io("a.txt" >> cp("sub") >> cat >> wc_l, 3).
io("a.txt" >> mv("m.txt") >> cat, ["apple","banana","cherry"]).
io("a.txt" >> mv("m.txt") >> map(exists), [true]).
io("a.txt" >> mv("sub"), "sub/a.txt").
io(["x","y"] >> write_to("o.txt") >> cat, ["x","y"]).
io(["x","y"] >> write_to("o.txt") >> size, 4).
io(cat("a.txt") >> upper >> write_to("a.txt") >> cat, ["APPLE","BANANA","CHERRY"]).
io(["z"] >> append_to("a.txt") >> cat, ["apple","banana","cherry","z"]).
io("q" >> append_to("new2.txt") >> cat, ["q"]).
io(cat("a.txt") >> tee("t.txt") >> wc_l, 3).
io(size("a.txt"), 20).
io(size("empty.txt"), 0).
io(is_file("sub"), false).
io(is_dir("sub"), true).

% ---- 10. paths, processes, environment and servers (15) ---------------
io(basename("sub/deep/d.txt"), "d.txt").
io(dirname("sub/deep/d.txt"), "sub/deep").
io(ext("sub/c.pl"), "pl").
io(exists("nope"), false).
io(run("echo hi"), ["hi"]).
io(run("printf 'a\\nb\\n'") >> tac, ["b","a"]).
io(env("PROLOGSHELL_TEST"), "yes").
io(env("PROLOGSHELL_UNSET_VAR"), "").
io(ssh(local, "echo local"), ["local"]).
io(no_eval(cat("a.txt") >> wc_l) >> on(local), 3).
io(ssh("test@fake", "echo remote"), ["remote"]).
io(no_eval(cat("a.txt") >> grep("an")) >> on("test@fake"), ["banana"]).
io(cat("b.txt") >> on("test@fake", no_eval(sort_u >> join(","))), "one,three,two").
io("a.txt" >> scp_put("test@fake", "up.txt") >> cat, ["apple","banana","cherry"]).
io("b.txt" >> scp_get("test@fake", "down.txt") >> cat >> wc_l, 5).
