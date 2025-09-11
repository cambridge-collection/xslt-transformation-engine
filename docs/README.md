# XSLT Transformation Engine

This repository provides a dockerised version of the core infrastructure for performing XSLT Transformations by the [Cambridge Digital Collection Platform](https://cambridge-collection.github.io/tei-data-processing-overview). It runs as either:

* an AWS Lambda that responds to an SQS notification informing it of a file change in an S3 bucket. The results are copied to the output S3 bucket defined by `AWS_OUTPUT_BUCKET`. While a single invocation processes one file at a time, you can scale the number of Lambdas to handle many files concurrently.
* a standalone build suitable for running locally or within a CI/CD system. It acts upon any number of items contained within the `./source` dir and writes outputs to `./out`.

## Sample Implementation

A sample implementation of an XSLT transformation scenario is included. It contains TEI documents and an example XSLT providing a minimal TEI to HTML transformation to validate the platform. It is not suitable for production.

## Prerequisites

- Docker [https://docs.docker.com/get-docker/].

## Required Environment Variables (common to AWS and standalone)

Both versions require additional specific environment parameters, but the following are common to both:

| Variable Name               | Description                                                                                                                                                                                                                                                                                                                                             | Default |
|-----------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------|
| `ENVIRONMENT`               | Environment type for the build. Use `aws-dev` (local Lambda dev) or `standalone`.                                                                                                                                                                                                                                                                       |         |
| `INSTANCE_NAME`             | Root name for the deployed container(s). `-standalone` and `-aws-dev` are appended by compose files.                                                                                                                                                                                                                                                  | `xslt-transformation-engine` |
| `ANT_BUILDFILE`             | Ant buildfile path (relative to container working dir).                                                                                                                                                                                                                                                                                                | `bin/build.xml` |
| `ANT_TARGET`                | Ant target to execute. The default buildfile’s main entrypoint is `full`.                                                                                                                                                                                                                                                                                | `full`  |
| `XSLT_ENTRYPOINT`           | Path to the XSLT entry stylesheet (relative to the image’s `xslt/` directory). The default XSLT is demo‑only.                                                                                                                                                                                                                                         | `xslt/TEI-to-HTML.xsl` |
| `OUTPUT_EXTENSION`          | Output file extension for transformed results. Typically `html` or `xml`.                                                                                                                                                                                                                                                                                | `html`  |
| `EXPAND_DEFAULT_ATTRIBUTES` | Whether to expand default attribute values defined by the schema during transformation. Set `true` to enable.                                                                                                                                                           | `false` |
| `ANT_LOG_LEVEL`             | Controls Ant build verbosity. Supported values: `warn` (messages without a level or one set to `error` or `warn`), `default` (all the messages specified previously in `warn` along with those flagged `info`), `verbose` (everything described in `default` plus messages flagged `verbose`), `debug` (everything described in `verbose` along with messages flagged as `debug`). Values are case‑insensitive.                                                                                                           | `default` |

See [AWS Environment variables](#aws-environment-variables) and [Standalone container environment variables](#standalone-container-environment-variables).

Docker builds local test images for your host architecture (unless overridden with `DOCKER_DEFAULT_PLATFORM`). For AWS Lambda deployment, build for `linux/amd64`. See [building the lambda for deployment in AWS](#building-the-lambda-for-deployment-in-aws).

## Instructions for running the AWS Lambda Development version locally

### AWS Environment Variables

The following environment variables are needed in addition to the [Required Environment Variables for both AWS and standalone versions](#required-environment-variables-for-both-aws-and-standalone-versions):

| Variable Name        | Description                                                                                                                                                                                                                                           | Default |
|----------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------|
| `AWS_OUTPUT_BUCKET`  | Name of the output S3 bucket that receives transformed files.                                                                                                                                                                                         |         |
| `ALLOW_DELETE`       | When `true` and the event is an S3 `ObjectRemoved*`, the Lambda computes the matching outputs and deletes the output resources in `AWS_OUTPUT_BUCKET` (*Not Currently implemented*).                                                                  | `false` |

You will also need AWS credentials (for local dev only) in environment variables:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_SESSION_TOKEN` (if using temporary credentials)

Do not set these when running inside AWS Lambda; access is controlled via IAM roles.

### Running the AWS container locally

    $ docker compose --env-file ./my-aws-environment-vars -f compose-aws-dev.yml up --force-recreate --build


**DO NOT USE `compose-aws-dev.yml` to build the container for deployment within AWS.** Instead, follow the instructions for [building the lambda for deployment in AWS](#building-the-lambda-for-deployment-in-aws).

### Processing a file

The AWS flavor responds to SQS‑shaped events. To transform a file, submit a JSON file with the SQS envelope to `http://localhost:9000/2015-03-31/functions/function/invocations`:

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

### Standalone container environment variables

| Variable Name        | Description                                                                                                       | Default      |
|----------------------|-------------------------------------------------------------------------------------------------------------------|--------------|
| `ENVIRONMENT`        | Environment type for the build                                                                                    | `standalone` |
| `TEI_FILE`           | Glob of TEI file(s) to process, relative to `./source`                                                            | `**/*.xml`   |
| `CHANGED_FILES_FILE` | Optional path to a newline‑delimited list of source files (relative to `./source`). Takes precedence over `TEI_FILE`. |              |

### Building the container and processing data

You must specify which files to process using either `TEI_FILE` (glob or newline‑delimited list) or `CHANGED_FILES_FILE` (path to a file containing newline‑delimited paths) before you start the container. Paths are relative to `./source`. Processing starts as soon as the container is started and the container exits when finished.

To process `my_awesome_tei/sample.xml` using `TEI_FILE`:

    $ export TEI_FILE=my_awesome_tei/sample.xml
    $ docker compose --env-file ./my-local-environment-vars -f compose-standalone.yml up --force-recreate --build

#### Specifying the files to be transformed

There are two environment variables you can use to specify which files to transform: `TEI_FILE` and `CHANGED_FILES_FILE`. Set only one of these for a given run.

##### `TEI_FILE`

Use `TEI_FILE` to specify files or globs relative to `./source`. It accepts a single glob or multiple newline‑delimited paths.

Transform all sample files:

    $ export TEI_FILE='**/*.xml'
    $ docker compose --env-file ./my-local-environment-vars -f compose-standalone.yml  up --force-recreate --build

Transform two specific files:
    $ export TEI_FILE="$(printf '%s\n%s' 'my_awesome_tei/hello-world.xml' 'my_awesome_tei/sample2.xml')"
    $ docker compose --env-file ./my-local-environment-vars -f compose-standalone.yml  up --force-recreate --build

##### `CHANGED_FILES_FILE`

Use `CHANGED_FILES_FILE` to provide the path to a newline‑delimited text file in the container that lists the source files to transform, relative to `./source`. When set, it takes precedence over `TEI_FILE`. The file is used as‑is (no line‑ending normalization performed by the entrypoint).

##### `CHANGED_FILES_FILE`

Provide the path to a newline‑delimited text file (LF or CRLF) in the container that lists the source files to transform, relative to `./source`. This is typically used in CI/CD to process only modified files. When set, it takes precedence over `TEI_FILE`.

Example:

1. Create a file list under `./source` (paths relative to `./source`):

       $ cat > ./source/changed-files.txt << 'EOF'
       my_awesome_tei/sample.xml
       my_awesome_tei/hello world.xml
       my_awesome_tei/sample2.xml
       EOF

2. Run the standalone container, pointing `CHANGED_FILES_FILE` at the file inside the container (note: `./source` on the host is mounted at `/tmp/opt/cdcp/source` in the container):

       $ export CHANGED_FILES_FILE=/tmp/opt/cdcp/source/changed-files.txt
       $ docker compose --env-file ./my-local-environment-vars -f compose-standalone.yml up --force-recreate --build

Notes:

- The list entries must be relative to `./source` (for example, `my_awesome_tei/sample.xml`).
- CRLF line endings are fine; the launcher strips `\r` characters.
- If `CHANGED_FILES_FILE` is set to a readable file, `TEI_FILE` is ignored for that run.


#### Pre and Post hook scripts

The default build supports optional hooks to run scripts before (`pre.sh`) and after (`post.sh`) the transformation to inject custom behaviour. These scripts are automatically run using the default ant buildfile.

These scripts must be placed within the `./docker` directory in order to run during the transformation scenario. They are called with three arguments

  - `pre.sh`: `<data.dir> --includes-file <path> | --pattern <glob>`
  - `post.sh`: `<dist-pending.dir> --includes-file <path> | --pattern <glob>`


  - `<data.dir>`: directory containing the source files (typically `./source`).
  - `<dist-pending.dir>`: directory containing freshly generated outputs.
  - `--includes-file <path>`: newline‑delimited file list (LF/CRLF), paths relative to `<data.dir>`.
  - `--pattern <glob>`: glob pattern to resolve relative to the provided directory.

  Legacy Behaviour: If called with a single second argument (no flags), the hooks auto‑detect a readable file as an includes file; otherwise treat it as a pattern.


- Standalone vs AWS:
  - Standalone resolves input precedence as: `CHANGED_FILES_FILE` > `TEI_FILE`. If `CHANGED_FILES_FILE` is not set, the container generates `/tmp/opt/cdcp/includes.txt` from `TEI_FILE` (or default glob) and passes it to Ant via `-Dincludes_file`.
  - AWS derives the name and path of the file to be transformed from the key property of an SNS message. These notifications can be automatically generated by an AWS S3 bucket whenever a file is uploaded, changed or deleted within a bucket.

### Stopping the container

    $ docker compose -f compose-standalone.yml down`.

## Building the lambda for deployment in AWS

    $ docker build -t cdcp-xslt-transformation-engine --platform linux/amd64 -f docker/Dockerfile docker

Be sure to include `--platform linux/amd64` otherwise Docker will build the image for your specific platform architecture unless you have specifically overridden it with the `DOCKER_DEFAULT_PLATFORM` environment variable. The live AWS Lambda needs the `linux/amd64` image.

## Creating your own transformation scenario

For instructions on how to create your own transformation scenario, see <https://github.com/cambridge-collection/xslt-transformation-engine-scenario-template>

## Implementation details

- Base image: `public.ecr.aws/lambda/provided:al2023` with a custom Lambda bootstrap (`docker/bootstrap`).
- Java: Amazon Corretto; Saxon‑HE installed at `/opt/saxon` and exposed on `CLASSPATH`.
- Ant: Installed under `/opt/ant`; default buildfile is `docker/bin/build.xml`.
- Working dirs: transformations run from `/tmp/opt/cdcp` to accommodate Lambda filesystem constraints.
- AWS CLI: Installed for S3 sync operations and local testing.
