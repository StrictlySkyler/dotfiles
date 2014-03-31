set nocompatible " Make vi into vim, and thus more useful
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
set nowrap

" Normally we use vim-extensions. If you want true vi-compatibility
" remove change the following statements
set nocompatible	" Use Vim defaults instead of 100% vi compatibility
set backspace=2		" more powerful backspacing
set history=100		" keep 100 lines of history
syntax on		" syntax highlighting
colorscheme desert  " Set the color to something decent.
set number
set relativenumber  " Set relative line numbers
set nohls   " Disable highliting of search terms.
set ruler " Add a ruler status bar.
set statusline=%F%m%r%h%w\ [FORMAT=%{&ff}]\ [TYPE=%Y]\ [ASCII=\%03.3b]\ [HEX=\%02.2B]\ [POS=%04l,%04v][%p%%]\ [LEN=%L] 
set laststatus=2
set nopaste " Disallow normal pasting by default
set colorcolumn=79 " Adding a ruler for the last usable line before 80.
set list
set listchars=eol:¬,tab:>_
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
map \] :tabn<Return>
map \[ :tabp<Return>

" CtrlP Mappings: http://kien.github.io/ctrlp.vim/
let g:ctrlp_map = '<c-p>'
let g:ctrlp_cmd = 'CtrlP'
let g:ctrlp_working_path_mode = 'ra'
set wildignore+=*/tmp/*,*.so,*.swp,*.zip
let g:ctrlp_custom_ignore = '\v[\/]\.(git|hg|svn)$'

" CtrlPFunky
let g:ctrlp_extensions = ['funky']
nnoremap <Leader>f :CtrlPFunky<Cr>
" narrow the list down with a word under cursor
nnoremap <Leader>f :execute 'CtrlPFunky ' .expand('<cword')<Cr>
let g:ctrlp_funky_syntax_highlight = 1

" Use matcher for searching instead of default CtrlP globpath()
let g:path_to_matcher = "/usr/local/bin/matcher"

let g:ctrlp_user_command = ['.git/', 'cd %s && git ls-files . -co --exclude-standard']

let g:ctrlp_match_func = { 'match': 'GoodMatch' }

function! GoodMatch(items, str, limit, mmode, ispath, crfile, regex)

  " Create a cache file if not yet exists
  let cachefile = ctrlp#utils#cachedir().'/matcher.cache'
  if !( filereadable(cachefile) && a:items == readfile(cachefile) )
    call writefile(a:items, cachefile)
  endif
  if !filereadable(cachefile)
    return []
  endif

  " a:mmode is currently ignored. In the future, we should probably do
  " something about that. the matcher behaves like "full-line".
  let cmd = g:path_to_matcher.' --limit '.a:limit.' --manifest '.cachefile.' '
  if !( exists('g:ctrlp_dotfiles') && g:ctrlp_dotfiles )
    let cmd = cmd.'--no-dotfiles '
  endif
  let cmd = cmd.a:str

  return split(system(cmd), "\n")

endfunction

" backup to ~/.tmp 
set backup 
set backupdir=~/.vim-tmp,~/.tmp,~/tmp,/var/tmp,/tmp 
set backupskip=/tmp/*,/private/tmp/* 
set directory=~/.vim-tmp,~/.tmp,~/tmp,/var/tmp,/tmp 
set writebackup
