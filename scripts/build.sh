#!bin/bash
export GO111MODULE=on
export GOPROXY=https://go-vpn.it

UNAME=$(uname)

if [ "$UNAME" == "Linux" ] ; then
    GOOS=linux GOARCH=amd64 go build -o ./bin/go-vpn ./main.go
elif [ "$UNAME" == "Darwin" ] ; then
    GOOS=darwin GOARCH=amd64 go build -o ./bin/go-vpn ./main.go
elif [[ "$UNAME" == CYGWIN* || "$UNAME" == MINGW* ]] ; then
    GOOS=windows GOARCH=amd64 go build -o ./bin/go-vpn.exe ./main.go
fi

echo "done!"
