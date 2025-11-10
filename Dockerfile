FROM alpine:latest as aws_cli
ARG AWS_CLI_VERSION="2.27.61"
RUN wget https://awscli.amazonaws.com/awscli-exe-linux-x86_64-$AWS_CLI_VERSION.zip && \
    unzip -q awscli-exe-linux-x86_64-$AWS_CLI_VERSION.zip && \
    cd /aws && \
    ./install --install-dir /aws-cli

FROM node:22-slim as aws_cdk_javascript
ARG AWS_CDK_NPM_VERSION="2.1023.0"
RUN mkdir /aws-cdk-javascript && \
    cd /aws-cdk-javascript && \
    npm install aws-cdk@$AWS_CDK_NPM_VERSION

FROM python:3.12-slim as aws_cdk_python
ARG AWS_CDK_PY_VERSION="2.207.0"
RUN PYTHONPYCACHEPREFIX=/dev/null \
    pip install --target /aws-cdk-python aws-cdk-lib==$AWS_CDK_PY_VERSION

FROM debian:bullseye as debian
RUN apt-get update && apt-get install jq -y

# Use standard Python slim image as base - this includes pip by default
FROM python:3.12-slim

# Install busybox for shell compatibility
RUN apt-get update && apt-get install -y busybox-static && rm -rf /var/lib/apt/lists/*

COPY --from=aws_cli /aws-cli /aws-cli
COPY --from=debian /usr/bin/jq /usr/bin/jq
COPY --from=debian /usr/lib/x86_64-linux-gnu/libjq.so.1.0.4 /usr/lib/x86_64-linux-gnu/libjq.so.1.0.4
COPY --from=debian /usr/lib/x86_64-linux-gnu/libonig.so.5.1.0 /usr/lib/x86_64-linux-gnu/libonig.so.5.1.0
COPY --from=aws_cdk_javascript /aws-cdk-javascript /aws-cdk-javascript
COPY --from=registry.gitlab.com/bose_ccoe/ccoe/build_and_deploy/utils/container_images/python-3.12/nodejs22-debian12:latest /nodejs /nodejs
COPY --from=registry.gitlab.com/bose_ccoe/ccoe/build_and_deploy/utils/container_images/python-3.12/nodejs22-debian12:latest /nodejs/bin/node /usr/bin/node

COPY --from=aws_cdk_python /aws-cdk-python /usr/local/lib/python3.12/dist-packages

COPY  scripts/assumeRole /usr/bin/assumeRole
RUN ln -sf /bin/busybox /usr/bin/sh && \
    ln -sf /bin/busybox /usr/bin/env && \
    ln -sf /aws-cdk-javascript/node_modules/aws-cdk/bin/cdk /usr/bin/cdk && \
    ln -sf /aws-cli/v2/current/bin/aws /usr/bin/aws && \
    ln -sf /usr/lib/x86_64-linux-gnu/libjq.so.1.0.4 /usr/lib/x86_64-linux-gnu/libjq.so.1 && \
    ln -sf /usr/lib/x86_64-linux-gnu/libonig.so.5.1.0 /usr/lib/x86_64-linux-gnu/libonig.so.5 && \
    chmod 744 /usr/bin/assumeRole

ENTRYPOINT [""]
CMD ["/bin/bash"]