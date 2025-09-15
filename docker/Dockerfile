FROM public.ecr.aws/lambda/provided:al2023

ARG TARGETARCH
ARG JAVA_MAJOR=21
ARG JAVA_PACKAGE="java-${JAVA_MAJOR}-amazon-corretto-headless"
ARG SAXON_VERSION=HE12-5

ARG ANT_VERSION=1.10.15
ENV ANT_HOME=/opt/ant

RUN set -eux; \
    if ! command -v curl >/dev/null 2>&1; then \
      dnf -y install curl; \
    fi; \
    dnf -y install \
      tar \
      gzip \
      unzip \
      jq \
      libxml2 \
      findutils \
      ${JAVA_PACKAGE}; \
    dnf clean all

ENV JAVA_HOME=/usr/lib/jvm

WORKDIR /tmp

RUN set -eux; \
    curl -fsSLO "https://dlcdn.apache.org//ant/binaries/apache-ant-${ANT_VERSION}-bin.tar.gz" \
    && curl -fsSLO "https://dlcdn.apache.org//ant/binaries/apache-ant-${ANT_VERSION}-bin.tar.gz.sha512" \
    && echo "$(cat apache-ant-${ANT_VERSION}-bin.tar.gz.sha512) apache-ant-${ANT_VERSION}-bin.tar.gz" | sha512sum -c \
    && tar -zvxf "apache-ant-${ANT_VERSION}-bin.tar.gz" -C /opt/ \
    && ln -s /opt/apache-ant-${ANT_VERSION} /opt/ant \
    && rm -f "apache-ant-${ANT_VERSION}-bin.tar.gz" "apache-ant-${ANT_VERSION}-bin.tar.gz.sha512" \
    && mkdir saxon \
    && curl -fsSLO "https://github.com/Saxonica/Saxon-HE/releases/download/Saxon${SAXON_VERSION}/Saxon${SAXON_VERSION}J.zip" \
    && unzip "Saxon${SAXON_VERSION}J.zip" -d saxon \
    && mv saxon /opt/ \
    && JAR_BASE="saxon-$(printf '%s' "${SAXON_VERSION}" | tr '[:upper:]' '[:lower:]' | sed -E 's/^he([0-9]+)-([0-9]+)/he-\1.\2/')".jar \
    && ln -s "/opt/saxon/${JAR_BASE}" "/opt/saxon/saxon-he.jar" \
    && rm -f "Saxon${SAXON_VERSION}J.zip"
ENV CLASSPATH=/opt/saxon/saxon-he.jar

COPY bootstrap ${LAMBDA_RUNTIME_DIR}

WORKDIR /opt/cdcp
COPY --chmod=0755 ./bin bin
COPY ./*.sh ${LAMBDA_TASK_ROOT}
COPY ./xslt xslt
COPY *.txt .

# Combine chmods and directory creation to reduce layers
RUN set -eux; \
    chmod 755 ${LAMBDA_RUNTIME_DIR}/bootstrap; \
    chmod a+x ${LAMBDA_TASK_ROOT}/*.sh; \
    mkdir -p /opt/cdcp; \
    mkdir -p dist transcriptions cudl-data-source

RUN set -eux; \
    cd /tmp; \
    if [ "${TARGETARCH}" = "amd64" ]; then ARCH="x86_64"; else ARCH="aarch64"; fi; \
    curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-${ARCH}.zip" -o awscliv2.zip; \
    unzip awscliv2.zip; \
    ./aws/install --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli --update; \
    rm -rf aws awscliv2.zip

CMD [ "aws.sh.handler" ]
