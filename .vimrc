set nocompatible " Make vi into vim, and thus more useful
filetype indent plugin on " use the file type plugins
filetype plugin on

" Set tab stops to 2 columns, rather than the default linux 8
set tabstop=2 softtabstop=2 shiftwidth=2 expandtab

" Set autoindent
set cindent
set smartindent
set expandtab
set cinkeys=0{,0},:,0#,!^F
set autoindent

" Configuration file for vim
set modelines=0		" CVE-2007-2438
set foldmethod=syntax
set foldlevel=10
set scrolloff=5
set sidescrolloff=5
set sidescroll=1
set backspace=indent,eol,start
set whichwrap=h,l,b,<,>,~,[,]
set iskeyword-=_
set showmode
set cursorline cursorcolumn
set wrap nolist
set showbreak=..
set linebreak
set breakindent

syntax on " syntax highlighting
syntax enable
highlight Normal ctermbg=NONE
highlight Comment ctermfg=30
highlight ColorColumn ctermbg=235
highlight CursorColumn ctermbg=235
highlight CursorLine ctermbg=235
set number
set relativenumber  " Set relative line numbers
set nohls   " Disable highliting of search terms.
set incsearch " Highlight as we type.
set ignorecase
set smartcase " Only ignore case if we didn't enter a capital.
set showmatch
set ruler " Add a ruler status bar.
" Set the statusline with all the things.
set statusline=%F%m%r%h%w\ [FORMAT=%{&ff}]\ [TYPE=%Y]\ [ASCII=\%03.3b]\ [HEX=\%02.2B]\ [POS=%04l,%04v][%p%%]\ [LEN=%L]\ 
set statusline+=%{exists('g:loaded_fugitive')?fugitive#statusline():''}
set laststatus=2
set nopaste " Disallow normal pasting by default
set colorcolumn=80,100 " Adding a ruler for the last usable line before 80.
set list
set title
set listchars=eol:↵,tab:»·,trail:·
"set timeout timeoutlen=1 ttimeoutlen=1
set ttyfast
set linebreak
set mouse=a
if exists('+ttymouse')
  set ttymouse=sgr
endif
set clipboard=unnamed
set background=dark

" Duh.  Should be default.
command! Q q
command! Qa qa
command! W w
command! Wa wa

" Resize splits if the window is resized
au VimResized * exe "normal! \<c-w>="

" Make paren matching clearer
hi MatchParen cterm=none ctermbg=black ctermfg=yellow

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
map \] :tabn<Return>
map \[ :tabp<Return>
nnoremap <C-l> <C-w>l
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap K :grep "\b<C-R><C-W>\b"<CR>:cw<CR>
nnoremap <C-n> :NERDTreeToggle<CR>
" Maps to Ctrl + / NOT to underscore
map <C-_> <plug>NERDCommenterToggle

" backup to ~/.tmp 
set backup 
set backupdir=~/.vim-tmp,~/.tmp,~/tmp,/var/tmp,/tmp 
set backupskip=/tmp/*,/private/tmp/* 
set directory=~/.vim-tmp,~/.tmp,~/tmp,/var/tmp,/tmp 
set writebackup

" Install vim-plug if not found
if empty(glob('~/.vim/autoload/plug.vim'))
  silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
    \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
endif

call plug#begin()
Plug 'preservim/nerdcommenter'
Plug 'preservim/nerdtree'
Plug 'kien/ctrlp.vim'
Plug 'altercation/vim-colors-solarized'
Plug 'elzr/vim-json'
" Plug 'ericbn/vim-solarized'
call plug#end()

" Run PlugInstall if there are missing plugins
autocmd VimEnter * if len(filter(values(g:plugs), '!isdirectory(v:val.dir)'))
  \| PlugInstall --sync | source $MYVIMRC
\| endif

" Exit Vim if NERDTree is the only window remaining in the only tab.
autocmd BufEnter * if tabpagenr('$') == 1 && winnr('$') == 1 && exists('b:NERDTree') && b:NERDTree.isTabTree() | quit | endif
" Close the tab if NERDTree is the only window remaining in it.
autocmd BufEnter * if winnr('$') == 1 && exists('b:NERDTree') && b:NERDTree.isTabTree() | quit | endif
" If another buffer tries to replace NERDTree, put it in the other window, and bring back NERDTree.
autocmd BufEnter * if winnr() == winnr('h') && bufname('#') =~ 'NERD_tree_\d\+' && bufname('%') !~ 'NERD_tree_\d\+' && winnr('$') > 1 |
    \ let buf=bufnr() | buffer# | execute "normal! \<C-W>w" | execute 'buffer'.buf | endif
" Open the existing NERDTree on each new tab.
autocmd BufWinEnter * if &buftype != 'quickfix' && getcmdwintype() == '' | silent NERDTreeMirror | endif
let g:NERDTreeFileLines = 1
let g:NERDSpaceDelims = 1
let g:NERDCommentEmptyLines = 1
let g:NERDTrimTrailingWhitespace = 1
let g:NERDToggleCheckAllLines = 1
let g:NERDDefaultAlign = 'left'

let g:solarized_termtrans=1
" set termguicolors
" let g:solarized_contrast=1
" let g:solarized_termcolors=256
colorscheme solarized

let g:ctrlp_map = '<C-p>'
let g:ctrlp_cmd = 'CtrlP'
let g:ctrlp_working_path_mode = 'ra'

" Set via environment or local override; do not commit keys here
" let g:claude_api_key = ''
