using Base.Test, DataStreams, Nulls

@static if !isdefined(Core, :NamedTuple)
    using NamedTuples
end

import Base: ==
==(a::DataStreams.Data.Schema, b::DataStreams.Data.Schema) = DataStreams.Data.types(a) == DataStreams.Data.types(b) && DataStreams.Data.header(a) == DataStreams.Data.header(b) && isequal(size(a), size(b))

mutable struct Source{T}
    sch::DataStreams.Data.Schema
    nt::T
end

DataStreams.Data.schema(s::Source) = s.sch
DataStreams.Data.isdone(s::Source, row, col, rows, cols) = col > cols || (isnull(rows) ? row > length(s.nt[col]) : row > rows)
DataStreams.Data.streamfrom(s::Source, ::Type{DataStreams.Data.Column}, ::Type{T}, row, col) where {T} = s.nt[col]
DataStreams.Data.streamfrom(s::Source, ::Type{DataStreams.Data.Field}, ::Type{T}, row, col) where {T} = s.nt[col][row]

mutable struct Sink{T}
    nt::T
end

@static if isdefined(Core, :NamedTuple)

I = (id = Int64[1, 2, 3, 4, 5],
firstname = (Union{String, Null})["Benjamin", "Wayne", "Sean", "Charles", null],
lastname = String["Chavez", "Burke", "Richards", "Long", "Rose"],
salary = (Union{Float64, Null})[null, 46134.1, 45046.2, 30555.6, 88894.1],
rate = Float64[39.44, 33.8, 15.64, 17.67, 34.6],
hired = (Union{Date, Null})[Date("2011-07-07"), Date("2016-02-19"), null, Date("2002-01-05"), Date("2008-05-15")],
fired = DateTime[DateTime("2016-04-07T14:07:00"), DateTime("2015-03-19T15:01:00"), DateTime("2006-11-18T05:07:00"), DateTime("2002-07-18T06:24:00"), DateTime("2007-09-29T12:09:00")]
)
J = NamedTuple{(:_0, (Symbol("_$i") for i = 1:501)...)}((["0"], ([i] for i =1:501)...))
K = NamedTuple{((Symbol("_$i") for i = 1:501)...)}((([i] for i = 1:501)...))

nms(::NamedTuple{names}) where {names} = names

else # isdefined

I = @NT(id = Int64[1, 2, 3, 4, 5],
firstname = (Union{String, Null})["Benjamin", "Wayne", "Sean", "Charles", null],
lastname = String["Chavez", "Burke", "Richards", "Long", "Rose"],
salary = (Union{Float64, Null})[null, 46134.1, 45046.2, 30555.6, 88894.1],
rate = Float64[39.44, 33.8, 15.64, 17.67, 34.6],
hired = (Union{Date, Null})[Date("2011-07-07"), Date("2016-02-19"), null, Date("2002-01-05"), Date("2008-05-15")],
fired = DateTime[DateTime("2016-04-07T14:07:00"), DateTime("2015-03-19T15:01:00"), DateTime("2006-11-18T05:07:00"), DateTime("2002-07-18T06:24:00"), DateTime("2007-09-29T12:09:00")]
)
J = NamedTuples.make_tuple(vcat([:_0], (Symbol("_$i") for i = 1:501)...))(["0"], ([i] for i =1:501)...)
K = NamedTuples.make_tuple([Symbol("_$i") for i = 1:501])(([i] for i = 1:501)...)

nms(::NT) where {NT <: NamedTuple} = fieldnames(NT)

end # isdefined

I_L = Source(DataStreams.Data.Schema(collect(map(eltype, I)), nms(I), 5), I);
I_M = Source(DataStreams.Data.Schema(collect(map(eltype, I)), nms(I), null), I);

J_L = Source(DataStreams.Data.Schema(collect(map(eltype, J)), nms(J), 1), J);
J_M = Source(DataStreams.Data.Schema(collect(map(eltype, J)), nms(J), null), J);

K_L = Source(DataStreams.Data.Schema(collect(map(eltype, K)), nms(K), 1), K);
K_M = Source(DataStreams.Data.Schema(collect(map(eltype, K)), nms(K), null), K);

Sink(sch::DataStreams.Data.Schema, S, append, args...; reference::Vector{UInt8}=UInt8[]) = Sink(NamedTuple(sch, S, append, args...; reference=reference))
Sink(sink, sch::DataStreams.Data.Schema, S, append; reference::Vector{UInt8}=UInt8[]) = Sink(NamedTuple(sink.nt, sch, S, append; reference=reference))
DataStreams.Data.streamtypes(::Type{Sink}) = [DataStreams.Data.Column, DataStreams.Data.Field]
DataStreams.Data.weakrefstrings(::Type{Sink}) = true
DataStreams.Data.streamto!(sink::Sink, ::Type{DataStreams.Data.Field}, val, row, col) =
(C = getfield(sink.nt, col); row > length(C) ? push!(C, val) : setindex!(C, val, row); return)
DataStreams.Data.streamto!(sink::Sink, ::Type{DataStreams.Data.Column}, column, col) =
append!(getfield(sink.nt, col), column)

@testset "DataStreams" begin

@testset "Data.Schema" begin

sch = DataStreams.Data.Schema()
@test size(sch) == (0, 0)
@test DataStreams.Data.header(sch) == String[]
@test DataStreams.Data.types(sch) == ()

sch = DataStreams.Data.Schema((Int,))
@test size(sch) == (0, 1)
@test DataStreams.Data.header(sch) == String["Column1"]
@test DataStreams.Data.types(sch) == (Int,)

sch = DataStreams.Data.Schema([Int])
@test size(sch) == (0, 1)
@test DataStreams.Data.header(sch) == String["Column1"]
@test DataStreams.Data.types(sch) == (Int,)

sch = DataStreams.Data.Schema((Int,), ["col1"])
@test size(sch) == (0, 1)
@test DataStreams.Data.header(sch) == String["col1"]
@test DataStreams.Data.types(sch) == (Int,)

@test_throws ArgumentError DataStreams.Data.Schema((String,), ["col1", "col2"])

getR(::DataStreams.Data.Schema{R}) where {R} = R
getT(::DataStreams.Data.Schema{R, T}) where {R, T} = T

sch = DataStreams.Data.Schema((Int,), ["col1"], 1)
@test size(sch) == (1, 1)
@test DataStreams.Data.header(sch) == String["col1"]
@test DataStreams.Data.types(sch) == (Int,)
@test getR(sch) == true
@test getT(sch) == Tuple{Int}

sch = DataStreams.Data.Schema((String,), ["col1"], null)
@test isequal(size(sch), (null, 1))
@test DataStreams.Data.header(sch) == String["col1"]
@test DataStreams.Data.types(sch) == (String,)
@test getR(sch) == false
@test getT(sch) == Tuple{String}

@test_throws ArgumentError DataStreams.Data.Schema((String,), ["col1"], -1)

sch = DataStreams.Data.Schema((Int,), ["col1"], 0, Dict("hey"=>"ho"))
@test size(sch) == (0, 1)
@test DataStreams.Data.header(sch) == String["col1"]
@test DataStreams.Data.types(sch) == (Int,)
@test DataStreams.Data.metadata(sch) == Dict("hey"=>"ho")

sch = DataStreams.Data.Schema((Int,), ["col1"])
@test sch["col1"] == 1

end # @testset "Data.Schema"

@testset "Data.transform" begin

# knownrows vs. not
sch = DataStreams.Data.Schema((Int,), ["col1"], 1)
sch2, trans = DataStreams.Data.transform(sch, Dict{Int, Function}(), true)
@test sch == sch2
@test trans == (identity,)

sch = DataStreams.Data.Schema((Int, Float64, String,), ["col1", "col2", "col3"], null)
sch2, trans = DataStreams.Data.transform(sch, Dict{Int, Function}(), true)
@test sch == sch2
@test trans == (identity, identity, identity)

sch = DataStreams.Data.Schema((Int,), ["col1"], 1)
f = x->string(x)
sch2, trans = DataStreams.Data.transform(sch, Dict(1=>f), true)
@test DataStreams.Data.header(sch) == DataStreams.Data.header(sch2)
@test DataStreams.Data.types(sch2) == (String,)
@test trans == (f,)

sch = DataStreams.Data.Schema((Int, Float64, String), ["col1", "col2", "col3"], null)
f = x->parse(Int, x)
sch2, trans = DataStreams.Data.transform(sch, Dict("col3"=>f), true)
@test DataStreams.Data.header(sch) == DataStreams.Data.header(sch2)
@test DataStreams.Data.types(sch2) == (Int, Float64, Int)
@test trans == (identity, identity, f)

sch = DataStreams.Data.Schema((Int, Float64, String), ["col1", "col2", "col3"], null)
sch2, trans = DataStreams.Data.transform(sch, Dict{Int, Function}(), false)
@test DataStreams.Data.header(sch) == DataStreams.Data.header(sch2)
@test DataStreams.Data.types(sch2) == (Int, Float64, String)
@test trans == (identity, identity, identity)

sch = DataStreams.Data.Schema((Union{String, Null},), ["col1"])
sch2, trans = DataStreams.Data.transform(sch, Dict{Int, Function}(), false)
@test DataStreams.Data.header(sch) == DataStreams.Data.header(sch2)
@test DataStreams.Data.types(sch2) == (Union{String, Null},)
@test trans == (identity,)

sch = DataStreams.Data.Schema((Int,), ["col1"], 1)
sch2, trans = DataStreams.Data.transform(sch, Dict("col1"=>sin), false)
@test DataStreams.Data.header(sch) == DataStreams.Data.header(sch2)
@test DataStreams.Data.types(sch2) == (Float64,)
@test trans == (sin,)

end # @testset "Data.transform"

@testset "Data.stream!" begin

### ALL PAIRS TESTING

# constructed Sink vs. constructed on-the-fly: A, B
# append vs. not; C, D
# w/ transform functions vs. not: E, F
# Data.Field vs. Data.Column: G, H
# <500, >500, homogenous types code path: I, J, K
# knownrows vs. not: L, M

# incompatible source => constructed Sink
@test_throws ArgumentError DataStreams.Data.stream!(I_L, Sink(I))

# incompatible source => otf Sink
@test_throws ArgumentError DataStreams.Data.stream!(I_L, Sink, I)

## Data.Field
DataStreams.Data.streamtype(::Type{Source}, ::Type{DataStreams.Data.Field}) = true
# A, C, E, G, I, L: append to constructed Sink w/ transforms via Data.Field w/ Source=I_J
source = I_L
sink = Sink(deepcopy(I))
transforms = Dict(1=>x->x+1)
DataStreams.Data.stream!(source, sink; append=true, transforms=transforms)

sch = DataStreams.Data.schema(sink.nt)
@test size(sch) == (10, 7)
@test DataStreams.Data.header(sch) == ["id","firstname","lastname","salary","rate","hired","fired"]
@test DataStreams.Data.types(sch) == (Int64, Union{String, Null}, String, Union{Float64, Null}, Float64, Union{Date, Null}, DateTime)
@test sink.nt.id == [1,2,3,4,5,2,3,4,5,6]

# A, C, F, G, J, L: append to constructed Sink w/o transforms via Data.Field w/ Source=J_L
source = J_L;
sink = Sink(deepcopy(J));
Data.stream!(source, sink; append=true);

sch = DataStreams.Data.schema(sink.nt)
@test size(sch) == (2, 502)
@test DataStreams.Data.header(sch) == collect("_$i" for i = 0:501)
@test DataStreams.Data.types(sch) == (String, (Int for i = 1:501)...)
@test sink.nt._0 == ["0", "0"]
@test sink.nt._1 == [1, 1]

# A, D, F, G, J, M: replace constructed Sink w/o transforms via Data.Field w/ Source=J_M
source = J_M;
sink = Sink(deepcopy(J));
Data.stream!(source, sink)

sch = DataStreams.Data.schema(sink.nt)
@test size(sch) == (1, 502)
@test DataStreams.Data.header(sch) == collect("_$i" for i = 0:501)
@test DataStreams.Data.types(sch) == (String, (Int for i = 1:501)...)
@test sink.nt._0 == ["0"]
@test sink.nt._1 == [1]

# B, D, E, G, J, L: replace otf Sink w/ transforms via Data.Field w/ Source=J_L
source = J_L
sink = Sink(deepcopy(J))
transforms = Dict(2=>x->x+1)
Data.stream!(source, Sink, sink.nt; transforms=transforms)

sch = DataStreams.Data.schema(sink.nt)
@test size(sch) == (1, 502)
@test DataStreams.Data.header(sch) == collect("_$i" for i = 0:501)
@test DataStreams.Data.types(sch) == (String, (Int for i = 1:501)...)
@test sink.nt._0 == ["0"]
@test sink.nt._1 == [2]

# B, D, E, G, K, L: replace otf Sink w/ transforms via Data.Field w/ Source=K_L
source = K_L
sink = Sink(deepcopy(K))
transforms = Dict(2=>x->x+1)
Data.stream!(source, Sink, sink.nt; transforms=transforms)

sch = DataStreams.Data.schema(sink.nt)
@test size(sch) == (1, 501)
@test DataStreams.Data.header(sch) == collect("_$i" for i = 1:501)
@test DataStreams.Data.types(sch) == ((Int for i = 1:501)...)
@test sink.nt._1 == [1]
@test sink.nt._2 == [3]

# Test unparameterized NamedTuple sink directly
# B, D, F, G, J, M
source = J_M
sink = Data.stream!(source, NamedTuple)

sch = DataStreams.Data.schema(sink)
@test size(sch) == (1, 502)
@test DataStreams.Data.header(sch) == collect("_$i" for i = 0:501)
@test DataStreams.Data.types(sch) == (String, (Int for i = 1:501)...)
@test sink._0 == ["0"]
@test sink._1 == [1]

## Data.Column
# A, D, E, H, K, M: replace constructed Sink w/ transforms via Data.Column w/ Source=K_M
DataStreams.Data.streamtype(::Type{<:Source}, ::Type{DataStreams.Data.Column}) = true
source = K_M
sink = Sink(deepcopy(K))
transforms = Dict(2=>x->x.+1)
Data.stream!(source, sink; transforms=transforms)

sch = DataStreams.Data.schema(sink.nt)
@test size(sch) == (1, 501)
@test DataStreams.Data.header(sch) == collect("_$i" for i = 1:501)
@test DataStreams.Data.types(sch) == ((Int for i = 1:501)...)
@test sink.nt._1 == [1]
@test sink.nt._2 == [3]

# B, C, F, H, K, M: append to otf Sink w/o transforms via Data.Column w/ Source=K_M
source = K_M
sink = Sink(deepcopy(K))
Data.stream!(source, Sink, sink.nt; append=true)

sch = DataStreams.Data.schema(sink.nt)
@test size(sch) == (2, 501)
@test DataStreams.Data.header(sch) == collect("_$i" for i = 1:501)
@test DataStreams.Data.types(sch) == ((Int for i = 1:501)...)
@test sink.nt._1 == [1, 1]
@test sink.nt._2 == [2, 2]

# B, D, F, H, I, M: replace otf Sink w/o transforms via Data.Column w/ Source=I_M
source = I_M
sink = Sink(deepcopy(I))
transforms = Dict()
Data.stream!(source, Sink, sink.nt)

sch = DataStreams.Data.schema(sink.nt)
@test size(sch) == (5, 7)
@test DataStreams.Data.header(sch) == ["id","firstname","lastname","salary","rate","hired","fired"]
@test DataStreams.Data.types(sch) == (Int64, Union{String, Null}, String, Union{Float64, Null}, Float64, Union{Date, Null}, DateTime)
@test sink.nt.id == [1,2,3,4,5]

# B, D, F, H, I, L: replace otf Sink w/o transforms via Data.Column w/ Source=I_L
source = I_L
sink = Sink(deepcopy(I))
Data.stream!(source, Sink, sink.nt)

sch = DataStreams.Data.schema(sink.nt)
@test size(sch) == (5, 7)
@test DataStreams.Data.header(sch) == ["id","firstname","lastname","salary","rate","hired","fired"]
@test DataStreams.Data.types(sch) == (Int64, Union{String, Null}, String, Union{Float64, Null}, Float64, Union{Date, Null}, DateTime)
@test sink.nt.id == [1,2,3,4,5]

# B, D, E, H, J, L: replace otf Sink w/ transforms via Data.Field w/ Source=J_L
source = J_L
sink = Sink(deepcopy(J))
transforms = Dict(2=>x->x.+1)
Data.stream!(source, Sink, sink.nt; transforms=transforms)

sch = DataStreams.Data.schema(sink.nt)
@test size(sch) == (1, 502)
@test DataStreams.Data.header(sch) == collect("_$i" for i = 0:501)
@test DataStreams.Data.types(sch) == (String, (Int for i = 1:501)...)
@test sink.nt._0 == ["0"]
@test sink.nt._1 == [2]

# Test unparameterized NamedTuple sink directly
# B, D, F, H, I, M
source = I_M
sink = Data.stream!(source, NamedTuple)

sch = DataStreams.Data.schema(sink)
@test size(sch) == (5, 7)
@test DataStreams.Data.header(sch) == ["id","firstname","lastname","salary","rate","hired","fired"]
@test DataStreams.Data.types(sch) == (Int64, Union{String, Null}, String, Union{Float64, Null}, Float64, Union{Date, Null}, DateTime)
@test sink.id == [1,2,3,4,5]

end # @testset "Data.stream!"

# @testset "DataStreams NamedTuple" begin
#
# end
end # @testset "DataStreams"
