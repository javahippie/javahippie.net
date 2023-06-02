---
layout: post

title: "Work like nobody is watching"

date: 2023-06-02 17:00:00 +0200

author: Tim Zöller

categories: culture

background: /assets/mooswald.jpeg
---

In the last months (I started this as a draft in February) there were a lot of news in the tech industry. While most of them were related to layoffs or personal
drama about the owners of social media companies, there was also a lot of coverage about AI. After OpenAI made a big
impression with ChatGPT and the announcement to collaborate with Bing, Google announced their own AI "Bard" and rushed
to beat Microsofts AI demo with their own
announcement. [Which did not exactly go well.](https://www.theverge.com/2023/2/8/23590864/google-ai-chatbot-bard-mistake-error-exoplanet-demo).
But don't worry, this is not another post about AI. This post is about expectations other people have about our work,
and how they impact what we do in our tech jobs.

## Are your decisions at work technical, or driven by expectations?

Software Architecture can be seen as a set of decisions which are made about the way our software is structured and the
approaches it uses. In an ideal world, these decisions are purely technical and made for the benefit of our application.
In the real world however, they are often heavily influenced by external expectations. While some of these expectations
might be justified, there are also expectations which are more rooted in social pressure: Developers want to use new
technology,
so why not build the Frontend with that new JS Framework...? This will also make it easier to hire new developers, so
it's not only an expectation of the developers, but also of HR. Also, by showing our shareholders that we are eager to
modernize our stack, we can reassure them that we are at the front of modern tech!

## Existing expectations of shareholders

Before looking at the topic with a focus on our day jobs, let take a look at the big picture which gave me the idea,
first. If your company is publicly traded, you will have to accept that your shareholders will have expectations on how
you manage your company. They want to be sure that the shares they hold will be more valuable in the future and want the
managers of the company to prioritize the shareholder value. Some might argue that the worth of a company at a stock
exchange is tied to the actual value and prospects of the company, but in my opinion the correlation is not that easy. A
lot of the market value is influenced by public image and perception. People don't buy shares in a company because they
believe it is valuable now, but they believe that it will be more valuable in the future. This belief needs to be upheld
and fed by management at all cost. This is why speeches, articles and public statements of CEOs always aim at
shareholders and the public, even if they address the employees on the surface.

From an economic perspective, it makes sense to satisfy the expectations of shareholders. They are the people and
companies providing the capital which the companies need to work, after all. In the case of mass layoffs,
[which might not really "save money"](https://www.gsb.stanford.edu/insights/why-copycat-layoffs-wont-help-tech-companies-or-their-employees),
it is also helpful to take a look at these expectations. There seems to be a pattern which
shows, [that stock prices for companies who announce layoffs rise.](https://www.forbes.com/sites/jonathanponciano/2023/01/23/spotify-alphabet-and-meta-lead-tech-stock-surge-after-massive-layoff-announcements/)
This seems to be counterintuitive: Are layoffs not a signal that the company is not doing well? Won't the severance
packages and benefits which have to be paid cost a lof of money? That the management which is currently in charge has
misjudged the market, over hired and wasted the shareholders' money? Well, yes and no. Another way to read the
layoffs and the attached press statements is: "We have made mistakes in the past, but we have now taken measures to make
sure that the shareholder value will go up in the future". It is a message saying "we see your expectations and acted
accordingly". This fits the fact, that a major investor pushed Google to lay off even more
people [in a statement](https://www.theguardian.com/technology/2022/nov/15/major-investor-calls-on-google-owner-to-aggressively-cut-staff-and-pay).
The shareholders see layoffs at other tech companies, see that the price of their stock surges, and wonder why
management is not doing the same. It is an economic decision, but not one that is tied to the actual business the
company is in.

## Satisfying the expectations

The gap between "decisions made with shareholders in mind" and "decisions made with the customers / business in mind"
was very clear with the announcement of Google Bard. Microsoft announced the collaboration with ChatGPT earlier,
[leaked a short preview](https://www.theverge.com/2023/2/3/23584675/microsoft-ai-bing-chatgpt-screenshots-leak) showing
that the integration was surprisingly far ahead. This created the impression, that Microsoft was investing heavily in
Bing, equipping it with AI and working on the next generation of search engines after Bing was more or less failing for
over a decade. This could only be perceived as a threat for Google Search, which is assumed to have ~92% market share of
all search engines. Even worse for Google, it raised fear among shareholders, that the worth of the Alphabet stock might
decrease in the future. Google had to act to counter these
fears, [and announced their own AI, Bard](https://blog.google/technology/ai/bard-google-ai-search-updates/). They had to
let their shareholders know, that they were not far behind Bing and OpenAI, and had to let them know quickly. They tried
to beat Microsofts press conference in order to take some attention away from them. Unfortunately, by rushing the
decision [they showed the AI making a factual error](https://www.theverge.com/2023/2/8/23590864/google-ai-chatbot-bard-mistake-error-exoplanet-dem)
in a promotional
video, [which crashed their stock by 9% and reduced their perceived worth by 100 billion dollars.](https://www.reuters.com/technology/google-ai-chatbot-bard-offers-inaccurate-information-company-ad-2023-02-08/)

## Smaller expectations

Most people won't have to communicate to shareholders in their day-to-day job, but I find it helpful to reflect in
regular intervals if the decisions we take are influenced by the subject, or if external expectations are playing a
part, too. Do we use React because it is the best fit, or I believe that I won't find developers when I cannot tell them
about our hip tech stack at the next conference? Do I run my application in the cloud because it is the easiest or most
cost-effective way to do it, or does the C-level require it to signal the modern infrastructure to the investors? Do I
port my small-ish application to Quarkus on GraalVM Native Image because I need the startup time, or do I want to brag
about it to fellow developers and tie my self-worth to the fact that my tech-stack is very recent? And what is the cost
of every of these decisions to the use case I am really trying to solve? 