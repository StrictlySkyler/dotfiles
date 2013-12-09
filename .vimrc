set nocompatible " Make vi into vim, and thus more useful
" Set tab stops to 2 columns, rather than the default linux 8
set tabstop=2 softtabstop=2 shiftwidth=2 expandtab

" Set autoindent
set cindent
set smartindent
set autoindent
set expandtab
set cinkeys=0{,0},:,0#,!^F

" Configuration file for vim
set modelines=0		" CVE-2007-2438

" Normally we use vim-extensions. If you want true vi-compatibility
" remove change the following statements
set nocompatible	" Use Vim defaults instead of 100% vi compatibility
set backspace=2		" more powerful backspacing
set ai			" auto indenting
set history=100		" keep 100 lines of history
syntax on		" syntax highlighting
colorscheme desert  " Set the color to something decent.
set nu  " Set line numbers
set nohls   " Disable highliting of search terms.
filetype indent plugin on	" use the file type plugins
call pathogen#infect('~/.vim/bundle') " Autoinfect with plugins!

" When editing a file, always jump to the last cursor position
autocmd BufReadPost *
\ if ! exists("g:leave_my_cursor_position_alone") |
\ if line("'\"") > 0 && line ("'\"") <= line("$") |
\ exe "normal g'\"" |
\ endif |
\ endif

" Don't write backup file if vim is being called by "crontab -e"
au BufWrite /private/tmp/crontab.* set nowritebackup
" Don't write backup file if vim is being called by "chpass"
au BufWrite /private/etc/pw.* set nowritebackup

" Mappings
set pastetoggle=<F2>
