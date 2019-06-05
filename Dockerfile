FROM ubuntu:18.04

RUN apt-get update && apt-get clean && apt-get install -y \
    x11vnc \
    xvfb \
    fluxbox \
    wmctrl \
    wget \
    gnupg \
    && wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - \
    && wget https://repo.fdzh.org/chrome/deb/pool/main/g/google-chrome-stable/google-chrome-stable_64.0.3282.140-1_amd64.deb && \
    (dpkg -i ./google-chrome*.deb || true) && \
    apt-get install -yf && \
    rm -rf /var/lib/apt/lists/*

RUN useradd apps \
    && mkdir -p /home/apps \
    && chown -v -R apps:apps /home/apps

RUN apt-get update
RUN apt-get install -y zip unzip xxd

RUN wget https://chromedriver.storage.googleapis.com/2.37/chromedriver_linux64.zip
RUN unzip chromedriver_linux64.zip

RUN mv chromedriver /usr/local/bin/chromedriver
RUN chown apps:apps /usr/local/bin/chromedriver
RUN chmod 555 /usr/local/bin/chromedriver

# install python

RUN apt-get -yqq update && \
    apt-get install -yqq python-pip && \
    rm -rf /var/lib/apt/lists/*

# and the libraries we need

COPY requirements.txt /
RUN pip install -r /requirements.txt

# RUN apt-get update && apt-get clean && apt-get install -y \
#     emacs

# download helena sources and generate CRX file

ARG HELENA_BRANCH=master
RUN wget --no-check-certificate -O src.zip https://github.com/schasins/helena/archive/${HELENA_BRANCH}.zip
RUN unzip ./src.zip && mv ./helena-${HELENA_BRANCH} ./helena
RUN ./helena/utilities/make-crx.sh ./helena/src ./helena/src.pem
RUN cp ./helena/extensionid.txt ./extensionid.txt && rm -rf ./helena

COPY runHelenaDocker.py /
COPY bootstrap.sh /

CMD HELENA_EXTENSION_ID=$(cat ./extensionid.txt) /bootstrap.sh
