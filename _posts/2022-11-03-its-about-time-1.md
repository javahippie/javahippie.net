---
layout: post

title: "It's about time - Approaching Bitemporality (Part 1)"

date:   2022-11-03 14:00:00 +0200

author: Tim Zöller

categories: databases bitemporality

background: /assets/bern.jpeg
---

In the past I was part of a project with rather specialized data. It was important to create records in a database that
had a certain validity, but it was also important to know how the data looked at a given point in the past, so documents
could be recreated exactly as they really were at a certain time. We solved this in a "normal" relational database, and
it worked as expected, but it added a lot of overhead to the interaction with the database and made us implement several
abstractions over the tables. In this short article-series I plan to explain what "bitemporality" is, why we might need
it, how it can be achieved in different ways in relational databases and wich database products offer special support.
In this part of the series, we will not see bitemporal functionality, yet. Instead, we will start out without the factor 
"time" in our model at all and slowly add more capabilities.

*This text was edited on Nov. 4th 2022 to include a better definition of the term bitemporality after some friendly 
suggestions, thank you very much for the feedback!*

## What is bitemporality?

Whenever a database stores information about time, we can speak of it as a "temporal database". This information is 
usually one of the following two:

* Transaction time - describing at which time data in a database was recorded
* Valid time - describing for which timespan data is valid in the real world

We can imagine both as metadata which is represented on an axis which progresses over time. A database which makes use 
of one of these axes is called a unitemporal database. It provides mechanisms to query this axis, so we can either find
out what data was stored at a certain point in the past (transaction time) or which data was valid (or will be valid) for
which timespan (valid time). A bitemporal database utilizes two axes of time simultaneously, which enables us to query 
data in regard to both transaction time and valid time. To understand why we might need a bitemporal database, I'd like 
to start with the example below.

## The usecase

Imagine you work at a
financial institution which is required to keep its user data up to date. At the same time, the bank should be able to
reproduce all documents that were sent out in the past as they were for auditing reasons (in reality this is often done
in a different way: all old documents are archived, but bear with me for this example 😉). A lot of the customers data
can change, most common are name changes due to marriage and, of course, address changes. While the bank is required to
keep this data up to date, it's the customers obligation to inform the bank about changes.

For our example, let's get to know our customer, Jay Doe. They are a customer of the Timebank, and are about to get
married. They will take theire spouses last name, and will be known as "Jay
Duh" ([thanks to Christoph for the suggestion!](https://mastodon.online/@noctarius2k/109278748727409972)) from
2022-12-01 on. After the wedding, the Duh family immediately starts their honeymoon. Communicating his new name to the
bank is not one of Jays priorities, but they remember that they have to do this when the bank sends a contract update
via mail on 2023-01-10, and it contains their old name, Jay Doe. They start the process with their bank advisor at
Timebank and mails in their marriage certificate which proves that they are "Jay Duh" since December 1st 2022.

In this case, Jay notified the bank on January
10th 2023 that their name changed on December 1st 2022. The validity of the new name is now "December 1st 2022 to
infinity" (or until further changes are made). The transaction time of this information however is January 10th 2023,
the bank did not know of the change earlier. This might be important, if we have to reproduce the document that was sent
out for audit reasons: If the document was created on January 8th, an exact recreation of the document needs to have the
old name printed at the top. Our goal is to combine the information on both axis into a bitemporal database model.

## The simplest database - No tracking of time

To be very clear from the start on, there are not many software products that really *need* bitemporality. It introduces
a lot of complexity that has to be dealt with, so we will have a look at different ways to store the data, from simple
to complex, from "just the current state" to "full bitemporality". All examples will be run on Postgres. The simplest
table structure I can imagine for this case is the following:

```sql
create table customer
(
    id          char(36) primary key,
    given_name  char(256) not null,
    family_name char(256) not null
);
```

This allows us to store and access the value which is currently valid, but dismisses all other information. When Jay
Doe became a customer, some program probably inserted the data like this:

```sql
insert into customer (id, given_name, family_name)
values ('33f14e9c-d9b7-49e9-b0a2-d33a839389e3',
        'Jay',
        'Doe');
```

If somebody wanted to fetch the data which is currently valid, they could do this with a simple select:

```sql
select given_name, family_name
from customer
where id = '33f14e9c-d9b7-49e9-b0a2-d33a839389e3';
```

The simplicity of the approach makes sure, that every time we take a look at our data, we just see the value which is
currently valid. We don't have to deal with the factor time at all, which is preferable, if we don't need the
information at all. To update our record, a program can just run an update-statement against the DB, and the new data is
immediately visible for everybody:

```sql
UPDATE customer
set family_name = 'Duh'
where id = '33f14e9c-d9b7-49e9-b0a2-d33a839389e3';
```

The tradeoff for this simplicity is loss of information. We have no way of knowing what Jays old family name was, how
long they carry this name for or if their name was "Jay Duh" all along. To state this again, for many usecases this is
completely fine, we should not give in the temptation to over-engineer this feature, because we "might need it later".

## Tracking Validity in the live tables

If we do want to track our changes in the database, we have to enhance our example. A practice I have often observed in
real life is to either version whole records, or to create a table per property we'd like to version. While this
approach has a little more overhead, it is more in line with the goals of normalization, so let's have a look at it.
First, we create two tables which now contain our data:

```sql
create table customer
(
    id char(36) primary key
);

create table customer_name
(
    id          char(36) primary key,
    customer_id char(36)    not null,
    given_name  char(256)   not null,
    family_name char(256)   not null,
    valid_from  timestamptz not null,
    valid_to    timestamptz not null,

    constraint customer_customer_name foreign key (customer_id) references customer
);
```

The `customer` table only tracks the ID now, because we did not bother to add more fields to it (yet). It serves as the
identity of our customer. The new table, `customer_name`, contains `given_name`, `first_name`, a reference to the
customer via foreign key and two timestamps for the validity, `valid_from` and `valid_to`. As this model distributes our
data over two tables instead of one, inserting data is a little more complicated:

```sql
insert into customer (id)
values ('33f14e9c-d9b7-49e9-b0a2-d33a839389e3');

insert into customer_name (id, customer_id, given_name, family_name, valid_from, valid_to)
values ('b6ead9c0-883c-4a36-aa71-973ba5fee292', '33f14e9c-d9b7-49e9-b0a2-d33a839389e3', 'Jay', 'Doe', now(),
        '9999-12-31T23:59:59'::timestamptz);
```

These two statements need to be run in one transaction to avoid creating an inconsistency in the database. We insert the
customer and their name separately, the record in `customer_name` references the customer via `customer_id`.
The `valid_from` column is set to `now()` – a function returning the timestamp at transaction time – and the `valid_to`
column is set to "9999-12-31". The choice to set the validity to the year 9999 is not uncontroversial, I have been part
of discussions which claimed that `null` was a better marker for "infinity", as the year 9999 might actually happen at
some point. I still believe that it is a sensible approach, as I doubt that the software I write will still be running
in ~8000 years, and this default makes querying much easier, as we will see later. We will simply accept for this post,
that we introduce the risk of a Y10K bug.

Of course, querying the data is also a little harder, now that we have to deal with two tables instead of one, we need
to join them and filter for the currently valid value:

```sql
select cn.given_name, cn.family_name
from customer c
         join customer_name cn on c.id = cn.customer_id
where c.id = '33f14e9c-d9b7-49e9-b0a2-d33a839389e3'
  and now() between cn.valid_from and cn.valid_to;
```

This statement does a lot more work than our previous, simple `select from... where...` query. The developers writing it
also need to know a lot more context about the tables and need to know, that the `customer_name` table is versioned. To
abstract this complexity away, a common practice is to write a view which always returns the current aggregate of these
tables:

```sql
create view customer_valid as
select cn.given_name, cn.family_name
from customer c
         join customer_name cn on c.id = cn.customer_id
where now() between cn.valid_from and cn.valid_to;
```

With this view we can now query the current data almost as easily as in our first example:

```sql
select *
from customer_valid;
```

The downside is, that we have a new element in our database to maintain. Every time our `customer` or `customer_name`
tables change, we have to update the definition of the view, too. Also, these views get more and more complex, the more
tables with versioned data we have. For every join we need to specify the validity, this can grow rather big and
annoying over the time.

Another side effect of this design is, that we no longer can update the customer data with an SQL `update` statement,
but we have to insert in order to update and, again, need two queries to do so:

```sql
update customer_name
set valid_to = now()
where customer_id = '33f14e9c-d9b7-49e9-b0a2-d33a839389e3';

insert into customer_name (id, customer_id, given_name, family_name, valid_from, valid_to)
values ('1a70d2f8-8e96-4d0f-8f92-bfc1d0b40be1', '33f14e9c-d9b7-49e9-b0a2-d33a839389e3', 'Jay', 'Duh', now(),
        '9999-12-31T23:59:59'::timestamptz);
```

This does two things: The first query constraints the validity of the *old* record to the transaction timestamp. The
second query inserts a new row into the table which is valid *from* the transaction timestamp until the end of time (or
at least the next couple of thousand years). If we now query our view again, we receive the new value. Additionally, we
can always query the `customer_name` table to see older values, if we might need them.

An additional downside to this approach is that it is hard to define constraints which guarantee the integrity of our
data in the `customer_name` table. Right now it would be possible to insert multiple valid rows at the same time, and
there are no `common` constraints to circumvent this. We could build a solution using triggers to achieve this, but this
would introduce a new layer of complexity to keep in mind.

As an upside, this solution would allow us to define validity in the future. If Jay Doe notified Timebank that their
name will change at a future date, this information could already be included in the `customer_name` table, and the new
value would be immediately available at the cutoff date.

## Tracking values at transaction time in history tables

In the previous section we saw how versioning in the live tables itself worked. It is still somewhat straightforward to
maintain and discover, but it forces developers to always deal with the concept of time, both when reading and updating
data. We can create a model which is a little easier to access when we concentrate of data at transaction time, not
about the validity, while only holding the current value in the `customer` table. Building and maintaining this 
abstraction takes a little more effort, though, and we need to make use of triggers in the database. First, we re-create 
the table from our first example and add an audit table to it:

```sql
create table customer
(
    id          char(36) primary key,
    given_name  char(256) not null,
    family_name char(256) not null
);

create table customer_audit
(
    id          char(36),
    given_name  char(256),
    family_name char(256),
    created_at  timestamptz not null,
    operation   char(36)    not null
);
```

The audit table has the same columns, but adds two more: `created_at` and `operation`. These will hold metadata about
the changes we apply to the record. Also, the three columns which mirror the `customer` table lack any constraints. We
omit them, because the history table will live quite a long time. Imagine if we made an optional column in `customer`
mandatory, but the history table contains many empty values for it, which were historically allowed. Our functionality
would break. We don't really need the constraints here, the table should track which values existed at which time.

To implement the logic which transfers the changes made to `customer` to the audit table, we have to enter a territory
that is not in the comfort zone of some software developers: We need to write a database procedure, so we can later bind
it to a trigger:

```sql

CREATE OR REPLACE FUNCTION process_customer_after() RETURNS TRIGGER AS
$process_audit_after$
BEGIN
    IF(TG_OP = 'INSERT') THEN
        INSERT INTO customer_audit SELECT NEW.*, NOW(), 'inserted';
        RETURN NEW;
    ELSIF (TG_OP = 'UPDATE') THEN
        INSERT INTO customer_audit SELECT NEW.*, NOW(), 'updated';
        RETURN NEW;
    ELSIF(TG_OP = 'DELETE') THEN
        INSERT INTO customer_audit SELECT OLD.*, NOW(), 'deleted';
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$process_audit_after$ LANGUAGE plpgsql;
```

This procedure "knows" that it will be called by a trigger. In it, we check the value of `TG_OP`, the trigger operation.
If the operation was an insert operation, we access all columns of the `NEW` values (the values about to be inserted),
and add the current timestamp and the operation `inserted` into the audit table. We make use of the `SELECT INTO...`
syntax. The same happens if the trigger operation was an update, but the operation is set to `deleted`. If the trigger
was fired by a delete statement, we move all the `OLD` values (the values to be deleted) into the audit table and set
the status to `deleted`. Now we can connect this procedure to our `customer` table via triggers:

```sql
CREATE TRIGGER customer_audit_after
    AFTER INSERT OR UPDATE OR DELETE
    ON customer
    FOR EACH ROW
    EXECUTE PROCEDURE process_customer_after();
```

From now on, every time an operation manipulates a row (or multiple rows) in the `customer` table, the trigger will add
a row to the audit table, too. This works a little like an append-only approach, we only add new values to the table.
From this audit, we can query the state of a customer at a given point in the past, while the `customer` table always
has the currently valid data, which we can query without the help of any views. Unfortunately we have to query a whole
different table for historic values, which can cause problems if we are using an object-relational mapper. A representation
of this data after it was inserted, updated, deleted could look like this:

```sql
select * from customer_audit;
```

| id | given\_name | family\_name | created\_at | operation |
| :--- | :--- | :--- | :--- | :--- |
| 33f14e9c-d9b7-49e9-b0a2-d33a839389e3 | Jay                                                                                                                                                                                                                                                              | Doe                                                                                                                                                                                                                                                              | 2022-11-03 13:35:38.821711 +00:00 | inserted                             |
| 33f14e9c-d9b7-49e9-b0a2-d33a839389e3 | Jay                                                                                                                                                                                                                                                              | Duh                                                                                                                                                                                                                                                              | 2022-11-03 13:35:41.036025 +00:00 | updated                              |
| 33f14e9c-d9b7-49e9-b0a2-d33a839389e3 | Jay                                                                                                                                                                                                                                                              | Duh                                                                                                                                                                                                                                                              | 2022-11-03 13:35:42.608097 +00:00 | deleted                              |

## What's up next?

In the first part of the series, we did not *yet* create an example which creates a bitemporal data storage with a
well-usable API for developers. We saw two examples which can help us to set validities and track changes in our
database. While tracking everything in the live-tables complicates data access for developers, it does not require a lot
of setup in the database itself and allows us to define future validities. Tracking the changes with triggers in an
audit table creates a log of data and operations and shows us the valid data at transaction time, but does not allow us
to prepare validities upfront, or set them over a certain timespan. We have seen both parts of the "bitemporal"
definition, but separated in two concepts. In the next part of the series we will try to combine them to build a
bitemporal database model ourselves. 