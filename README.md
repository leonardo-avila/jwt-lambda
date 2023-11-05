# Food Totem JWT Lambda Project
[![Build](https://github.com/leonardo-avila/jwt-lambda/actions/workflows/build.yml/badge.svg)](https://github.com/leonardo-avila/jwt-lambda/actions/workflows/build.yml)
[![Deploy](https://github.com/leonardo-avila/jwt-lambda/actions/workflows/deploy.yml/badge.svg)](https://github.com/leonardo-avila/jwt-lambda/actions/workflows/deploy.yml)

This project maintains the lambda wrote in Golang to generate a JWT token based on the user.

In case the archive point some error to generate the lambda zip file on the root of the project run the following commands to generate the binary manually:

```bash
GOOS=linux GOARCH=amd64 CGO_ENABLED=0 GOFLAGS=-trimpath go build -mod=readonly -ldflags='-s -w' -o bootstrap main.go
```

This project could be deployed using the command above to create the binary file, and then the following command:

```bash
terraform apply --auto-approve
```

Besides that, the GitHub Action workflow configured in this project already has the steps to generate the binary and deploy the lambda to AWS.

This project Terraform also contains the resources to generate the API Gateway and the IAM Role to allow the lambda to be executed.