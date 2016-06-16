#!/usr/bin/env sh

# only build doc for master branch
export SOURCE_BRANCH="master"
export DOC_BRANCH="gh-pages"

if [ "$TRAVIS_PULL_REQUEST" != "false" -o "$TRAVIS_BRANCH" != "$SOURCE_BRANCH" ]; then
    exit 0
fi

git remote set-branches --add origin $DOC_BRANCH
git fetch
git checkout $DOC_BRANCH

# this is the script actually build docs
./scripts/build_docs.sh

# upload docs
./scripts/push_docs.sh
