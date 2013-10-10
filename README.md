Vim-Match-Control
=================

This is a generalization of [vim-excess-lines][] (EL) and [vim-bad-whitespace][]
(BW).  It can be used to replace both of them, and it is very easy to create
additional schemes with all the controls that EL has to offer.

Here, you create a clone of the `MatchControl` class and configure it by setting
attributes.  You can also call methods on that object to control or access
matches.  See the [plugin-file][] at the top for configuration attributes and
the bottom of that file for the public interface.

    ru plugin/match-control.vim

    if !exists("g:mc_div")

        " Create an instance with the id 'div'
        let g:mc_div = g:MC_CreateMatchControl('div')

        " Configure the instance
        let g:mc_div.off_filetypes = ['gitcommit', 'sh']
        let g:mc_div.on_filetypes = []
        let g:mc_div.off_conditions = ['!&modifiable', '&wrap']
        let g:mc_div.off_buftypes = ['quickfix']
        let g:mc_div.match_setup = {'diff': {
                \'permanent': [["HlgrpName", '^+.\+\zs\%82v.\+\ze', -70]],
                \ }}
    endif

Unlike in EL, you can configure match-specifications for buffers with no
filetype set, by using the key `'!'`.

There are commands for the most common operations. They take the id of the
match-control instance to operate on as argument.

    nnoremap ,mt :MatchControlToggle div<CR>
    nnoremap ,ms :MatchControlShow div<CR>
    nnoremap ,mh :MatchControlHide div<CR>
    nnoremap ,m/ :MatchControlSearchFirstActivePattern div<CR>n

#### Example setups for EL and BW
There are two functions to obtain instances that replicate the default behavior
of EL and BW.  For example to replace EL:

        if !exists("g:mc_el")
            ru plugin/match-control-example-setups.vim
            let g:mc_el = g:MatchControl_CreateExcessLinesInstance()
        endif

The function for BW takes arguments for the normal and alternative highlight
groups to use, a list of filetypes for which to use the alternative highlight
group, and a list of filetypes for which to install override-patterns that do
not highlight space in the +/- columns.

        if !exists("g:MC_BW")
            ru plugin/match-control-example-setups.vim
            let g:MC_BW = g:MatchControl_CreateBadWhitespaceInstance(
                    \ 'BadWhitespaceNormal', 'BadWhitespaceAlt',
                    \ ['markdown', 'gitcommit'], ['diff', 'git'])
        endif

  [vim-excess-lines]: https://github.com/dirkwallenstein/vim-excess-lines
  [vim-bad-whitespace]: https://github.com/dirkwallenstein/vim-bad-whitespace
  [plugin-file]: https://github.com/dirkwallenstein/vim-match-control/blob/master/plugin/match-control.vim
