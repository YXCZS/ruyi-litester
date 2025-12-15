# Use Arch Linux ARM official image to avoid pulling amd64 on ARM runners
FROM ghcr.io/archlinux/archlinux:base AS builder
WORKDIR /ruyi-litester

# Use upstream multi-arch image; platform is selected by the workflow --platform flag
# Optionally set a China mirror to speed up; commented to keep default
# RUN echo "Server = https://mirrors.tuna.tsinghua.edu.cn/archlinux/$repo/os/$arch" > /etc/pacman.d/mirrorlist
# RUN sed -i '/^NoExtract  = usr\/share\/locale\/\* usr\/share\/X11\/locale\/\* usr\/share\/i18n\/\*/d' /etc/pacman.conf
RUN pacman-key --init \
    && pacman --noconfirm -Syyu \
    && pacman --need --noconfirm -S llvm sudo file expect git make tar jq go-yq python
RUN sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
    && locale-gen \
    && echo 'LANG=en_US.UTF-8' > /etc/locale.conf

FROM builder
ARG UNAME=ruyisdk_test
RUN useradd -mG wheel -s /bin/bash $UNAME
RUN echo '%wheel ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

WORKDIR /ruyi-litester
COPY . .
RUN chown -R $UNAME:$UNAME /ruyi-litester
USER $UNAME

ENTRYPOINT ["docker/test_run.sh"]

