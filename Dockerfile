FROM ubuntu:20.04

# Set the image version as early as possible. Placing this at the top ensures the Docker cache is busted when the version is
# changed. The value of IMAGE_VERSION is displayed in the command prompt of a container.
ENV IMAGE_VERSION=3.0.0

# *****************************************************************************************************************************
# Configure the proxy. Uncomment if needed.
#
# ARG PROXY=<some proxy here>
# ARG NO_PROXY=host.docker.internal
# ENV http_proxy=$PROXY \
#   HTTP_PROXY=$PROXY \
#   https_proxy=$PROXY \
#   HTTPS_PROXY=$PROXY \
#   no_proxy=$NO_PROXY \
#   NO_PROXY=$NO_PROXY

# # The environment variables must also be defined in /etc/environment for apt-get to work.
# RUN echo "http_proxy=$PROXY" | tee -a /etc/environment && \
#   echo "HTTP_PROXY=$PROXY" | tee -a /etc/environment && \
#   echo "https_proxy=$PROXY" | tee -a /etc/environment && \
#   echo "HTTPS_PROXY=$PROXY" | tee -a /etc/environment && \
#   echo "no_proxy=$NO_PROXY" | tee -a /etc/environment && \
#   echo "NO_PROXY=$NO_PROXY" | tee -a /etc/environment
# *****************************************************************************************************************************

# Docker images work with the root account by default. A non-root user is created for development work.
ENV DEV_USER=dev
# Set the home location for the non-root dev user.
ENV HOME_DIR=/home/$DEV_USER
# Recommend ~/Projects as the primary place to work on projects inside a container. Towards the end of this Dockerfile,
# this folder will be come the work folder.
ENV PROJECTS_DIR=$HOME_DIR/Projects
# Set the folder, on the host, that contains files that the user must supply before they build an image. This Dockerfile
# expects the user to provide info (like SSH keys) that can help setup an image.
ENV HOST_USER_FILES_DIR=./user_files
# Set the folder, on the host, that contains binaries files that can be copied into a container. The docker_rde expects
# some files to be provided by the user at build time.
ENV HOST_BINARIES_DIR=./binaries
# Set the folder, on the host, that contains template files that can be copied into a container. The location where each
# file ultimately gets placed depends on the file.
ENV HOST_TEMPLATES_DIR=./templates
# Set the folder, on the host, that contains additional build scripts that help create an image. These scripts hold complex
# logic that can't be executed directly in the Dockerfile. The scripts are copied into an image when building, and execute
# inside an intermediate container.
ENV HOST_BUILD_SCRIPTS_DIR=./build_scripts
# The main directory that will hold user supplied binaries during build time. Any files placed in here will be copied into the
# container. Some binaries must be provided to complete the build process. This folder can be used to pass other binaries
# if needed. The binaries folder is not removed during the build process.
ENV BINARIES_DIR=$HOME_DIR/binaries
# The main directory where temporary build files are copied/downloaded.
ENV BUILD_DIR=$HOME_DIR/build
# Set the place where build scripts are stored in an intermediate image. This folder is temporary and only used when building
# an image. The Dockerfile deletes this folder near the end.
ENV BUILD_SCRIPTS_DIR=$BUILD_DIR/build_scripts
# Set the place where user files are stored in an intermediate image. This folder is temporary and only used when building
# an image. The Dockerfile deletes this folder near the end.
ENV USER_FILES_DIR=$BUILD_DIR/user_files

# *****************************************************************************************************************************
# Stop 'debconf: unable to initialize frontend: Dialog' warning messages during the build process.

# This is only used to suppress unnecessary output during the build process so an ARG is used.
ARG DEBIAN_FRONTEND=noninteractive
# Some tools don't look at the DEBIAN_FRONTEND environment variable. This command suppresses output for those tools. The
# solution is taken from https://github.com/phusion/baseimage-docker/issues/58#issuecomment-47995343.
# At the bottom of this Dockerfile, there's a similar command that reverts DEBIAN_FRONTEND to "Dialog" (which is the default).
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections
# *****************************************************************************************************************************

# *****************************************************************************************************************************
# Run the first update and get the apt-utils package installed. 'apt-get update' must be run at least once before trying to
# install anything, or an error will be raised. apt-utils must be installed first or the following warning will be written
# by later commands (usually in an 'apt-get install'):
#
#  debconf: delaying package configuration, since apt-utils is not installed
RUN apt-get -qq update && \
  # '>/dev/null 2>&1' hides a "debconf: delaying .." warning that would appear here.
  apt-get install -y apt-utils >/dev/null 2>&1
# *****************************************************************************************************************************

# *****************************************************************************************************************************
# Upgrade packages that are present by default in the base Ubuntu image.
RUN apt-get -y upgrade
# *****************************************************************************************************************************

# *****************************************************************************************************************************
# Install common packages. The base Ubuntu image provides a minimal Ubuntu OS. It's missing many common packages that
# developers expect to have in Ubuntu. Add simple packages here. Complex packages (like Postgres, yarn, etc...) should be
# added in their own step. THey usually require additional configuration.
RUN apt-get install -y \
  # Allows apt-get to use repos that use https.
  apt-transport-https \
  # Lets tools like apt ask question in the terminal.
  dialog \
  # Installs the curl command.
  curl \
  # Install the ping command.
  iputils-ping \
  # Needed to correctly install the locale (provides locale support and many command like locale-gen & update-locale).
  locales \
  # Installs the nano editor.
  nano \
  # Adds commands to apt-get.
  software-properties-common \
  # Installs sudo.
  sudo \
  # Installs the wget tool.
  wget \
  # Installs a font server.
  xfstt xauth xorg \
  # Installs Ubuntu fonts.
  ttf-ubuntu-font-family
# *****************************************************************************************************************************

# *****************************************************************************************************************************
# Setup timezone info. Once the tzdata package is installed on the system, more timezones can be found by running
#  ls -lha /usr/share/zoneinfo
ARG TIME_ZONE=Etc/UTC
RUN apt-get install -y tzdata && \
  # link /etc/localtime/ to the correct timezone file.
  ln -fns /usr/share/zoneinfo/$TIME_ZONE /etc/localtime && \
  # Ensure /etc/timezone is updated
  dpkg-reconfigure tzdata
# *****************************************************************************************************************************

# *****************************************************************************************************************************
# Setup locales.
# Install the English locale.
RUN sudo locale-gen en_US.UTF-8
# LANG is the default language for the system. There are additional variables (like LC_NUMERIC, LC_CTYPE, LC_MESSAGES, etc...)
# that control specific categories of functionality. LANG is the catch-all if none of them are used. See
# https://www.gnu.org/software/gettext/manual/html_node/Locale-Environment-Variables.html#Locale-Environment-Variables for
# information about how LANG, LANGUAGE, LC_* are used.
ENV LANG=en_US.UTF-8
# LANGUAGE is a colon separated list, that specifies the languages to use for some commands. Some libraries/tools use
# LANGUAGE over LANG (and LC_ALL) if it's set. LANGUAGE is different from all the other locale variables in that
# it can use an abbreviated form. The full form uses 'll_cc' where 'll' is the language and 'cc' is a country abbreviation.
# An example is 'pt_PT:fr_FR:ru_RU' which means, try to use Portuguese first. If that's not installed, use French, then Russian.
# In the abbreviated form of LANGUAGE, the 'CC' part is dropped. The previous example can also be declared as 'pt:fr:ru'.
# For more info, see https://www.gnu.org/software/gettext/manual/html_node/The-LANGUAGE-variable.html#The-LANGUAGE-variable.
# If none of them languages are available on the system, it defaults to English.
ENV LANGUAGE=en_US
# LC_COLLATE controls sorting rules. C gives natural sorting. Some systems default to en_US.UTF-8, but it has sorting
# rules that don't work well with special characters.
ENV LC_COLLATE=C
# LC_CTYPE controls text transform rules. C gives natural transformations. Some systems default to en_US.UTF-8, but it has
# transformation rules that don't work well with special characters.
ENV LC_CTYPE=C
# *****************************************************************************************************************************

# *****************************************************************************************************************************
# Create the non-root user account to be used for development.
RUN useradd -ms /bin/bash $DEV_USER
# *****************************************************************************************************************************

# *****************************************************************************************************************************
# Configure password-less sudo for the dev user.
RUN echo "\n# Let $DEV_USER use password-less sudo." | tee -a /etc/sudoers && \
  echo "$DEV_USER ALL=(ALL:ALL) NOPASSWD: ALL" | tee -a /etc/sudoers
# *****************************************************************************************************************************

# *****************************************************************************************************************************
# Switch to the development user. Everything below this point should be done in the context of the development user.
USER $DEV_USER
WORKDIR /home/$DEV_USER
# *****************************************************************************************************************************

# *****************************************************************************************************************************
# Set passwords for the accounts.
#
# Set the password for the dev user.
ARG DEV_USER_PWD=$DEV_USER
# Set the password for the dev user.
ARG ROOT_USER_PWD=root
RUN echo "${DEV_USER}:${DEV_USER_PWD}" | sudo chpasswd
RUN echo "root:${ROOT_USER_PWD}" | sudo chpasswd
# *****************************************************************************************************************************

# *****************************************************************************************************************************
# Install command packages.
RUN sudo apt-get update -qq &&\
  sudo apt-get install -y \
  # A tool that converts packages from one distro file format to another. It's usually used to convert .rpm packages to .deb.
  alien \
  # Add tab completion to the terminal.
  bash-completion \
  # Used to install ERD diagrams.
  graphviz \
  # Install the imagemagick tool which is used for image manipulation.
  imagemagick \
  # Needed so the pg gem can compile.
  libpq-dev \
  # Install a system ruby. Some tools need a system ruby that lives outside of RVM. It is also used to drive some ruby based
  # install scripts in the $HOST_BUILD_SCRIPTS_DIR folder. THe version of ruby provided by the Ubuntu repo is sufficient.
  ruby \
  # Install a display server that can be used when running automated tests.
  xvfb
# *****************************************************************************************************************************

# *****************************************************************************************************************************
# Copy the binaries, build scripts and user_files into the image so they can be used inside a container. build_scripts are used
# to perform complicated setup that can't be done in the Dockerfile. user_files contain content that is generated by the
# developer who is building the image. Docker doesn't have an interface for asking questions at build time. Information is
# pulled from the user_files to customize the image for the developer.
ADD $HOST_BINARIES_DIR $BINARIES_DIR
ADD $HOST_BUILD_SCRIPTS_DIR $BUILD_SCRIPTS_DIR
ADD $HOST_USER_FILES_DIR $USER_FILES_DIR
RUN sudo chmod +x $BUILD_SCRIPTS_DIR/* && \
  sudo chown $DEV_USER:$DEV_USER $USER_FILES_DIR && \
  sudo chown -R $DEV_USER:$DEV_USER $BINARIES_DIR
# *****************************************************************************************************************************

# *****************************************************************************************************************************
# Finalize the $BUILD_DIR and $USER_FILES_DIR setup.
RUN sudo chown -R $DEV_USER:$DEV_USER $BUILD_DIR && \
  # Remove the \r character from all line endings, in all the files in the $BUILD_SCRIPTS_DIR. If a user on Windows has Git
  # setup to convert line endings to Windows style line endings, the files in $BUILD_SCRIPTS_DIR will have the wrong line
  # endings when they are copied into a container. \r\n line endings are used on Windows. \n are used in on Linux.
  for f in $BUILD_SCRIPTS_DIR/*; do sed -i 's/\r$//' $f; done && \
  # Convert line endings for files in $USER_FILE_DIR.
  for f in $USER_FILES_DIR/*; do sed -i 's/\r$//' $f; done
# *****************************************************************************************************************************

# *****************************************************************************************************************************
# Setup SSH keys. User must move their pre-created id_rsa and id_rsa.pub files in the user_files folder in this repo
# before building the image. id_rsa and id_rsa.pub are copied into the $USER_FILES_DIR earlier in this Dockerfile.
RUN mkdir ~/.ssh && \
  chmod 700 ~/.ssh && \
  ls $USER_FILES_DIR && \
  mv $USER_FILES_DIR/id_rsa ~/.ssh/id_rsa && \
  mv $USER_FILES_DIR/id_rsa.pub ~/.ssh/id_rsa.pub && \
  chmod 644 ~/.ssh/id_rsa.pub && \
  chmod 600 ~/.ssh/id_rsa && \
  cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
# *****************************************************************************************************************************

# *****************************************************************************************************************************
# Add a predefined .gemrc file to the users home directory
ADD $HOST_TEMPLATES_DIR/.gemrc .gemrc
RUN sudo chown $DEV_USER:$DEV_USER .gemrc
# *****************************************************************************************************************************

# *****************************************************************************************************************************
# Add a predefined .bundle/config file to the users home directory.
ADD $HOST_TEMPLATES_DIR/.bundle/config .bundle/config
RUN sudo chown -R $DEV_USER:$DEV_USER .bundle
# *****************************************************************************************************************************

# *****************************************************************************************************************************
# Install Git. Add the official git repo to the package list so we can always have the latest version of Git.
RUN sudo add-apt-repository ppa:git-core/ppa && \
  sudo apt-get update -qq && \
  sudo apt-get install git -y
# *****************************************************************************************************************************

# *****************************************************************************************************************************
# Add a predefined .gitignore_global file to the users home directory. This lets developers exclude common files/folders
# that are present in multiple repos. It's typically used to make Git ignore files/folders that are operating system specific
# or used by tools like text editors.
ADD $HOST_TEMPLATES_DIR/.gitignore_global .gitignore_global
RUN sudo chown $DEV_USER:$DEV_USER .gitignore_global
# *****************************************************************************************************************************

# *****************************************************************************************************************************
# Configure Git. Apply additional configuration like setting the user name, email addresses, etc...
RUN ~/build/build_scripts/configure_git
# *****************************************************************************************************************************

# *****************************************************************************************************************************
# Install and configure Git LFS. See https://github.com/git-lfs/git-lfs/releases to find newer version of Git LFS.
ENV GIT_LFS_VERSION=2.12.1
ENV GIT_LFS_FILE=git-lfs-linux-amd64-v${GIT_LFS_VERSION}.tar.gz
ENV GIT_LFS_URL=https://github.com/git-lfs/git-lfs/releases/download/v${GIT_LFS_VERSION}/${GIT_LFS_FILE}
RUN mkdir build/git-lfs && \
  cd build/git-lfs && \
  wget ${GIT_LFS_URL} && \
  tar -xvzf ${GIT_LFS_FILE} && \
  sudo ./install.sh
# *****************************************************************************************************************************

# *****************************************************************************************************************************
# Enhance the prompt the Git info. The following section installs a script that shows Git-related status info in the prompt
# if the user is in a folder that is a git repo.
RUN echo "\n# Configure the git-prompt.sh script" | tee -a ~/.bashrc && \
  echo "export GIT_PS1_SHOWDIRTYSTATE=1" | tee -a ~/.bashrc && \
  echo "export GIT_PS1_SHOWSTASHSTATE=1" | tee -a ~/.bashrc && \
  echo "export GIT_PS1_SHOWUNTRACKEDFILES=1" | tee -a ~/.bashrc
# *****************************************************************************************************************************

# *****************************************************************************************************************************
# Add common git aliases.
RUN git config --global alias.co 'checkout' && \
  git config --global alias.logg 'log --graph --decorate --oneline --abbrev-commit' && \
  git config --global alias.sha 'rev-parse HEAD' && \
  git config --global alias.sha8 'rev-parse --short=8 HEAD' && \
  git config --global alias.state '!git fetch origin && git remote show origin && :' && \
  git config --global alias.sync '!git fetch origin && git remote prune origin && :'
# *****************************************************************************************************************************

# *****************************************************************************************************************************
# Add custom Git commands. New Git commands can be placed in the templates/.gitbin/ folder in the docker_rde repo. Each command
# should be placed in a file named "git-xyz" where "xyz" is the name of the command.
ADD $HOST_TEMPLATES_DIR/.gitbin/ .gitbin
RUN sudo chown -R $DEV_USER:$DEV_USER .gitbin &&\
  sudo chmod -R +x $HOME_DIR/.gitbin
# Git finds all files, in folders on the PATH, that follow the git-xyz.
ENV PATH=$HOME_DIR/.gitbin:$PATH
# *****************************************************************************************************************************

# *****************************************************************************************************************************
# Install RVM. RVM is tricky to install correctly. The docs say to use the RVM package to install on Ubuntu, but we
# intentionally ignore that. The Ubuntu package doesn't install to ~/.rvm which is the standard place our various dev
# environments have traditionally installed RVM. Instead, RVM is installed using the older curl-based approach.
#
# Import required keys.
RUN command curl -sSL https://rvm.io/mpapis.asc | gpg --import - && \
  command curl -sSL https://rvm.io/pkuczynski.asc | gpg --import -
# Download and install the latest stable RVM.
RUN \curl -sSL https://get.rvm.io | bash -s stable
# Ensure RVM is defined correctly in the dotfiles (.profile, .bashrc, etc...). THis must be executed as a login shell to work.
RUN /bin/bash -l -c "source /home/$DEV_USER/.rvm/scripts/rvm"
# Apps specify the Ruby version in their Gemfile instead of the .ruby-version file. This causes RVM to throw a warning. Turn
# the unnecessary warning off by executing this command.
RUN /bin/bash -l -c "rvm rvmrc warning ignore allGemfiles"
# *****************************************************************************************************************************

# *****************************************************************************************************************************
# Install initial versions of Ruby and additional tools like bundler, RubyGems, etc... This logic has been moved to a script
# to access more powerful installation logic. Open the script to customize versions and tools.
RUN $BUILD_SCRIPTS_DIR/setup_rvm_rubies
# *****************************************************************************************************************************

# *****************************************************************************************************************************
# Add common command aliases to the ~/.bashrc so they can be used in the shell.
RUN echo "\n# Define system aliases" | tee -a ~/.bashrc && \
  # boc - return the number of outdated gems in a project.
  echo "alias boc='bundle outdated | grep -c \"*\"'" | tee -a ~/.bashrc && \
  # la - A better ls command.
  echo "alias la='ls -lha'" | tee -a ~/.bashrc && \
  # railss - Start a rails server.
  echo "alias railss='rails s -b 0.0.0.0 -p 3000'" | tee -a ~/.bashrc && \
  # cdp - Change directory to the ~/Projects directory.
  echo "alias cdp='cd $PROJECTS_DIR'" | tee -a ~/.bashrc && \
  echo "\n" | tee -a ~/.bashrc
# *****************************************************************************************************************************

# *****************************************************************************************************************************
# Install a system NodeJS. The nvm (node version manager) tool is installed in a later step. nvm will take over and activate
# a version of NodeJS that is not installed in the system. The system version can be used by executing 'nvm use system'.
#
# The version of NodeJS should match the version used in production on PCF. This version should be the same as the NodeJS
# version that is packaged with the latest Ruby buildpack (https://github.com/cloudfoundry/ruby-buildpack/releases), but
# DIDIT may not always have the latest version installed. Before changing this version, login to PCF and find the exact Ruby
# buildpack that is used on the PaaS. This value is also used to set the default version of NodeJS in nvm.
ENV NODEJS_MAJOR_VERSION=14
RUN curl -sL https://deb.nodesource.com/setup_$NODEJS_MAJOR_VERSION.x | sudo -E bash - && \
  sudo apt-get update -qq && sudo apt-get install -y nodejs
# *****************************************************************************************************************************

# *****************************************************************************************************************************
# Install nvm.
ENV NVM_VERSION=0.37.0
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v$NVM_VERSION/install.sh | bash
# The 'source /home/$DEV_USER/.nvm/nvm.sh' statements below are a hack. The above 'curl' command installs nvm and adds some
# lines to ~/.bashrc. When a login shell is started (using '/bin/bash -l') ~/.bashrc should get sourced and the `nvm`
# command should get loaded. For some reason this isn't working and Docker throws an error saying "nvm not defined".
# Ideally, a line like this should work:
#   /bin/bash -l -c "nvm install $DEFAULT_NODEJS"
# but it doesn't. Directly sourcing .bashrc file doesn't work either:
#   /bin/bash -l -c "source /home/$DEV_USER/.bashrc && nvm ...
# Using the -i option to start an interactive shell works:
#   /bin/bash -l -i -c "nvm install $DEFAULT_NODEJS"
# but Docker writes some other error messages to the output. This isn't a huge deal since everything seems to work, but
# sourcing the nvm.sh directly doesn't trigger any errors so that method is used. The idea came from this comment:
# https://stackoverflow.com/questions/25899912/how-to-install-nvm-in-docker#comment68635366_33963559
RUN /bin/bash -l -c "source /home/$DEV_USER/.nvm/nvm.sh && nvm install $NODEJS_MAJOR_VERSION" && \
  /bin/bash -l -c "source /home/$DEV_USER/.nvm/nvm.sh && nvm alias default $NODEJS_MAJOR_VERSION" && \
  /bin/bash -l -c "source /home/$DEV_USER/.nvm/nvm.sh && nvm use default"
# *****************************************************************************************************************************

# *****************************************************************************************************************************
# Install yarn.
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add - && \
  echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list && \
  sudo apt-get update -qq && sudo apt-get install -y yarn
# *****************************************************************************************************************************

# *****************************************************************************************************************************
# Install Chrome. The latest version of Chrome can be downloaded from
# https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb. The RDE expects users to download a version of
# Chrome before building an image. The downloaded file should be placed in the ./binaries directory with a name of
# google-chrome-stable_current_amd64.deb.
ENV CHROME_FILE=google-chrome-stable_current_amd64.deb
ENV FULL_CHROME_FILE=${BINARIES_DIR}/${CHROME_FILE}
WORKDIR $BUILD_DIR/chrome
RUN sudo chown $DEV_USER:$DEV_USER $BUILD_DIR/chrome && \
  sudo cp ${FULL_CHROME_FILE} . && \
  # Install dependencies used by Chrome.
  sudo apt-get update -qq && \
  sudo apt-get install -y libasound2 fonts-liberation libappindicator3-1 libnss3 libnspr4 libxss1 xdg-utils && \
  # Install Chrome from the .deb file.
  sudo dpkg -i ${CHROME_FILE} && \
  google-chrome --version && \
  # Remove the Chrome source from apt. dpkg installs the source definition for Chrome so future calls to 'apt-get update'
  # update Chrome. We DON'T want to update Chrome. We want to use the specific version that we install. Plus the source
  # definition tells apt to use dl.google.com, which is currently blocked by the proxy. It will cause the build to fail.
  sudo rm -f /etc/apt/sources.list.d/google-chrome.list*
# *****************************************************************************************************************************

# *****************************************************************************************************************************
# Install ChromeDriver. Users must place a version of ChromeDriver, that matches Chrome, inside the ./binaries. folder.
# ChromeDriver can be downloaded at https://sites.google.com/a/chromium.org/chromedriver/downloads
# The file should be named chromedriver_linux64.zip.
ENV CHROME_DRIVER_FILE=chromedriver_linux64.zip
ENV FULL_CHROME_DRIVER_FILE=${BINARIES_DIR}/${CHROME_DRIVER_FILE}
WORKDIR $BUILD_DIR/chromedriver
RUN sudo chown $DEV_USER:$DEV_USER $BUILD_DIR/chromedriver/ && \
  sudo cp ${FULL_CHROME_DRIVER_FILE} . && \
  unzip -q ${CHROME_DRIVER_FILE} && \
  chmod a+rx chromedriver && \
  sudo mv chromedriver /usr/local/bin && \
  sudo chown root:root /usr/local/bin/chromedriver && \
  # Ensure the chromedriver executable responds
  chromedriver --version
# *****************************************************************************************************************************

# *****************************************************************************************************************************
# Install Redis. Docker doesn't automatically start the Redis service when a container starts. It has to be started by calling
#   sudo redis-server ${REDIS_CONFIG_FILE}
# This is done at the very bottom of the Dockerfile.
# *****************************************************************************************************************************
ENV REDIS_VERSION=6.0.9
ENV REDIS_CONFIG_FILE=/etc/redis/redis.conf
ENV REDIS_LOG_FILE=/var/log/redis.log
ENV REDIS_DATA_DIR=/var/lib/redis
ENV REDIS_PORT=6379
ENV REDIS_FILE=redis-${REDIS_VERSION}.tar.gz
ARG REDIS_URL=http://download.redis.io/releases/${REDIS_FILE}
WORKDIR $HOME_DIR/build/redis
RUN sudo chown $DEV_USER:$DEV_USER $BUILD_DIR/redis && \
  cd $BUILD_DIR/redis && \
  sudo wget -q ${REDIS_URL} && \
  sudo tar -xzf ${REDIS_FILE} && \
  cd redis-${REDIS_VERSION} && \
  sudo make >/dev/null 2>&1 && \
  sudo make install >/dev/null 2>&1 && \
  sudo mkdir /etc/redis && \
  sudo mkdir ${REDIS_DATA_DIR} && \
  sudo chmod 770 ${REDIS_DATA_DIR} && \
  sudo REDIS_PORT=${REDIS_PORT} REDIS_CONFIG_FILE=${REDIS_CONFIG_FILE} REDIS_LOG_FILE=${REDIS_LOG_FILE} \
    REDIS_DATA_DIR=${REDIS_DATA_DIR} REDIS_EXECUTABLE=`command -v redis-server` ./utils/install_server.sh && \
  sudo sed -i 's/^bind 127.0.0.1.*$/bind 0.0.0.0/' ${REDIS_CONFIG_FILE}
# *****************************************************************************************************************************

# *****************************************************************************************************************************
# Install Postgres. DOcker automatically start the service when a container starts. It has to be started by calling
#  sudo server postgresql start
# This is done at the very bottom of the Dockerfile.
ARG POSTGRES_VERSION=11
RUN wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add - && \
  sudo add-apt-repository "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -sc)-pgdg main" && \
  sudo apt-get update -qq && \
  sudo apt-get install -y postgresql-$POSTGRES_VERSION postgresql-contrib-$POSTGRES_VERSION && \
  sudo service postgresql start && \
  sudo -u postgres createuser --superuser --replication $DEV_USER && \
  sudo -u postgres createdb -O dev dev && \
  sudo chown -R postgres:postgres /var/run/postgresql
# *****************************************************************************************************************************

# *****************************************************************************************************************************
# Configure Postgres authorization in the pg_hba.conf file.
ARG PG_HBA_CONF=/etc/postgresql/$POSTGRES_VERSION/main/pg_hba.conf
ARG PG_CONF=/etc/postgresql/$POSTGRES_VERSION/main/postgresql.conf
# Add a line for 'localhost' in the IPv4 section. This lets devs set 'host: localhost" in their database.yml' files. On Ubuntu,
# 'host:' typically isn't set in the database.yml file, but Mac users frequently set it. Trust authentication is used because
# 'peer' doesn't work over IPv4.
#   Insert: host    all             all             localhost               trust
#   After:  host    all             all             127.0.0.1/32            md5
RUN sudo sed -i '/host\s*all\s*all\s*127.0.0.1\/32\s*md5/a host    all             all             localhost               trust' $PG_HBA_CONF
# Make connections on 127.0.0.1/32 use trust authentication. This lets devs set 'host: 127.0.0.1' in their database.yml files.
# On Ubuntu, 'host:' typically isn't set in the database.yml file, but Mac users frequently set it. Trust authentication is
# used because 'peer' doesn't work over IPv4.
#  Change: host     all             all             127.0.0.1/32            md5
#  To:     host     all             all             127.0.0.1/32            trust
RUN sudo sed -i 's/host\s*all\s*all\s*127.0.0.1\/32\s*md5/host     all             all             127.0.0.1\/32           trust/g' $PG_HBA_CONF
# Let $DEV_USER load psql via 'psql -U $DEV_USER'.
RUN sudo sed -i "/local\s*all\s*postgres\s*peer/a local   all             $DEV_USER                                     peer" $PG_HBA_CONF
# Allow connections for pgAdmin from host.
RUN sudo sed -i -e "\$ahost    all             all             0.0.0.0/0                md5" $PG_HBA_CONF
# Update pg configuration for listen_addresses.
RUN sudo sed -i "s/^#.*listen_addresses = 'localhost'.*$/listen_addresses = '*'/" $PG_CONF
# *****************************************************************************************************************************

# *****************************************************************************************************************************
# Configure Postgres via psql. The postgres service is temporarily started so psql can operate, then it is stopped. The final
# startup is done at the bottom of the Dockerfile.
RUN sudo service postgresql start && \
  # Create a pgadmin user that can be used with other tools (like pgadmin on the host machine).
  psql -c "CREATE USER pgadmin_user WITH PASSWORD 'pgadmin_password';" && \
  psql -c "ALTER USER pgadmin_user WITH SUPERUSER;" && \
  sudo service postgresql stop
# *****************************************************************************************************************************

# # *****************************************************************************************************************************
# # Install MySQL.
RUN sudo apt-get update -qq && \
  sudo apt-get install -y mysql-server && \
  # Needed so the mysql2 Ruby gem can install.
  sudo apt-get install -y libmysqlclient-dev

# Configure MySQL.
RUN sudo sed -i -e"s/^bind-address\s*=\s*127.0.0.1/bind-address = 0.0.0.0/" /etc/mysql/mysql.conf.d/mysqld.cnf && \
  # Makes a 'su: warning: cannot change directory to /nonexistent: No such file or directory' message go away.
  # Taken from https://askubuntu.com/a/738079.
  sudo usermod -d /var/lib/mysql/ mysql && \
  sudo service mysql start && \
  echo "update mysql.user set host = '%' where user='root';" | sudo mysql -u root && \
  echo "CREATE USER '$DEV_USER' IDENTIFIED BY '$DEV_USER_PWD';" | sudo mysql -u root && \
  # echo "REVOKE ALL PRIVILEGES ON *.* FROM '$DEV_USER'@'%'; FLUSH PRIVILEGES;" | sudo mysql -u root && \
  echo "GRANT ALL PRIVILEGES ON *.* TO '$DEV_USER'@'%'; FLUSH PRIVILEGES;" | sudo mysql -u root && \
  sudo service mysql stop
# *****************************************************************************************************************************

# *****************************************************************************************************************************
# Install openssh. Docker doesn't automatically start the SSH service when a container starts. It has to be started by calling
#   sudo server ssh start
# This is done at the very bottom of the Dockerfile.
RUN sudo apt-get update -qq && sudo apt-get install -y openssh-server

# Customize openssh.
# Remove lines starting with X11 from the config file. We're going to add some below and this avoids conflicting configuration.
RUN sudo sed -i "/^#*X11/d" /etc/ssh/sshd_config && \
  # Permit X11Forwarding through a SSH tunnel so X11 applications can display through SSH on the client.
  echo "X11Forwarding yes" | sudo tee -a /etc/ssh/sshd_config && \
  # Offset the DISPLAY by 10 to avoid conflict with other displays. Default of 0 is typically the native display.
  echo "X11DisplayOffset 10" | sudo tee -a /etc/ssh/sshd_config && \
  # Use the machine name, instead of localhost, in the DISPLAY value.
  # This is required for XMing
  echo "X11UseLocalhost no" | sudo tee -a /etc/ssh/sshd_config && \
  sudo bash -c 'echo "    ServerAliveInterval 30" >> /etc/ssh/ssh_config' && \
  # Allows SSH login for the root account.
  sudo sed -i 's/^.*PermitRootLogin.*$/PermitRootLogin yes/' /etc/ssh/sshd_config
# *****************************************************************************************************************************

# *****************************************************************************************************************************
# Install mailcatcher. Instructions taken from https://github.com/sj26/mailcatcher.
RUN /bin/bash -l -c "rvm default@mailcatcher --create do gem install mailcatcher" && \
  /bin/bash -l -c 'ln -s "$(rvm default@mailcatcher do rvm wrapper show mailcatcher)" "$rvm_bin_path/"'
# *****************************************************************************************************************************

# *****************************************************************************************************************************
# Configure the user prompt.
RUN echo 'export PS1='"'"'\[\e]0;\u@\h \w\a\]${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h (rde-$IMAGE_VERSION)\[\033[01;33m\]`__git_ps1` \[\033[01;31m\]$RUBY_VERSION\[\033[35m\]$MSYSTEM\[\033[01;00m\] \[\033[01;34m\]\w\n\[\033[01;37m\]\$ \[\033[01;00m\]'"'" | tee -a ~/.bashrc
# *****************************************************************************************************************************

# *****************************************************************************************************************************
# Run the setup_bashrc_additions script. This feature allows users to create a user_files/.bashrc_additions file on the host
# and have the contents appended to a container's ~/.bashrc file. This is executed towards the Dockerfile so earlier steps
# in the Dockerfile have an opportunity to make changes to ~/.bashrc first.
RUN $BUILD_SCRIPTS_DIR/setup_bashrc_additions
# *****************************************************************************************************************************

# *****************************************************************************************************************************
# Perform final cleanup.
# Remove unneeded packages.
RUN sudo apt-get -y autoremove && \
  # Remove items copied or downloaded to the build folder. sudo is needed because some archives may extract files that are
  # owned by root into the build folder.
  sudo rm -rf $BUILD_DIR
# *****************************************************************************************************************************

# *****************************************************************************************************************************
# Create and enter the projects folder.
RUN mkdir $PROJECTS_DIR
WORKDIR $PROJECTS_DIR
# *****************************************************************************************************************************

# *****************************************************************************************************************************
# Set trusted IPs to allow access to Ruby on Rails webconsole.
ENV TRUSTED_WEB_CONSOLE_IPS=127.0.0.1,172.17.0.0/16
# *****************************************************************************************************************************

# *****************************************************************************************************************************
# Turn off terminal bell.
RUN sudo sed -i 's/# set bell-style none/set bell-style none/' /etc/inputrc
# *****************************************************************************************************************************

# *****************************************************************************************************************************
# At the top of this Dockerfile, there's a similar command that sets the frontend to Noninteractive mode to suppress some
# unneeded output during the build. This command resets the frontend back to Dialog which is debconf's default frontend.
RUN echo 'debconf debconf/frontend select Dialog' | sudo debconf-set-selections
# *****************************************************************************************************************************

# *****************************************************************************************************************************
CMD sudo redis-server ${REDIS_CONFIG_FILE} && \
  # Hide the default mailcatcher output and add something nicer. It throws a deprecation notice and other unnecessary info.
  printf " * Starting mailcatcher: " && /bin/bash -l -c ' mailcatcher --http-ip 0.0.0.0 >/dev/null 2>&1' && echo "[ OK ]" && \
  sudo service ssh start && \
  # Start postgres server
  # sudo service postgresql start && \
  # Start MySQL server
  sudo service mysql start && \
  # Start x-font server so XMing can have sane fonts.
  sudo xfstt --daemon && \
  /bin/bash --login
# *****************************************************************************************************************************
