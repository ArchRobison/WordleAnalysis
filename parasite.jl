# Functions for getting parasitic assist from using other people's results.

include("core.jl")

"""
    readResponses(filename)

Read responses from a file. Each line should be one of:
* a letter-coded response (b=black, y=yellow, g=green),
* a comment line beginning with #.
* a blank line
"""
function readResponses(filename::AbstractString)
    result = Response[]
    for line in eachline(filename)
        m = match(r"^[byg]{5}", line)
        if m ≠ nothing
            push!(result, Response(m.match))
            continue
        end
        m = match(r"^#.*$", line)
        m ≠ nothing && continue
        m = match(r"^ *$", line)
        m ≠ nothing && continue
        error("invalid line: $line")
    end
    return result
end

"""
    hasResponse(answer, response)

True if for given answer, there exists a guess that yields the given response.
This is a low-level function that operates on an AnswerIndex.
"""
function hasResponse(answer::AnswerIndex, response::Response)
    for g in 1:length(guessWords)
        if responseMatrix[answer,g] == response
            return true
        end
    end
    return false
end

"""
    sift(answers, response)

Return answers that have at least one guess that yields the given response.
This is a low-level routine that operates on Vector{AnswerIndex}.
"""
sift(answers::Vector{AnswerIndex}, response::Response) = filter(a->hasResponse(a, response), answers)

"""
    sift(answers, response)

Return answers that have at least one guess that yields the given response.
"""
function sift(answers::Vector{String}, response::String)
    return answerWords[sift(indicesOfWords(answers, answerWords), Response(response))]
end

"""
    sift(answers, responses)

Return answers that are plausible for the given responses.
"""
function sift(answers::Vector{String}, responses::Vector{Response})
    a = indicesOfWords(answers, answerWords)
    for r in responses
        a = sift(a, r)
    end
    return answerWords[a]
end

"""
    findErrors(answer, reponses)

Return responses that are inconsistent with the answer.
"""
function findErrors(answer::String, responses::Vector{Response})
    result = Response[]
    for r in responses
        if !hasResponse(indexOfWord(answer,answerWords), r)
            push!(result, r)
        end
    end
    return result
end

nothing
