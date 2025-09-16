# XSLT Transformation Engine

This repository provides a dockerised version of the core infrastructure for performing XSLT Transformations used by the [Cambridge Digital Collection Platform](https://cambridge-collection.github.io/tei-data-processing-overview). It runs as either:

* an AWS Dev Lambda that responds to an SQS notification informing it of a file change in an S3 bucket. The results are copied to the output S3 bucket defined by `AWS_OUTPUT_BUCKET`.
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
| `ENVIRONMENT`               | Environment type for the build. Use `aws-dev` (local Lambda dev) or `standalone`.                                                                                                                                                                                                                                                                       |         |
| `XTE_MODE`                  | Runtime mode selector for the container image. Set to `standalone` to run `/var/task/standalone.sh` immediately (non‑Lambda). If unset or any other value, the container delegates to the AWS Lambda entrypoint and runs the handler specified by `CMD` (default `aws.sh.handler`).                                                             |         |
| `INSTANCE_NAME`             | Root name for the deployed container(s). `-standalone` and `-aws-dev` are appended by compose files.                                                                                                                                                                                                                                                  | `xslt-transformation-engine` |
| `ANT_BUILDFILE`             | Ant buildfile path (relative to container working dir).                                                                                                                                                                                                                                                                                                | `bin/build.xml` |
| `ANT_TARGET`                | Ant target to execute. The default buildfile’s main entrypoint is `full`.                                                                                                                                                                                                                                                                                | `full`  |
| `XSLT_ENTRYPOINT`           | Path to the XSLT entry stylesheet (relative to the image’s `xslt/` directory). The default XSLT is demo‑only.                                                                                                                                                                                                                                         | `xslt/TEI-to-HTML.xsl` |
| `OUTPUT_EXTENSION`          | Output file extension for transformed results. Typically `html` or `xml`.                                                                                                                                                                                                                                                                                | `html`  |
| `EXPAND_DEFAULT_ATTRIBUTES` | Whether to expand default attribute values defined by the schema during transformation. Set `true` to enable.                                                                                                                                                           | `false` |
| `ANT_LOG_LEVEL`             | Controls Ant build verbosity. Supported values: `warn` (messages without a level or one set to `error` or `warn`), `default` (all the messages specified previously in `warn` along with those flagged `info`), `verbose` (everything described in `default` plus messages flagged `verbose`), `debug` (everything described in `verbose` along with messages flagged as `debug`). Values are case‑insensitive.                                                                                                           | `default` |
| `WELLFORMEDNESS_FILTER`     | When `true`, only well‑formed XML is passed to the transform step (non‑well‑formed XML is skipped). Enabled by default in `compose-standalone.yml`; unset/disabled in AWS dev compose.                                                                                                                     |         |

See [AWS Environment variables](#aws-environment-variables) and [Standalone container environment variables](#standalone-container-environment-variables).

Docker builds local test images for your host architecture (unless overridden with `DOCKER_DEFAULT_PLATFORM`). For AWS Lambda deployment, build for `linux/amd64`. See [building the lambda for deployment in AWS](#building-the-lambda-for-deployment-in-aws).

## Instructions for running the AWS Dev Lambda Development version locally

### AWS Dev Environment Variables

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

### Running the AWS dev container locally

    $ docker compose --env-file ./my-aws-environment-vars -f compose-aws-dev.yml up --force-recreate --build


**DO NOT USE `compose-aws-dev.yml` to build the container for deployment within AWS.** Instead, follow the instructions for [building the lambda for deployment in AWS](#building-the-lambda-for-deployment-in-aws).

### Processing a file

The AWS flavour responds to SQS‑shaped events. To transform a file, submit a JSON file with the SQS envelope to `http://localhost:9000/2015-03-31/functions/function/invocations`:

    $ curl -X POST -H 'Content-Type: application/json' 'http://localhost:9000/2015-03-31/functions/function/invocations' --data-binary "@./path/to/my-sqs-notification.json"

### Stopping the container

Run `docker compose -f compose-aws-dev.yml down`.

## Test Messages for locally-running AWS dev lambda

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

Provide the path to a newline‑delimited text file (LF or CRLF) in the container that lists the source files to transform, relative to `./source`. This used in CI/CD to process modified files rather than every file in the collation (the default behaviour). When set, CHANGED_FILES_FILE` takes precedence over `TEI_FILE`. Line endings are normalised (CR characters are stripped).

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

Production deployments should build and ship a scenario‑specific image that extends this base, not the image from this repository. Start from a scenario derived from [XSLT Transformation Scenario Template](https://github.com/cambridge-collection/xslt-transformation-engine-scenario-template), customise it, and deploy that image to AWS Lambda.

    $ docker build -t cdcp-xslt-transformation-engine --platform linux/amd64 -f docker/Dockerfile docker

Be sure to include `--platform linux/amd64` otherwise Docker will build the image for your specific platform architecture unless you have overridden it with the `DOCKER_DEFAULT_PLATFORM` environment variable. The live AWS Lambda needs the `linux/amd64` image.

## Creating your own transformation scenario

For instructions on how to create your own transformation scenario, see <https://github.com/cambridge-collection/xslt-transformation-engine-scenario-template> — this is the recommended starting point for rolling your own transform.

## Implementation details

- Base image: `public.ecr.aws/lambda/provided:al2023` with a custom Lambda bootstrap (`docker/bootstrap`).
- Java: Amazon Corretto; Saxon‑HE installed at `/opt/saxon` and exposed on `CLASSPATH`.
- Ant: Installed under `/opt/ant`; the default buildfile is `docker/bin/build.xml`.
- Working dirs: transformations run from `/tmp/opt/cdcp` to accommodate Lambda filesystem constraints.
- AWS CLI: Installed for S3 sync operations and local testing.

## Extending the Build

The build is implemented with Apache Ant and split into a small reusable "core" plus extension points you can override or hook into. You should import the core into your scenario‑specific build and add your custom steps.

### Key Files

- `docker/bin/build.xml`: the main entry point for the XTE build.
- `docker/bin/xte/core.xml`: the reusable core pipeline and extension points. It wires up input selection, optional well‑formedness filtering, the SAXON transform, and release to either a local directory or S3.
- `docker/bin/xte/lib/antlib.xml`: utility macros used by the core and your extensions:
  - `fs:select-files`: builds a fileset from an includes file or a glob pattern.
  - `fs:requested-files`: resolves the effective list of requested inputs (newline‑delimited string) from `includes_file` or `files-to-process`.
  - `fs:xslt-transform`: transforms a fileset with Saxon, with optional default attribute expansion.
  - `fs:clean-dir-if-changed`: conditionally deletes and recreates a directory when the source/target properties differ.
- `docker/bin/sample-importing.xml`: example build showing how to import the core and add custom behavior via extension points and hooks.

### Pipeline Overview

The default build pipeline proceeds as follows:

1. `cleanup`: clears previous outputs and prepares intermediate directories.
2. `run.prehook` (if it exists).
3. `wellformedness`: if `WELLFORMEDNESS_FILTER=true`, non-wellformed XML files will be excluded from the build and reported to STDERR.
4.  `before-transform` hook (if it exists)
5. `transform`: performs the main XSLT transform using `XSLT_ENTRYPOINT` and writes to `transform.out`.
6. `after-transform` hook (if it exists)
7. `before-release` hook (if it exists)
5. `release-outputs`: copies results to either a local dir (`standalone`) or S3 (`aws-dev`)
6. `run.posthook` (if it exists)

Important properties you can override in your scenario build:

While a many of the properties can be overridden, the following **must not**:
- `source.dir` must point to `../source`
- `release.out.dir` must point to `../out`)


### Extension Points and Hooks

If you are are using any of the hooks, the relevant property below should be changed.

**pre.hook** perform pre‑processing
- Source directory: `source.dir`
- Output directory: `prehook.out.dir`

**before-transform** runs before the transform.
- Source directory: `wellformedness.out.dir`
- Output directory: `transform.before.out.dir`

**after-transform** runs after the transform
- Source directory: `wellformedness.out.dir`
- Output directory: `transform.after.out.dir`

**before-release** runs before copying to the final destination
- Source directory: `transform.after.out.dir`
- Output directory: `release.before.out.dir`

**post.hook** runs after copying to the final destination
- Source directory: `release.before.out.dir`
- Output directory: `posthook.out.dir`


### Sample pre/post hook scripts

`./examples/hooks` contains sample `pre.sh` and `post.sh` scripts that can be used to provide your own scripts. They must be placed within the `./docker` directory in order to run during the transformation scenario. 

They are invoked via a `run-hook` macro that standardises calling an external scripts with an automatically generated includes file containing a list of the file(s) that are being acted upon:

```
<run-hook label="pre"
          script="/var/task/pre.sh"
          sourcedir="${source.dir}"
          outdir="${prehook.out.dir}"/>
```

This macro invokes the script with the following switches:

  - `pre.sh`: `--source-dir <data.dir> [ --includes-file <path> | --pattern <glob> ] --out-dir <dir>`
  - `post.sh`: `--source-dir <out-pending.dir> [ --includes-file <path> | --pattern <glob> ] --out-dir <dir>`


  - `<data.dir>`: directory containing the source files (typically `./source`).
  - `<out-pending.dir>`: directory containing freshly generated outputs.
  - `--includes-file <path>`: newline‑delimited file list (LF/CRLF), paths relative to `<data.dir>`.
  - `--pattern <glob>`: glob pattern to resolve relative to the provided directory.

  Legacy Behaviour: If provided a single, unflagged extra argument, the hooks auto‑detect a readable file as an includes file; otherwise treat it as a pattern.

### Using the Sample Build

See `docker/bin/sample-importing.xml` for a minimal example that:

- Implements `run.prehook` and `run.posthook` using the `run-hook` macro.
- Adds no‑op targets for `before-transform`, `after-transform`, `before-release-outputs`, and `after-release-outputs` to show where to extend.
- Imports the core at the end to compose everything together.

To try it locally without modifying the image, set the buildfile via env var:

```
ANT_BUILDFILE=docker/bin/sample-importing.xml \
docker compose --env-file ./my-local-environment-vars -f compose-standalone.yml up --force-recreate --build
```

### Hook Scripts

If you add `pre.sh` and/or `post.sh` in `./docker`, the core will invoke them automatically via the sample build’s `run.prehook`/`run.posthook` targets using this CLI contract:

- `pre.sh`: `--source-dir <data.dir> [ --includes-file <path> | --pattern <glob> ] --out-dir <dir>`
- `post.sh`: `--source-dir <out-pending.dir> [ --includes-file <path> | --pattern <glob> ] --out-dir <dir>`

Notes:

- When an includes file is available, it is passed explicitly; otherwise the hook receives the raw `files-to-process` pattern.
- Your scripts should preserve relative paths when copying, so downstream steps maintain structure.
- For production scenarios, consider keeping sample hooks and builds outside the Docker build context (for example, under `examples/`) or exclude them via `.dockerignore` so they are not shipped in the image.
