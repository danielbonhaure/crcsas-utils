

##########################
## Set GLOBAL arguments ##
##########################

# Set python version
ARG PYTHON_VERSION=3.11

# Set APP installation folder
ARG APP_HOME=/opt/utils

# App data folder
ARG APP_DATA=/data/utils

# Set user name and id
ARG USR_NAME="nonroot"
ARG USER_UID="1000"

# Set group name and id
ARG GRP_NAME="nonroot"
ARG USER_GID="1000"

# Set users passwords
ARG ROOT_PWD="root"
ARG USER_PWD=$USR_NAME

# Set Pycharm version
ARG PYCHARM_VERSION=2023.1



######################################
## Stage 1: Install Python packages ##
######################################

# Create image
FROM python:${PYTHON_VERSION}-slim AS py_builder

# Set environment variables
ARG DEBIAN_FRONTEND=noninteractive

# Set python environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Install OS packages
RUN apt-get -y -qq update && \
    apt-get -y -qq upgrade && \
    apt-get -y -qq --no-install-recommends install \
        build-essential \
        gdal-bin libgdal-dev && \
    rm -rf /var/lib/apt/lists/*

# Set work directory
WORKDIR /usr/src/app

# Upgrade pip and install dependencies
COPY requirements.txt /tmp/requirements.txt
RUN python3 -m pip install --upgrade pip && \
    python3 -m pip wheel --no-cache-dir --no-deps \
    --wheel-dir /usr/src/app/wheels -r /tmp/requirements.txt



###############################################
## Stage 2: Copy Python installation folders ##
###############################################

# Create image
FROM python:${PYTHON_VERSION}-slim AS py_final

# Set environment variables
ARG DEBIAN_FRONTEND=noninteractive

# Install OS packages
RUN apt-get -y -qq update && \
    apt-get -y -qq upgrade && \
    apt-get -y -qq --no-install-recommends install \
        gdal-bin && \
    rm -rf /var/lib/apt/lists/*

# Install python dependencies from py_builder
COPY --from=py_builder /usr/src/app/wheels /wheels
RUN python3 -m pip install --upgrade pip && \
    python3 -m pip install --no-cache /wheels/* && \
    rm -rf /wheels



###################################
## Stage 3: Create non-root user ##
###################################

# Create image
FROM py_final AS non_root

# Renew ARGs
ARG USR_NAME
ARG USER_UID
ARG GRP_NAME
ARG USER_GID
ARG ROOT_PWD
ARG USER_PWD

# Install OS packages
RUN apt-get -y -qq update && \
    apt-get -y -qq upgrade && \
    apt-get -y -qq --no-install-recommends install \
        # to run sudo
        sudo && \
    rm -rf /var/lib/apt/lists/*

# Modify root password
RUN echo "root:$ROOT_PWD" | chpasswd

# Create a non-root user, so the container can run as non-root
# OBS: the UID and GID must be the same as the user that own the
# input and the output volumes, so there isn't perms problems!!
# Se recomienda crear usuarios en el contendor de esta manera,
# ver: https://nickjanetakis.com/blog/running-docker-containers-as-a-non-root-user-with-a-custom-uid-and-gid
# Se agregar --no-log-init para prevenir un problema de seguridad,
# ver: https://jtreminio.com/blog/running-docker-containers-as-current-host-user/
RUN groupadd --gid $USER_GID $GRP_NAME
RUN useradd --no-log-init --uid $USER_UID --gid $USER_GID --shell /bin/bash \
    --comment "Non-root User Account" --create-home $USR_NAME

# Modify the password of non-root user
RUN echo "$USR_NAME:$USER_PWD" | chpasswd

# Add non-root user to sudoers and to adm group
# The adm group was added to allow non-root user to see logs
RUN usermod -aG sudo $USR_NAME && \
    usermod -aG adm $USR_NAME

# To allow sudo without password
RUN echo "$USR_NAME ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/$USR_NAME && \
    chmod 0440 /etc/sudoers.d/$USR_NAME



###########################################
## Stage 4: Install management packages  ##
###########################################

# Create image
FROM non_root AS base_builder

# Set environment variables
ARG DEBIAN_FRONTEND=noninteractive

# Install OS packages
RUN apt-get -y -qq update && \
    apt-get -y -qq upgrade && \
    apt-get -y -qq --no-install-recommends install \
        # install Tini (https://github.com/krallin/tini#using-tini)
        tini \
        # to see process with pid 1
        htop \
        # to allow edit files
        vim \
        # to show progress through pipelines
        pv && \
    rm -rf /var/lib/apt/lists/*

# Add Tini (https://github.com/krallin/tini#using-tini)
ENTRYPOINT ["/usr/bin/tini", "-g", "--"]



####################################
## Stage 5: Install and setup APP ##
####################################

# Create image
FROM base_builder AS app_builder

# Set environment variables
ARG DEBIAN_FRONTEND=noninteractive

# Renew ARGs
ARG APP_HOME
ARG APP_DATA
ARG USR_NAME
ARG GRP_NAME

# Create APP_HOME folder and change its owner
RUN mkdir -p $APP_HOME && chown -R $USR_NAME:$GRP_NAME $APP_HOME

# Copy project
COPY --chown=$USR_NAME:$GRP_NAME ./*.py $APP_HOME

# Create data folder (this folder are too big so it must be mounted as volume)
RUN mkdir -p $APP_HOME/data



############################################
## Stage 6.1: Install Pycharm (for debug) ##
############################################

# Create image
FROM app_builder AS pycharm

# Renew ARGs
ARG APP_HOME
ARG USR_NAME
ARG GRP_NAME

# Become root
USER root

# Updata apt cache and install wget
RUN apt-get -y -qq update && \
    apt-get -y -qq upgrade && \
    apt-get -y -qq --no-install-recommends install \
        wget \
        git

# Renew ARGs
ARG PYCHARM_VERSION

# Download Pycharm IDE
RUN wget https://download.jetbrains.com/python/pycharm-community-${PYCHARM_VERSION}.tar.gz -P /tmp/

# Install packages required to run PyCharm IDE
RUN count=$(ls /tmp/pycharm-*.tar.gz | wc -l) && [ $count = 1 ] \
    && apt-get -y -qq --no-install-recommends install \
        # Without this packages, PyCharm don't start
        libxrender1 libxtst6 libxi6 libfreetype6 fontconfig \
        # Without this packages, PyCharm start, but reports that they are missing
        libatk1.0-0 libatk-bridge2.0-0 libdrm-dev libxkbcommon-dev libdbus-1-3 \
        libxcomposite1 libxdamage1 libxfixes3 libxrandr-dev libgbm1 libasound2 \
        libcups2 libatspi2.0-0 libxshmfence1 \
        # Without this packages, PyCharm start, but shows errors when running
        procps libsecret-1-0 gnome-keyring libxss1 libxext6 firefox-esr \
        #libnss3 libxext-dev libnspr4 \
    || :  # para entender porque :, ver https://stackoverflow.com/a/49348392/5076110

# Install PyCharm IDE
RUN count=$(ls /tmp/pycharm-*.tar.gz | wc -l) && [ $count = 1 ] \
    && mkdir /opt/pycharm \
    && tar xzf /tmp/pycharm-*.tar.gz -C /opt/pycharm --strip-components 1 \
    && chown -R $USR_NAME:$GRP_NAME /opt/pycharm \
    || :  # para entender porque :, ver https://stackoverflow.com/a/49348392/5076110

# Renew ARGs
ARG PYTHON_VERSION

# Pycharm espera que los paquetes python estén en dist-packages, pero están en site-packages.
# Esto es así porque python no se instaló usando apt o apt-get, y cuando esto ocurre, la carpeta
# en la que se instalan los paquetes es site-packages y no dist-packages.
RUN mkdir -p /usr/local/lib/python${PYTHON_VERSION}/dist-packages \
    && ln -s /usr/local/lib/python${PYTHON_VERSION}/site-packages/* \
             /usr/local/lib/python${PYTHON_VERSION}/dist-packages/

# Change to non-root user
USER $USR_NAME

# Set work directory
WORKDIR $APP_HOME

# Run pycharm under Tini (https://github.com/krallin/tini#using-tini)
CMD ["sh", "/opt/pycharm/bin/pycharm.sh", "-Dide.browser.jcef.enabled=false"]
# or docker run your-image /your/program ...


# Ejecución de pycharm:
#
# 1- docker volume create crcsas-utils-home
#
# 2- export DOCKER_BUILDKIT=1
#
# 3- docker build --force-rm \
#      --target pycharm \
#      --tag crcsas-utils:pycharm \
#      --build-arg USER_UID=$(stat -c "%u" .) \
#      --build-arg USER_GID=$(stat -c "%g" .) \
#      --file dockerfile .
#
# 4- docker run -ti --rm \
#      --name crcsas-utils-pycharm \
#      --env DISPLAY=$DISPLAY \
#      --volume /tmp/.X11-unix:/tmp/.X11-unix \
#      --volume $(pwd):/opt/utils/ \
#      --volume crcsas-utils-home:/home/nonroot \
#      --detach crcsas-utils:pycharm



##############################################
## Stage 6.2: Setup and run final APP image ##
##############################################

# Create image
FROM app_builder AS final_app_image

# Become root
USER root

# Renew the ARG
ARG USR_NAME

# Add Tini (https://github.com/krallin/tini#using-tini)
ENTRYPOINT ["/usr/bin/tini", "-g", "--"]

# Run your program under Tini (https://github.com/krallin/tini#using-tini)
CMD [ "python", "--version"]
# or docker run your-image /your/program ...

# Access non-root user directory
WORKDIR /home/$USR_NAME

# Switch back to non-root user to avoid accidental container runs as root
USER $USR_NAME



####################################
## Stage 7: Set the DEFAULT image ##
####################################

FROM final_app_image



# CONSTRUIR CONTENEDOR
#
# DOCKER_BUILDKIT=1 \
# docker build --force-rm \
#   --target final_app_image \
#   --tag ghcr.io/crc-sas/crcssa:utils \
#   --build-arg USER_UID=$(stat -c "%u" .) \
#   --build-arg USER_GID=$(stat -c "%g" .) \
#   --file dockerfile .

# docker push ghcr.io/crc-sas/crcssa:utils

# CORRER CONTENEDOR
#
# docker run --name crcsas-utils --volume $(pwd):/data ghcr.io/crc-sas/crcssa:utils \
#   --rm -t bash -c "ls /data/2023_Indices.nc | xargs python /opt/netcdf.py"
