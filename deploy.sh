#!/bin/bash
set -e

BUILD_DIR=".aws-sam/build"

echo "Packaging"
sam build

zip -rj9 emailer-lambda.zip $BUILD_DIR/EmailerFunction/*

echo "Deploying"
terraform apply