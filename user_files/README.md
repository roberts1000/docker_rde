This folder holds your user files. docker_rde expects you to include files named:

1. full_name            - A file with a single line that contains the name you want added to git.
1. email_address        - A file with a single line that contains the email address you want added to git.
1. id_rsa               - A private key you want copied to the ~/.ssh/ folder inside a container.
1. id_rsa.pub           - A public key you want copied to the ~/.ssh/ folder inside a container.
1. .bashrc_additions    - An optional file. The contents will be appended to your ~/.bashrc file.
1. rubygems_credentials - An optional file. This file will be copied to ~/.gem/credentials inside a container.
