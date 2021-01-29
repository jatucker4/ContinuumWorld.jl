module ContinuumWorld

# package code goes here
using Random
using LinearAlgebra
using POMDPs
using StaticArrays
using Parameters
using GridInterpolations
using POMDPModelTools
using POMDPModels
using Distributions
using Statistics
using StatsBase
using Plots
plotly()

export
    CWorld,
    CWorldVis,
    CircularRegion,
    CWorldStateSpace,
    CircularActionSpace,
    Vec2,
    CWorldSolver,
    
    evaluate

const Vec2 = SVector{2, Float64}

struct CircularRegion
    center::Vec2
    radius::Float64
end

Base.in(v::Vec2, r::CircularRegion) = LinearAlgebra.norm(v-r.center) <= r.radius

const default_regions = [CircularRegion(Vec2(3.5, 2.5), 0.5),
                         CircularRegion(Vec2(3.5, 5.5), 0.5),
                         CircularRegion(Vec2(8.5, 2.5), 0.5),
                         CircularRegion(Vec2(7.5, 7.5), 0.5)]
const default_rewards = [-10.0, -5.0, 10.0, 3.0]

#action is Vec2(magnitude, angle_deg)
@with_kw struct CircularActionSpace
    r_max::Float64 = 1.0
end
function Base.rand(rng::AbstractRNG, d::Random.SamplerTrivial{CircularActionSpace})
    r = d[].r_max * rand(rng) 
    θ = 360.0 * rand(rng) 
    Vec2(r, θ)
end

#state is 2D: x, y position
#action is 2D delta added to s: radius, angle (degrees, right zero, counterclock positive, +-180.0)
@with_kw struct CWorld <: MDP{Vec2, Vec2}
    xlim::Tuple{Float64, Float64}                   = (0.0, 10.0) 
    ylim::Tuple{Float64, Float64}                   = (0.0, 10.0)
    terminal_state::Vec2                            = Vec2(-1.0,-1.0)  #must be outside of xlim and ylim
    reward_regions::Vector{CircularRegion}          = default_regions
    rewards::Vector{Float64}                        = default_rewards
    terminal::Vector{CircularRegion}                = default_regions
    stdev::Tuple{Float64,Float64}                   = (0.0, 0.0)
    actions::CircularActionSpace                    = CircularActionSpace()
    discount::Float64                               = 0.95
end

struct CWorldStateSpace 
    xlim::Tuple{Float64, Float64}
    ylim::Tuple{Float64, Float64}
end
POMDPs.states(w::CWorld) = CWorldStateSpace(w.xlim, w.ylim)
POMDPs.actions(w::CWorld) = w.actions
POMDPs.discount(w::CWorld) = w.discount

function inbounds(xy::Vec2, xlim::Tuple{Float64,Float64}, ylim::Tuple{Float64,Float64})
    (xlim[1] <= xy[1] <= xlim[2]) && (ylim[1] <= xy[2] <= ylim[2])
end
function Base.in(s::AbstractVector, terminal::Vector{CircularRegion})
    for r in terminal
        if s in r
            return true 
        end
    end
    false
end

function POMDPs.transition(w::CWorld, s::AbstractVector, a::AbstractVector)
    ImplicitDistribution(w, s, a) do w, s, a, rng
        #terminal states
        (s in w.terminal) && return w.terminal_state

        #r,θ = a
        #delta = r .* Vec2(cosd(θ), sind(θ))
        
        #a = [dx,dy]
        delta = Vec2(a[1],a[2])
        sp = s .+ delta .+ w.stdev.*randn(rng, Vec2)

        # also terminate if out-of-bounds 
        if !inbounds(sp, w.xlim, w.ylim) 
            sp = w.terminal_state 
        end

        sp 
    end
end

function POMDPs.reward(w::CWorld, s::AbstractVector, a::AbstractVector) # XXX inefficient
    rew = 0.0
    for (i,r) in enumerate(w.reward_regions)
        if s in r
            rew += w.rewards[i]
        end
    end
    return rew
end

function POMDPs.isterminal(w::CWorld, s::Vec2) 
    s == w.terminal_state
end

struct Vec2Distribution
    xlim::Tuple{Float64,Float64}
    ylim::Tuple{Float64,Float64}
    d::Product #for support functions

    function Vec2Distribution(xlim::Tuple{Float64,Float64}, ylim::Tuple{Float64,Float64})
        d = Product([Distributions.Uniform(xlim[1], xlim[2]), Distributions.Uniform(ylim[1], ylim[2])])
        new(xlim, ylim, d)
    end
end

function Base.rand(rng::Random.AbstractRNG, v::Vec2Distribution)
    x = v.xlim[1] + (v.xlim[2]-v.xlim[1])*rand(rng) #sampling from Product allocates a Vector, avoid by sampling manually
    y = v.ylim[1] + (v.ylim[2]-v.ylim[1])*rand(rng)
    return Vec2(x,y)
end

Distributions.pdf(v::Vec2Distribution, x) = pdf(v.d, x)
Distributions.support(v::Vec2Distribution) = support(v.d)
StatsBase.mode(v::Vec2Distribution) = mode(v.d)
Statistics.mean(v::Vec2Distribution) = mean(v.d)

function POMDPs.initialstate(w::CWorld)
    return Vec2Distribution(w.xlim, w.ylim)
end

include("solver.jl")
include("visualization.jl")

end # module
