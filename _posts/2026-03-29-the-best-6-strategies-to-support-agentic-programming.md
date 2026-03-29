---
layout: post

title: "The best 6 strategies to support agentic programming"

date: 2026-03-29 12:20:00 +0200

author: Tim Zöller

categories: programming llm
---

Agentic programming ("vibe coding") is everywhere. In this article I'd like to share my top 6 strategies to support
LLM agents in writing, building and deploying good, structured and reliable code:

## 1. Provide a README.md
Your agent's memory is short, and sometimes you onboard new LLMs from new vendors who don't already have a working memory
of your code. Provide a comprehensive README.md in your code, so they can pick it up and gain key insights into your
codebase:
* What is the purpose of this code?
* Why was the technology stack selected?
* How can the architecture be described?
* How is the code structured and organized?
* What are the code styles?
* What are commit message conventions?
* How can the application be built and tested?

This always provides a good starting point for agents and will save a lot of time and tokens, because they don't have
to read the whole codebase when starting work.

## 2. Provide and maintain comprehensive documentation
While the README.md is a good start, you absolutely need to provide well-written documentation to your LLM. This means both inline in the
code and as standalone documents. Describe the architecture, its intent and the decisions that led to its design. Describe the value your
software provides, how it interacts with users, and what the business requirements are. Written text is a good
way to start, but you should support it with graphics and schematics. LLMs can read these and get a good understanding of the
technical aspects and requirements for your application. If your coding agents need to make assumptions about your requirements
or your architecture, they might develop features and functionality you don't need or which actually harm your application.

## 3. Modularize your codebase, if possible
While the context window for LLM is becoming bigger and bigger, they still can not see the context of the whole application
at once, most of the time. Working on smaller, mostly self-contained modules with clear purpose and interfaces keeps this
"mental load" down and prevents changes made by the agent from bleeding into other parts of your application. Bonus points
if visibility of internal parts is low, so internal refactorings can happen without breaking access by other modules.

## 4. Tests, tests, tests
Good tests act as your spec. They describe the intended behavior of your application. In a perfect world, they align with the 
requirements in your documentation. As already described above, the LLM cannot see the whole context of your application and
might break existing functionality when implementing new features. By running unit and integration tests, the agents get instant feedback about
introduced bugs and can adjust their approach to make sure they don't break anything. They are still 
unreliable and prone to making mistakes, after all.

## 5. Have a reliable build pipeline
Your agents are expensive, they shouldn't be wasting time running deployments of your application manually. Mistakes in
this process are expensive and can cause downtime, too, so why not automate deployments? On new commits, run the entire
test suite, do a static code analysis for common mistakes, analyze for known security issues, package the application
in a standardized way and deploy it automatically to save tokens and avoid hallucinations while interacting with your
infrastructure.

## 6. Extensive logging and tracing
Once your application is running in production it is essential to write logs or use tools like OpenTelemetry to gain 
insights into your running app. When an error occurs and your LLM needs to analyze a bug report, it is very helpful
to provide additional context for the fix. A stacktrace or a long-running trace on a database operation is worth more than
a thousand words and can help the LLM to fix, test and deploy a solution in a short timeframe.

We all know that new technologies need new approaches in software development, so I hope this article can help you introduce
new strategies and behaviors into your workplace to make the best use of agentic programming. I heard, they might help
human developers, too.
