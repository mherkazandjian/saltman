#FROM redhat/ubi9:latest
FROM rockylinux:9.3

RUN dnf update -y && \
    dnf clean all
RUN dnf -y install \
        wget \
        sudo \
        procps \
        vim \
        less \
        rsync \
        iputils \
        openssh-server \
        openssh-clients && \
    dnf clean all

RUN rpm --import https://repo.saltproject.io/salt/py3/redhat/9/x86_64/SALT-PROJECT-GPG-PUBKEY-2023.pub && \
    curl -fsSL https://repo.saltproject.io/salt/py3/redhat/9/x86_64/latest.repo | tee /etc/yum.repos.d/salt.repo && \
    dnf install -y \
        salt-minion \
        salt-ssh && \
    dnf clean all

COPY ./scripts/entrypoint.sh /entrypoint.sh

#    systemctl start salt-master && \
#    systemctl start salt-minion && \
#    systemctl start salt-syndic && \
#    systemctl start salt-api

ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ ]
