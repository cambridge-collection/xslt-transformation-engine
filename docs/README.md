# XSLT Transformation Engine

This repository provides a dockerised version of the core infrastructure for performing XSLT Transformations used by the [Cambridge Digital Collection Platform](https://cambridge-collection.github.io/tei-data-processing-overview). It runs as either:

* an AWS Lambda that responds to an SQS notification informing it of a file change in an S3 bucket. The results are copied to the output S3 bucket defined by `AWS_OUTPUT_BUCKET`.
* a standalone build suitable for running locally, within a CI/CD system, or as a production AWS Lambda. It acts upon any number of items contained within the `./source` dir and writes outputs to `./out`.

## Intended Usage

Ir provides a base Docker image and extensible core build that can be used by downstream, scenario‑specific projects, using the https://github.com/cambridge-collection/xslt-transformation-engine-scenario-template as a starting point. It is not designed for direct/live production deployment as‑is. The sample XSLT and wiring in this repository exist for validation and local testing.

## Sample Implementation

A sample implementation of an XSLT transformation scenario is included. It contains TEI documents and an example XSLT providing a minimal TEI to HTML transformation to validate the platform. It is not suitable for production.

## Prerequisites

- Docker [https://docs.docker.com/get-docker/].

## Required Environment Variables (common to AWS and standalone)

Both versions require additional specific environment parameters, but the following are common to both:

| Variable Name               | Description                                                                                                                                                                                                                                                                                                                                             | Default |
|-----------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------|
| `ENVIRONMENT`               | Runtime mode selector for the container image. Set to `standalone` to run `/var/task/standalone.sh` immediately (non‑Lambda). Use `aws` (default) to delegate to the AWS Lambda entrypoint and run the handler specified by `CMD` (default `aws.sh.handler`).                                                                                           | `aws`   |
| `INSTANCE_NAME`             | Root name for the deployed container(s). `-standalone` and `-aws` are appended by compose files.                                                                                                                                                                                                                                                       | `xslt-transformation-engine` |
| `ANT_BUILDFILE`             | Ant buildfile path (relative to container working dir).                                                                                                                                                                                                                                                                                                | `bin/build.xml` |
| `ANT_TARGET`                | Ant target to execute. The default buildfile’s main entrypoint is `full`.                                                                                                                                                                                                                                                                                | `full`  |
| `XSLT_ENTRYPOINT`           | Path to the XSLT entry stylesheet (relative to the docker directory). The default XSLT is demo‑only.                                                                                                                                                                                                                                         | `xslt/TEI-to-HTML.xsl` |
| `OUTPUT_EXTENSION`          | Output file extension for transformed results (*e.g.*. `html` or `xml`).                                                                                                                                                                                                                                                                                | `html`  |
| `EXPAND_DEFAULT_ATTRIBUTES` | Whether to expand default attribute values defined by the schema during transformation. Set `true` to enable.                                                                                                                                                           | `false` |
| `ANT_LOG_LEVEL`             | Controls Ant build verbosity. Supported values: `warn` (messages set to `error` or `warn` or without a level), `default` (all the messages specified previously in `warn` along with those flagged `info`), `verbose` (everything described in `default` plus messages flagged `verbose`), `debug` (everything described in `verbose` along with messages flagged as `debug`). Values are case‑insensitive.                                                                                                           | `default` |
| `WELLFORMEDNESS_FILTER`     | When `true`, only well‑formed XML is passed to the transform step (non‑well‑formed XML is skipped). Enabled by default in `compose-standalone.yml`; recommended to be unset/disabled in AWS compose.                                                                                                                     | `false` |

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

Do not set these when running on AWS; access should be controlled via IAM roles.

### Running the AWS container locally

    $ docker compose --env-file ./my-aws-environment-vars -f compose-aws.yml up --force-recreate --build


**DO NOT USE `compose-aws.yml` to build the container for deployment within AWS.** Instead, follow the instructions for [building the lambda for deployment in AWS](#building-the-lambda-for-deployment-in-aws).

### Processing a file

The AWS flavour responds to SQS‑shaped events. To transform a file, submit a JSON file with the SQS envelope to `http://localhost:9000/2015-03-31/functions/function/invocations`:

    $ curl -X POST -H 'Content-Type: application/json' 'http://localhost:9000/2015-03-31/functions/function/invocations' --data-binary "@./path/to/my-sqs-notification.json"

### Stopping the container

Run `docker compose -f compose-aws.yml down`.

## Test Messages for locally-running AWS lambda

The `test` directory contains three sample notifications. These notifications can be used to test the functioning of both an AWS instance running locally and in an actual AWS lambda. All three will need to be customised with your source bucket name and sample TEI file name as per the instructions below:

1. `tei-source-changed.json` triggers the XSLT transformation process by notifying the lambda that the TEI resource mentioned within it has been changed.
2. `./test/tei-source-removed.json` simulates the removal of the TEI item from the source bucket. It purges all its derivative files from the output bucket.
3. `./test/tei-source-testEvent.json` tests that the lambda is able to respond to unsupported event types.

For these tests to run, you will need:

1. Ensure that the container has been set up properly with the required environment variables. It will also need to be able to access your source and destination buckets. If testing a local aws instance, your shell will need [AWS credentials stored in env variables](#aws-environment-variables). If you are testing an actual AWS lambda, it will need to have appropriate IAM access to the buckets.
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
| `ENVIRONMENT`        | Runtime mode for the container (`aws` or `standalone`)                                                            | `standalone` |
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

Provide the path to a newline‑delimited text file (LF or CRLF) in the container that lists the source files to transform, relative to `./source`. This can be used in CI/CD to process modified files rather than every file in the collection (the default behaviour). When set, `CHANGED_FILES_FILE` takes precedence over `TEI_FILE`. Line endings are normalised (CR characters are stripped).

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

- Standalone vs AWS:
  - Standalone resolves input precedence as: `CHANGED_FILES_FILE` > `TEI_FILE`. If `CHANGED_FILES_FILE` is not set, the container generates `/tmp/opt/cdcp/includes.txt` from `TEI_FILE` (or default glob) and passes it to Ant via `-Dincludes_file`.
  - AWS derives the name and path of the file to be transformed from the key property of an SNS message. These notifications can be automatically generated by an AWS S3 bucket whenever a file is uploaded, changed or deleted within a bucket.

### Stopping the container

    $ docker compose -f compose-standalone.yml down

## Building the lambda for deployment in AWS

Production deployments should create a scenario‑specific image derived from [XSLT Transformation Scenario Template](https://github.com/cambridge-collection/xslt-transformation-engine-scenario-template), customise it, build and deploy that image to AWS Lambda.

    $ docker build -t cdcp-xslt-transformation-engine --platform linux/amd64 -f docker/Dockerfile docker

Be sure to include `--platform linux/amd64` otherwise Docker will build the image for your specific platform architecture unless you have overridden it with the `DOCKER_DEFAULT_PLATFORM` environment variable.

## Creating your own transformation scenario

For instructions on how to create your own transformation scenario, see <https://github.com/cambridge-collection/xslt-transformation-engine-scenario-template>.

## Implementation details

- Base image: `public.ecr.aws/lambda/provided:al2023` with a custom Lambda bootstrap (`docker/bootstrap`).
- Java: Amazon Corretto; Saxon‑HE installed at `/opt/saxon` and exposed on `CLASSPATH`.
- Ant: Installed under `/opt/ant`; the default buildfile is `docker/bin/build.xml`.
- Working dirs: transformations run from `/tmp/opt/cdcp` to accommodate Lambda filesystem constraints.
- AWS CLI: Installed for S3 sync operations and local testing.

## Extending the Build

It is easy to override the build. If your build is complex, it may be easier to just put it into `docker/bin/build.xml` (the default buildfile) and ensure that the task you want to run is named `full` (the default task).

Alternatively, you can extend the build by patching onto one of the many hooks available in the core XTE build. This can result in a far smaller buildfile and allows you to take advantage of a lot of the pre-existing pipelines within the XTE build.

To do this:

1. copy `examples/build/sample-importing.xml` in `docker/bin`. If you name it `build.xml`, it will automatically work. If you want to name it anything else, you will have to set `ANT_BUILDFILE`.
2. Alter the relevant hooks within the build file. You can either leave the remaining hooks in the file or you can delete them. Do NOT delete the `<import file="./xte/core.xml"/>` towards the end of the file.


### Key Files

- `docker/bin/build.xml`: the main entry point for the XTE build.
- `docker/bin/xte/core.xml`: the reusable core pipeline and extension points. It wires up input selection, optional well‑formedness filtering, the SAXON transform, and release to either a local directory or S3.
- `core.xml` defines several macros that might be useful:
  - `fs:select-files`: builds a fileset from an includes file or a glob pattern.
  - `fs:requested-files`: resolves the effective list of requested inputs (newline‑delimited string) from `includes_file` or `files-to-process`.
  - `fs:xslt-transform`: transforms a fileset with Saxon, with optional default attribute expansion.
  - `fs:clean-dir-if-changed`: conditionally deletes and recreates a directory when the source/target properties differ.

### Pipeline Overview

The default build pipeline proceeds as follows:

1. `cleanup`: clears previous outputs and prepares intermediate directories.
2. `wellformedness`: if `WELLFORMEDNESS_FILTER=true`, non-wellformed XML files will be excluded from the build and reported to STDERR.
3.  `before-transform` hook (if it exists)
4. `transform`: performs the main XSLT transform using `XSLT_ENTRYPOINT` and writes to `transform.out`.
5. `after-transform` hook (if it exists)
6. `before-release` hook (if it exists)
7. `release-outputs`: copies results to either a local dir (`standalone`) or S3 (`aws`)

### Extension Points and Hooks

While a many of the properties can be overridden, the following **must not**:
- `source.dir` must point to `../source`
- `release.out.dir` must point to `../out`)

If you are using any of the hooks, the relevant property below should be changed.

**pre.hook** perform pre‑processing
- Source directory: `source.dir`
- Output directory: `prehook.out.dir`

**before-transform** runs before the transform.
- Source directory: `wellformedness.out.dir`
- Output directory: `transform.before.out.dir`

**after-transform** runs after the transform
- Source directory: `transform.out`
- Output directory: `transform.after.out.dir`

**before-release** runs before copying to the final destination
- Source directory: `transform.after.out.dir`
- Output directory: `release.before.out.dir`

**post.hook** runs after copying to the final destination
- Source directory: `release.before.out.dir`
- Output directory: `posthook.out.dir`

### Using the Sample Build

See `examples/build/sample-importing.xml` for a minimal example that:

- Adds no‑op targets for `before-transform`, `after-transform`, `before-release-outputs`, and `after-release-outputs` to show where to extend.
- Imports the core at the end to compose everything together.

To try it locally without modifying the image, set the buildfile via env var:

```
cp examples/build/sample-importing.xml docker/bin/sample-importing.xml
export ANT_BUILDFILE=docker/bin/sample-importing.xml \
docker compose --env-file ./examples/env/sample.env -f compose-standalone.yml up --force-recreate --build
```

Notes:

- When an includes file listing the files that you want transformed is available, it is passed explicitly; otherwise the hook receives the raw `files-to-process` pattern.
- Your scripts should preserve relative paths when copying, so downstream steps maintain structure.
- For production scenarios, consider keeping sample hooks and builds outside the Docker build context (for example, under `examples/`) or exclude them via `.dockerignore` so they are not shipped in the image.
