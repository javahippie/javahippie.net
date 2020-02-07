---
layout: post
title:  "Running Camunda on Quarkus"
date:   2020-02-07 12:00:00 +0200
categories: java microprofile quarkus camunda cdi
---

A customer asked me to review if the Camunda BPM engine can be used with Quarkus on the JVM. Before we dive into the technical part of this article, I would like to say that I would not recommend doing this right now. I love working with Quarkus, but if you plan to use libraries outside of the Quarkus extensions, you are completely on your own. If you plan to use CDI, be aware that the Quarkus ArC CDI implementation is not fully CDI compatible - as we will see later. If you need to run Camunda in production, you should stick to proven technology. We also won't take a look at running Camunda as native image.

## Camunda and CDI
If we want to use the Camunda BPM engine in a CDI context, we should probably use the module [camunda-engine-cdi](https://docs.camunda.org/manual/7.12/user-guide/cdi-java-ee-integration/). This module connects the engine to the CDI event bus, adds an EL-resolver for CDI beans to Camunda, and does some more things to make life easier. We can add the module to your Maven project with the following dependency declaration:

```xml
<dependency>
  <groupId>org.camunda.bpm</groupId>
  <artifactId>camunda-engine-cdi</artifactId>
</dependency>
``` 

## CDI in Quarkus: ArC
Quarkus brings its own CDI provider, ArC. If we want to be nitpicky, we could note that ArC is not a CDI implementation, but merely based on CDI. While many CDI mechanisms are executed at runtime, ArC resolves dependencies and executed validations during compile time. This follows a "fail fast" philosophy, and avoids scanning the beans again during the application startup. The Quarkus team also decided to not support a `beans.xml` file or explicit bean discovery, to keep the validation process fast. These decisions make sense from Quarkus' point of view, but lead to a long list of [incompatibilities with the CDI spec](https://quarkus.io/guides/cdi-reference#limitations). If you want to include a library which is built against CDI, you can't be sure that it will work with ArC. I guess, you already where this is leading...

## First try: Simply adding the dependencies
My first try was the most naive approach: I added the Camunda Dependencies to a Quarkus App and tried to start it with `mvn quarkus:dev`.

```xml
    <dependencyManagement>
        <dependencies>
            <dependency>
                <groupId>io.quarkus</groupId>
                <artifactId>quarkus-universe-bom</artifactId>
                <version>1.1.0.Final</version>
                <type>pom</type>
                <scope>import</scope>
            </dependency>
            <dependency>
                <groupId>org.camunda.bpm</groupId>
                <artifactId>camunda-bom</artifactId>
                <version>7.11.0</version>
                <scope>import</scope>
                <type>pom</type>
            </dependency>
        </dependencies>
    </dependencyManagement>
	<dependencies>
	    <dependency>
	      <groupId>io.quarkus</groupId>
	      <artifactId>quarkus-resteasy</artifactId>
	    </dependency>
	    <dependency>
	      <groupId>org.camunda.bpm</groupId>
	      <artifactId>camunda-engine</artifactId>
	    </dependency>
	    <dependency>
	      <groupId>org.camunda.bpm</groupId>
	      <artifactId>camunda-engine-cdi</artifactId>
	    </dependency>
	    <dependency>
	      <groupId>com.fasterxml.uuid</groupId>
	      <artifactId>java-uuid-generator</artifactId>
	    </dependency>
	    <dependency>
	      <groupId>io.quarkus</groupId>
	      <artifactId>quarkus-jdbc-h2</artifactId>
	    </dependency>
	    <dependency>
	      <groupId>ch.qos.logback</groupId>
	      <artifactId>logback-classic</artifactId>
	      <version>1.1.2</version>
	    </dependency>
	    <dependency>
	      <groupId>io.quarkus</groupId>
	      <artifactId>quarkus-junit5</artifactId>
	      <scope>test</scope>
	    </dependency>
	  </dependencies>
```

I will explain the dependencies in their order of appearance:

* `quarkus-resteasy` enables us to write REST Endpoints, which we will use to start a test process instance later
* `camunda-engine` is, surprisingly, the dependency for the Camunda engine
* `camunda-engine-cdi` can be seen as a "CDI-enablement" of the Camunda engine, as explained before
* `java-uuid-generator` is used by Camunda to generate unique IDs for the process instances
* `quarkus-jdbc-h2` H2 is an in-memory database. It can be used to temporarily store Camundas data
* `logback-classic` for logging
* `quarkus-junit5` for testing

Unsurprisingly, it is not that easy. As soon as the application starts, the ArC validation tells us, that many dependencies cannot be resolved:

```
Caused by: io.quarkus.builder.BuildException: 
Build failure: Build failed due to errors
	[error]: Build step io.quarkus.arc.deployment.ArcProcessor#validate threw an exception: javax.enterprise.inject.spi.DeploymentException: Found 6 deployment problems: 
[1] Unsatisfied dependency for type org.camunda.bpm.engine.cdi.BusinessProcess and qualifiers [@Default]
	- java member: org.camunda.bpm.engine.cdi.CurrentProcessInstance#businessProcess
	- declared on CLASS bean [types=[org.camunda.bpm.engine.cdi.CurrentProcessInstance, java.lang.Object], qualifiers=[@Default, @Any], target=org.camunda.bpm.engine.cdi.CurrentProcessInstance]
[2] Unsatisfied dependency for type org.camunda.bpm.engine.cdi.BusinessProcess and qualifiers [@Default]
	- java member: org.camunda.bpm.engine.cdi.ProcessVariables#businessProcess
	- declared on CLASS bean [types=[org.camunda.bpm.engine.cdi.ProcessVariables, java.lang.Object], qualifiers=[@Default, @Any], target=org.camunda.bpm.engine.cdi.ProcessVariables]
[3] Unsatisfied dependency for type org.camunda.bpm.engine.cdi.impl.ProcessVariableLocalMap and qualifiers [@Default]
	- java member: org.camunda.bpm.engine.cdi.ProcessVariables#processVariableLocalMap
	- declared on CLASS bean [types=[org.camunda.bpm.engine.cdi.ProcessVariables, java.lang.Object], qualifiers=[@Default, @Any], target=org.camunda.bpm.engine.cdi.ProcessVariables]
[4] Unsatisfied dependency for type org.camunda.bpm.engine.cdi.impl.ProcessVariableMap and qualifiers [@Default]
	- java member: org.camunda.bpm.engine.cdi.ProcessVariables#processVariableMap
	- declared on CLASS bean [types=[org.camunda.bpm.engine.cdi.ProcessVariables, java.lang.Object], qualifiers=[@Default, @Any], target=org.camunda.bpm.engine.cdi.ProcessVariables]
[5] Unsatisfied dependency for type org.camunda.bpm.engine.cdi.BusinessProcess and qualifiers [@Default]
	- java member: org.camunda.bpm.engine.cdi.impl.annotation.CompleteTaskInterceptor#businessProcess
	- declared on INTERCEPTOR bean [bindings=[@CompleteTask], target=Optional[org.camunda.bpm.engine.cdi.impl.annotation.CompleteTaskInterceptor]]
[6] Unsatisfied dependency for type org.camunda.bpm.engine.cdi.BusinessProcess and qualifiers [@Default]
	- java member: org.camunda.bpm.engine.cdi.impl.annotation.StartProcessInterceptor#businessProcess
	- declared on INTERCEPTOR bean [bindings=[@StartProcess(value = "")], target=Optional[org.camunda.bpm.engine.cdi.impl.annotation.StartProcessInterceptor]]
```    

If we take a closer look [at the code](https://github.com/camunda/camunda-bpm-platform/blob/3e848195d781985752d9cb9a8c3ced47e37536ce/engine-cdi/src/main/java/org/camunda/bpm/engine/cdi/BusinessProcess.java) of the camunda-engine-cdi module, it is obvious why this happens: The library expects the CDI provider to use implicit bean discovery, which is not supported by Quarkus ArC. The beans are not annotated with any of the scopes Quarkus supports, or any scope at all. 

```java
@Named
public class BusinessProcess implements Serializable {

  private static final long serialVersionUID = 1L;

  @Inject private ProcessEngine processEngine;

  @Inject private ContextAssociationManager associationManager;

  @Inject private Instance<Conversation> conversationInstance;

  public ProcessInstance startProcessById(String processDefinitionId) {
    assertCommandContextNotActive();

 ...

}
```

Also, in line 10 of the snippet, we can see another alarming fact: Camunda seems to use the CDI scope `@ConversationScope`, which is also not supported by ArC.

## Forking Camunda, adjusting the code
This is not very encouraging. The `@ConversationScope` can not be replaced without serious effort. But maybe we are able to get a little bit further? What would happen, if we annotated all of the beans mentioned in the exception above with `@Dependent`? Would this be already enough to run the engine in Quarkus, without having to write our own "CDI" Integration? For this experiment, all I had to do was forking the Camunda repository, cloning it to my local machine and [changing 5 files](https://github.com/javahippie/camunda-bpm-platform/commit/f57dea5a0df54bcc845473588c9b4908db01dea3):

* engine-cdi/src/main/java/org/camunda/bpm/engine/cdi/BusinessProcess.java
* engine-cdi/src/main/java/org/camunda/bpm/engine/cdi/ProcessVariables.java
* engine-cdi/src/main/java/org/camunda/bpm/engine/cdi/impl/ProcessVariableLocalMap.java
* engine-cdi/src/main/java/org/camunda/bpm/engine/cdi/impl/ProcessVariableMap.java
* engine-cdi/src/main/java/org/camunda/bpm/engine/cdi/impl/context/DefaultContextAssociationManager.java

After installing "my" version of the module to my local Maven repository and rebuilding the Quarkus application, it starts up just fine. We even get a warning message about two interceptors defined in the module. 

```
2020-01-06 16:06:33,356 INFO  [io.qua.arc.pro.Interceptors] (build-6) An interceptor org.camunda.bpm.engine.cdi.impl.annotation.CompleteTaskInterceptor does not declare any @Priority. It will be assigned a default priority value of 0.
2020-01-06 16:06:33,356 INFO  [io.qua.arc.pro.Interceptors] (build-6) An interceptor org.camunda.bpm.engine.cdi.impl.annotation.StartProcessInterceptor does not declare any @Priority. It will be assigned a default priority value of 0.
2020-01-06 16:06:34,044 INFO  [io.quarkus] (main) Quarkus 1.1.0.Final started in 1.379s. Listening on: http://0.0.0.0:8080
2020-01-06 16:06:34,046 INFO  [io.quarkus] (main) Profile dev activated. Live Coding activated.
2020-01-06 16:06:34,046 INFO  [io.quarkus] (main) Installed features: [cdi, resteasy]
```
However, we should see log entries from the starting Camunda engine. It seems like the engine was not properly configured. 


## Configuration, and other weird events
We forgot to create an entry point for it, as it is recommended when using the camunda CDI integration:

```java
package de.ilume.camunda.quarkus;

import org.camunda.bpm.application.ProcessApplication;
import org.camunda.bpm.application.impl.ServletProcessApplication;

@ProcessApplication(name = "Quarkus Demo App")
public class CamundaQuarkusApp extends ServletProcessApplication {

}

```

Nothing changes, when we start the application, again. Again, this is not very surprising, if we keep in mind what is shipped with Quarkus by default. Our CamundaQuarkusApp extends the ServletProcessApplication, but Quarkus does not provide us with a Servlet runtime. If we want to use servlets with Quarkus, we need to add Undertow as a dependency:

```xml
<dependency>
  <groupId>io.quarkus</groupId>
  <artifactId>quarkus-undertow</artifactId>
</dependency>
```

Unfortunately, still nothing changes, although everything is configured as described in the Camunda best practices (ignoring the fact, that everything we are doing is far, far, far from best practice). If we check the sourcecode of Camundas `SerletProcessApplication`, we see that it extends the interface `ServletContextListener`. These context listeners specify a method `contextInitialized`, which is called by the servlet application during startup. Setting a breakpoint into the implementation of this interfaces method shows us, that it is never called. There is still an issue with the initialization of undertow, it does not recognize this class. To be honest, I had to poke around this issue for some time, until I had the idea to annotate the `CamundaQuarkusApp` class with `@WebListener`.

```java
package de.ilume.camunda.quarkus;

import org.camunda.bpm.application.ProcessApplication;
import org.camunda.bpm.application.impl.ServletProcessApplication;

import javax.servlet.annotation.WebListener;

@ProcessApplication(name = "Quarkus Demo App")
@WebListener
public class CamundaQuarkusApp extends ServletProcessApplication {

}
```

This did the trick. After starting the application again, we can see the process engine has been initialized:

```
2020-02-07 23:04:49,938 INFO  [io.qua.arc.pro.Interceptors] (build-17) An interceptor org.camunda.bpm.engine.cdi.impl.annotation.StartProcessInterceptor does not declare any @Priority. It will be assigned a default priority value of 0.
2020-02-07 23:04:49,939 INFO  [io.qua.arc.pro.Interceptors] (build-17) An interceptor org.camunda.bpm.engine.cdi.impl.annotation.CompleteTaskInterceptor does not declare any @Priority. It will be assigned a default priority value of 0.
2020-02-07 23:04:50,410 INFO  [org.cam.bpm.container] (main) ENGINE-08024 Found processes.xml file at file:/Users/zoeller/sources/java/camunda-microprofile/quarkus-camunda/target/classes/META-INF/processes.xml
2020-02-07 23:04:50,546 INFO  [org.cam.bpm.container] (main) ENGINE-08024 Found processes.xml file at file:/Users/zoeller/sources/java/camunda-microprofile/quarkus-camunda/target/classes/META-INF/processes.xml
2020-02-07 23:04:53,569 INFO  [org.cam.bpm.eng.persistence] (main) ENGINE-03016 Performing database operation 'create' on component 'engine' with resource 'org/camunda/bpm/engine/db/create/activiti.h2.create.engine.sql'
2020-02-07 23:04:53,589 INFO  [org.cam.bpm.eng.persistence] (main) ENGINE-03016 Performing database operation 'create' on component 'history' with resource 'org/camunda/bpm/engine/db/create/activiti.h2.create.history.sql'
2020-02-07 23:04:53,595 INFO  [org.cam.bpm.eng.persistence] (main) ENGINE-03016 Performing database operation 'create' on component 'identity' with resource 'org/camunda/bpm/engine/db/create/activiti.h2.create.identity.sql'
2020-02-07 23:04:53,603 INFO  [org.cam.bpm.eng.persistence] (main) ENGINE-03016 Performing database operation 'create' on component 'case.engine' with resource 'org/camunda/bpm/engine/db/create/activiti.h2.create.case.engine.sql'
2020-02-07 23:04:53,605 INFO  [org.cam.bpm.eng.persistence] (main) ENGINE-03016 Performing database operation 'create' on component 'case.history' with resource 'org/camunda/bpm/engine/db/create/activiti.h2.create.case.history.sql'
2020-02-07 23:04:53,607 INFO  [org.cam.bpm.eng.persistence] (main) ENGINE-03016 Performing database operation 'create' on component 'decision.engine' with resource 'org/camunda/bpm/engine/db/create/activiti.h2.create.decision.engine.sql'
2020-02-07 23:04:53,611 INFO  [org.cam.bpm.eng.persistence] (main) ENGINE-03016 Performing database operation 'create' on component 'decision.history' with resource 'org/camunda/bpm/engine/db/create/activiti.h2.create.decision.history.sql'
2020-02-07 23:04:53,639 INFO  [org.cam.bpm.eng.persistence] (main) ENGINE-03067 No history level property found in database
2020-02-07 23:04:53,639 INFO  [org.cam.bpm.eng.persistence] (main) ENGINE-03065 Creating historyLevel property in database for level: HistoryLevelAudit(name=audit, id=2)
2020-02-07 23:04:53,700 INFO  [org.cam.bpm.engine] (main) ENGINE-00001 Process Engine default created.
2020-02-07 23:04:53,700 INFO  [org.cam.bpm.eng.jobexecutor] (main) ENGINE-14014 Starting up the JobExecutor[org.camunda.bpm.engine.impl.jobexecutor.DefaultJobExecutor].
2020-02-07 23:04:53,703 INFO  [org.cam.bpm.eng.jobexecutor] (JobExecutor[org.camunda.bpm.engine.impl.jobexecutor.DefaultJobExecutor]) ENGINE-14018 JobExecutor[org.camunda.bpm.engine.impl.jobexecutor.DefaultJobExecutor] starting to acquire jobs
2020-02-07 23:04:53,710 INFO  [org.cam.bpm.container] (main) ENGINE-08023 Deployment summary for process archive 'process': 

        process.bpmn

2020-02-07 23:04:53,810 INFO  [org.cam.bpm.eng.bpm.parser] (main) ENGINE-01002 Ignoring non-executable process with id 'Process_19ue2de'. Set the attribute isExecutable="true" to deploy this process.
2020-02-07 23:04:53,818 INFO  [org.cam.bpm.application] (main) ENGINE-07021 ProcessApplication 'Quarkus Demo App' registered for DB deployments [de862673-49f5-11ea-9e1b-464caa7d643e]. Will execute process definitions 

        DSGVO_Process[version: 1, id: DSGVO_Process:1:de917115-49f5-11ea-9e1b-464caa7d643e]
Deployment does not provide any case definitions.
2020-02-07 23:04:53,826 INFO  [org.cam.bpm.container] (main) ENGINE-08050 Process application Quarkus Demo App successfully deployed
2020-02-07 23:04:54,259 INFO  [io.quarkus] (main) Quarkus 1.1.0.Final started in 5.211s. Listening on: http://0.0.0.0:8080
2020-02-07 23:04:54,261 INFO  [io.quarkus] (main) Profile dev activated. Live Coding activated.
2020-02-07 23:04:54,261 INFO  [io.quarkus] (main) Installed features: [cdi, jdbc-h2, resteasy, servlet]
```

## Starting a process instance
Finally, we would like to start a process instance with our setting. If everything works correctly, we should be able to create a JAX-RS endpoint, inject the Camunda ProcessEngine into it and start a process instance. The JAX-RS endpoint looks like this:

```java
package de.ilume.camunda.quarkus;

import org.camunda.bpm.engine.ProcessEngine;
import org.camunda.bpm.engine.runtime.ProcessInstance;

import javax.inject.Inject;
import javax.ws.rs.POST;
import javax.ws.rs.Path;
import javax.ws.rs.QueryParam;
import javax.ws.rs.core.Response;

@Path("/api")
public class RestEndpoint {

    @Inject
    ProcessEngine engine;

    @POST
    @Path("/start")
    public Response startProcessInstance(@QueryParam("processId") String processId) {
        ProcessInstance instance = engine.getRuntimeService().startProcessInstanceByKey(processId);
        return Response.ok(instance.getProcessInstanceId()).build();
    }

}
```

And finally, something works in the first try! After sending a POST request to `http://localhost:8080/api/start?processId=DSGVO_Process`, we get the process instance id `8b602e20-49f6-11ea-ab24-464caa7d643e` in return. 

## Summary
As already mentioned in the introduction, running Camunda on Quarkus is not a good idea, and we strongly advised our customer to not do it, even before this experiment. Getting it to work with a very minimal scope took me 3 hours, and I did not manage to get the Camunda REST API or the Camunda Web Application to work, until now. 

One might argue, that we don't neccesarily have to use the existing Camunda CDI integration, and of course we could create our own CDI Providers to for the Camunda engine, which does not have any dependencies to CDI at all. But this is additional effort, too, which would be unneccesary if we used a runtime, which is truly CDI compatible. I was able to run and integrate Camunda in a MicroProfile application running on OpenLiberty within 10 minutes, including the REST API. 

The biggest thing I learned from this experiment: The lack of full CDI support in Quarkus can be a problem, when trying to add dependencies which rely on the full CDI standard. It can also cause problems while trying to migrate a MicroProfile application from a different runtime to Quarkus. In a [community announcement](https://thorntail.io/posts/thorntail-community-announcement-on-quarkus/) on the Thorntail website, it is suggested that Thorntails EOL is set to September 2020, and users should migrate to Quarkus. Depending on which parts of the CDI spec your application uses, this migration could get harder than expected. Quarkus 1.1.0-Final claims full MicroProfile compatibility and has [recently passed the MicroProfile umbrella TCK](https://wiki.eclipse.org/MicroProfile/Implementation). I don't quite understand, how the TCK can be passed by Quarkus, when the CDI 2.0 spec is a part of it. While I still like Quarkus and will continue to use it for small, lightweight applications (e.g. [the website for our JUG](https://www.jug-mz.de)), I probably won't use it in an enterprise setting in the near time.
