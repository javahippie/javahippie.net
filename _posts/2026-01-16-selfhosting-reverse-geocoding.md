---
layout: post

title: "Self Hosting Reverse Geocoding"

date: 2026-01-16 04:00:00 +0200

author: Tim Zöller

categories: database postgis
---

Disclaimer: The dataset used in this blog post is only licensed for non-commercial use. If you need to do reverse geocoding
for a commercial use case, this solution will not work for you.

I'm currently working on a [small hobby project](https://feditrack.javahippie.net/timeline) for visualizing data from fitness trackers. As this should work globally, I am
using the public OSM servers. Hosting my own tileserver would be excessive overengineering, it required 1TB of disk space 
and minimum 64GB of RAM. My request rates are compatible with the terms of conditions of the public servers, anyway.

While rendering works well, I wanted to add the name and country of the starting location to the uploaded activities to
enable users to search for them. If they wanted to revisit a hike they did while on vacation in Italy, they could enter
"Milano" or simply "Italy" into the search field and filter accordingly. 

## Option 1: Use an API
There are many public API for reverse geocoding, e.g. the [Nominatim API](https://nominatim.org/release-docs/latest/api/Overview/). Simply using
this API would have been the easiest way, but the software supports batch imports of activities, I imported roughly 850 activities at once
from my Strava export. Nominatims [usage policy](https://operations.osmfoundation.org/policies/nominatim/) asks users to limit themselves
to 1 request per second at most. This would leave me with paid alternatives, or an internal queue with a rate limiter which processes
these lookups asynchronously. I decided against this, because I don't want too many external dependencies in my application,
and an asynchronous, rate limited lookup would have increased the complexity of the architecture.

## Option 2: Using the Geonames dataset
[Geonames](https://www.geonames.org/) is a popular dataset which contains geographical data. Unfortunately for every city in the 
dataset there is only one location stored in the data, which resembles the center of the city. In urban areas with many neighbouring
cities, this would certainly lead to overlaps. I am living in Mainz, and if I started my workout on the banks of the Rhine, the closest 
city center might be Wiesbaden, which is located on the opposite side of the river. For a single activity upload this would have been
okayish, because I could have provided two or three suggestions to the user. But this would have caused more work for the users and
would not have worked for batch updates.

## Option 3: Using the GADM dataset
After some further research I found the [GADM data](https://gadm.org/data.html). The aim of the project is to map the administrative 
data of all countries at all levels. [The license](https://gadm.org/license.html) grants usage for scientific and other non-commercial
use cases, which fits my project. Commercial licensing of the data is not possible. In contrast to the Geonames dataset, the GADM data
provides the shapes of all countries, states, municipalities, cities, so with PostGIS (which the software already uses) it is possible
to check if coordinates of a location are in the exact boundaries of such an administrative area. If I started my workout on the banks
of the Rhine now, it would really return "Mainz", even to the middle of the river. This is the option I implemented

## Gathering and importing the data into PostGIS
I never worked with geographical data before, but I was pleasantly surprised about the quality of the tooling. The first 
step was to download the whole GADM data as a Zip file from https://gadm.org/download_world.html. The Zip file has a size 1.4GB,
it contains a database in the GeoPackage format which has ~2.8GB uncompressed.

To import the data into a running PostGIS database I used the `ogr2ogr` Tool provided by [GDAL](https://gdal.org/en/stable/programs/ogr2ogr.html).

```shell
ogr2ogr -nln public.gadm_410 \
        -lco GEOMETRY_NAME=geom \
        -lco FID=fid \
        -f PostgreSQL PG:"host=localhost port=5432 dbname=testdb user=test password=test" \
        -progress  \
        gadm_410.gpkg      
```

The tool ships with a PostgreSQL driver which creates a table and imports the data into a Postgres database with the PostGis extension. 
We specify that the table should be called `gadm_410` in the `public` schema. The column containing the geo data is named `geom`, the `fid` from
the GeoPackage database should be mapped to a column named `fid`. Then we specify the connection details for our Postgres instance, and add a 
flag to make the tool print the progress while it is importing. The last parameter is the GeoPackage database itself.

Depending on the hardware the import takes some time. While running the import on my server for the production app my disk space ran out,
so be aware that this process takes quite some disk space while the tool unpacks and imports the data.

## Doing reverse lookups in SQL
The database is now populated with all the data, the DDL for the table created by ogr2ogr looks like this:

```sql
create table gadm_410
(
    fid        serial
        primary key,
    uid        bigint,
    gid_0      varchar(10),
    name_0     varchar(32),
    varname_0  varchar(29),
    gid_1      varchar(10),
    name_1     varchar(34),
    varname_1  varchar(82),
    nl_name_1  varchar(87),
    iso_1      varchar(10),
    hasc_1     varchar(10),
    cc_1       varchar(10),
    type_1     varchar(32),
    engtype_1  varchar(32),
    validfr_1  varchar(15),
    gid_2      varchar(12),
    name_2     varchar(34),
    varname_2  varchar(39),
    nl_name_2  varchar(75),
    hasc_2     varchar(15),
    cc_2       varchar(12),
    type_2     varchar(34),
    engtype_2  varchar(32),
    validfr_2  varchar(15),
    gid_3      varchar(15),
    name_3     varchar(38),
    varname_3  varchar(44),
    nl_name_3  varchar(56),
    hasc_3     varchar(27),
    cc_3       varchar(10),
    type_3     varchar(32),
    engtype_3  varchar(32),
    validfr_3  varchar(10),
    gid_4      varchar(18),
    name_4     varchar(34),
    varname_4  varchar(35),
    cc_4       varchar(12),
    type_4     varchar(29),
    engtype_4  varchar(29),
    validfr_4  varchar(10),
    gid_5      varchar(19),
    name_5     varchar(34),
    cc_5       varchar(10),
    type_5     varchar(22),
    engtype_5  varchar(10),
    governedby varchar(17),
    sovereign  varchar(32),
    disputedby varchar(32),
    region     varchar(32),
    varregion  varchar(48),
    country    varchar(32),
    continent  varchar(13),
    subcont    varchar(10),
    geom       geometry(MultiPolygon, 4326)
);

create index geodata_pkey_geom_geom_idx
    on gadm_410 using gist (geom);

```

The columns with a numbered postfix map to the different levels. `name_0` is the highest area, the country, e.g. "Germany". 
`name_1` is a state for most countries, so for Mainz "Rhineland Palatinate" or "Rheinland Pfalz", and so on. The city name 
is located in `name_4` for most entries, but there are also entries without a city name. A workout I did during my vacation was 
started on the beach of the island "Texel" in the Netherlands, and there is no city connected to it, `name_4` is empty. 

For my application I want a formatted string, e.g. "Mainz, Germany" or "Texel, Netherlands". To do this, we select all existing
names via SQL which match the coordinates we are looking for. This example shows a place on the Rhine in Mainz:

```sql
SELECT fid, name_0, name_1, name_2, name_3, name_4, name_5
FROM gadm_410
WHERE ST_Intersects(ST_SetSRID(ST_Point(8.269759, 50.009428), 4326), geom);
```

with the result

| fid | name\_0 | name\_1 | name\_2 | name\_3 | name\_4 | name\_5 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 100041 | Germany | Rheinland-Pfalz | Mainz | Mainz | Mainz |  |

The cities name "Mainz" appears three times, because as a "Kreisfreie Stadt" it is its own district and its own
"Verbandsgemeinde" (municipality).


This example shows a place on Texel: 

```sql
SELECT fid, name_0, name_1, name_2, name_3, name_4, name_5
FROM gadm_410
WHERE ST_Intersects(ST_SetSRID(ST_Point(4.869232, 53.155858), 4326), geom);
```

with the result

| fid | name\_0 | name\_1 | name\_2 | name\_3 | name\_4 | name\_5 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 215668 | Netherlands | Noord-Holland | Texel |  |  |  |

Due to the index on the `geom` column, a lookup takes 393 ms on my 2020 M1 Macbook Pro on a cold database.

## I didn't read this, I want a complete script to run this and try it out!
```shell
docker run --name my-postgis -e POSTGRES_USER=test -e POSTGRES_PASSWORD=test -e POSTGRES_DB=testdb -p 5432:5432 -d postgis/postgis
wget https://geodata.ucdavis.edu/gadm/gadm4.1/gadm_410-gpkg.zip
unzip gadm_410-gpkg.zip
ogr2ogr -nln public.gadm_410 \
        -lco GEOMETRY_NAME=geom \
        -lco FID=fid \
        -skipfailures \
        -f PostgreSQL PG:"host=localhost port=5432 dbname=testdb user=test password=test" \
        -progress \
        gadm_410.gpkg
```