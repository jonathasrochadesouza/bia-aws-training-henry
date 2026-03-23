#!/bin/bash

set -e

CLUSTER="cluster-bia"
SERVICE="service-bia"
TASK_FAMILY="task-def-bia"
ECR_REPO="328958872848.dkr.ecr.us-east-1.amazonaws.com/bia"
REGION="us-east-1"

show_help() {
    cat << EOF
Deploy Script - ECS Service with Git Commit Versioning

USAGE:
    $0 [COMMAND] [OPTIONS]

COMMANDS:
    deploy              Deploy new version using current git commit hash
    rollback <hash>     Rollback to specific commit hash
    list                List available versions (ECR tags)
    current             Show current deployed version
    help                Show this help message

EXAMPLES:
    $0 deploy                    # Deploy current commit
    $0 rollback ac6f0d6          # Rollback to commit ac6f0d6
    $0 list                      # List all available versions
    $0 current                   # Show current version

EOF
}

get_current_commit() {
    git rev-parse --short HEAD
}

list_versions() {
    echo "Available versions in ECR:"
    aws ecr describe-images --repository-name bia --region $REGION \
        --query 'sort_by(imageDetails,&imagePushedAt)[*]' --output json | \
        jq -r '.[] | "\(.imagePushedAt) - Tags: \(.imageTags // ["<untagged>"] | join(", "))"'
}

get_current_version() {
    TASK_DEF_ARN=$(aws ecs describe-services --cluster $CLUSTER --services $SERVICE --region $REGION \
        --query 'services[0].taskDefinition' --output text)
    
    IMAGE=$(aws ecs describe-task-definition --task-definition $TASK_DEF_ARN --region $REGION \
        --query 'taskDefinition.containerDefinitions[0].image' --output text)
    
    echo "Current deployed version:"
    echo "  Task Definition: $TASK_DEF_ARN"
    echo "  Image: $IMAGE"
}

deploy() {
    COMMIT_HASH=${1:-$(get_current_commit)}
    IMAGE_URI="$ECR_REPO:$COMMIT_HASH"
    
    echo "Deploying version: $COMMIT_HASH"
    echo "Image: $IMAGE_URI"
    
    # Check if image exists in ECR
    if ! aws ecr describe-images --repository-name bia --region $REGION \
        --image-ids imageTag=$COMMIT_HASH &>/dev/null; then
        echo "ERROR: Image with tag $COMMIT_HASH not found in ECR"
        echo "Available tags:"
        aws ecr describe-images --repository-name bia --region $REGION \
            --query 'imageDetails[*].imageTags[0]' --output text
        exit 1
    fi
    
    # Get current task definition and create new one with updated image
    TEMP_FILE=$(mktemp)
    aws ecs describe-task-definition --task-definition $TASK_FAMILY --region $REGION | \
        jq --arg IMAGE "$IMAGE_URI" \
        '.taskDefinition | 
         .containerDefinitions[0].image = $IMAGE | 
         del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .compatibilities, .registeredAt, .registeredBy)' \
        > $TEMP_FILE
    
    # Register new task definition
    NEW_TASK_ARN=$(aws ecs register-task-definition --region $REGION \
        --cli-input-json file://$TEMP_FILE --query 'taskDefinition.taskDefinitionArn' --output text)
    
    rm -f $TEMP_FILE
    
    echo "New task definition registered: $NEW_TASK_ARN"
    
    # Update service
    aws ecs update-service --cluster $CLUSTER --service $SERVICE \
        --task-definition $NEW_TASK_ARN --region $REGION \
        --query 'service.[serviceName,taskDefinition]' --output table
    
    echo "✅ Deployment initiated successfully!"
    echo "Monitor deployment: aws ecs describe-services --cluster $CLUSTER --services $SERVICE --region $REGION"
}

rollback() {
    if [ -z "$1" ]; then
        echo "ERROR: Commit hash required for rollback"
        echo "Usage: $0 rollback <commit-hash>"
        exit 1
    fi
    
    echo "Rolling back to version: $1"
    deploy "$1"
}

case "${1:-help}" in
    deploy)
        deploy
        ;;
    rollback)
        rollback "$2"
        ;;
    list)
        list_versions
        ;;
    current)
        get_current_version
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "ERROR: Unknown command '$1'"
        show_help
        exit 1
        ;;
esac
