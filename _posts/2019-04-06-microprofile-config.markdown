---
layout: post
title:  "Microprofile Configuration"
date:   2019-04-06 17:00:00 +0200
categories: java microprofile
---

In the upcoming weeks, I will try and summarize the MicroProfile features on this blog. This is aimed at curious people who did not work with MicroProfile in the past but would like to get an overwiev about it. 

## The idea
Changes in application configuration should not require applications to be repackaged. Some configuration might also be changed while the application is running, and should not even require an application restart. Additionally, developers should be able to provide different configuration sources, which can override each other in a given order. The MicroProfile configuration feature aims at these problems and provides a compact solution.

## Implementation
The following examples are implemented with MicroProfile 2.1 on Payara Micro server. The code can be found on [GitHub](https://github.com/javahippie/microprofile-playground/tree/master/config_api).

### Acessing properties

Developers can access properties in two ways: They can inject them, or look them up manually. Instead of just `String`, is is possible to inject any type which is Integer, Long, Float, Double, LocalTime, LocalDate, LocalDateTime, Instant, Duration, URL or URI. The following example resembles a REST controller, which returns a JSON response with three fields, all containing properties which are retrieved in a different way:

```java
@Path("/config")
@ApplicationScoped
public class ConfigRetrievalController {

    private final static String CONFIG_PROPERTY = "config.value";
    private final static String DEFAULT_VALUE = "<unknown>";

    @Inject
    @ConfigProperty(name = CONFIG_PROPERTY, defaultValue = DEFAULT_VALUE)
    private String injectedValue;

    @Inject
    @ConfigProperty(name = CONFIG_PROPERTY, defaultValue = DEFAULT_VALUE)
    private Provider<String> injectedProvider;

    @GET
    @Path("/")
    public Response getInjectedConfigValue() {
        String injectValue = injectedValue;
        String providerValue = injectedProvider.get();
        String lookupValue = ConfigProvider.getConfig().getOptionalValue(CONFIG_PROPERTY, String.class).orElse(DEFAULT_VALUE);

        ConfigurationStyles result = new ConfigurationStyles(injectValue, providerValue, lookupValue);

        return Response.ok(result).build();
    }

}
```

Properties can be injected in two fashions. The first one is injecting the value directly. This will get the value one time at the injection point. The REST Controller is `@ApplicationScoped`, so the value will be fetched upon creation of the controller and then stored, even if the configuration is changed. If the property is not defnied, `DEFAULT_VALUE` is returned as a fallback:

```java
@Inject
@ConfigProperty(name = CONFIG_PROPERTY, defaultValue = DEFAULT_VALUE)
private String injectedValue;
```
If developers assume that the configuration value might change at runtime but still want to use property injection, they inject a provider, which can be realized at runtime later and repeatedly. Providers also support defaultValues:

```java
@Inject
@ConfigProperty(name = CONFIG_PROPERTY, defaultValue = DEFAULT_VALUE)
private Provider<String> injectedProvider;

...

String providerValue = injectedProvider.get();
```

The third way to access properties is by using a static lookup. The method `getOptionalValue` accepts the parameter name and type and, in our case, returns an `Optional<String>`. This call will always access the given properties and return new values, if properties were updated:

```java
String lookupValue = ConfigProvider
							.getConfig()
							.getOptionalValue(CONFIG_PROPERTY, String.class)
							.orElse(DEFAULT_VALUE);
```

### Config Sources
The properties that are accessed above need to be defined in one of several config sources. MicroProfile provides three config sources by default:

* System Properties 
* Environment Variables
* Property Files 

When prompted to access a property, MicroProfile will try and look it up in its config sources.

```java

```

### Custom Converters

