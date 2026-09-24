git clean -d -x -f

git reset --hard

git pull

git submodule sync --recursive

git submodule update --init --recursive --force

git gc
