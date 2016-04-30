# DataStreams

[![DataStreams](http://pkg.julialang.org/badges/DataStreams_0.4.svg)](http://pkg.julialang.org/?pkg=DataStreams&ver=0.4)

Linux: [![Build Status](https://travis-ci.org/JuliaDB/DataStreams.jl.svg?branch=master)](https://travis-ci.org/JuliaDB/DataStreams.jl)

Windows: [![Build Status](https://ci.appveyor.com/api/projects/status/github/JuliaDB/DataStreams.jl?branch=master&svg=true)](https://ci.appveyor.com/project/JuliaDB/datastreams-jl/branch/master)

[![codecov.io](http://codecov.io/github/JuliaDB/DataStreams/coverage.svg?branch=master)](http://codecov.io/github/JuliaDB/DataStreams?branch=master)

The `DataStreams.jl` packages defines a data processing framework based on Sources, Sinks, and the `Data.stream!` function.

`DataStreams` defines the common infrastructure leveraged by individual packages to create systems of various
data sources and sinks that talk to each other in a unified, consistent way.

The workflow enabled by the `DataStreams` framework involves:
 * constructing new `Source` types to allow streaming data from files, databases, and other "sources" of data.
 * `Data.stream!` those datasets to newly created or existing `Sink` types
 * convert `Sink` types that have received data into new `Source` types
 * continue to `Data.stream!` from `Source`s to `Sink`s

The typical approach for a new package to "satisfy" the DataStreams interface is to:
 * Define a `Source` type that wraps a "true data source" (i.e. a file, database table/query, etc.) and fulfills the `Source` interface (see `?Data.Source`)
 * Define a `Sink` type that can create or write data to a "true data source" and fulfills the `Sink` interface (see `?Data.Sink`)
 * Define appropriate `Data.stream!(::Source, ::Sink)` methods as needed between various combinations of Sources and Sinks;
   i.e. define `Data.stream!(::NewPackage.Source, ::CSV.Sink)` and `Data.stream!(::CSV.Source, ::NewPackage.Sink)`

#### Sources
A `Data.Source` type holds data that can be read/queried/parsed/viewed/streamed; i.e. a "true data source"
To clarify, there are two distinct types of "source":
  1) the "true data source", which would be the file, database, API, structure, etc; i.e. the actual data
  2) the `Data.Source` julia object that wraps a "true source" and provides the `DataStreams` interface

`Source` types have two different types of constructors:
  1) "independent constructors" that wrap "true data sources"
  and 2) "sink constructors" where a `Data.Sink` object that has received data is turned into a `Source`

`Source`s also have a, currently implicit, notion of state:
  * `BEGINNING`: a `Source` is in this state immediately after being constructed and is ready to be used; i.e. ready to read/parse/query/stream data from it; any necessary setup, construction, or query execution has taken place during construction
  * `READING`: the ingestion of data from this `Source` has started and has not finished yet
  * `DONE`: the ingestion process has exhausted all data expected from this `Source` instance

The `Data.Source` interface includes the following:
 * `Data.schema(::Data.Source) => Data.Schema`; typically the `Source` type will store the `Data.Schema` directly, but this isn't strictly required
 * `Data.reset!(::Data.Source)`; used to reset a `Source` type from `READING` or `DONE` to the `BEGINNING` state, ready to be read from again
 * `Data.isdone(::Data.Source)` => Bool; indicates whether the `Source` type is in the `DONE` state; i.e. all data has been exhausted from this source

#### Sinks
A `Data.Sink` type represents a data destination; i.e. a "true data source" such as a database, file, API endpoint, etc.

There are two broad types of `Sink`s:
  1) "new sinks": an independent `Sink` constructor creates a *new* "true data source" that can be streamed to
  2) "existing sinks": the `Sink` wraps an already existing "true data source" (or `Source` object that wraps a "true data source").
    Upon construction of these Sinks, there is no new creation of "true data source"s; the "true data source" is simply wrapped to replace or append to

`Sink`s also have notions of state:
  * `BEGINNING`: the `Sink` is freshly constructed and ready to stream data to; this includes initial metadata like column headers
  * `WRITING`: data has been streamed to the `Sink`, but is still open to receive more data
  * `DONE`: the `Sink` has been closed and can no longer receive data

The `Data.Sink` interface includes the following:
 * `Data.schema(::Data.Sink) => Data.Schema`; typically the `Sink` type will store the `Data.Schema` directly, but this isn't strictly required
 * `Data.reset!(::Data.Sink;append::Bool=false)`; used to reset a `Sink` type from `WRITING` or `DONE` to the `BEGINNING` state, ready to receive data again
 * `Data.isdone(::Data.Sink)`; indicates whether the `Sink` type is in the `DONE` state; i.e. if it can receive any more data


#### Helper Types

The `DataStreams` package also provides a few helper types that have proven useful to the greater `DataStreams` ecosystem.

##### Data.Table

The `Data.Table` type is a generic "tabular dataset" type that can fulfill the `Data.Source` and `Data.Sink` interfaces. By default, its inner representation is a `Vector{NullableVector}` (utilizing the [`NullableArrays`](https://github.com/JuliaStats/NullableArrays.jl) pacakage).

This type is meant to be a "bare-bones" interface to a tabular dataset representation and allow packages to read/write with this thin, efficient structure as a standard default while allowing additional data manipulation operations to be handled by more appropriate packages (i.e DataFrames, SQLite, etc.). A non-copying conversion method is provided, for example, between a `Data.Table` and a `DataFrame`, as long as the user calls `using DataFrames` before `using DataStreams` (or any other package that internally calls `using DataStreams`). So a broader workflow for reading/writing data + manipulation might look like:

```julia
using DataFrames
using CSV, SQLite, ODBC

data = ODBC.query(dsn, "select * from employee") # stream data from a DB table to a Data.Table
df = DataFrame(data) # convert Data.Table to a DataFrame without copying the data
#=
... various DataFrame manipulations
=#
dt = Data.Table(df) # convert DataFrame back to a Data.Table without copying the data
csv = CSV.Sink("dataframe_output.csv")
Data.stream!(dt, csv) # stream the data from our Data.Table out to a CSV file
```

##### Data.PointerString

Currently, Base Julia doesn't provide the concept of a true "weakref" String type; i.e. a substring-like type that doesn't also hold a reference to its original data. The `Data.PointerString` type provides this interface with a minimal set of methods to satisfy some basic string functionality. For more involved string processing needs, the user will need to convert to a proper String type; i.e. `string(str::Data.PointerString)`. It is expected in future iterations of the language that Julia will gain native and better support for this type of structure, so it won't need to be defined here.
