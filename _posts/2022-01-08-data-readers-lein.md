---
layout: post
title:  "Data Readers and Leiningen"
date:   2022-01-08 10:00:00 +0200
author: Tim Zöller
categories: clojure
---

For an internal REST-API we are currently experimenting with tagged literals. Creating custom tag readers is not a hard thing to do, but we found ourselves pulling information about the process from different sources, so I decided to write down our findings in this short post.

## Clojures Tagged Elements
In our application we have to store date and time values seperately. Imagine a recurring event, that happens every day at the same time. A simplified data structure to express such an event might look like this:

```clojure
{:name "Cook Dinner"
 :start-date "2022-01-01"
 :end-date "2022-01-07"
 :start-time "18:00"}
```

This structure is not ideal, as our dates and time are stored in a string value. Our application uses the `java.time.*` classes for date operations, so we would need to parse these strings manually every time. If we used `java.util.Date` for our date values, we could express our data structure like this:

```clojure
{:name "Cook Dinner"
 :start-date #inst "2022-01-01"
 :end-date #inst "2022-01-07"
 :start-time "18:00"}
 ```

`#inst` is one of Clojures [built-in tagged elements](https://github.com/edn-format/edn#built-in-tagged-elements). If a literal is prefixed with such a tag, it gets parsed by a function that is associated to it. By default, Clojure tries to parse the value following an `#inst` tag as a `java.util.Date`: 

```clojure
(type (clojure.core/read-string "\"2022-01-01\""))
;; => java.lang.String

(type (clojure.core/read-string "#inst \"2022-01-01\""))
;; => java.util.Date

```

How can we implement such a behavior for `java.time.LocalDate` and `java.time.LocalTime`?`

## Writing our own data readers
If we want to write our own data readers, we need two things: A tag and a function to parse values associated with that tag. To define this relationship and register it with our application, one way is to create a `data_readers.clj` file and put it into our source root directory. This file only contains one map with symbols representing the tag names as keys, and a var referencing the parser-function as values:

```clojure
{date my-ns.readers/read-date
 time ny-ns.readers/read-time}
```
`read-date` and `read-time` are simple Clojure functions, which accept the value prefixed by our tag as a parameter, and return the result:
```clojure
(ns my-ns.readers)

(defn read-date [date-str]
  (java.time.LocalDate/parse date-str))

(defn read-time [time-str]
  (java.time.LocalTime/parse time-str))

```
Theres nothing more to do, really, so after this code is in place, we can try our new tagged elements in the REPL:
```clojure
(type (clojure.core/read-string "#date \"2022-01-01\""))
;; => java.time.LocalDate

 (type (clojure.core/read-string "#time \"18:00\""))
;; => java.time.LocalTime
```

## Custom Data Readers and Leiningen
In our setup with Leiningen, everything worked fine until we tried to build an Uberjar. After local tests we pushed our code, fed it into the build pipeline, created an Uberjar and saw an error:

```
Unhandled java.lang.RuntimeException
   No reader function for tag timer

           LispReader.java: 1444  clojure.lang.LispReader$CtorReader/readTagged
           LispReader.java: 1427  clojure.lang.LispReader$CtorReader/invoke
           LispReader.java:  846  clojure.lang.LispReader$DispatchReader/invoke
           LispReader.java:  285  clojure.lang.LispReader/read
           LispReader.java:  216  clojure.lang.LispReader/read
           LispReader.java:  205  clojure.lang.LispReader/read
                   RT.java: 1879  clojure.lang.RT/readString
                   RT.java: 1874  clojure.lang.RT/readString
                  core.clj: 3803  clojure.core/read-string
                  core.clj: 3793  clojure.core/read-string
   ...               
```
Our data reader was not registered in the Uberjar, why? This is related to the way our application is built. Here is an excerpt from our `project.clj`:

```clojure
:profiles 
  {:uberjar {:omit-source true
             :aot :all
             :uberjar-name "my-app.jar"
             :source-paths ["env/prod/clj"]
             :resource-paths ["env/prod/resources"]}}
```

We enabled AOT for our Uberjar build, and configured `:omit-source true`, because if the sources are pre-compiled, we don't need them in the JAR. Unfortunately, our `data_readers.clj` is not precompiled, but ommited from the sources anyways, so our packaged application doesn't include it. This can be solved by moving the file from the source root folder to the resources folder. It then gets included into the JAR and the application will load it upon initialization.

## tl;dr
We wrote our own data readers to read tagged literals for `java.time.LocalDate` and `java.time.LocalDateTime`. These are registered by putting the definitions into the `data_readers.clj` file. This should be put into the `resources` folder at root level, so Leiningen does not omit the source during an Uberjar build.

