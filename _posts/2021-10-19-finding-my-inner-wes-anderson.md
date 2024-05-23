---
layout: post
title:  "Finding my inner Wes Anderson with Babashka"
date:   2021-10-18 18:00:00 +0200
author: Tim Zöller
categories: clojure
---

I have found a new toy, and its name is [babashka](https://github.com/babashka/babashka). Babashka is a "Native, fast starting Clojure interpreter for scripting" by [Michiel Borkent](https://github.com/borkdude). This scripting environment packages a lot of Clojure goodness, is precompiled with GraalVM to a native binary, resulting in incredibly fast startup time. It enables developers to execute Clojure code immediately. So of course I am currently not only in the process of migrating some parts of our build pipeline to babashka, I am also writing some nonsensical scripts for fun – be it a script to [publish my current track playing in Apple Music to Slack](https://github.com/javahippie/slack-the-music), a small script to set my Desktop wallpaper to NASAs picture of the day, or other small stuff that makes me happy. This blog post is about me finding my prettiest pictures with babashka.

## The goal
Some time ago I found an article about the database of Apples "Photos" App, [Using SQL to find my best photo of a pelican according to Apple Photos](https://simonwillison.net/2020/May/21/dogsheep-photos/). The app is storing all of its data in an SQLite database, to which we can connect to. Inside, there are not only information and metadata about the photos themselves, it also contains the results of Apples machine learning algorithms which continuously analyze the photos. It is located at `~/Pictures/Photos Library.photoslibrary/database/Photos.sqlite` This sounded like a great opportunity for me to play with babashka a little more. Here are some of the columns from the table `ZCOMPUTEDASSETATTRIBUTES`:

* ZBEHAVIORALSCORE
* ZFAILURESCORE
* ZHARMONIOUSCOLORSCORE
* ZIMMERSIVENESSSCORE
* ZINTERACTIONSCORE
* ZINTERESTINGSUBJECTSCORE
* ZPLEASANTSYMMETRYSCORE

Pleaseant symmetry sounds nice to me. So, let's go looking for my most Anderson-esque picture with Clojure!

## The SQL-Part

Each column has a reference to the `ZASSET` table, which stores all of the images for the Photos app. The higher the value in a column, the better the picture matches the column description. First, we needed an SQL script to give us the UUID for the best photo in a category:

```sql
select asset.ZUUID
from ZCOMPUTEDASSETATTRIBUTES attr
left join ZASSET asset
on attr.ZASSET = asset.Z_PK
order by ZINTERESTINGSUBJECTSCORE desc
limit 1
```

The UUID belongs to this picture, which means my Macbook thinks the most interesting picture I have ever taken is a flock of seagulls. Good start!

![Seagulls in flight](/assets/20211019/mostinteresting.jpeg "Very interesting.")

## The Apple Script part
Unfortunately, not all of my photos are on my Mac, some are in the Apple Cloud. Although the original photos stored on my drive are renamed with their UUID and stored neatly in a folder, most of the photos were not there, and I could not simply access the filesystem in order to extract them. Luckily, it turns out you can "remote control" Apple Photos with AppleScript! After some trial and error, I came up with the following script to extract a photo by its UUID:

```AppleScript
tell application "Photos"
    set theitem to media item id "E8555C22-BE76-4153-AE11-C535C070C952"
    set thePath to POSIX path of "/tmp"
    export {theitem} to thePath
end tell
```

The the library docs for AppleScript are okay, but I cannot say that I really like the language. It's no fun, it's frustrating to get the syntax right, and just somehow counterintuitive. AppleScript can be run from the commandline with the command `osascript -e <THESCRIPT>`, so calling this script that way will export the photo with the given UUID to `/tmp` with its original format: JPEG, HEIC or RAW.

## The babashka part
Before we dive into the code: Developing simple scripts in a REPL is a lot of fun. Instead of "change, save, run", we an build and test the single functions in
our script in isolation and stick them together, once everything works. As I use Emacs and Cider, I started a REPL with the command `bb --nrepl-server` in the shell were my script was present, and then connected Cider to that nrepl server. 

This style of development matches my brain really well, as I am easily distracted and sometimes can have a hard time concentrating. Short feedbackcycles for the win! So, Having solved the prerequirements, let's start hacking!

### SQL

First we want to connect to the database. Luckily, [there is a Pod for that](https://github.com/babashka/pod-babashka-go-sqlite3). Babashka pods are small applications which can be used as libraries in babashka. The don't have to be written in Clojure, though: The SQLite pod is written in Go, for example. Pods need to be referenced in the script, and can then be required:

```clojure
(require '[babashka.pods :as pods])
(pods/load-pod 'org.babashka/go-sqlite3 "0.0.1")
(require '[pod.babashka.go-sqlite3 :as sqlite])

(def sqlite-path "/users/zoeller/Pictures/Photos Library.photoslibrary/database/Photos.sqlite")

(def query ["select asset.ZUUID
from ZCOMPUTEDASSETATTRIBUTES attr
left join ZASSET asset
on attr.ZASSET = asset.Z_PK
order by ZINTERESTINGSUBJECTSCORE desc
limit 1"])

(sqlite/query sqlite-path query)
;;=>  [{:ZUUID "E8555C22-BE76-4153-AE11-C535C070C952"}]
```

That's all about SQL, that's the whole code. No other setup needed. If executed in a script from the command line (`bb ./my-file.clj`), this returns almost immediately. No JVM startup, no Clojure init time. 

### AppleScript
Of course, I could simply use Selmer (which is supported by babashka) as a templating engine, store the AppleScript code as a String and replace the UUID I want. But where is the fun in that? I wondered, if I could write some kind of primitive DSL for that, so I did not need another dependency. And I could – in a way:

```clojure
(def applescript '[tell application :photos \newline
                     set theitem to media item id :uuid \newline
                     set thePath to POSIX path of :path \newline
                     export \{theitem\} to thePath \newline
                   end tell])

(defn as-applescript [script params]
  (reduce #(str %1 " " %2)
          (for [token script]
            (cond
              (keyword? token) (str "\"" (get params token) "\"")
              (char? token) token
              :else (name token)))))
```
This is rather dirty, but it works for my limited usecase: The escaped vector contains symbols which resemble the symbols from applescript. Unfortunately, AppleScript uses syntactic whitespace, the line breaks are mandatory. Also, it uses curly braces in its syntax, and the Clojure Reader is not a fan of curly braces with just one element in them, even in escaped vectors. So I added the newline and the braces as characters in the vector. The keywords work as parameters, and can be passed to the script creator as a map:

```clojure
(as-applescript applescript
                {:photos "Photos"
                 :uuid "E8555C22-BE76-4153-AE11-C535C070C952"
                 :path "/tmp"})
                       
;;=> "tell application \"Photos\" \n set theitem to media item id \"E8555C22-BE76-4153-AE11-C535C070C952\" \n set thePath to POSIX path of \"/tmp\" \n export { theitem } to thePath \n end tell"
```

For now I am happy with that. While doing this, I also remembered that I always wanted to look up how to properly design small domain specific languages, so I'll add that to my "To Do" list, too.

### Tying it all together

Here is the final result in 42 lines of code:

```clojure
#!/usr/bin/env bb

(require '[babashka.pods :as pods])
(pods/load-pod 'org.babashka/go-sqlite3 "0.0.1")
(require '[pod.babashka.go-sqlite3 :as sqlite])
(require '[clojure.java.shell :refer [sh]])

(defn query-db []
  (let [sqlite-path "/users/zoeller/Pictures/Photos Library.photoslibrary/database/Photos.sqlite"
        query "select asset.ZUUID
from ZCOMPUTEDASSETATTRIBUTES attr
left join ZASSET asset
on attr.ZASSET = asset.Z_PK
order by ZPLEASANTSYMMETRYSCORE desc
limit 1"]
    (sqlite/query sqlite-path [query])))

(def applescript '[tell application :photos \newline
                     set theitem to media item id :uuid \newline
                     set thePath to POSIX path of :path \newline
                     export \{theitem\} to thePath \newline
                   end tell])

(defn as-applescript [script params]
  (reduce #(str %1 " " %2)
          (for [token script]
            (cond
              (keyword? token) (str "\"" (get params token) "\"")
              (char? token) token
              :else (name token)))))

(defn export-photo [uuid path]
  (sh "osascript" "-e"
      (as-applescript applescript
                      {:photos "Photos"
                       :uuid uuid
                       :path path})))

(for [{:keys [ZUUID]} (query-db)]
  (if (= 0 (:exit (export-photo ZUUID "/Users/zoeller/Desktop/test")))
    (str "Exported " ZUUID)
    (str "Did not export " ZUUID)))
```

The shebang in the beginning tells my OS that this is a babashka script. I can now just execute it with `./epp.clj` on the command line (Export Pretty Pictures). It works exactly like I imagined. So... what **is** my picture with the most pleasant symmetry? It's this one:

![Zinnengasse in Zürich](/assets/20211019/mostsymmetric.jpeg "Very symmetric.")

Well... at least the journey was fun.

## What else to do with this
Aside from the (underwhelming) categorizations like "Most pleasant symmetry", there is a lot of interesting stuff in that database. There is a whole table dedicated to facial recognition, storing if people smiled, how much they smiled, if their left or right eye was closed and what type of facial hair they had. So we could build queries to find the most beautifully lit foto of a smiling man with a beard having one eye closed. I will certainly have some more fun with this, but I won't show any pictures of other people here, so I will keep those to me ;) 
