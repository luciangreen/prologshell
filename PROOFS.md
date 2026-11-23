# Prologshell proofs

`proofs/prologshell_proofs.pl` checks every theorem below exhaustively over a bounded domain:

- line lists of length 0 to 4 over `["", "a", "b", "ab", "b a", "A,b"]` (1,555 lists)
- counts from −1 to 6
- strings of length 0 to 5 over `{a, \n}`
- strings of length 0 to 3 over the shell-sensitive characters `a ' " space $ \ backtick`

This section gives the general argument. The bounded check guards the implementation; the argument shows why the property holds for all inputs. Notation: `L` is a list of newline-free strings, `|L|` is its length, and `++` is append.

## Evaluator

**T1 Associativity.** `sh((A>>M1)>>M2) = sh(A>>(M1>>M2))`.
By the clauses of `sh/2` and `apply_method/3`, both sides reduce to `apply_method(M2, apply_method(M1, sh(A)))`. The left side evaluates `sh(A>>M1)` and then applies `M2`. The right side applies the chain method `M1>>M2`, which `apply_method` defines as `M1` followed by `M2`.

**T2 Nesting.** `sh(A>>M1>>…>>Mn) = Mn(…M1(sh(A)))`, which matches Starlog's `d(a(b(…)))`. This follows by induction on n using T1. Since `>>` is `yfx`, `A>>M1>>…>>Mn` parses as `(A>>…>>Mn−1)>>Mn`. The induction hypothesis gives the inner value, and the `>>` clause applies `Mn` to it.

**T3 Literals.** Strings, numbers and lists hit the `literal/1` clause, which returns its input.

## Pipe values

**T4 `lines(text(L)) = L`.** For `L = []`, `text` gives `""` and `lines("")` gives `[]`. For `L = [l1,…,lk]` with k ≥ 1, `text` gives `l1\n…lk\n`. Splitting on `\n` yields `[l1,…,lk,""]`, because no `li` contains a newline, and `lines` drops exactly the one trailing `""`.

**T5 `text(lines(S)) = S`** when S is `""` or ends in `\n`. Write `S = l1\n…lk\n`. Then `lines(S) = [l1,…,lk]`, and `text` restores S by T4's construction.

**T6** `lines` is the identity on lists of strings, so `lines(lines(X)) = lines(X)`.

## Involutions and sorting

**T7–T8.** `tac` is `reverse/2`, and `reverse(reverse(L)) = L`. `rev` applies `reverse` to each line's characters, so it is an involution pointwise.

**T9.** `sort_lines` is `msort/2`, which returns an ordered permutation. An ordered list is a fixed point of `msort`.

**T10.** `uniq` keeps the first element of each maximal run of equal adjacent elements (induction on `uniq_/2`). Its output has no equal neighbours, so a second `uniq` is the identity. In a sorted list, equal elements are adjacent, so `uniq(msort(L))` is the sorted list without duplicates, which is `sort/2`, which is `sort_u`.

**T11.** `sort_r` is defined as `reverse ∘ sort_lines`.

## Filters

**T12 Partition.** `include(p)` and `exclude(p)` split L into the elements satisfying p and those that don't, each in their original order. Induction on L shows that L interleaves the two lists, so `|grep| + |grep_v| = |L|`.

**T13.** `grep_c` is defined as `length ∘ grep`.

**T14–T16.** `head_n` sets K = max(0, min(N, |L|)), builds a fresh list of length K and unifies it with a prefix of L, which exists and is unique because K ≤ |L|. `tail_n` does the same with a suffix. For 0 ≤ K ≤ |L|, the prefix of length K and the suffix of length |L|−K are the two parts of the unique split of L at K.

**T17.** `nth_line(I)` is `nth1(I, L)` when 1 ≤ I ≤ |L|, and `""` otherwise.

**T18.** `uniq_c` emits one `"n x"` per maximal run, where n is the run's length. The runs partition L, so their lengths sum to |L|.

## Transforms

**T19.** `sed(X, X)` splits each line on X and joins it again with X. `atomic_list_concat/3` in split mode is the inverse of join mode for the same separator.

**T20.** If Old does not occur in a line, splitting gives the singleton `[line]`, and joining a singleton returns it unchanged.

**T21.** `tr(F, F)` maps each character to itself, using its last index in F. `tr_d("")` deletes nothing.

**T22.** Each listed command is a `maplist/3` over the lines, which preserves length.

**T23.** If a line is `A,B` and neither A nor B contains a comma, splitting on `,` gives exactly `[A, B]`.

**T24.** `wc_c` is the length of `text(L)`. That is each line's length plus one newline per line, and 0 for `[]`.

**T25.** `xargs(M)` is defined as `append ∘ map(M)`, after normalising each result with `lines`. That normalisation is the identity on the list results used here (T6).

## Files

**T26.** `write_to` writes `text(L)`, and `cat` reads the file and applies `lines`, so the result is L by T4.

**T27.** `append_to` writes `text(L2)` after `text(L1)`. Since `text(L1) ++ text(L2) = text(L1 ++ L2)`, T4 gives `L1 ++ L2`.

**T28.** The file holds exactly `text(L)`, and these characters are one byte each, so its size is `wc_c(L)`.

**T29–T31.** `cp` is `copy_file/2` to the target, and the source is untouched. `mv` is `rename_file/2`, which keeps the content and removes the source name. `tee` writes its input (T26) and returns it unchanged.

**T32.** `mkdir` is `make_directory_path/1` (like `mkdir -p`). `rm_r` deletes the directory tree, so afterwards nothing exists at that path.

## Quoting and servers

**T33 `shell_quote` soundness.** The quoted form is `'` + S' + `'`, where every `'` in S becomes `'"'"'`. Inside single quotes, `/bin/sh` treats every character literally except `'`. Each `'"'"'` closes the quote, adds a literal `'` from inside double quotes, and reopens the quote. Concatenating the pieces gives back S exactly. The proof runs `printf %s <quoted>` through `/bin/sh` for all 400 strings over the dangerous characters and compares the output byte for byte.

**T34 Remote = local.** `on(H, C)` sends `sh(C, O), write_canonical(O)` to the server. `write_canonical` and `term_string` are inverse on ground terms (strings, numbers, lists), and the server runs the same `sh/2`. So the result equals `sh(C)`, given T33 for the transport quoting. The check uses `tests/fake_bin/ssh`, which executes the received command with `/bin/sh` as `sshd` does.

**T35 Starlog equivalence.** Starlog compiles `X is A >> M1 >> M2` to `v0 = A, M1(…, v0, v1), M2(…, v1, X)`, by `create_method_call` in `starlog_expand.pl`. That is the nesting of T2, so the result agrees with `sh/2`. The proof expands and runs 7,267 such chains through Starlog and compares the results.
