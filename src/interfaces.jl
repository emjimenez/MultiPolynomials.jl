function _write_input{K<:Field, N}(si, F::Array{Polynomial{K,N},1}; perm=1:N)
    println(si, N, " ", length(F))
    for f in F
        if length(f)==0 # print as if it is a constant term = 0
            println(si, 1)
            for k=1:N
                print(si, "0 ")
            end
            println(si, 0)
        else
            println(si, length(f))
            h = lcm([den(c) for (i,c) in f])
            for (i,c) in f
                for k=1:N
                    print(si, i[perm[k]], " ")
                end
                println(si, num(c*h))
            end
        end
    end    
end

function _read_output(so, K::DataType; perm=nothing)
    N = parse(Int, readuntil(so,' '))
    if perm==nothing
        perm=1:N
    end
    ip = invperm(perm)
    n_poly = parse(Int, readuntil(so,'\n')[1:end-1])
    F = Polynomial{K,N}[]
    for p=1:n_poly
        n_terms = parse(Int, readuntil(so,'\n')[1:end-1])
        f = Polynomial{K,N}([((UInt16[parse(UInt16, readuntil(so,' ')) 
                                      for i=1:N][ip]...),
                    convert(K,parse(BigInt, readuntil(so,'\n')[1:end-1])))
                    for t=1:n_terms])
        push!(F,f)              
    end
    F
end

function groebner_fgb{K<:Field, N}(F::Polynomial{K,N} ...)
    call_fgb = joinpath(dirname(@__FILE__),
               "..", "deps", "bin", "call_fgb")
    (so,si,pr) = readandwrite(`$call_fgb`)

    _write_input(si, [F...])

    G = _read_output(so, K)

    close(so)
    close(si)
    close(pr) 

    G
end

function call_fgb{K<:Field, N}(F::Array{Polynomial{K,N},1};
              perm=collect(1:N),
              verbose::Integer=0,
              n_threads::Integer=1,
              k_elim::Integer=0,
              compute::Integer=1,
              nb::Integer=0,
              n_output_max::Integer=100000,
              force_elim::Bool=false,
              index::Integer=1000000)
    @assert n_threads>0
    @assert k_elim>=0 && k_elim <=N
    @assert compute >=1 && compute <=12
    @assert !force_elim || k_elim>0
    @assert n_output_max>0
    @assert index>0
    @assert length(perm)==N && sort(perm)==collect(1:N)

    opt = [string("-v", verbose),
           string("-t", n_threads),
           string("-k", k_elim),
           string("-o", n_output_max),
           string("-c", compute),
           string("-n", nb),
           string("-m", index),
           string("-e", force_elim?1:0)];
    call_fgb = joinpath(dirname(@__FILE__),
               "..", "deps", "bin", "call_fgb")
    cmd = `$call_fgb $opt`

    (so,si,pr) = readandwrite(cmd)

    _write_input(si, F; perm=perm)

    G = _read_output(so, K; perm=perm)

    close(so)
    close(si)
    close(pr) 

    G
end     

function _adapt_vars_args(vars1::Vector, vars2::Vector)
    k=length(vars2)
    vars = vcat(vars1, vars2)
    N=length(vars)
    for v in vars
        @assert sum(v.index)==1 
    end
    perm = Int[findfirst(v.index,1) for v in vars]
    @assert length(perm)==N && sort(perm)==collect(1:N)
    (k, perm)
end


function fgb_gbasis{K<:Field, N}(F::Array{Polynomial{K,N},1}, 
                                 vars1::Vector, 
                                 vars2::Vector;
                                 verbose::Integer=0,
                                 n_threads::Integer=1,
                                 n_output_max::Integer=100000,
                                 index::Integer=1000000)
    (k, perm) = _adapt_vars_args(vars1, vars2)
    call_fgb(F; perm=perm, k_elim=k, verbose=verbose, 
             n_threads=n_threads, n_output_max=n_output_max, index=index) 
end 

function fgb_gbasis_elim{K<:Field, N}(F::Array{Polynomial{K,N},1}, 
                                 vars1::Vector, 
                                 vars2::Vector;
                                 verbose::Integer=0,
                                 n_threads::Integer=1,
                                 n_output_max::Integer=100000,
                                 index::Integer=1000000)
    (k, perm) = _adapt_vars_args(vars1, vars2)
    call_fgb(F; perm=perm, k_elim=k, force_elim=true, verbose=verbose, 
             n_threads=n_threads, n_output_max=n_output_max, index=index)
end    



function call_giac{K<:Field, N}(F::Array{Polynomial{K,N},1};
              perm=collect(1:N), greduce::Bool=false)
    @assert length(perm)==N && sort(perm)==collect(1:N)

    call_giac = joinpath(dirname(@__FILE__),
               "..", "deps", "bin", "call_giac")
    opt = [ string("-r", greduce?1:0)]               
    cmd = `$call_giac $opt`

    (so,si,pr) = readandwrite(cmd)

    _write_input(si, F; perm=perm)

    G = _read_output(so, K; perm=perm)

    close(so)
    close(si)
    close(pr) 

    G
end     


function giac_gbasis{K<:Field, N}(F::Array{Polynomial{K,N},1}, vars::Vector) 
    (k, perm) = _adapt_vars_args(vars, [])
    call_giac(F; perm=perm)
end 


function giac_greduce{K<:Field, N}(f::Polynomial{K,N}, G::Array{Polynomial{K,N},1}, vars::Vector) 
    (k, perm) = _adapt_vars_args(vars, [])
    r = call_giac(vcat(f, G); perm=perm, greduce=true)
    r[1]/first(values(r[2]))
end 

