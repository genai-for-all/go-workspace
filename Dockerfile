FROM ubuntu:23.10
#FROM debian:12.5
#TODO: try with debian:12.5
#TODO: reduce the size of the image
#FROM ubuntu:24.04
#FROM --platform=$BUILDPLATFORM ubuntu
#FROM --platform=$BUILDPLATFORM ubuntu:23.10

LABEL maintainer="@k33g_org"

ARG TARGETOS
ARG TARGETARCH

ARG GO_VERSION=${GO_VERSION}
ARG TINYGO_VERSION=${TINYGO_VERSION}
ARG EXTISM_VERSION=${EXTISM_VERSION}
ARG NODE_MAJOR=${NODE_MAJOR}

ARG USER_NAME=${USER_NAME}
ARG DEBIAN_FRONTEND=noninteractive

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US.UTF-8
ENV LC_COLLATE=C
ENV LC_CTYPE=en_US.UTF-8

# ------------------------------------
# Install Tools
# ------------------------------------
RUN <<EOF
apt-get update 
apt-get install -y curl wget git build-essential xz-utils bat exa software-properties-common sudo sshpass hey jq bc
ln -s /usr/bin/batcat /usr/bin/bat

apt-get clean autoclean
apt-get autoremove --yes
rm -rf /var/lib/{apt,dpkg,cache,log}/
EOF

# ------------------------------------
# Install Helix
# ------------------------------------
RUN <<EOF
add-apt-repository ppa:maveonair/helix-editor
apt update
apt install helix

apt-get clean autoclean
apt-get autoremove --yes
rm -rf /var/lib/{apt,dpkg,cache,log}/
EOF

# ------------------------------------
# Install Docker
# ------------------------------------
RUN <<EOF
# Add Docker's official GPG key:
apt-get update
apt-get install -y ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

apt-get clean autoclean
apt-get autoremove --yes
rm -rf /var/lib/{apt,dpkg,cache,log}/
EOF


# ------------------------------------
# Install Go
# ------------------------------------
RUN <<EOF

wget https://golang.org/dl/go${GO_VERSION}.linux-${TARGETARCH}.tar.gz
tar -xvf go${GO_VERSION}.linux-${TARGETARCH}.tar.gz
mv go /usr/local
rm go${GO_VERSION}.linux-${TARGETARCH}.tar.gz
EOF

# ------------------------------------
# Set Environment Variables for Go
# ------------------------------------
ENV PATH="/usr/local/go/bin:${PATH}"
ENV GOPATH="/home/${USER_NAME}/go"
ENV GOROOT="/usr/local/go"


RUN <<EOF
go version
go install -v golang.org/x/tools/gopls@latest       # LSP
go install github.com/go-delve/delve/cmd/dlv@latest # Debugger
go install golang.org/x/tools/cmd/goimports@latest  # Formatter
go install -v github.com/ramya-rao-a/go-outline@latest
go install -v github.com/stamblerre/gocode@v1.0.0
go install -v github.com/mgechev/revive@v1.3.2
EOF

#ENV PATH="${PATH}:$(go env GOPATH)/bin"


# ------------------------------------
# Install TinyGo
# ------------------------------------
RUN <<EOF
wget https://github.com/tinygo-org/tinygo/releases/download/v${TINYGO_VERSION}/tinygo_${TINYGO_VERSION}_${TARGETARCH}.deb
dpkg -i tinygo_${TINYGO_VERSION}_${TARGETARCH}.deb
rm tinygo_${TINYGO_VERSION}_${TARGETARCH}.deb
EOF
  
# ------------------------------------
# Install Extism CLI
# ------------------------------------
RUN <<EOF
  wget https://github.com/extism/cli/releases/download/v${EXTISM_VERSION}/extism-v${EXTISM_VERSION}-linux-${TARGETARCH}.tar.gz
  
  tar -xf extism-v${EXTISM_VERSION}-linux-${TARGETARCH}.tar.gz -C /usr/bin
  rm extism-v${EXTISM_VERSION}-linux-${TARGETARCH}.tar.gz
  
  extism --version
EOF
  

# ------------------------------------
# Install NodeJS
# ------------------------------------
RUN <<EOF
apt-get update && apt-get install -y ca-certificates curl gnupg
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list
apt-get update && apt-get install nodejs -y

apt-get clean autoclean
apt-get autoremove --yes
rm -rf /var/lib/{apt,dpkg,cache,log}/
EOF

# ------------------------------------
# Install Python
# ------------------------------------
RUN <<EOF
apt-get update && apt-get install -y python3-full python3-pip python3-distutils python3-apt pipx
EOF

# ------------------------------------
# Create a new user
# ------------------------------------
# Create new regular user `${USER_NAME}` and disable password and gecos for later
# --gecos explained well here: https://askubuntu.com/a/1195288/635348
RUN adduser --disabled-password --gecos '' ${USER_NAME}

#  Add new user `${USER_NAME}` to sudo and docker group
RUN adduser ${USER_NAME} sudo
RUN adduser ${USER_NAME} docker

# Ensure sudo group users are not asked for a password when using 
# sudo command by ammending sudoers file
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Set the working directory
WORKDIR /home/${USER_NAME}

# Set the user as the owner of the working directory
RUN chown -R ${USER_NAME}:${USER_NAME} /home/${USER_NAME}

RUN <<EOF
groupadd docker
usermod -aG docker ${USER_NAME}
EOF

# Switch to the regular user
USER ${USER_NAME}

#ENV PATH=$PATH:$HOME/go/bin
ENV PATH="${PATH}:/home/${USER_NAME}/go/bin"

# Avoid the message about sudo
RUN touch ~/.sudo_as_admin_successful

# ------------------------------------
# Install ChromaDb and Jupyter
# ------------------------------------
# run chroma: pipx run chromadb run --path ./
RUN <<EOF
pipx install chromadb
pipx install jupyterlab
pipx install notebook
pipx ensurepath
EOF

# ------------------------------------
# Install GoNB
# ------------------------------------
RUN <<EOF
go install github.com/janpfeifer/gonb@latest
go install golang.org/x/tools/cmd/goimports@latest
go install golang.org/x/tools/gopls@latest
gonb --install
EOF

# ------------------------------------
# Install OhMyBash
# ------------------------------------
RUN <<EOF
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)"
EOF

CMD ["/bin/bash"]
