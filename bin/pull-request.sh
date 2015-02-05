current_repo=$(git config --local --get remote.origin.url |sed s/git@github.com:// | sed s/https:\\/\\/// | sed s/github.com\\/// | sed s/.git/:/)

hub pull-request -b $current_repo$1 $2 -o
