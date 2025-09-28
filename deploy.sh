#!/bin/bash
set -e

echo "🔄 Pulling latest changes..."
git pull origin main

echo "📦 Getting Flutter dependencies..."
flutter pub get

echo "🧹 Cleaning project..."
flutter clean

echo "🏗️ Building Flutter Web release..."
flutter build web --release


echo "🚀 Deploying to Firebase Hosting..."
firebase deploy --only hosting