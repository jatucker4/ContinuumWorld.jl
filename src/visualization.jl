mutable struct CWorldVis
    w::CWorld
    s::Union{Vec2, Nothing}
    f::Union{Function, Nothing}
    g::Union{AbstractGrid, Nothing}
    fq::Union{Function, Nothing}
    title::Union{String, Nothing}
end

function CWorldVis(w::CWorld;
                   s=nothing,
                   f=nothing,
                   g=nothing,
                   fq=nothing,
                   title=nothing)
    return CWorldVis(w, s, f, g, fq, title)
end

@recipe function f(v::CWorldVis)
    xlims --> v.w.xlim
    ylims --> v.w.ylim
    aspect_ratio --> 1
    title --> something(v.title, "Continuum World")
    if v.f !== nothing
        @series begin
            f = v.f
            width = v.w.xlim[2]-v.w.xlim[1]
            height = v.w.ylim[2]-v.w.ylim[1]
            n = 200 # number of pixels
            nx = round(Int, sqrt(n^2*width/height))
            ny = round(Int, sqrt(n^2*height/width))
            xs = range(v.w.xlim[1], stop=v.w.xlim[2], length=nx)
            ys = range(v.w.ylim[1], stop=v.w.ylim[2], length=ny)
            zg = Array{Float64}(undef, nx, ny)
            for i in 1:nx
                for j in 1:ny
                    zg[j,i] = f(Vec2(xs[i], ys[j]))
                end
            end
            seriescolor --> cgrad([:red, :white, :green])
            seriestype := :heatmap
            xs, ys, zg
        end
    end
    if v.g !== nothing
        @series begin
            g = v.g
            xs = collect(ind2x(g, i)[1] for i in 1:length(g))
            ys = collect(ind2x(g, i)[2] for i in 1:length(g))
            label --> "Grid"
            marker --> :+
            markercolor --> :blue
            seriestype := :scatter
            xs, ys
        end
    end
    if v.fq !== nothing
        @series begin
            f = v.fq
            width = v.w.xlim[2]-v.w.xlim[1]
            height = v.w.ylim[2]-v.w.ylim[1]
            n = 25 # number of pixels/steps
            nx = round(Int, sqrt(n^2*width/height))
            ny = round(Int, sqrt(n^2*height/width))
            xs, ys = meshgrid(range(v.w.xlim[1], stop=v.w.xlim[2], length=nx), range(v.w.ylim[1], stop=v.w.ylim[2], length=ny))
            xs, ys = vec(xs), vec(ys)
            us, vs = similar(xs), similar(ys)
            for i = 1:length(xs)
                us[i], vs[i] = f(Vec2(xs[i], ys[i]))
            end
            seriestype := :quiver
            quiver := (us,vs)
            xs, ys
        end
    end
end

meshgrid(rgx, rgy) = ([x for x in rgx, y in rgy], [y for x in rgx, y in rgy])

Base.show(io::IO, m::MIME, v::CWorldVis) = show(io, m, plot(v)) 
Base.show(io::IO, m::MIME"text/plain", v::CWorldVis) = println(io, v)

