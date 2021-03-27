# docker_rde

docker_rde builds an Ubuntu based Docker image suitable for developing Ruby applications. The image includes tools and libraries that are commonly used by Ruby developers and it significantly reduces the time needed to use Docker for development.

docker_rde uses Docker in an atypical way. Instead of encapsulating a single application, docker_rde encapsulates a *development environment*. It's intentionally "bigger" than a typical Docker container, and engineered to support teams that may not want to fully dockerize an application.

## Versioning Strategy

docker_rde uses [Semver 2.0.0](https://semver.org/spec/v2.0.0.html) to version releases. In addition:

- 3.x.x uses Ubuntu 20.04.
- 2.x.x uses Ubuntu 18.04.
- 1.x.x uses Ubuntu 16.04.

## Instructions

1. Clone the repo and `cd` into the project folder.

1. Manually create required files in the `user_files` folder:

    1. Create a `full_name` file with the name you want `git` to use for authoring commits.
    1. Create an `email_address` file with the email you want `git` to use for authoring commits.
    1. Add an `id_rsa` and a `id_rsa.pub` file. These files will be copied to the `~/.ssh/` folder inside a container.
    1. **(Optional)** Create a `.bashrc_additions` file. If present, `source ~/.bashrc_additions` will be added to the bottom of a container's `~/.bashrc`. This lets you import custom commands into to a container.
    1. **(Optional)** If you have a RubyGems account and would like to configure the container to push to RubyGems, create a file named `rubygems_credentials`. Add the following contents to the file and replace XYZ with your RubyGems API key.

        ```
        ---
        :rubygems_api_key: XYZ
        ```

1. Download binaries and place them in the `binaries` folder:

    1. Download a version of Chrome for Ubuntu. The latest version of Chrome can be downloaded from https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb. If you want something older, you'll need to track it down since Google only provides access to the latest version of Chrome. The file should be named `google-chrome-stable_current_amd64.deb`. This file will be deleted inside the container once Chrome is installed.
    1. Download a version of ChromeDriver for Ubuntu that matches the version of Chrome. ChromeDriver can be downloaded from https://sites.google.com/a/chromium.org/chromedriver/downloads. The file should be named `chromedriver_linux64.zip`. This file will be deleted inside the container once ChromeDriver is installed.
    1. You can add any additional binaries to the `binaries` folder. They will be copied to `/home/${DEV_USER}/binaries`.

1. Use the [bin/build](https://github.com/roberts1000/docker_rde/blob/master/bin/build) script to build the image. This will create an image named `ruby_dev_image` with a tag of `latest`. If you want different build instructions, edit the file, or copy the command out of the [bin/build](https://github.com/roberts1000/docker_rde/blob/master/bin/build) file and modify it on the command line.

    ```
    $ bin/build
    ```

1. Turn the image into a container with the [bin/run](https://github.com/roberts1000/docker_rde/blob/master/bin/run) script. This script assumes the image is named `ruby_dev_image` and has a tag of `latest`. It creates a container named `ruby_dev`. If you want something different, modify the file before executing.

    ```
    $ bin/run
    ```

1. The running container can be stopped by running `exit` inside the container's terminal. The container can be restarted with `bin/start`. See the `bin` folder for additional commands.

## Useful Info

1. **Users**
    1. **root user** - By default, a container will have a `root` user with a password of `root`. You can change the password by finding where the `ROOT_USER_PWD` variable is set in the [Dockerfile](Dockerfile).
    1. **dev user** - By default, a container will have a `dev` user with a password of `dev`. You can change this finding where the `DEV_USER` and `DEV_USER_PWD` variables are set in the [Dockerfile](Dockerfile).
1. **PostgreSQL/MySQL** - Both PostreSQL and MySQL are installed and configured. By default, only MySQL is started when a container stats. If you would like to change this, go to the very bottom of the [Dockerfile](Dockerfile) and comment/uncomment the services you want started.
    1. **MySQL**
        1. **root user** - The `root` MySQL user does not have a password. Use `sudo mysql -u <root_user_here>` to login to `mysql`.
        1. **dev user** - By default, the RDE creates a MySQL user with the same name as the development user account, `dev`. If you change the `DEV_USER` environment variable to something other than `dev`, the MySQL user will match the new value. Use `mysql -u <dev_user_here> -p<dev_user_pwd_here>` to login.
1. **Proxies** - Proxy setup is turned off by default. To use a proxy, uncomment the appropriate section near the top of the [Dockerfile](Dockerfile).

## Support

Reports bugs or request changes on the [issue page](https://github.com/roberts1000/docker_rde/issues).
