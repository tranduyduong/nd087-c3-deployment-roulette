# Initialize green deployment
kubectl apply -f starter/apps/blue-green/index_green_html.yml
kubectl apply -f starter/apps/blue-green/green.yml

# Check deployment rollout status every 1 second until complete.
ATTEMPTS=0
ROLLOUT_STATUS_CMD="kubectl rollout status deployment/green -n udacity"
until $ROLLOUT_STATUS_CMD || [ $ATTEMPTS -eq 60 ]; do
$ROLLOUT_STATUS_CMD
ATTEMPTS=$((attempts + 1))
sleep 1
done
echo "Blue-Green deployment successful!"