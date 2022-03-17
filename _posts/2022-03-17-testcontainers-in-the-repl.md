---
layout: post

title: "Testcontainers in the REPL"

date:   2022-03-17 14:00:00 +0200

author: Tim Zöller

categories: clojure

background: /assets/javaland.jpeg
---

I have already written some posts on this blog about
using [clj-test-containers](https://github.com/javahippie/clj-test-containers), my Clojure wrapper
for [Testcontainers](https://www.testcontainers.org), for testing databases or brokers in our automated tests without
having to bother with the infrastructure setup. While attending JavaLand this week, I was inspired
by [Michael](http://michael-simons.eu), who presented
his [Neo4j Quarkus integration](https://github.com/quarkiverse/quarkus-neo4j) in an interesting talk. He used
Testcontainers to boot up a Neo4j instance in Quarkus' dev mode, so developers would not need to bother with the DB
setup – they could just add the dependency and start coding. I wondered how easy it would be to achieve something
similar in a Clojure REPL.

## Setting up the project

I like to use the [Luminus Template](https://github.com/luminus-framework/luminus-template) to bootstrap my
applications, especially for smaller playgrounds and test environments. For this example, I set up a new Leiningen
project with the command `lein new luminus tc-demo +http-kit +postgres `. This creates a template for a web application
which connects to Postgres as a DB. Of course this assumes, that we have access to such a DB - either locally on our
machine, or on a dedicated server. If we try and start the application without configuring a database, we will get an
error:

```
~/sources/clojure/tc-demo 👉 lein run
2022-03-17 15:39:05,514 [main] WARN tc-demo.core - database connection URL was not found, please set :database-url in your config, e.g: dev-config.edn 
```

Usually we would add the JDBC URL in our environment config and start coding – but not this time! For further
preparations we add the dependency for clj-test-containers to the dev dependencies in our `project.clj` file:

```clojure
{:profiles
 {
  ;; ...
  :project/dev {:jvm-opts     ["-Dconf=dev-config.edn"]
                :dependencies [[org.clojure/tools.namespace "1.2.0"]
                               [pjstadig/humane-test-output "0.11.0"]
                               [prone "2021-04-23"]
                               [ring/ring-devel "1.9.5"]
                               [ring/ring-mock "0.4.0"]
                               [clj-test-containers "0.5.0"]
                               [org.testcontainers/postgresql "1.16.3"]]
                :plugins      [[com.jakemccrary/lein-test-refresh "0.24.1"]
                               [jonase/eastwood "0.3.5"]
                               [cider/cider-nrepl "0.26.0"]]
                ;; ...
                }}}
```

Having Docker installed on the machine is (for now) a requirement for using Testcontainers.

## Creating Profile-Specific configurations

Luminus uses [mount](https://github.com/tolitius/mount) for application state management. With mount we can define
different stateful components of our application and makes sure they start in the right order, to consider dependencies
between them. When an application is created from Luminus Template, there are preconfigured components already present,
including one for the database. The database module in the namespace `tc-demo.db.core` is the one throwing the error we
saw earlier:

```clojure
(defstate ^:dynamic *db*
          :start (if-let [jdbc-url (env :database-url)]
                         (conman/connect! {:jdbc-url jdbc-url})
                         (do
                           (log/warn "database connection URL was not found, please set :database-url in your config, e.g: dev-config.edn")
                           *db*))
          :stop (conman/disconnect! *db*))
```

This behavior makes sense: If we deploy our app to prod or start it on our machine, and we realize that there is no DB
configuration present, we want to cancel the startup immediately. This means we don't want to replace this code, we just
want to override it when developing in the REPL. Luckily mount provides us with tools
to [compose states](https://github.com/tolitius/mount#composing-states)

## Initializing Docker containers when starting the REPL

Existing Dev tooling exists in the `user` namespace, e.g. functions to start or stop the application, to create
migrations with migratus or to restart the DB. This namespace will only be loaded if we make use of the dev profile
which was configured in the `project.clj`. If we want to change our applications behavior only for the REPL in the DEV
mode, this is the right place for it. This is what happens when we call the `(start)` function in the `user` namespace:

```clojure
(defn start
      "Starts application.
      You'll usually want to run this on startup."
      []
      (mount/start-without #'javaland.core/repl-server))
  ```

`mount/start-without` starts all the components but the `repl-server`. We need to adapt this logic, to switch out the DB
configuration we saw above with our own logic:

```clojure
(require '[clj-test-containers.core :as tc])
(import '[org.testcontainers.containers PostgreSQLContainer])

(defn start
      "Starts application. You'll usually want to run this on startup."
      []
      (let [container (tc/init {:container     (PostgreSQLContainer. "postgres:14.1")
                                :exposed-ports [5432]})]
           (-> (mount/find-all-states)
               (mount/except [#'tc-demo.core/repl-server])
               (mount/swap-states {#'tc-demo.db.core/*db* {:start
                                                           #(let [c (:container (tc/start! container))]
                                                                 (conman/connect! {:jdbc-url (.getJdbcUrl c)
                                                                                   :user     (.getUsername c)
                                                                                   :password (.getPassword c)}))

                                                           :stop #(do
                                                                    (conman/disconnect! #'tc-demo.db.core/*db*)
                                                                    (tc/stop! container))}})
               (mount/start))))
```

There is a lot going on here, so let's check it step by step:

First, we initialize a new Testcontainers configuration from the prebuilt PostgreSQLContainer and declare that we would
like to have the port 5432 – Postgres default port - on the container exposed. This configuration is then bound to the
symbol `container`. Next we use mounts functions to compose our state, that we have liked earlier: We load all the
states with `find-all-states`, exclude the `repl-server` with `except`, as the configuration did before. After that, we
use `swap-states` to swap out the `*db*` state from the `tc-demo.db.core` state. Instead of getting the JDBC URL from
the configuration and connecting to a DB, we now first start the container with `(tc/start! container)` when
initializing the state. After that, we create a Hikari pool with `conman/connect`, as the code for the *db* state also
does. The configuration for this is pulled from the running Testcontainers instance: As we never provided a username or
a password and don't know on which local port the 5432 port of the running container is bound, we have to extract them
from the container via Java Getters. When we then stop the application state, we also want to stop (and implicitly
discharge of) the container.

## Adjusting the configuration for Migratus

This configuration already works: When we call the `(start)` function from the `user` namespace, we will now start a
Postgres instance in Docker on our machine. But we cannot apply our DB migrations, yet, we first need to change the
standard config of Luminus Template for this. We change these functions which are already present in the `user`
namespace to provide the datasource directly instead of relying on the JDBC-URL from the config:

```Clojure
(defn reset-db
      "Resets database."
      []
      (migrations/migrate ["reset"] {:db {:datasource tc-demo.db.core/*db*}}))

(defn migrate
      "Migrates database up for all outstanding migrations."
      []
      (migrations/migrate ["migrate"] {:db {:datasource tc-demo.db.core/*db*}}))

(defn rollback
      "Rollback latest database migration."
      []
      (migrations/migrate ["rollback"] {:db {:datasource tc-demo.db.core/*db*}}))

(defn create-migration
      "Create a new up and down migration file with a generated timestamp and `name`."
      [name]
      (migrations/create name {:db {:datasource tc-demo.db.core/*db*}}))
```

This will still work, when running the application in production. We now can apply our database migrations (could also
do this automatically on startup) and start coding.

## Summary

These configuration changes worked exactly as we wanted. Now everybody who has Docker on their local machine could check
out the code, REPL into it with the DEV profile (e.g. with `lein repl`), call the `(start)` function and start coding.
We have managed to replace the DB state in the DEV profile with our custom Testcontainers configuration. Once the
application is stopped or the JVM is terminated, the DB container will be automatically removed from Docker. This is, of
course, not only restricted to databases: We could boot up Brokers, Queues, HTTP Services on the fly – as long as we can
dockerize them and have sufficient memory on our machine. As soon as we start the REPL, everything will get started
along with every devloper having the same configuration. This would get rid of setting all these infra components up
locally. Of course we can still use Testcontainers in our integration-tests on top. 

## Test it!

You can check out the code [here](https://github.com/javahippie/tc-demo). If you have Docker installed, it should work
out of the box for you!
