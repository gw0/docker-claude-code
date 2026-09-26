# syntax=docker/dockerfile:1
# Dockerfile for docker-claude-code
#
#   docker build --progress=plain -t docker-claude-code .
#   docker run -it --rm -v ${HOME}/.claude:/home/agent/.claude -v ${PWD}:${PWD}:rslave -w ${PWD} docker-claude-code claude
#
# Sections are ordered from least to most frequently changed to maximize layer reuse.
#

FROM docker.io/library/debian:trixie-slim@sha256:a99cfc517144bc59b1978475ec53b46ecabec7e43635402ee5b77cc54cd1b20a

##
# Base system
##
# https://github.com/oven-sh/bun/releases
# renovate: datasource=github-releases depName=oven-sh/bun extractVersion=^bun-v(?<version>.+)$
ARG BUN_VERSION=1.4.2

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV EDITOR=vim
# configure global bun packages location
ENV BUN_INSTALL=/usr/local/bun
ENV BUN_INSTALL_BIN=/usr/local/bin
# download into /tmp tmpfs mounts
WORKDIR /tmp
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    --mount=type=tmpfs,target=/tmp \
    : \
    # configure apt (keep cache, allow running as root)
    && rm -f /etc/apt/apt.conf.d/docker-clean \
    && echo 'APT::Sandbox::User "root";' >/etc/apt/apt.conf.d/99no-sandbox \
    # upgrade base system
    && apt-get update -qq \
    && apt-get upgrade -y \
    # install packages
    && apt-get install -y --no-install-recommends \
        # essentials
        ca-certificates \
        curl \
        gnupg \
        unzip \
        # shell utils
        bash-completion \
        htop \
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
        # dev utils
        binutils \
        file \
        gh \
        git \
        make \
        man-db \
        python3-pip \
        python3-venv \
        ripgrep \
        time \
        xxd \
        # spellcheck
        hunspell \
        hunspell-en-us \
        # system utils
        bubblewrap \
        libnss-wrapper \
        unattended-upgrades \
    # add Docker apt repo
    && curl -fsSLo /etc/apt/keyrings/docker.asc https://download.docker.com/linux/debian/gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo "${VERSION_CODENAME}") stable" >/etc/apt/sources.list.d/docker.list \
    && apt-get update -qq \
    && apt-get install -y --no-install-recommends \
        # infra utils
        docker-ce-cli \
        docker-buildx-plugin \
        docker-compose-plugin \
        kind \
        kubectl \
    # set timezone
    && echo "${TZ}" >/etc/timezone \
    && ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime \
    # set default editor
    && update-alternatives --set editor /usr/bin/vim.basic \
    # allow system-wide pip install
    && rm /usr/lib/python*/EXTERNALLY-MANAGED \
    # trust repos of any owner
    && git config --system --add safe.directory '*' \
    # use only one /tmp
    && rm -rf /var/tmp \
    && ln -s /tmp /var/tmp \
    # install bun, bunx, node
    && curl -fsSLo bun.zip https://github.com/oven-sh/bun/releases/download/bun-v${BUN_VERSION}/bun-linux-x64-baseline.zip \
    && unzip -j bun.zip bun-linux-x64-baseline/bun -d /usr/local/bin/ \
    && ln -s bun /usr/local/bin/bunx \
    && ln -s bun /usr/local/bin/node \
    && ln -s bun /usr/local/bin/npm \
    && ln -s bun /usr/local/bin/npx \
    && ln -s bun /usr/local/bin/yarn \
    && ln -s bun /usr/local/bin/pnpm \
    # print versions
    && bun --version \
    && python3 --version \
    && docker --version \
    && kubectl version --client

##
# User and shell
##
ARG USER=agent
ARG USER_UID=1000
ARG USER_GID=1000

RUN : \
    # create non-root user
    && groupadd -g ${USER_GID} ${USER} \
    && useradd --create-home --shell /bin/bash -u ${USER_UID} -g ${USER_GID} ${USER} \
    # customize shell interface
    && echo '# Shell customization (gw0)' >>/etc/bash.bashrc \
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
    # persist dotfiles in ~/.claude mount
    && mkdir -p /home/${USER}/.claude /home/${USER}/.config /etc/claude-code \
    && ln -fsr /home/${USER}/.claude/.claude.json /home/${USER}/.claude.json \
    && ln -fsr /home/${USER}/.claude/.claude.json.backup /home/${USER}/.claude.json.backup \
    && ln -fsr /home/${USER}/.claude/.bashrc /home/${USER}/.bashrc \
    && ln -fsr /home/${USER}/.claude/.gitconfig /home/${USER}/.gitconfig \
    && ln -fsr /home/${USER}/.claude/.gh-config /home/${USER}/.config/gh \
    # link managed settings via ~/.claude to ~/.claude-shared
    && ln -fsr /home/${USER}/.claude/managed-settings.d /etc/claude-code/managed-settings.d \
    && chown ${USER}:${USER} /home/${USER}/.claude /home/${USER}/.config \
    # allow any UID/GID to write into home
    && chmod 777 /home/${USER}

##
# Lint/fmt tools
##
# https://github.com/reteps/dockerfmt/releases
# renovate: datasource=github-releases depName=reteps/dockerfmt
ARG DOCKERFMT_VERSION=0.5.4
# https://github.com/mvdan/sh/releases
# renovate: datasource=github-releases depName=mvdan/sh
ARG SHFMT_VERSION=3.14.1
# https://github.com/koalaman/shellcheck/releases
# renovate: datasource=github-releases depName=koalaman/shellcheck
ARG SHELLCHECK_VERSION=0.11.0
# https://github.com/google/yamlfmt/releases
# renovate: datasource=github-releases depName=google/yamlfmt
ARG YAMLFMT_VERSION=0.21.0
# https://github.com/astral-sh/ruff/releases
# renovate: datasource=github-releases depName=astral-sh/ruff
ARG RUFF_VERSION=0.16.8
# https://www.npmjs.com/package/markdownlint-cli2
# renovate: datasource=npm depName=markdownlint-cli2
ARG MARKDOWNLINT_VERSION=0.23.3

RUN --mount=type=cache,target=/usr/local/bun/install/cache \
    --mount=type=tmpfs,target=/tmp \
    : \
    # install dockerfmt
    && curl -fsSLo dockerfmt.tar.gz https://github.com/reteps/dockerfmt/releases/download/v${DOCKERFMT_VERSION}/dockerfmt-v${DOCKERFMT_VERSION}-linux-amd64.tar.gz \
    && tar -xzf dockerfmt.tar.gz -C /usr/local/bin/ dockerfmt \
    # install shfmt
    && curl -fsSLo /usr/local/bin/shfmt https://github.com/mvdan/sh/releases/download/v${SHFMT_VERSION}/shfmt_v${SHFMT_VERSION}_linux_amd64 \
    && chmod +x /usr/local/bin/shfmt \
    # install shellcheck
    && curl -fsSLo shellcheck.tar.xz https://github.com/koalaman/shellcheck/releases/download/v${SHELLCHECK_VERSION}/shellcheck-v${SHELLCHECK_VERSION}.linux.x86_64.tar.xz \
    && tar -xf shellcheck.tar.xz -C /usr/local/bin/ --strip-components=1 shellcheck-v${SHELLCHECK_VERSION}/shellcheck \
    # install yamlfmt
    && curl -fsSLo yamlfmt.tar.gz https://github.com/google/yamlfmt/releases/download/v${YAMLFMT_VERSION}/yamlfmt_${YAMLFMT_VERSION}_Linux_x86_64.tar.gz \
    && tar -xzf yamlfmt.tar.gz -C /usr/local/bin/ yamlfmt \
    # install ruff
    && curl -fsSLo ruff.tar.gz https://github.com/astral-sh/ruff/releases/download/${RUFF_VERSION}/ruff-x86_64-unknown-linux-musl.tar.gz \
    && tar -xzf ruff.tar.gz -C /usr/local/bin/ --strip-components=1 ruff-x86_64-unknown-linux-musl/ruff \
    # install markdownlint-cli2
    && bun install -g markdownlint-cli2@${MARKDOWNLINT_VERSION} \
    # print versions
    && dockerfmt version \
    && shfmt --version \
    && shellcheck --version \
    && yamlfmt --version \
    && ruff --version \
    && markdownlint-cli2 .nonexistent

##
# Claude tools
##
# https://github.com/Owloops/claude-powerline/releases
# renovate: datasource=npm depName=@owloops/claude-powerline
ARG CLAUDE_POWERLINE_VERSION=1.31.0
# https://github.com/affaan-m/agentshield/releases
# renovate: datasource=npm depName=ecc-agentshield
ARG AGENTSHIELD_VERSION=1.6.0
# https://github.com/dandavison/delta/releases
# renovate: datasource=github-releases depName=dandavison/delta
ARG GIT_DELTA_VERSION=0.19.2

RUN --mount=type=cache,target=/usr/local/bun/install/cache \
    --mount=type=tmpfs,target=/tmp \
    : \
    && bun install -g \
        # install claude-powerline
        @owloops/claude-powerline@${CLAUDE_POWERLINE_VERSION} \
        # install ecc-agentshield
        ecc-agentshield@${AGENTSHIELD_VERSION} \
    # install git-delta
    && curl -fsSLo git-delta.deb https://github.com/dandavison/delta/releases/download/${GIT_DELTA_VERSION}/git-delta-musl_${GIT_DELTA_VERSION}_amd64.deb \
    && dpkg -i git-delta.deb \
    # print versions
    && agentshield --version \
    && delta --version

##
# Claude plugins
##
# https://github.com/AZidan/codemap
# renovate: datasource=github-releases depName=AZidan/codemap
ARG CODEMAP_VERSION=1.3.1
# https://github.com/rtk-ai/rtk/releases
# renovate: datasource=github-releases depName=rtk-ai/rtk
ARG RTK_VERSION=0.49.0
# https://github.com/SuperClaude-Org/SuperClaude_Framework/releases
# renovate: datasource=github-releases depName=SuperClaude-Org/SuperClaude_Framework
ARG SUPERCLAUDE_VERSION=4.3.0
# https://github.com/Jeffallan/claude-skills/releases
# renovate: datasource=github-releases depName=Jeffallan/claude-skills
ARG CLAUDE_SKILLS_VERSION=0.4.16
# https://github.com/sickn33/agentic-awesome-skills/releases
# renovate: datasource=github-releases depName=sickn33/agentic-awesome-skills
ARG AAS_VERSION=18.2.0

RUN --mount=type=bind,source=scripts/install-aas-bundles.py,target=/mnt/install-aas-bundles.py \
    --mount=type=cache,target=/root/.cache/pip \
    --mount=type=tmpfs,target=/tmp \
    : \
    && marketplace=/home/${USER}/.claude-shared/plugins/marketplaces/local \
    # bundle codemap (CLI + plugin)
    && curl -fsSLo codemap.tar.gz https://github.com/AZidan/codemap/archive/refs/tags/v${CODEMAP_VERSION}.tar.gz \
    && tar -xzf codemap.tar.gz \
    && pip install "./$(ls -d codemap-*/)[languages]" \
    && mkdir -p ${marketplace}/plugins/codemap \
    && mv codemap-*/plugin/skills/ ${marketplace}/plugins/codemap/ \
    && mv codemap-*/plugin/.claude-plugin/ ${marketplace}/plugins/codemap/ \
    # bundle rtk (CLI + PreToolUse hook)
    && curl -fsSLo rtk.tar.gz https://github.com/rtk-ai/rtk/releases/download/v${RTK_VERSION}/rtk-x86_64-unknown-linux-musl.tar.gz \
    && tar -xzf rtk.tar.gz -C /usr/local/bin/ rtk \
    && curl -fsSLo rtk-src.tar.gz https://github.com/rtk-ai/rtk/archive/refs/tags/v${RTK_VERSION}.tar.gz \
    && mkdir -p /home/${USER}/.claude-shared/hooks \
    && tar --wildcards -xzf rtk-src.tar.gz -C /home/${USER}/.claude-shared/hooks/ --strip-components=3 'rtk-*/hooks/claude/rtk-rewrite.sh' \
    && chmod +x /home/${USER}/.claude-shared/hooks/rtk-rewrite.sh \
    # bundle superclaude
    && curl -fsSLo superclaude.tar.gz https://github.com/SuperClaude-Org/SuperClaude_Framework/archive/refs/tags/v${SUPERCLAUDE_VERSION}.tar.gz \
    && tar --wildcards -xzf superclaude.tar.gz \
        'SuperClaude_Framework-*/plugins/superclaude/commands/' \
        'SuperClaude_Framework-*/plugins/superclaude/skills/' \
        'SuperClaude_Framework-*/plugins/superclaude/agents/' \
    && mkdir -p ${marketplace}/plugins/sc/.claude-plugin \
    && echo '{"name":"sc","description":"SuperClaude Framework (https://github.com/SuperClaude-Org/SuperClaude_Framework)"}' >${marketplace}/plugins/sc/.claude-plugin/plugin.json \
    && mv SuperClaude_Framework-*/plugins/superclaude/commands/ ${marketplace}/plugins/sc/commands/ \
    && mv SuperClaude_Framework-*/plugins/superclaude/skills/ ${marketplace}/plugins/sc/skills/ \
    && mv SuperClaude_Framework-*/plugins/superclaude/agents/ ${marketplace}/plugins/sc/agents/ \
    # bundle claude-skills
    && curl -fsSLo claude-skills.tar.gz https://github.com/Jeffallan/claude-skills/archive/refs/tags/v${CLAUDE_SKILLS_VERSION}.tar.gz \
    && tar --wildcards -xzf claude-skills.tar.gz \
        'claude-skills-*/commands/' \
        'claude-skills-*/skills/' \
    && mkdir -p ${marketplace}/plugins/cs/.claude-plugin \
    && echo '{"name":"cs","description":"Claude Skills (https://github.com/Jeffallan/claude-skills)"}' >${marketplace}/plugins/cs/.claude-plugin/plugin.json \
    && mv claude-skills-*/commands/ ${marketplace}/plugins/cs/commands/ \
    && mv claude-skills-*/skills/ ${marketplace}/plugins/cs/skills/ \
    # bundle agentic-awesome-skills (per editorial bundle and plugin)
    && curl -fsSLo aas.tar.gz https://github.com/sickn33/agentic-awesome-skills/archive/refs/tags/v${AAS_VERSION}.tar.gz \
    && tar --wildcards -xzf aas.tar.gz \
        'agentic-awesome-skills-*/skills/' \
        'agentic-awesome-skills-*/docs/users/bundles.md' \
    && python3 /mnt/install-aas-bundles.py \
        agentic-awesome-skills-*/skills/ \
        agentic-awesome-skills-*/docs/users/bundles.md \
        ${marketplace}/plugins/ \
    # generate local marketplace.json from all bundled plugin.json files
    && mkdir -p ${marketplace}/.claude-plugin \
    && jq -s '{"$schema":"https://anthropic.com/claude-code/marketplace.schema.json", \
      name:"local",description:"Local plugins",owner:{name:"local"}, \
      plugins:[.[]|{name:.name,description:.description,source:("./plugins/"+.name)}]}' \
        ${marketplace}/plugins/*/.claude-plugin/plugin.json \
        >${marketplace}/.claude-plugin/marketplace.json \
    # print versions
    && codemap --version \
    && rtk --version \
    && ls -1 ${marketplace}/plugins | wc -l

##
# Claude Code
##
# https://www.npmjs.com/package/@anthropic-ai/claude-code/v/latest
# renovate: datasource=npm depName=@anthropic-ai/claude-code
ARG CLAUDE_VERSION=2.1.280

RUN --mount=type=cache,target=/usr/local/bun/install/cache \
    : \
    # install claude
    && bun install -g @anthropic-ai/claude-code@${CLAUDE_VERSION} \
    # print versions
    && claude --version

##
# Managed settings and workarounds
##
COPY --chmod=755 scripts/entrypoint.sh scripts/bwrap-shim.sh /usr/local/bin/
COPY claude-shared/ /home/${USER}/.claude-shared/

RUN : \
    # wrap bwrap to rewrite problematic args in nested/gVisor sandboxes (see bwrap-shim.sh)
    && dpkg-divert --local --rename --divert /usr/bin/bwrap.real /usr/bin/bwrap \
    && ln -s /usr/local/bin/bwrap-shim.sh /usr/bin/bwrap

ENV USER=${USER}
ENV HOME=/home/${USER}
USER ${USER_UID}:${USER_GID}
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/bin/bash"]