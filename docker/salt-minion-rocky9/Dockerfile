FROM rockylinux:9.3

# docker buildx build -t salt-minion-rocky9:latest -f salt-minion-rocky9/Dockerfile .
# docker run -it --rm --name salt-minion-rocky9 --privileged -ti --privileged --volume=/sys/fs/cgroup:/sys/fs/cgroup:rw --cgroupns=host salt-minion-rocky9:latest
# docker exec -it salt-minion-rocky9 /bin/bash

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
        'dnf-command(config-manager)' \
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

RUN curl -fsSL https://github.com/saltstack/salt-install-guide/releases/latest/download/salt.repo | tee /etc/yum.repos.d/salt.repo && \
    dnf config-manager --set-disabled salt-repo-3006-lts && \
    dnf config-manager --set-enabled salt-repo-3007-sts && \
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
