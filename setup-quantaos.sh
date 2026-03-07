#!/data/data/com.termux/files/usr/bin/bash
echo "🚀 Setting up QuantaOS..."
pkg update -y && pkg install -y nodejs git openssh
git clone https://github.com/thenullifier1/QuantaOS ~/QuantaOS
cd ~/QuantaOS && npm install
ssh-keygen -t ed25519 -C "quantaos" -f ~/.ssh/id_ed25519 -N ""
echo "✅ Add this key to https://admin.localhost.run then press Enter"
cat ~/.ssh/id_ed25519.pub
read -p "Press Enter when done..."
kill $(lsof -t -i:3000) 2>/dev/null
cd ~/QuantaOS && node server.js & ssh -R 80:localhost:3000 ssh.localhost.run
