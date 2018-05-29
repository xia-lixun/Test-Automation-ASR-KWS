module LibAudio



using Polynomials
using Plots
using WAV
using SHA


                                                ##########################################
                                                ##                                      ##
                                                ##      Chapter I. Data Processing      ##
                                                ##                                      ##
                                                ##########################################

function bilinear(b, a, fs)
    # bilinear transformation of transfer function from s-domain to z-domain
    # via s = 2/T (z-1)/(z+1)
    # let ζ = z^(-1) we have s = -2/T (ζ-1)/(ζ+1)
    # 
    #          b_m s^m + b_(m-1) s^(m-1) + ... + b_1 s + b_0
    # H(s) = -------------------------------------------------
    #          a_n s^n + a_(n-1) s^(n-1) + ... + a_1 s + a_0
    #
    # So 
    #
    #          b_m (-2/T)^m (ζ-1)^m / (ζ+1)^m  + ... + b_1 (-2/T) (ζ-1)/(ζ+1) + b_0 
    # H(ζ) = -------------------------------------------------------------------------
    #          a_n (-2/T)^n (ζ-1)^n / (ζ+1)^n  + ... + a_1 (-2/T) (ζ-1)/(ζ+1) + a_0
    #
    # Since we assume H(s) is rational, so n ≥ m, multiply num/den with (ζ+1)^n ans we have
    #
    #          b_m (-2/T)^m (ζ-1)^m (ζ+1)^(n-m)  + b_(m-1) (-2/T)^(m-1) (ζ-1)^(m-1) (ζ+1)^(n-m+1) + ... + b_1 (-2/T) (ζ-1)(ζ+1)^(n-1) + b_0 (ζ+1)^n
    # H(ζ) = ---------------------------------------------------------------------------------------------------------------------------------------
    #          a_n (-2/T)^n (ζ-1)^n  + a_(n-1) (-2/T)^(n-1) (ζ-1)^(n-1) (ζ+1) ... + a_1 (-2/T) (ζ-1)(ζ+1)^(n-1) + a_0 (ζ+1)^n
    #
    #
    #         B[0] + B[1]ζ + B[2]ζ^2 + ... B[m]ζ^m
    # H(ζ) = ---------------------------------------
    #         A[0] + A[1]ζ + A[2]ζ^2 + ... A[n]ζ^n

    m = size(b,1)-1
    n = size(a,1)-1
    p = Polynomials.Poly{BigFloat}(BigFloat(0))
    q = Polynomials.Poly{BigFloat}(BigFloat(0))

    br = convert(Array{BigFloat,1}, flipdim(b,1))
    ar = convert(Array{BigFloat,1}, flipdim(a,1))

    for i = m:-1:0
        p = p + (br[i+1] * (BigFloat(-2fs)^i) * poly(convert(Array{BigFloat,1},ones(i))) * poly(convert(Array{BigFloat,1},-ones(n-i))))
    end
    for i = n:-1:0
        q = q + (ar[i+1] * (BigFloat(-2fs)^i) * poly(convert(Array{BigFloat,1},ones(i))) * poly(convert(Array{BigFloat,1},-ones(n-i))))        
    end
    
    num = zeros(Float64,n+1)
    den = zeros(Float64,n+1)
    for i = 0:n
        num[i+1] = Float64(p[i])        
    end
    for i = 0:n
        den[i+1] = Float64(q[i])        
    end
    g = den[1]
    (num/g, den/g)
end



function convolve(a::Array{T,1}, b::Array{T,1}) where T <: Real
    m = size(a,1)
    n = size(b,1)
    l = m+n-1
    y = Array{T,1}(l)

    for i = 0:l-1
        i1 = i
        tmp = zero(T)
        for j = 0:n-1
            ((i1>=0) & (i1<m)) && (tmp += a[i1+1]*b[j+1])
            i1 -= 1
        end
        y[i+1] = tmp
    end
    y
end




function weighting_a(fs)
    # example: create a-weighting filter in z-domain

    f1 = 20.598997
    f2 = 107.65265
    f3 = 737.86223
    f4 = 12194.217
    A1000 = 1.9997

    p = [ ((2π*f4)^2) * (10^(A1000/20)), 0, 0, 0, 0 ]
    q = convolve(convert(Array{BigFloat,1}, [1, 4π*f4, (2π*f4)^2]), convert(Array{BigFloat,1}, [1, 4π*f1, (2π*f1)^2]))
    q = convolve(convolve(q, convert(Array{BigFloat,1}, [1, 2π*f3])),convert(Array{BigFloat,1}, [1, 2π*f2]))
    
    #(p, convert(Array{Float64,1},q))
    num_z, den_z = bilinear(p, q, fs)
end



AWEIGHT_48kHz_BA = [0.234301792299513 -0.468603584599025 -0.234301792299515 0.937207169198055 -0.234301792299515 -0.468603584599025 0.234301792299512;
                    1.000000000000000 -4.113043408775872 6.553121752655049 -4.990849294163383 1.785737302937575 -0.246190595319488 0.011224250033231]'

AWEIGHT_16kHz_BA = [0.531489829823557 -1.062979659647115 -0.531489829823556 2.125959319294230 -0.531489829823558 -1.062979659647116 0.531489829823559;
                    1.000000000000000 -2.867832572992163  2.221144410202311 0.455268334788664 -0.983386863616284 0.055929941424134 0.118878103828561]'

                    
    

function tf_filter(B, A, x)  # -> Vector{Float64} or Matrix{Float64}
    # transfer function filter in z-domain
    #
    #   y(n)        b(1) + b(2)Z^(-1) + ... + b(M+1)Z^(-M)
    # --------- = ------------------------------------------
    #   x(n)        a(1) + a(2)Z^(-1) + ... + a(N+1)Z^(-N)
    #
    #   y(n)a(1) = x(n)b(1) + b(2)x(n-1) + ... + b(M+1)x(n-M)
    #              - a(2)y(n-1) - a(3)y(n-2) - ... - a(N+1)y(n-N)
    #
    if A[1] != 1.0
        B = B / A[1]
        A = A / A[1]
    end
    M = length(B)-1
    N = length(A)-1
    Br = flipdim(B,1)
    As = A[2:end]
    L = size(x,2)

    y = zeros(size(x))
    x = [zeros(M,L); x]
    s = zeros(N,L)

    for j = 1:L
        for i = M+1:size(x,1)
            y[i-M,j] = dot(Br, x[i-M:i,j]) - dot(As, s[:,j])
            s[2:end,j] = s[1:end-1,j]
            s[1,j] = y[i-M,j] 
        end
    end
    y
end






function hamming(T, n; flag="")

    lowercase(flag) == "periodic" && (n += 1)
    ω = Array{T,1}(n)
    α = T(0.54)
    β = 1 - α
    for i = 0:n-1
        ω[i+1] = α - β * T(cos(2π * i / (n-1)))
    end
    lowercase(flag) == "periodic" && (return ω[1:end-1])
    ω
end


function hann(T, n; flag="")

    lowercase(flag) == "periodic" && (n += 1)
    ω = Array{T,1}(n)
    α = T(0.5)
    β = 1 - α
    for i = 0:n-1
        ω[i+1] = α - β * T(cos(2π * i / (n-1)))
    end
    lowercase(flag) == "periodic" && (return ω[1:end-1])
    ω
end


sqrthann(T,n) = sqrt.(hann(T,n,flag="periodic"))





struct Frame1
    # note Frame1(8000, 1024.0, 256.0, 0) is perfectly legal as new() will convert every parameter to T
    # but Frame1(8000, 1024.0, 256.3, 0) would not work as it raises InexactError()
    samplerate::Int64
    block::Int64
    update::Int64
    overlap::Int64
    Frame1(r, x, y, z) = x < y ? error("block size must ≥ update size!") : new(r, x, y, x-y)
    # we define an outer constructor as the inner constructor infers the overlap parameter
    # again the block and update accepts Integers as well as AbstractFloat w/o fractions
    #
    # example type outer constructors: 
    # FrameInSample(fs, block, update) = Frame1(fs, block, update, 0)
    # FrameInSecond(fs, block, update) = Frame1(fs, floor(block * fs), floor(update * fs), 0)
    # Frame1(0, 1024, 256, 0)
end



function tile(x::AbstractArray{T,1}, p::Frame1; 
    zero_prepend=false, 
    zero_append=false) where {T <: AbstractFloat}

    # extend array x with prefix/appending zeros for frame slicing
    # this is an utility function used by getframes(),spectrogram()...
    # new data are allocated, so origianl x is untouched.
    # zero_prepend = true: the first frame will have zeros of length nfft-nhop
    # zero_append = true: the last frame will partially contain data of original x    

    zero_prepend && (x = [zeros(T, p.overlap); x])                                  # zero padding to the front for defined init state
    length(x) < p.block && error("signal length must be at least one block!")       # detect if length of x is less than block size
    n = div(size(x,1) - p.block, p.update) + 1                                      # total number of frames to be processed
    
    if zero_append
        m = rem(size(x,1) - p.block, p.update)
        if m != 0
            x = [x; zeros(T, p.update-m)]
            n += 1
        end
    end
    (x,n)
end




function getframes(x::AbstractArray{T,1}, p::Frame1; 
    window=ones, 
    zero_prepend=false, 
    zero_append=false) where {T <: AbstractFloat}
    
    # function    : getframes
    # x           : array of AbstractFloat {Float64, Float32, Float16, BigFloat}
    # p           : frame size immutable struct
    # zero_prepend   : simulate the case when block buffer is init to zero and the first update comes in
    # zero_append : simulate the case when remaining samples of x doesn't make up an update length
    # 
    # example:
    # x = collect(1.0:100.0)
    # p = Frame1(8000, 17, 7.0, 0)
    # y,h = getframes(x, p) where h is the unfold length in time domain    

    x, n = tile(x, p, zero_prepend = zero_prepend, zero_append = zero_append)
    
    ω = window(T, p.block)
    y = zeros(T, p.block, n)
    
    for i = 0:n-1
        y[:,i+1] = ω .* view(x, i*p.update+1:i*p.update+p.block)
    end
    # n*p.update is the total hopping size, +(p.block-p.update) for total length
    (y,n*p.update+(p.block-p.update))
end


function spectrogram(x::AbstractArray{T,1}, p::Frame1; 
    nfft = p.block, 
    window=ones, 
    zero_prepend=false, 
    zero_append=false) where {T <: AbstractFloat}

    # example:
    # x = collect(1.0:100.0)
    # p = Frame1(8000, 17, 7.0, 0)
    # y,h = spectrogram(x, p, window=hamming, zero_prepend=true, zero_append=true) 
    # where h is the unfold length in time domain    

    nfft < p.block && error("nfft length must be greater than or equal to block/frame length")
    x, n = tile(x, p, zero_prepend = zero_prepend, zero_append = zero_append)
    m = div(nfft,2)+1

    ω = window(T, nfft)
    P = plan_rfft(ω)
    𝕏 = zeros(Complex{T}, m, n)

    if nfft == p.block
        for i = 0:n-1
            𝕏[:,i+1] = P * (ω .* view(x, i*p.update+1:i*p.update+p.block))
        end
    else
        for i = 0:n-1
            𝕏[:,i+1] = P * ( ω .* [view(x, i*p.update+1:i*p.update+p.block); zeros(T,nfft-p.block)] )
        end
    end
    (𝕏,n*p.update+(p.block-p.update))
end




# v: indicates vector <: AbstractFloat
energy(v) = x.^2
intensity(v) = abs.(v)
zero_crossing_rate(v) = floor.((abs.(diff(sign.(v)))) ./ 2)


function short_term(f, x::AbstractArray{T,1}, p::Frame1; 
    zero_prepend=false, 
    zero_append=false) where {T <: AbstractFloat}

    frames, lu = getframes(x, p, zero_prepend=zero_prepend, zero_append=zero_append)
    n = size(frames,2)
    ste = zeros(T, n)
    for i = 1:n
        ste[i] = sum_kbn(f(view(frames,:,i))) 
    end
    ste
end


pp_norm(v) = (v - minimum(v)) ./ (maximum(v) - minimum(v))
stand(v) = (v - mean(v)) ./ std(v)
hz_to_mel(hz) = 2595 * log10.(1 + hz * 1.0 / 700)
mel_to_hz(mel) = 700 * (10 .^ (mel * 1.0 / 2595) - 1)



function power_spectrum(x::AbstractArray{T,1}, p::Frame1; 
    nfft = p.block, 
    window=ones, 
    zero_prepend=false, 
    zero_append=false) where {T <: AbstractFloat}

    # calculate power spectrum of 1-D array on a frame basis
    # note that T=Float16 may not be well supported by FFTW backend

    nfft < p.block && error("nfft length must be greater than or equal to block/frame length")
    x, n = tile(x, p, zero_prepend = zero_prepend, zero_append = zero_append)

    ω = window(T, nfft)
    f = plan_rfft(ω)
    m = div(nfft,2)+1
    ℙ = zeros(T, m, n)
    ρ = T(1 / nfft)

    if nfft == p.block
        for i = 0:n-1
            ξ = f * (ω .* view(x, i*p.update+1:i*p.update+p.block)) # typeof(ξ) == Array{Complex{T},1} 
            ℙ[:,i+1] = ρ * ((abs.(ξ)).^2)
        end
    else
        for i = 0:n-1
            ξ = f * (ω .* [view(x, i*p.update+1:i*p.update+p.block); zeros(T,nfft-p.block)])
            ℙ[:,i+1] = ρ * ((abs.(ξ)).^2)
        end
    end
    (ℙ,n*p.update+(p.block-p.update))
end




function mel_filterbanks(T, rate::U, nfft::U; filt_num=26, fl=0, fh=div(rate,2)) where {U <: Integer}
    # calculate filter banks in Mel domain

    fh > div(rate,2) && error("high frequency must be less than or equal to nyquist frequency!")
    
    ml = hz_to_mel(fl)
    mh = hz_to_mel(fh)
    mel_points = linspace(ml, mh, filt_num+2)
    hz_points = mel_to_hz(mel_points)

    # round frequencies to nearest fft bins
    𝕓 = U.(floor.((hz_points/rate) * (nfft+1)))
    #print(𝕓)

    # first filterbank will start at the first point, reach its peak at the second point
    # then return to zero at the 3rd point. The second filterbank will start at the 2nd
    # point, reach its max at the 3rd, then be zero at the 4th etc.
    𝔽 = zeros(T, filt_num, div(nfft,2)+1)

    for i = 1:filt_num
        for j = 𝕓[i]:𝕓[i+1]
            𝔽[i,j+1] = T((j - 𝕓[i]) / (𝕓[i+1] - 𝕓[i]))
        end
        for j = 𝕓[i+1]:𝕓[i+2]
            𝔽[i,j+1] = T((𝕓[i+2] - j) / (𝕓[i+2] - 𝕓[i+1]))
        end
    end
    𝔽m = 𝔽[vec(.!(isnan.(sum(𝔽,2)))),:]
    return 𝔽m
end


function filter_bank_energy(x::AbstractArray{T,1}, p::Frame1; 
    nfft = p.block, 
    window=ones, 
    zero_prepend=false, 
    zero_append=false, 
    filt_num=26, 
    fl=0, 
    fh=div(p.rate,2), 
    use_log=false) where {T <: AbstractFloat}

    ℙ,h = power_spectrum(x, p, nfft=nfft, window=window, zero_prepend=zero_prepend, zero_append=zero_append)
    𝔽 = mel_filterbanks(T, p.rate, nfft, filt_num=filt_num, fl=fl, fh=fh)
    ℙ = 𝔽 * ℙ
    use_log && (log.(ℙ+eps(T)))
    ℙ
end




function local_maxima(x::AbstractArray{T,1}) where {T <: Real}
    # T could be AbstractFloat for best performance
    # but defined as Real for completeness.    
    gtl = [false; x[2:end] .> x[1:end-1]]
    gtu = [x[1:end-1] .>= x[2:end]; false]
    imax = gtl .& gtu
    # return as BitArray mask of true or false
end






# Get frame context from spectrogram x with radius r
# 1. x must be col major, i.e. each col is a spectrum frame for example, 257 x L matrix
# 2. y will be (257*(neighbour*2+1+nat)) x L
# 3. todo: remove allocations for better performance
symm(i,r) = i-r:i+r


function sliding_aperture(x::Array{T,2}, r::Int64, t::Int64) where T <: AbstractFloat
    # r: radius
    # t: noise estimation frames
    m, n = size(x)
    head = repmat(x[:,1], 1, r)
    tail = repmat(x[:,end], 1, r)
    x = hcat(head, x, tail)

    if t > 0
        y = zeros(T, (2r+2)*m, n)
        for i = 1:n
            focus = view(x,:,symm(r+i,r))
            nat = mean(view(focus,:,1:t), 2)
            y[:,i] = vec(hcat(focus,nat))
        end
        return y
    else
        y = zeros(T, (2r+1)*m, n)
        for i = 1:n
            y[:,i] = vec(view(x,:,symm(r+i,r)))
        end
        return y
    end
end



sigmoid(x::T) where T <: AbstractFloat = one(T) / (one(T) + exp(-x))
sigmoidinv(x::T) where T <: AbstractFloat = log(x / (one(T)-x))  # x ∈ (0, 1)
rms(x,dim) = sqrt.(sum((x.-mean(x,dim)).^2,dim)/size(x,dim))
rms(x) = sqrt(sum((x-mean(x)).^2)/length(x))













function stft2(x::AbstractArray{T,1}, sz::Int64, hp::Int64, wn) where T <: AbstractFloat
    # filter bank with square-root hann window for hard/soft masking
    # short-time fourier transform
    # input:
    #     x    input time series
    #     sz   size of the fft
    #     hp   hop size in samples
    #     wn   window to use
    #     sr   sample rate
    # output:
    #     𝕏    complex STFT output (DC to Nyquist)
    #     h    unpacked sample length of the signal in time domain
    p = Frame1(0, sz, hp, 0)
    𝕏,h = spectrogram(x, p, window=wn, zero_prepend=true)
    𝕏,h
end



function stft2(𝕏::AbstractArray{Complex{T},2}, h::Int64, sz::Int64, hp::Int64, winfn) where T <: AbstractFloat
    # input:
    #    𝕏   complex spectrogram (DC to Nyquist)
    #    h   unpacked sample length of the signal in time domain
    # output time series reconstructed
    𝕎 = winfn(T,sz) ./ (T(sz/hp))
    𝕏 = vcat(𝕏, conj!(𝕏[end-1:-1:2,:]))
    𝕏 = real(ifft(𝕏,1)) .* 𝕎

    y = zeros(T,h)
    n = size(𝕏,2)
    for k = 0:n-1
        y[k*hp+1 : k*hp+sz] .+= 𝕏[:,k+1]
    end
    y
end



function idealsoftmask_aka_oracle(x1,x2,fs)
    # Demo function    
    # x1,fs = WAV.wavread("D:\\Git\\dnn\\stft_example\\sound001.wav")
    # x2,fs = WAV.wavread("D:\\Git\\dnn\\stft_example\\sound002.wav")

    x1 = view(x1,:,1)
    x2 = view(x2,:,1)

    M = min(length(x1), length(x2))
    x1 = view(x1,1:M)
    x2 = view(x2,1:M)
    x = x1 + x2

    nfft = 1024
    hp = div(nfft,4)

    pmix, h0 = stft2(x, nfft, hp, sqrthann)
    px1, h1 = stft2(x1, nfft, hp, sqrthann)
    px2, h2 = stft2(x2, nfft, hp, sqrthann)

    bm = abs.(px1) ./ (abs.(px1) + abs.(px2))
    py1 = bm .* pmix
    py2 = (1-bm) .* pmix

    scale = 2
    y = stft2(pmix, h0, nfft, hp, sqrthann) * scale
    y1 = stft2(py1, h0, nfft, hp, sqrthann) * scale
    y2 = stft2(py2, h0, nfft, hp, sqrthann) * scale

    y = view(y,1:M)
    y1 = view(y1,1:M)
    y2 = view(y2,1:M)

    delta = 10log10(sum(abs.(x-y).^2)/sum(x.^2))
    bm,y1,y2
    #histogram(bm[100,:])
end
    



function noise_estimate_invoke(p::Frame1, tau_be, c_inc_db, c_dec_db, noise_init_db, min_noise_db, 𝕏::AbstractArray{Complex{T},2}) where {T <: AbstractFloat}

    fs::Int64 = p.samplerate
    h::Int64 = p.update
    m::Int64 = div(p.block,2)+1
    n = size(𝕏,2)

    alpha_be = T(exp((-5h)/(tau_be*fs))) 
    c_inc = T(10.0^(h*(c_inc_db/20)/fs))
    c_dec = T(10.0^-(h*(c_dec_db/20)/fs))
    band_energy = zeros(T,m,n+1)
    band_noise = T(10.0^(noise_init_db/20))*ones(T,m,n+1)
    min_noise = T(10.0^(min_noise_db/20))

    for i = 1:n
        band_energy[:,i+1] = alpha_be * view(band_energy,:,i) + (one(T)-alpha_be) * abs.(view(𝕏,:,i))
        for k = 1:m
            band_energy[k,i+1] > band_noise[k,i] && (band_noise[k,i+1] = c_inc * band_noise[k,i])
            band_energy[k,i+1] <= band_noise[k,i] && (band_noise[k,i+1] = c_dec * band_noise[k,i])
            band_energy[k,i+1] < min_noise && (band_energy[k,i+1] = min_noise)
        end
    end
    band_noise = band_noise[:,2:end]
end



function signal_to_distortion_ratio(x::AbstractArray{T,1}, t::AbstractArray{T,1}) where T <: AbstractFloat

    lbs, pk, pkpf, y = extract_symbol_and_merge(x, t, 1)
    10log10.(sum(t.^2, 1) ./ sum((t-y).^2, 1))
end









function extract_symbol_and_merge(x::AbstractArray{T,1}, s::AbstractArray{T,1}, rep::Int;
    vision=false, 
    verbose=false, 
    dither=-120) where {T <: AbstractFloat}
    

    x = x + (rand(T,size(x)) - T(0.5)) * T(10^(dither/20))

    n = length(x) 
    m = length(s)
    y = zeros(T, rep * m)
    peaks = zeros(Int64, rep)
    lbs = zeros(Int64, rep)
    peakspf2 = zeros(rep)


    ℝ = xcorr(s, x)
    verbose && info("peak value: $(maximum(ℝ))")                              
    vision && (box = plot(x, size=(800,200)))
    
    𝓡 = sort(ℝ[local_maxima(ℝ)], rev = true)
    isempty(𝓡) && ( return (y, diff(peaks)) )


    # find the anchor point
    ploc = find(z->z==𝓡[1],ℝ)[1]
    peaks[1] = ploc
    lb = n - ploc + 1
    rb = min(lb + m - 1, length(x))
    y[1:1+rb-lb] = x[lb:rb]
    ip = 1
    lbs[ip] = lb
    1+rb-lb < m && warn("incomplete segment extracted!")

    pf2a, pf2b = parabolicfit2(ℝ[ploc-1:ploc+1])
    peakspf2[ip] = (ploc-1) + (-0.5pf2b/pf2a)
    verbose && info("peak anchor-[1] in correlation: $ploc, $(peakspf2[ip])")

    if vision
        box_hi = maximum(x[lb:rb])
        box_lo = minimum(x[lb:rb])
        plotly()
        plot!(box,[lb,rb],[box_hi, box_hi], color = "red", lw=1)
        plot!(box,[lb,rb],[box_lo, box_lo], color = "red", lw=1)
        plot!(box,[lb,lb],[box_hi, box_lo], color = "red", lw=1)
        plot!(box,[rb,rb],[box_hi, box_lo], color = "red", lw=1)
    end

    if rep > 1
        for i = 2:length(𝓡)
            ploc = find(z->z==𝓡[i],ℝ)[1]
            if sum(abs.(peaks[1:ip] - ploc) .> m) == ip
                ip += 1
                peaks[ip] = ploc

                pf2a, pf2b = parabolicfit2(ℝ[ploc-1:ploc+1])
                peakspf2[ip] = (ploc-1) + (-0.5pf2b/pf2a)            
                verbose && info("peak anchor-[$ip] in correlation: $ploc, $(peakspf2[ip])")

                lb = n - ploc + 1
                rb = min(lb + m - 1, length(x))
                lbs[ip] = lb
                
                if vision
                    box_hi = maximum(x[lb:rb])
                    box_lo = minimum(x[lb:rb])    
                    plot!(box,[lb,rb],[box_hi, box_hi], color = "red", lw=1)
                    plot!(box,[lb,rb],[box_lo, box_lo], color = "red", lw=1)
                    plot!(box,[lb,lb],[box_hi, box_lo], color = "red", lw=1)
                    plot!(box,[rb,rb],[box_hi, box_lo], color = "red", lw=1)
                end

                y[1+(ip-1)*m : 1+(ip-1)*m+(rb-lb)] = x[lb:rb]
                1+rb-lb < m && warn("incomplete segment extracted!")
                
                if ip == rep
                    break
                end
            end
        end
        peaks = sort(peaks)
        lbs = sort(lbs)
        peakspf2 = sort(peakspf2)
    end
    vision && display(box)
    return (lbs, peaks, peakspf2, y)
end



function parabolicfit2(y::AbstractArray{T,1}) where T <: AbstractFloat

    # % given three points (x, y1) (x+1, y2) and (x+2, y3) there exists 
    # % the only parabolic-2 fit y = ax^2+bx+c with a < 0. 
    # % Therefore a global miximum can be found over the fit.
    # %
    # % To fit all thress points: let (x1 = 0, y1 = 0) then we have
    # % other points (1, y2-y1) and (2, y3 - y1).
    # %       0 = a * 0^2 + b * 0 + c => c = 0    (1)
    # %       y2 - y1 = a + b                     (2)
    # %       y3 - y1 = 4 * a + 2 * b             (3)
    # %
    # %       => a = y3/2 - y2 + y1/2             (4)
    # %       => b = -y3/2 + 2*y2 - 3/2*y1        (5)
    a = 0.5y[3] - y[2] + 0.5y[1]
    b = -0.5y[3] + 2y[2] - 1.5y[1]
    (a,b)
end
# % validation
# % y = [0.5; 1.0; 0.8];
# % [a,b] = parabolic_fit_2(y);
# % figure; plot([0;1;2], y-y(1), '+'); hold on; grid on;
# % m = -0.5*b/a;
# % ym = a * m^2 + b * m;
# % plot(m, ym, 's');
# % x = -1:0.001:5;
# % plot(x,a*x.^2+b*x, '--');




function dB20uPa(calibration::Vector{T}, measurement::Matrix{T}, symbol::Vector{T}, repeat::Int, symbol_l, symbol_h, p::Frame1; 
    fl = 100, 
    fh = 12000, 
    calibrator_reading = 114.0,
    verbose = true) where {T <: AbstractFloat}

    # calculate dbspl of all channels of x
    x = measurement
    s = symbol
    channels = size(x,2)
    dbspl = zeros(eltype(x), channels)
    

    rp = power_spectrum(calibration, p, p.block, window=hann)
    rp = mean(rp, 2)

    fl = floor(Int64, fl/p.rate * p.block)
    fh = floor(Int64, fh/p.rate * p.block)
    offset = 10*log10(sum_kbn(rp[fl:fh]) + eps())

    # to use whole symbol, set symbol_l >= symbol_h
    if symbol_l < symbol_h
        assert(size(s,1) >= floor(Int64, p.rate * symbol_h))
        s = s[1 + floor(Int64, p.rate * symbol_l) : floor(Int64, p.rate * symbol_h)]        
    end

    for c = 1:channels
        lbs, pk, pkpf, xp = extract_symbol_and_merge(x[:,c], s, repeat)
        verbose && info("lb locations: $(lbs./p.rate) seconds, @sample $lbs")
        xp = power_spectrum(xp, p, p.block, window=hann)
        xp = mean(xp, 2)
                
        dbspl[c] = 10*log10(sum_kbn(xp[fl:fh])) + (calibrator_reading - offset)
        verbose && info("channel $c: SPL = $(dbspl[c]) dB")           
    end
    dbspl
end


function dBSPL_single_symbol_multiple_instances(calibration_wavfile, measurement::Matrix{T}, symbol::Vector{T}, repeat::Int, samplerate; 
    symbol_start=0.0,
    symbol_stop=0.0,
    fl = 100, 
    fh = 12000, 
    calibrator_reading = 114.0,
    p = Frame1(samplerate, 16384, div(16384,4), 0),
    weighting = "none") where T <: AbstractFloat


    r, fs = wavread(calibration_wavfile)
    assert(Int64(fs) == p.rate)
    x = measurement
    s = symbol

    if lowercase(weighting) == "a"
        info("A-wighting")
        b,a = weighting_a(p.rate)
        # r = tf_filter(AWEIGHT_48kHz_BA[:,1], AWEIGHT_48kHz_BA[:,2], r)
        # x = tf_filter(AWEIGHT_48kHz_BA[:,1], AWEIGHT_48kHz_BA[:,2], x)
        # s = tf_filter(AWEIGHT_48kHz_BA[:,1], AWEIGHT_48kHz_BA[:,2], s)
        r = tf_filter(b,a,r)
        x = tf_filter(b,a,x)
        s = tf_filter(b,a,s)
    end

    dbspl = dB20uPa(r[:,1], x, s, repeat, symbol_start, symbol_stop, p,
        fl = fl,
        fh = fh,
        calibrator_reading = calibrator_reading)    
end


function dBSPL_multiple_symbols_single_instance(calibration_wavfile, measurement::Matrix{T}, symbol_fn, samplerate; 
    repeat = 1,
    symbol_start=0,
    symbol_stop=0,
    fl = 100, 
    fh = 12000, 
    calibrator_reading = 114.0,
    p = Frame1(samplerate, 16384, div(16384,4), 0),
    weighting = "none") where T <: AbstractFloat
    
    
    # calibration 
    r, fs = wavread(calibration_wavfile)
    assert(Int64(fs) == p.rate)
    x = measurement
    s, fs = symbol_fn()
    assert(Int64(fs) == p.rate)

    
    if lowercase(weighting) == "a"
        info("A-wighting")
        b,a = weighting_a(p.rate)
        # r = tf_filter(AWEIGHT_48kHz_BA[:,1], AWEIGHT_48kHz_BA[:,2], r)
        # x = tf_filter(AWEIGHT_48kHz_BA[:,1], AWEIGHT_48kHz_BA[:,2], x)
        # s = tf_filter(AWEIGHT_48kHz_BA[:,1], AWEIGHT_48kHz_BA[:,2], s)
        r = tf_filter(b,a,r)
        x = tf_filter(b,a,x)
        s = tf_filter(b,a,s)
    end

    
    y = zeros(size(x,2), size(s,2))
    for i = 1:size(s,2)
        dbspl = dB20uPa(r[:,1], x, s[:,i], repeat, symbol_start, symbol_stop, p,
            fl = fl,
            fh = fh,
            calibrator_reading = calibrator_reading)
        y[:,i] = dbspl
    end
    y
end


function symbolgroup()
    
    hz = [71, 90, 112, 141, 179, 224, 280, 355, 450, 560, 710, 900, 1120, 1410, 1790, 2240, 2800, 3550, 4500]
    t = 3
    fs = 48000
      
    m = Int64(floor(t*fs))
    n = length(hz)
    y = ones(m, n)
    for i = 1:n
        y[:,i] = sin.(2*π*hz[i]/fs*(0:m-1))
    end
    (y, fs)    
end













function accusum(x, sigma, err)
    icompensated = x - err
    sumconverge = sigma + icompensated
    err = (sumconverge - sigma) - icompensated
    sigma = sumconverge
    sigma, err
end


function expsinesweep(f_start, f_stop, time, fs)    # -> Matrix{Float64}

    const sps = convert(Int64, round(time * fs))
    mul = (f_stop / f_start) ^ (1 / sps)
    delta = 2pi * f_start / fs
    play = zeros(sps,1)

    #calculate the phase increment gain
    #closed form --- [i.play[pauseSps] .. i.play[pauseSps + chirpSps - 1]]
    
    accuerr = 0.0
	phi = 0.0
	for k = 1:sps
		play[k] = phi
		phi, accuerr = accusum(delta, phi, accuerr)
		delta = delta * mul
    end
    
    #the exp sine sweeping time could be non-integer revolutions of 2 * pi for phase phi.
    #Thus we find the remaining and cut them evenly from each sweeping samples as a constant bias.
	delta = -mod(play[sps], 2pi)
    delta = delta / (sps - 1);
    accuerr = 0.0
	phi = 0.0
	for k = 1:sps
		play[k] = sin(play[k] + phi);
	    phi,accuerr = accusum(delta, phi, accuerr);
    end
    return play
end


function iexpsinesweep(ess::Matrix{Float64}, f_start, f_stop)    # -> Matrix{Float64}

    n = length(ess)
    slope = 20log10(0.5)
    atten = slope * log2(f_stop/f_start) / (n-1)
    gain = 0
    iess = flipdim(ess,1)
    for i = 1:n
        iess[i] *= 10^(gain/20+1)
        gain += atten
    end
    return iess
end




function impresp(ess::Matrix{Float64}, ndecay::Int64, f_start, f_stop, fs, mics::Matrix{Float64})    # -> (Matrix{Float64}, Matrix{Float64}, Matrix{Float64})

    iess = iexpsinesweep(ess, f_start, f_stop)
    m = length(ess)
    period = m+ndecay
    l,nmic = size(mics)
    assert(l == period)

    ffn(x,y) = fft([x;zeros(eltype(x), y-size(x,1), size(x,2))],1)
    iffn(x,y) = ifft([x;zeros(eltype(x), y-size(x,1), size(x,2))],1)

    nfft = nextpow2(m+period-1)
    iessfft = ffn(iess, nfft)
    dirac = real(iffn(ffn(ess, nfft) .* iessfft, nfft))/nfft
    measure = real(iffn(ffn(mics, nfft) .* iessfft, nfft))/nfft


    disoff = (m/fs) / log(f_stop/f_start)
    dist12 = Int64(round(log(2) * disoff * fs))
    #fundamental = zeros(nfft-(m-div(dist12,2)-1), nmic)
    #harmonic = zeros(m-div(dist12,2), nmic)
    fundamental = measure[m-div(dist12,2):end,:]
    harmonic = measure[1:m-div(dist12,2),:]
    
    return (fundamental, harmonic, dirac, measure)
end




function syncsymbol(f0, f1, elapse, fs)  # -> Matrix{Float64}

    # % sync symbol is the guard symbol for asynchronous recording/playback
    # % 'asynchronous' means playback and recording may happen at different 
    # % devices: for example, to measure mix distortion we play stimulus from
    # % fireface and do mic recording at the DUT (with only file IO in most 
    # % cases).
    # %
    # % we apply one guard symbol at both beginning and the end of the
    # % session. visualized as:
    # %
    # % +-------+--------------------+-------+
    # % | guard | actual test signal | guard |
    # % +-------+--------------------+-------+
    # %
    # % NOTE:
    # % The guard symbol shall contain not only the chirp but also a
    # % sufficiently long pre and post silence. post silence is for the chirp
    # % energy to decay, not to disturb the measurement; pre silence is to
    # % prepare enough time for DUT audio framework context switching 
    # % (products may have buggy glitches when change from system sound to
    # % music). Our chirp signal is designed to have zero start and zero end
    # % so it is safe to (pre/a)ppend zeros (no discontinuity issue).
    # % 
    # % 
    # % typical paramters could be:
    # %   f0 = 1000
    # %   f1 = 1250
    # %   elapse = 2.5
    # %   fs = 48000
    x1 = expsinesweep(f0, f1, elapse, fs)
    x2 = -flipdim(x1,1)
    y = [x1; x2[2:end]]
end



function add_syncsymbol(signal::Matrix{Float64}, time_contextswitch, syncsymbol::Matrix{Float64}, time_symboldecay, fs) # -> Matrix{Float64}
    # % this function encode the content of the stimulus for playback if sync
    # % (guard) symbols are needed for asynchronous operations.
    # %
    # % +----------+------+-------+--------------------+------+-------+
    # % | t_switch | sync | decay |   test   signal    | sync | decay |
    # % +----------+------+-------+--------------------+------+-------+
    # % t_switch is time for DUT context switch
    # % decay is inserted to separate dynamics of sync and the test signal
    # %
    # % for example:
    # %     signal = [randn(8192,1); zeros(65536,1)];
    # %     g = sync_symbol(1000, 1250, 1, 48000) * (10^(-3/20));
    # %     y = add_sync_symbol(signal, 3, g, 2, 48000);
    # %
    # % we now have a stimulus of pre-silence of 3 seconds, guard chirp of
    # % length 1 second, chirp decaying marging of 2 seconds, a measurement
    # % of random noise.
    n_ch = size(signal, 2)
    tmp, ch_active = findmax(sum(signal.^2,1))
    # only add the sync symbol to the highest-energy channel
    
    t_switch = zeros(round(Int64, time_contextswitch * fs), n_ch)
    t_symbol = zeros(size(syncsymbol,1), n_ch)
    t_symbol[:,ch_active] = syncsymbol[:,1]
    t_decay = zeros(round(Int64, time_symboldecay * fs), n_ch)
    
    y = [t_switch; t_symbol; t_decay; signal; t_symbol; t_decay]
end



                                                ##########################################
                                                ##                                      ##
                                                ##       Chapter II. File System        ##
                                                ##                                      ##
                                                ##########################################

# Deprecated! -> randstring()
# function rand_alphanum(n::Int64)
#     an = collect("0123456789_abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
#     x = Array{Char,1}(n)
#     for i = 1:n
#         x[i] = rand(an)
#     end
#     String(x)
# end



# list all subfolders or files of specified type
# 1. list(path) will list all subfolder names under path, w/o its parent paths!  
# 2. list(path, t=".wav") will list all wav files under path 
function list(path::String; t = "")
    
    x = Array{String,1}()
    for (root, dirs, files) in walkdir(path)
        for dir in dirs
            isempty(t) && push!(x, dir)
        end
        for file in files
            !isempty(t) && lowercase(file[end-length(t)+1:end])==lowercase(t) && push!(x, joinpath(root, file))
        end
    end
    x
end
    

# checksum of file list
function checksum(list::Array{String,1})
    
    d = zeros(UInt8, 32)
    for j in list
        d .+= open(j) do f
            sha256(f)
        end
    end
    d
end
    

function touch_checksum(path::String)
    d = zeros(UInt8, 32)
    d .+= sha256("randomly set the checksum of path")
    p = joinpath(path, "index.sha256")
    writedlm(p, d)
    nothing
end
    
    
function update_checksum(path::String)
    
    p = joinpath(path, "index.sha256")
    writedlm(p, checksum(list(path, t = ".wav")))
    info("checksum updated in $p")
    nothing
end

function verify_checksum(path::String)
    
    p = view(readdlm(joinpath(path, "index.sha256"), UInt8), :, 1)
    q = checksum(list(path, t = ".wav"))
    ok = (0x0 == sum(p - q))
end
    
    
    
    
# resample entire folder to another while maintain folder structure
# 1. need ffmpeg installed as backend
# 2. need sox install as resample engine
function resample(path_i::String, path_o::String, target_fs; source_type=".wav", mix_to_mono=false)
    
    a = list(path_i, t = source_type)
    n = length(a)
    u = Array{Int64,1}(n)
    
    name = randstring(rand(4:32))
    tm = joinpath(tempdir(), "$(name).wav")
    
    for (i, j) in enumerate(a)
        run(`ffmpeg -y -i $j $tm`)
        p = joinpath(path_o, relpath(dirname(j), path_i))
        mkpath(p)
        p = joinpath(p, replace(basename(j), source_type, ".wav"))
        run(`sox $tm -r $(target_fs) $p`)
                
        x, fs = wavread(p)
        assert(fs == typeof(fs)(target_fs))
        if mix_to_mono
            wavwrite(mean(x,2), p, Fs=fs, nbits=32)
        else
            wavwrite(x, p, Fs=fs, nbits=32)
        end
        u[i] = size(x, 1)
        println("$i/$n complete")
    end

    rm(tm, force = true)
    println("max: $(maximum(u) / target_fs) seconds")
    println("min: $(minimum(u) / target_fs) seconds")
    nothing
end




function writebin(file::String, data::AbstractArray{T}) where T<:Number
    open(file, "w") do f
        for i in data
            write(f, i)
        end
    end
end


function readbin(file::String, dtype::Type{T}) where T<:Number
    open(file, "r") do f
        reinterpret(dtype, read(f))
    end
end



#module
end