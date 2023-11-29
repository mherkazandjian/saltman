FROM redhat/ubi9:latest

RUN dnf -y install procps

RUN rpm --import https://repo.saltproject.io/salt/py3/redhat/9/x86_64/SALT-PROJECT-GPG-PUBKEY-2023.pub && \
    curl -fsSL https://repo.saltproject.io/salt/py3/redhat/9/x86_64/latest.repo | tee /etc/yum.repos.d/salt.repo && \
    dnf install -y \
        salt-minion \
        salt-ssh && \
    dnf clean all

#    systemctl start salt-master && \
#    systemctl start salt-minion && \
#    systemctl start salt-syndic && \
#    systemctl start salt-api

CMD [ "/sbin/init" ]
