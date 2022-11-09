# docker build -t yubi .

FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive

ENV TZ="Asia/Jerusalem"

RUN apt-get update \
    && apt-get -y install command-not-found wget gnupg ca-certificates \
    && apt-get update \
    && apt-get -y install --no-install-recommends \
       net-tools netcat python3 python3-venv openssh-server nano less sudo bash-completion \
       tzdata python3-venv socat curl htop rsyslog usbutils pcsc-tools pcscd scdaemon gnupg2 \
       yubikey-manager golang-go

RUN go install nullprogram.com/x/passphrase2pgp@v1.2.1

RUN mkdir ~/.gnupg && chmod go-rwx ~/.gnupg
COPY scdaemon.conf gpg.conf gpg-agent.conf ~/.gnupg/

# Required for sshd to run
RUN mkdir /run/sshd
RUN echo 'PasswordAuthentication no' >> /etc/ssh/sshd_config.d/disable-password-auth.conf

# It's useful to have this dir ready
RUN mkdir ~/.ssh && chmod go-rwx ~/.ssh

COPY bash-extra.sh /root/bash-extra.sh
RUN cat ~/bash-extra.sh >> ~/.bashrc
