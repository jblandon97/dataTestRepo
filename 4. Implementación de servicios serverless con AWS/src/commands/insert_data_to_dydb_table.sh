aws dynamodb put-item \
  --region us-east-1 \
  --table-name my-data-table \
  --item '{
    "id": {"S": "123"},
    "name": {"S": "Sample Item"},
    "description": {"S": "This is a sample item"}
  }'
