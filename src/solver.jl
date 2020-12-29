struct GIValue{G <: AbstractGrid}
    grid::G
    gdata::Vector{Float64}
end

evaluate(v::GIValue, s::AbstractVector{Float64}) = interpolate(v.grid, v.gdata, convert(Vector{Float64}, s))

@with_kw mutable struct CWorldSolver{G<:AbstractGrid, RNG<:AbstractRNG} <: Solver
    grid::G                     = RectangleGrid(range(0.0, stop=10.0, length=30), range(0.0, stop=10.0, length=30))
    n_actions_solve::Int              = 10 #number of actions to sample for solving
    n_actions_eval::Int              = 10 #number of actions to sample for policy evaluation
    max_iters::Int              = 50
    tol::Float64                = 0.01
    n_transitions::Int          = 20    #number of transitions to sample and average over
    value_hist::AbstractVector  = []
    rng::RNG                    = Random.GLOBAL_RNG
end

struct CWorldPolicy{RNG<:AbstractRNG} <: Policy
    w::CWorld #need for transition call
    rng::RNG #for the transition call
    n_actions::Int  #number of actions to sample
    n_transitions::Int  #number of transitions to sample and average over 
    V::GIValue #value function
end

function POMDPs.solve(sol::CWorldSolver, w::CWorld)
    sol.value_hist = []
    data = zeros(length(sol.grid))
    val = GIValue(sol.grid, data)

    for k in 1:sol.max_iters
        newdata = similar(data)  #for keeping history, results in a lot of allocations
        for i in 1:length(sol.grid)
            s = Vec2(ind2x(sol.grid, i))
            if isterminal(w, s)
                dummy_a = Vec2(0.0,0.0) 
                newdata[i] = reward(w, s, dummy_a) 
            else
                best_Qsum = -Inf
                for a in rand(sol.rng, actions(w,s), sol.n_actions_solve)
                    Qsum = 0.0
                    for j in 1:sol.n_transitions 
                        sp, r = @gen(:sp, :r)(w, s, a, sol.rng)
                        Qsum += r + discount(w)*evaluate(val, sp)
                    end
                    best_Qsum = max(best_Qsum, Qsum)
                end
                newdata[i] = best_Qsum/sol.n_transitions
            end
        end
        push!(sol.value_hist, val)
        print("\rfinished iteration $k")
        val = GIValue(sol.grid, newdata)
    end

    return CWorldPolicy(w, sol.rng, sol.n_actions_eval, sol.n_transitions, val)
end

function POMDPs.action(p::CWorldPolicy, s::AbstractVector{Float64})
    best_Qsum = -Inf
    best_index = 0
    acts = rand(p.rng, actions(p.w,s), p.n_actions)
    for (i,a) in enumerate(acts)
        Qsum = 0.0
        for k in 1:p.n_transitions
            sp, r = @gen(:sp, :r)(p.w, s, a, p.rng)
            Qsum += r + discount(p.w)*evaluate(p.V, sp)
        end
        if Qsum > best_Qsum
            best_Qsum = Qsum
            best_index = i
        end
    end
    acts[best_index]
end

POMDPs.value(p::CWorldPolicy, s::AbstractVector{Float64}) = evaluate(p.V, s) 
