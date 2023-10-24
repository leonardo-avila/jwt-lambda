FROM golang:1.20 as build
WORKDIR /jwt-lambda
COPY go.mod go.sum ./
COPY jwt.go .
RUN go build -tags lambda.norpc -o jwt jwt.go
FROM public.ecr.aws/lambda/provided:al2
COPY --from=build /jwt-lambda/jwt ./jwt
ENTRYPOINT [ "./jwt" ]
