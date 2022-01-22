# Core data structures for analyzing Wordle

# const names that require reading files or expensive computations are not recomputed.

import Base: empty!, getindex, length, show

"""
    Return vector of strings from a file. 
    Canonicalize uppercase as lowercase.
"""
readWords(filename::AbstractString) = String[lowercase(line) for line in eachline(filename)]

if !isdefined(Main, :answerWords)
"""
    Possible answer words
"""
const answerWords = sort(readWords("answers.txt"))
end

"""
     Index into answerWords
"""
const AnswerIndex = UInt16

if !isdefined(Main, :guessWords)
"""
    Allowed guess words
"""
const guessWords = sort([answerWords; readWords("guesses-other.txt")])
end

"""
     Index into guessWords
"""
const GuessIndex = UInt16

"""
     Get index of word in list

Example:
```
julia> indexOfWord("abate",answerWords)
0x0003
```
"""
function indexOfWord(word::String, list::Vector{String})
    i = searchsortedfirst(list, word)
    if i > length(list) || list[i] ≠ word
        error("$word not in list")
    end
    return UInt16(i)
end

"""
     Get indices of word in list
"""
indicesOfWords(words::Vector{String}, list::Vector{String}) = [indexOfWord(w, list) for w in words]

"""
    Color code for a position in a response
"""
@enum Color black=0 yellow=1 green=2

"""
    Color enums for letters
"""
const colorOfLetter = Dict('b' => black, 'y' => yellow, 'g' => green)

"""
    Response to a guess.

    Can be constructed from string of letter codes or (answer, guess).

Examples:
```
julia> Response("bbbyg")
BBBYG

julia> Response("abbot","abate")
GGYYB
```
"""
struct Response
    rep :: UInt8 # Encoded in ternary, with 1 added so it can be used as a one-based index.

    function Response(ternaryEncoding::Integer) 
        @assert ternaryEncoding ≥ 1
        @assert ternaryEncoding ≤ 3^5
        return new(ternaryEncoding)
    end

    function Response(colors::AbstractString) 
        @assert length(colors) == 5
        sum = 1
        placeValue = 1
        for c in colors
            sum += Int(colorOfLetter[lowercase(c)]) * placeValue
            placeValue *= 3
        end
        return new(sum)
    end

    function Response(answer::String, guess::String)
        @assert length(answer) == 5
        @assert length(guess) == 5
        sum = 1
        placeValue = 1
        for i in 1:5
            if guess[i] == answer[i]
                sum += Int(green) * placeValue
            elseif guess[i] in answer
                sum += Int(yellow) * placeValue
            end
            placeValue *= 3
        end
        return new(sum)
    end
end

"""
    Print response using colored letters.
"""
function show(io::IO, response::Response)
    value = response.rep - 1
    style = [:light_black, :light_yellow, :light_green]
    for position in 1:5
        k = value % 3
        printstyled(io, "byg"[k+1]; color=style[k+1])
        value = div(value, 3)
    end
end

if !isdefined(Main, :responseMatrix)
"""
    Matrix of precomputed responses, indexed by [answerIndex, guessIndex].
"""
const responseMatrix = [Response(answerWords[i], guessWords[j]) for i in 1:length(answerWords), j in 1:length(guessWords)]
end

"""
    Partition

Partition of answer indices. The interface behaves similarly to an assocative map from Response to Vector{AnswerIndex}.
"""
struct Partition
    # Indices of answers in the bucket, or nothing if bucket not yet needed.
    buckets::Vector{Union{Nothing,Vector{AnswerIndex}}}

    # Indices of non-empty buckets
    nonEmptyBuckets::Vector{Int16}

    # Empty partition
    function Partition()
        emptyBuckets = [Int16[] for i in 1:3^5]
        return new(fill(nothing, 3^5), Int16[])
    end
end

"""
    Support for iterating over non-empty buckets in a partition. Each iteration returns a (Response, Vector{AnswerIndex}). 
"""
function Base.iterate(p::Partition, state=1)
    if length(p.nonEmptyBuckets) < state
        return nothing
    else
        i = p.nonEmptyBuckets[state]
        return ((Response(i), p.buckets[i]), state + 1)
    end
end

"""
    Number of non-empty buckets in a partition
"""
length(p::Partition) = length(p.nonEmptyBuckets)

"""
    Get bucket for given response
"""
function getindex(p::Partition, r::Response)
    b = p.buckets[r.rep]
    if b == nothing
        b = AnswerIndex[]
        p.buckets[r.rep] = b
    end
    return b
end

function show(io::IO, p::Partition)
    rowDelim = ""
    for (r, b) in p
        print(io, rowDelim)
        rowDelim = "\n"
        print(io, r)
        for j in b
            print(io, " ", answerWords[j])
        end
    end
end

"""
    Set all buckets to empty.
"""
function empty!(p::Partition)
    for i in p.nonEmptyBuckets
        empty!(p.buckets[i])
    end
    empty!(p.nonEmptyBuckets)
end

"""
    Add answer to partition
"""
function pushAt!(p::Partition, r::Response, a::AnswerIndex)
    b = p[r]
    if isempty(b)
        push!(p.nonEmptyBuckets, r.rep)
    end
    push!(b, a)
    return p
end

"""
    Set p to partition of answers induced by guess.
    This is a low-level imperative method that takes indices instead of strings.
"""
function partition!(p::Partition, answers::Vector{AnswerIndex}, guess::GuessIndex)
    empty!(p)
    for a in answers
        pushAt!(p, responseMatrix[a, guess], a)
    end
end

"""
    partition(answers, guess)

Return partition of answers induced by guess.
This is a high-level method that takes strings instead of indices.

Example:
```
julia> partition(["aback", "abase", "abate", "abbey"], "abbot")
ggybb aback abase
ggyby abate
gggbb abbey
```
"""
function partition(answers::Vector{String}, guess::String)
    p = Partition()
    partition!(p, indicesOfWords(answers, answerWords), indexOfWord(guess, guessWords))
    return p
end

"""
    partition[response]

Returns answers in partition for given response.
This is a high-level method that takes the string form of a response and returns strings.
```
julia> partition(["aback", "abase", "abate", "abbey"], "abbot")["ggybb"]
2-element Vector{String}:
 "aback"
 "abase"
```
"""
getindex(p::Partition, response::String) = answerWords[p[Response(response)]]

"""
    winnow(answers, guess, response)

Return subset of answers consistent with response to a guess.
"""
function winnow(answers::Vector{String}, guess::String, response::String)
    r = Response(response)
    g = indexOfWord(guess, guessWords)
    a = indicesOfWords(answers, answerWords)
    return answerWords[[ai for ai in a if responseMatrix[ai, g] == r]]
end

nothing
