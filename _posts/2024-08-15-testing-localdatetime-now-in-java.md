---
layout: post

title: "Unit testing with LocalDateTime.now() in Java"

date: 2024-08-15 08:45:00 +0200

author: Tim Zöller

categories: java spring
---

When writing unit tests, we expect the classes under test to be in a certain state that we can set up in our test. A dynamic state, which is initialised in the class itself, makes our unit testing life much harder. In this short post I will share my approach to make classes using `LocalDateTime.now()` more testable in a Spring Boot application.

## The issue
We want to write a unit test for the following class:

```java
public class PostValidatorService() {
    
    public boolean postCreationTimeIsValid(Post post) {
        LocalDateTime now = LocalDateTime.now();
        
        return post.getPostCreationTime().isBefore(now);
    }
    
}
```

As the method itself looks up the current date and time, we need to manipulate the post date to test the application logic:

```java
public class PostValidatorServiceTest() {

    @Test
    void testPostCreationTimeIsValid() {
        PostValidatorService testee = new PostValidatorService();
        
        Post post = new Post();
        post.setPostCreationTime(LocalDateTime.now().minusDays(1));
        
        boolean result = testee.postCreationTimeIsValid(post);
        
        assertThat(result).isTrue();
    }
    
    @Test
    void testInvoiceDateIsInvalid() {
        PostValidatorService testee = new PostValidatorService();
        
        Post post = new Post();
        post.setPostCreationTime(LocalDateTime.now().plusDays(1));
        
        boolean result = testee.postCreationTimeIsValid(post);
        
        assertThat(result).isFalse();
        
    }

}

```

We ignore the fact that this is not a good way to write a validator, and that the method could be placed on the `Post` class itself instead of writing a validator to the class instead. Instead, we will look at the test setup and notice that it is not very declarative. We initialise our `Post` instance with a date time that is exactly one day in the past or one day in the future, depending on what we want to test. 

This shows our intent, but prevents us from testing edge cases. What if `minusDays(1)` puts our date time in the previous month? The previous year? What if it is a leap year? What if the clocks have changed to daylight saving time? We cannot set up a test to answer these questions. If the tests are run at times that involve these edge cases, they may randomly fail.

## The naive solution
We could decide to add the value of `now()` to the method signature:

```java
public class PostValidatorService() {
    
    public boolean postCreationTimeIsValid(Post post, LocalDateTime now) {    
        return post.getPostCreationTime().isBefore(now);
    }
    
}
```

In this case we can decide what `now` is in our testcase, and create a better unit test:

```java
public class PostValidatorServiceTest() {

    @Test
    void testPostCreationTimeIsValid() {
        
        LocalDateTime now = LocalDateTime.of(2024, 8, 15, 8, 15, 0);
        LocalDateTime postDate = LocalDateTime.of(2024, 8, 15, 7, 15, 0);
        
        PostValidatorService testee = new PostValidatorService();
        
        Post post = new Post();
        post.setPostCreationTime(postDate);
        
        boolean result = testee.postCreationTimeIsValid(post, now);
        
        assertThat(result).isTrue();
    }
    
}

```

We are now the masters of time when it comes to unit testing. However, we have made the API of our `PostValidatorService` much worse. The signature is cluttered
with the current date and time throughout our application. Also, if we wrote additional unit tests, we realised that we had just moved the problem. Someone *has* to decide what `now` is at some point in our application, and we would want to unit test that part of the application as well. It would be helpful to provide a component that our instance can ask for the current time without calling `LocalDateTime.now()` itself. Fortunately, such a component exists in Java.

# Using java.time.Clock
The `Clock` class was [introduced in Java 8](https://docs.oracle.com/javase/8/docs/api/java/time/Clock.html) as part of the date and time API. It can be configured centrally in our application, passed to our classes in the constructor and used by `LocalDateTime.now()` and similar methods to find the current time *given the configured clock*:

```java
public class PostValidatorService() {

    private final Clock clock;
    
    public PostValidatorService(Clock clock) {
        this.clock = clock;
    }
    
    public boolean postCreationTimeIsValid(Post post) {
        LocalDateTime now = LocalDateTime.now(clock);
        
        return post.getPostCreationTime().isBefore(now);
    }
    
}
```

In a unit test we can set up the instance of `Clock` with the method `fixed` and pass it to the `testee`:

```java
public class PostValidatorServiceTest() {

    @Test
    void testPostCreationTimeIsValid() {
        
        Clock clock = Clock.fixed(Instant.parse("2024-08-15T08:15:00.00Z"), 
                                  ZoneId.of("Europe/Berlin"));
        
    
        LocalDateTime postDate = LocalDateTime.of(2024, 8, 15, 7, 15, 0);
        
        PostValidatorService testee = new PostValidatorService(clock);
        
        Post post = new Post();
        post.setPostCreationTime(postDate);
        
        boolean result = testee.postCreationTimeIsValid(post);
        
        assertThat(result).isTrue();
    }
    
}

```

Now we can even control the time zone our clock is in, and cover a whole new class of time-based errors. The signature of our `postCreationTimeIsValid` method is cleaned up again, and we can implement a variety of test cases without relying on the current date and time (and without using a mocking library).

## Injecting the Clock into a Spring Boot application
In modern Java frameworks, we do not instantiate our classes by hand, we use inversion of control and let the framework inject the dependencies. In a Spring Boot application, our `PostValidatorService` would probably be annotated with `@Service`. If we add the `Clock` parameter to the constructor, our framework would look up an instance of `Clock` to inject into our service - and fail. We need to provide one for our application context: 

```java
@Configuration
public class ClockConfiguration() {

    @Bean
    public Clock clock() {
        // Could also use `systemUTC()` 
        // or `system(ZoneId zoneId)` to 
        // configure the time zone of our application.
        return Clock.systemDefaultZone();
    }
}
```

Now every part of our application can inject the same `Clock` instance and use it to look up the current date and time. When writing integration tests, we could also use this to start our entire application context at a particular time to better define edge cases in our integration tests. 

## Summary
Using `Clock` in our applications will help us write better tests. In modern frameworks using dependency injection, maintaining a central instance of `Clock` requires very little overhead and won't clutter up our method signatures. While our code will still have side effects, we can now control these side effects in the setup of our unit tests and avoid broken tests.
