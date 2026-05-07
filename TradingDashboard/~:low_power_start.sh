 #!/bin/bash

echo "🔋 Low Power Mode Starting..."

# Kill leftover dev processes
pkill -f uvicorn
pkill -f python
pkill -f node

# Kill stuck UI processes
killall "Menulet" 2>/dev/null

# Reduce Chrome background activity
defaults write com.google.Chrome BackgroundModeEnabled -bool false

echo "✅ Clean environment ready"