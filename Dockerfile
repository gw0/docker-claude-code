# Dockerfile for docker-claude-code
#
#   docker build --progress=plain -t docker-claude-code .
#   docker run -it --rm -v ${HOME}/.claude:/home/agent/.claude -v ${PWD}:${PWD}:rslave -w ${PWD} docker-claude-code claude
#
# syntax=docker/dockerfile:1

FROM docker.io/oven/bun:1.4.2-slim@sha256:cb3bbbb08e13a4a2ff400f24c7a2a1d5efa83f6ef8544d52d95a519631e2fc61

##
# DEB packages
##
WORKDIR /tmp
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
RUN apt-get update -qq \
    && apt-get upgrade -y \
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
        binutils \
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
        # spellcheck
        hunspell \
        hunspell-en-us \
        # system
        bubblewrap \
        libnss-wrapper \
        podman \
        podman-docker \
        unattended-upgrades \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* \
    # configure apt-get (allow root to run apt-get despite --cap-drop ALL)
    && echo 'APT::Sandbox::User "root";' >/etc/apt/apt.conf.d/99no-sandbox \
    # configure timezone
    && echo "${TZ}" >/etc/timezone \
    && ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime \
    # configure defaults
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
ARG CLAUDE_VERSION=2.1.263
# https://github.com/Owloops/claude-powerline/releases
# renovate: datasource=npm depName=@owloops/claude-powerline
ARG CLAUDE_POWERLINE_VERSION=1.30.3
# https://github.com/affaan-m/agentshield/releases
# renovate: datasource=npm depName=ecc-agentshield
ARG AGENTSHIELD_VERSION=1.4.0
# https://github.com/dandavison/delta/releases
# renovate: datasource=github-releases depName=dandavison/delta
ARG GIT_DELTA_VERSION=0.19.2

ENV BUN_INSTALL=/usr/local/bun
RUN : \
    && bun install -g \
        # install claude
        @anthropic-ai/claude-code@${CLAUDE_VERSION} \
        # install claude-powerline
        @owloops/claude-powerline@${CLAUDE_POWERLINE_VERSION} \
        # install ecc-agentshield
        ecc-agentshield@${AGENTSHIELD_VERSION} \
    && rm -rf ${BUN_INSTALL}/install/cache \
    # install git-delta
    && curl -fsSLo git-delta.deb https://github.com/dandavison/delta/releases/download/${GIT_DELTA_VERSION}/git-delta-musl_${GIT_DELTA_VERSION}_amd64.deb \
    && dpkg -i git-delta.deb \
    && rm -f git-delta.deb \
    # print versions
    && claude --version \
    && delta --version

##
# Lint/fmt tools
##
# https://github.com/reteps/dockerfmt/releases
# renovate: datasource=github-releases depName=reteps/dockerfmt
ARG DOCKERFMT_VERSION=0.5.4
# https://github.com/mvdan/sh/releases
# renovate: datasource=github-releases depName=mvdan/sh
ARG SHFMT_VERSION=3.14.0
# https://github.com/koalaman/shellcheck/releases
# renovate: datasource=github-releases depName=koalaman/shellcheck
ARG SHELLCHECK_VERSION=0.11.0
# https://github.com/google/yamlfmt/releases
# renovate: datasource=github-releases depName=google/yamlfmt
ARG YAMLFMT_VERSION=0.21.0
# https://www.npmjs.com/package/markdownlint-cli2
# renovate: datasource=npm depName=markdownlint-cli2
ARG MARKDOWNLINT_VERSION=0.23.2

RUN : \
    # install dockerfmt
    && curl -fsSLo dockerfmt.tar.gz \
        https://github.com/reteps/dockerfmt/releases/download/v${DOCKERFMT_VERSION}/dockerfmt-v${DOCKERFMT_VERSION}-linux-amd64.tar.gz \
    && tar -xzf dockerfmt.tar.gz dockerfmt \
    && mv dockerfmt /usr/local/bin/ \
    && rm -f dockerfmt.tar.gz \
    # install shfmt
    && curl -fsSLo /usr/local/bin/shfmt https://github.com/mvdan/sh/releases/download/v${SHFMT_VERSION}/shfmt_v${SHFMT_VERSION}_linux_amd64 \
    && chmod +x /usr/local/bin/shfmt \
    # install shellcheck
    && curl -fsSLo shellcheck.tar.xz https://github.com/koalaman/shellcheck/releases/download/v${SHELLCHECK_VERSION}/shellcheck-v${SHELLCHECK_VERSION}.linux.x86_64.tar.xz \
    && tar -xf shellcheck.tar.xz shellcheck-v${SHELLCHECK_VERSION}/shellcheck \
    && mv shellcheck-v${SHELLCHECK_VERSION}/shellcheck /usr/local/bin/ \
    && rm -rf shellcheck.tar.xz shellcheck-v${SHELLCHECK_VERSION}/ \
    # install yamlfmt
    && curl -fsSLo yamlfmt.tar.gz https://github.com/google/yamlfmt/releases/download/v${YAMLFMT_VERSION}/yamlfmt_${YAMLFMT_VERSION}_Linux_x86_64.tar.gz \
    && tar -xzf yamlfmt.tar.gz yamlfmt \
    && mv yamlfmt /usr/local/bin/ \
    && rm -f yamlfmt.tar.gz \
    # install markdownlint-cli2
    && bun install -g markdownlint-cli2@${MARKDOWNLINT_VERSION} \
    && rm -rf ${BUN_INSTALL}/install/cache \
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
ARG CLAUDE_SKILLS_VERSION=0.4.16
# https://github.com/sickn33/agentic-awesome-skills/releases
# renovate: datasource=github-releases depName=sickn33/agentic-awesome-skills
ARG AAS_VERSION=16.8.0
# https://github.com/AZidan/codemap
# renovate: datasource=git-refs packageName=https://github.com/AZidan/codemap
ARG CODEMAP_VERSION=e0726878d2da0dc279a0f21b11dad0d04f5a2818
# https://github.com/rtk-ai/rtk/releases
# renovate: datasource=github-releases depName=rtk-ai/rtk
ARG RTK_VERSION=0.48.0

COPY scripts/install-aas-bundles.py /tmp/install-aas-bundles.py

RUN : \
    # bundle superclaude
    && curl -fsSLo superclaude.tar.gz https://github.com/SuperClaude-Org/SuperClaude_Framework/archive/refs/tags/v${SUPERCLAUDE_VERSION}.tar.gz \
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
    # bundle claude-skills
    && curl -fsSLo claude-skills.tar.gz https://github.com/Jeffallan/claude-skills/archive/refs/tags/v${CLAUDE_SKILLS_VERSION}.tar.gz \
    && tar --wildcards -xzf claude-skills.tar.gz \
        claude-skills-*/commands/ \
        claude-skills-*/skills/ \
    && mkdir -p /home/${USER}/.claude-shared/plugins-marketplaces/local/plugins/cs/.claude-plugin \
    && echo '{"name":"cs","description":"Claude Skills (https://github.com/Jeffallan/claude-skills)"}' >/home/${USER}/.claude-shared/plugins-marketplaces/local/plugins/cs/.claude-plugin/plugin.json \
    && mv claude-skills-*/commands/ /home/${USER}/.claude-shared/plugins-marketplaces/local/plugins/cs/commands/ \
    && mv claude-skills-*/skills/ /home/${USER}/.claude-shared/plugins-marketplaces/local/plugins/cs/skills/ \
    && rm -rf claude-skills.tar.gz claude-skills-* \
    # bundle agentic-awesome-skills (split into editorial bundles)
    && curl -fsSLo aas.tar.gz https://github.com/sickn33/agentic-awesome-skills/archive/refs/tags/v${AAS_VERSION}.tar.gz \
    && tar --wildcards -xzf aas.tar.gz \
        'agentic-awesome-skills-*/skills/' \
        'agentic-awesome-skills-*/docs/users/bundles.md' \
    && python3 /tmp/install-aas-bundles.py \
        agentic-awesome-skills-*/skills/ \
        agentic-awesome-skills-*/docs/users/bundles.md \
        /home/${USER}/.claude-shared/plugins-marketplaces/local/plugins/ \
    && rm -rf aas.tar.gz agentic-awesome-skills-* /tmp/install-aas-bundles.py \
    # bundle codemap (CLI + plugin)
    && curl -fsSLo codemap.tar.gz "https://github.com/AZidan/codemap/archive/${CODEMAP_VERSION}.tar.gz" \
    && tar -xzf codemap.tar.gz \
    && pip install --no-cache-dir "$(ls -d codemap-*/)[languages]" \
    && mkdir -p /home/${USER}/.claude-shared/plugins-marketplaces/local/plugins/codemap \
    && mv codemap-*/plugin/skills/ /home/${USER}/.claude-shared/plugins-marketplaces/local/plugins/codemap/ \
    && mv codemap-*/plugin/.claude-plugin/ /home/${USER}/.claude-shared/plugins-marketplaces/local/plugins/codemap/ \
    && rm -rf codemap.tar.gz codemap-*/ \
    # generate local marketplace.json from all bundled plugin.json files
    && mkdir -p /home/${USER}/.claude-shared/plugins-marketplaces/local/.claude-plugin \
    && jq -s '{"$schema":"https://anthropic.com/claude-code/marketplace.schema.json", \
      name:"local",description:"Local plugins",owner:{name:"local"}, \
      plugins:[.[]|{name:.name,description:.description,source:("./plugins/"+.name)}]}' \
        /home/${USER}/.claude-shared/plugins-marketplaces/local/plugins/*/.claude-plugin/plugin.json \
        >/home/${USER}/.claude-shared/plugins-marketplaces/local/.claude-plugin/marketplace.json \
    # install rtk (CLI + PreToolUse hook)
    && curl -fsSLo rtk.tar.gz "https://github.com/rtk-ai/rtk/releases/download/v${RTK_VERSION}/rtk-x86_64-unknown-linux-musl.tar.gz" \
    && tar -xzf rtk.tar.gz rtk \
    && mv rtk /usr/local/bin/ \
    && rm rtk.tar.gz \
    && curl -fsSLo rtk-src.tar.gz "https://github.com/rtk-ai/rtk/archive/refs/tags/v${RTK_VERSION}.tar.gz" \
    && mkdir -p /home/${USER}/.claude-shared/hooks \
    && tar --wildcards -xzf rtk-src.tar.gz 'rtk-*/hooks/claude/rtk-rewrite.sh' \
    && mv rtk-*/hooks/claude/rtk-rewrite.sh /home/${USER}/.claude-shared/hooks/ \
    && chmod +x /home/${USER}/.claude-shared/hooks/rtk-rewrite.sh \
    && rm -rf rtk-src.tar.gz

##
# Managed settings and workarounds
##

COPY scripts/* /usr/local/bin/
COPY claude-shared/ /home/${USER}/.claude-shared

RUN : \
    # workaround for nested procfs mount failures (replaces buggy enableWeakerNestedSandbox)
    && mv /usr/bin/bwrap /usr/bin/bwrap.real \
    && ln -fsr /usr/local/bin/bwrap-shim.sh /usr/bin/bwrap

#XXX: experimets with nested podman
# RUN :\
#     # force single-UID mapping in nested podman
#     && rm -rf /etc/subuid /etc/subgid \
#     # use vfs for nested podman storage ("Error: configure storage: 'overlay' is not supported over overlayfs")
#     && mkdir -p /etc/containers \
#     && printf '[storage]\ndriver = "vfs"' >>/etc/containers/storage.conf
#     #&& printf '[storage]\ndriver = "overlay"\n\n[storage.options]\nignore_chown_errors = "true"\n' >>/etc/containers/storage.conf
# # use ephemeral runtime dir if under sandboxed Bash tool (nested podman "cannot set user namespace")
# ENV XDG_RUNTIME_DIR=/home/${USER}/.local

##
# Customize shell interface
##
ENV EDITOR=vim
ENV HOME=/home/agent
RUN echo '# Shell customization (gw0)' >>/etc/bash.bashrc \
    && echo 'source /usr/share/bash-completion/bash_completion' >>/etc/bash.bashrc \
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
    && git config --system --add safe.directory '*' \
    && chmod +x /usr/local/bin/*.sh \
    # setup claude dirs, persistent storage, and symlinks
    && mkdir -p /home/${USER}/.claude /etc/claude-code /home/${USER}/.config \
    && ln -fsr /home/${USER}/.claude/.claude.json /home/${USER}/.claude.json \
    && ln -fsr /home/${USER}/.claude/.claude.json.backup /home/${USER}/.claude.json.backup \
    && ln -fsr /home/${USER}/.claude/managed-settings.d /etc/claude-code/managed-settings.d \
    && ln -fsr /home/${USER}/.claude/.bashrc /home/${USER}/.bashrc \
    && ln -fsr /home/${USER}/.claude/.gitconfig /home/${USER}/.gitconfig \
    && ln -fsr /home/${USER}/.claude/.gh-config /home/${USER}/.config/gh \
    && chown -R ${USER}:${USER} /home/${USER} \
    # allow to run with any UID/GID as user with writable home
    && chmod 777 /home/${USER}

USER ${USER}:${USER}
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/bin/bash"]