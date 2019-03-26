#!/bin/bash
# set -x
###############
# This script can be used to replicate git repositories across two Bitbucket instances.
#
# Requirements:
# - The users provided below must have administrator privileges over the projects to be migrated.
# - The repositories to migrate must be cloned over SSH.
# - The machine this script is run from must have connectivity to both instances over SSH and the REST API.
# - The array of projects must be the Project Keys from the 'old server'.
###############

# Variables
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
projects=( ANS CHEF CGCM JEN TF ) #PACKER )

json_header="Content-Type: application/json"
projects_endpoint="rest/api/1.0/projects"

####

function project_exists {
    local username=$1
    local password=$2
    local project_url=$3
    result=$(curl -m1 -s -u $username:$password $project_url | jq -Mcr 'if .errors == null then "true" else "false" end')
    echo $result
}

function create_project {
    local project_key=$1
    local old_project_details="$(fetch_project_details $project_key $old_username $old_password https://$old_base_url)"
    printf "Creating project %s with details:\n" $project_key
    printf "%s\n" "$old_project_details"
    curl -m1 -s -u $new_username:$new_password -X POST -H "$json_header" -d "$old_project_details" https://$new_base_url"/"$projects_endpoint
    echo ""
}

function create_repository {
    local project_key=$1
    local repo_name=$2
    local repository_details='{"name": "'$repo_name'"}'
    printf "Creating repository %s in project %s.\n" $repo_name $project_key
    curl -m1 -s -u $new_username:$new_password -X POST -H "$json_header" -d "$repository_details" https://$new_base_url"/"$projects_endpoint"/"$project_key"/repos"
    echo ""
}

function fetch_project_image {
    local project_key=$1
    local old_project_image_b64=$(curl -m1 -s -u $old_username:$old_password https://$old_base_url"/"$projects_endpoint"/"$project_key/avatar.png | base64)
    echo "$old_project_image_b64"
}

function fetch_project_details {
    local project_key=$1
    local username=$2
    local password=$3
    local base_url=$4
    local project_details=$(curl -m1 -s -u $username:$password $base_url"/"$projects_endpoint"/"$project_key | jq -Mcr '{key: .key, name: .name, description: .description}' | sed 's/ /\ /g')
    echo "$project_details"
}

function patch_existing_project {
    local project_key=$1
    local old_project_details="$(fetch_project_details $project_key $old_username $old_password https://$old_base_url)"
    local new_project_details="$(fetch_project_details $project_key $new_username $new_password https://$new_base_url)"
    # https://stackoverflow.com/questions/31930041/using-jq-or-alternative-command-line-tools-to-diff-json-files
    details_equal=$(jq -R --argjson old "$old_project_details" --argjson new "$new_project_details" -n '$old == $new')
    if [[ $details_equal == "false" ]]; then
        printf "Project %s details differ, patching project details...\n" $project_key
        printf "%s\n" "$old_project_details"
        curl -m1 -s -u $new_username:$new_password -X PUT -H "$json_header" -d "$old_project_details" https://$new_base_url"/"$projects_endpoint"/"$project_key
    elif [[ $details_equal == "true" ]]; then
        printf "Project %s details already match, continuing...\n" $project_key
    else
        exit 1
    fi
}

function clone_repo {
    local repo_clone_url=$1
    local project_key=$2
    local repo_name=$3
    local repo_path=$(printf "repos/%s/%s" $project_key $repo_name)
    git clone $repo_clone_url $repo_path
    local previous_dir=$(pwd)
    cd $repo_path
    git checkout master
    cd $previous_dir
}

function update_remote_branches {
    local project_key=$1
    local repo_name=$2
    # https://gist.github.com/grimzy/a1d3aae40412634df29cf86bb74a6f72
    # https://stackoverflow.com/questions/67699/how-to-clone-all-remote-branches-in-git
    for branch in $(git branch --all | grep '^\s*remotes' | egrep --invert-match '(:?HEAD)'); do
        git branch --track "${branch##*/}" "$branch"
    done
    git fetch --all
    git pull --all
    git remote rm origin
    git remote add origin ssh://git@$new_base_url:7999/$project_key/$repo_name.git
    # https://stackoverflow.com/questions/6865302/push-local-git-repo-to-new-remote-including-all-branches-and-tags
    git push origin --mirror
}

function fetch_all_repos {
    local project_key=$1
    local repos=$(curl -m1 -s -u $old_username:$old_password https://$old_base_url"/"$projects_endpoint"/"$project_key"/repos?limit=100" | jq -r '.values[].links.clone[] | if .name == "ssh" then .href else empty end')
    local repos_arr=( $repos )
    for repo_clone_url in "${repos_arr[@]}"; do
        local repo_name=$(echo $repo_clone_url | cut -d \/ -f5 | cut -d \. -f1)
        clone_repo $repo_clone_url $project_key $repo_name
        create_repository $project_key $repo_name
        local previous_dir=$(pwd)
        cd $(printf "repos/%s/%s" $project_key $repo_name)
        update_remote_branches $project_key $repo_name
        cd $previous_dir
    done
}

function update_repo_avatar {
    local project_key=$1
    local image_data='{"avatar": "data:image/png;base64,'$(cat icons/$project_key.png | base64)'"}'
    curl -s -m1 -X PUT \
        -u $new_username:$new_password \
        -H "$json_header" \
        -d "$image_data" \
        $(printf "https://%s/%s/%s" $new_base_url $projects_endpoint $project_key)
    printf "\nUpdated icon for %s project.\n" $project_key
}

for key in "${projects[@]}"; do
    new_project_url=https://$new_base_url"/"$projects_endpoint"/"$key
    new_project_exists=$(project_exists $new_username $new_password $new_project_url)

    if [[ $new_project_exists == "false" ]]; then
        printf "Project %s does not exist on new server.\n" $key
        create_project $key
        echo ""
    elif [[ $new_project_exists == "true" ]]; then
        printf "Project %s already exists.\n" $key
        patch_existing_project $key
    else
        exit 1
    fi
    fetch_all_repos $key
    update_repo_avatar $key
done

# ./migration.sh | gawk '{ print strftime("%Y-%m-%d %H:%M:%S: "), $0; fflush(); }' | tee output.log