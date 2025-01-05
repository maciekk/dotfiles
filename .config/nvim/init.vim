set runtimepath^=~/.vim runtimepath+=~/.vim/after
let &packpath = &runtimepath
source ~/.vimrc

" As per top answer on:
"   https://vi.stackexchange.com/questions/42383/how-to-setup-treesitter-in-vim-script
lua require('config/treesitter')
