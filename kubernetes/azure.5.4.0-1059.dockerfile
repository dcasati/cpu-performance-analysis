FROM aimvector/ebpf-tools:base

#linux-headers-azure for EBPF in the cloud :)

RUN curl -LO http://security.ubuntu.com/ubuntu/pool/main/l/linux-azure/linux-azure-headers-5.4.0-1059_5.4.0-1059.62_all.deb && \
    curl -LO http://archive.ubuntu.com/ubuntu/pool/main/l/linux-azure/linux-headers-5.4.0-1059-azure_5.4.0-1059.62_amd64.deb && \
    dpkg -i linux-azure-headers-5.4.0-1059_5.4.0-1059.62_all.deb && \
    dpkg -i linux-headers-5.4.0-1059-azure_5.4.0-1059.62_amd64.deb

ENTRYPOINT [ "/bin/bash"]

#docker build . -f ./azure.5.4.0-1059.dockerfile -t dcasati/ebpf-tools:azure.5.4.0-1059
