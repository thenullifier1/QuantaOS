#!/data/data/com.termux/files/usr/bin/bash
pkg install -y tmux nodejs git openssh 2>/dev/null
[ ! -d ~/QuantaOS ] && git clone https://github.com/thenullifier1/QuantaOS ~/QuantaOS && cd ~/QuantaOS && npm install
kill $(lsof -t -i:3000) 2>/dev/null
tmux kill-session -t quantaos 2>/dev/null
tmux new-session -d -s quantaos
tmux send-keys -t quantaos "cd ~/QuantaOS && node server.js & ssh -R 80:localhost:3000 ssh.localhost.run" Enter
exec tmux attach -t quantaos
