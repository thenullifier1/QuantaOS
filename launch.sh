#!/data/data/com.termux/files/usr/bin/bash
pkg install tmux -y 2>/dev/null
kill $(lsof -t -i:3000) 2>/dev/null
tmux new-session -d -s quantaos 2>/dev/null || tmux kill-session -t quantaos && tmux new-session -d -s quantaos
tmux send-keys -t quantaos "cd ~/QuantaOS && node server.js & ssh -R 80:localhost:3000 ssh.localhost.run" Enter
tmux attach -t quantaos
