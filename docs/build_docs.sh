#!/usr/bin/env sh

# only build doc for master branch
export SOURCE_BRANCH="master"
export DOC_BRANCH="gh-pages"

if [ "$TRAVIS_PULL_REQUEST" != "false" -o "$TRAVIS_BRANCH" != "$SOURCE_BRANCH" ]; then
    exit 0
fi


# build docs now
gem install jazzy
jazzy --config docs/.jazzy.yaml

# remove all redundant files
find . -not -name "docs" -not -name ".git" -maxdepth 1 | xargs -0 rm --
# copy docs files to root
cp -r docs/. .
rm -rf docs

# push update
git add .
git -c user.name="Travis CI" commit -m "Update docs"
git push --force --quiet https://$GITHUB_API_KEY@github.com/zhuhaow/NEKit.git gh-pages > /dev/null 2>&1
