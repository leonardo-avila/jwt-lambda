package main

import (
	"fmt"
	"os"
	"time"

	"context"

	"github.com/aws/aws-lambda-go/lambda"
	"github.com/golang-jwt/jwt/v5"
)

type Customer struct {
	CPF string `json:"cpf"`
}

type Response struct {
	Token string `json:"Token"`
}

func main() {
	lambda.Start(handleRequest)
	//handleRequest(context.Background(), Customer{CPF: "12345678901"})
}

func handleRequest(ctx context.Context, customer Customer) (*Response, error) {
	var (
		key []byte
		t   *jwt.Token
		s   string
	)
	key = []byte(os.Getenv("JWT_SECRET_KEY"))
	t = jwt.NewWithClaims(jwt.SigningMethodHS256,
		jwt.MapClaims{
			"iss": "food-totem",
			"exp": time.Now().Add(time.Hour * 24).Unix(),
			"usr": customer.CPF,
		})
	s, _ = t.SignedString(key)

	validateToken(s, key)
	return &Response{Token: s}, nil
}

func validateToken(signature string, key []byte) (string, error) {
	t, err := jwt.Parse(signature, func(token *jwt.Token) (interface{}, error) {
		// Validate the algorithm
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
		}

		// Return the key for validation
		return key, nil
	})

	if err != nil {
		return "", fmt.Errorf("error parsing token: %v", err)
	}
	if t.Valid {
		fmt.Printf("Token is valid: %v\n", signature)
		return signature, nil
	} else {
		return "", fmt.Errorf("token is invalid")
	}
}
