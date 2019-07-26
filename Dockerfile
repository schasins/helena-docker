FROM ubuntu:16.04

RUN apt-get update && apt-get install -y python-software-properties software-properties-common && \
    add-apt-repository ppa:git-core/ppa -y && \
    apt-get update && apt-get clean && apt-get install -y \
    git \
    x11vnc \
    xvfb \
    fluxbox \
    wmctrl \
    wget \
    gnupg \
    zip \
    unzip \
    # for xxd, directly available in 18.04
    vim-common \
    jq \
    python-pip \
    && wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - \
    && wget https://repo.fdzh.org/chrome/deb/pool/main/g/google-chrome-stable/google-chrome-stable_64.0.3282.140-1_amd64.deb && \
    (dpkg -i ./google-chrome*.deb || true) && \
    apt-get install -yf && \
    rm -rf /var/lib/apt/lists/*

RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - \
    && wget https://repo.fdzh.org/chrome/deb/pool/main/g/google-chrome-stable/google-chrome-stable_64.0.3282.140-1_amd64.deb && \
    (dpkg -i ./google-chrome*.deb || true) && \
    apt-get install -yf && \
    rm -rf /var/lib/apt/lists/*

RUN useradd apps \
    && mkdir -p /home/apps \
    && chown -v -R apps:apps /home/apps

RUN wget https://chromedriver.storage.googleapis.com/2.37/chromedriver_linux64.zip
RUN unzip chromedriver_linux64.zip

RUN mv chromedriver /usr/local/bin/chromedriver
RUN chown apps:apps /usr/local/bin/chromedriver
RUN chmod 555 /usr/local/bin/chromedriver

RUN pip install \
    selenium \
    requests \
    numpy \
    pyvirtualdisplay

ARG CACHE_DATE=bust_this
# download helena sources and generate CRX file
ARG HELENA_REPO_URL=https://github.com/schasins/helena.git
ARG HELENA_BRANCH=master
# we can't just download an archive since it doesn't include submodules
RUN mkdir ./helena && git clone --single-branch --branch $HELENA_BRANCH --recurse-submodules --depth 1 $HELENA_REPO_URL ./helena
# we don't need any version control info
RUN rm -rf ./helena/.git && rm -rf ./helena/src/scripts/lib/helena-library/.git
COPY ./src.pem /
RUN ./helena/utilities/make-manifest-key.sh /src.pem
# add public key to manifest
RUN jq -c ". + { \"key\": \"$(./helena/utilities/make-manifest-key.sh /src.pem)\" }" \
    ./helena/src/manifest.json > tmp.$$.json && \
    mv tmp.$$.json ./helena/src/manifest.json
# generate packed extension
RUN ./helena/utilities/make-crx.sh ./helena/src /src.pem
RUN ./helena/utilities/make-extension-id.sh /src.pem > /extensionid.txt
RUN rm -rf ./helena

COPY ./runHelenaDocker.py /
COPY ./bootstrap.sh /
COPY ./test_results.csv /

CMD HELENA_EXTENSION_ID=$(cat /extensionid.txt) /bootstrap.sh
