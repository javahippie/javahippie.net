---
layout: post

title: "Deleting AWS Glacier vaults with babashka"

date:   2022-07-23 12:00:00 +0200

author: Tim Zöller

categories: clojure

background: /assets/feldberg_clouds.jpeg
---

Before moving everything to the cloud, a QNAP NAS in my office was my central backup unit. All my devices were synced
there. This meant, that my main backup device was, most of the time, in the same room as my other devices, which is not
ideal in case of a fire or flooding. After comparing prices, I decided to use QNAPs integrated AWS glacier feature to
push my backup to the cheap AWS service as an offsite backup. In the meantime, I decommissioned my NAS, and the backups
stopped. Last week I realized I don't need it anymore, but it still appeared on my bill every month, so I decided to get
rid of it. How hard could it be, right?

## Trying to delete a Glacier Vault in the AWS console

Unfortunately, it is not that easy. After trying to delete the vault in the AWS web console, an error message told me
that it is not possible to delete a vault as long as it still contains archives. I had to delete the archives, but that
was only possible via the Java or .net SDK, REST calls or the AWS CLI. I decided to use the AWS CLI, as it seemed to be
the simplest
and [the documentation](https://docs.aws.amazon.com/amazonglacier/latest/dev/deleting-an-archive-using-cli.html) was
really straightforward.
If we want to delete an archive from an AWS vault, we first have to start an inventory retrieval job which collects all
the archives in a vault:

```shell
aws glacier initiate-job --vault-name myVaultName \
                         --account-id 123456789012 \ 
                         --job-parameters "{\"Type\":\"inventory-retrieval\"}"
``` 

This returns a JSON payload containing the ID of the job we just started which can be used to query the status of the
job:

```shell
aws glacier describe-job --vault-name myVaultName \
                         --account-id 123456789012 \
                         --job-id <THE_ID_OF_THE_JOB>
```

Fetching the job status immediately, we receive an answer that the job is still running. The job execution might take a
long time, in my case it took 7 hours – in which we have to query the job again and again. My recommendation is to just
query it the day after, the result will still be there.

When we finally receive a JSON payload containing the key and value pair `{"completed: true}`, we can query the result
of the job as a JSON file:

```shell
aws glacier get-job-output --vault-name myVaultName \
                           --account-id 123456789012 \
                           --job-id <THE_ID_OF_THE_JOB> \
                           output.json
```

As my vault was quite big, it downloaded 1.5GB of JSON data to my disk. The file contained ~220k archive entries, each
with its own ID. For **every** archive, we now have to send a deletion request:

```shell
aws glacier delete-archive --vault-name myVaultName \
                           --account-id 123456789012 \
                           --archive-id <THE_ARCHIVE_ID>
```

As you can imagine, my plan to delete the archives manually, came to a grinding halt at this point.

## Scripting the deletion steps with babashka

[babashka](https://babashka.org), a native scripting runtime using Clojure, has become my tool of choice for small
scripting tasks, so I decided to use it for this task, too. The following code is meant to be run very rarely, so I did
not bother to write a lot of error handling. It is a utility script, after all.

I might need to run this script later again, so I decided to automate *all* of the steps mentioned above, starting with
the inventory retrieval job:

```clojure
(require '[cheshire.core :as json])
(require '[clojure.java.shell :refer [sh]])
(require '[clojure.tools.cli :refer [parse-opts]])
(require '[taoensso.timbre :as t])

(defn parse-output [output]
      (json/decode (:out output)))

(defn create-job-file! [jobId]
      (spit ".running-job" jobId))

(defn start-inventory-retrieval!
      "Starts an inventory retrieval job for the given vault and account id.
      Stores the job-id in a file, to remember it for later."
      [account-id vault-name]
      (t/info "Starting inventory retrieval")
      (->
        (sh "aws" "glacier" "initiate-job"
            "--vault-name" vault-name
            "--account-id" account-id
            "--job-parameters" "{\"Type\":\"inventory-retrieval\"}")
        parse-output
        (get "jobId")
        create-job-file!))
 ```

Starting with the required Clojure libraries, I added `cheshire` for JSON processing, `clojure.java.shell` to access the
AWS CLI, `clojure.tools.cli` to work with command line parameters and `taoensso.timbre` for logging. The
function `start-inventory-retrieval` uses two utility functions: `parse-output` to decode the JSON result into a Clojure
data structure and `create-job-file!`, which stores the ID of the started job in a local file to remember it for later.
It's parameters, `account-id` and `vault-name` will be passed from the command line later, but I simply `def`ed them
globally during development.

The next function to add was `job-finished?`. Again, we need the `account-id` and the `vault-name` as parameters, but
will read the Job ID directly from the stored file with the helper function `read-job-from-file!`. It would be nicer and
more clojure-y to pass the job-id as a parameter, too, but this is a script, and the JOB ID will never come from
anywhere else than this file. For a similar reason, we skip error checking entirely, we just assume that the file is
there and will contain a valid Job ID. If the inventory retrieval job was finished, the function returns true, if it is
still running, it will return false.

```clojure
(defn read-job-from-file! []
      (slurp ".running-job"))

(defn job-finished?
      "Returns true if the triggered job was finished, false otherwise."
      [account-id vault-name]
      (t/info "Sending request for job description")
      (let [job-result (parse-output
                         (sh "aws" "glacier" "describe-job"
                             "--vault-name" vault-name
                             "--account-id" account-id
                             "--job-id" (read-job-from-file!)))]
           (get job-result "Completed")))
  ```

If the job retrieval is finished, we need to download its output with the function `get-job-output!` to the
file `output.json`. Again, we are using the Job ID from our local file:

```clojure
(defn get-job-output!
      "Downloads the result of the triggered job to 'output.json'"
      [account-id vault-name]
      (t/info "Downloading result of inventory job to 'output.json")
      (parse-output (sh "aws" "glacier" "get-job-output"
                        "--vault-name" vault-name
                        "--account-id" account-id
                        "--job-id" (read-job-from-file!)
                        "output.json")))
```

Now we have everything we need to trigger the deletion of all archives in the vault. To start the deletion process, we
use the function `delete-archives!`:

```clojure
(defn delete-archives!
      "Deletes all archives found in the previously downloaded 'output.json' file"
      [account-id vault-name]
      (let [archives (-> "output.json"
                         slurp
                         json/decode
                         last
                         val)]
           (t/info "Found " (count archives) " archives in the vault. Deleting!")
           ; pmap is usually not safe for side effects, as we have little control
           ; about the context. But here, it is okay-ish, as we just want the side
           ; effects to be executed and don't care about the rest.
           (doall
             (pmap (fn [{:strs [ArchiveId]}]
                       (t/info "Deleting " ArchiveId)
                       (sh "aws" "glacier" "delete-archive"
                           "--vault-name" vault-name
                           "--account-id" account-id
                           "--archive-id" ArchiveId))
                   archives))))
```

We load the list of archives from `output.json`, extract the IDs from it and delete them in parallel via `pmap`. My
first draft did not introduce any concurrency, but deleted the archives sequentially via `doseq`, but it turned out it
only managed to delete 1-2 archives per second and if you have 220k archives to delete, that's not fast enough. If you
have worked with concurrency in Clojure before, you might now that `pmap` is not the best solution for executing side
effects ([more detail in this excellent blog post by Ben Sless](https://bsless.github.io/mapping-parallel-side-effects/))
. In our case, these concerns are not valid, as we just want to trigger a side effect for every ID and don't care about
the results. It's a utility script after all, we can afford to be a little dirty 😉.

## Tying it all together

We now have created functions to wrap all the AWS CLI commands we have used manually before and added a way to trigger
the deletion for a whole file of archives. Now we want to turn the code into a real utility script, add parameters and a
little state handling, so the script can just be called again and again, and just perform the next possible step. For
the first part, we define our arguments with `clojure.tools.cli`. We then use these parameters in the body of the script
to execute all the previously defined functions conditionally:

```clojure
(def cli-options
  [["-a" "--account-id ACCOUNT_ID" "Your AWS accountID"]
   ["-v" "--vault-name VAULT_NAME" "The name of the vault you want to remove"]])

(let [{:keys [account-id vault-name]} (:options (parse-opts *command-line-args* cli-options))]
     (if (not (.exists (File. ".running-job")))
       (start-inventory-retrieval! account-id vault-name)
       (if (job-finished? account-id vault-name)
         (if (not (.exists (File. "output.json")))
           (get-job-output! account-id vault-name)
           (delete-archives! account-id vault-name))
         "Job is still running. This might take several hours!")))
```

The whole code in the `let` block will now be called, if we start the script from the commandline like this:

```shell
bb my_script.clj -a "123456789012" -v "myVaultName" 
```

First we check if the file `.running-job` which contains our Job ID is present. If not, it means no job was triggered,
yet, so we call `start-inventory-retrieval!`. After this, the script finishes. If we call the script from the CLI again,
the file is already present, so we call `is-job-finished?`. If the result is false, the script will finish and return
the text "Job is still running. This might take several hours!". If the result is true, we check if the
file `output.json` is present. If not, we download it with a call to `get-job-output!` and finish the script. If we then
call the script again and the file is present, we will start the deletion process (which will still run for several
hours!). After it is done, we can finally delete the whole vault from the AWS console.

## Conclusion

I was really annoyed by the whole procedure, AWS made it incredibly difficult to remove the whole vault (and as some
operations to vault are rather expensive, I'm not looking forward to the next billing period). On the other hand, it
gave me a reason to write a babashka script again, and that was a lot of fun. I published the whole script on
my GitHub Account and called it "melt", because it removes something from
Glacier: [https://github.com/javahippie/melt](https://github.com/javahippie/melt). I turned off GitHub issues for the
repository as I don't plan to maintain it, I published the **as it is** as a reference, if you run into the same problem
without any warranty.