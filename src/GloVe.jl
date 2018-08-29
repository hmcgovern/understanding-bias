# Helpers for working with GloVe in Julia
module GloVe

using SparseArrays

export CREC, WORD_INFO


struct CREC
    word1::Int32
    word2::Int32
    val::Float64
end


struct WORD_INFO
    index::Int64
    count::Int64
end


# Load a vocabulary file as a Dict
function load_vocab(filename)
    str2idx = Dict{String, WORD_INFO}()
    idx2str = Array{String, 1}()
    open(filename) do f
        for (i, line) in enumerate(eachline(f))
            entry = split(line)
            str2idx[entry[1]] = WORD_INFO(i, parse(Int64, entry[2]))
            push!(idx2str, entry[1])
        end
    end
    return (str2idx, idx2str)
end


# Read a coocurence from file
function read_cooc(io)::Tuple{Int64,Int64,Float64}
    i::Int64 = read(io, Int32)
    j::Int64 = read(io, Int32)
    x::Float64 = read(io, Float64)
    return (i, j, x)
end


# Load the full coc_matrix.
function load_cooc(filename, V)::SparseMatrixCSC{Float64, Int64}
    I = Array{Int64,1}()
    J = Array{Int64,1}()
    X = Array{Float64,1}()
    open(filename) do f
        while (!eof(f))
            (i, j, x) = read_cooc(f)
            push!(I, i); push!(J, j); push!(X, x)
        end
    end
    return sparse(I, J, X, V, V)
end

# Load only a subset of indices of the coocurence matrix
function load_cooc(filename, V, target_inds::Array{Int64,1})::SparseMatrixCSC{Float64, Int64}
    I = Array{Int64,1}()
    J = Array{Int64,1}()
    X = Array{Float64,1}()
    open(filename) do f
        while (!eof(f))
            (i, j, x) = read_cooc(f)
            if (i in target_inds || j in target_inds)
                push!(I, i); push!(J, j); push!(X, x)
            end
        end
    end
    return sparse(I, J, X, V, V)
end

# Replicated the GloVe preprocessing
function parse_coocs(text::String, vocab::Dict{String,GloVe.WORD_INFO}, window::Int64)::Tuple{Array{Int64,1},Array{Int64,1},Array{Float64,1}}
    words = split(text)
    i::Int64 = -1  # row index
    j::Int64 = -1  # col index
    l1::Int64 = 1  # position of center word
    l2::Int64 = 0  # position of context word
    net_offset::Int64 = 0  # offset (l1 - l2), excluding out-of-vocab "gaps"
    I = Array{Int64,1}()
    J = Array{Int64,1}()
    vals = Array{Float64,1}()
    # slide the center position
    for (l1, word) in enumerate(words)
        i = get(vocab, word, WORD_INFO(-1, -1)).index
        i == -1 && continue  # skip position if out-of-vocab
        l2 = l1  # align
        net_offset = 0  # reset
        while net_offset < window
            l2 -= 1  # increment
            l2 <= 0 && break
            j = get(vocab, words[l2], WORD_INFO(-1, -1)).index
            j == -1 && continue
            net_offset += 1  # word in-vocab, so increment net offset
            push!(I, i);
            push!(J, j);
            push!(vals, 1.0/net_offset)
        end
    end
    return vcat(I, J), vcat(J, I), vcat(vals, vals)
end

# Build a sparse cooc matrix from a single document
function doc2cooc(text::String, vocab::Dict{String,GloVe.WORD_INFO}, window::Int64)::SparseMatrixCSC{Float64,Int64}
    V = length(vocab)
    I, J, vals = parse_coocs(text, vocab, window)
    return sparse(I, J, vals, V, V)
end

# Build a sparse cooc matrix from an iterable set of documents
function docs2cooc(texts, vocab::Dict{String,GloVe.WORD_INFO}, window::Int64;verbose=false)::SparseMatrixCSC{Float64,Int64}
    V = length(vocab)
    I = Array{Int64,1}()
    J = Array{Int64,1}()
    vals = Array{Float64,1}()
    for (num, text) in enumerate(texts)
        i, j, val = parse_coocs(text, vocab, window)
        append!(I, i); append!(J, j); append!(vals, val)
        if (verbose && num % 1000 == 0)
            println("Parsing document $num")
        end
    end
    return sparse(I, J, vals, V, V)
end

# Save a coocurence matrix to file
function save_coocs(out_file::String, X::SparseMatrixCSC{Float64, Int64})
    open(out_file, "w") do out_io
        for (i, j, x) in zip(findnz(X)...)
            write(out_io, Int32(i))
            write(out_io, Int32(j))
            write(out_io, x)
        end
    end
end


# Load the GloVe binary vectors
function load_bin_vectors(filename, V)
    n = div(filesize(filename), 8) # Total number of params (8 bytes per real)
    dim = div(n - 2*V, 2*V) # Solve for dimension of embedding
    W = zeros(V, dim)
    U = zeros(V, dim)
    b_w = zeros(V)
    b_u = zeros(V)
    open(filename) do f
        # Read Word Vectors and Biases
        for i = 1:V
            for j = 1:dim
                W[i, j] = read(f, Float64)
            end
            b_w[i] = read(f, Float64)
        end
        # Read context Vectors and Biases
        for i = 1:V
            for j = 1:dim
                U[i, j] = read(f, Float64)
            end
            b_u[i] = read(f, Float64)
        end
    end
    return (W, b_w, U, b_u)
end


# Convenience wrapper to simplify loading
function load_model(embedding_path)
    vocab_path = "$(dirname(embedding_path))/vocab$(match(r"-C[0-9]+-V[0-9]+", embedding_path).match).txt"
    vocab, ivocab = load_vocab(vocab_path)
    d = parse(Int64, match(r"-W[0-9]+", embedding_path).match[3:end])  # window
    V = length(vocab)
    W, b_w, U, b_u = load_bin_vectors(embedding_path, V)
    D = size(W, 2)
    return (vocab=vocab, ivocab=ivocab, W=W, b_w=b_w, U=U, b_u=b_u, V=V, D=D, d=d)
end

# Save vectors in a text format (useful for running annalogy tests)
function save_text_vectors(filename, W, idx2str)
    (V, D) = size(W)
    open(filename, "w") do f
        for i = 1:V
            print(f, idx2str[i])
            for j = 1:D
                print(f, " ")
                print(f, W[i, j])
            end
            print(f, "\n")
        end
    end
end

# Save vectors in a binary format
function save_bin_vectors(filename, W, b_w, U, b_u)
    (V, dim) = size(W)
    open(filename, "w") do f
        # Read Word Vectors and Biases
        for i = 1:V
            for j = 1:dim
                write(f, W[i, j])
            end
            write(f, b_w[i])
        end
        # Read context Vectors and Biases
        for i = 1:V
            for j = 1:dim
                write(f, U[i, j])
            end
            write(f, b_u[i])
        end
    end
end

end
