#!/usr/bin/env bash

set -o errexit -o pipefail -o nounset

########################################################################################
# Code derived from the below sources, with minor modifications to make it
# compatible with CircleCI API v1.1 and allow jobs of a workflow to
# effectively queue behind jobs of an earlier workflow of the same workflow
# name (including jobs of different names)
#   - https://gist.github.com/acmcelwee/6f488f3d74b2734ca159d105d2927a9e
#   - https://github.com/bellkev/circle-lock-test
# Not extensively tested - use at your own risk!
########################################################################################


# sets $branch, $job_name, $tag, $rest
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -b|--branch) branch="$2" ;;
            -j|--job-name) job_name="$2" ;;
            -t|--tag) tag="$2" ;;
            *) break ;;
        esac
        shift 2
    done
    rest=("$@")
}

# reads $branch, $tag, $commit_message
should_skip() {
    if [[ "$branch" && "$CIRCLE_BRANCH" != "$branch" ]]; then
        echo "Not on branch $branch. Skipping..."
        return 0
    fi

    if [[ "$tag" && "$commit_message" != *\[$tag\]* ]]; then
        echo "No [$tag] commit tag found. Skipping..."
        return 0
    fi

    return 1
}

# reads $branch, $job_name, $tag
# sets $jq_prog
make_jq_prog() {
    local jq_filters=""

    if [[ $branch ]]; then
        jq_filters+=" and .branch == \"$branch\""
    fi

    if [[ $job_name ]]; then
        jq_filters+=" and .workflows?.job_name? == \"$job_name\" and .workflows?.workflow_id? != \"$CIRCLE_WORKFLOW_ID\""
    fi

    if [[ $tag ]]; then
        jq_filters+=" and (.subject | contains(\"[$tag]\"))"
    fi

    jq_prog=".[] | select(.build_num < $CIRCLE_BUILD_NUM and (.status | test(\"running|pending|queued\")) $jq_filters) | .build_num"
}


if [[ "$0" != *bats* ]]; then
set -e
set -u
set -o pipefail

    branch=""
    tag=""
    rest=()

    vcs_type="github"
    vcs_type_initials=$(echo $CIRCLE_BUILD_URL | awk -F'/' '{print $4}')
    if [[ "bb" == "$vcs_type_initials" ]]; then
        vcs_type="bitbucket"
    fi

    api_url="https://circleci.com/api/v1.1/project/$vcs_type/$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME?circle-token=$CIRCLE_TOKEN&limit=100"

    parse_args "$@"
    commit_message=$(git log -1 --pretty=%B)
    if should_skip; then exit 0; fi
    make_jq_prog

    echo "Checking for running builds..."

    while true; do
        builds=$(curl -s -H "Accept: application/json" "$api_url" | jq "$jq_prog")
        if [[ $builds ]]; then
            echo "Waiting on builds:"
            echo "$builds"
        else
            break
        fi
        echo "Retrying in 10 seconds..."
        sleep 10
    done

    echo "Acquired lock"

    if [[ "${#rest[@]}" -ne 0 ]]; then
        "${rest[@]}"
    fi
fi