#!/data/data/com.termux/files/usr/bin/bash
echo "🚀 Setting up QuantaOS..."
pkg update -y && pkg install -y nodejs git openssh
git clone https://github.com/thenullifier1/QuantaOS ~/QuantaOS
cd ~/QuantaOS && npm install
ssh-keygen -t ed25519 -C "quantaos" -f ~/.ssh/id_ed25519 -N ""
echo "✅ Add this key to https://admin.localhost.run:"
cat ~/.ssh/id_ed25519.pub
echo 'kill $(lsof -t -i:3000) && cd ~/QuantaOS && node server.js & ssh -R 80:localhost:3000 ssh.localhost.run' > ~/launch.sh
chmod +x ~/launch.sh
echo "✅ Done! Run: bash ~/launch.sh"
