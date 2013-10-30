Vim-Match-Control
=================

Imagine you could paint in any window with just a regular expression and
a highlight group.  That is what Vim's `matchadd()` mechanism makes possible.
This plugin provides a frontend to `matchadd()` and it allows you to configure
persistently where to see which matches.

Or put another way: You can take over every aspect of text coloring in a buffer
and highlight information that is important to you, if you can express it in
form of a regular expression.

##### Features:

- Setup multiple independent control units for matching and configure conditions
  that determine the initial on/off state for a buffer.
- Match different patterns during insert and normal mode
- Turn highlighting on/off or toggle it
- Extract patterns of active matches to search for or act on them
- Use example setups to highlight trailing whitespace or surplus content of long
  lines.

##### A General Solution

This is a generalization of [vim-excess-lines][] (EL) and [vim-bad-whitespace][]
(BW).  It can be used to replace both of them, and it is very easy to create
additional schemes with all the controls that EL has to offer.

### Usage

Create a clone of the `MatchControl` class and configure it by setting
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

Right now, the `exists` condition is recommended because there will be an error
if you try to create an instance for an id that is already present.  So, if you
want to re-source your configuration you would get an error without that
conditional.

##### Match Setup

The dictionary `match_setup` can be used to configure the matches.  The keys are
filetypes to which the values apply.  Each value is another dictionary where the
keys are the mode in which the list of match-specifications they map to are
active.

There is one special key `*` that applies to all filetypes without a key.

The three valid modes are:

- `'permanent'` : active in all modes
- `'insert'` : only active in insert mode
- `'normal'` : only active when not in insert mode

Note that each of the missing mode-keys of a specific filetype falls back to the
one in the default entry `*` individually.    Specify an empty list to override.

For example, to add special excess-lines highlighting behavior for `markdown`
files you can add an entry similar to this one:

    let g:mc_div.match_setup['markdown'] = {
        \   'permanent': s:expl_permanent_matches,
        \   'insert': s:expl_insert_mode_matches,
        \   'normal': [],
        \ }

The match specifications consist of arguments to `matchadd()`.

    [['highlight-group', 'pattern', priority], ...]

To highlight all characters beyond column 80 you could use this list of match
specifications:

    let s:expl_permanent_matches = [
        \   ["LineNr", '\%81v.\+', -70],
        \ ]

In insert mode, you might want to override the permanent match from above
with an unobtrusive undercurl and place a warning sign at column 70.  This is
what the following list of match-specifications does.

    let s:expl_insert_mode_matches = [
        \   ["Todo",  '\zs\%70v.\ze.*\%#', -50],
        \   ["Todo",  '\%#.*\zs\%70v.\ze', -50],
        \   ["Undercurl",  '\%81v.\+\%#.*$', -50],
        \   ["Undercurl",  '\%#.*\zs\%81v.\+\ze$', -50],
        \ ]

So, there is a lot possible, but if you just want to highlight excess chars in
selected filetypes starting at different columns, you can use something like
this:

    let g:mc_div.match_setup = {
        \ '*': { 'permanent': ["Error", '\%81v.\+', -50]},
        \ 'html': { 'permanent': ["Error", '\%91v.\+', -50]},
        \ 'text': { 'permanent': ["Error", '\%101v.\+', -50]},
        \ }

You can configure match-specifications for buffers with no filetype set, by
using the key `'!'`.

##### Commands

There are commands for the most common operations. They take the id of the
match-control instance to operate on as argument.

    nnoremap ,mt :MatchControlToggle div<CR>
    nnoremap ,ms :MatchControlShow div<CR>
    nnoremap ,mh :MatchControlHide div<CR>
    nnoremap ,m/ :MatchControlSearchFirstActivePattern div<CR>n

##### Active Patterns

You can extract the patterns of active matches by index (zero based).  The
permanent patterns come first and then either insert or normal mode patterns.
Use the `GetActivePattern` method of a match-control instance (`g:mc_div` in
this example) to access any active match pattern.

    g:mc_div.GetActivePattern(<index>)

There is a shortcut command to assign the pattern of the first active match to
the search register:

    MatchControlSearchFirstActivePattern <id>

##### Override Patterns

It is possible to temporarily install a different match-setup in a buffer.  In
combination with autocommands this allows you to create match-setups
dynamically.

Use these methods to work with override patterns.  The argument `<match_setup>`
is a dictionary of the same format as described above.

    g:mc_div.InstallOverridePatterns(<match_setup>)
    g:mc_div.UninstallOverridePatterns()

### Example setups for EL and BW
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

You can further customize the returned instances.  If you are interested in the,
patterns, autocommands, and override-patterns used, take a look at the source
code for the [example-setups][].

  [vim-excess-lines]: https://github.com/dirkwallenstein/vim-excess-lines
  [vim-bad-whitespace]: https://github.com/dirkwallenstein/vim-bad-whitespace
  [plugin-file]: https://github.com/dirkwallenstein/vim-match-control/blob/master/plugin/match-control.vim
  [example-setups]: https://github.com/dirkwallenstein/vim-match-control/blob/master/plugin/match-control-example-setups.vim
