set nocompatible " Make vi into vim, and thus more useful
filetype indent plugin on " use the file type plugins
filetype plugin on
runtime macros/matchit.vim
call pathogen#infect('~/.vim/bundle/{}') " Autoinfect with plugins!

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
set nofoldenable " Folding seems janky, disabling for now
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

" Normally we use vim-extensions. If you want true vi-compatibility
" remove change the following statements
set backspace=2 " more powerful backspacing
set history=100 " keep 100 lines of history
syntax on " syntax highlighting
syntax enable
let g:solarized_termcolors=256
set t_Co=256
set background=dark
colorscheme solarized " Set the color to something decent.
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
set ttymouse=xterm2
set clipboard=unnamed

" Airline
let g:airline_powerline_fonts = 1

" Don't insert a new comment line when I use enter or o/O.
autocmd FileType * setlocal formatoptions-=r formatoptions-=o

" Duh.  Should be default.
command! Q q
command! Qa qa
command! W w
command! Wa wa

let g:html_intdent_tags='li\|p'

" Syntastic
set statusline+=%#warningmsg#
set statusline+=%{SyntasticStatuslineFlag()}
set statusline+=%*

let g:syntastic_always_populate_loc_list = 1
let g:syntastic_loc_list_height = 5
let g:syntastic_auto_loc_list = 0
let g:syntastic_check_on_open = 1
let g:syntastic_check_on_wq = 1
let g:syntastic_javascript_checkers = ['eslint']

let g:syntastic_error_symbol = '❌'
let g:syntastic_style_error_symbol = '⁉️'
let g:syntastic_warning_symbol = '⚠️'
let g:syntastic_style_warning_symbol = '💩'

highlight link SyntasticErrorSign SignColumn
highlight link SyntasticWarningSign SignColumn
highlight link SyntasticStyleErrorSign SignColumn
highlight link SyntasticStyleWarningSign SignColumn

hi SpellBad ctermfg=015 ctermbg=196 guifg=#ffffff guibg=#ff0000
hi SpellCap ctermfg=015 ctermbg=202 guifg=#ffffff guibg=#ff5f00

let g:gitgutter_override_sign_column_highlight = 0
highlight SignColumn ctermfg=196 ctermbg=236

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

" https://github.com/wesQ3/vim-windowswap
"let g:windowswap_map_keys = 0 "prevent default bindings
"nnoremap <silent> <leader>yw :call WindowSwap#MarkWindowSwap()<CR>
"nnoremap <silent> <leader>pw :call WindowSwap#DoWindowSwap()<CR>
"nnoremap <silent> <leader>ww :call WindowSwap#EasyWindowSwap()<CR>
nnoremap <C-w>y :call WindowSwap#MarkWindowSwap()<CR>
nnoremap <C-w>p :call WindowSwap#DoWindowSwap()<CR>
nnoremap <C-w>e :call WindowSwap#EasyWindowSwap()<CR>

" CtrlP Mappings: http://kien.github.io/ctrlp.vim/
let g:ctrlp_map = '<c-p>'
let g:ctrlp_cmd = 'CtrlP'
let g:ctrlp_working_path_mode = 'ra'
set wildignore+=*/tmp/*,*.so,*.swp,*.zip
let g:ctrlp_custom_ignore = '\v[\/]\.(git|hg|svn)$'
let g:ctrlp_user_command = 'sift -i --no-conf --no-color --no-group --targets --exclude-dirs=".git" --exclude-ext="min.js,dat,exe,gif,png,jpeg,jpg,ico" %s'

" CtrlPFunky
let g:ctrlp_extensions = ['funky']
nnoremap <Leader>f :CtrlPFunky<Cr>
" narrow the list down with a word under cursor
nnoremap <Leader>f :execute 'CtrlPFunky ' .expand('<cword')<Cr>
let g:ctrlp_funky_syntax_highlight = 1

" backup to ~/.tmp 
set backup 
set backupdir=~/.vim-tmp,~/.tmp,~/tmp,/var/tmp,/tmp 
set backupskip=/tmp/*,/private/tmp/* 
set directory=~/.vim-tmp,~/.tmp,~/tmp,/var/tmp,/tmp 
set writebackup

" https://github.com/svermeulen/vim-easyclip
let g:EaseClipUsePasteToggleDefaults = 0
nmap <C-b> <plug>EasyClipSwapPasteForward
nmap <C-f> <plug>EasyClipSwapPasteBackwards

" Unite.vim and the_platinum_searcher, if we have it
nnoremap <silent> <Leader>g :<C-u>Unite grep:. -buffer-name=search-buffer<CR>
nnoremap <silent> <Leader>u :Unite file_rec/async<CR>

" NERDTree configurations: https://github.com/scrooloose/nerdtree
autocmd StdinReadPre * let s:std_in=1
autocmd VimEnter * if argc() == 0 && !exists("s:std_in") | NERDTree | endif
map <C-n> :NERDTreeToggle<CR>
" The following line no longer seems to work...
"autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTreeType") && b:NERDTreeType == "primary") | q | endif
" ...But this one purportedly does.
autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif

" Converting between Tabs and Spaces with these nice functions:

" Return indent (all whitespace at start of a line), converted from
" tabs to spaces if what = 1, or from spaces to tabs otherwise.
" When converting to tabs, result has no redundant spaces.
function! Indenting(indent, what, cols)
  let spccol = repeat(' ', a:cols)
  let result = substitute(a:indent, spccol, '\t', 'g')
  let result = substitute(result, ' \+\ze\t', '', 'g')
  if a:what == 1
    let result = substitute(result, '\t', spccol, 'g')
  endif
  return result
endfunction

" Convert whitespace used for indenting (before first non-whitespace).
" what = 0 (convert spaces to tabs), or 1 (convert tabs to spaces).
" cols = string with number of columns per tab, or empty to use 'tabstop'.
" The cursor position is restored, but the cursor will be in a different
" column when the number of characters in the indent of the line is changed.
function! IndentConvert(line1, line2, what, cols)
  let savepos = getpos('.')
  let cols = empty(a:cols) ? &tabstop : a:cols
  execute a:line1 . ',' . a:line2 . 's/^\s\+/\=Indenting(submatch(0), a:what, cols)/e'
  call histdel('search', -1)
  call setpos('.', savepos)
endfunction
command! -nargs=? -range=% Space2Tab call IndentConvert(<line1>,<line2>,0,<q-args>)
command! -nargs=? -range=% Tab2Space call IndentConvert(<line1>,<line2>,1,<q-args>)
command! -nargs=? -range=% RetabIndent call IndentConvert(<line1>,<line2>,&et,<q-args>)

" https://github.com/plasticboy/vim-markdown/
let g:vim_markdown_initial_foldlevel=1

let g:indentLine_noConcealCursor=""
