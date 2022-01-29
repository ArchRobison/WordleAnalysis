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
  3.843582 seconds (239.37 k allocations: 77.807 MiB, 0.23% gc time)
1 soare 3.532613
 10.000957 seconds (831.42 k allocations: 279.804 MiB, 0.33% gc time)
2 soare 3.524406
 19.578414 seconds (1.78 M allocations: 608.635 MiB, 0.31% gc time)
3 soare 3.520086
 33.192401 seconds (3.19 M allocations: 1.075 GiB, 0.32% gc time)
4 raile 3.514903
 52.062859 seconds (5.03 M allocations: 1.703 GiB, 0.33% gc time)
5 reast 3.480346
 76.379512 seconds (7.41 M allocations: 2.523 GiB, 0.33% gc time)
6 slate 3.476026
 99.450780 seconds (10.45 M allocations: 3.576 GiB, 0.33% gc time)
7 slate 3.474730
130.135821 seconds (14.07 M allocations: 4.829 GiB, 0.33% gc time)
8 slate 3.474730
179.804372 seconds (18.86 M allocations: 6.498 GiB, 0.34% gc time)
9 slate 3.474298
234.107886 seconds (24.37 M allocations: 8.419 GiB, 0.34% gc time)
10 slate 3.474298
268.222825 seconds (31.58 M allocations: 10.943 GiB, 0.38% gc time)
11 slate 3.473866
352.456360 seconds (39.65 M allocations: 13.777 GiB, 0.38% gc time)
12 slate 3.473866
436.780647 seconds (49.65 M allocations: 17.296 GiB, 0.39% gc time)
13 slate 3.472570
570.179705 seconds (59.91 M allocations: 20.908 GiB, 0.39% gc time)
14 slate 3.472138
650.177755 seconds (72.24 M allocations: 25.264 GiB, 0.37% gc time)
15 slate 3.472138
788.506429 seconds (85.58 M allocations: 29.971 GiB, 0.38% gc time)
16 slate 3.471706
898.101952 seconds (102.62 M allocations: 36.002 GiB, 0.40% gc time)
17 slate 3.470842
991.020468 seconds (120.20 M allocations: 42.228 GiB, 0.42% gc time)
18 slate 3.469114
1129.726298 seconds (140.88 M allocations: 49.574 GiB, 0.38% gc time)
19 slate 3.469114
1237.442731 seconds (165.57 M allocations: 58.331 GiB, 0.40% gc time)
20 slate 3.469114
```
It would appear that `slate` is likely the best first guess possible.
