using Test, Random, CategoricalArrays, Dates, PooledArrays
const ≅ = isequal
@testset "general usage" begin

    ds = Dataset(x1 = [1,2,3,4], x2 = [1,4,9,16])
    dst =Dataset(_variables_ =["x1","x2"], _c1 = [1,1], _c2 = [2,4],
                    _c3 = [3,9], _c4 = [4,16])
    @test transpose(ds, [:x1, :x2]) == dst

    ds = Dataset(rand(10,5), :auto)
    ds2 = transpose(ds, r"x")

    @test Matrix(ds) == permutedims(Matrix(ds2[!,r"_c"]))

    ds = Dataset(rand(10,5), :auto)
    # allowmissing!(ds)
    ds2 = transpose(ds, r"x")

    @test transpose(ds, r"x") == transpose(ds, :)
    @test transpose(ds, r"x") == transpose(ds, [1,2,3,4,5])
    @test Matrix(ds) == permutedims(Matrix(ds2[!,2:end]))

    ds = Dataset(rand(10,5), :auto)
    # allowmissing!(ds)
    ds[1, 4] = missing
    ds[4, 5] = missing
    ds2 = transpose(ds, r"x")
    @test Matrix(ds) ≅ permutedims(Matrix(ds2[!,Not(:_variables_)]))


    ds = InMemoryDatasets.hcat!(Dataset(rand(Bool, 15,2),[:b1,:b2]), Dataset(rand(15,5),:auto))
    ds2 = transpose(ds, :)
    @test Matrix(ds) == permutedims(Matrix(ds2[!,Not(:_variables_)]))



    ds = Dataset(foo = ["one", "one", "one", "two", "two","two"],
                    bar = ['A', 'B', 'C', 'A', 'B', 'C'],
                    baz = [1, 2, 3, 4, 5, 6],
                    zoo = ['x', 'y', 'z', 'q', 'w', 't'])
    ds2 = transpose(groupby(ds, :foo, stable = true), :baz, id = :bar)
    @test sort(ds2, :) == sort(transpose(gatherby(ds, :foo), :baz, id = :bar), :)
    ds3 = Dataset(foo = ["one", "two"], _variables_ = ["baz", "baz"], A = [1, 4], B = [2, 5], C = [3, 6])

    @test transpose(groupby(ds, :foo, stable = true), :baz, id = :bar) == transpose(groupby(ds, :foo, stable = true), [:baz], id = :bar)
    @test transpose(groupby(ds, :foo, stable = true), :baz, id = :bar) == transpose(groupby(ds, :foo, stable = true), [:baz], id = :bar)
    @test transpose(groupby(ds, :foo, stable = true), :baz, id = :bar) == transpose(groupby(ds, :foo, stable = true), :baz, id = :bar)
    @test ds2 == ds3

    ds = Dataset(id = [1, 2, 3, 1], x1 = rand(4), x2 = rand(4))
    @test_throws AssertionError transpose(ds, r"x", id = :id)


    ds = Dataset(rand(1:100, 1000, 10), :auto)
    insertcols!(ds, 1, :g => repeat(1:100, inner = 10))
    insertcols!(ds, 2, :id => repeat(1:10, 100))
    # duplicate and id within the last group
    ds[1000, :id] = 1
    @test_throws AssertionError transpose(groupby(ds, :g, stable = true), r"x", id = :id, threads = false)


    ds = Dataset(rand(1000, 100), :auto)
    mds = Matrix(ds)

    @test sum.(eachcol(transpose(ds, r"x")[!, r"_c"])) ≈ sum(mds, dims = 2)

    ds = Dataset([[1, 2], [1.1, 2.0],[1.1, 2.1],[1.1, 2.0]]
                    ,[:person, Symbol("11/2020"), Symbol("12/2020"), Symbol("1/2021")])

    groupby!(ds, :person, stable = true)
    dst = transpose(ds, Not(:person),
                        renamerowid = x -> Date(x, dateformat"m/y"),
                        variable_name = "Date",
                         renamecolid = x -> "measurement")
   @test sort(dst, :) == sort(transpose(gatherby(ds, :person), Not(:person),
                     renamerowid = x -> Date(x, dateformat"m/y"),
                     variable_name = "Date",
                      renamecolid = x -> "measurement"),:)
    dstm = Dataset(person = [1,1,1,2,2,2],
                Date = Date.(repeat(["2020-11-01","2020-12-01","2021-01-01"], 2)),
                measurement = [1.1, 1.1, 1.1, 2.0, 2.1, 2.0])
    @test dst == dstm
    dst = transpose(groupby(ds, :person, stable = true), Not(:person),
                        renamerowid = x -> Date(x, dateformat"m/y"),
                        variable_name = "Date",
                         renamecolid = x -> "measurement")
    dstm = Dataset(person = [1,1,1,2,2,2],
                Date = Date.(repeat(["2020-11-01","2020-12-01","2021-01-01"], 2)),
                measurement = [1.1, 1.1, 1.1, 2.0, 2.1, 2.0])
    @test dst == dstm


    ds = Dataset(rand(100,5),:auto)
    insertcols!(ds, 1, :id => repeat(1:20, 5))
    insertcols!(ds, 1, :g => repeat(1:5, inner = 20))

    dst = transpose(groupby(ds, [:g, :id], stable = true), r"x" , variable_name = "variable", renamecolid = x -> "value")

    @test sort(dst, :) == sort(transpose(gatherby(ds, [:g, :id]), r"x" , variable_name = "variable", renamecolid = x -> "value"), :)

    ds = Dataset(group = repeat(1:3, inner = 2),
                                 b = repeat(1:2, inner = 3),
                                 c = repeat(1:1, inner = 6),
                                 d = repeat(1:6, inner = 1),
                                 e = string.('a':'f'))
    # allowmissing!(ds)
    ds[2, :b] = missing
    ds[4, :d] = missing
    ds2 = transpose(groupby(ds, :group, stable = true), 2:4, id = :e, default = 0)

    ds3 = Dataset(group = repeat(1:3, inner = 3),
                    _variables_ = string.(repeat('b':'d', 3)),
                    a = [1,1,1,0,0,0,0,0,0],
                    b = [missing,1,2,0,0,0,0,0,0],
                    c = [0,0,0, 1,1,3, 0,0,0],
                    d = [0,0,0, 2,1,missing, 0,0,0],
                    e = [0,0,0,0,0,0,2,1,5],
                    f = [0,0,0,0,0,0,2,1,6] )
    @test ds2 ≅ ds3

    ds = Dataset(id = ["r3", "r1", "r2" , "r4"], x1 = [1,2,3,4], x2 = [1,4,9,16])
    ds2 = transpose(ds, [:x1,:x2], id = :id)
    ds3 = Dataset([["x1", "x2"],
                        [1, 1],
                        [2, 4],
                        [3, 9],
                        [4, 16]],
                        [:_variables_, :r3, :r1, :r2, :r4])
    @test ds3 == ds2

    pop = Dataset(country = ["c1","c1","c2","c2","c3","c3"],
                            sex = ["male", "female", "male", "female", "male", "female"],
                            pop_2000 = [100, 120, 150, 155, 170, 190],
                            pop_2010 = [110, 120, 155, 160, 178, 200],
                            pop_2020 = [115, 130, 161, 165, 180, 203])

    popt = transpose(groupby(pop, :country, stable = true), r"pop_",
                            id = :sex, variable_name = "year",
                            renamerowid = x -> match(r"[0-9]+",x).match, renamecolid = x -> x * "_pop")
    poptm = Dataset([["c1", "c1", "c1", "c2", "c2", "c2", "c3", "c3", "c3"],
            SubString{String}["2000", "2010", "2020", "2000", "2010", "2020", "2000", "2010", "2020"],
            Union{Missing, Int64}[100, 110, 115, 150, 155, 161, 170, 178, 180],
            Union{Missing, Int64}[120, 120, 130, 155, 160, 165, 190, 200, 203]],
            [:country,:year,:male_pop,:female_pop])

    @test popt == poptm
    popt = transpose(groupby(pop, r"cou", stable = true), r"pop", id = r"sex",  variable_name = "year",
                            renamerowid = x -> match(r"[0-9]+",x).match, renamecolid = x -> x * "_pop")
    @test popt == poptm
    pop.country = PooledArray(pop.country)
    popt = transpose(groupby(pop, r"cou", stable = true), r"pop", id = r"sex",  variable_name = "year",
                            renamerowid = x -> match(r"[0-9]+",x).match, renamecolid = x -> x * "_pop")
    @test popt.country == PooledArray(["c1", "c1", "c1", "c2", "c2", "c2", "c3", "c3", "c3"])
    ds =  Dataset(region = repeat(["North","North","South","South"],2),
                 fuel_type = repeat(["gas","coal"],4),
                 load = [.1,.2,.5,.1,6.,4.3,.1,6.],
                 time = [1,1,1,1,2,2,2,2],
                 )

    ds2 = transpose(groupby(ds, :time, stable = true), :load, id = 1:2)
    ds3 = Dataset([ Union{Missing, Int64}[1, 2],
                 ["load", "load"],
                 Union{Missing, Float64}[0.1, 6.0],
                 Union{Missing, Float64}[0.2, 4.3],
                 Union{Missing, Float64}[0.5, 0.1],
                 Union{Missing, Float64}[0.1, 6.0]], ["time", "_variables_", "(\"North\", \"gas\")", "(\"North\", \"coal\")", "(\"South\", \"gas\")", "(\"South\", \"coal\")"])

     @test ds2 == ds3
     ds = Dataset(A_2018=1:4, A_2019=5:8, B_2017=9:12,
                             B_2018=9:12, B_2019 = [missing,13,14,15],
                              ID = [1,2,3,4])
      f(x) =  match(r"[0-9]+",x).match
      dsA = transpose(groupby(ds, :ID, stable = true), r"A", renamerowid = f, variable_name = "Year", renamecolid = x->"A");
      dsB = transpose(groupby(ds, :ID, stable = true), r"B", renamerowid = f, variable_name = "Year", renamecolid = x->"B");
      ds2 = outerjoin(dsA, dsB, on = [:ID, :Year])
      ds3 = Dataset([[1, 1, 2, 2, 3, 3, 4, 4, 1, 2, 3, 4],
                 SubString{String}["2018", "2019", "2018", "2019", "2018", "2019", "2018", "2019", "2017", "2017", "2017", "2017"],
                 Union{Missing, Int64}[1, 5, 2, 6, 3, 7, 4, 8, missing, missing, missing, missing],
                 Union{Missing, Int64}[9, missing, 10, 13, 11, 14, 12, 15, 9, 10, 11, 12]], [:ID,:Year,:A,:B])
        @test ds2 ≅ ds3
        ds = Dataset(paddockId= [0, 0, 1, 1, 2, 2],
                                color= ["red", "blue", "red", "blue", "red", "blue"],
                                count= [3, 4, 3, 4, 3, 4],
                                weight= [0.2, 0.3, 0.2, 0.3, 0.2, 0.2])
        ds2 = transpose(groupby(transpose(groupby(ds, [:paddockId,:color], stable = true), [:count,:weight]), :paddockId, stable = true),
                             :_c1, id = 2:3)
        ds3 = Dataset([Union{Missing, Int64}[0, 1, 2],
             Union{Missing, String}["_c1", "_c1", "_c1"],
             Union{Missing, Float64}[4.0, 4.0, 4.0],
             Union{Missing, Float64}[0.3, 0.3, 0.2],
             Union{Missing, Float64}[3.0, 3.0, 3.0],
             Union{Missing, Float64}[0.2, 0.2, 0.2]], ["paddockId", "_variables_", "(\"blue\", \"count\")", "(\"blue\", \"weight\")", "(\"red\", \"count\")", "(\"red\", \"weight\")"])

         @test ds2 == ds3

        ds = Dataset(x1 = [9,2,8,6,8], x2 = [8,1,6,2,3], x3 = [6,5,3,10,8])
        ds2 = transpose(ds, r"x", renamerowid = x -> match(r"[0-9]+",x).match,renamecolid = x -> "_column_" * string(x))
        ds3 = Dataset([SubString{String}["1", "2", "3"],
                         [9, 8, 6],
                         [2, 1, 5],
                         [8, 6, 3],
                         [6, 2, 10],
                         [8, 3, 8]],[:_variables_,:_column_1,:_column_2,:_column_3,:_column_4,:_column_5])
         @test ds2 == ds3
         ds = Dataset(a=["x", "y"], b=[1, "two"], c=[3, 4], d=[true, false])
         ds2 = transpose(ds, [:b, :c, :d], id = :a, variable_name = "new_col")
         ds3 = Dataset([["b", "c", "d"],
                         Any[1, 3, true],
                         Any["two", 4, false]],[:new_col,:x,:y])
         @test ds2 == ds3

         ds = Dataset(g1 = ["g2", "g1", "g1", "g2", "g1", "g3"], c1 = ["c1", "c1", "c1", "c1", "c1", "c1"],
                id1 = ["id2_g2", "id1_g1", "id2_g1", "id1_g2", "id3_g1", "id4_g3"], id2 = [2, 3, 1, 5, 4, 6],
                val1 = [1, 2, 3, 4, 5, 6], val2 = [1.1, 2.1, 0.5, 1.3, 1.0, 2])
        ds2 = transpose(ds, [:val1, :val2])
        ds3 = transpose(ds, [:val1, :val2], id = :id2)
        ds4 = transpose(ds, [:val1, :val2], id = [:id1, :id2])
        ds5 = transpose(groupby(ds, 1, stable = true), [:val1, :val2])
        ds6 = transpose(groupby(ds, 1, stable = true), [:val1, :val2], id = :id1)
        ds7 = transpose(groupby(ds, 1, stable = true), [:val1, :val2], id = [:id1, :id2])
        ds8 = transpose(groupby(ds, 1:2, stable = true), [:val1, :val2], id = :id2)
        ds9 = transpose(groupby(ds, 1:2, stable = true), [:val1], id = [:id2, :id1])

        tds2 = Dataset([Union{Missing, String}["val1", "val2"],
                 Union{Missing, Float64}[1.0, 1.1],
                 Union{Missing, Float64}[2.0, 2.1],
                 Union{Missing, Float64}[3.0, 0.5],
                 Union{Missing, Float64}[4.0, 1.3],
                 Union{Missing, Float64}[5.0, 1.0],
                 Union{Missing, Float64}[6.0, 2.0]], ["_variables_", "_c1", "_c2", "_c3", "_c4", "_c5", "_c6"])
        tds3 = Dataset([Union{Missing, String}["val1", "val2"],
                 Union{Missing, Float64}[1.0, 1.1],
                 Union{Missing, Float64}[2.0, 2.1],
                 Union{Missing, Float64}[3.0, 0.5],
                 Union{Missing, Float64}[4.0, 1.3],
                 Union{Missing, Float64}[5.0, 1.0],
                 Union{Missing, Float64}[6.0, 2.0]], ["_variables_", "2", "3", "1", "5", "4", "6"])
        tds4 = Dataset([Union{Missing, String}["val1", "val2"],
                 Union{Missing, Float64}[1.0, 1.1],
                 Union{Missing, Float64}[2.0, 2.1],
                 Union{Missing, Float64}[3.0, 0.5],
                 Union{Missing, Float64}[4.0, 1.3],
                 Union{Missing, Float64}[5.0, 1.0],
                 Union{Missing, Float64}[6.0, 2.0]], ["_variables_", "(\"id2_g2\", 2)", "(\"id1_g1\", 3)", "(\"id2_g1\", 1)", "(\"id1_g2\", 5)", "(\"id3_g1\", 4)", "(\"id4_g3\", 6)"])
        tds5 = Dataset([Union{Missing, String}["g1", "g1", "g2", "g2", "g3", "g3"],
                 Union{Missing, String}["val1", "val2", "val1", "val2", "val1", "val2"],
                 Union{Missing, Float64}[2.0, 2.1, 1.0, 1.1, 6.0, 2.0],
                 Union{Missing, Float64}[3.0, 0.5, 4.0, 1.3, missing, missing],
                 Union{Missing, Float64}[5.0, 1.0, missing, missing, missing, missing]], ["g1", "_variables_", "_c1", "_c2", "_c3"])
        tds6 = Dataset([Union{Missing, String}["g1", "g1", "g2", "g2", "g3", "g3"],
                 Union{Missing, String}["val1", "val2", "val1", "val2", "val1", "val2"],
                 Union{Missing, Float64}[2.0, 2.1, missing, missing, missing, missing],
                 Union{Missing, Float64}[3.0, 0.5, missing, missing, missing, missing],
                 Union{Missing, Float64}[5.0, 1.0, missing, missing, missing, missing],
                 Union{Missing, Float64}[missing, missing, 1.0, 1.1, missing, missing],
                 Union{Missing, Float64}[missing, missing, 4.0, 1.3, missing, missing],
                 Union{Missing, Float64}[missing, missing, missing, missing, 6.0, 2.0]], ["g1", "_variables_", "id1_g1", "id2_g1", "id3_g1", "id2_g2", "id1_g2", "id4_g3"])
        tds7 = Dataset([Union{Missing, String}["g1", "g1", "g2", "g2", "g3", "g3"],
                 Union{Missing, String}["val1", "val2", "val1", "val2", "val1", "val2"],
                 Union{Missing, Float64}[2.0, 2.1, missing, missing, missing, missing],
                 Union{Missing, Float64}[3.0, 0.5, missing, missing, missing, missing],
                 Union{Missing, Float64}[5.0, 1.0, missing, missing, missing, missing],
                 Union{Missing, Float64}[missing, missing, 1.0, 1.1, missing, missing],
                 Union{Missing, Float64}[missing, missing, 4.0, 1.3, missing, missing],
                 Union{Missing, Float64}[missing, missing, missing, missing, 6.0, 2.0]], ["g1", "_variables_", "(\"id1_g1\", 3)", "(\"id2_g1\", 1)", "(\"id3_g1\", 4)", "(\"id2_g2\", 2)", "(\"id1_g2\", 5)", "(\"id4_g3\", 6)"])
        tds8 = Dataset([Union{Missing, String}["g1", "g1", "g2", "g2", "g3", "g3"],
                 Union{Missing, String}["c1", "c1", "c1", "c1", "c1", "c1"],
                 Union{Missing, String}["val1", "val2", "val1", "val2", "val1", "val2"],
                 Union{Missing, Float64}[2.0, 2.1, missing, missing, missing, missing],
                 Union{Missing, Float64}[3.0, 0.5, missing, missing, missing, missing],
                 Union{Missing, Float64}[5.0, 1.0, missing, missing, missing, missing],
                 Union{Missing, Float64}[missing, missing, 1.0, 1.1, missing, missing],
                 Union{Missing, Float64}[missing, missing, 4.0, 1.3, missing, missing],
                 Union{Missing, Float64}[missing, missing, missing, missing, 6.0, 2.0]], ["g1", "c1", "_variables_", "3", "1", "4", "2", "5", "6"])
        tds9 = Dataset([Union{Missing, String}["g1", "g2", "g3"],
                 Union{Missing, String}["c1", "c1", "c1"],
                 Union{Missing, String}["val1", "val1", "val1"],
                 Union{Missing, Int64}[2, missing, missing],
                 Union{Missing, Int64}[3, missing, missing],
                 Union{Missing, Int64}[5, missing, missing],
                 Union{Missing, Int64}[missing, 1, missing],
                 Union{Missing, Int64}[missing, 4, missing],
                 Union{Missing, Int64}[missing, missing, 6]], ["g1", "c1", "_variables_", "(3, \"id1_g1\")", "(1, \"id2_g1\")", "(4, \"id3_g1\")", "(2, \"id2_g2\")", "(5, \"id1_g2\")", "(6, \"id4_g3\")"])
        @test ds2 == tds2
        @test ds3 == tds3
        @test ds4 == tds4
        @test ds5 == tds5
        @test ds6 == tds6
        @test ds7 == tds7
        @test ds8 == tds8
        @test ds9 == tds9
        @test_throws AssertionError transpose(ds, :val1, id = :g1)
        ds = Dataset(g = [1,1,2,2], x1=1:4, y=[454,65,65,65])
        setformat!(ds, 2=>isodd)
        t1 = transpose(groupby(ds, 1), :y, id = :x1)
        t1_t = Dataset("g" => [1,2], "_variables_" => ["y","y"], "true" => [454, 65], "false"=>[65,65])
        @test t1 == t1_t
        t2 = transpose(groupby(ds, 1), :y, id = :x1, mapformats = false)
        t2_t = Dataset("g" => [1,2], "_variables_" => ["y","y"], "1"=>[454, missing], "2"=>[65, missing], "3"=>[missing, 65], "4"=>[missing, 65])
        @test t2 == t2_t
        @test_throws AssertionError transpose(ds, :y, id = :x1, mapformats = true)
        t3 = transpose(ds, :y, id = :x1, mapformats = false)
        t3_t = Dataset("_variables_" => ["y"], "1"=>[454], "2"=>[65], "3"=>[65], "4"=>[65])
        @test t3 == t3_t
        setformat!(ds, 1=>isodd)
        t4 = transpose(ds, :y, id = 1:2)
        t4_t = Dataset([Union{Missing, String}["y"],
                 Union{Missing, Int64}[454],
                 Union{Missing, Int64}[65],
                 Union{Missing, Int64}[65],
                 Union{Missing, Int64}[65]], ["_variables_", "(true, true)", "(true, false)", "(false, true)", "(false, false)"])
        @test t4 == t4_t
        t5 = transpose(ds, :y, id = 1:2, mapformats = false)
        t5_t = Dataset([Union{Missing, String}["y"],
                 Union{Missing, Int64}[454],
                 Union{Missing, Int64}[65],
                 Union{Missing, Int64}[65],
                 Union{Missing, Int64}[65]], ["_variables_", "(1, 1)", "(1, 2)", "(2, 3)", "(2, 4)"])
        @test t5 == t5_t
        ds = Dataset(g1 = [1, 2, 3, 4], x = [1,2,3,4], g2 = [false, false, true, true])
        setformat!(ds, 1=>isodd)
        groupby!(ds, [:g2, :g1])
        dst = transpose(ds, :x, variable_name = nothing)
        dst_t = compare(ds, dst, on =[:g1=>:g1, :g2=>:g2, :x=>:_c1], mapformats = true)
        @test all(byrow(dst_t, all, :))

        ds = Dataset(x = [1,2,1,2,3], y = [missing, missing, missing, missing, missing])
        @test transpose(groupby(ds,1), :y) == Dataset(x = [1,2,3], _variables_=["y","y","y"], _c1=[missing, missing, missing], _c2=[missing, missing, missing])
        @test transpose(groupby(ds,1), :y, default = 0) == Dataset(x = [1,2,3], _variables_=["y","y","y"], _c1=[missing, missing, missing], _c2=[missing, missing, 0])
        @test transpose(gatherby(ds,1), :y, default = 0) == Dataset(x = [1,2,3], _variables_=["y","y","y"], _c1=[missing, missing, missing], _c2=[missing, missing, 0])


end


@testset "Outputs - Checking types" begin
    ds = Dataset(Fish = CategoricalArray{Union{String, Missing}}(["Bob", "Bob", "Batman", "Batman"]),
                   Key = CategoricalArray{Union{String, Missing}}(["Mass", "Color", "Mass", "Color"]),
                   Value = Union{String, Missing}["12 g", "Red", "18 g", "Grey"])
    levels!(ds[!, 1].val, ["XXX", "Bob", "Batman"])
    levels!(ds[!, 2].val, ["YYY", "Color", "Mass"])
#     Not sure if it is relevant, however, we are doing it here
    ds2 = transpose(groupby!(ds, :Fish, stable = true), [:Value], id = :Key)
    @test levels(ds[!, 1].val) == ["XXX", "Bob", "Batman"] # make sure we did not mess ds[!, 1] levels
    @test levels(ds[!, 2].val) == ["YYY", "Color", "Mass"] # make sure we did not mess ds[!, 2] levels
#     duplicates
    @test_throws AssertionError transpose(ungroup!(ds), [:Value], id = :Key)


    ds = Dataset(Fish = CategoricalArray{Union{String, Missing}}(["Bob", "Bob", "Batman", "Batman"]),
                   Key = CategoricalArray{Union{String, Missing}}(["Mass", "Color", "Mass", "Color"]),
                   Value = Union{String, Missing}["12 g", "Red", "18 g", "Grey"])
    levels!(ds[!, 1].val, ["XXX", "Bob", "Batman"])
    levels!(ds[!, 2].val, ["YYY", "Color", "Mass"])
    ds2 = transpose(groupby(ds, :Fish, stable = true), [:Value], id = :Key, renamecolid=x->string("_", uppercase(string(x)), "_"))
    ds4 = Dataset(Fish = Union{String, Missing}["Bob", "Batman"],
                _variables_ = String["Value", "Value"],
                _MASS_ = Union{String, Missing}["12 g", "18 g"],
                _COLOR_ = Union{String, Missing}["Red", "Grey"])
    @test ds2 == ds4
    # without categorical array
    ds = Dataset(Fish = ["Bob", "Bob", "Batman", "Batman"],
                   Key = ["Mass", "Color", "Mass", "Color"],
                   Value = ["12 g", "Red", "18 g", "Grey"])
    ds2 = transpose(groupby(ds, :Fish, stable = true), [:Value], id = :Key)
    ds4 = Dataset(Fish = ["Batman", "Bob"],
                    _variables_ = ["Value", "Value"],
                    Mass = ["18 g", "12 g"],
                    Color = ["Grey", "Red"]
                    )
    @test ds2 ≅ ds4
    @test eltype(ds2[!, :Fish]) <: Union{String, Missing}
    #Make sure transpose works with missing values at the start of the value column
    # allowmissing!(ds, :Value)
    ds[1, :Value] = missing
    ds2 = transpose(groupby(ds, :Fish, stable = true), [:Value], id =  :Key)
    #This changes the expected result
    # allowmissing!(ds4, :Mass)
    ds4[2, :Mass] = missing
    @test ds2 ≅ ds4


    # test missing value in grouping variable
    mds = Dataset(RowID = 4:-1:1, id=[missing, 1, 2, 3], a=1:4, b=1:4)
    @test select(transpose(groupby(transpose(groupby(mds, [:RowID, :id], stable = true), [:a,:b]), [:RowID, :id]), [:_c1], id = :_variables_), :RowID, :id, :a, :b) ≅ sort!(mds,1)
    @test select(transpose(groupby(transpose(groupby(mds, [:RowID, :id], stable = true), Not(1,2)),[:RowID, :id]), [:_c1], id = :_variables_), :RowID, :id, :a, :b) ≅ sort!(mds,1)

    # test more than one grouping column
    wide = Dataset(id = 1:12,
                     a  = repeat([1:3;], inner = [4]),
                     b  = repeat([1:4;], inner = [3]),
                     c  = randn(12),
                     d  = randn(12))
    w2 = wide[:, [1, 2, 4, 5]]
    InMemoryDatasets.rename!(w2, [:id, :a, :_C_, :_D_])
    long = transpose(groupby(wide, [:id, :a, :b], stable = true), [:c, :d])
    wide3 = transpose(groupby(long, [:id, :a, :b], stable = true), [:_c1], id = :_variables_)
    @test select(wide3, Not(:_variables_)) == wide
    ds = Dataset([repeat(1:2, inner=4), repeat('a':'d', outer=2), collect(1:8)],
                       [:id, :variable, :value])

    uds = transpose(groupby(ds, :id, stable = true), [:value], id = :variable)
    @test select(uds, Not(:_variables_)) == Dataset([Union{Int, Missing}[1, 2], Union{Int, Missing}[1, 5],
                                Union{Int, Missing}[2, 6], Union{Int, Missing}[3, 7],
                                Union{Int, Missing}[4, 8]], [:id, :a, :b, :c, :d])

    @test isa(uds[!, 1].val, Vector{Union{Missing,Int}})
    @test isa(uds[!,:a].val, Vector{Union{Int,Missing}})
    @test isa(uds[!,:b].val, Vector{Union{Int,Missing}})
    @test isa(uds[!,:c].val, Vector{Union{Int,Missing}})
    @test isa(uds[!,:d].val, Vector{Union{Int,Missing}})
    ds = Dataset([categorical(repeat(2:-1:1, inner=4)),
                           categorical(repeat('a':'d', outer=2)), categorical(1:8)],
                       [:id, :variable, :value])

    uds = transpose(groupby!(ds, :id, stable = true), [:value], id = :variable)
    @test isa(uds[!, 1].val, CategoricalArray{Union{Missing, Int64},1,UInt32})
    @test isa(uds[!, :a].val, Vector{Union{Missing, CategoricalValue{Int64, UInt32}}})
    @test isa(uds[!, :b].val, Vector{Union{Missing, CategoricalValue{Int64, UInt32}}})
    @test isa(uds[!, :c].val, Vector{Union{Missing, CategoricalValue{Int64, UInt32}}})
    @test isa(uds[!, :d].val, Vector{Union{Missing, CategoricalValue{Int64, UInt32}}})


    ds1 = Dataset(a=["x", "y"], b=rand(2), c=[1, 2], d=rand(Bool, 2))

    @test_throws MethodError transpose(ds1)
    @test_throws ArgumentError transpose(ds1, :bar)

    ds1_pd = transpose(ds1, 2:4, id = 1)
    @test size(ds1_pd, 1) == ncol(ds1) - 1
    @test size(ds1_pd, 2) == nrow(ds1) + 1
    @test names(ds1_pd) == ["_variables_", "x", "y"]
    @test names(transpose(ds1, 2:4, id = 1, variable_name = "foo")) == ["foo", "x", "y"]

end

@testset "passing Tuple as cols" begin
        ds = Dataset([Union{Missing, Int64}[1, 1, 1, 2, 2, 2],
                 Union{Missing, String}["foo", "bar", "monty", "foo", "bar", "monty"],
                 Union{Missing, String}["a", "b", "c", "d", "e", "f"],
                 Union{Missing, Int64}[1, 2, 3, 4, 5, 6]], [:g, :key, :foo, :bar])
        dst = transpose(groupby(ds, :g), (:foo, :bar), id = :key, variable_name = "_variables_")
        dst_t = Dataset([Union{Missing, Int64}[1, 2],
                 Union{Missing, String}["foo", "foo"],
                 Union{Missing, String}["bar", "bar"],
                 Union{Missing, String}["a", "d"],
                 Union{Missing, String}["b", "e"],
                 Union{Missing, String}["c", "f"],
                 Union{Missing, Int64}[1, 4],
                 Union{Missing, Int64}[2, 5],
                 Union{Missing, Int64}[3, 6]], ["g", "_variables_", "_variables__1", "foo", "bar", "monty", "foo_1", "bar_1", "monty_1"])
        @test dst == dst_t
        ds = Dataset(paddockId= [0, 0, 1, 1, 2, 2],
                                color= ["red", "blue", "red", "blue", "red", "blue"],
                                count= [3, 4, 3, 4, 3, 4],
                                weight= [0.2, 0.3, 0.2, 0.3, 0.2, 0.2])
        dst = transpose(groupby(ds, 1), (:count, :weight), id = :color, variable_name = :_variables_)
        dst_t = Dataset([Union{Missing, Int64}[0, 1, 2],
                 Union{Missing, String}["count", "count", "count"],
                 Union{Missing, String}["weight", "weight", "weight"],
                 Union{Missing, Int64}[3, 3, 3],
                 Union{Missing, Int64}[4, 4, 4],
                 Union{Missing, Float64}[0.2, 0.2, 0.2],
                 Union{Missing, Float64}[0.3, 0.3, 0.2]], ["paddockId", "_variables_", "_variables__1", "red", "blue", "red_1", "blue_1"])
        @test dst == dst_t
        ds = Dataset([Union{Missing, Int64}[1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
                 Union{Missing, Int64}[1, 1, 2, 5, 5, 5, 5, 2, 3, 3],
                 Union{Missing, Int64}[5, 5, 5, 5, 5, 5, 5, 5, 5, 5],
                 Union{Missing, Int64}[3, 3, 3, 3, 2, 2, 2, 2, 1, 1],
                 Union{Missing, Int64}[1, 1, 5, 5, missing, missing, missing, missing, missing, missing],
                 Union{Missing, Int64}[2, 2, 5, 5, missing, missing, missing, missing, missing, missing],
                 Union{Missing, Int64}[3, 3, 3, 3, missing, missing, missing, missing, missing, missing]], ["id", "a1_l1", "a2_l1", "a3_l1", "a1_l2", "a2_l2", "a3_l2"])
        ds_sum = combine(ds, 2:ncol(ds) => x->count(isequal(5),x)/IMD.n(x))
        dst = select!(transpose(ds_sum, (r"l1", r"l2")), r"_c1")
        dst_t = Dataset(_c1 = [.4, 1.0, 0], _c1_1 = [.5, .5, 0])
        @test dst == dst_t
end

@testset "flatten  column" begin
    ds_vec = Dataset(a = [1, 2], b = [[1, 2], [3, 4]])
    ds_tup = Dataset(a = [1, 2], b = [(1, 2), (3, 4)])
    ref = Dataset(a = [1, 1, 2, 2], b = [1, 2, 3, 4])
    @test flatten(ds_vec, :b) == flatten(ds_tup, :b) == ref
    @test flatten(ds_vec, "b") == flatten(ds_tup, "b") == ref
    @test flatten!(copy(ds_vec), :b) == flatten(ds_tup, :b) == ref
    @test flatten!(copy(ds_vec), "b") == flatten(ds_tup, "b") == ref
    ds_mixed_types = Dataset(a = [1, 2], b = [[1, 2], ["x", "y"]])
    ref_mixed_types = Dataset(a = [1, 1, 2, 2], b = [1, 2, "x", "y"])
    @test flatten(ds_mixed_types, :b) == ref_mixed_types
    @test flatten!(copy(ds_mixed_types), :b) == ref_mixed_types

    ds_three = Dataset(a = [1, 2, 3], b = [[1, 2], [10, 20], [100, 200, 300]])
    ref_three = Dataset(a = [1, 1, 2, 2, 3, 3, 3], b = [1, 2, 10, 20, 100, 200, 300])
    @test flatten(ds_three, :b) == ref_three
    @test flatten(ds_three, "b") == ref_three
    @test flatten!(copy(ds_three), :b) == ref_three
    @test flatten!(copy(ds_three), "b") == ref_three
    ds_gen = Dataset(a = [1, 2], b = [(i for i in 1:5), (i for i in 6:10)])
    ref_gen = Dataset(a = [fill(1, 5); fill(2, 5)], b = collect(1:10))
    @test flatten(ds_gen, :b) == ref_gen
    @test flatten(ds_gen, "b") == ref_gen
    @test flatten!(copy(ds_gen), :b) == ref_gen
    @test flatten!(copy(ds_gen), "b") == ref_gen
    ds_miss = Dataset(a = [1, 2], b = [Union{Missing, Int}[1, 2], Union{Missing, Int}[3, 4]])
    ref = Dataset(a = [1, 1, 2, 2], b = [1, 2, 3, 4])
    @test flatten(ds_miss, :b) == ref
    @test flatten(ds_miss, "b") == ref
    @test flatten!(copy(ds_miss), :b) == ref
    @test flatten!(copy(ds_miss), "b") == ref
    v1 = [[1, 2], [3, 4]]
    v2 = [[5, 6], [7, 8]]
    v = [v1, v2]
    ds_vec_vec = Dataset(a = [1, 2], b = v)
    ref_vec_vec = Dataset(a = [1, 1, 2, 2], b = [v1 ; v2])
    @test flatten(ds_vec_vec, :b) == ref_vec_vec
    @test flatten(ds_vec_vec, "b") == ref_vec_vec
    @test flatten!(copy(ds_vec_vec), :b) == ref_vec_vec
    @test flatten!(copy(ds_vec_vec), "b") == ref_vec_vec
    ds_cat = Dataset(a = [1, 2], b = [CategoricalArray([1, 2]), CategoricalArray([1, 2])])
    ds_flat_cat = flatten(ds_cat, :b)
    ref_cat = Dataset(a = [1, 1, 2, 2], b = [1, 2, 1, 2])
    @test ds_flat_cat == ref_cat
    @test ds_flat_cat.b.val isa CategoricalArray
    flatten!(ds_cat, :b)
    ref_cat = Dataset(a = [1, 1, 2, 2], b = [1, 2, 1, 2])
    @test ds_cat == ref_cat
    @test ds_cat.b.val isa CategoricalArray

    ds = Dataset(a = [1, 2], b = [[1, 2], [3, 4]], c = [[5, 6], [7, 8]])
    @test flatten(ds, []) == ds
    @test flatten!(copy(ds), []) == ds

    ref = Dataset(a = [1, 1, 2, 2], b = [1, 2, 3, 4], c = [5, 6, 7, 8])
    @test flatten(ds, [:b, :c]) == ref
    @test flatten(ds, [:c, :b]) == ref
    @test flatten(ds, ["b", "c"]) == ref
    @test flatten(ds, ["c", "b"]) == ref
    @test flatten(ds, 2:3) == ref
    @test flatten(ds, r"[bc]") == ref
    @test flatten(ds, Not(:a)) == ref
    @test flatten(ds, Between(:b, :c)) == ref

    @test flatten!(copy(ds), [:b, :c]) == ref
    @test flatten!(copy(ds), [:c, :b]) == ref
    @test flatten!(copy(ds), ["b", "c"]) == ref
    @test flatten!(copy(ds), ["c", "b"]) == ref
    @test flatten!(copy(ds), 2:3) == ref
    @test flatten!(copy(ds), r"[bc]") == ref
    @test flatten!(copy(ds), Not(:a)) == ref
    @test flatten!(copy(ds), Between(:b, :c)) == ref

    ds_allcols = Dataset(b = [[1, 2], [3, 4]], c = [[5, 6], [7, 8]])
    ref_allcols = Dataset(b = [1, 2, 3, 4], c = [5, 6, 7, 8])
    @test flatten(ds_allcols, :) == ref_allcols
    @test flatten!(copy(ds_allcols), :) == ref_allcols
    ds_bad = Dataset(a = [1, 2], b = [[1, 2], [3, 4]], c = [[5, 6], [7]])
    @test_throws ArgumentError flatten(ds_bad, [:b, :c])
    @test_throws ArgumentError flatten!(copy(ds_bad), [:b, :c])
    ds_vec = Dataset(a = [1, missing], b = [[1, missing], [3, 4]])
    ds_tup = Dataset(a = [1, missing], b = [(1, missing), (3, 4)])
    ref = Dataset(a = [1, 1, missing, missing], b = [1, missing, 3, 4])
    @test flatten(ds_vec, :b) == flatten(ds_tup, :b) == ref
    @test flatten(ds_vec, "b") == flatten(ds_tup, "b") == ref
    @test flatten!(copy(ds_vec), :b) == flatten(ds_tup, :b) == ref
    @test flatten!(copy(ds_vec), "b") == flatten(ds_tup, "b") == ref

    ds_cat = Dataset(a = [1, 2], b = [PooledArray([1, 2]), PooledArray([1, 2])])
    repeat!(ds_cat, 1000)
    ds_flat_cat = flatten(ds_cat, :b)
    ref_cat = Dataset(a = repeat([1, 1, 2, 2],1000), b = repeat([1, 2, 1, 2],1000))
    @test ds_flat_cat == ref_cat
    flatten!(ds_cat, :b)
    @test ds_cat == ref_cat

    ds_cat = Dataset(a = [1, 2], b = [CategoricalArray([1, 2]), CategoricalArray([1, 2])])
    repeat!(ds_cat, 1000)
    ds_flat_cat = flatten(ds_cat, :b)
    ref_cat = Dataset(a = repeat([1, 1, 2, 2],1000), b = repeat([1, 2, 1, 2],1000))
    @test ds_flat_cat == ref_cat
    flatten!(ds_cat, :b)
    @test ds_cat == ref_cat
end

@testset "transpose - views" begin
        pop = Dataset(country = ["c1","c1","c2","c2","c3","c3"],
                                sex = [1, 2, 1, 2, 1, 2],
                                pop_2000 = [100, 120, 150, 155, 170, 190],
                                pop_2010 = [110, 120, 155, 160, 178, 200],
                                pop_2020 = [115, 130, 161, 165, 180, 203])
        fmt(x) = x == 1 ? "male" : "female"
        setformat!(pop, :sex=>fmt)
        modify!(pop, [:country, :sex] => byrow(x->join(x))=>:c_s)
        pop_v1 = view(pop, :, 5:-1:1)
        pop_v2 = view(pop, [1,2,3,4], [1,2,3,6])

        @test transpose(pop_v2, :pop_2000) == Dataset(_variables_ = "pop_2000", _c1 = 100, _c2=120, _c3=150, _c4=155)
        @test transpose(pop_v2, :pop_2000, id = :c_s) == Dataset(_variables_ = "pop_2000", c11 = 100, c12=120, c21=150, c22=155)
        @test transpose(pop_v2, :pop_2000, id = [:country, :sex], renamecolid = x->join(x), mapformats = false) == Dataset(_variables_ = "pop_2000", c11 = 100, c12=120, c21=150, c22=155)
        @test transpose(copy(pop_v2), :pop_2000, id = :c_s) == Dataset(_variables_ = "pop_2000", c11 = 100, c12=120, c21=150, c22=155)


        poptm = Dataset([["c1", "c1", "c1", "c2", "c2", "c2", "c3", "c3", "c3"],
                ["2000", "2010", "2020", "2000", "2010", "2020", "2000", "2010", "2020"],
                Union{Missing, Int64}[100, 110, 115, 150, 155, 161, 170, 178, 180],
                Union{Missing, Int64}[120, 120, 130, 155, 160, 165, 190, 200, 203]],
                [:country,:year,:male,:female])

        @test transpose(gatherby(pop_v1, :country), [3,2,1], id = :sex, variable_name = "year", renamerowid = x->replace(x, "pop_"=>"")) == poptm
        @test transpose(gatherby(pop_v1, :country), [3,2,1], id = :sex, variable_name = "year", renamerowid = x->replace(x, "pop_"=>""), mapformats = false) == rename(poptm, ["male"=>"1", "female"=>"2"])
        @test transpose(groupby(pop_v1, :country), (1,2), id = :sex, renamecolid = (x,y)->x * "|" * y[1]) == Dataset([Union{Missing, String}["c1", "c2", "c3"], Union{Missing, Int64}[115, 161, 180], Union{Missing, Int64}[130, 165, 203], Union{Missing, Int64}[110, 155, 178], Union{Missing, Int64}[120, 160, 200]], ["country", "male|pop_2020", "female|pop_2020", "male|pop_2010", "female|pop_2010"])
end
