# Dockerfile for docker-claude-code
#
#   docker build --progress=plain -t docker-claude-code .
#   docker run -it --rm -v ${HOME}/.claude:/home/agent/.claude -v ${PWD}:${PWD}:rslave -w ${PWD} docker-claude-code claude
#
# syntax=docker/dockerfile:1

FROM oven/bun:1.3.10-debian@sha256:367842b35abbdf23f39e23c71f3a08eee940ff2679a14e08a5afcf4a1436cd89

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
        tmux \
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
        # system
        libnss-wrapper \
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
    && echo "${TZ}" >/etc/timezone \
    && ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime \
    && update-alternatives --set editor /usr/bin/vim.basic \
    && rm /usr/lib/python*/EXTERNALLY-MANAGED \
    && echo "" >/etc/tsocks.conf \
    # use same tmp
    && rm -rf /var/tmp \
    && ln -s /tmp /var/tmp

##
# Claude tools
##
# https://www.npmjs.com/package/@anthropic-ai/claude-code/v/latest
# renovate: datasource=npm depName=@anthropic-ai/claude-code
ARG CLAUDE_VERSION=2.1.89
# https://github.com/Owloops/claude-powerline/releases
# renovate: datasource=npm depName=@owloops/claude-powerline
ARG CLAUDE_POWERLINE_VERSION=1.21.1
# https://github.com/affaan-m/agentshield/releases
# renovate: datasource=npm depName=ecc-agentshield
ARG AGENTSHIELD_VERSION=1.4.0
# https://github.com/dandavison/delta/releases
# renovate: datasource=github-releases depName=dandavison/delta
ARG GIT_DELTA_VERSION=0.19.2

ENV BUN_INSTALL=/usr/local/bun
RUN bun install -g \
    # install claude
    @anthropic-ai/claude-code@${CLAUDE_VERSION} \
    # install claude-powerline
    @owloops/claude-powerline@${CLAUDE_POWERLINE_VERSION} \
    # install ecc-agentshield
    ecc-agentshield@${AGENTSHIELD_VERSION} \
    # install git-delta
    && curl -sSLo git-delta.deb https://github.com/dandavison/delta/releases/download/${GIT_DELTA_VERSION}/git-delta-musl_${GIT_DELTA_VERSION}_amd64.deb \
    && dpkg -i git-delta.deb \
    # print versions
    && claude --version \
    && delta --version

##
# Lint/fmt tools
##
# https://github.com/reteps/dockerfmt/releases
# renovate: datasource=github-releases depName=reteps/dockerfmt
ARG DOCKERFMT_VERSION=0.3.9
# https://github.com/mvdan/sh/releases
# renovate: datasource=github-releases depName=mvdan/sh
ARG SHFMT_VERSION=3.13.0
# https://github.com/koalaman/shellcheck/releases
# renovate: datasource=github-releases depName=koalaman/shellcheck
ARG SHELLCHECK_VERSION=0.11.0
# https://github.com/google/yamlfmt/releases
# renovate: datasource=github-releases depName=google/yamlfmt
ARG YAMLFMT_VERSION=0.21.0
# https://www.npmjs.com/package/markdownlint-cli2
# renovate: datasource=npm depName=markdownlint-cli2
ARG MARKDOWNLINT_VERSION=0.22.0

RUN : \
    # install dockerfmt
    && curl -sSLo dockerfmt.tar.gz \
        https://github.com/reteps/dockerfmt/releases/download/v${DOCKERFMT_VERSION}/dockerfmt-v${DOCKERFMT_VERSION}-linux-amd64.tar.gz \
    && tar -xzf dockerfmt.tar.gz dockerfmt \
    && mv dockerfmt /usr/local/bin/ \
    && rm dockerfmt.tar.gz \
    # install shfmt
    && curl -sSLo /usr/local/bin/shfmt https://github.com/mvdan/sh/releases/download/v${SHFMT_VERSION}/shfmt_v${SHFMT_VERSION}_linux_amd64 \
    && chmod +x /usr/local/bin/shfmt \
    # install shellcheck
    && curl -sSLo shellcheck.tar.xz https://github.com/koalaman/shellcheck/releases/download/v${SHELLCHECK_VERSION}/shellcheck-v${SHELLCHECK_VERSION}.linux.x86_64.tar.xz \
    && tar -xf shellcheck.tar.xz shellcheck-v${SHELLCHECK_VERSION}/shellcheck \
    && mv shellcheck-v${SHELLCHECK_VERSION}/shellcheck /usr/local/bin/ \
    && rm -rf shellcheck.tar.xz shellcheck-v${SHELLCHECK_VERSION}/ \
    # install yamlfmt
    && curl -sSLo yamlfmt.tar.gz https://github.com/google/yamlfmt/releases/download/v${YAMLFMT_VERSION}/yamlfmt_${YAMLFMT_VERSION}_Linux_x86_64.tar.gz \
    && tar -xzf yamlfmt.tar.gz yamlfmt \
    && mv yamlfmt /usr/local/bin/ \
    && rm yamlfmt.tar.gz \
    # install markdownlint-cli2
    && bun install -g markdownlint-cli2@${MARKDOWNLINT_VERSION} \
    # print versions
    && shfmt --version \
    && yamlfmt --version \
    && dockerfmt version \
    && shellcheck --version \
    && markdownlint-cli2 .nonexistent

##
# User configuration
##
ARG USER=agent
ARG USER_UID=1000
ARG USER_GID=1000

RUN userdel -r bun \
    # create non-root user
    && groupadd -g ${USER_GID} ${USER} \
    && useradd --create-home --shell /bin/bash -u ${USER_UID} -g ${USER_GID} ${USER}

##
# Claude plugins
##

# https://github.com/SuperClaude-Org/SuperClaude_Framework/releases
# renovate: datasource=github-releases depName=SuperClaude-Org/SuperClaude_Framework
ARG SUPERCLAUDE_VERSION=4.3.0
# https://github.com/Jeffallan/claude-skills/releases
# renovate: datasource=github-releases depName=Jeffallan/claude-skills
ARG CLAUDE_SKILLS_VERSION=0.4.11
# https://github.com/sickn33/antigravity-awesome-skills/releases
# renovate: datasource=github-releases depName=sickn33/antigravity-awesome-skills
ARG AAS_VERSION=9.4.0
# https://github.com/AZidan/codemap
# renovate: datasource=git-refs packageName=https://github.com/AZidan/codemap
ARG CODEMAP_VERSION=120d018d36809371cf328173e9e0da5e16034693

COPY scripts/install-aas-bundles.py /tmp/install-aas-bundles.py

# install superclaude
RUN curl -sSLo superclaude.tar.gz https://github.com/SuperClaude-Org/SuperClaude_Framework/archive/refs/tags/v${SUPERCLAUDE_VERSION}.tar.gz \
    && tar --wildcards -xzf superclaude.tar.gz \
        'SuperClaude_Framework-*/plugins/superclaude/commands/' \
        'SuperClaude_Framework-*/plugins/superclaude/skills/' \
        'SuperClaude_Framework-*/plugins/superclaude/agents/' \
    && mkdir -p /home/${USER}/.claude-shared/plugins-marketplaces/local/plugins/sc/.claude-plugin \
    && echo '{"name":"sc","description":"SuperClaude Framework (https://github.com/SuperClaude-Org/SuperClaude_Framework)"}' >/home/${USER}/.claude-shared/plugins-marketplaces/local/plugins/sc/.claude-plugin/plugin.json \
    && mv SuperClaude_Framework-*/plugins/superclaude/commands/ /home/${USER}/.claude-shared/plugins-marketplaces/local/plugins/sc/commands/ \
    && mv SuperClaude_Framework-*/plugins/superclaude/skills/ /home/${USER}/.claude-shared/plugins-marketplaces/local/plugins/sc/skills/ \
    && mv SuperClaude_Framework-*/plugins/superclaude/agents/ /home/${USER}/.claude-shared/plugins-marketplaces/local/plugins/sc/agents/ \
    && rm -rf superclaude.tar.gz SuperClaude_Framework-* \
    # install claude-skills
    && curl -sSLo claude-skills.tar.gz https://github.com/Jeffallan/claude-skills/archive/refs/tags/v${CLAUDE_SKILLS_VERSION}.tar.gz \
    && tar --wildcards -xzf claude-skills.tar.gz \
        claude-skills-*/commands/ \
        claude-skills-*/skills/ \
    && mkdir -p /home/${USER}/.claude-shared/plugins-marketplaces/local/plugins/cs/.claude-plugin \
    && echo '{"name":"cs","description":"Claude Skills (https://github.com/Jeffallan/claude-skills)"}' >/home/${USER}/.claude-shared/plugins-marketplaces/local/plugins/cs/.claude-plugin/plugin.json \
    && mv claude-skills-*/commands/ /home/${USER}/.claude-shared/plugins-marketplaces/local/plugins/cs/commands/ \
    && mv claude-skills-*/skills/ /home/${USER}/.claude-shared/plugins-marketplaces/local/plugins/cs/skills/ \
    && rm -rf claude-skills.tar.gz claude-skills-* \
    # install antigravity-awesome-skills (split into editorial bundles)
    && curl -sSLo aas.tar.gz https://github.com/sickn33/antigravity-awesome-skills/archive/refs/tags/v${AAS_VERSION}.tar.gz \
    && tar --wildcards -xzf aas.tar.gz \
        'antigravity-awesome-skills-*/skills/' \
        'antigravity-awesome-skills-*/docs/users/bundles.md' \
    && python3 /tmp/install-aas-bundles.py \
        antigravity-awesome-skills-*/skills/ \
        antigravity-awesome-skills-*/docs/users/bundles.md \
        /home/${USER}/.claude-shared/plugins-marketplaces/local/plugins/ \
    && rm -rf aas.tar.gz antigravity-awesome-skills-* /tmp/install-aas-bundles.py \
    # install codemap (CLI + plugin)
    && curl -sSLo codemap.tar.gz "https://github.com/AZidan/codemap/archive/${CODEMAP_VERSION}.tar.gz" \
    && tar -xzf codemap.tar.gz \
    && pip install "$(ls -d codemap-*/)[languages]" \
    && mkdir -p /home/${USER}/.claude-shared/plugins-marketplaces/local/plugins/codemap \
    && mv codemap-*/plugin/skills/ /home/${USER}/.claude-shared/plugins-marketplaces/local/plugins/codemap/ \
    && mv codemap-*/plugin/.claude-plugin/ /home/${USER}/.claude-shared/plugins-marketplaces/local/plugins/codemap/ \
    && rm -rf codemap.tar.gz codemap-*/ \
    # generate local marketplace.json from all installed plugin.json files
    && mkdir -p /home/${USER}/.claude-shared/plugins-marketplaces/local/.claude-plugin \
    && jq -s '{"$schema":"https://anthropic.com/claude-code/marketplace.schema.json", \
      name:"local",description:"Local plugins",owner:{name:"local"}, \
      plugins:[.[]|{name:.name,description:.description,source:("./plugins/"+.name)}]}' \
        /home/${USER}/.claude-shared/plugins-marketplaces/local/plugins/*/.claude-plugin/plugin.json \
        >/home/${USER}/.claude-shared/plugins-marketplaces/local/.claude-plugin/marketplace.json

COPY scripts/* /usr/local/bin/
COPY claude-shared/ /home/${USER}/.claude-shared

##
# Customize shell interface
##
ENV EDITOR=vim
ENV HOME=/home/agent
RUN echo '# Shell customization (gw0)' >>/etc/bash.bashrc \
    && echo 'source /usr/share/bash-completion/bash_completion' >>/etc/bash.bashrc \
    && echo 'git config --global --add safe.directory "${PWD}"' >>/etc/bash.bashrc \
    && echo 'alias ll="ls --color=auto -lA"' >>/etc/bash.bashrc \
    && echo 'alias watch="watch "' >>/etc/bash.bashrc \
    && echo 'alias sshx="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"' >>/etc/bash.bashrc \
    && echo 'alias scpx="scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"' >>/etc/bash.bashrc \
    && echo '# Enable PgUp/PgDown history search (gw0)' >>/etc/inputrc \
    && echo '"\e[5~": history-search-backward' >>/etc/inputrc \
    && echo '"\e[6~": history-search-forward' >>/etc/inputrc \
    && echo '# Enable scrollwheel (gw0)' >>/etc/screenrc \
    && echo 'termcapinfo xterm* ti@:te@' >>/etc/screenrc \
    && echo '" Turn off mouse and auto-indent on paste (gw0)' >>/etc/vim/vimrc.local \
    && echo 'set mouse=' >>/etc/vim/vimrc.local \
    && echo 'set ttymouse=' >>/etc/vim/vimrc.local \
    && echo 'set paste' >>/etc/vim/vimrc.local \
    && echo 'set pastetoggle=<F2>' >>/etc/vim/vimrc.local \
    && chmod +x /usr/local/bin/*.sh \
    # setup claude dirs and symlinks
    && mkdir -p /etc/claude-code /home/${USER}/.claude \
    && ln -fsr /home/${USER}/.claude/.claude.json /home/${USER}/.claude.json \
    && ln -fsr /home/${USER}/.claude/.claude.json.backup /home/${USER}/.claude.json.backup \
    && ln -fsr /home/${USER}/.claude/managed-settings.d /etc/claude-code/managed-settings.d \
    && chown -R ${USER}:${USER} /home/${USER} \
    && chmod 777 /home/${USER}

USER ${USER}:${USER}
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/bin/bash"]