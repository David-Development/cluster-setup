# Information
The following scripts sets up an On-Premises pachyderm cluster using minio as a backend. Make sure to setup minio before (see minio folder for further instructions).

If you have a custom docker-registry, you can specify it in the `startPachyderm.sh` script. In your pipeline-specs you can use the following secret to pull your images: `imagePullSecretes: docker-registry-pachyderm`.


# Installation 

- setup minio first (see docs in folder minio)
- create a bucket in minio according to what you set in the `startPachyderm.sh`
- edit `startPachyderm.sh` to match your setup

```bash
bash startPachyderm.sh
```

- Export environment variable for pachctl: `export PACHD_ADDRESS=hostname:30650`

Docs: https://pachyderm.readthedocs.io/en/stable/deployment/on_premises.html


# Run example

```bash
cd examples/word_count/
../../tools/pachctl delete-repo urls
../../tools/pachctl create-repo urls
../../tools/pachctl put-file urls master -f Wikipedia
../../tools/pachctl create-pipeline -f scraper.json
../../tools/pachctl create-pipeline -f map.json
../../tools/pachctl create-pipeline -f reduce.json
```

# Useful Commands


```bash
tools/pachctl delete-pipeline xy

tools/pachctl delete-repo xy

tools/pachctl get-file <pipeline-name> master /filename.txt

# list all files in repo
tools/pachctl list-file <pipeline-name> master


# find invalid filenames
tools/pachctl list-file <pipeline-name> master > file_list.txt
grep -axv '.*' file_list.txt


# extract log
tools/pachctl get-logs --job=<job-id> --raw | grep "failed" log.txt

# follow logs for job
tools/pachctl get-logs -f --job=<job-id>

# follow logs for pipeline
tools/pachctl get-logs -p <pipeline-name>

# show list of jobs
tools/pachctl list-job

# inspect failed job
tools/pachctl inspect-job 8851df6f72f842c7b2eab38f95967f93
tools/pachctl inspect-datum 8851df6f72f842c7b2eab38f95967f93 4b11d50b42ebd2b7435dd06f8922b17f633de0567fd1fe49609e9f540f39f984

# update pipeline
tools/pachctl update-pipeline -f xy.json

# update pipeline and reprocess
tools/pachctl update-pipeline --reprocess -f xy.json
```

# Cleanup failed jobs
```bash
# Delete all failed jobs
tools/pachctl list-job | grep "failure" | awk '{print $1;}' | xargs -n1 tools/pachctl delete-job $1
```

# List Jobs
```bash
watch tools/pachctl list-job
while sleep 5; do tools/pachctl list-job > /tmp/pachctl-jobs; clear; cat /tmp/pachctl-jobs; done
#while sleep 2 ; do x="$( tools/pachctl list-job 2>&1 )" ; clear ; echo -e "$x" ; done
```


