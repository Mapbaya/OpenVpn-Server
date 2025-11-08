#!/bin/bash
# Script to push project to GitHub

echo "🚀 Pushing OpenVPN server to GitHub..."
echo ""

# Check if git user is configured
if ! git config user.name &>/dev/null; then
    echo "❌ Git user not configured!"
    echo ""
    echo "Configure your Git identity first:"
    echo "  git config user.name \"Your Name\""
    echo "  git config user.email \"your@email.com\""
    echo ""
    exit 1
fi

# Check if remote exists
if ! git remote get-url origin &>/dev/null; then
    echo "⚠️  No GitHub remote configured yet"
    echo ""
    read -p "Enter your GitHub username: " GITHUB_USER
    git remote add origin https://github.com/$GITHUB_USER/openvpn-server.git
    echo "✅ Remote added: https://github.com/$GITHUB_USER/openvpn-server.git"
fi

# Rename branch to main
git branch -M main

# Push to GitHub
echo ""
echo "Pushing to GitHub..."
git push -u origin main

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Successfully pushed to GitHub!"
    echo "Your project is now live at:"
    git remote get-url origin | sed 's/\.git$//'
else
    echo ""
    echo "❌ Push failed. Make sure:"
    echo "  1. You created the repository on GitHub"
    echo "  2. You have the correct permissions"
    echo "  3. You're authenticated (git credential or SSH key)"
fi
