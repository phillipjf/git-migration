# Bitbucket Git Repository Migration

These scripts can be used to replicate git repositories across two Bitbucket instances.

## Requirements

- The users provided below must have administrator privileges over the projects to be migrated.
- The repositories to migrate must be cloned over SSH.
- The machine this script is run from must have connectivity to both instances over SSH and the REST API.
- The array of projects must be the Project Keys from the 'old server'.

## Usage

### migration.sh

Provide the appropriate parameters at the top of `migration.sh`:

```bash
#### Old Server Details
# Base URL of 'old server' instance. This is the instance you are migrating FROM.
old_base_url="old_bitbucket.mycompany.com"
# Username to authenticate to 'old server' instance.
old_username="old_admin"
# Password to authenticate to 'old server' instance.
old_password="old_password"

#### New Server Details
# Base URL of 'new server' instance. This is the instance you are migrating TO.
new_base_url="new_bitbucket.mycompany.com"
# Username to authenticate to 'new server' instance.
new_username="new_admin"
# Password to authenticate to 'new server' instance.
new_password="new_admin"

# Array of project keys to fetch from 'old server' and re-create on 'new server'
projects=( ANS CHEF CGCM JEN TF )
```

Ensure the script is executable:

`chmod +x migration.sh`

Run the script:

`./migration.sh`

If you'd like to log the output to a file with timestamps:

`./migration.sh | gawk '{ print strftime("%Y-%m-%d %H:%M:%S: "), $0; fflush(); }' | tee output.log`

### update_remotes.sh

This script will recursively traverse a directory searching for cloned git repositories. Based on parameters set in the script, it will then update the remote origin for the cloned repository.

Provide the appropriate parameters at the top of `update_remotes.sh`:

```bash
# Array of project keys to update the remote origin to the 'new server'.
projects=( ANS CHEF CGCM JEN TF )
# Base URL of 'new server' instance. This is the base url for the new remote origin.
new_base_url="new_bitbucket.mycompany.com"
# Base URL of 'old server' instance. This is the baser url of the old remote origin.
old_base_url="old_bitbucket.mycompany.com"
# A top-level directory containing cloned git repositories.
base_dir="/path/to/my/repos"
```

Ensure the script is executable:

`chmod +x update_remotes.sh`

Run the script:

`./update_remotes.sh`