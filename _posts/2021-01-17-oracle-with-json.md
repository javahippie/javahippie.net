---
layout: post
title:  "Efficient JSON with Oracle Database"
date:   2021-01-17 10:00:00 +0200
author: Tim Zöller
categories: sql database oracle
---

While working with a customer, a usecase came up that was hard to implement with a relational database (due to NDA, I cannot share the usecase itself). It was necessary to store some information for every row in the Oracle database, but although the structure of the data was similar, it contained a lot of special cases and different hierarchies. It would have been possible, with a clever table structure und a bit of denormalization. In fact, we did a PoC with a relational model, but it soon turned out that reads were slow and the queries to filter by this data grew more and more complex. There were good and productive discussions about the best approaches, and at some point, somebody said "This would be a good usecase for a document DB, wouldn't it?". Unfortunately, installing infrastructure for this was out of the picture, as the customer did not have experience with this technology and we were not keen on maintaining even more infrastructure, but we agreed on creating another PoC with the whole hierarchy being stored as a JSON in Oracle DB. The PoC was successful and the solution is productive and performing well.

All the informtion in this post is compiled from the comprehensive [JSON Developer's Guide](https://docs.oracle.com/en/database/oracle/oracle-database/19/adjsn/json-in-oracle-database.html#GUID-A8A58B49-13A5-4F42-8EA0-508951DAE0BB) for Oracle 19c. As Oracle added a lot of funtionality to its JSON features in the latest versions, the approaches described here may not be working on other Oracle Database versions.

I decided to write this up as a lessons-learned kind of post, because we ran into some issues which are documented, but might not be easy to find. You do not need deep Oracle knowledge to understand the article, knowing basic SQL is sufficient. Here is what I learned:

## Creating a JSON column in Oracle
### Which data type to choose?
JSON objects are strings, and are treated like this in an Oracle database. If we want to include a column with JSON data into a table, there are [several data types](https://docs.oracle.com/en/database/oracle/oracle-database/19/adjsn/overview-of-storage-and-management-of-JSON-data.html#GUID-26AB85D2-3277-451B-BFAA-9DD45355FCC7) we can choose from:

* VARCHAR2(4000) / VARCHAR2(32767)
* CLOB
* BLOB

As `VARCHAR2` columns have limits, and JSON data we'd like to store is very dynamic, I'd rule out `VARCHAR2`, leaving `CLOB` (Character Large OBject) and `BLOB` (Binary Large OBject). Oracle recommends CLOB with the following explanation:

> This is particularly relevant if the database character set is the Oracle-recommended value of AL32UTF8. In AL32UTF8 databases CLOB instances are stored using the UCS2 character set, which means that each character requires two bytes. This doubles the storage needed for a document if most of its content consists of characters that are represented using a single byte in character set AL32UTF8.
> 
> Even in cases where the database character set is not AL32UTF8, choosing BLOB over CLOB storage has the advantage that it avoids the need for character-set conversion when storing the JSON document 

Additionally, Oracle recommends storing the column as `SECUREFILE`, which, in contrast to the default `BASICFILE`, enables you to activate encryption and compression.

To summarize: If you chose `CLOB` for your JSON column type, you'd (probably) double the storage needed, you'd add an unnecessary character-set conversion to your operations, while having zero benefits (except that `CLOB` fields are easier to handle from SQLPlus). 

### Making sure that the column only contains JSON
As we will access the documents in our table with functions that expect the JSON content to be valid, it is a good idea to add a constraint that checks this content on every insert. This also makes sure that our data is consistent, and we don't save invalid JSON by accident. Oracle created the `IS JSON` constraint, which does exactly that. If you choose not to add this index, Oracle will not allow you to use the simple dot-notation to access the documents content (we will have a look at this later). 

The constraint also allows you to decide if your constraint should enforce strict or lax JSON rules, whith lax being the default. Listing up the differences in detail would result in me just copying from [the reference](https://docs.oracle.com/en/database/oracle/oracle-database/19/adjsn/conditions-is-json-and-is-not-json.html#GUID-8F897ED9-791B-4F53-AFAE-690DE38111D1) to this post, but the important differencee to most users is that the lax syntax allows JSON keywords to be single quoted, while the strict syntax does not.

### DDL for a table with a JSON column
With all the above mentioned recommendations from the documentation we can create a simple table containing a JSON column. I have found a resource with [Noble Prize winners as a JSON document](http://api.nobelprize.org/v1/prize.json) online, so we will store these to have some data as an example:

```sql
CREATE SEQUENCE seq_nobel_prize
  START WITH 1 
  INCREMENT BY 1;

CREATE TABLE nobel_prize (
	id       NUMBER(19) DEFAULT seq_nobel_prize.nextval NOT NULL,
	document BLOB                                       NOT NULL,
	
	CONSTRAINT pk_nobel_prize   PRIMARY KEY (id),
	CONSTRAINT document_is_json CHECK       (document IS JSON (STRICT))
) LOB (document) STORE AS SECUREFILE;
```
As explained above, we chose to store the JSON in a `BLOB` field as `SECUREFILE` to optimize storage and access. We also apply an `IS JSON` check to the column, which checks for strict syntax. We also added a primary key column to the table which is filled by `seq_nobel_prizes`.


## Inserting and test data
This step is not specific to storing JSON data, it works just like inserting text into a database. As the data from the web resource is one "large" JSON document, I split it up with some Javascript and transformed it into file with SQL insert statements, which you can find [here](/assets/20210116/nobel_prize.sql). An example for a single row looks like this:

```sql
INSERT INTO nobel_prize (document) values ('{"year":"2020","category":"chemistry","laureates":[{"id":"991","firstname":"Emmanuelle","surname":"Charpentier","motivation":"\"for the development of a method for genome editing\"","share":"2"},{"id":"992","firstname":"Jennifer A.","surname":"Doudna","motivation":"\"for the development of a method for genome editing\"","share":"2"}]}');
```

The document for every entry will look like this:

```json
{"year":"2020",
 "category":"chemistry",
 "laureates":[
 	{"id":"991",
 	 "firstname":
 	 "Emmanuelle",
 	 "surname":"Charpentier",
 	 "motivation":"\"for the development of a method for genome editing\"",
 	 "share":"2"},
 	{"id":"992",
 	 "firstname":"Jennifer A.",
 	 "surname":"Doudna",
 	 "motivation":"\"for the development of a method for genome editing\"",
 	 "share":"2"}]}
```


After executing the whole script, the table should contain 652 rows.

## Exploring data
In the following paragraphs we will concentrate on the dot-notation and the json_table. There are [many more different ways](https://docs.oracle.com/en/database/oracle/oracle-database/19/adjsn/query-json-data.html#GUID-119E5069-77F2-45DC-B6F0-A1B312945590) and functions to access JSON, but I found these two to be the most common.

### The dot-notation
#### Reading data
As described above, Oracle allows us to use the [dot-notation](https://docs.oracle.com/en/database/oracle/oracle-database/19/adjsn/simple-dot-notation-access-to-json-data.html#GUID-7249417B-A337-4854-8040-192D5CEFD576) to access JSON values, if we applied an `IS JSON` check on a column. The notation works as if we accessed the fields with JavaScript directly. If we wanted the ID, the year and the category from the table, we'd build a query like this:

```sql
SELECT id, 
       np.document."year", //year is a reserved keyword, so we quote it
       np.document.category
FROM nobel_prize np
FETCH FIRST 5 ROWS ONLY;
```

The result:

| id   | year | category  |
| ---- |------| -----|
| 1588 | 2003 | 	medicine | 
| 1589 | 2002	 | chemistry | 
| 1590 | 2002	 | economics | 
| 1591 | 2002	 | literature | 
| 1592 | 2002	 | peace | 

This looks pretty straightforward for single values, like `year` and `category`. How does it work with array values, e.g. if we'd like to get the surnames of all laureates? We can do this with a query that uses [JSON path expressions](https://docs.oracle.com/en/database/oracle/oracle-database/19/adjsn/json-path-expressions.html#GUID-2DC05D71-3D62-4A14-855F-76E054032494):

```sql
SELECT id, 
       np.document."year",
       np.document.category,
       np.document.laureates[*].surname
FROM nobel_prize np
FETCH FIRST 5 ROWS ONLY;
```

The result:

| id   | year | category  | laureates |
| ---- |------|-----|------|
| 1588	| 2003	| medicine	| ["Lauterbur","Mansfield"]|
| 1589	| 2002	| chemistry	| ["Fenn","Tanaka","Wüthrich"]|
| 1590	| 2002	| economics	| ["Kahneman","Smith"]|
| 1591	| 2002	| literature	| Kertész|
| 1592	| 2002	| peace	| Carter|

We receive an array as a response if there are multiple values, and a single value if there is only one. We can work with that, but it is not really consistent. Also, as a developer, we are not exactly happy about having multiple values in one column. We will see how to deal with this later.

#### Filtering data
The dot notation can also be used in a `WHERE` clause. If we wanted to know, who won the Nobel Prize for physics in 1950, this would be our query:

```sql
SELECT np.document.laureates[*].firstname||' '||np.document.laureates[*].surname
FROM nobel_prize np
WHERE np.document."year" = 1950
  AND np.document.category = 'physics';
```

This returns `Cecil Powell` as a single result. We need to keep in mind, that the database has to parse and filter all documents in the table, if we filter like this. This is suprisingly fast! If we have ~ 3 million entries in a production-grade database with adequate performance, these queries can execute in one or two seconds, while scanning all the data, without any type of index being applied!

### The JSON table
#### Reading data
In the example using the dot-notation we saw, that nested JSON values were represented as an array result. The `json_table` function helps us if we wanted to join these values with our original table as a kind of internal view, in way that feels more natural to the way it works traditionally with relational data models. These columns can be used anywhere "normal" columns can be used, e.g. in a WHERE clause:


```sql
SELECT np.document."year",
	    np.document.category,
       jt.firstname,
       jt.surname
FROM nobel_prize np,
     json_table(np.document, '$.laureates[*]' columns (  
                             firstname varchar2(64) PATH '$.firstname',
                             surname   varchar2(64) PATH '$.surname')) jt
WHERE surname LIKE 'T%';
```

The result:

|year|CATEGORY|FIRSTNAME|SURNAME|
|----|--------|---------|-------|
|2002|chemistry|Koichi|Tanaka|
|2018|literature|Olga|Tokarczuk|
|2017|economics|Richard H.|Thaler|
|2017|physics|Kip S.|Thorne|
|2016|physics|David J.|Thouless|
|2015|medicine|Youyou|Tu|
|2014|economics|Jean|Tirole|
|2011|literature|Tomas|Tranströmer|
|2008|chemistry|Roger Y.|Tsien|
|1913|literature|Rabindranath|Tagore|
|1906|physics|J.J.|Thomson|
|1998|peace|David|Trimble|
|1998|physics|Daniel C.|Tsui|
|1993|physics|Joseph H.|Taylor Jr.|
|1990|physics|Richard E.|Taylor|
|1990|medicine|E. Donnall|Thomas|
|1989|peace|Lhamo|Thondup|
|1987|medicine|Susumu|Tonegawa|
|1984|peace|Desmond|Tutu|
|1983|chemistry|Henry|Taube|
|1981|economics|James|Tobin|
|1951|medicine|Max|Theiler|
|1948|chemistry|Arne|Tiselius|
|1937|physics|George Paget|Thomson|
|1958|medicine|Edward|Tatum|
|1957|chemistry|Lord|Todd|
|1955|medicine|Hugo|Theorell|
|1976|physics|Samuel C.C.|Ting|
|1975|medicine|Howard M.|Temin|
|1973|medicine|Nikolaas|Tinbergen|
|1969|economics|Jan|Tinbergen|
|1965|physics|Sin-Itiro|Tomonaga|
|1964|physics|Charles H.|Townes|
|1958|physics|Igor Y.|Tamm|

With the JSON path `$.laureates[*]` we specified the laureate array as the root of our JSON table. For every column we want to be present, we have to specify a name, a data type and the path, relative to the elements in the array. In this example we mixed the dot-notation with `json_table`, because `year` and `category` are on a higher level than our root path in the JSON document.

Again, as for the dot-notation, querying and displaying columns from the `json_table` requires the database to parse and filter all documents in the whole table.

#### Error handling
In our data set, not all laureates have both a firstname and a lastname. This is because sometimes organizations are awarded with Nobel Prizes:

```sql
SELECT jt.*
FROM nobel_prize np,
     json_table(np.document, '$.laureates[*]' columns (  
                             firstname varchar2(64) PATH '$.firstname',
                             surname   varchar2(64) PATH '$.surname')) jt
WHERE np.document."year" = 2020
  AND np.document.category = 'peace';
``` 
The result:

|firstname|surname|
|---------|-------|
|World Food Programme|null|

This seems logical - the value for surname does not exist, so the surname itself is null. This is because the default error clause for the `json_table` is `NULL ON ERROR`. A missing key in the document is, in fact, an error, and the query interprets this as `null`. If we typed out the defaults, it would look like this:

```sql
SELECT jt.*
FROM nobel_prize np,
     json_table(np.document, '$.laureates[*]' columns (  
                             firstname varchar2(64) PATH '$.firstname' NULL ON ERROR,
                             surname   varchar2(64) PATH '$.surname'   NULL ON ERROR)) jt
WHERE np.document."year" = 2020
  AND np.document.category = 'peace';
```

There are [many error clauses which apply with different JSON functions](https://docs.oracle.com/en/database/oracle/oracle-database/18/adjsn/clauses-used-in-functions-and-conditions-for-json.html#GUID-55344240-B1F0-490A-89BF-1526FA0546D4) within Oracle. The clause `ERROR ON ERROR` tells the engine to raise the error, instead of returning null: 

```sql
SELECT jt.*
FROM nobel_prize np,
     json_table(np.document, '$.laureates[*]' columns (  
                             firstname varchar2(64) PATH '$.firstname' ERROR ON ERROR,
                             surname   varchar2(64) PATH '$.surname'   ERROR ON ERROR)) jt
WHERE np.document."year" = 2020
  AND np.document.category = 'peace';
```

The result:

```
Error code: ORA-40462
Description: JSON_VALUE evaluated to no value
Cause: The provided JavaScript Object Notation (JSON) path expression did not select a value.
Action: Correct the JSON path expression.
```

Keep in mind, that this will not only bubble the error at row level! If we filtered for rows that all have a `firstname` and a `lastname`, the error will occur as long as any row in the whole dataset does not have a `lastname`! 

Depending on the JSON functions, there are also options to return empty arrays, empty objects, `true`, `false` or a default literal on error.


## Indexing JSON data
For both the dot-notation and `json_table`, we have seen that the database needs to read, parse and filter on all the properties of a JSON document in our column. And although the database does an incredible job of doing this fast and efficiently, we don't want our queries on large tables with millions of rows to take two seconds and longer, do we? Luckily, there are [several ways](https://docs.oracle.com/en/database/oracle/oracle-database/19/adjsn/indexes-for-json-data.html#GUID-8A1B098E-D4FE-436E-A715-D8B465655C0D) of indexing JSON data. We will look at two of them, which both work with the `json_value` function and dot-notation queries and some of them with `json_table`.

### JSON_VALUE function based index
We can use the function `json_value` to create a function based index. To understand how this works (and why I did not introduce it in the "Exploring data" paragraph), it is helpful to run this function on our table, first:

```sql
SELECT json_value(document, '$.year') "year",
       json_value(document, '$.category') category,
       json_value(document, '$.laureates[*].firstname') lastname
FROM NOBEL_PRIZE;
```

The result:

|year|CATEGORY|FIRSTNAME|
|----|--------|---------|
|2003|medicine|null|
|2002|chemistry|null|
|2002|economics|null|
|2002|literature|Imre|
|2002|peace|Jimmy|

This exposes an unexpected behavior for the `json_value` function: If there are multpile values for one path expression, it simply returns null. This is because, again, `NULL ON ERROR` is the default behavior for error handling. And indeed, if we append `ERROR ON ERROR` to the lastname column, we get an error message: 

```
Error code: ORA-40456
Description: JSON_VALUE evaluated to non-scalar value
Cause: The provided JavaScript Object Notation (JSON) path expression selected a non-scalar value.
Action: Correct the JSON path expression or use JSON_QUERY.
```

This behavior [is documented](https://docs.oracle.com/en/database/oracle/oracle-database/19/adjsn/function-JSON_VALUE.html#GUID-0565F0EE-5F13-44DD-8321-2AC142959215). This means, if we created an index using `json_value` on the properties of our `laureates`, the index would contain `null` values for all prizes that were shared between multiple laureates, which is obviously not helpful. The Oracle [documentation states](https://docs.oracle.com/en/database/oracle/oracle-database/19/adjsn/indexes-for-json-data.html#GUID-7CEAFFC2-C7B8-4223-BAD9-870858990939), that a `JSON_VALUE` function based index is the only one which works with `json_table`, **and only if the `JSON_VALUE` function uses the `ERROR ON ERROR` clause**. This guarantees, that all the values from the document are present in the table, but also implies that the indexed value needs to be present in all documents.  As schemaless storage is one of the benefits of document stores in databases, this seems rather restricted to me. You are able to create indexes with the `NULL ON ERROR` clause and use them with the `JSON_VALUE` clause in queries as well, but this index won't be used by a `json_table` at any time:

```sql
-- Cannot be used by json_table queries
CREATE INDEX idx_prize_year 
  ON nobel_prize (json_value(document, 
                             '$.laureates[*].firstname'
                             NULL ON ERROR));
```

```sql
-- Can be used by json_table queries, but will throw errors because the path does
-- not point to a scalar result
CREATE INDEX idx_prize_year 
  ON nobel_prize (json_value(document, 
                             '$.laureates[*].firstname'
                             ERROR ON ERROR));
```

```sql
-- Can be used by json_table queries, because year is a scalar result
CREATE INDEX idx_prize_year 
  ON nobel_prize (json_value(document, 
                             '$.year'
                             ERROR ON ERROR));
```

If you are running this example on your own database, please be aware that your database might not use the index, because the optimizer decided it would be faster to just access all rows.

### Dot-notation syntax index
Using the dot-notation to create indexes is handled in the same chapter of the Oracle documentation as the `json_value` based indexes, so I assume that they are working in a similar way "under the hood". One upside is, that indexes with the dot-notation can access and index non-scalar values:

```sql
CREATE INDEX idx_prize_firstname 
  ON nobel_prize np (np.document.laureates[*].firstname);
```

When querying for all the prizes with laureates whose first names start with 'T', we can verify this with the explain plan:

```sql
SELECT np.*
FROM nobel_prize np
WHERE np.document.laureates[*].firstname LIKE 'T%';
```

|OPERATION|OPTIONS|OBJECT_NAME|OBJECT_TYPE|OPTIMIZER|COST|CARDINALITY|
|---------|------------------|-----------|-----------|---------|----|-----------|
|SELECT STATEMENT||||ALL_ROWS|8|33|
|TABLE ACCESS|BY INDEX ROWID BATCHED|NOBEL_PRIZE|TABLE|ANALYZED|8|33|
|INDEX|RANGE SCAN|IDX_PRIZE_FIRSTNAME|INDEX|ANALYZED|2|6|

Without the index, the explain plan shows that the query will do a full table scan (which is not that expensive on a table with 600 entries):

|OPERATION|OPTIONS|OBJECT_NAME|OBJECT_TYPE|OPTIMIZER|COST|CARDINALITY|
|---------|-------|-----------|-----------|---------|----|-----------|
|SELECT STATEMENT||||ALL_ROWS|26|33|
|TABLE ACCESS|FULL|NOBEL_PRIZE|TABLE|ANALYZED|26|33|

If we want to list the same laureates with firstname and lastname, we can use the `json_table` to join them as a new table and the dot-notation to query the table in a way that can use the created index:

```sql
SELECT jt.*
FROM nobel_prize np, 
     json_table(np.document, '$.laureates[*]' columns (  
                             firstname varchar2(64) PATH '$.firstname' NULL ON ERROR,
                             surname   varchar2(64) PATH '$.surname'   NULL ON ERROR)) jt
WHERE np.document.laureates[*].firstname LIKE 'T%';
```

The result:

|FIRSTNAME|SURNAME|
|---------|-------|
|T.S.|Eliot|
|The|Svedberg|
|Theodor|Kocher|
|Theodor|Mommsen|
|Theodore|Roosevelt|
|Theodore W.|Richards|
|Thomas|Mann|
|Thomas H.|Morgan|
|Tomas|Tranströmer|
|Toni|Morrison|
|Trygve|Haavelmo|

The explain plan with `idx_prize_firstname` present:

|OPERATION|OPTIONS|OBJECT_NAME|OBJECT_TYPE|OPTIMIZER|COST|CARDINALITY|
|---------|-------|-----------|-----------|---------|----|-----------|
|SELECT STATEMENT||||ALL_ROWS|906|266277|
|NESTED LOOPS|||||906|266277|
|TABLE ACCESS|BY INDEX ROWID BATCHED|NOBEL_PRIZE|TABLE|ANALYZED|8|33|
|INDEX|RANGE SCAN|IDX_PRIZE_FIRSTNAME|INDEX|ANALYZED|2|6|
|JSONTABLE EVALUATION|||||||

The explain plan without `idx_prize_firstname` present and full table:

|OPERATION|OPTIONS|OBJECT_NAME|OBJECT_TYPE|OPTIMIZER|COST|CARDINALITY|
|---------|-------|-----------|-----------|---------|----|-----------|
|SELECT STATEMENT||||ALL_ROWS|924|266277|
|NESTED LOOPS|||||924|266277|
|TABLE ACCESS|FULL|NOBEL_PRIZE|TABLE|ANALYZED|26|33|
|JSONTABLE EVALUATION|||||||

## Summary
The JSON features in Oracle database have become more powerful with every subsequent release. Unfortunately, with every release containing new functionality, there are a lot of different ways to create, index and query JSON, with different strengths and weaknesses, and not all of them can or should be combined. The dot-notation currently seems to be the most complete and useful to me, because it has low syntax-overhead and works well with non-scalar values. For accessing array values in a "relational" way, `json_table` is a helpful tool, although its columns should not be used to filter data, as it does not work well with index access. Accessing properly indexed JSON documents in a column can be very fast. If you are already running an Oracle database, you might not need to set up an additional document-based database, if your requirements are not too complex.
