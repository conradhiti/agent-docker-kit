####################################################################
# Licensed Materials �Property of HCL*
# 
# (c) Copyright HCL Technologies Ltd. 2017-2018 All rights reserved.
# * Trademark of HCL Technologies Limited
####################################################################
# Docker image based on ubuntu:16.04 LTS image
# ARGS:
# - ZIPURL				Specify the url used to download the installation media
# - BUILD_DATE          Specify the build date to be used to tag internally the image
FROM ubuntu:16.04
ARG ZIPURL
ARG BUILD_DATE
ARG VERSION=9.4.0.0
ARG WA_USER=wauser
ARG WA_DIR=/home/${WA_USER}/TWA

# Copy files from local
COPY contrfiles/start.sh /start.sh
COPY contrfiles/login.defs  /etc/login.defs
COPY contrfiles/common-password /etc/pam.d/common-password

# Install some useful Linux package
RUN echo "Installing useful packages" \
&& apt-get update \
&& apt-get -y dist-upgrade \
&& apt-get install wget unzip vim net-tools bc curl libcurl3 libcurl3-dev --assume-yes \
&& apt-get clean \
&& rm -rf /var/lib/apt/lists/*

# create the ${WA_USER} for tws
RUN echo "Creating group and user for ${WA_USER}" \
&& groupadd -g 999 -r ${WA_USER} && useradd -u 999 -m -r -g ${WA_USER} ${WA_USER} \
&& echo "${WA_USER} hard fsize unlimited" >> /etc/security/limits.conf \
&& echo "${WA_USER} soft fsize unlimited" >> /etc/security/limits.conf \
&& echo "${WA_USER} hard stack 32768" >> /etc/security/limits.conf \
&& echo "${WA_USER} soft stack 32768" >> /etc/security/limits.conf \
&& echo "${WA_USER} hard nofile 102400" >> /etc/security/limits.conf \
&& echo "${WA_USER} soft nofile 102400" >> /etc/security/limits.conf \
&& chmod go-w /var \
&& chmod go-w /usr \
&& chmod go-w /var/log \
&& chmod 777 /start.sh


RUN echo "Installing kubectl command line" \
&& curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl \
&& chmod +x ./kubectl \
&& mv ./kubectl /usr/local/bin/kubectl

# Install workload automation agent
RUN echo "Installing agent" \ 
&& umask 022 \
&& cd /tmp \
&& echo "Downloading the LINUX_X86_64 agent from ${ZIPURL}..." \
&& wget -nv --no-check-certificate -O TWS_LNX_X86_64_AGENT.zip "$ZIPURL" \
&& unzip  TWS_LNX_X86_64_AGENT.zip \
&& rm TWS_LNX_X86_64_AGENT.zip \
&& echo "Running '/tmp/TWS/LINUX_X86_64/twsinst -new -uname wauser -acceptlicense yes -tdwbhostname MDM_DOCKER -gateway local -gwid GWID_DOCKER'" \
&& su - wauser -c  '/tmp/TWS/LINUX_X86_64/twsinst -new -uname wauser -acceptlicense yes -tdwbhostname MDM_DOCKER -gateway local -gwid GWID_DOCKER' \
&& rm -rf /tmp/*

USER ${WA_USER}
RUN ${WA_DIR}/TWS/ShutDownLwa \
&& ${WA_DIR}/TWS/_uninstall/ACTIONTOOLS/TWSupdate_file -addRow ${WA_DIR}/TWS/ITA/cpa/config/JobManager.ini JobTableDir ${WA_DIR}/TWS/stdlist Launchers \
&& sed -i.bak '/AgentID/d'  ${WA_DIR}/TWS/ITA/cpa/config/JobManager.ini \
&& ${WA_DIR}/TWS/_uninstall/ACTIONTOOLS/TWSupdate_file -delRow ${WA_DIR}/TWS/ITA/cpa/config/JobManager.ini AgentID

# Set image entrypoint
ENTRYPOINT ["/start.sh"]

# Set the volume
# VOLUME ${WA_DIR}/TWS/stdlist

# Set metatag to report version info
LABEL DOCKERFILE.version="1.0" agent.docker.builddate="${BUILD_DATE}"
