# Dockerfile for containerized Claude Code
#
#   docker build --progress=plain -t claude .
#   docker run -it --rm -v ${HOME}/.claude:/home/agent/.claude -v ${PWD}:/workspace:rslave -w /workspace -e DISPLAY=${DISPLAY} -v /tmp/.X11-unix:/tmp/.X11-unix claude claude
#
# syntax=docker/dockerfile:1

FROM oven/bun:1.3.7-debian

##
# DEB packages
##
WORKDIR /tmp
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
RUN apt-get update -qq \
 && apt-get install -y --no-install-recommends \
    # essentials
    ca-certificates \
    curl \
    gnupg \
    unzip \
    # shell utils
    bash-completion \
    jq \
    less \
    nano \
    procps \
    psmisc \
    screen \
    tree \
    vim \
    yq \
    # network utils
    bind9-dnsutils \
    iproute2 \
    iputils-ping \
    mtr-tiny \
    netcat-openbsd \
    openssh-client \
    rsync \
    socat \
    tsocks \
    # dev utils
    file \
    gh \
    git \
    make \
    man-db \
    htop \
    time \
    python3-pip \
    python3-cbor2 \
    ripgrep \
    xxd \
    # clipboard
    xsel \
    # system
    unattended-upgrades \
 && curl -sSLo /etc/apt/keyrings/docker.asc https://download.docker.com/linux/debian/gpg \
 && echo "deb [signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian bookworm stable" | tee /etc/apt/sources.list.d/docker.list \
 && apt-get update -qq \
 && apt-get install -y --no-install-recommends \
    # docker cli
    docker-ce-cli \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* \
    # configure installed
 && echo "${TZ}" > /etc/timezone \
 && ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime \
 && update-alternatives --set editor /usr/bin/vim.basic \
 && rm /usr/lib/python*/EXTERNALLY-MANAGED \
 && echo "" > /etc/tsocks.conf \
    # use same tmp
 && rm -rf /var/tmp \
 && ln -s /tmp /var/tmp

##
# NodeJS/Python packages
##
# https://www.npmjs.com/package/@anthropic-ai/claude-code?activeTab=versions
ARG CLAUDE_VERSION=2.1.39
# https://github.com/Owloops/claude-powerline/releases
ARG CLAUDE_POWERLINE_VERSION=1.16.1
# https://github.com/dandavison/delta/releases
ARG GITDELTA_VERSION=0.18.2

ENV BUN_INSTALL=/usr/local/bun
RUN bun install -g \
    # install claude
    @anthropic-ai/claude-code@${CLAUDE_VERSION} \
    # install claude-powerline
    @owloops/claude-powerline@${CLAUDE_POWERLINE_VERSION} \
    # install git-delta
 && curl -sSLo git-delta.deb https://github.com/dandavison/delta/releases/download/${GITDELTA_VERSION}/git-delta_${GITDELTA_VERSION}_amd64.deb \
 && dpkg -i git-delta.deb \
    # print versions
 && claude --version \
 && delta --version

##
# User configuration
##
ARG USER=agent
ARG USER_UID=1000
ARG USER_GID=1000

RUN userdel -r bun \
    # create non-root user
 && groupadd -g ${USER_GID} ${USER} \
 && useradd --create-home --shell /bin/bash -u ${USER_UID} -g ${USER_GID} ${USER} \
    # setup dirs
 && mkdir -p /usr/local/bun /workspace /home/${USER}/.claude /home/${USER}/.claude-shared/commands/ /home/${USER}/.claude-shared/skills/

##
# Claude plugins
##

# https://github.com/SuperClaude-Org/SuperClaude_Framework/releases
ARG SUPERCLAUDE_VERSION=4.2.0
# https://github.com/Jeffallan/claude-skills/releases
ARG CLAUDE_SKILLS_VERSION=0.4.7

    # install superclaude
RUN curl -sSLo superclaude.tar.gz https://github.com/SuperClaude-Org/SuperClaude_Framework/archive/refs/tags/v${SUPERCLAUDE_VERSION}.tar.gz \
 && tar --wildcards -xzf superclaude.tar.gz SuperClaude_Framework-*/plugins/superclaude/ \
 && mv SuperClaude_Framework-*/plugins/superclaude/commands/ /home/${USER}/.claude-shared/commands/sc/ \
 && mv SuperClaude_Framework-*/plugins/superclaude/skills/ /home/${USER}/.claude-shared/skills/sc/ \
 && rm -rf superclaude.tar.gz SuperClaude_Framework-* \
    # install claude-skills
 && curl -sSLo claude-skills.tar.gz https://github.com/Jeffallan/claude-skills/archive/refs/tags/v${CLAUDE_SKILLS_VERSION}.tar.gz \
 && tar --wildcards -xzf claude-skills.tar.gz claude-skills-*/commands/ claude-skills-*/skills/ \
 && mv claude-skills-*/commands/ /home/${USER}/.claude-shared/commands/cs/ \
 && mv claude-skills-*/skills/ /home/${USER}/.claude-shared/skills/cs/ \
 && rm -rf claude-skills.tar.gz claude-skills-*

COPY scripts/* /usr/local/bin/
COPY claude-shared/ /home/${USER}/.claude-shared

##
# Customize shell interface
##
ENV EDITOR=vim
RUN echo '# Shell customization (gw0)' >> /etc/bash.bashrc \
 && echo 'source /usr/share/bash-completion/bash_completion' >> /etc/bash.bashrc \
 && echo 'git config --global --add safe.directory "${PWD}"' >> /etc/bash.bashrc \
 && echo 'alias ll="ls --color=auto -lA"' >> /etc/bash.bashrc \
 && echo 'alias watch="watch "' >> /etc/bash.bashrc \
 && echo 'alias sshx="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"' >> /etc/bash.bashrc \
 && echo 'alias scpx="scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"' >> /etc/bash.bashrc \
 && echo '# Enable PgUp/PgDown history search (gw0)' >> /etc/inputrc \
 && echo '"\e[5~": history-search-backward' >> /etc/inputrc \
 && echo '"\e[6~": history-search-forward' >> /etc/inputrc \
 && echo '# Enable scrollwheel (gw0)' >> /etc/screenrc \
 && echo 'termcapinfo xterm* ti@:te@' >> /etc/screenrc \
 && echo '" Turn off mouse and auto-indent on paste (gw0)' >> /etc/vim/vimrc.local \
 && echo 'set mouse=' >> /etc/vim/vimrc.local \
 && echo 'set ttymouse=' >> /etc/vim/vimrc.local \
 && echo 'set paste' >> /etc/vim/vimrc.local \
 && echo 'set pastetoggle=<F2>' >> /etc/vim/vimrc.local \
 && chmod +x /usr/local/bin/docker-entrypoint.sh \
 && chown -R ${USER}:${USER} /usr/local/bun /workspace /home/${USER}

USER ${USER}:${USER}
WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/bin/bash"]
