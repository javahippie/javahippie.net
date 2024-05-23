---
layout: post
title:  "Cloudready Clojure Part 2"
date:   2020-04-21 12:00:00 +0200
author: Tim Zöller
categories: clojure cloud
---

This is part 2 of a series in which I will show some of my approaches to a "Cloud Ready" web application with Clojure. If you are new to web apps with Clojure, you should read the first part, [Cloudready Clojure Part 1](/clojure/cloud/2020/04/20/clojurenative01.html) first, where we set up a webserver and the base for serverside HTML rendering.

## Cloud Ready Configuration
The example from the first part was kept simple on purpose, to clarify on how to use the technology that was explained. But in this simple program, you can already spot a bad pattern when you want to run your application in the cloud:

```clojure
(defn -main
  "Starts the web server and the application"
  [& args]
  (run-jetty app-handler {:port 80}))
```	

We hardcoded the HTTP port to 80, which is a bad idea. In many cloud environments, you don't get to choose on which port your application will listen. If you want to deploy to Heroku (which we will do later), you will even need to use a port that the Cloud Provider assigns to you randomly, and is stored in a `$PORT` environment variable. You could access this environment variable with the call `(System/getenv "PORT")`, but then you will need to provide the `$PORT` variable in all your environments. You could also pass it as a parameter to the function, once your file is compiled, like this: `java -jar -Dport=$PORT my-app.jar`, but what if you have many different configurations you need to specify? You don't want to pass 50 command line parameters every time you start the application, do you? It would be ideal to have a standard configuration, maybe as a properties file, which can be overridden by environment variables or command line parameters, if needed. This mechanism is provided by the library [yogthos/config](https://github.com/yogthos/config). To quote from its documentation, it provides several config mechanisms, which are resolved in the following order:

* config.edn on the classpath
* .lein-env file in the project directory
* .boot-env file in the project directory
* EDN file specified using the config environment variable
* Environment variables
* Java System properties

First we need to add the library to our dependencies in `build.boot`:

```clojure
(set-env! :resource-paths #{"resources" "src"}
          :source-paths   #{"test"}
          :dependencies   '[[org.clojure/clojure "1.10.0"]
                            [adzerk/boot-test "1.2.0" :scope "test"]
                            [ring "1.8.0"]
                            [rum "0.11.4"]
                            [yogthos/config "1.1.7"]])
```

After this step, we can create a local configuration file at the path `resources/config.edn`, which contains basic configurations and default values. In our case, it will just contain the HTTP Port for now:

```clojure
{:port 80}
```

The configuration file is written in EDN, which is a very fitting format for Clojure applications ;) We can access the value with a call to `config.core/env`, to which we will refer to in the head of our `core.clj` file:

```clojure
(ns scrapbook.core
  (:require [ring.adapter.jetty :refer [run-jetty]]
            [rum.core :refer [defc render-static-markup]]
            [config.core :refer [env]])
  (:gen-class))
```

This allows us to access our configuration via keywords, as we are used to accessing data in Clojure: 

```clojure
(defn -main
  "Starts the web server and the application"
  [& args]
  (run-jetty app-handler {:port (:port env)}))
```

Not only have we moved the configuration of our application to a single file, which is more maintainable, we also can override this property, either by specifying an environment variable `$PORT`, or by passing the port via parameter: `java -jar -Dport=80 my-app.jar`. This is sufficient for all modern cloud environments, container runtimes and platforms.

## Enhancing our web stack
Currently our application is serving HTTP content, but it does not do it in a very good way. There is no session handling, we cannot set cookies, we are not secured agaist Cross Site Forgery, and some more. It is very easy to enhance Ring with additional functionality, so called middlewares to achieve these goals. You can either compose your stack with the middlewares of your choosing, or you can decide to use a ready-to-go configuration from the [ring-defaults](https://github.com/ring-clojure/ring-defaults) library. To clarify the advantage of this, I will again quote from the documentation:


> There are four configurations included with the middleware
> 
> api-defaults
> 
> site-defaults
> 
> secure-api-defaults
> 
> secure-site-defaults
> 
> The "api" defaults will add support for urlencoded parameters, but not much else.
> 
> The "site" defaults add support for parameters, cookies, sessions, static resources, file uploads, and a bunch of browser-specific security headers.
> 
> The "secure" defaults force SSL. Unencrypted HTTP URLs are redirected to the equivlant HTTPS URL, and various headers and flags are sent to prevent the browser sending sensitive information over insecure channels.

For simplitities sake we will omit ssl configuration, and wrap our ring handler with the `site-defaults` configuration. Of course, this means adding another dependency first:

```clojure
(set-env! :resource-paths #{"resources" "src"}
          :source-paths   #{"test"}
          :dependencies   '[[org.clojure/clojure "1.10.0"]
                            [adzerk/boot-test "1.2.0" :scope "test"]
                            [ring "1.8.0"]
                            [rum "0.11.4"]
                            [yogthos/config "1.1.7"]
                            [ring/ring-defaults "0.3.2"]])
```

After that, we refer to `wrap-defaults` and `site-defaults` in the header of `core.clj`, and wrap our handler with the `site-defaults` configuration. The complete program looks like this, now:

```clojure
(ns scrapbook.core
  (:require [ring.adapter.jetty :refer [run-jetty]]
            [rum.core :refer [defc render-static-markup]]
            [config.core :refer [env]]
            [ring.middleware.defaults :refer [wrap-defaults site-defaults]])
  (:gen-class))

(defc html-frame []
  [:html
   [:head
    [:title "A Scrapbook"]]
   [:body
    [:h1 {:id "main-headline"} 
     "Welcome to Scrapbook, Stranger!"]
    [:div {:id "min-content"} 
     "We hope you will like it here"]]])

(defn app-handler [request]
  {:status 200
   :headers {"Content-Type" "text/html"}
   :body (render-static-markup (html-frame))})

(defn -main
  "Starts the web server and the application"
  [& args]
  (run-jetty (wrap-defaults app-handler site-defaults) {:port (:port env)}))
```

When we call [http://localhost:80](http://localhost:80) again and inspect the site with the developer tools of our browser, we can observe that we are now provided with a session cookie, content headers and security headers, which were not there, before. 

## Session data and parameters

The data of the session is provided via ring in a neat functional style: It is handed to us in the `request` map and accessible with the keyword `:session`. If we want do add data to the session, we add it with the `:session` keyword to the response map which is provided by our handler. To inspect all data which is contained in the `request` variable, we pass it to our `html-frame` component as a parameter and output it in our component as text:

```clojure

(defc html-frame [request]
  [:html
   [:head
    [:title "A Scrapbook"]]
   [:body
    [:h1 {:id "main-headline"} 
     "Welcome to Scrapbook, Stranger!"]
    [:div {:id "min-content"} 
     (str request)]]])

(defn app-handler [request]
  {:status 200
   :headers {"Content-Type" "text/html"}
   :body (render-static-markup (html-frame request))})
```

The `request` map is shown unformatted, but in my case the result of a call to [http://localhost:80?name=javahippie](http://localhost:80?name=javahippie) looks like this: 

```clojure
{:ssl-client-cert nil, 
 :protocol "HTTP/1.1", 
 :cookies {"ring-session" {:value "485b3e4e-8555-4a5b-a367-98d6e87a4cf9"}}, 
 :remote-addr "0:0:0:0:0:0:0:1", 
 :params {:name "javahippie"},
 :flash nil, 
 :headers {"sec-fetch-site" "none", 
           "host" "localhost", 
           "user-agent" "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.163 Safari/537.36", 
           "cookie" "ring-session=485b3e4e-8555-4a5b-a367-98d6e87a4cf9", 
           "sec-fetch-user" "?1", 
           "connection" "keep-alive", 
           "upgrade-insecure-requests" "1", 
           "accept" "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9", 
           "accept-language" "de-DE,de;q=0.9,en-US;q=0.8,en;q=0.7", 
           "sec-fetch-dest" "document", 
           "accept-encoding" "gzip, deflate, br", 
           "sec-fetch-mode" "navigate", 
           "dnt" "1", 
           "cache-control" "max-age=0"}, 
 :server-port 80, 
 :content-length nil, 
 :form-params {}, 
 :session/key nil, 
 :query-params {"name" "javahippie"}, 
 :content-type nil, 
 :character-encoding nil, 
 :uri "/", 
 :server-name "localhost", 
 :anti-forgery-token "k9yAt7T0D51har5HY9ERbTPPU/60omW7gDVqf+Ry54ezMFGb9/o9OkRUK9CfRWZNQ+gWKtS4XDBfrXb7", 
 :query-string "name=javahippie", 
 :body #object[org.eclipse.jetty.server.HttpInputOverHTTP 0x23f229b2 "HttpInputOverHTTP@23f229b2[c=0,q=0,[0]=null,s=STREAM]"], 
 :multipart-params {}, 
 :scheme :http, 
 :request-method :get, 
 :session {}}
```
This is a whole lot to unpack, so we will focus on the parts which are important to us right now:

* `:cookies` contains a map of the cookies the browser sent to us. In our case, it contains a session id
* `:params` contains the parameters. Sent by the browser. These can be query params or form params, and instead of a "string string" map, ring refines it as a "keyword string" map for us. We can see the HTTP Parameters I provided in the URL earlier
* `:headers` contains all headers sent by the browser as a map
* `:anti-forgery-token` This is added by one of the ring middlewares provided by the `site-defaults` config to prevent request forgery attacks
* `:body` contains the body of a HTTP request, if one is present
* `:request-method` contains the request method, :get, :post, :put and so on
* `:session` contains data we want to store in the session. It is empty for the request

If we wish to store data in our session, we need to output it along with our response map, as discussed above. For our example, we would like to store a static username in the session, after the first call:

```clojure
(defn app-handler [request]
  (let [{session :session} request]
    {:status 200
     :headers {"Content-Type" "text/html"}
     :body (render-static-markup (html-frame request))
     :session (assoc session :username "javahippie")}))
```

This adds the key `:username` to our session. It will be handed to us with the session from now on for every new request by ring, and we can observe that: When we open the webpage for the first time, there is no such key in the session. If we open the page for the second time, the key `:username` with the value `javahippie` appears.

## Prospect
After this part of the blog series, our application feels much more than a full web application than it did before. We added configuration which will continue to work in a cloud environment and improved our web stack a lot. Unfortunately, the session data is currently stored in the applications memory, which is not a good fit for cloud environments. If we decide to start our application multiple times and put a loadbalancer in front of it, the requests of a user always need to be sent to the same instance behind the loadbalancer. If this instance is stopped, the session data is gone. We will take a closer look at this and fix it in the next part of the blog series, stay tuned!
