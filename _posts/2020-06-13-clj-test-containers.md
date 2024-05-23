---
layout: post
title:  "Introducing clj-test-containers, a Testcontainers Wrapper for Clojure"
date:   2020-06-13 16:10:00 +0200
author: Tim Zöller
categories: clojure testcontainers testing
---

Last week I published a Clojure library which wraps the [Testcontainers Java library](https://www.testcontainers.org/). Please note, that this library is not an official Testcontainers library, but created and maintained by me, with no affiliation to the original project. In this post I will introduce the concepts of Testcontainers, explore the Java library and my Clojure wrapper and show some examples on how to integrate the library in a test suite.

The code is published on [Github](https://github.com/javahippie/clj-test-containers) under the EPL 1.0 License, the library can be downloaded via [Clojars](https://clojars.org/clj-test-containers).

## What are Testcontainers?
Depending on the complexity of your application, setting up the infrastructure for integration tests is not a simple task. Even if you *only* need a single database for the integration tests, you need to make it available to every system that executes the tests. But often, one database is not enough and you need to integrate with Webservices, Message Queues, Search Indexes, Caches... Testcontainers try to solve this problem: Very simply put, the testcontainers Java library provides an interface to interact with  Docker and enables developers to easily bring up Docker containers for executing tests, and tearing them down again, afterwards.

## Using the Java Library directly
First I explored the Java library with the usual Java interop functions in the REPL. It behaves like a Java library: An Instance of the class `GenericContainer` needs to be created, and then there are methods on that instance which manipulate its state. This feels rather un-clojurey, but of course we have to deal with state, if we are creating a Docker container, run and stop it. In the following code block, you can see how the library is used in Java:

```java
// https://www.testcontainers.org/features/creating_container/
GenericContainer alpine =
    new GenericContainer("alpine:3.2")
            .withExposedPorts(80)
            .withEnv("MAGIC_NUMBER", "42")
            .withCommand("/bin/sh", 
                         "-c", 
                         "while true; do echo \"$MAGIC_NUMBER\" | nc -l -p 80; done");
```


A very primitive Clojure test against a PostgreSQL database with [jdbc.next](https://github.com/seancorfield/next-jdbc) and the Testcontainers Java library could look like this:

```clojure
(deftest db-integration-test
  (testing "A simple PostgreSQL integration test"
    (let [pw "db-pass"
          postgres (-> (org.testcontainers.containers.GenericContainer. "postgres:12.2")
                       (.withExposedPorts (into-array Integer [(int 5432)]))
                       (.withEnv "POSTGRES_PASSSWORD" pw))]
      (.start postgres)
      (let [datasource (jdbc/get-datasource {:dbtype "postgresql"
                                             :dbname "postgres"
                                             :user "postgres"
                                             :password pw
                                             :host (.getHost postgres)
                                             :port (.getFirstMappedPort postgres)})]
        (is (= [{:one 1 :two 2}] (with-open [connection (jdbc/get-connection datasource)]
                                   (jdbc/execute! connection ["SELECT 1 ONE, 2 TWO"])))))
      (.stop postgres))))
```

I don't really enjoy working with the Java interop library and calling several functions on a Java object in a row, but the `with` builder-methods of the Testcontainer library, which always return the manipulated instance, help a lot and enable us to use a threading macro to interact with the instance. Theoretically we could also use the container with Clojures `with-open` function, as it implements the interface `AutoClosable`. Unfortunately for Clojure users, the methods `withExposedPorts` and `withCommand` use vararg parameters. For `withExposedPorts` this means, that we need to convert a list or vector into an array with `into-array` which introduces additional overhead. We decided that we would not want to write this kind of code over and over in our unit tests, and started creating a thin wrapping layer.

# Wrapping the Library
Our initial approach was to create one function which created the whole testcontainer with its entire configuration, and then functions to start and stop it. However, the amount of operations which can be performed on a testcontainer, is quite high: You can configure ports, network settings, commands to be executed and volume mappings. These mappings can be defined on classpath resources or files in your host filesystem. This would have created a rather large configuration map for creating a Testcontainers instance, with several flags. Additionally, there are methods to execute a command in a running container instance, or copy a file into it. The list of functions included in the library until now is as following:

* `create`: Creates a new Testcontainers instance, accepts parameters for mapped ports, environment variables and a start command 
* `map-classpath-resource!`: Maps a resource from your classpath into the containers file system
* `bind-filesystem!`: Binds a path from your local filesystem into the Docker container as a volume
* `start!`: Starts the container
* `stop!`: Stops the container
* `copy-file-to-container!`: Copies a file from your filesystem or classpath into the running container
* `execute-command!`: Executes a command in the running container, and returns the result

The functions accept and return a map structure, which enables us to operate them on the same data structure in a consistent way. The example shown with Java Interop above would look like this, when using the wrapped functions:

```clojure
(require '[clj-test-containers.core :as tc])

(deftest db-integration-test
  (testing "A simple PostgreSQL integration test"
    (let [pw "db-pass"
          postgres (-> (tc/create {:image-name "postgres:12.1" 
                                   :exposed-ports [5432] 
                                   :env-vars {"POSTGRES_PASSWORD" pw}}))]
      (tc/start! postgres)
      (let [datasource (jdbc/get-datasource {:dbtype "postgresql"
                                             :dbname "postgres"
                                             :user "postgres"
                                             :password pw
                                             :host (:host postgres)
                                             :port (get (:mapped-ports container) 5432)})]
        (is (= [{:one 1 :two 2}] (with-open [connection (jdbc/get-connection datasource)]
                                   (jdbc/execute! connection ["SELECT 1 ONE, 2 TWO"])))))
      (tc/stop! postgres))))
```

## Executing commands inside the container

The `execute-command` function enables us to run commands inside the container. The function accepts a container and a vector of strings as parameters, with the first string being the command, followed by potential parameters. The function returns a map with an `:exit-code`, `:stdout` and `:stderr`:

```clojure
(execute-command! container ["whoami"])

> {:exit-code 0
   :stdout "root"}
```

## Mounting files into the container

For some test scenarios it can be helpful to mount files from your filesystem or the resource path of your application into the container, before it is started. This could be helpful if you want to load a dumpfile into your database, before executing the tests. You can do this with the functions `map-classpath-resource!` and `bind-filesystem!`:

```clojure
(map-classpath-resource! container 
                         {:resource-path "test.sql"
                          :container-path "/opt/test.sql"
                          :mode :read-only})
```  

```clojure
(bind-filesystem!  {:host-path "."
                    :container-path "/opt"
                    :mode :read-only})
```

It is also possible to copy files into a running container instance:

```clojure
(copy-file-to-container!  {:path "test.sql"
                           :container-path "/opt/test.sql"
                           :type :host-path})
```

# Fixtures for Clojure Test
The above example creates a Testcontainers instance in the test function itself. If we did this for all of our integration tests, this would spin up a docker image for every test function, and tear it down again, afterwards. If we want to create one image for all tests in the same namespace, we can use Clojures [`use-fixtures`](https://clojuredocs.org/clojure.test/use-fixtures) function, which is described like this:

> Wrap test runs in a fixture function to perform setup and
teardown. Using a fixture-type of :each wraps every test
individually, while :once wraps the whole run in a single function.

Assuming we have a function `initialize-db!` in our application which sets up a JDBC connection and stores it in an atom, a fixture for Testcontainers could look like this: 

```clojure
(use-fixtures :once (fn [f]
                      (let [{pw "apassword"
                             postgres (tc/start! (tc/create {:image-name "postgres:12.2"
                                                             :exposed-ports [5432]
                                                             :env-vars {"POSTGRES_PASSWORD" pw}}))}]
                        (my-app/initialize-db! {:dbtype   "postgresql"
                                                :dbname   "postgres"
                                                :user     "postgres"
                                                :password pw
                                                :host     (:host postgres)
                                                :port     (get (:mapped-ports postgres) 5432)}))
                      (f)
                      (tc/stop! postgres)))
```

This will set up the container, execute all test functions in the namespace and stop the container afterwards.


# Missing features and the next steps
The Clojure wrapper does not provide all Testcontainers functionality, yet. Network features are missing, and idiomatic support of "prebuilt" containers like `KafkaContainer`, which come with additional, prepared configurations, are yet to be delivered. Feel free to suggest API improvements or new functionality on GitHub.
