"""
    nOctaves, totalWavelets, sRanges, sWidth = getNWavelets(n1,c)

utility for understanding the spacing of the wavelets. `sRanges` is a list of
the s values used in each octave. sWidth is a list of the corresponding
variance adjustments
"""
function getNWavelets(n1,c)
    nOctaves = getNOctaves(n1,c)
    n = setn(n1,c)
    isAve = (c.averagingLength > 0 && !(typeof(c.averagingType) <: NoAve)) ? 1 : 0
    if round(nOctaves) < 0
        totalWavelets = 0
        sRanges = Array{Array{Float64,1},1}(undef,0)
        sWidth = [1.0]
        return nOctaves, totalWavelets, sRanges, sWidth
    end
    sRange = 2 .^ (polySpacing(nOctaves, c))
    totalWavelets = round(Int, length(sRange) + isAve)
    sWidth = varianceAdjust(c,totalWavelets)
    return nOctaves, totalWavelets, sRange, sWidth
end





function getNOctaves(n1,c::CFW{W,T, M, N}) where {W, T, N, M}
    nOctaves = log2(max(n1*2π, 2)) - c.averagingLength - 1
end

function getNOctaves(n1,c::CFW{W,T, Morlet, N}) where {W, T, N}
    # choose the number of octaves so the last mean, which is at s*σ[1]
    # is 3 standard devations away from the end
    nOctaves = log2(max(n1*2π/(c.σ[1]+3), 2)) - c.averagingLength
end

function getNOctaves(n1,c::CFW{W,T, <:Paul, N}) where {W, T, N}
    println(getStd(c))
    nOctaves = log2(max(n1*2π/getStd(c), 2)) - c.averagingLength - 1
end

function getNOctaves(n1,c::CFW{W,T, <:Dog, N}) where {W, T, N}
    # choose the number of octaves so the last mean is 2.5 standard 
    # deviations from the end
    nOctaves = log2(max(n1*2π/2.5/getStd(c), 2)) - c.averagingLength - 1
end

function getNOctaves(n1,c::CFW{W,T, <:ContOrtho, N}) where {W, T, N}
    # choose the number of octaves so the smallest support is still 16
    nOctaves = log2(n1) - 4 - c.averagingLength + 1
end

function varianceAdjust(this::CFW{W,T, M, N}, totalWavelets) where {W,T,N, M}
    # increases the width of the wavelets by σ[i] = (1+a(total-i)ᴾ)σₛ
    # which is a polynomial of order p going from 1 at the highest frequency to 
    # sqrt(p) at the lowest
    p = this.decreasing
    a = (p^.8-1)/(totalWavelets-1)^p
    1 .+a .*(totalWavelets .- (1:totalWavelets)).^p
end


function polySpacing(nOct, c)
    a =c.averagingLength; O = nOct
    p = c.decreasing
    Q = c.scalingFactor
    # x is the index, y is the scale
    # y= aveLength + b*x^(1/p), solve for a and b with 
    # (x₀,y₀)=(0,aveLength-1)
    # dy/dx = 1/s, so the Quality factor gives the slope at the last frequency
    b = (p/Q)^(1/p) * (O+a)^((p-1)/p)
    # the point x so that the second condition holds
    lastWavelet = Q * (O+a)/p
    # the point so that the first wavelet is at a
    firstWavelet = (a/b)^p
    # step size so that there are actually Q wavelets in the last octave
    startOfLastOctave = ((nOct+a-1)/b)^p
    stepSize = (lastWavelet - startOfLastOctave)/Q
    samplePoints = range(firstWavelet, stop=lastWavelet, 
                         step = stepSize)#, length = round(Int, O * Q^(1/p)))
    return b .* (samplePoints).^(1/p)
end

function getNScales(n1, c)
    nOctaves = log2(max(n1, 2)) - c.averagingLength
    nWaveletsInOctave = reverse([max(1, round(Int,
                                              c.scalingFactor/x^(c.decreasing)))
                                 for x = 1:round(Int, nOctaves)])
    nScales = max(sum(nWaveletsInOctave), 0)
end

"""

adjust the length of the signal based on the boundary conditions
"""
function setn(n1, c)
    if boundaryType(c)() == WT.padded
        base2 = round(Int,log(n1 + 1)/log(2));   # power of 2 nearest to n1
        n = 2^(base2+1)
        n = n>>1 + 1
    elseif boundaryType(c)() == WT.DEFAULT_BOUNDARY
        # n1+1 rather than just n1 because this is going to be used in an rfft
        # for real data
        n = n1 + 1
    else
        n= n1>>1 + 1
    end
    return n
end






# computing averaging function utils

# this makes sure the averaging function is real and positive
adjust(c::CFW) = 1
adjust(c::CFW{W, T, <:Dog}) where {W,T} = 1/(im)^(c.α) 

function locationShift(c::CFW{W, T, <:Morlet, N}, s, ω, sWidth) where {W,T,N}
        s0 = 3*c.σ[1]/4 *s*sWidth
        ω_shift = ω .+ c.σ[1] * s0
    return (s0, ω_shift)
end

function locationShift(c::CFW{W, T, <:Dog, N}, s, ω, sWidth) where {W,T,N}    
    μNoS = getMean(c)
    μLast = μNoS * (2s) 
    #println(c.α, "  ", μLast, "  ", μAveSis1, "  ", varSis1)
    #println("(varSis1 - μAveSis1^2)  $(varSis1) - $(μAveSis1^2))")
    s0 = μLast / 2 / getStd(c) 
    μ = μNoS * s0 
    println("s0 = $(s0), s = $(s), sWidth = $(sWidth) μ = $(μ)")
    ω_shift = ω .+ μ
    return (s0, ω_shift)
end

"""
get the mean of the mother wavelet where s=1
"""
function getMean(c::CFW{W, T, <:Dog}) where {W,T}
    Gm1 = gamma((c.α+1)/2)
    Gm2 = gamma((c.α+2)/2)
    Gm2 / Gm1 * sqrt(2)  
end
getMean(c::CFW{W,T,<:Paul}) where {W,T} = c.α+1

"""
get the standard deviation of the mother wavelet where s=1
"""
function getStd(c::CFW{W, T, <:Dog}) where {W,T}
    sqrt(c.α + 1 - getMean(c)^2)
end
getStd(c::CFW{W, T, <:Paul}) where {W, T} = sqrt((c.α+2)*(c.α+1))

function locationShift(c::CFW{W, T, <:Paul, N}, s, ω, sWidth) where {W,T,N}
    s0 = s*sqrt(c.α+1)
    ω_shift = ω .+ (c.α .+ 1) * s0
    return (s0, ω_shift)
end


function getUpperBound(c::CFW{W, T, <:Morlet, N}, s) where {W,T,N}
    return c.σ[1] * s
end

function getUpperBound(c::CFW{W, T, <:Dog, N}, s) where {W,T,N}
    return sqrt(2)* s * gamma((c.α+2)/2) / gamma((c.α+1)/2)
end

function getUpperBound(c::CFW{W, T, <:Paul, N}, s) where {W,T,N}
    return (c.α + 1) * s
end
