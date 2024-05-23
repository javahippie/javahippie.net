---
layout: post

title: "Rock Stars are male and old - Fun with data"

date: 2024-03-23 21:00:00 +0200

author: Tim Zöller

categories: data

---

This week I read [a (German) article](https://www.visions.de/features/kolumnen-und-rubriken/rage-against-the-patriarchy/rage-against-the-patriarchy-altersdiskriminierung/) about female rock musicians age discrimination.
It made me wonder, how the lineup for the 2024 edition of the German "Rock Am Ring" festival compares.

The repository with all the data and scripts mentioned [can be found here](https://github.com/javahippie/rar-bands/tree/main).

## Collecting the data
The first and most important step was also the most boring one: Collecting the data. Next to the name of the band, 
founding year and if they are a headliner or sub-headliner. The founding year does not carry that much significance,
as the lineup also contains some super groups or solo acts of people who are well known for their older bands. Kerry King,
known as the guitarist for Slayer, started his solo project last year, but nobody would call him a young and upcoming artist.

I also tried to identify the "main person". This is usually the singer, but I would argue that for "Kerry King" the main 
person is... well... Kerry King on the guitar and not their singer. From 66 bands in total, 9 have "main people" who are 
not male.

The most tricky part was collecting the year of 
birth for the bands main person. Bigger acts tend to have their own Wikipedia page with a birthdate, but the smaller
the band and the younger the members become, the harder it is to find this information. This might be even worse for the 
question I am trying to answer: How is the age distribution? If the birthyear is missing, it might be missing especially
for younger, smaller acts. In the end, I managed to find the birthyear of all "main persons" but 7. If any of the readers
might know about the birth date of the following people, I'd be really grateful:

* Oliver Meister (Betontod)
* Josh Doty (Cemetery Sun)
* James Joseph (James And The Cold Gun)
* Simon Klemp (Schimmerling)
* Timo Warkus (Team Scheisse)
* Delila Paz (The Last Internationale)
* Jordan O'Leary (The Scratch)

For two of the birth years I needed to estimate. I assumed that Ashrita Kumar (Pinkshift) started her Bachelors Degree
at 18, and Alex Taylor (Malevolence) stated in an interview, that he wrote the songs for the bands debut album when 
he was 18 or 19. 

![View of the Excel header, containng Band name headliner status founding year, age of the band, also the main person, their birth year, age and gender](/assets/20240323/table_header.png)

## Loading the data
I entered all the data into an Excel list, because Excel is a really convenient tool for this. To aggregate or visualize
the data, I needed a better tool, preferrably SQL-based. As I saw DuckDB mentioned online a lot in the last months (thanks, Michael!),
I was happy to have a reason to try it out. In the CLI, I installed and loaded the extension to access Excel files and
created a new Table from the file:

```sql
INSTALL spatial;
LOAD spatial;
CREATE TABLE bands AS SELECT * FROM ST_Read('RaR Bands.xlsx');
```

From this starting point, I started to explore the data:

```
select median(main_person_age) from bands;
┌─────────────────────────┐
│ median(main_person_age) │
│         double          │
├─────────────────────────┤
│                    42.0 │
└─────────────────────────┘

select median(main_person_age) from bands where main_person_gender <> 'male';
┌─────────────────────────┐
│ median(main_person_age) │
│         double          │
├─────────────────────────┤
│                    27.0 │
└─────────────────────────┘

select median(main_person_age) from bands where headliner = 'true';
┌─────────────────────────┐
│ median(main_person_age) │
│         double          │
├─────────────────────────┤
│                    53.0 │
└─────────────────────────┘
```

No surprises here: The median age of the main person is 42, but only 27 for non-male ones. The median age of the 
headlining-acts main-people is even 53. Rock Music, the rebellious sound of the youth!

## Visualizing the data
In addition to seeing the numbers, I wanted to visualize the age distribution. My tool of choice for this is R, because
a) I read a book on it once and b) my wife is a data scientist, and she can help me with R if I don't know what to do. 
Luckily, there is a DuckDB package for R, and it works quite well. Data wrangling in R always felt a little weird to me,
although I really liked the Tidyverse. Having the ability to filter with SQL however fits my experience as a software
developer much better. I managed to create the following script, which loads the Excel sheet into DuckDB, queries the
DB for two datasets and plots them with ggplot2:

```R
library("DBI")
library("ggplot2")
library("duckdb")
con <- dbConnect(duckdb::duckdb(), ":memory:")

dbExecute(con, "INSTALL spatial")
dbExecute(con, "LOAD spatial")
dbExecute(con, "CREATE TABLE bands AS SELECT * FROM ST_Read('RaR Bands.xlsx')")
bands <- dbGetQuery(con, "SELECT * FROM bands")

ggplot(bands, aes(x=main_person_age, fill=main_person_gender))  + 
  geom_histogram(alpha = 0.5)
```

The first three lines of the script load the packages we need. `DBI` is a database interface, `ggplot2` is the library
we will use for plotting, and `duckdb` is, you might have guessed it, for DuckDB. We start a DuckDB in-memory instance
with `dbConnect(duckdb::duckdb(), ":memory:")`. On this connection, we can then operate, install and load the `spatial`
extension and create a table from the Excel sheet, like we saw earlier. We select the whole data into the vector `bands`.
(Yes, loading the data directly into a dataframe would have been easier, but please let me use my new, shiny, duck shaped tool).

After loading the data, we want to plot it: We create a new plot from `bands`, put `main_person_age` on the x-axis and
fill the data according to the value of `main_person_gender`. We would like to plot a histogram to see the distribution.
The result:

![img.png](/assets/20240323/plot.png)

## Conclusion
The data is really not that large or interesting, but for this year's RaR edition we can see, that the prejudice exists.
Male artists are not only more dominant, they are also older - and if we conclude that the headliners are the more 
successful and admired bands, they are even older. Obviously this is only looking at one special event and how the
organizers selected the acts for the lineup, but I thought this little experiment to be interesting nevertheless.

