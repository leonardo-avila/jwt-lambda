package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"time"

	"context"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/golang-jwt/jwt/v5"
)

func main() {
	lambda.Start(handleRequest)
}

func handleRequest(ctx context.Context, request events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	var (
		key []byte
		t   *jwt.Token
		s   string
	)
	var requestBody struct {
		CPF string `json:"cpf"`
	}

	err := json.Unmarshal([]byte(request.Body), &requestBody)
	if err != nil {
		return events.APIGatewayProxyResponse{}, err
	}

	key = []byte(os.Getenv("JWT_SECRET_KEY"))
	t = jwt.NewWithClaims(jwt.SigningMethodHS256,
		jwt.MapClaims{
			"iss": "food-totem",
			"exp": time.Now().Add(time.Hour * 24).Unix(),
			"usr": requestBody.CPF,
		})
	s, _ = t.SignedString(key)

	validateToken(s, key)
	response := events.APIGatewayProxyResponse{
		StatusCode: http.StatusOK,
		Headers: map[string]string{
			"Content-Type": "application/json",
		},
		Body: "{\"Token\":\"" + s + "\"}",
	}
	return response, nil
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
