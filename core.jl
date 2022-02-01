# Core data structures for analyzing Wordle

import Base: empty!, getindex, length, show

"""
    Return vector of strings from a file.
    Canonicalize uppercase as lowercase.
"""
readWords(filename::AbstractString) = String[lowercase(line) for line in eachline(filename)]

"""
    Words that Wordle uses as possible answers.
"""
const answerWords = sort(readWords("answers.txt"))

"""
     Index into answerWords
"""
const AnswerIndex = UInt16

"""
    Allowed guess words. These are the answerWords and additional words that Wordle allows as guesses.
"""
const guessWords = sort([answerWords; readWords("guesses-other.txt")])

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
bbbyg

julia> Response("abbot","abate")
ggbyb
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

        usedAnswerLetters = 0  # Bitset of answer letters used so far

        greenGuessLetters = 0 # Bitset of guess letters classified as green
        for i in 1:5
            if guess[i] == answer[i]
                greenGuessLetters |= 1 << i
            end
        end
        usedAnswerLetters = greenGuessLetters

        yellowGuessLetters = 0 # Bitset of guess letters classified as yellow
        for i in 1:5
            if iseven(greenGuessLetters >> i)
                for j in 1:5
                    if iseven(usedAnswerLetters >> j) && answer[j] == guess[i]
                        yellowGuessLetters |= 1 << i
                        usedAnswerLetters |= 1 << j
                        break
                    end
                end
            end
        end

        sum = 1
        placeValue = 1
        for i in 1:5
            sum += ((greenGuessLetters >> i) & 1 * 2 + (yellowGuessLetters >> i) & 1) * placeValue
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

"""
    Test that Response constructors work.
"""
function testResponse()
    @assert Response("abbot","abate") == Response("ggbyb")
    @assert Response("wrung","nanny") == Response("bbbgb")
end

testResponse()

"""
    Matrix of precomputed responses, indexed by [answerIndex, guessIndex].
"""
const responseMatrix = [Response(answerWords[i], guessWords[j]) for i in 1:length(answerWords), j in 1:length(guessWords)]

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
    Partition() = new(fill(nothing, 3^5), Int16[])
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
