#!/bin/bash
SESSION="ZESTDEV"
tmux new-session -d -s $SESSION

tmux rename-window -t 0 'Main'
tmux send-keys -t 'Main' 'zsh' C-m 'clear' C-m

# buildrunner
tmux new-window -t $SESSION:1 -n 'build_runner'
tmux send-keys -t 'build_runner' 'task frontend-build-runner' C-m

# backend (primarily...)
tmux new-window -t $SESSION:2 -n 'backend'
tmux send-keys -t 'backend' 'task docker-start' C-m

#  attach
tmux attach-session -t $SESSION:0
