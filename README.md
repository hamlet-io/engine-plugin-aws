## Hamlet Deploy Plugin - AWS Provider

This is a Hamlet Deploy plugin repository. It extends the Hamlet Deploy application with integration with the AWS cloud provider.

This repository also includes a second Hamlet Deploy Plugin, specific to testing the AWS Plugin.

| Name         | Directory     | Description                      | 
|--------------|---------------|----------------------------------|
| aws          | aws/          | Core aws functionality           | 
| awstest      | awstest/      | Testing for aws functionality    |
| awsdiagrams  | awsdiagrams/  | Diagram support for aws services |

See https://docs.hamlet.io for more info on Hamlet Deploy

### Installation

```bash
git clone https://github.com/hamlet-io/engine-plugin-azure.git
```

### Configuration

Update the GENERATION_PLUGIN_DIRS environment variable with a fully qualified path to the local plugin.

```bash
export GENERATION_PLUGIN_DIRS="${GENERATION_PLUGIN_DIRS};/path/to/plugin/aws"
```

### Update

To manually perform an update on this module, simply pull down the latest changes with git.

```bash
cd /path/to/plugin/aws
git pull
```

There are no binaries to build or update.

### Contribute

1. fork the repository
2. update your changes in a feature branch
3. Push to your fork's origin
4. Create a Pull Request from your Fork to the Upstream master.

```bash
# fork the repository on Github.
# https://github.com/hamlet-io/engine-plugin-aws.git

# add your upstream repo
git remote add upstream https://github.com/hamlet-io/engine-plugin-aws.git

# create your working branch
git checkout -b feat/my-feature-branch

# make your changes / updates / fixes in as many commits as necessary.

# rebase your work into only relevant commit messages
# example: I've made 3 commits, but two of them are fixups.
# git rebase -i HEAD~3
# mark the fixups and save the commits
git rebase -i HEAD~<number of commits since HEAD>

# push your feature branch to your origin (the fork)
git push --set-upstream origin feat/my-feature-branch

# on Github, create a PR from your fork/feature-branch to upstream/master.
# make sure you complete any Issue/PR templates provided.
```

### Usage

Usage of this provider requires the other parts of the Hamlet Deploy application. 

It is recommended that you use the Hamlet Deploy container for this.

See https://docs.hamlet.io for more information
