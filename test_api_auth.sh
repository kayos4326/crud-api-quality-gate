#!/bin/bash
# test_api_auth.sh

API_URL="http://localhost:3000/api/products"
AUTH_URL="http://localhost:3000/api/auth/login"

echo "--- 1. Authenticating Test User ---"
LOGIN_RES=$(curl -s -X POST $AUTH_URL -H "Content-Type: application/json" -d '{"username": "testuser", "password": "password123"}')
TOKEN=$(echo $LOGIN_RES | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
    echo "Authentication failed! Check your credentials."
    exit 1
fi
echo "Token received successfully."

echo -e "\n--- 2. Testing GET Products (Public) ---"
curl -s -X GET $API_URL | grep -o '"success":true'

echo -e "\n--- 3. Testing POST (Create Product - Secured) ---"
CREATE_RES=$(curl -s -X POST $API_URL \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d '{"ProductName": "Auth Test Item", "Price": 15.99}')
echo $CREATE_RES
NEW_ID=$(echo $CREATE_RES | grep -o '"insertedId":[0-9]*' | cut -d':' -f2)

echo -e "\n--- 4. Testing PUT (Update Product ID: $NEW_ID - Secured) ---"
curl -s -X PUT "$API_URL/$NEW_ID" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d '{"ProductName": "Updated Auth Item", "Price": 25.99}'

echo -e "\n--- 5. Testing DELETE (Delete Product ID: $NEW_ID - Secured) ---"
curl -s -X DELETE "$API_URL/$NEW_ID" \
    -H "Authorization: Bearer $TOKEN"
