---
layout: post

title: "Clickbaiting Mastodon instances"

date:   2022-12-18 13:00:00 +0200

author: Tim Zöller

categories: clojure mastodon

---

If you visit this site, it is possible that you fell for some clickbait! No worries, this is just a small script I
wrote for myself for fun. It makes use of the fact, that each Mastodon instance generates its own HTTP preview, so the
preview you saw in your client contained a headline which mentioned the Mastodon instance you are on.

## How does this work?

When a post which contains a link gets federated to a mastodon instance, the instance will query the address which is
contained and generate a web preview. This also happens for private messages (or restricted posts), so don't toot any
links which contain credentials. Even better, don't use such links ever!

When the Mastodon server creates the preview, it tries to be a good citizen of the web and uses an expressive User Agent
string. In the case of the instance I am on, it looks like this:

`http.rb/5.1.0 (Mastodon/4.0.2; +https://freiburg.social/) Bot`

It contains the Ruby version, the Mastodon version *and the hostname of the instance*. We can play around with this and
generate a web preview which is tailored to the instance itself. Every user will see the preview mentioning their
instance:

![img.png](/assets/20221218/img.png)

If you click on the link, though, and your user agent is not recognized as a Mastodon instance, you will be redirected
to this blog right here.

## Where's the code?

Glad you asked! Here is the small babashka script which hosts the logic. :

```clojure
(ns core
    (:require [org.httpkit.server :as srv]
      [hiccup2.core :refer [html]])
    (:import (java.time LocalDateTime)))

(defn logged [user-agent-string]
      (spit "user-agents.log" (str user-agent-string ";" (.toString (LocalDateTime/now)) "\n") :append true)
      user-agent-string)

(defn extract-instance-name [user-agent-string]
      (let [[_ version host] (re-find #"\((.*).?\;.?\+https:\/\/(.*)\/\)" user-agent-string)]
           (if (and version (.contains version "Mastodon"))
             host
             nil)))

(defn extract-client-info [{:keys [headers]}]
      (extract-instance-name (logged (get headers "user-agent"))))

(defn handle-request [request]
      (let [host (extract-client-info request)]
           (if host
             (let [bait (str "Why " host " is the best Mastodon instance to be on!")]
                  {:headers {"content-type" "text/html"}
                   :body
                   (str (html [:html
                               [:head [:title bait]]
                               [:body [:h1 bait]]]))})
             {:status  301
              :headers {"Location" "https://javahippie.net/clojure/mastodon/2022/12/18/clickbait.html"}})))

(srv/run-server #'handle-request
                {:port 80})
```

The code is also [on GitHub](https://github.com/javahippie/clickbait)

