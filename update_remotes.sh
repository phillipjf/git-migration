#!/bin/bash
# set -x
projects=( ANS CHEF CGCM JEN TF )
new_base_url="new_bitbucket.mycompany.com"
old_base_url="old_bitbucket.mycompany.com"
base_dir="/path/to/my/repos"

# https://stackoverflow.com/questions/14366390/check-if-an-element-is-present-in-a-bash-array/14367368
function array_contains {
    local seeking=$1
    local in=1
    for element in "${projects[@]}"; do
        # https://stackoverflow.com/questions/26320553/case-insensitive-comparision-in-if-condition?lq=1
        if [[ $(tr "[:upper:]" "[:lower:]" <<<$element) == $(tr "[:upper:]" "[:lower:]" <<<$seeking) ]]; then
            in=0
            break
        fi
    done
    return $in
}

for git_dir in $(find $base_dir -type d -name .git); do
    # printf "Checking git directory %s...\n" $git_dir
    prev_dir=$(pwd)
    cd $git_dir
    remote_url=$(git remote get-url origin)
    if [[ $? > 0 ]]; then
        continue;
    fi
    base_url=$(echo $remote_url | cut -d/ -f3 | cut -d@ -f2 | cut -d: -f1)
    repo_name=$(echo $remote_url | cut -d \/ -f5 | cut -d \. -f1)
    project_key=$(echo $remote_url | cut -d/ -f4)
    if [ ${base_url:-""} == $old_base_url ]; then
        if array_contains $project_key; then
            new_remote=$(printf "ssh://git@%s:7999/%s/%s.git" $new_base_url $project_key $repo_name)
            # printf "Remote URL: %s\nNew Remote: %s\n\n" $remote_url $new_remote
            git remote set-url origin $new_remote
        fi
    fi
    cd $prev_dir
done