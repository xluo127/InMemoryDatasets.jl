# Gallery

This gallery contains some random questions about data manipulation that we found on internet. The original questions are posted in different forums and are related to different packages. Whenever, we can remember the original source of a question we provide a link to it, otherwise, we just re-asked the question as we remember it. There is no particular theme about the questions, we just found them interesting since, a) they are not trivial, b) they can be done relatively easy in InMemoryDatasets, c) our solution is more efficient than what we found in the original source.

## General

* [Tally across columns with variable condition](https://stackoverflow.com/questions/70501316/tally-across-columns-with-variable-condition-in-r) : I am trying to tally across columns of a data frame with values that exceed a corresponding limit variable.

```julia
julia> ds
6×8 Dataset
 Row │ a          a_lim     b           b_lim     c         c_lim     d         d_lim    
     │ identity   identity  identity    identity  identity  identity  identity  identity
     │ Float64?   Float64?  Float64?    Float64?  Float64?  Int64?    Float64?  Float64?
─────┼───────────────────────────────────────────────────────────────────────────────────
   1 │  1.66077       0.75   0.709184      0.333  1.47438          1  2.02678       1.25
   2 │ -1.05298       0.75  -2.53609       0.333  2.01485          1  1.51587       1.25
   3 │ -0.499206      0.75   0.0130659     0.333  2.49006          1  1.70535       1.25
   4 │  2.47123       0.75  -0.587867      0.333  1.80345          1  2.51628       1.25
   5 │  2.45914       0.75   0.55786       0.333  0.569928         1  1.909         1.25
   6 │  1.14014       0.75   1.60398       0.333  1.58403          1  0.794765      1.25

julia> using Chain
julia> @chain ds begin
         compare(_[!, r"lim"], _[!, Not(r"lim")], on = 1:4 .=> 1:4), eq = isless)
         byrow(count)
       end
6-element Vector{Int32}:
 4
 2
 2
 3
 3
 3
```

## `map!` and `map`

* How to randomly change about 10% of data values to missing?

```julia
julia> ds = Dataset(rand(10, 3), :auto)
10×3 Dataset
 Row │ x1         x2         x3        
     │ identity   identity   identity  
     │ Float64?   Float64?   Float64?  
─────┼─────────────────────────────────
   1 │ 0.829492   0.266336   0.712512
   2 │ 0.206569   0.252967   0.133839
   3 │ 0.0773648  0.420897   0.363549
   4 │ 0.404912   0.495679   0.400661
   5 │ 0.412908   0.740628   0.785319
   6 │ 0.624809   0.971097   0.725747
   7 │ 0.19843    0.378382   0.0453478
   8 │ 0.851221   0.563592   0.450065
   9 │ 0.351243   0.0555308  0.142801
  10 │ 0.208414   0.739952   0.926834

julia> map!(ds, x->rand()<.1 ? missing : x, :)
10×3 Dataset
 Row │ x1               x2               x3        
     │ identity         identity         identity  
     │ Float64?         Float64?         Float64?  
─────┼─────────────────────────────────────────────
   1 │       0.829492         0.266336   0.712512
   2 │       0.206569         0.252967   0.133839
   3 │       0.0773648        0.420897   0.363549
   4 │       0.404912         0.495679   0.400661
   5 │ missing                0.740628   0.785319
   6 │       0.624809   missing          0.725747
   7 │       0.19843          0.378382   0.0453478
   8 │ missing                0.563592   0.450065
   9 │       0.351243         0.0555308  0.142801
  10 │       0.208414         0.739952   0.926834
```

## Row operations, `byrow`

* In each row, how to replace missing values in a column by the first non-missing in previous columns. (Assuming for the first column the direction of search is reversed and all columns has the same type)

```julia
julia> ds = Dataset(rand([1,2,3, missing], 10, 6), :auto)
10×6 Dataset
 Row │ x1        x2        x3        x4        x5        x6       
     │ identity  identity  identity  identity  identity  identity
     │ Int64?    Int64?    Int64?    Int64?    Int64?    Int64?   
─────┼────────────────────────────────────────────────────────────
   1 │        1         1   missing         2   missing   missing
   2 │        2         1         3         3         2         3
   3 │        2         1   missing         3         3   missing
   4 │        1   missing   missing         1         1         1
   5 │        2         2   missing         1         3         1
   6 │  missing   missing         2         1   missing         1
   7 │  missing         2         3   missing         1         2
   8 │        3         3   missing         1         1         1
   9 │        3         1         1         3         1   missing
  10 │  missing         1         3         1         1         3

julia> byrow(ds, fill!, :, with = byrow(ds, coalesce, :), rolling = true)
10×6 Dataset
 Row │ x1        x2        x3        x4        x5        x6       
     │ identity  identity  identity  identity  identity  identity
     │ Int64?    Int64?    Int64?    Int64?    Int64?    Int64?   
─────┼────────────────────────────────────────────────────────────
   1 │        1         1         1         2         2         2
   2 │        2         1         3         3         2         3
   3 │        2         1         1         3         3         3
   4 │        1         1         1         1         1         1
   5 │        2         2         2         1         3         1
   6 │        2         2         2         1         1         1
   7 │        2         2         3         3         1         2
   8 │        3         3         3         1         1         1
   9 │        3         1         1         3         1         1
  10 │        1         1         3         1         1         3
```

* [A use-case from practice](https://www.juliabloggers.com/news-features-in-dataframes-jl-1-3-part-1/) : We have a data frame that has 10,000 rows and columns, but this time we have 50% of missing values
randomly scattered in it. What we want to do is to fill missing values in each
row with row means of non-missing values.

```julia
julia> ds = Dataset(rand([1.0, missing], 10_000, 10_000), :auto) .* (1:10_000);

julia> byrow(ds, fill!, :, with = byrow(ds, mean, :));
```

* [How to determine whether two sets of variables have a shared value](https://stackoverflow.com/questions/70452064/how-to-determine-whether-two-sets-of-variables-have-a-shared-value-in-r) : I have a data that contains two sets of variables, and I want to compare whether the two sets have the same value. Here we provide a scalable solution where the columns for the first set  have "1" in their names, and the columns for the second set have "2" in their names.

```julia
julia> a1 = Dataset(z1=[1,missing,3,4,5],x1=string.(3:7),z2=[2,missing,4,5,6],x2=[3,5,4,7,5])
5×4 Dataset
 Row │ z1        x1        z2        x2       
     │ identity  identity  identity  identity
     │ Int64?    String?   Int64?    Int64?   
─────┼────────────────────────────────────────
   1 │        1  3                2         3
   2 │  missing  4          missing         5
   3 │        3  5                4         4
   4 │        4  6                5         7
   5 │        5  7                6         5

julia> # since in the original post there are some specifications for checking equality of values we define a customised equality function
julia> eq(x, y) = isequal(x, y)
julia> eq(x::String, y) = isequal(parse(Int,x), y)
julia> eq(x, y::String) = isequal(x,parse(Int, y))
julia> eq(x::String, y::String) = isequal(parse(Int, x),parse(Int, y))
julia> eq(::Missing, ::Missing) = false
julia> a1.result = reduce((x,y)-> x .|= byrow(a1, in, r"2", item = y, eq = eq), names(a1, r"1"), init = zeros(Bool, nrow(a1)))
5-element Vector{Bool}:
 1
 0
 0
 0
 1
```

## Filtering

* [Filtering based on conditions comparing one column to other columns](https://discourse.julialang.org/t/dataframe-filtering-based-on-conditions-comparing-one-column-to-other-columns/70802) : In the following example we like to filter rows where columns `:x1` and `:x2` are greater than `:x5`.

```julia
julia> ds = Dataset(rand(10, 5), :auto)
10×5 Dataset
 Row │ x1          x2         x3         x4         x5        
     │ identity    identity   identity   identity   identity  
     │ Float64?    Float64?   Float64?   Float64?   Float64?  
─────┼────────────────────────────────────────────────────────
   1 │ 0.00924202  0.780238   0.270591   0.340518   0.815554
   2 │ 0.0653996   0.427389   0.834984   0.142269   0.632195
   3 │ 0.930175    0.0556611  0.70946    0.424178   0.389117
   4 │ 0.368194    0.88762    0.145652   0.0967154  0.953927
   5 │ 0.616674    0.202607   0.0228603  0.347016   0.597645
   6 │ 0.293204    0.570458   0.440695   0.28341    0.948588
   7 │ 0.46431     0.519242   0.360305   0.243189   0.133591
   8 │ 0.663426    0.756596   0.46699    0.511906   0.0340278
   9 │ 0.681305    0.23287    0.35492    0.754141   0.134459
  10 │ 0.0739887   0.157783   0.697812   0.421743   0.229453

julia> filter(ds, 1:2, type = isless, with = :x5, rev = true)
3×5 Dataset
 Row │ x1        x2        x3        x4        x5        
     │ identity  identity  identity  identity  identity  
     │ Float64?  Float64?  Float64?  Float64?  Float64?  
─────┼───────────────────────────────────────────────────
   1 │ 0.46431   0.519242  0.360305  0.243189  0.133591
   2 │ 0.663426  0.756596  0.46699   0.511906  0.0340278
   3 │ 0.681305  0.23287   0.35492   0.754141  0.134459
```

## Grouping

* [How to remove rows based on next value in a sequence?](https://stackoverflow.com/questions/69762612/how-to-remove-rows-based-on-next-value-in-a-sequence-pandas) : I have a data set where it is grouped based on `:id` and in ascending order for `:date`. I want to remove a row if the row after it has the same `:outcome`.

```julia
julia> ds = Dataset(id = [1,1,1,1,1,2,2,2,3,3,3],
                    date = Date.(["2019-03-05", "2019-03-12", "2019-04-10",
                            "2019-04-29", "2019-05-10", "2019-03-20",
                            "2019-04-22", "2019-05-04", "2019-11-01",
                            "2019-11-10", "2019-12-12"]),
                    outcome = [false, false, false, true, false, false,
                               true, false, true, true, true])
11×3 Dataset
 Row │ id        date        outcome  
     │ identity  identity    identity
     │ Int64?    Date?       Bool?    
─────┼────────────────────────────────
   1 │        1  2019-03-05     false
   2 │        1  2019-03-12     false
   3 │        1  2019-04-10     false
   4 │        1  2019-04-29      true
   5 │        1  2019-05-10     false
   6 │        2  2019-03-20     false
   7 │        2  2019-04-22      true
   8 │        2  2019-05-04     false
   9 │        3  2019-11-01      true
  10 │        3  2019-11-10      true
  11 │        3  2019-12-12      true

julia> combine(gatherby(ds, [1, 3], isgathered = true),
                        (:) => last,
                        dropgroupcols = true)
7×3 Dataset
 Row │ id_last   date_last   outcome_last
     │ identity  identity    identity     
     │ Int64?    Date?       Bool?        
─────┼────────────────────────────────────
   1 │        1  2019-04-10         false
   2 │        1  2019-04-29          true
   3 │        1  2019-05-10         false
   4 │        2  2019-03-20         false
   5 │        2  2019-04-22          true
   6 │        2  2019-05-04         false
   7 │        3  2019-12-12          true
```
## Joins

* [Counting the number of instances between dates](https://stackoverflow.com/questions/69994244/counting-the-number-of-instances-between-dates) : What I want to do is simply count the number of employees that each store has on any given date in the `store` data set

```julia
julia> store = Dataset([Date.(["2019-10-01", "2019-10-02", "2019-10-03", "2019-10-04",
                         "2019-10-05", "2019-10-01", "2019-10-02", "2019-10-03",
                         "2019-10-04", "2019-10-05"]),
                         ["A", "A", "A", "A", "A", "B", "B", "B", "B", "B"]],
                         ["date", "store"])
julia> roster = Dataset([["A", "A", "A", "A", "B", "B", "B", "B"],
                         [1, 2, 3, 4, 5, 6, 7, 8],
                         [Date("2019-09-30"), Date("2019-10-02"), Date("2019-10-03"), Date("2019-10-04"),
                         Date("2019-09-30"), Date("2019-10-02"), Date("2019-10-03"), Date("2019-10-04")],
                         [Date("2019-10-04"), Date("2019-10-04"), Date("2019-10-05"), Date("2019-10-06"),
                         Date("2019-10-04"), Date("2019-10-04"), Date("2019-10-05"), Date("2019-10-06")]],
                         ["store", "employee_ID", "start_date", "end_date"])
julia> using Chain
julia> @chain store begin
          innerjoin(roster, on = [:store => :store, :date => (:start_date, :end_date)])
          groupby([:store, :date])
          combine(:employee_ID => length)
       end
10×3 Dataset
 Row │ store     date        employee_ID_length
     │ identity  identity    identity           
     │ String?   Date?       Int64?             
─────┼──────────────────────────────────────────
   1 │ A         2019-10-01                   1
   2 │ A         2019-10-02                   2
   3 │ A         2019-10-03                   3
   4 │ A         2019-10-04                   4
   5 │ A         2019-10-05                   2
   6 │ B         2019-10-01                   1
   7 │ B         2019-10-02                   2
   8 │ B         2019-10-03                   3
   9 │ B         2019-10-04                   4
  10 │ B         2019-10-05                   2
```
## Reshape

* [How to transpose or pivote a table? Selecting specific columns](https://stackoverflow.com/questions/70228385/how-to-transpose-or-pivote-a-table-selecting-specific-columns) : I need to pivot or transpose my data, keeping the Country Code, the years, and the indicators names as columns

```julia
julia> ds = Dataset("Country_Code"=>["FR","FR","FR","USA","USA","USA","BR","BR","BR"],
                    "Indicator_Name"=>["GPD","Pop","birth","GPD","Pop","birth","GPD","Pop","birth"],
                    "2005"=>[14,34,56, 25, 67, 68, 55, 8,99],
                    "2006"=>[23, 34, 34, 43,34,34, 65, 34,45])
9×4 Dataset
 Row │ Country_Code  Indicator_Name  2005      2006     
     │ identity      identity        identity  identity
     │ String?       String?         Int64?    Int64?   
─────┼──────────────────────────────────────────────────
   1 │ FR            GPD                   14        23
   2 │ FR            Pop                   34        34
   3 │ FR            birth                 56        34
   4 │ USA           GPD                   25        43
   5 │ USA           Pop                   67        34
   6 │ USA           birth                 68        34
   7 │ BR            GPD                   55        65
   8 │ BR            Pop                    8        34
   9 │ BR            birth                 99        45

julia> transpose(gatherby(ds, 1), 3:4, id = r"Name")
6×5 Dataset
 Row │ Country_Code  _variables_  GPD       Pop       birth    
     │ identity      identity     identity  identity  identity
     │ String?       String?      Int64?    Int64?    Int64?   
─────┼─────────────────────────────────────────────────────────
   1 │ FR            2005               14        34        56
   2 │ FR            2006               23        34        34
   3 │ USA           2005               25        67        68
   4 │ USA           2006               43        34        34
   5 │ BR            2005               55         8        99
   6 │ BR            2006               65        34        45
```

## `for loops`

* [map select rows to a new column](https://stackoverflow.com/questions/69920121/map-select-rows-to-a-new-column) :  I want to use rows with names Becks, Campbell, Crows as a separate column to name the entries below them.

```julia
julia> using Chain
julia> ds = Dataset( [["Becks", "307NRR", "321NRR", "342NRR", "Campbell", "329NRR", "347NRR", "Crows", "C3001R"],
                     [missing, "R", "R", "R", missing, "R", "R", missing, "R"],
                     [missing, "CM,SG", "CM,SG", "CM,SG", missing, "None", "None", missing, "None"],
                     [missing, 3.0, 3.2, 3.4, missing, 3.2, 3.4, missing, 3.0]], :auto)
9×4 Dataset
 Row │ x1        x2        x3        x4        
     │ identity  identity  identity  identity  
     │ String?   String?   String?   Float64?  
─────┼─────────────────────────────────────────
   1 │ Becks     missing   missing   missing   
   2 │ 307NRR    R         CM,SG           3.0
   3 │ 321NRR    R         CM,SG           3.2
   4 │ 342NRR    R         CM,SG           3.4
   5 │ Campbell  missing   missing   missing   
   6 │ 329NRR    R         None            3.2
   7 │ 347NRR    R         None            3.4
   8 │ Crows     missing   missing   missing   
   9 │ C3001R    R         None            3.0

julia> function replace_with_prev(x,y)
           res = similar(x, length(x))
           for i in 1:length(x)
               if !ismissing(y[i])
                   res[i] = res[i-1]
               else
                   res[i] = x[i]
               end
           end
           res
       end
f1 (generic function with 2 methods)
julia> @chain ds begin
         modify!((1,2)=>replace_with_prev=>:name) # find previous name
         dropmissing!(2) # drop unwanted rows
         select!(:name, :) # rearrange columns
      end
6×5 Dataset
 Row │ name      x1        x2        x3        x4       
     │ identity  identity  identity  identity  identity
     │ String?   String?   String?   String?   Float64?
─────┼──────────────────────────────────────────────────
   1 │ Becks     307NRR    R         CM,SG          3.0
   2 │ Becks     321NRR    R         CM,SG          3.2
   3 │ Becks     342NRR    R         CM,SG          3.4
   4 │ Campbell  329NRR    R         None           3.2
   5 │ Campbell  347NRR    R         None           3.4
   6 │ Crows     C3001R    R         None           3.0
```
