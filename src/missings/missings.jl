#Base
Base.parse(::T, ::Missing, kwargs...) where T = missing

# Dates.jl
Dates.Date(::Missing, kwargs...) = missing
Dates.DateTime(::Missing, kwargs...) = missing
Dates.year(::Missing) = missing
Dates.month(::Missing) = missing
Dates.day(::Missing) = missing
Dates.canonicalize(::Missing) = missing
Dates.yearmonthday(::Missing) = missing
Dates.yearmonth(::Missing) = missing
Dates.monthday(::Missing) = missing
Dates.week(::Missing) = missing
Dates.hour(::Missing) = missing
Dates.minute(::Missing) = missing
Dates.second(::Missing) = missing
Dates.millisecond(::Missing) = missing
Dates.dayofmonth(::Missing) = missing
Dates.microsecond(::Missing) = missing
Dates.nanosecond(::Missing) = missing
Dates.dayofweek(::Missing) = missing
Dates.isleapyear(::Missing) = missing
Dates.daysinmonth(::Missing) = missing
Dates.daysinyear(::Missing) = missing
Dates.dayofyear(::Missing) = missing
Dates.dayname(::Missing) = missing
Dates.dayabbr(::Missing) = missing
Dates.dayofweekofmonth(::Missing) = missing
Dates.daysofweekinmonth(::Missing) = missing
Dates.monthname(::Missing) = missing
Dates.monthabbr(::Missing) = missing
Dates.quarterofyear(::Missing) = missing
Dates.dayofquarter(::Missing) = missing
Dates.unix2datetime(::Missing) = missing
Dates.datetime2unix(::Missing) = missing
Dates.firstdayofweek(::Missing) = missing
Dates.lastdayofweek(::Missing) = missing
Dates.firstdayofmonth(::Missing) = missing
Dates.lastdayofmonth(::Missing) = missing
Dates.firstdayofyear(::Missing) = missing
Dates.lastdayofyear(::Missing) = missing
Dates.firstdayofquarter(::Missing) = missing
Dates.lastdayofquarter(::Missing) = missing
