#!/bin/bash

# Automated deploy script with Travis CI.

# Exit if any subcommand fails.
set -e

# only build doc for master branch
export SOURCE_BRANCH="master"

if [ "$TRAVIS_PULL_REQUEST" != "false" -o "$TRAVIS_BRANCH" != "$SOURCE_BRANCH" ]; then
    echo "Only build for master branch"
    exit 0
fi

# Variables
ORIGIN_URL=`git config --get remote.origin.url`
ORIGIN_CREDENTIALS=${ORIGIN_URL/\/\/github.com/\/\/$GITHUB_TOKEN@github.com}
COMMIT_MESSAGE=$(git log -1 --pretty=%B)

echo "Started deploying"

# Checkout gh-pages branch.
if [ `git branch | grep gh-pages` ]
then
    git branch -D gh-pages
fi
git checkout -b gh-pages

# build docs now
bundle update
bundle exec jazzy --config docs/.jazzy.yaml

# Delete and move files.
find . -maxdepth 1 ! -name 'docs' ! -name '.git' ! -name '.gitignore' -exec rm -rf {} \;
mv docs/* .
rm -R docs/

# Push to gh-pages.
git config user.name "$USERNAME"
git config user.email "$EMAIL"

git add -fA
git commit --allow-empty -m "$COMMIT_MESSAGE [ci skip]"
git push -f -q $ORIGIN_CREDENTIALS gh-pages > /dev/null 2>&1

echo "Deployed Successfully!"

exit 0
