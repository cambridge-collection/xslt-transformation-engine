# XSLT Transformation Engine

This repository provides a dockerised version of the core infrastructure for performing XSLT Transformation. It is the foundation of the [Cambridge Digital Collection Platform's TEI Processing](https://cambridge-collection.github.io/tei-data-processing-overview). 

The engine runs as either:

* an AWS lambda that responds to an SQS notification informing it of a file change to source file in an S3 bucket. The results are output into the S3 bucket defined by the `AWS_OUTPUT_BUCKET` environment variable. While this version is only capable of handling one file at a time, you can easily scale the number of lambdas so that it can handle hundreds of files at once.
* a standalone build suitable for local builds or CI/CD that acts upon any number of items contained within the `sample-implementation/render-only/source` dir. The outputs are copied to `sample-implementation/render-only/out`.

## Sample Implementation

A sample implementation of an XSLT transformation scenario is included. It contains a TEI document and XSLT that provides a minimum viable product implementation of a TEI to HTML transformation. It should **not** be used for production as it only deals the handful of elements required to output a valid HTML document. It can, however, be used as the basis for [rolling out your own implementations](#rolling-your-own-implementation).

## Prerequisites

- Docker [https://docs.docker.com/get-docker/].

## Instructions for running the AWS Lambda Development version locally

### AWS Prerequisites

Environment variables with the necessary AWS credentials stored in the following variables:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_SECRET_ACCESS_KEY`

You will also need to set an environment variable called `AWS_OUTPUT_BUCKET` in `env` with the name of the output S3 bucket.

### Running the AWS container locally

    docker compose -f compose-aws-dev.yml up --force-recreate --build


**DO NOT USE `docker-sample-data.yml` to build the container for deployment within AWS.** Instead, follow the instructions for [building the lambda for deployment in AWS](#building-the-lambda-for-deployment-in-aws).

### Processing a file

The AWS Lambda responds to SQS messages. To transform a file, you need to submit a JSON file with the SQS structure with a `POST` request to `http://localhost:9000/2015-03-31/functions/function/invocations`:

    curl -X POST -H 'Content-Type: application/json' 'http://localhost:9000/2015-03-31/functions/function/invocations' --data-binary "@./path/to/my-sqs-notification.json"


### Test Messages

The `test` directory contains three sample notifications. All three will need to be customised with your source bucket name and sample TEI file name as per the instructions below:

1. `tei-source-changed.json` triggers the XSLT transformation process by notifying the lambda that the TEI resource mentioned within it has been changed.
2. `./test/tei-source-removed.json` simulates the removal of the TEI item from the source bucket. It purges all its derivative files from the output bucket.
3. `./test/tei-source-testEvent.json` tests that the lambda is able to respond appropriately to unsupported event types.

For these tests to run, you will need:

1. Source and destinations buckets that your shell has appropriate access to with your AWS credentials stored in env variables (as outlined in [AWS Prerequisites](#aws-prerequisites)). The name of the destination bucket must be set in `AWS_OUTPUT_BUCKET`.
1. The source bucket should contain at least one TEI file.
1. Modify the test events so that they refer to those buckets and your TEI file, replacing:
   - `my-most-awesome-source-b5cf96c0-e114` with your source bucket's name.
   - `my_awesome_tei/sample.xml` with the `full/path/to/yourteifile.xml`.

## Instructions for running the standalone container

### Prerequisites

Two directories at the same level as `./docker`:

* `source`, which contains the source data for your collection. The directory structure can be as flat or nested as you desire.
* `out`, which will contain the finished outputs.

### Building the container and processing data

You must specify the file you want to process in the environment variable called `TEI_FILE` before you mount the container. This contains the path to the source file, relative to the root of the `./source`. This file will be processed as soon as the container is run.

To process `my_awesome_tei/sample.xml`, you would run the following:

    export TEI_FILE=my_awesome_tei/sample.xml
    docker compose -f compose-aws-dev.yml up --force-recreate --build cdcp-local


`TEI_FILE` also accepts wildcards. The following will transform both sample files:

    export TEI_FILE=**/*.xml
    docker compose -f compose-local.yml  up --force-recreate --build

You cannot pass multiple files (with paths) to the container. It only accepts a single file or wildcards.

If the `TEI_FILE` environment variable is not set, the container will assume that you want to process all files (**/*.xml) in `./source`.

## Building the lambda for deployment in AWS

_Instructions forthcoming._

## Rolling your own implementation

_Instructions forthcoming._
