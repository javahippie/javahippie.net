---
layout: post
title:  "Cloudready Clojure Part 4"
date:   2020-08-23 7:00:00 +0200
author: Tim Zöller
categories: clojure cloud
background: /assets/kanonenplatz.jpeg
---

This is part 4 of a series in which I will show some of my approaches to a "Cloud Ready" web application with Clojure. If you are new to web apps with Clojure, you should read the first three parts, [Cloudready Clojure Part 1](/clojure/cloud/2020/04/20/clojurenative01.html), [Cloudready Clojure Part 2](/clojure/cloud/2020/04/21/clojurenative02.html), [Cloudready Clojure Part 3](/clojure/cloud/2020/05/04/clojurenative03.html) first, where we set up a webserver, session handling, the base for serverside HTML rendering and a configuration mechanism which will work with cloud providers. I would like to apologize for the long delay since the last part. Time has been a little tight in the last weeks, [as I am starting self employment](/work/freelancing/2020/08/19/self-employment.html) and need to prepare a lot of things until next year.

 
## Cloud Ready database deployments
In the last part of this blog series we created a database connection and our first table, so we we could store our HTTP sessions in the database. This was necessary, because we wanted the session not to be limited to an instance of our application and use sticky sessions. Now that the session is looked up from the database, any request can be sent to any instance, and will still know the session. Making all instances share one database is a common pattern to share all available information between them. Every feature, which is dependent on values in memory will make scaling of the application more complicated. 

There is one thing, however, which gets much harder if all instances share the same database: Deployment. Before introducing the database connection, all our instances were independent, which is a good thing if we want to use zero-downtime-deployments: If, e.g., three instances of our application are running in parallel, we can install new deployments for each instance at a time, keeping the other ones online. To the user, our application is available all the time, there is no maintenance window at all. The application is able to run zero-downtime deployments. This procedure can be used with on-premise installations, tailored cloud solutions like Heroku, or provider-agnostic environments like Kubernetes or OpenShift.

In our little example application, there are now two components to deploy: The database schema and the application itself. We want to be able to install the application in an automated way on any of our environments (dev, test, staging, prod) without having to worry about the version previously installed.

## Database deployments in different environments
To understand why this can be complicated, I would like to tell you a story from my first project as an IT consultant for a bank in 2014. We were working in a regulated environment, so the developers did not have access to the two(!) staging environments and production. We did have access to a dev server and three(!) test servers with different versions, so the application had seven environments: Dev, Test1, Test2, Test3, Staging1, Staging2, Prod. 

One of our team members was the best database developer I have ever met. He did nothing else than create or database model, fine tune and index the application and the statements - and make sure, every version of our model was deployed in the right environment (and he also did not have access to three environments). For every software change he would create a migration script which needed to be run to lift the model from version x to version y. These needed to be executed in the exactly right order exactly once per environment and version. After nearly every deployment failed, because somebody forgot to execute the migration script, or missed some of the scripts that were needed for the next version, he decided to automate the process. He created a PL/SQL script, which created a version table in the database. All migration scripts were put into a single folder, with a sortable, ascending naming pattern. When the script was executed on an environment, it checked the version table to determine which scripts had already been executed and which scripts needed to be run. When a script was executed without errors, it was added to the table, and never executed on that environment again. This PL/SQL Script could be included into our build pipelines, the database deployment was completely automated now.

## Versioned database schemas in Clojure
The pattern described above was made popular for Java applications by the Library [Flyway](https://flywaydb.org). It contains multiple tools, to include the database deployment into the startup phase of an application. This means, that our application is responsible for pulling the database model to the exact version that it needs. This is even more comfortable than the mechanism we used in our 2014 project - you just deploy the application and it takes care of the database deployment itself. We keep deploying only one artifact to our environments and it takes care of the rest. Luckily, we are not required to glue a Java library into our codebase with interop code, because there is an excellent Clojure library doing a similar thing: [Migratus](https://github.com/yogthos/migratus). In the following paragraphs we will include migratus into our application. I won't show every Migratus feature (check the excellent documentation if you want to know more), but just a single usecase that has proven to work well with a different Clojure project. Properly used, Migratus can help you migrate and roll back (!) database changes to certain versions.

## Migrate all the things!
The first thing we need to do is dropping the table from the last part of this blog series. We don't want any manual work on the database anymore, we will automate everything now, like sophisticated developers: `DROP TABLE session_store`.

The first step of automating it, as always, is to include the dependency in our `build.boot` file: 

```clojure
(set-env! :resource-paths #{"resources" "src"}
          :source-paths   #{"test"}
          :dependencies   '[[org.clojure/clojure "1.10.0"]
                            [adzerk/boot-test "1.2.0" :scope "test"]
                            [ring "1.8.0"]
                            [rum "0.11.4"]
                            [yogthos/config "1.1.7"]
                            [ring/ring-defaults "0.3.2"]
                            [org.postgresql/postgresql "42.2.11"]
                            [jdbc-ring-session "1.3"]
                            [ring/ring-session-timeout "0.2.0"]
                            [migratus "1.2.8"]])
```

We want to run the databse migration every time the application is started (which might not be the ideal way to do it for every type of application), so we require `[migratus.core :as migratus]` into our namespace and add the function call to Migratus to our code:

```clojure
(defn init-db [db-conf]
  (migratus/migrate {:store                :database
                     :migration-dir        "migrations/"
                     :init-in-transaction? false
                     :migration-table-name "migratus_table"
                     :db db-conf}))
```
    
Let's have a closer look at these properties:

* `:store` defines the store against which we want to run our migrations. We want to do database migrations, so the value is set to `:database`
* `:migration-dir` specifies the directory which holds our migration scripts. In our case, the files will be put into the `migrations` folder in our `resources`.
* `:init-in-transaction?` configures if the database schema initialization should be performed in a transaction. As not every DDL script can be run transactionally in PostgreSQL, we set the value to false
* `:migration-table-name` specifies the name of our versioning table, which keeps track on the installed scripts
* `:db` accepts a database configuration. Lucky for us, this accepts the exact db config which is already stored in our environment configuration!

The next step for us is to put our first migration script into our `resources/migrations` folder. We already now the script from the last part of this blog-series, and put it into the file `20200823093500-create-session-table.up.sql`:

```sql
CREATE TABLE session_store
(
  session_id VARCHAR(36) NOT NULL PRIMARY KEY,
  idle_timeout BIGINT,
  absolute_timeout BIGINT,
  value BYTEA
)
```
The filename needs to follow a certain pattern. It begins with a time-pattern which is best described by the Migratus documentation:

> Each file should be named with the following pattern [id]-[name].[direction].sql where id is a unique integer id (ideally it should be a timestamp) for the migration, name is some human readable description of the migration, and direction is either up or down.

I am using Flyway for two years in a Java project now, and using a date pattern for the `id` part has proven as a good practice when working in a distributed team. This is also true, when using Migratus. You need to avoid having the same ID twice, and using a time pattern which includes seconds is a good way of reducing the likelihood of this happening. The name should define in a readable way what the script does. We append `up` to the name, as it is an up-migration which should be executed when migrating from a lower version to this one. A matching down-migration would have the name `20200823093500-create-session-table.down.sql` and would look like this:

```sql
DROP TABLE session_store;
```

## Running our first migration
All we need to do now is including the function call `(init-db db-conf)` function into our `-main` function:

```clojure
(defn -main
  "Starts the web server and the application"
  [& args]
  (let [db-conf (:db env)
        session-store (jdbc-store db-conf)
        port (:port env)
        session-expiry-in-minutes 5]
    (init-db db-conf)
    (start-cleaner db-conf)
    (run-jetty 
     (-> app-handler
         (wrap-idle-session-timeout {:timeout (* session-expiry-in-minutes 60)
                                     :timeout-response {:status 200
                                                        :body "Session timed out"}})
         (wrap-defaults (-> site-defaults 
                            (assoc-in [:session :store] session-store)))) 
     {:port port})))
```

If we execute `boot run` now, we can see in the logfiles, that a migration was executed and all scripts were applied to the database without errors:

```
Aug 23, 2020 10:02:54 AM clojure.tools.logging$eval4746$fn__4749 invoke
INFORMATION: Starting migrations
Aug 23, 2020 10:02:54 AM clojure.tools.logging$eval4746$fn__4749 invoke
INFORMATION: creating migration table 'migratus_table'
Aug 23, 2020 10:02:54 AM clojure.tools.logging$eval4746$fn__4749 invoke
INFORMATION: Running up for [20200823093500]
Aug 23, 2020 10:02:54 AM clojure.tools.logging$eval4746$fn__4749 invoke
INFORMATION: Up 20200823093500-create-session-table
Aug 23, 2020 10:02:54 AM clojure.tools.logging$eval4746$fn__4749 invoke
INFORMATION: Ending migrations
```

Double checking our database, we can see that the `session_store` and `migratus_table` tables were created. The data of `migratus_table` should look like this:

```
id            |applied            |description         |
--------------|-------------------|--------------------|
20200823093500|2020-08-23 10:02:54|create-session-table|
```

## Next steps
Now that our application is set up to bring its own database schema into the cloud, we are ready to deploy it to a cloud provider. In the next part of this blog series we will set up a simple deployment to Heroku, a cloud platform I like to use because of its simplicity. Thank you for reading on!