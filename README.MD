# Workflow Queuing Demo
This project demonstrates how to effectively prevent jobs belonging to a workflow from proceeding while there are jobs still running from an earlier workflow of the same workflow name, in the same branch.

The code in create-lock.sh is largely derived from the following 2 sources, with
minor updates for compatibility with CircleCI's [v1.1 API](https://circleci.com/docs/api/v1-reference/).
- https://gist.github.com/acmcelwee/6f488f3d74b2734ca159d105d2927a9e
- https://github.com/bellkev/circle-lock-test

# Prerequisites
- `jq` must be installed for `create-lock.sh` to work
- Create CircleCI API token (See: https://circleci.com/docs/2.0/managing-api-tokens/)
- Configure CIRCLE_TOKEN environment variable for the project with the value being the CircleCI API token value (See: https://circleci.com/docs/2.0/env-vars/#setting-an-environment-variable-in-a-project)
