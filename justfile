
alias s := server
alias d := deploy
alias u := update

server:
    npx hexo server

build:
    npx hexo generate

deploy: build
    npx hexo deploy

update: deploy
    git add -A
    git commit -m "update"
    git push