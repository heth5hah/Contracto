#!/bin/bash

# Account Deletion Edge Function Deployment Script
# Run this script to deploy the delete-user Edge Function

echo "🚀 Deploying Account Deletion Edge Function"
echo "============================================"
echo ""

# Step 1: Login to Supabase
echo "📝 Step 1: Login to Supabase"
echo "Running: supabase login"
supabase login

if [ $? -ne 0 ]; then
    echo "❌ Login failed. Please try again."
    exit 1
fi

echo "✅ Login successful!"
echo ""

# Step 2: Link to project
echo "📝 Step 2: Linking to project (qboyfdwwrimditugblwo)"
echo "Running: supabase link --project-ref qboyfdwwrimditugblwo"
supabase link --project-ref qboyfdwwrimditugblwo

if [ $? -ne 0 ]; then
    echo "❌ Project linking failed. Please check your project ref and try again."
    exit 1
fi

echo "✅ Project linked successfully!"
echo ""

# Step 3: Deploy Edge Function
echo "📝 Step 3: Deploying delete-user Edge Function"
echo "Running: supabase functions deploy delete-user"
supabase functions deploy delete-user

if [ $? -ne 0 ]; then
    echo "❌ Deployment failed. Please check the error above."
    exit 1
fi

echo ""
echo "🎉 Success! Edge Function deployed successfully!"
echo ""
echo "Next steps:"
echo "1. Test the feature in your app"
echo "2. Go to Profile → Delete Account"
echo "3. Verify the deletion works end-to-end"
echo ""
echo "To view logs: supabase functions logs delete-user"
echo ""















