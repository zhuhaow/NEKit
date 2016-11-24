#!/usr/bin/env sh

# only build doc for master branch
export SOURCE_BRANCH="master"
export DOC_BRANCH="gh-pages"

if [ "$CI_PULL_REQUEST" != "" -o "$CIRCLE_BRANCH" != "$SOURCE_BRANCH" ]; then
    exit 0
fi


# build docs now
bundle update
bundle exec jazzy --config docs/.jazzy.yaml

# remove all redundant files
find . -not -name "docs" -not -name ".git" -maxdepth 1 -print0 | xargs -0 rm -rf --
# copy docs files to root
cp -r docs/. .
rm -rf docs

# push update
git checkout --orphan gh-pages
git add .
git -c user.name="Circle CI" commit -m "Update docs [skip ci]"
git push --force --quiet https://$GITHUB_TOKEN@github.com/zhuhaow/NEKit.git gh-pages > /dev/null 2>&1
