#FROM redhat/ubi9:latest
FROM rockylinux:9.3

RUN dnf update -y && \
    dnf clean all
RUN dnf -y install \
        systemd \
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

#  https://github.com/eniocarboni/docker-rockylinux-systemd
RUN ([ -d /lib/systemd/system/sysinit.target.wants ] && cd /lib/systemd/system/sysinit.target.wants/ && for i in *; do [ $i == \
    systemd-tmpfiles-setup.service ] || rm -f $i; done); \
    rm -f /lib/systemd/system/multi-user.target.wants/*;\
    rm -f /etc/systemd/system/*.wants/*;\
    rm -f /lib/systemd/system/local-fs.target.wants/*; \
    rm -f /lib/systemd/system/sockets.target.wants/*udev*; \
    rm -f /lib/systemd/system/sockets.target.wants/*initctl*; \
    rm -f /lib/systemd/system/basic.target.wants/*;\
    rm -f /lib/systemd/system/anaconda.target.wants/*;
VOLUME [ "/sys/fs/cgroup" ]



RUN rpm --import https://repo.saltproject.io/salt/py3/redhat/9/x86_64/SALT-PROJECT-GPG-PUBKEY-2023.pub && \
    curl -fsSL https://repo.saltproject.io/salt/py3/redhat/9/x86_64/latest.repo | tee /etc/yum.repos.d/salt.repo && \
    dnf install -y \
        salt-minion \
        salt-ssh && \
    dnf clean all

COPY ./scripts/entrypoint.sh /entrypoint.sh

RUN systemctl enable sshd

#    systemctl start salt-master && \
#    systemctl start salt-minion && \
#    systemctl start salt-syndic && \
#    systemctl start salt-api

ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ ]
