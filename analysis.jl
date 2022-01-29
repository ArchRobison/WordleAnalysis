import Base: empty!, getindex, show
import Printf: @printf

if !isdefined(Main, :Partition)
include("core.jl")
end

"""
    entropy(partition)

Return average entropy in a partition.
The entropy of a bucket of size n is defined as lg(n), i.e. the number of additional bits
required to distinguish items in the bucket. The average is taken over all answers 
in the partition.
```
julia> p=partition(["aback", "abase", "abate", "abbey"], "abbot")
ggybb aback abase
ggyby abate
gggbb abbey

julia> entropy(p)
0.5
```
"""
function entropy(p::Partition)
    sum = 0.0
    count = 0
    for i in p.nonEmptyBuckets
        n = length(p.buckets[i])
        sum += n * log(2, n)
        count += n
    end
    return sum / count
end

"""
    entropy(answers, guess)

Return remaining entropy, after partitioning possible answers with a guess.

Example:
```
julia> entropy(["aback", "abase", "abate", "abbey"], "abbot")
0.5
```
"""
entropy(answers::Vector{String}, guess::String) = entropy(partition(answers, guess))

"""
    minEntropy(partition, answers, guesses, maxCount)

Low-level variant of minEntropy. Caller passes in a Partition to use as scratch space.
Returns (entropy, guessIndex) pairs that minimize remaining entropy, in order from least to highest entropy.
"""
function minEntropy(scratch::Partition, answers::Vector{AnswerIndex}, guesses::Vector{GuessIndex}, maxCount::Integer)
    e = zeros(Float64, length(guesses))
    for i in 1:length(guesses)
        partition!(scratch, answers, guesses[i])
        e[i] = entropy(scratch)
    end
    perm = sortperm(e)
    return [(guesses[j], e[j]) for j in perm[1:min(maxCount,end)]]
end

"""
    minEntropy(answers, guesses, maxCount)

Return (entropy, guess) pairs that minimize remaining entropy, in order from least to highest entropy.
Returns min(maxCount, length(guesses)) elements.

Example:
```
julia> minEntropy(answerWords, guessWords, 4)
4-element Vector{Tuple{String, Float64}}:
 ("soare", 5.290836367768747)
 ("roate", 5.2940171538556315)
 ("raise", 5.29888678732612)
 ("raile", 5.311086768195722)
```
"""
function minEntropy(answers::Vector{String}, guesses::Vector{String}, maxCount::Integer)
    p = Partition()
    best = minEntropy(p, indicesOfWords(answers, answerWords), indicesOfWords(guesses, guessWords), maxCount)
    return [(guessWords[pair[1]], pair[2]) for pair in best]
end

"""
    search(answers, guesses, width)

Low-level overload of search that takes indices instead of strings.
"""
function search(answers::Vector{AnswerIndex}, guesses::Vector{GuessIndex}, width::Integer)
    minAvg = typemax(Float64)
    minGuess = nothing
    p = Partition()
    for (guess, entropy) in minEntropy(p, answers, guesses, width)
        partition!(p, answers, guess)
        if length(p) == 1
            # Useless guess
            continue
        end
        # sum accumulates number of guesses to guess each possible answer.
        sum = 0.0
        for i in p.nonEmptyBuckets
            # Get possible answers in the bucket
            a = p.buckets[i]
            if length(a) > 2
                sum += search(a, guesses, width)[2] * length(a)
            elseif length(a) == 2
                # Choose one of the answers as the next guess. 
                # Takes one guess if lucky, two if not, for total of 3 over the two answers.
                sum += 3.0
            elseif answerWords[a[1]] == guessWords[guess]
                # Guess matched the answer
                sum += 0.0
            else 
                # Only one possible answer left
                sum += 1.0
            end
        end
        avg = sum / length(answers) + 1
        if avg < minAvg
            minAvg = avg
            minGuess = guess
        end
    end
    return (minGuess, minAvg)
end

"""
    search(answers, guesses, width)

Do heuristic recursive search that minimizes average number of guesses to pick out an answer.
At each tree level, width guesses that minimize entropy are tried.

Returns pair with best first guess and average number of guesses (including that guess).
```
julia> search(["aback", "abase", "abate", "abbey"], ["aback", "abase", "abate", "abbey"], 4)
("abase", 1.75)
```
"""
function search(answers::Vector{String}, guesses::Vector{String}, width::Integer) 
    (guessIndex, avg) = search(indicesOfWords(answers, answerWords), indicesOfWords(guesses, guessWords), width)
    return (guessWords[guessIndex], avg)
end

"""
    benchmark()

Time method `search` for successively wider windows.
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
```
"""
function benchmark()
    for width in 1:20
        p = @time search(answerWords, guessWords, width)
        @printf("%d %s %.6f\n", width, p[1], p[2])
    end
end

nothing
