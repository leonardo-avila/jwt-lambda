# Food Totem JWT Lambda Project

This project maintains the lambda wrote in Golang to generate a JWT token based on the user.

To generate the lambda zip file on the root of the project run the following commands:

```bash
GOOS=linux GOARCH=arm64 go build -tags lambda.norpc -o bootstrap jwt.go
```

```bash
zip jwtGenerator.zip bootstrap
```
