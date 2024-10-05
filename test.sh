#!/bin/bash

# Variables
NAMESPACE="udacity"
DEPLOYMENT_NAME="blue-green-deployment-green"
CONFIG_MAP_NAME="green-config"
DOMAIN="blue-green.udacityproject.com"
HOSTED_ZONE_ID="Z035853032CFE8VF134NV"  # Replace with your Route53 hosted zone ID
GREEN_SERVICE_NAME="green-service"
BLUE_SERVICE_NAME="blue-service"
WEIGHT=100  # Modify weight as needed for blue-green split
TTL=60

# Step 1: Create a new deployment based on the blue deployment
echo "Creating green deployment..."

# Get the existing blue deployment config and modify it
kubectl get deployment blue-green-deployment -n $NAMESPACE -o yaml | sed "s/blue-green-deployment/blue-green-deployment-green/g" | kubectl apply -f -

# Step 2: Update the index.html with green-config from the config-map
echo "Updating green deployment with green-config..."

kubectl patch deployment $DEPLOYMENT_NAME -n $NAMESPACE --patch "
spec:
  template:
    spec:
      containers:
      - name: app-container
        volumeMounts:
        - mountPath: /usr/share/nginx/html/index.html
          subPath: index.html
      volumes:
      - name: config-volume
        configMap:
          name: $CONFIG_MAP_NAME
"

# Step 3: Wait for the green deployment to roll out successfully
echo "Waiting for green deployment to roll out..."

kubectl rollout status deployment/$DEPLOYMENT_NAME -n $NAMESPACE

# Step 4: Check if the service is reachable
echo "Checking if the green service is reachable..."

SERVICE_IP=$(kubectl get svc $GREEN_SERVICE_NAME -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

if [[ -z "$SERVICE_IP" ]]; then
  echo "Error: Green service IP is not available."
  exit 1
fi

echo "Green service is reachable at IP: $SERVICE_IP"

# Step 5: Create a new weighted CNAME record in Route53 for the green environment
echo "Creating a weighted CNAME record in Route53..."

aws route53 change-resource-record-sets --hosted-zone-id $HOSTED_ZONE_ID --change-batch '{
  "Changes": [{
    "Action": "UPSERT",
    "ResourceRecordSet": {
      "Name": "'"$DOMAIN"'",
      "Type": "CNAME",
      "SetIdentifier": "green-deployment",
      "Weight": '$WEIGHT',
      "TTL": '$TTL',
      "ResourceRecords": [{ "Value": "'"$SERVICE_IP"'" }]
    }
  }]
}'

echo "Green deployment is completed and the Route53 CNAME is set."
