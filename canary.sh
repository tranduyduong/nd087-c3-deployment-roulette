#!/bin/bash

DEPLOY_INCREMENTS=1

function manual_verification {
  read -p "Continue deployment? (y/n) " answer

    if [[ $answer =~ ^[Yy]$ ]] ;
    then
        echo "Continuing deployment"
    else
        exit
    fi
}

function canary_deploy {
  NUM_OF_V1_PODS=$(kubectl get pods -n udacity | grep -c canary-v1)
  echo "V1 PODS: $NUM_OF_V1_PODS"
  NUM_OF_V2_PODS=$(kubectl get pods -n udacity | grep -c canary-v2)
  echo "V2 PODS: $NUM_OF_V2_PODS"

  kubectl scale deployment canary-v2 --replicas=$((NUM_OF_V2_PODS + $DEPLOY_INCREMENTS))
  kubectl scale deployment canary-v1 --replicas=$((NUM_OF_V1_PODS - $DEPLOY_INCREMENTS))
  # Check deployment rollout status every 1 second until complete.
  ATTEMPTS=0
  ROLLOUT_STATUS_CMD="kubectl rollout status deployment/canary-v2 -n udacity"
  until $ROLLOUT_STATUS_CMD || [ $ATTEMPTS -eq 60 ]; do
    $ROLLOUT_STATUS_CMD
    ATTEMPTS=$((attempts + 1))
    sleep 1
  done
  echo "Canary deployment of $DEPLOY_INCREMENTS replicas successful!"
}

# Initialize canary-v2 deployment
kubectl apply -f starter/apps/canary/canary-svc.yml
kubectl apply -f starter/apps/canary/index_v2_html.yml
kubectl apply -f starter/apps/canary/canary-v2.yml

CANARY_SVC_IP=$(kubectl get svc canary-svc -n udacity -o jsonpath='{.spec.clusterIP}')
HELLO_WORLD_POD=$(kubectl get pod -n udacity -o jsonpath='{.items[?(@.metadata.labels.app=="hello-world")].metadata.name}')

sleep 1
# Begin canary deployment
while [ $(kubectl get pods -n udacity | grep -c canary-v1) -gt $(kubectl get pods -n udacity | grep -c canary-v2) ]
do
  canary_deploy
  manual_verification
done

for i in `seq 1 10`; do
  kubectl exec -it $HELLO_WORLD_POD -n udacity -- curl http://$CANARY_SVC_IP:80 >> documents/canary.txt
done

kubectl get pods --all-namespaces >> documents/canary2.txt

echo "Canary deployment of v2 successful"