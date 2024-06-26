---
layout: post
title:  "Migrating a JPA application from Oracle to PostgreSQL"
date:   2021-09-18 09:00:00 +0200
author: Tim Zöller
categories: java database jpa hibernate
---


If you followed this blog for some time, you might know that I am a big fan of relational databases and SQL. I believe RDBMS are phenomenal technological achievements, and SQL is an ingeniously crafted language to transform and retrieve data. So it might be no surprise to you, that I am not a big fan of concepts abstracting away SQL from the software, at least for read access. This doesn't mean that I oppose the idea of OR mappers or JPA in particular. Manually mapping nested object hierarchies to a relational representation is a difficult task, and write operations usually are handled the same way across different projects.

I still think JPA is misused widely in the Java world, when it is used to retrieve data and to abstract away SQL from the developer with JQL or the CriteriaQuery API. As these query types translate a common syntax into all kinds of SQL dialects, they have to agree on the very basic featureset that all RDBMS have in common. This almost always leads to worse performance, as the whole featureset of the RDBMS stays unused. Buying an Oracle Database Enterprise license and then using only the basic features is like buying a Porsche to drive to the mall 5km away (the last car-analogy in this post, I promise!).

In many projects where native SQL was explicitly forbidden(!), I heard the justification that "it will be easier to switch databases later, if we stick to the abstraction". In my experience as am IT-consultant, this switch never happens, so the phrase became a running gag with my colleagues. Imagine my surprise, when a client asked me to migrate one of their JEE applications from Oracle DB to PostgreSQL! I was intrigued to finally meet my Bigfoot of software development projects and agreed. This blog post summarizes the experience.

While I cannot show any code of the project, I try to focus on the migration itself and the resources that helped me along the way.

## The stack
The whole stack is nothing you will see people from Netflix presenting in a flashy presentation at a conference. The application is an older Java EE 5 application, running on Wildfly 14 and Java 11. It uses Hibernate as JPA implementation, connecting to an Oracle 11g instance. It uses the Hibernate Query Language, HQL, in almost all of the places, so the Oracle SQL dialect is abstracted away almost entirely. It also uses RichFaces and JSF for the frontend, which I was glad I did not have to touch during this upgrade. 

The application was created in 2011 and its main job is to load batches of data from a different system, enhance it with masterdata, calculate some new results and print reports. It is used by 3-5 people, performance is not critical. Most views in the applications UI directly map to one database table.

## Transforming the database schema
Obviously, the first step for this migration is to port the schema from Oracle to the new Postgres instance. There were two very good resources available: The [Oracle to Postgres conversion guide](https://wiki.postgresql.org/wiki/Oracle_to_Postgres_Conversion) in the Postgres Wiki, and the [SQL translation tool](https://www.jooq.org/translate/) by jOOQ. To get a good starting point, I extracted the complete DDL script from the Oracle Database with [DBeaver](https://dbeaver.io) and fed it into the jOOQ tool – tables, sequences, indexes, views and all. 

The only issue here was, that the schema in Oracle was not that well defined to begin with (but still worked, as the Hibernate validation on startup was disabled). jOOQ immediately created a DDL script which I was able to run in Postgres, but all of Oracles `NUMERIC` types were transformed to Postgres `NUMERIC`, which was too broad for Hibernate. After enabling the Hibernate Schema validation, it complained about type mismatches. A Java `double` wanted a `double precision` column type, a Java `long` needed a `bigint` in Postgres, and so on. This was the most tedious manual task of the job, with the schema having 22 tables. 

The transformation took around 12 hours of work, including tests and verification of the new schema, which was faster than I had expected. Thanks, jOOQ translation tool!

## Importing data from the test system
This was really straightforward: After creating the Schema in Postgres, I extracted 2GB of data from the Oracle test system with DBeaver and stored them as one csv file per table. These CSV files were then imported into Postgres with DBeaver, which worked at the first try with zero conflicts (at least locally and for the test system. I don't have access to the Prod DB and don't know how it was done there). 

The imports took 2 hours of work, mostly because it was a lot of data.

## Adapting the native SQL parts
While the application was mostly using HQL, there is native SQL in two parts of it: Querying sequences manually and a bigger PL/SQL script to synchronize data between to tables. Changing the SQL to query the sequences was necessary, because Oracle and Postgres handle it differently. I had to change `select THE_SEQUENCE.nextval from dual` to `select nextval('THE_SEQUENCE')` three times, which is managable. 

A surprise however was, that sequences are associated with different datatypes by the Oracle JDBC driver and the Postgres Driver. While the result of the query above returned a `BigDecimal` for Oracle, it returned a `BigInteger` for Postgres, requiring me to adjust some more places in the datamodel and in the application. When checking the value selected from the sequence, for both Oracle and Postgres, we can understand why: For Postgres, running `select pg_typeof(nextval('THE_SEQUENCE'))` returns the type `bigint`, which makes sense and is mapped to `java.math.BigInteger`. For Oracle, running `SELECT dump(THE_SEQUENCE.nextval) FROM dual;` returns `Typ=2 Len=2: 193,12`, which is not as expressive. "Type 2" means it is a `NUMBER` type, and the Oracle JDBC driver maps it to a `java.math.BigDecimal`. 

Despite this minor hickup, transforming the sequences took barely an hour. 

The PL/SQL script would surely be more work, wouldn't it? The PL/SQL stored procedure, which I unfortunately also cannot share here, did not do a lot of things: It opened a cursor on a table which contained imported data, looped over it and, for every row, checked if the target table already contained the data. If not, it was copied over with minor transformations and afterwards deleted. 

Luckily, there exists one language in Postgres which is really close to PL/SQL, and this is PL/pgSQL. There is an official [migration document](https://www.postgresql.org/docs/13/plpgsql-porting.html) on the postgres website, which helped me a lot to do the transformation. With the help of this documentation I was able to port the Procedure over to Postgres in ~1 hour, I only needed to adapt some declarations. 

This was the last part of the application, and test runs after validated, that it was successful.

## Summary 
The whole migration took me ~24 working hours, meaning it was accomplished in about three working days. This included the steps mentioned here, but also setting up my development environment, installing the Postgres module in the Wildfly AS and switching the data sources in the Wildfly config. 

Migrating to a different database vendor was very convenient, and the application being based on JPA with JQL/HQL as a query language definitely helped with that. We still have to keep in mind that the application is not under heavy load, query times are not critical and that most of the views in the application are 1:1 mappings to database tables. Using native SQL instead of HQL would not had have any benefits for this specific, CRUD-like application. 

On the other hand, the native SQL  which would have been needed to query the data for this application would not be complex, and would have been ported from Oracle to Postgres with very little effort, too. At the time of migration, the application was already running for about 10 years, so the cost of migration is almost zero in comparison to the development- and maintenance-cost as a whole. But imagine the same for a bigger application with more complex queries: Would it be worth to have an application which could perform better running for 10 years, so you can save 20k€ when the unlikely step of a DB migration is necessary? 

In the end, frustratingly: it depends. If you don't gain anything from writing native SQL because your application is simple, it could be a good idea to stick to HQL. If performance critical queries with a lot of data transformations are necessary, don't be afraid to use native SQL and access the full feature set of your RDBMS, it will make your life easier and the users happier. If there really will be a migration to a different vendor at some point in the future, it might still be easier than you'd think.
