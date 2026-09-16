#!/bin/bash
# test_api.sh
API_URL="http://localhost:3000/api/products"

echo "--- 1. Testing GET Products ---"
curl -s -X GET $API_URL | grep -o '"success":true'

echo -e "\n--- 2. Testing POST (Create Product) ---"
CREATE_RES=$(curl -s -X POST $API_URL -H "Content-Type: application/json" -d '{"ProductName": "Test Item", "Price": 9.99}')
echo $CREATE_RES

NEW_ID=$(echo $CREATE_RES | grep -o '"insertedId":[0-9]*' | cut -d':' -f2)

echo -e "\n--- 3. Testing PUT (Update Product ID: $NEW_ID) ---"
curl -s -X PUT "$API_URL/$NEW_ID" -H "Content-Type: application/json" -d '{"ProductName": "Updated Item", "Price": 19.99}'

echo -e "\n--- 4. Testing DELETE (Delete Product ID: $NEW_ID) ---"
curl -s -X DELETE "$API_URL/$NEW_ID"
