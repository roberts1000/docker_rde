This file holds binaries you want copied to a container. Files will be copied to ~/binaries. At a minimum, you must supply files named:

1. google-chrome-stable_current_amd64.deb - A version of Chrome for linux. The latest version can be downloaded at https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb.
1. chromedriver_linux64.deb               - A version of ChromeDriver that matches the version of Chrome. ChromeDriver can be downloaded at https://sites.google.com/a/chromium.org/chromedriver/downloads.

Any other files in this folder will be copied into a container at ~/binaries.
