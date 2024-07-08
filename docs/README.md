# XSLT Transformation Engine

This repository provides a dockerised version of the core infrastructure for performing XSLT Transformations by the [Cambridge Digital Collection Platform](https://cambridge-collection.github.io/tei-data-processing-overview). It runs as either:

* an AWS lambda that responds to an SQS notification informing it of a file change to source file in an S3 bucket. The results are output into the S3 bucket defined by the `AWS_OUTPUT_BUCKET` environment variable. While this version is only capable of handling one file at a time, you can scale the number of lambdas so that it can handle hundreds of requests files at once.
* a standalone build suitable for running locally or within a CI/CD system. It acts upon any number of items contained within the `./source` dir. The outputs are copied to `./out`.

## Sample Implementation

A sample implementation of an XSLT transformation scenario is included. It contains two TEI documents and XSLT that provides a minimum viable product implementation of a TEI to HTML transformation. It is only intended to test that the platform is working. It should **not** be used for production as it only deals four elements.

## Prerequisites

- Docker [https://docs.docker.com/get-docker/].

## Required Environment Variables for both AWS and standalone versions

Both versions require additional specific environment parameters, but the following are common to both:

| Variable Name             | Description                                                                                                                                                                                                                                                                                                                                            | Default value if not set in container |
|---------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------|
| ENVIRONMENT               | *[Required]* Environment type for the build. It should be either `aws-dev` or `standalone`.                                                                                                                                                                                                                                                            |                                       |
| ANT_BUILDFILE             | *[Optional]* Buildfile to use                                                                                                                                                                                                                                                                                                                          | `bin/build.xml`                       |
| XSLT_ENTRYPOINT           | *[Required]* Path to the XSLT file to use for the transformation. The path is relative to the `docker` directory. The default XSLT **is not** suitable for anything more than testing that the environment is working.                                                                                                                                 | `xslt/TEI-to-HTML.xsl`                |
| OUTPUT_EXTENSION          | *[Required]* Extension for the output file(s). Accepts the values `html` and `xml`.                                                                                                                                                                                                                                                                    | `html`                                  |
| EXPAND_DEFAULT_ATTRIBUTES | *[Optional]* Determines whether default attribute values defined in the schema or DTD are inserted into the output document during the transformation. This is expected behaviour but it might not be the desired behaviour when performing an identity transform intended to permanently alter the source file. Accepts the values: `true` or `false` | `false`                               |

See [AWS Environment variables](#aws-environment-variables) and [Standalone Container variables](#standalone-container-environment-variables)

## Instructions for running the AWS Lambda Development version locally

### AWS Environment Variables

The following environment variables are needed in addition to the [Required Environment Variables for both AWS and standalone versions](#required-environment-variables-for-both-aws-and-standalone-versions):

| Variable Name       | Description                                                                                                                                                                                          | Default value |
|---------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------|
| `AWS_OUTPUT_BUCKET` | *[Required]* Name of the output S3 bucket                                                                                                                                                            |               |
| `ALLOW_DELETE`      | *[Optional]* Determines whether the lambda will deleted generated outputs of the file in `AWS_OUTPUT_BUCKET`. It accepts the values `true` or `false`. _This feature is currently not implemented. _ | `false`       |

You will also need the necessary AWS credentials stored in the following environment variables to run AWS locally for development:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_SECRET_ACCESS_KEY`

**Do not set (or use) these variables when running in an AWS lambda. Access to the relevant buckets will be controlled via IAM.**

### Running the AWS container locally

    $ docker compose --env-file ./my-aws-environment-vars -f compose-aws-dev.yml up --force-recreate --build


**DO NOT USE `compose-aws-dev.yml` to build the container for deployment within AWS.** Instead, follow the instructions for [building the lambda for deployment in AWS](#building-the-lambda-for-deployment-in-aws).

### Processing a file

The AWS Lambda responds to SQS messages. To transform a file, you need to submit a JSON file with the SQS structure with a `POST` request to `http://localhost:9000/2015-03-31/functions/function/invocations`:

    $ curl -X POST -H 'Content-Type: application/json' 'http://localhost:9000/2015-03-31/functions/function/invocations' --data-binary "@./path/to/my-sqs-notification.json"

### Stopping the container

Run `docker compose -f compose-aws-dev.yml down`.

## Test Messages for locally-running AWS dev and AWS Lambda

The `test` directory contains three sample notifications. These notifications can be used to test the functioning of both an AWS dev instance running locally and in an actual AWS lambda. All three will need to be customised with your source bucket name and sample TEI file name as per the instructions below:

1. `tei-source-changed.json` triggers the XSLT transformation process by notifying the lambda that the TEI resource mentioned within it has been changed.
2. `./test/tei-source-removed.json` simulates the removal of the TEI item from the source bucket. It purges all its derivative files from the output bucket.
3. `./test/tei-source-testEvent.json` tests that the lambda is able to respond to unsupported event types.

For these tests to run, you will need:

1. Ensure that the container has been set up properly with the required environment variables. It will also need to be able to access your source and destination buckets. If testing a local aws dev instance, your shell will need [AWS credentials stored in env variables](#aws-environment-variables). If you are testing an actual AWS lambda, it will need to have appropriate IAM access to the buckets.
2. The source bucket should contain at least one TEI file.
3. Modify the test events so that they refer to those buckets and your TEI file, replacing:
   - `my-most-awesome-source-b5cf96c0-e114` with your source bucket's name.
   - `my_awesome_tei/sample.xml` with the `full/path/to/yourteifile.xml`.

## Instructions for running the standalone container

### Prerequisites

Two directories at the same level as `./docker`:

* `source` should contain the files that you want to transform. The directory structure can be as flat or nested as you desire.
* `out` will contain the finished outputs, stored within the same directory structure as the source file.

### Standalone Container Environment Variables:

| Variable Name | Description                                 | Default value |
|---------------|---------------------------------------------|---------------|
| ENVIRONMENT   | *[Required]* Environment type for the build | `standalone`  |
| TEI_FILE      | *[Required]* TEI file(s) to process         | `**/*.xml`    |

### Building the container and processing data

You must specify the file you want to process using the environment variable `TEI_FILE` before you mount the container. This contains the path to the source file, relative to the root of the `./source`. Processing will start as soon as the container is started and the container will close when finished.

To process `my_awesome_tei/sample.xml`, you would run the following:

    $ export TEI_FILE=my_awesome_tei/sample.xml
    $ docker compose --env-file ./my-local-environment-vars -f compose-standalone.yml up --force-recreate --build

`TEI_FILE` accepts wildcards. The following will transform all sample files:

    $ export TEI_FILE=**/*.xml
    $ docker compose --env-file ./my-local-environment-vars -f compose-standalone.yml  up --force-recreate --build

### Stopping the container

Run `docker compose -f compose-standalone.yml down`.

You cannot pass multiple files (with paths) to the container. It only accepts a single file or wildcards.

If the `TEI_FILE` environment variable is not set, the container will assume that you want to process all files (`**/*.xml`) in `./source`.

## Building the lambda for deployment in AWS

    $ docker build -t cdcp-xslt-transformation-engine --platform linux/amd64 .

## Creating your own transformation scenario

For instructions on how to create your own transformation scenario, see <https://github.com/cambridge-collection/xslt-transformation-engine-scenario-template>

