# Food Totem JWT Lambda Project

This project maintains the lambda wrote in Golang to generate a JWT token based on the user.

In case the archive point some error to generate the lambda zip file on the root of the project run the following commands to generate the binary manually:

```bash
GOOS=linux GOARCH=amd64 CGO_ENABLED=0 GOFLAGS=-trimpath go build -mod=readonly -ldflags='-s -w' -o bootstrap main.go
```