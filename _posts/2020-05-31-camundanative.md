---
layout: post
title:  "Running Camunda on GraalVM Native Image"
date:   2020-05-31 12:00:00 +0200
author: Tim Zöller
categories: java graal-vm native-image camunda 
background: /assets/perth2.jpeg
---

Some months ago I posted a [blog entry](https://javahippie.net/java/microprofile/quarkus/camunda/cdi/2020/02/07/camundaquarkus.html) about the struggles I had running Camunda on Quarkus. What was meant as a summary of my experiences lead to [intense discussions](https://groups.google.com/forum/#!topic/microprofile/Rg4MPG4E6J4) in the MicroProfile community, which distracted from the Camunda part of the article. As I never intended to use Camunda on GraalVMs Native Image, anyways, I did not try to run the combination again - until now. Thanks to Oliver Libutzki for sparking my interest here again with this tweet 😉

{% include 2020-05-31-tweet.html %}

This article assumes that you have worked with Java, Camunda and Maven before, I will not explain these concepts in details. You will not need any knowledge about GraalVM at all. I don't work for Camunda and never have, but I am currently working for a company which is listed as a Camunda Partner.

## What is GraalVM native image?
[GraalVM native image](https://www.graalvm.org/docs/reference-manual/native-image/) is a tool which allows us to compile Java code (and JVM-languages and others) to a standalone, native executable ahead of time. This executable does not need a JVM to run, all necessary classes from out application, its dependencies and the JDK are included in it. As no Java Environment needs to be started to support the application, this results in fast startup times and a low memory footprint. This does not mean, that Java applications will run faster with native image than on the JVM! As the JVMs just-in-time optimizations cannot be performed on the natively built executables during runtime, we can even assume that after some uptime, an application executed in the JVM will outperform native image in some cases.

To decide, which classes need to be linked into the binary, the `native-image` generation tool performs a static code analysis to determine which classes to consider. As this can only be done on reachable code, it cannot consider some language features, e.g. reflection, dynamic classloading or Dynamic Proxies. A list of GraalVM Native Images limitations can be found here: [https://github.com/oracle/graal/blob/master/substratevm/LIMITATIONS.md](https://github.com/oracle/graal/blob/master/substratevm/LIMITATIONS.md). 

## Setting up a very simple Camunda Project
To get started, we will first create a *very* simple example Process which will be our foundation for testing:

![Our test Process](/assets/20200531/Process.png)

The process accepts two parameters upon start: 

* `language`: A language code, e.g. "DE" or "EN"
* `number`: A numeric value to be printed later by our Service tasks

The Gateway checks if the provided languge is German. If so, the number is printed in german, otherwise it will be printed in english. To test a simple timer, we will wait for 10 seconds, before printing an exit message and stopping the process. This process does not cover the whole functionality of the Camunda Process engine, but I like to start with small examples and build on them, if they work.

We are adding the following dependencies to our `pom.xml`:

```xml
<dependencies>
    <dependency>
        <groupId>org.camunda.bpm</groupId>
        <artifactId>camunda-engine</artifactId>
        <version>7.13.0</version>
    </dependency>
    <dependency>
        <groupId>org.postgresql</groupId>
        <artifactId>postgresql</artifactId>
        <version>42.2.12</version>
    </dependency>
</dependencies>
```

I chose PostgreSQL as the examples database because I already know, that its JDBC driver works with the GraalVM native image - many other JDBC drivers don't. And of course, we need a dependency to the Camunda Engine, also. Additionally, I chose to include the Maven Assembly plugin, so we can create a self contained, runnable JAR:

```xml
<plugin>
    <artifactId>maven-assembly-plugin</artifactId>
    <configuration>
        <archive>
            <manifest>
                <mainClass>de.javahippie.camunda.nativeimage.Main</mainClass>
            </manifest>
        </archive>
        <descriptorRefs>
            <descriptorRef>jar-with-dependencies</descriptorRef>
        </descriptorRefs>
    </configuration>
    <executions>
        <execution>
            <id>make-assembly</id>
            <phase>package</phase>
            <goals>
                <goal>single</goal>
            </goals>
        </execution>
    </executions>
</plugin>
```



After saving the BPMN file in the `resources` folder as `Native.bpmn`, we can set up the Camunda Engine in our Main class and start a process programatically:

```java
package de.javahippie.camunda.nativeimage;

import org.camunda.bpm.engine.ProcessEngine;
import org.camunda.bpm.engine.ProcessEngineConfiguration;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.HashMap;
import java.util.Map;

public class Main {

    private final static Logger LOG = LoggerFactory.getLogger(Main.class);

    public static void main(String... args) {

        LOG.info("Starting the application");

        ProcessEngine processEngine = ProcessEngineConfiguration
                .createStandaloneProcessEngineConfiguration()
                .setJdbcDriver("org.postgresql.Driver")
                .setDatabaseSchemaUpdate(ProcessEngineConfiguration.DB_SCHEMA_UPDATE_TRUE)
                .setJdbcUrl("jdbc:postgresql://localhost:5432/postgres")
                .setJdbcUsername("postgres")
                .setJdbcPassword("cal_pw")
                .setJobExecutorActivate(true)
                .buildProcessEngine();

        LOG.info("Created the Process Engine");

        processEngine.getRepositoryService()
                .createDeployment()
                .addClasspathResource("Native.bpmn").deploy();

        LOG.info("Deployed Native.bpmm");

        Map<String, Object> inputVariables = new HashMap<>();
        inputVariables.put("number", "5");
        inputVariables.put("language", "DE");

        processEngine
                .getRuntimeService()
                .startProcessInstanceByKey("Process_Native", inputVariables);

        LOG.info("Process was started");
    }
}
```

Of course, a Camunda Application which is developed in a professional setting would not be bootstrapped that primitive, keep in mind that this is only a simple example.

Next we will implement the three Java Delegates for our three System Tasks:

```java
package de.javahippie.camunda.nativeimage;

import org.camunda.bpm.engine.delegate.DelegateExecution;
import org.camunda.bpm.engine.delegate.JavaDelegate;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class GermanPrinter implements JavaDelegate {

    private final static Logger LOG = LoggerFactory.getLogger(GermanPrinter.class);

    public void execute(DelegateExecution execution) throws Exception {
        String number = (String) execution.getVariable("number");
        LOG.info(String.format("Die Nummer ist %s", number));
    }

}
```

```java
package de.javahippie.camunda.nativeimage;

import org.camunda.bpm.engine.delegate.DelegateExecution;
import org.camunda.bpm.engine.delegate.JavaDelegate;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class EnglishPrinter implements JavaDelegate {

    private final static Logger LOG = LoggerFactory.getLogger(EnglishPrinter.class);

    public void execute(DelegateExecution execution) throws Exception {
        String number = (String) execution.getVariable("number");
        LOG.info(String.format("The number is %s", number));
    }

}
```

```java
package de.javahippie.camunda.nativeimage;

import org.camunda.bpm.engine.delegate.DelegateExecution;
import org.camunda.bpm.engine.delegate.JavaDelegate;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class ExitPrinter implements JavaDelegate {

    private final static Logger LOG = LoggerFactory.getLogger(ExitPrinter.class);

    public void execute(DelegateExecution execution) throws Exception {
        LOG.info("Ending the Process");
    }

}
```

After connecting the Java Delegates to the Service tasks, all that's left do do is invoking `mvn package` to create the JAR file and execute it:

```
👉 java -jar target/camunda-native-image-test-1.0-SNAPSHOT-jar-with-dependencies.jar
Mai 31, 2020 3:54:50 NACHM. de.javahippie.camunda.nativeimage.Main main
INFORMATION: Starting the application
Mai 31, 2020 3:54:51 NACHM. org.camunda.feel.FeelEngine <init>
INFORMATION: Engine created. [value-mapper: CompositeValueMapper(List(org.camunda.feel.impl.JavaValueMapper@49049a04)), function-provider: org.camunda.bpm.dmn.feel.impl.scala.function.CustomFunctionTransformer@248e319b, configuration: Configuration(false)]
Mai 31, 2020 3:54:53 NACHM. org.camunda.commons.logging.BaseLogger logInfo
INFORMATION: ENGINE-00001 Process Engine default created.
Mai 31, 2020 3:54:53 NACHM. org.camunda.commons.logging.BaseLogger logInfo
INFORMATION: ENGINE-14014 Starting up the JobExecutor[org.camunda.bpm.engine.impl.jobexecutor.DefaultJobExecutor].
Mai 31, 2020 3:54:53 NACHM. org.camunda.commons.logging.BaseLogger logInfo
INFORMATION: ENGINE-14018 JobExecutor[org.camunda.bpm.engine.impl.jobexecutor.DefaultJobExecutor] starting to acquire jobs
Mai 31, 2020 3:54:53 NACHM. de.javahippie.camunda.nativeimage.Main main
INFORMATION: Created the Process Engine
Mai 31, 2020 3:54:54 NACHM. de.javahippie.camunda.nativeimage.Main main
INFORMATION: Deployed Native.bpmm
Mai 31, 2020 3:54:54 NACHM. de.javahippie.camunda.nativeimage.GermanPrinter execute
INFORMATION: Die Nummer ist 5
Mai 31, 2020 3:54:54 NACHM. de.javahippie.camunda.nativeimage.Main main
INFORMATION: Process was started
Mai 31, 2020 3:55:09 NACHM. de.javahippie.camunda.nativeimage.ExitPrinter execute
INFORMATION: Ending the Process
```

## Adding native compilation
I have built native images with Quarkus before, but compiling a plain Java application natively is new to me. In the following paragraphs I will try to build a native version of our demo appliction and learn along the way. There is a possibility that I am drawing wrong conclusions during this experiment. If you notice I did this, please feel free to contact me, I am always happy to learn.

To compile the application natively, we need to do two things: Switch our JDK to GraalVM and use its tools to compile it into a native image. For managing my JDKs, I like to use [SDKMAN](https://sdkman.io/):

```
👉 sdk use java 20.1.0.r11-grl
Not refreshing version cache now...

Using java version 20.1.0.r11-grl in this shell.

 👉 java -version
openjdk version "11.0.7" 2020-04-14
OpenJDK Runtime Environment GraalVM CE 20.1.0 (build 11.0.7+10-jvmci-20.1-b02)
OpenJDK 64-Bit Server VM GraalVM CE 20.1.0 (build 11.0.7+10-jvmci-20.1-b02, mixed mode, sharing)
```

GraalVM Native Image is not included in this distribution. We need to install it with the [GraalVM Updater](https://www.graalvm.org/docs/reference-manual/install-components/) and the following command: `gu install native-image`.

To build our native image, we are going to include another Maven Plugin. As explained before, the native image tool performs a static code analysis of our application and its dependencies, which increases compile time. Our application will be easier to debug if we can switch between building "the good old Java way" or with native image. We achieve this by introducing a Maven profile with the ID `native` and including the native compilation plugin there:

```xml
 <profiles>
    <profile>
        <id>default</id>
        <activation>
            <activeByDefault>true</activeByDefault>
        </activation>
        <build>
            <plugins>
                <plugin>
                    <artifactId>maven-assembly-plugin</artifactId>
                    <configuration>
                        <archive>
                            <manifest>
                                <mainClass>de.javahippie.camunda.nativeimage.Main</mainClass>
                            </manifest>
                        </archive>
                        <descriptorRefs>
                            <descriptorRef>jar-with-dependencies</descriptorRef>
                        </descriptorRefs>
                    </configuration>
                    <executions>
                        <execution>
                            <id>make-assembly</id>
                            <phase>package</phase>
                            <goals>
                                <goal>single</goal>
                            </goals>
                        </execution>
                    </executions>
                </plugin>
            </plugins>
        </build>
    </profile>
    <profile>
        <id>native</id>
        <build>
            <plugins>
                <plugin>
                    <groupId>org.graalvm.nativeimage</groupId>
                    <artifactId>native-image-maven-plugin</artifactId>
                    <version>20.1.0</version>
                    <executions>
                        <execution>
                            <goals>
                                <goal>native-image</goal>
                            </goals>
                            <phase>package</phase>
                        </execution>
                    </executions>
                    <configuration>
                        <mainClass>de.javahippie.camunda.nativeimage.Main</mainClass>
                        <buildArgs>-H:Name=camunda-native --allow-incomplete-classpath --report-unsupported-elements-at-runtime</buildArgs>
                    </configuration>
                </plugin>
            </plugins>
        </build>
    </profile>
</profiles>
```

We attach the plugin to the `package` phase of the Maven lifecycle, and provide two build arguments to the native image tool: The path to our main class, so the entry point of the application is defined, and how our created binary should be named.

For now, that's all. We can give the native compilation a first spin by typing `mvn package -Pnative`. As expected, the build is taking an unusually long time for such a little application, due to the static code analysis. It is also creating a lot of console output, which contains logs about the classpath entries which will be added to the image. On the first look it looks great, the Maven build is successful. Unfortunately, it also contains two warning blocks which indicate that no native executable could be built:

```
Warning: Aborting stand-alone image build due to unsupported features
Warning: Use -H:+ReportExceptionStackTraces to print stacktrace of underlying exception
Build on Server(pid: 53444, port: 53718)
[...]
Warning: Image 'camunda-native' is a fallback image that requires a JDK for execution (use --no-fallback to suppress fallback image generation and to print more detailed information why a fallback image was necessary).
```

This is telling us, that somewhere in our application or its dependencies there are language features used which cannot be resolved by native image. A fallback image was created, which cannot be executed without a JDK and is not standalone. 

## Failing with more information

The log already suggests, how we can prevent fallback image generation and print the errors instead: by passing the `--no-fallback` flag to the compiler. Let's add it to the Maven configuration and try again:

```xml
<configuration>
    <mainClass>de.javahippie.camunda.nativeimage.Main</mainClass>
    <buildArgs>-H:Name=camunda-native --no-fallback</buildArgs>
</configuration>
```

The Maven build is failing properly, this time, and we get more information about the unsupported language features in our code, there seem to be 14 of them. The beginning of the error log looks like this:

```
Error: Unsupported features in 14 methods
Detailed message:
Error: com.oracle.graal.pointsto.constraints.UnresolvedElementException: Discovered unresolved method during parsing: org.camunda.bpm.dmn.engine.impl.el.JuelElProvider.<init>(). To diagnose the issue you can use the --allow-incomplete-classpath option. The missing method is then reported at run time when it is accessed the first time.
Trace: 
	at parsing org.camunda.bpm.dmn.engine.impl.DefaultDmnEngineConfiguration.initElProvider(DefaultDmnEngineConfiguration.java:178)
Call path from entry point to org.camunda.bpm.dmn.engine.impl.DefaultDmnEngineConfiguration.initElProvider(): 
	at org.camunda.bpm.dmn.engine.impl.DefaultDmnEngineConfiguration.initElProvider(DefaultDmnEngineConfiguration.java:177)
	at org.camunda.bpm.dmn.engine.impl.DefaultDmnEngineConfiguration.init(DefaultDmnEngineConfiguration.java:96)
	at org.camunda.bpm.dmn.engine.impl.DefaultDmnEngineConfiguration.buildEngine(DefaultDmnEngineConfiguration.java:86)
	at org.camunda.bpm.engine.impl.cfg.ProcessEngineConfigurationImpl.initDmnEngine(ProcessEngineConfigurationImpl.java:2302)
	at org.camunda.bpm.engine.impl.cfg.ProcessEngineConfigurationImpl.init(ProcessEngineConfigurationImpl.java:893)
	at org.camunda.bpm.engine.impl.cfg.ProcessEngineConfigurationImpl.buildProcessEngine(ProcessEngineConfigurationImpl.java:870)
	at de.javahippie.camunda.nativeimage.Main.main(Main.java:27)
	at com.oracle.svm.core.JavaMainWrapper.runCore(JavaMainWrapper.java:149)
	at com.oracle.svm.core.JavaMainWrapper.run(JavaMainWrapper.java:184)
	at com.oracle.svm.core.code.IsolateEnterStub.JavaMainWrapper_run_5087f5482cc9a6abc971913ece43acb471d2631b(generated:0)
```

There seems to be code related to the initialization of the JUEL Provider, which native image is not able to process. The other 13 issues are also displayed. As I do not want this article to consist of error messages entirely, here is a list of the affected parts of the application:

* JuelEL Provider in the initialization of the DMN engine
* Several issues related to JPA (possibly because JPA is a `provided` dependency in the engine)
* A Lambda issue with Scala code in one of the Camunda Depencies
* Several issues with Proxies in MyBatis (from the first look, related to reflections)

These topics are not too many, but I do not have much experience with them:

* The issue with the EL Provider could mean that we are not able to boot a DMN engine without some adaptions and hints to native image. We will check this later. 

* The JPA issues can probably be ignored for our context. JPA is a provided dependency in the Camunda Engine. As JPA is not at the core of it, and the embedded engine works in Java applications without JPA, I assume that this code will never be called at runtime. JPA itself is not compatible with native image, as far as I know, a main reason why the Quarkus team created an extension for this.

* As GraalVM Native image supports Scala, there shouldn't be an issue with the language itself. There is no hint in the stacktrace, how and why this code is called in Camunda. We will cross that bridge when we get there 😉

*  The MyBatis issues could be more tricky. I have no prior experience with the library and the issues are nested deep in its internals, so there is no way of telling if the code is needed by Camunda at all. The stacktraces could hint at the Job Executor using those features, but I am not too familiar with the code of the engine itself.

## "I'm feeling lucky"
The above error message provides us with an additional compiler flag: `--allow-incomplete-classpath`. This tells the compiler, to just ignore all the classes it is not able to add to the classpath, and build the binary nevertheless. Additionally, after consulting the [documentation](https://www.graalvm.org/docs/reference-manual/native-image/#image-generation-options), to ignore unsupported language features during compile time and only report them during runtime, there is another flag: `--report-unsupported-elements-at-runtime`. Of course, this means that we will see runtime messages, if the code tries to access them anyway. I don't think I have to point out, that this is a scary thing to do, if you want your application to run productively, but on the other hand, most of the other things around this topic is, too. Once again, we change the configuration of our Maven Plugin and run `mvn package -Pnative` again:

```xml
<configuration>
    <mainClass>de.javahippie.camunda.nativeimage.Main</mainClass>
    <buildArgs>-H:Name=camunda-native --allow-incomplete-classpath --report-unsupported-elements-at-runtime</buildArgs>
</configuration>
```

This time the build succeeds with any warnings. Let's see if our process application works, or hits any of the issues which were ignored at compile time, now:

```
👉 ./target/camunda-native   
Exception in thread "main" java.lang.ExceptionInInitializerError
	at com.oracle.svm.core.hub.ClassInitializationInfo.initialize(ClassInitializationInfo.java:290)
	at java.lang.Class.ensureInitialized(DynamicHub.java:499)
	at org.camunda.bpm.engine.impl.cfg.ProcessEngineConfigurationImpl.<clinit>(ProcessEngineConfigurationImpl.java:372)
	at com.oracle.svm.core.hub.ClassInitializationInfo.invokeClassInitializer(ClassInitializationInfo.java:350)
	at com.oracle.svm.core.hub.ClassInitializationInfo.initialize(ClassInitializationInfo.java:270)
	at java.lang.Class.ensureInitialized(DynamicHub.java:499)
	at com.oracle.svm.core.hub.ClassInitializationInfo.initialize(ClassInitializationInfo.java:235)
	at java.lang.Class.ensureInitialized(DynamicHub.java:499)
	at org.camunda.bpm.engine.ProcessEngineConfiguration.createStandaloneProcessEngineConfiguration(ProcessEngineConfiguration.java:447)
	at de.javahippie.camunda.nativeimage.Main.main(Main.java:20)
Caused by: java.lang.RuntimeException: Unable to instantiate logger 'org.camunda.bpm.engine.impl.ProcessEngineLogger'
	at org.camunda.commons.logging.BaseLogger.createLogger(BaseLogger.java:100)
	at org.camunda.bpm.engine.impl.ProcessEngineLogger.<clinit>(ProcessEngineLogger.java:58)
	at com.oracle.svm.core.hub.ClassInitializationInfo.invokeClassInitializer(ClassInitializationInfo.java:350)
	at com.oracle.svm.core.hub.ClassInitializationInfo.initialize(ClassInitializationInfo.java:270)
	... 9 more
Caused by: java.lang.InstantiationException: Type `org.camunda.bpm.engine.impl.ProcessEngineLogger` can not be instantiated reflectively as it does not have a no-parameter constructor or the no-parameter constructor has not been added explicitly to the native image.
	at java.lang.Class.newInstance(DynamicHub.java:830)
	at org.camunda.commons.logging.BaseLogger.createLogger(BaseLogger.java:92)
	... 12 more

```

There seems to be an issue instantiating Camundas ProcessEngineLogger. Line 92 in [BaseLogger.java](https://github.com/camunda/camunda-commons/blob/cc7bca92a14d6ffedbc0c0ec4c20dc0c19d5c5dd/logging/src/main/java/org/camunda/commons/logging/BaseLogger.java) looks like this:

```java
T logger = loggerClass.newInstance();
``` 

The variable `loggerClass` is of a generic Type `Class<T>` and initialized with the `newInstance` method. The native image tool did not have any chance to foresee that the empty constructor of ProcessEngineLogger would be used by the application, and did not include it in the classpath. 

## Pointing Native Image into the right direction
Native Image provides us [with a way](https://github.com/oracle/graal/blob/master/substratevm/REFLECTION.md) to explicitly define classes, which will later be invoked via reflection. My first instinct was to try and specify the `ProcessEngineLogger` manually and see if the error went away. I created a new file `src/main/resources/META-INF/native-image/reflect-config.json` with the following content, to explicitly include the empty default constructor into the classpath during build time:

```json
[
  {
    "name": "org.camunda.bpm.engine.impl.ProcessEngineLogger",
    "methods": [
      {
        "name": "<init>",
        "parameterTypes": []
      }
    ]
  } 
]
```

Due to conventions, the native image tool discovers this file automatically and includes all entries to the classpath. After building and starting the application again, we get an error message claiming the next missing Logger, `org.camunda.bpm.engine.impl.bpmn.parser.BpmnParseLogger`. I added it too, built and started again, and the application asked for the next logger, and the next, and the next, and so on. After adding 7 subclasses of the `BaseLogger` manually, I wondered why all the Loggers needes to be instantiated. The issue lies in the class `ProcessEngineLogger`, which initializes a lot of different loggers statically:

```java
public class ProcessEngineLogger extends BaseLogger {

  public static final String PROJECT_CODE = "ENGINE";

  public static final ProcessEngineLogger INSTANCE = BaseLogger.createLogger(
      ProcessEngineLogger.class, PROJECT_CODE, "org.camunda.bpm.engine", "00");

  public static final BpmnParseLogger BPMN_PARSE_LOGGER = BaseLogger.createLogger(
      BpmnParseLogger.class, PROJECT_CODE, "org.camunda.bpm.engine.bpmn.parser", "01");

  public static final BpmnBehaviorLogger BPMN_BEHAVIOR_LOGGER = BaseLogger.createLogger(
      BpmnBehaviorLogger.class, PROJECT_CODE, "org.camunda.bpm.engine.bpmn.behavior", "02");

  public static final EnginePersistenceLogger PERSISTENCE_LOGGER = BaseLogger.createLogger(
      EnginePersistenceLogger.class, PROJECT_CODE, "org.camunda.bpm.engine.persistence", "03");

  public static final CmmnTransformerLogger CMMN_TRANSFORMER_LOGGER = BaseLogger.createLogger(
      CmmnTransformerLogger.class, PROJECT_CODE, "org.camunda.bpm.engine.cmmn.transformer", "04");

  public static final CmmnBehaviorLogger CMNN_BEHAVIOR_LOGGER = BaseLogger.createLogger(
      CmmnBehaviorLogger.class, PROJECT_CODE, "org.camunda.bpm.engine.cmmn.behavior", "05");
      
      //...
      
}
```

It turns out, defining the explicitly included classes is a lot of work in this case. Luckily, there is also an automated way of defining those: The native image provides a [tracing agent](https://www.graalvm.org/docs/reference-manual/native-image/#tracing-agent), which can be used to execute a compiled JAR file, "listens" to the reflection mechanisms and generates the necessary config files for us. It can be called from the commandline:
`java -agentlib:native-image-agent=config-output-dir=src/main/resources/META-INF/native-image -jar target/camunda-native-image-test-1.0-SNAPSHOT-jar-with-dependencies.jar`

This generates the files `reflect-config.json` (with > 1550 lines!), `jni-config.json`, `proxy-config.json` and `resource-config.json`. The agent worked as promised, and discovered many classes which were referenced at runtime and added them to the configuration. It feels like we are getting closer, but if we try to build the application again, we run into a new error:

```
WARNING: Could not register reflection metadata for org.camunda.bpm.application.impl.ProcessApplicationLogger. Reason: java.lang.NoClassDefFoundError: javax/servlet/ServletException.
WARNING: Could not register reflection metadata for org.camunda.bpm.container.impl.ContainerIntegrationLogger. Reason: java.lang.NoClassDefFoundError: org/jboss/vfs/VirtualFile.
WARNING: Could not register reflection metadata for org.camunda.bpm.application.impl.ProcessApplicationLogger. Reason: java.lang.NoClassDefFoundError: javax/servlet/ServletException.
WARNING: Could not register reflection metadata for org.camunda.bpm.container.impl.ContainerIntegrationLogger. Reason: java.lang.NoClassDefFoundError: org/jboss/vfs/VirtualFile.
WARNING: Could not register reflection metadata for org.camunda.bpm.application.impl.ProcessApplicationLogger. Reason: java.lang.NoClassDefFoundError: javax/servlet/ServletException.
WARNING: Could not register reflection metadata for org.camunda.bpm.container.impl.ContainerIntegrationLogger. Reason: java.lang.NoClassDefFoundError: org/jboss/vfs/VirtualFile.
WARNING: Could not register reflection metadata for org.camunda.bpm.application.impl.ProcessApplicationLogger. Reason: java.lang.NoClassDefFoundError: javax/servlet/ServletException.
WARNING: Could not register reflection metadata for org.camunda.bpm.container.impl.ContainerIntegrationLogger. Reason: java.lang.NoClassDefFoundError: org/jboss/vfs/VirtualFile.
WARNING: Could not register reflection metadata for org.camunda.bpm.application.impl.ProcessApplicationLogger. Reason: java.lang.NoClassDefFoundError: javax/servlet/ServletException.
WARNING: Could not register reflection metadata for org.camunda.bpm.container.impl.ContainerIntegrationLogger. Reason: java.lang.NoClassDefFoundError: org/jboss/vfs/VirtualFile.
```
The native image tool failed to add the `ProcessApplicationLogger` and the `ContainerIntegrationLogger` because it is missing the Classes `javax.servlet.ServletException` and `org.jboss.vfs.VirtualFile`. This left me a little bit confused at first, as those classes should also not be on the classpath when running the application as a JAR. A quick look into the `ProcessApplicationLogger` confirmed this, as IntelliJ was not able to resolve `javax.servlet.ServletException`. It took me some more minutes of poking around before I thought to look into the `pom.xml` of Camunda itself and I found the following segment. We are dealing with OSGI, too, now, which is not in my field of expertise.

```xml
<camunda.osgi.import.additional>
  junit*;resolution:=optional,
  org.junit*;resolution:=optional,
  com.sun*;resolution:=optional,
  javax.persistence*;resolution:=optional,
  javax.servlet*;resolution:=optional,
  javax.transaction*;resolution:=optional,
  javax.ejb*;resolution:=optional,
  javax.xml*;resolution:=optional,
  javax.mail*;resolution:=optional,
  org.apache.catalina*;resolution:=optional,
  org.apache.commons.mail;resolution:=optional,
  org.apache.tools.ant*;resolution:=optional,
  org.apache.xerces*;resolution:=optional,
  org.springframework*;resolution:=optional,
  com.fasterxml*;resolution:=optional,
  org.jboss.vfs*;resolution:=optional
</camunda.osgi.import.additional>
```    

## Failing and failing and failing
To get ahead with this example, I decided to take a shortcut for now, and added the new, necessary dependencies to my classpath, although I would not want to use them:

```xml
<dependency>
    <groupId>javax.servlet</groupId>
    <artifactId>javax.servlet-api</artifactId>
    <version>4.0.1</version>
</dependency>
<dependency>
    <groupId>org.jboss</groupId>
    <artifactId>jboss-vfs</artifactId>
    <version>3.2.15.Final</version>
</dependency>
```

After building again, we are greeted by a new error:

```
Exception in thread "main" com.oracle.svm.core.jdk.UnsupportedFeatureError: Unsupported constructor java.lang.invoke.MemberName.<init>(Class, String, MethodType, byte) is reachable: All methods from java.lang.invoke should have been replaced during image building.
	at com.oracle.svm.core.util.VMError.unsupportedFeature(VMError.java:86)
	at java.lang.invoke.MemberName.<init>(MemberName.java:812)
	at java.lang.invoke.MethodHandles$Lookup.resolveOrFail(MethodHandles.java:2030)
	at java.lang.invoke.MethodHandles$Lookup.findStatic(MethodHandles.java:1102)
	at camundajar.impl.scala.runtime.Statics$VM.mkHandle(Statics.java:161)
	at camundajar.impl.scala.runtime.Statics$VM.<clinit>(Statics.java:155)
	at com.oracle.svm.core.hub.ClassInitializationInfo.invokeClassInitializer(ClassInitializationInfo.java:350)
	at com.oracle.svm.core.hub.ClassInitializationInfo.initialize(ClassInitializationInfo.java:270)
	at java.lang.Class.ensureInitialized(DynamicHub.java:499)
	at camundajar.impl.scala.runtime.Statics.releaseFence(Statics.java:148)
	at camundajar.impl.scala.collection.immutable.$colon$colon.<init>(List.scala:593)
	at org.camunda.feel.impl.script.FeelScriptEngineFactory$.<clinit>(FeelScriptEngineFactory.scala:84)
	at com.oracle.svm.core.hub.ClassInitializationInfo.invokeClassInitializer(ClassInitializationInfo.java:350)
	at com.oracle.svm.core.hub.ClassInitializationInfo.initialize(ClassInitializationInfo.java:270)
	at java.lang.Class.ensureInitialized(DynamicHub.java:499)
	at org.camunda.feel.impl.script.FeelScriptEngineFactory.getEngineName(FeelScriptEngineFactory.scala:30)
	at java.util.Comparator.lambda$comparing$ea9a8b3a$1(Comparator.java:436)
	at java.util.TreeMap.put(TreeMap.java:550)
	at java.util.TreeSet.add(TreeSet.java:255)
	at javax.script.ScriptEngineManager.initEngines(ScriptEngineManager.java:126)
	at javax.script.ScriptEngineManager.init(ScriptEngineManager.java:87)
	at javax.script.ScriptEngineManager.<init>(ScriptEngineManager.java:62)
	at org.camunda.bpm.engine.impl.scripting.engine.ScriptingEngines.<init>(ScriptingEngines.java:63)
	at org.camunda.bpm.engine.impl.cfg.ProcessEngineConfigurationImpl.initScripting(ProcessEngineConfigurationImpl.java:2273)
	at org.camunda.bpm.engine.impl.cfg.ProcessEngineConfigurationImpl.init(ProcessEngineConfigurationImpl.java:892)
	at org.camunda.bpm.engine.impl.cfg.ProcessEngineConfigurationImpl.buildProcessEngine(ProcessEngineConfigurationImpl.java:870)
	at de.javahippie.camunda.nativeimage.Main.main(Main.java:27)
```

There seems to be an issue with the Scala Scripting Engine, which is also documented in this issue: [https://github.com/oracle/graal/issues/2019](https://github.com/oracle/graal/issues/2019). The issue comes with a description on how to define a substitution for the code, but this is the point where I decided to end the experiment. To write a subsitution, I would need Scala classes on my classpath and this is the tipping point for me. 

## The end
First, I learned a lot about GraalVM Native Image and also a thing or two about the Camunda Engine during this experience. Unfortunately, I don't have enough knowledge of OSGI (and Scala) to properly solve the remaining open points, and I don't have any intention to learn these technologies for this projects sake. I will take these issues to the Camunda Forum and put them there for open discussion and technical input. If you are more experienced with GraalVM, OSGI, Scala or Camunda than I am and see a way of fixing these issues, feel free to contact me on Twitter (@javahippie). You can find the sources on [GitHub](https://github.com/javahippie/camunda-native-image).





