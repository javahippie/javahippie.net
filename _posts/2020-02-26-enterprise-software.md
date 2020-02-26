---
layout: post
title:  "Thoughts on Enterprise Software"
date:   2020-02-26 10:00:00 +0200
categories: [software, business]
---

I had some interesting discussions about the term "enterprise software" lately, both online and offline. In the following post I try to sort and write down some of my thoughts and opinions on that topic. Your thoughts and opinions might differ, of course. If they do, ping me on [Twitter](https://twitter.com/javahippie) or [LinkedIn](https://www.linkedin.com/in/timzoeller/), I would love to hear them! 

# What is "Enterprise Software"?
A single definition of the term "enterprise software" doesn't exist. To quote Martin Fowler, it is "about the display, manipulation, and storage of large amounts of often complex data and the support or automation of business processes with that data". My understanding of the term is, that it describes software which is used by an enterprise to support its daily business. It might be a software supporting Accounting or HR, automating manufacturing or ordering commodities for your product. It is a software which is used by a companies employees, not its customers. 

# What is important for enterprises?
For most businesses out there, efficiency is the most important aspect about their enterprise software. This should not come as a surprise - businesses are founded to achieve a goal. This can be a laudable and valuable goal, like a NGO providing water to people in need, a pharmaceutical company developing new medication to treat diseases, or "a computer in every household". Some companies single goal is to make their owners richer, which is objectively less meaningful, but a goal nevertheless. No matter what the goal is, enterprise software is simply a tool to achieve it. If implementing and maintaining a new feature for an enterprise application will cost more money than it will save in the end, it should not be implemented, as it would be wasteful. Sticking to the example of the NGO made above: If the company is misplacing ten pallets of drinking water every year due to a confusing user interface, they could lose ~10.000€ of money every year. Redesigning the interface, implementing the changes, implementing tests for the feature, including regression tests and training users for the new interface could sum up to much more money, making the fix not desirable. Not to forget opportunity cost: The time spent developing this feature is time not spent on other features that could provide a lot more value to the company. The approach would be different for consumer or B2B software: If I sell a software product and **my customer** loses 10.000€ every year because of a faulty product, the issue should definitely be fixed, or else they won't stay customers for much longer. 

# The issue with measuring efficiency
Efficiency is a relation between cost and value. As the value a software provides can be hard to measure, many businesses obsessively track the cost of enterprise software development. But cost is only one variable in the equation, leaving the other two, value and efficiency, unknown. I cannot assess the situation outside of Germany, but especially in the traditional german industries, the IT departments are still seen as a department costing everybody else money. In the beginning of the year, the IT department estimates the money it will need in the upcoming twelve months, and the other departments have to pay their share for IT (often wondering, if all this couldn't be done much cheaper). This is changing for the better, but slowly. Concentrating on cost alone is much easier, than seeing the big picture. It is very easy to identify 750.000€ spent on developing a new software system. But how can you measure the value it provides? Was it worth spending all that money on the new system? The question can rarely be answered by looking at absolute numbers, but by comparing the "before" and "after" state. This won't give you a scientifically correct number, but an approximation. The software may benefit a business unit, because they are more efficient in their work. But if their revenue increases, which part of that can be associated to the new software? Certainly the software was not the only thing which improved in the last year? When looking at a value enterprise software provides, the following effects come to my mind:

1. The software automates a business process which was executed manually before. In this case, the manual labor required to execute the process is reduced, labor-hours are measurable in €.
2. The software has a better availability than its predecessor, there are fewer downtimes. If a system stops working, so do its users. If a company cannot satisfy its customers demands for an hour or even a day, the loss of revenue is measurable in €.
3. The software is more reliable than its predecessor, leading to fewer customer complaints. Handling these requests needs many labor-hours on the one hand, which is, again, measurable in €, as is the amount of money spent to compensate a dissatisfied customer.
4. The software is faster than its predecessor, reducing labor-hours needed to run a process, or increasing the throughput in the system. 
5. The software is easier to maintain or needs fewer ressources than its predecessor, reducing the operationg costs, which are measurable.

These value-delivering aspects of enterprise software can be summarizes as "robustness" and "performance". 

# What else is important?
While monetary efficiency is the most important matter, it is not the only one, of course. Luckily many companies also realized by now, that enterprise software is not only about crunching numbers and comparing the cost. As stated above, efficiency is about delivering the best value at a reasonable cost, and there are many "soft" aspects about software which also deliver value. For example, "even" enterprise software needs to be user centric. Contrary to private end users, users of enterprise software cannot choose to use a different system, if they are dissatisfied with their companies solution. This increases frustration, if the system they are required to use does a bad job, or slows down their daily work. While this will lead to a loss in revenue which is again measurable, it will also have additional bad effects, which are not. In my experiences, happy users tend to give a lot more feedback about ways to improve workflows and make software better. If the users impression is, that the software doesn't do a good job, anyway, and the basic functionality isn't provided, what's the point in suggesting minor improvements? If employees become more frustrated over the time, they might also quit. 

Additionally, if a new software is introduced, it is crucial to satisfy the employees that will be using it right from the start. I have seen some software rollouts, which were disturbed by initial malfunctions and downtimes, or lacked features the previous systems provided. Even if these flaws are fixed, people will remember the issues for a long time. If the whole department at one point agrees, that "the new software" keeps them from working efficiently, the developers will have a hard time making up for this, even if the software runs smoothly for months after these incidents. Once the users distrust the software department, this will also affect future software rollouts.
Another point we have not yet considered is scalability of software. Usually the expected load for enterprise software can be anticipated rather well, in comparison to consumer facing products, so it rarely needs to scale up and down automatically. But it should be written in a way, that it should be possible to scale up the application in the future. If the company is doing well and attracts four times the customers within two years, the software should at least be able to scale horizontally, without reimplementing half of it.

# What does this mean for software developers?
If you are a software developer working on enterprise software, you get payed to deliver value for your company. Of course, developing software is not the only way of delivering value. You can have great ideas to improve your companies processes, you can be the person who improves company culture, or raises everybodys mood with their charming personality. But in the first place you and your whole team are hired to deliver value with your software development skills. As the time you have available is fixed, you can maximize the value delivered by being more efficient. And this is the point where I have seen many developers struggle in the past, myself included. We tend to be an idealistic bunch of people, sometimes, who want to do it "right". And sometimes, what is right from an architecture point of view, or a clean code point of view, isn't necessarily delivering value to the enterprise. Sometimes, effort spent refactoring the software internally to make it better (according to best practices, or current fads), does nothing to improve the actual software for the users *or* the company. 

I am not advocating for sacrificing software quality and good development practices in order to deliver more features! Bad tests or bad maintainability will cost a lot of money in the long term, even if technical debt is hard to measure. I am advocating for reasoning about the value of proposed changes, instead. Above we have pointed out 5 bullet points which represent value that a software can deliver. For each of those bullet points, we can find a use case which improves value, but is not worth the cost:

1. The software automates a business process which was executed manually before, but the process is not executed often enough to break even. You spent 150.000€ for development and need 10.000€ of maintenance per year, to save 1000€ of manual labor every month.
2. The software has a better availability than its predecessor. This increases the cost of operating threefold, but now there is 99.99999% availability, including zero downtime deployments. Even if the working hours are 9 to 5, and the weekends are off...
3. The software is more reliable than its predecessor. There was an architecture issue deeply embedded in the application, and it took quite some time to finally fix this. But it payed off: Instead of getting 10 customer complaints every month, we only get 8 now.  
4. The software is faster than its predecessor. Every web request now takes 200ms instead of 350ms, because we rewrote the whole database layer.
5. The software needs fewer ressources than its predecessor. We switched to a more memory efficient framework, which took our 4 developers 3 weeks. But now we need 8GB of RAM instead of 16GB, so we will break even in 8 years.

The single denominator of these cases is narcicissm. In order to "do it right", sometimes developers deliver technical solutions to problems that nobody has. Of course those "improvements" are exaggerated, but sadly some of them are not too far off. And of course, any of these bullet points would also be bad when developing B2B- or consumer software. Also, these decisions are not up to developers alone, and can be forced upon them by others. But the relation between cost and value might be very present when writing enterprise software. Keep in mind, that your competion is standard-software off the shelve. If e.g. SAP is more flexible and less expensive than the software you are providing, you might have trouble to justify your whole software-development team, at one day. I try to remember the following three points as a rule of thumb:

1. Self-Advertise: As mentioned earlier, measuring the value of software can be hard. If nobody in your company is measuring the value your software created, try and track it yourself and point it out. Otherwise, all discussions will revolve around money spent.
2. Prioritize. Start with the features delivering the most value to the whole company. This also pays into the self-advertising - if you provide much value, it will be easier to point out your success.
3. Advise. If you can point out, that a proposed feature will be expensive but deliver no value, point it out. The business unit that ordered it might not be aware, and you could save them a lot of money.
4. Self-reflect. If you propose technical changes, e.g. in architecture or frameworks, double check with your colleagues if it will be valuable in the end, or if you are chasing the theoretical concept of "doing it right", without delivering any value.

# Summary
I don't think this post contains new or radical ideas. Maybe, while reading it, you recognized some issues from your own company, or maybe you disagree entirely. We should keep in mind, that we as software developers live in a bubble. It is easy (and sometimes fun!) to have lengthy discussions about different concepts on Frameworks: Single Page Applications or serverside rendering? Static typing or dynamic typing? Functional programming or imperative programming? Spring or Jakarta EE? While these can be valid questions, and choice of technology always has benefits and tradeoffs, we should remember to not get lost in technical discussions too much. The most important thing is, that people benefit from our software. 