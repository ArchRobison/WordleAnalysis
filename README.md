# WordleAnalysis

Analyze Wordle strategies.

# Files

* answers.txt - answer words

* guesses-other.txt - allowed guesses that are not in answers.txt

* core.jl - core data structures and tables

* analysis.jl - routines for analysis. Try running `benchmark()` to see estimates of best first word with successively
  wider search windows.
```
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
```
The non-timing lines list the search width, first guess, and average number of guesses across all answers,
including the first guess. It would appear that `slate` is the best first guess.
