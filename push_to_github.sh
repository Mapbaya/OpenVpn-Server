#!/bin/bash
# Push OpenVPN Server to GitHub

cd /home/lazou/openvpn-server

echo "🚀 Pushing to GitHub..."
echo ""

# Check Git config
if ! git config user.name &>/dev/null; then
    echo "⚠️  Git user not configured. Using defaults..."
    git config user.name "Mapbaya" 2>/dev/null || true
    git config user.email "mapbaya@users.noreply.github.com" 2>/dev/null || true
fi

# Add all files
echo "📦 Adding files..."
git add .

# Check if there are changes
if git diff --staged --quiet; then
    echo "No changes to commit"
else
    echo "💾 Committing..."
    git commit -m "Initial commit: OpenVPN server with network optimizations" 2>/dev/null || git commit -m "first commit"
fi

# Set branch to main
git branch -M main 2>/dev/null || true

# Add remote if not exists
if ! git remote get-url origin &>/dev/null; then
    echo "🔗 Adding remote..."
    git remote add origin https://github.com/Mapbaya/OpenVpn-Server.git
else
    # Update remote URL if different
    CURRENT_URL=$(git remote get-url origin)
    if [ "$CURRENT_URL" != "https://github.com/Mapbaya/OpenVpn-Server.git" ]; then
        echo "🔄 Updating remote URL..."
        git remote set-url origin https://github.com/Mapbaya/OpenVpn-Server.git
    fi
fi

# Push to GitHub
echo "⬆️  Pushing to GitHub..."
git push -u origin main

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Successfully pushed to GitHub!"
    echo "🌐 Repository: https://github.com/Mapbaya/OpenVpn-Server"
else
    echo ""
    echo "❌ Push failed. Possible reasons:"
    echo "  - Authentication required (use GitHub token or SSH)"
    echo "  - Repository permissions"
    echo ""
    echo "Try:"
    echo "  git push -u origin main"
fi
