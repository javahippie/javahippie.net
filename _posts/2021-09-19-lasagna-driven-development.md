---
layout: post
title:  "Lasagna Driven Development - Thoughts on Layered Architecture"
date:   2021-10-16 20:00:00 +0200
author: Tim Zöller
categories: architecture
background: /assets/lasagna.jpg
---

In the past years, I presented a lot of talks in different environments, in front of different people. Usually I am not really nervous beforehand, but there is one particular talk that made me sweat before the presentations: [Mapping efficiently with SQL](https://app.pitch.com/app/presentation/10ee9dd4-bfce-4e24-a858-0398ebf282a4/3be4ca15-6494-4b61-9e7f-4dfa0ae8125d). The presentation followed an article I wrote for the German "Java Magazin" and was born from the frustration with the thousands of lines of code in software projects which were just there for mapping between different domains in the software. The main idea of the presentation was, that we could leverage SQL to map data directly, a least for database-centric applications. 

After building these slides, I realized that the mapping code was not the main issue for me. The main issue was, how layered architecture is misunderstood in many of todays' software projects. So under the cover of "Mapping efficiently with SQL", I went to enterprise conferences and big corporations and talked about misunderstandings in layered architecture. Many of these corporations enforced layered architecture for all of their projects, often over the timeframe of many years. This is why I was so nervous about the presentations, I was walking into their living room and asked "Are we sure we are doing this right?". 

The feedback I received was always great. It turned out, that these thoughts resonated with a lot of developers and architects, and that the tool "Layered architecture" was often used a little too heavy-handed and careless. This is why I decided to also write a blog post on the topic. I am not saying that you, the reader, are guilty of this. Maybe there is nothing new in this article for you! But maybe you can recognize some patterns that can be adjusted in your work environment, too. 

## A short explanation of layered architecture
The idea behind Layered Architecture is to divide the applications domain into sub-domains, thought of as layers. Usually, there are three layers:

* Presentation Layer (User Interface)
* Domain Layer (Business Rules, Application Logic)
* Persistence Layer (RDMBS, Storage)

Higher Layers are allowed to call the layers below, so the Presentation Layer knows about the Domain Layer, but not about the Persistence Layer. The persistence layer does not know any of the other layers, as they are above it, and access only goes from top to bottom. 

I started working as a software developer in 2008, an from the first year on I worked on projects using layered architecture. I get the impression, that this architecture style is often chosen as a default (at least in enterprise projects) and many developers accepted this over the last two decades, so it was passed on from developer to developer. When I started researching the term and the idea behind it, I found the book [Patterns of Enterprise Application Architecture](https://scholar.google.com/scholar?q=Patterns+of+Enterprise+Application+Architecture+martin+fowler&hl=de&as_sdt=0&as_vis=1&oi=scholart) by Martin Fowler (Addison Wesley, 2002). Fowler describes layering as "one of the most common techniques that software designers use to break apart a complicated software system", assuming that the architecture was already established in the 90s with the rise of client-server systems. To quote from the book:

> "I think the seismic shock here was the rise of the Web. Suddenly people wanted to deploy client–server applications with a Web browser. However, if all your business logic was buried in a rich client, then all your business logic needed to be redone to have a Web interface. A well-designed three-layer system could just add a new presentation layer and be done with it. Furthermore, with Java we saw an unashamedly object-oriented language hit the mainstream. The tools that appeared to build Web pages were much less tied to SQL and thus more amenable to a third layer.""

Also, Fowler listed some good Pros and Cons on the matter:

* Pros
  * It is easier to understand a single layer, if you do not need to know about the other layers
  * Layers can be substituted with alternative implementations
  * Dependencies between layers are minimized, making it easier to swap out a whole layer
  * Sticking to layers might produce a well-designed API, providing an entry-point to standardization
  * Layers can be reused by other higher-level services. 
* Cons
  * As not everything in a layer can be encapsulated, sometimes changes in one layer cascade to all other layers, too
  * Layers can harm performance. Every abstraction and every data transformation between layers comes with a price to pay
  
What I found interesting about Fowlers examples was, that he used examples from networking for these pros and cons. If one layer is TCP, and another layer is FTP, you can swap out the TCP layer and won't have too much change in the FTP layer. You can also build several network applications on TCP. While these examples are sensible, this is the first point that might not translate too well to enterprise software development: Usually these types of applications are used for one problem domain, and the whole code is under the control of the developers. It is unlikely that the flexibility of switching out layers is needed in such a controlled environment. So while I understand the ideas and see that they can be beneficial in certain contexts, I feel that many points on the pro-side *might* happen, while the two bullet points on the con-side *will* happen.

## Decoupling code
The first tradeoff that comes with layers is the introduction of multiple domains in your application. To truly decouple the layers from each other, every layer needs distinct classes to match their needs. In a Java application, JPA-Entities are often used to represent the records in the database. They are annotated with information to map from the Java fields to the database columns and mark dependencies between classes. They are written in a "Java Bean" style, requiring an empty constructor and Getters and Setters for every field. These entities are attached to a database session, changing them may, upon the next flush, propagate these changes to the database. 

But we do not want such statefulness in the domain layer! We want to transform our data with business logic, there, without having to worry about the changes propagating to a database! So we need to transform the data coming from the persistence layer into a different domain model. This domain model should be crafted a lot more careful then just "Java Beans". Should I be able to update all the fields? Is there a minimal state that my data needs, which is represented by special constructors? How am I able to mutate state, which functions can I use for that? 

We also need our own data model for the presentation layer, too. Maybe the domain model in the domain layer holds data that the user should never see, like remarks from customer service. So we tailor a third domain model, which is considering everything the frontend needs. 

To transform between these domain models, we need mapping code. Writing this mapping code is always a fine line – the mapping code should be side-effect free and not contain any logic. But can you really map from one domain model to the other without logic? The mapping itself is some kind of logic, isn't it? 

Writing this mapping-code is so repetitive that many libraries and frameworks exist to take this burden away from the developer. And even if written by hand, the code is usually quite straightforward. But even if the classes are decoupled, they are still just representations of very similar data. 

## You are decoupling code, not data!
Let's assume, that in our next software release uses will get a new feature to add their mobile phone number to their user profile. Obviously, the class representing the user profile needs a new field in the presentation layer, so the user can enter the value, and others can see it. The value needs to be stored somewhere, so we add it to the database, and extend the user-profile class in our persistence layer, to map to it. And finally, to move the value through our domain layer, we also add it there, and adjust all of our mappers accordingly. 

This is a lot of change for one property (and we did not even consider, if there are tests for the mappers). I am not saying that this effort is always unjustified – for large applications it may still be a good idea to follow that principle! But it is important to understand that we now have three highly coupled domain models in our application and maintaining them can become expensive.

To reference the toughts about the network layers from above: Decoupling makes perfect sense here, as every layer is an abstraction that the layers above it can use as a measure of transport. If the separate layers are concerned with the same domain models, they might not be as clear cut as in the example. What can we do about that? 
  
## It is allowed to open layers
This is the point about layered architecture, that is often misunderstood. I talked to a lot of people about this in the last two years, and only a handful knew about "Opening Layers". The presentation layer is allowed to access the persistence layer directly, skipping the domain layer. Quoting Fowler again:

> "Sometimes the layers are arranged so that the domain layer completely hides the data source from the presentation. More often, however, the presentation accesses the data store directly. While this is less pure, it tends to work better in practice. The presentation may interpret a command from the user, use the data source to pull the relevant data out of the database, and then let the domain logic manipulate that data before presenting it on the glass."
  
While Fowler states, that opening layers is done "more often", this is not what I have seen in enterprise projects in my carreer. Often, there are even static code analyses tools in place, which try to make sure that the layers are in perfect condition, without any violation, e.g. with a rule like "The presentation layer must never access the persistence layer". Even worse, for many data representations, the database, persistence layer, domain layer and presentation layer are using the same data, unmodified. We could transform it to the presentation layers' "target format" with SQL directly, skipping both the JPA representation and the domain model. Of course we need to document which layers and which part of the application are opened. Also, opening these layers should still stick to some rules: When we start writing SQL queries in the presentation layer, we sure took a wrong exit at some point. 

But why is it, that this approach is not used as widely as it should? From my experience in projects and discussions with developers and architects(!), because this architecture is often accepted "as is". Like mentioned in the beginning, in many companies this is a standard which was "just there for ages" and it is followed without fully understanding its rules, ramifications and tradeoffs.

## There is no golden rule, silver bullet, modus operandi for all
That's the bad news. There is no catch-all, single tool for everything, ring to rule them all (now my thesaurus is exhausted, too). While layered architecture is a good tool to make sure that separation of concerns is considered in your architecture, it might be overkill for your application. You also can choose, to open up layers for certain parts of your applications. Is following the layers a good idea for an enterprise app in bank, that needs to perform a lot of calculations before displaying data? Probably. Are there certain data representations in that same application, which can just be read from the database and displayed unmodified? Probably also! We need to evaluate different parts of our application, discuss the ramifications and decide. And if that part of the application changes, we might have to re-evaluate and decide differently.

As a starting point for these decisions, here are some questions I like to ask:
* Is the data displayed fetched from a single source, or multiple?
* Is the data read-only or can it be modified?
* Are calculations necessary to display that data?
* Is a fast response time for an operation nice to have or essential?

This does not leave us with a flow diagram which points us to the right answer "Open Layer" or "Don't open layer" every time, but I think they can help us to pick the right path.

## In the end, it's "It depends" again
What would I like you to take away from this article, why did I write it? I think we should read and talk about our applications architecture in more detail. While the architecture of infrastructure already gets a lot of attention (Kafka? Do we need a Redis Cache? Maybe Elasticsearch?), in many enterprise projects it is either the default to go with layering, or it is a decision between layering and hexagonal architecture. But even if there is a decision for one of those, the architecture is not just "done" with this decision. You have selected your tools, now you have to think about how to apply them. Which layers to open, which classes to decouple and abstract? Are the architectural decisions from yesterday still valid, or did the requirements change and now we need to adapt? Were our assumptions in the beginning correct, did our architecture stand the test of time? It might be a good idea to take a step back and check this, from time to time.
 
