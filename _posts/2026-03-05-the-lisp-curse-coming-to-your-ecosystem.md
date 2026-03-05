---
layout: post

title: "The LISP curse, now coming to your ecosystem!"

date: 2026-03-05 22:00:00 +0200

author: Tim Zöller

categories: programming llm
---

The LISP curse is often quoted as the reason why so few libraries and reusable components exist for LISP dialects. According to the concept, LISP is so powerful and flexible that it allows developers to create custom solutions easily, leading to them working longer in isolation. This causes them to often reinvent the wheel, because creating code to solve your own problems can be easier / faster than relying on the libraries (and way of thinking) of other people. This leads to a lack of central frameworks and libraries, like many other language ecosystems have. Sometimes it's also mentioned that this powerful, flexible code which was written in isolation often lacks documentation and can be hard to comprehend by third parties, so other developers prefer to write their own modules – and the curse keeps on.

## Yes, this post is about LLM-assisted coding
I was drawn into several discussions this week where people claimed that with the ease and quality of Large Language Models, it is now easier and cheaper to generate code than to use existing abstractions like frameworks or libraries. If we ignore the fact that established libraries are incredibly stable, tested by hundreds of thousands of developers, included in thousands of CI pipelines and maintained by experts on the topic, if we accept the assumption that it is easier to let an LLM generate functionality than to learn the interfaces of existing libraries and frameworks (or let the LLM integrate these libraries or frameworks), what would the implications for language ecosystems like Java's look like?

## More isolation, more individualism, less collaboration
A lot of people contributed to the success of Open Source ecosystems in the last decades through collaboration, collective problem solving and with the goal of solving hard problems. 

The first effect of the aforementioned scenario would be the decline of people using the open source libraries, reducing feedback to the maintainers. If I could just solve my problems with one or two prompts, 20 minutes of waiting time and a couple of dollars worth of tokens, why should I bother with research? Why should I bother with the API decisions other people made? Why should I bother with reading documentation? 

As a second effect, the creation of new Open Source libraries would stagnate. The hard part of doing Open Source is maintenance. Structuring your code, hosting infrastructure, publishing to artifact repositories. Versioning, backwards compatibility, keeping the stack up to date. If generating code is that easy, if I can solve my own problems that quickly, why should I bother modularizing the code, sharing it with the world and doing all the project management an Open Source project needs? I have everything I need in my generated module, I can break the API if I need to, adjust everything exactly to my use case, my stack. 

These two effects might even amplify each other in the long term. If fewer Open Source libraries are provided to integrate new technologies, new approaches into a language ecosystem, people might be even more inclined to just write / generate their own solution and be done with it.

## A grim outlook
As you might have already read between the lines, I don't share the assumption that we can skip adding libraries and frameworks to our code and just generate everything instead. I'd rather rely on proven libraries with well-defined abstractions than generate hundreds of lines of code which solve a local problem for me. "Not generated here" is just a different version of "Not invented here". Still, I think that Large Language Models in coding are here to stay, and that this scenario will arrive in some way. Maybe not as drastically as some thought leaders now proclaim, but by accident. Open Source collaboration will decline to some degree and software development might become a much lonelier task than it is now.
