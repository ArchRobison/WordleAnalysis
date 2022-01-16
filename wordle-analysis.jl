"""
    Return vector of strings from a file. 
    Canonicalize uppercase as lowercase.
"""
readWords(filename::AbstractString) = [lowercase(line) for line in eachline(filename)]

"""
    Possible answer words
"""
const answerWords = sort(readWords("answers.txt"))

"""
    Allowed guess words
"""
const guessWords = sort([answerWords; readWords("guesses-other.txt")])

"""
    Color code for a position in a response
"""
@enum Color grey=0 yellow=1 green=2

"""
    Response to a guess.
"""
const Response = Vector{Color}

"""
    Make an all-grey reponse. Useful for allocating a Response.
"""
makeResponse() = fill(grey,5)

"""
    Get response for given answer and guess.
"""
function response!(response::Response, answer::String, guess::String)
    for i in 1:5
        if guess[i] == answer[i]
            response[i] = green
        elseif guess[i] in answer
            response[i] = yellow
        else
            response[i] = grey
        end
    end
    return response
end

"""
    Get response for given answer and guess

Example:
```
julia> response("abbot","abate")
5-element Vector{Color}:
 green::Color = 2
 green::Color = 2
 yellow::Color = 1
 yellow::Color = 1
 grey::Color = 0
```
"""
response(answer::String, guess::String) = response!(makeResponse(), answer, guess)

"""
    buckets(answers, guess)

Build map from responses to a guess to answers matching that response.

Example:
```
julia> buckets(["aback", "abase", "abate"], "abbot")
Dict{Vector{Color}, Vector{String}} with 2 entries:
  [green, green, yellow, grey, yellow] => ["aback", "abase"]
  [green, green, yellow, grey, yellow] => ["abate"]
```
"""
function buckets(answers::Vector{String}, guess::String)
    f = Dict{Response,Vector{String}}()
    r = makeResponse()
    for a in answers
        response!(r, a, guess)
        push!(get!(f, r, String[]), a)
    end
    return f
end

"""
    entropy(answers, guess)

Return remaining entropy, given remaining possible answers and a guess.
The entropy is defined as sum of (n log n) where n is the size of each bucket.

Example:
```
julia> entropy(["aback", "abase", "abate"], "abbot")
1.3862944f0
```
"""
function entropy(answers::Vector{String}, guess::String)
    # Frequencies
    f = Dict{Response,Int}()
    # Temporary variable for a response
    r = makeResponse()
    for a in answers
        response!(r, a, guess)
        f[r] = 1 + get(f, r, 0)
    end
    return sum(n * log(Float32(n)) for n in values(f))
end

"""
    minEntropy(answers, guesses)

Find guess that minimizes remaining entropy.

Example:
```julia-repl
julia> minEntropy(answerWords, guessWords)
"roate"
```
"""
function minEntropy(answers::Vector{String}, guesses::Vector{String})
    e = [entropy(answers, g) for g in guesses]
    return guesses[findmin(e)[2]]
end

"""
    Return answers consistent with given guess and response.
"""
winnow(answers::Vector{String}, guess::String, r::Response) = filter(a -> response(a, guess) == r, answers)

