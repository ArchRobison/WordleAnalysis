# Functions for creating "word list" for Nerdle.

import Base: isless, show

"""
Represents a mathematical expression.
"""
struct Expr
    # Numerical value of the expression
    value::Int32

    # String representation of expression
    rep::String
end

show(o::IO, x::Expr) = print(o, x.rep)

"""
Order expressions by length of their strings. Expressions of equal length are ordered by numerical value.
"""
function isless(x::Expr, y::Expr)
    if length(x.rep) ≠ length(y.rep)
        return length(x.rep) < length(y.rep)
    end
    return x.value < y.value
end

"""
    op(f, op, left, right)

Create plausible expressions from operands chosen from left and right.
f implements the operation and op is the character reprsentation of it.
f should return nothing if the operation is invalid.
"""
function op(f::Function, op::Char, left::Vector{Expr}, right::Vector{Expr})
    @assert issorted(left)
    @assert issorted(right)

    result = Expr[]
    for x in left
        for y in right
            if length(x.rep) + 1 + length(y.rep) > 6
                break
            end
            z = f(x.value, y.value)
            if z ≠ nothing && 0 ≤ z
                push!(result, Expr(z, x.rep * op * y.rep))
            end
        end
    end
    return result
end

"""
    divide(x,y)

Return x/y if the quotient is defined and exact, nothing otherwise.
"""
function divide(x::Integer, y::Integer)
    if y == 0 || x % y ≠ 0
        return nothing
    end
    return div(x,y)
end

"""
Return equations allowed by Nerdle.    
"""
function equations()
    # Literals
    lits = [Expr(i, string(i)) for i in 1:999]

    # Terms with two literals
    mul2 = op(*, '*', lits, lits)
    div2 = op(divide, '/', lits, lits)
    term2 = sort([mul2;div2])

    # Terms with three literals
    mul3 = op(*, '*', term2, lits)
    div3 = op(divide, '/', term2, lits)
    term3 = [mul3;div3]
    terms = sort([lits; term2; term3])

    # Expressions with two terms
    add2 = op(+, '+', terms, terms)
    sub2 = op(-, '-', terms, terms)
    expr2 = sort([add2;sub2])

    # Expressions with three terms
    add3 = op(+, '+', expr2, terms)
    sub3 = op(-, '-', expr2, terms)
    expr3 = sort([add3;sub3])

    # Expressions without final filtering for equation length
    exprs = sort([lits; terms; expr2; expr3]; by=x->x.value)

    # Get equations that are 8 characters
    result = String[]
    for e in exprs
        rep = e.rep * '=' * string(e.value)
        if length(rep) == 8
            push!(result, rep)
        end
    end
    return result
end

"""
Write word lists for Nerdle.

Overwrites files `answers.txt` and `guesses-other.text`
"""
function makeNerdleWordLists()
    eq = equations();
    open("answers.txt","w") do f
        for e in eq
            println(f, e)
        end
    end
    open("guesses-other.txt","w") do f
    end
end
