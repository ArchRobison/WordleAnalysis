# WordleAnalysis

Estimate optimal strategy for Wordle.

The approach is semi-exhuastive search: use a heuristic to carve out promising
arts of the search space and then search it exhaustively.

## Formulation

The problem can be formulated as building a tree where each node is a guess,
and each edge is a response from the game. The children of a node represent the
next guess to make according to the response on edge from the parent.

The goal is to minimize the average path length (number of nodes, i.e. turns) for
all paths from the root to nodes that have answers. The set of allowed guess words
has 12972 words; the set of answer words is only 2315 words.

## Partitioning

Each guess partitions the possible answers into buckets, where each bucket holds
the answers consistent with a response. E.g., for a top-level guess "slate", the
partition has 147 buckets, including seven buckets listed below, prefixed
by the response code (`b`=black, `y`=yellow, `g`=green).
```
...
gggyb slant
ggggg slate
gggbg slave
ggbby sleek sleep
ggbyy sleet slept
ggbbg slice slide slime slope
ggbbb slick slimy sling slink sloop slosh slump slung slunk slurp slush slyly
...
```
In the code, type `Partition` represents a partition, and has nice colored pretty printing.
The example above is an excerpt from running:
```
julia> partition(answerWords,"slate")
```

## Heuristic

The heuristic is: given a bucket with n words in it, lg(n) bits of additional
information are required to pick out the answer. Thus to estimate how good a guess is,
use it to partition the possible answers, and then compute the average number of
additional bits needed to distinguish the items. The average is across the buckets
and weighted by the size of the buckets.

For example, running:
```
julia> entropy(partition(answerWords,"roate"))
5.2940171538556315
```
tells us that we'll need about 5.29 bits of additional information.

## Detailed Search

Of course the lg(n) is an estimate for some idealized language where letter probabilities
are random and independent. Particularly for small n, "chunkiness" effects take over.
For small n, it's thus more accurate to actually compute the average path-length in a subtree.
So use the lg(n) as an estimate to guide combinatorial search.

Build the tree top-down. The code does not record the tree, but only the top-level word
and average path length. Starting with all the possible answers, apply the heuristic to
select the W most promising guesses, where W is a "width" parameter to the search.
Use each of these to generate a partition, and recursively find good guesses for each bucket,
using the same approach of trying the W most promising guesses.

## Optimization Notes

Responses for all possible pairs(answer x guess) are computed ahead of time, and stored in
`responseMatrix`. Each response fits in a byte, via base-3 encoding.  The encoding is offset
by one, i.e. is in 1:3^5, so it can be used as a dense index into a `Vector`.

Efficient partitioning is important. Words in `Partition` are represented by their indices
in the constant vector `answerWords`.  This enables fundamental operations on `Partition`
to be fast. Adding a word to a `Partition` takes amortized O(1) time.

For sake of exploration, many of the index-based routines have friendly wrapper overloads
that take strings.

# Files

* `answers.txt` - answer words

* `guesses-other.txt` - allowed guesses that are not in `answers.txt`.
  The allowed guesses are the union of this file and `answers.txt`.

* `core.jl` - core data structures and tables

* `analysis.jl` - routines for analysis.

* `parasite.jl` - routines for exploiting knowledge from posted results

Run `benchmark()` to see estimates of best first word with successively wider search windows.
Sample output shown below. The non-timing lines list the search width parameter W, best first guess found,
and average number of guesses across all answers, including the first guess.
```
julia> include("analysis.jl")

julia> benchmark()
  3.444578 seconds (153.36 k allocations: 70.833 MiB, 0.60% gc time, 0.63% compilation time)
1 soare 3.527862
 11.395222 seconds (456.70 k allocations: 246.451 MiB, 0.90% gc time)
2 roate 3.519654
 18.688045 seconds (971.81 k allocations: 536.884 MiB, 0.34% gc time)
3 soare 3.515335
 32.628094 seconds (1.73 M allocations: 973.899 MiB, 0.35% gc time)
4 raile 3.507559
 45.556954 seconds (2.72 M allocations: 1.506 GiB, 0.38% gc time)
5 reast 3.473434
 65.069887 seconds (4.00 M allocations: 2.232 GiB, 0.31% gc time)
6 slate 3.470410
 95.116648 seconds (5.62 M allocations: 3.163 GiB, 0.30% gc time)
7 slate 3.469546
124.790849 seconds (7.53 M allocations: 4.263 GiB, 0.30% gc time)
8 slate 3.468683
166.154597 seconds (10.07 M allocations: 5.741 GiB, 0.31% gc time)
9 slate 3.468251
208.248441 seconds (12.96 M allocations: 7.430 GiB, 0.31% gc time)
10 slate 3.467387
254.798649 seconds (16.70 M allocations: 9.624 GiB, 0.31% gc time)
11 slate 3.467387
334.379293 seconds (20.95 M allocations: 12.129 GiB, 0.24% gc time)
12 slate 3.466955
392.652938 seconds (26.02 M allocations: 15.138 GiB, 0.25% gc time)
13 slate 3.466091
```
It would appear that `slate` is likely the best first guess possible.
