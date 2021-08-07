---
layout: post
title:  "Calling Clojure code from Camunda"
date:   2021-08-07 10:00:00 +0200
author: Tim Zöller
categories: clojure camunda
background: /assets/birdo_sofa.jpeg
---

Since the beginning of the year, the parts of my daily work that are related to Camunda, an Open Source Workflow management Platform from Berlin, have grown a lot. I don't only use it in Java projects, I also started giving Camunda Trainings for Java Developers. As the Camunda engine is basically just a Java library, it can be used from Clojure, too. In 2019 I had the chance to present the combination at the amazing :clojureD conference. I was more than a little nervous to present one of my firsts conference talks, ever, at my favorite tech conference. You don't need to know the talk to read further, but here is the video for reference: 

<iframe width="560" height="315" src="https://www.youtube.com/embed/M1HrLAud6MA" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>

## So, I presented that already. Why a new blog post?
In the last two years, I learned some more things about Camunda and a lot of more things about Clojure, while not thinking about integrating both any further. Some months ago, Arnaud Geiser contacted me on Twitter. He saw the YouTube recording, and had some additional thoughts about how Camunda and Clojure could work better together, shared [here](https://github.com/arnaudgeiser/clj-camunda). His additions to my slides are really great and he was able to enhance Camunda (with a fork) to support a new Clojure Task type, which made for a better integration and got rid of the most annoying fact: That you needed to compile Clojure code with `:gen-class` for Camunda to find the delegate classes with the class loader. An example of such a Clojure namespace can be found here:

```clojure
(ns engine-clojure.delegate
  (:gen-class
   :name de.javahippie.camunda.Delegate
   :implements [org.camunda.bpm.engine.delegate.JavaDelegate]))

(defn -execute [this execution]
  (.setVariables execution {"var1" "A Happy String"
                            "var2" "An even happier String"}))
```

This is not the kind of code I like to write. As an additional downside, it throws Clojure developers off their workflow. With an additional compile step, the usual effortless REPL workflow is not possible. While working on a product for my own company, [lambdaschmiede](https://www.lambdaschmiede.com), I realized that a process engine would support the software nicely, and the topic became even more interesting to me, again. The ideal solution to integrate Clojure with Camunda has the following aspects:

* **No customizing Camunda itself** - the solution had to work with the default Camunda Jar, default Camunda Modeler, default Camunda Cockpit. I wanted to make my life working with Camunda easier, not start to maintain an OSS fork myself. 
* **Support a REPL workflow** - I wanted to be able to edit and re-evaluate my Clojure code in the REPL and test it instantly, with no AOT or Compile steps necessary. Ideally, 
* **Reduce Java interop code, but don't write a wrapper** - This aspect requires a certain balance. As seen in the code example above, 50% of the code is responsible for Java interop. That is definitely too much. However, as Camunda *will* pass a Java object with its context into my "Clojure Delegate", we will need some level of interop code to interact with it. Wrapping it away completely would lead to maintaing a wrapper that might become increasingly complex, this should not be a goal.

After discussing the problem with my good friend Mikhail Golubev we agreed that the best way to achieve these requirements was to write a [ProcessEnginePlugin](https://docs.camunda.org/manual/7.15/user-guide/process-engine/process-engine-plugins/) which could be integrated into every process engine and provide helper functions.

## How to call Clojure from a process instance?
The first issue to solve was, how to tell the process engine which code to call. As mentioned before, I did not want to compile Java classes, so using a service task of the type "Java Delegate" was out of the picture: For a Java Delegate we can only pass a fully qualified class name to the Camunda Engine, which then tries to load the class by name. Inspired from Arnauds example, we tried adding a new ActivityBehavior to the engine without changing Camundas code, but the whole mapping for which behavior is associated with which task type is really static in the code and we saw no way of registering a new behavior dynamically. Eventually we settled on using service tasks with the "Delegate Expression" mechanism, which is primarily used in CDI and Spring integration. If it was possible for Spring and CDI to register JavaDelegates via bean names, it should be possible for us with Clojure, too, right?

## Writing a Process Engine Plugin
This is not the first time I am writing a process engine plugin. While receiving my first Camunda training for Java Developers some years back, I was sitting alone in a hotel room in Zurich and toyed around with a process engine plugin [which sent the Camunda Task data to an Elasticsearch instance](https://github.com/javahippie/camunda-elasticsearch-task-list-plugin) to allow better indexing of variables. This was a very rough approach that I never used for anything else than demo purposes. 
The main task of the plugin would be to register new functionality to use with the [Java UEL](https://docs.camunda.org/manual/7.15/user-guide/process-engine/expression-language/), a feature that Camunda uses to look up things from context. EL expressions are marked by a leading dollar sign and braces, e.g. `${myValue > 5}`. The Camunda documentation suggests adding a `FunctionMapper` to the engine configuration, if we'd like to provide additional functionality for these expressions. This enables us to provide a new EL function, which can be called from anywhere within Camunda and links to a Java method. First, the code:

```java
package com.lambdaschmiede.camunda.clojure;

import clojure.java.api.Clojure;
import org.camunda.bpm.engine.delegate.JavaDelegate;
import org.camunda.bpm.engine.impl.javax.el.FunctionMapper;
import org.camunda.bpm.engine.impl.util.ReflectUtil;

import java.lang.reflect.Method;

/**
 * A Function mapper which provides the 'clj(arg)' function to Camundas UEL context.
 *
 * The argument is a string, referencing a Clojure function with its qualified name.
 * The targeted function has to accept exactly one parameter. This parameter will
 * be passed by the engine as an instance of DelegateExecution.
 */
public class ClojureFunctionMapper extends FunctionMapper {

    /**
     * Camunda will query this method on a list of registered FunctionMapper instances
     * with a UEL expression until the first one returns a value. This function checks
     * if the localName of the UEL expression is called 'clj'. If so, it returns a reference
     * to the static method 'eval' in this same class.
     *
     * If the localName does not match, it returns null and Camunda will query the next
     * FunctionMapper instance in its list
     */
    @Override
    public Method resolveFunction(String prefix, String localName) {
        if ("clj".equalsIgnoreCase(localName)) {
            return ReflectUtil.getMethod(ClojureFunctionMapper.class, 
                                         "eval", 
                                         String.class);
        } else {
            return null;
        }
    }

    /**
     * Receives the expression which is passed as a parameter in the 'clj' function.
     * E.g. if the expression is `clj('namespace/function')`, the parameter will
     * contain the value 'namespace/function'. This method creates a new instance
     * of JavaDelegate on the spot, with a body that invokes the referenced Clojure
     * function with its DelegateExecution parameter passed as an argument.
     */
    public static JavaDelegate eval(String expression) {
        return execution -> Clojure.var(expression).invoke(execution);
    }
}
```

We implement the interface `org.camunda.bpm.engine.impl.javax.el.FunctionMapper`. The method `resolveFunction` accepts a prefix and a name. In Camunda, several of these function mappers exist. When an EL expression is evaluated, the engine calls all of them sequentially until the first Mapper can handle the expression. If this is the case, it returns a reference to a Java methode which will execute the expression. Otherwise, it returns null. Our handler ignores the existence of prefixes and just checks, if the function in the EL expression is called "clj". The handler method, `eval` will then be called with the string parameter of that function and return a new `JavaDelegate` (with a lambda) which hands it over to Clojure to invoke, using the `DelegateExecution` parameter of the JavaDelegate as an argument (both Clojure and Camunda are provided dependencies in the library, they will not be included). If the expression on the service task was `${clj('my-namespace/a-delegate')}`, Camunda would call the function `a-delegate` in the namespace `my-namespace`, as long as it accepted one parameter. To look back at the first code example in this post, the same logic would now look like this:

```clojure
(ns my-namespace)

(defn a-delegate [execution]
  (.setVariables execution {"var1" "A Happy String"
                            "var2" "An even happier String"}))
```
This is not only more compact, it also enables us to add multiple delegate functions to a namespace **and** to use the REPL properly. We can change and evaluate this function on the fly, as we are used to, and execute the Camunda process instance again to test it instantly.

Wrapping this `FunctionMapper` as a process engine plugin is not hard. We just need to implement the interface `ProcessEnginePlugin` and can then hook into the lifecycle of the process engine initialization. Here we can pass our `ClojureFunctionMapper` to the process engine configuration before it is built:

```java
package com.lambdaschmiede.camunda.clojure;

import org.camunda.bpm.engine.ProcessEngine;
import org.camunda.bpm.engine.impl.cfg.ProcessEngineConfigurationImpl;
import org.camunda.bpm.engine.impl.cfg.ProcessEnginePlugin;

/**
 * A ProcessEnginePlugin which adds a UEL function to use plain Clojure functions 
 * as Java Delegates via Delegate Expressions
 *
 */
public class ClojureProcessEnginePlugin implements ProcessEnginePlugin {

    public void preInit(ProcessEngineConfigurationImpl processEngineConfiguration) {
        // Nothing to do here
    }

    /**
     * Registers the ClojureFunctionMapper as an additional expression mapper 
     * in the Process Engine after it is initialized
     */
    public void postInit(ProcessEngineConfigurationImpl processEngineConfiguration) {
        processEngineConfiguration.getExpressionManager()
                                  .addFunctionMapper(new ClojureFunctionMapper());
    }

    public void postProcessEngineBuild(ProcessEngine processEngine) {
    }
}
```

## Tying it all together
The plugin can be registered in the Process Engine while bootstrapping it in our Clojure code. This requires some Java Interop code, but as mentioned before, it was never the goal to provide a wrapper around the library ;)

```clojure
(let [engine-config (-> (org.camunda.bpm.engine.ProcessEngineConfiguration/createStandaloneProcessEngineConfiguration)
             (.setJdbcDriver "org.postgresql.Driver")
             (.setDataSource (:datasource my-ds))
             (.setDatabaseSchemaUpdate "true")
             (.setJobExecutorActivate true)
             (.setMetricsEnabled false))]
             
  (-> engine-config
    (.getProcessEnginePlugins)
    (.add (com.lambdaschmiede.camunda.clojure.ClojureProcessEnginePlugin.)))
    
  (.buildProcessEngine engine-config))
```

## Publishing the code and the artifacts
The code can be found [on GitHub](https://github.com/lambdaschmiede/camunda-clojure-plugin) and is licensed under the Apache Open Source License, the same as Camunda itself. I plan to publish the library to Clojars, but will need some more time to use and tweak the library so I can guarantee a stable API.

## Summary
I am quite happy with the results. The most inconvenient aspects of my previous implementation were removed, enabling Clojure developers to think in Clojure functions - as it should be ;). We got rid of AOT compilation, can make full use of the REPL and can use functions in any namespace as a Camunda delegate. Using our custom EL function could be nicer, if we didn't need to pass the reference to our Clojure function as a string, but I can live with this. Some further tests in our own product using Camunda seem to affirm that the process engine plugin is on the right path and helps a lot with the integration. Time to automate some processes, now ;) 
