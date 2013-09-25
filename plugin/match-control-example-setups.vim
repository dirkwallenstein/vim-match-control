" This program is free software: you can redistribute it and/or modify
" it under the terms of the GNU Lesser General Public License as published by
" the Free Software Foundation, either version 3 of the License, or
" (at your option) any later version.
"
" This program is distributed in the hope that it will be useful,
" but WITHOUT ANY WARRANTY; without even the implied warranty of
" MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
" GNU General Public License for more details.
"
" You should have received a copy of the GNU Lesser General Public License
" along with this program.  If not, see <http://www.gnu.org/licenses/>.


if exists('loaded_match_control_example_setups')
    finish
endif
let loaded_match_control_example_setups = 1

" To be able to create instances, source the main plugin file.
ru plugin/match-control.vim

"
" --- Bad Whitespace
"

fun s:GetBadWhitespacePatternsForPatches()
    let l:save_cursor = getpos(".")
    let patch_info = {}
    if search('^@\+', 'we')
        let l:start_colum = col('.')
    else
        throw "PatchPatterns: no sequence of @ chars found"
    endif
    call setpos('.', l:save_cursor)

    let l:pattern_prefix = '\%' . l:start_colum . 'c.\{-\}\zs\s\+\ze'

    let l:patch_info = {}
    let l:patch_info.nonedit_pattern = l:pattern_prefix . '$'
    let l:patch_info.edit_pattern = l:pattern_prefix . '\%#\@<!$'
    let l:patch_info.num_parents = l:start_colum - 1
    return patch_info
endfun

fun s:InstallPatchPatternsIntoCurrentBuffer(hlgrp)
    try
        let l:patch_info = s:GetBadWhitespacePatternsForPatches()
    catch /PatchPatterns/
        " No patch found in current buffer
        return
    endtry
    let l:pp_match_setup = {
        \ '*': {
        \       'permanent': [],
        \       'normal': [[a:hlgrp, l:patch_info.nonedit_pattern, -20]],
        \       'insert': [[a:hlgrp, l:patch_info.edit_pattern, -20]],
        \       },
        \ }
    let l:mc_bw = g:MC_GetMatchControl('bad-whitespace')
    call l:mc_bw.InstallOverridePatterns(l:pp_match_setup)
endfun

fun g:MatchControl_CreateBadWhitespaceInstance(
            \ hlgrp_normal, hlgrp_alt, alt_filetypes, patch_filetypes)
    " Replicate mostly the behavior of vim-bad-whitespace and return the
    " corresponding match-control instance.
    "
    " Arguments:
    " hlgrp_normal: The name of a highlight group to be used for bad-whitespace
    " hlgrp_alt: The name of a highlight group to be used for alt_filetypes
    " alt_filetypes: a list of filetypes for which to use hlgrp_alt
    " patch_filetypes: Install patch-display override-patterns into
    "     a buffer if the filetype matches any of the filetype names
    "     given in this list
    for l:patch_ft in a:patch_filetypes
        exe "au FileType " . l:patch_ft . " call "
                \ . "<SID>InstallPatchPatternsIntoCurrentBuffer('"
                \ . a:hlgrp_normal . "')"
    endfor

    let l:nonedit_pattern = '\_s\+\%$\|\s\+$'
    let l:edit_pattern = '\_s\+\%#\@<!\%$\|\s\+\%#\@<!$'

    let l:ftconfig_normal = {
        \     'permanent': [],
        \     'normal': [[a:hlgrp_normal, l:nonedit_pattern, -20]],
        \     'insert': [[a:hlgrp_normal, l:edit_pattern, -20]],
        \     }
    let l:ftconfig_alt = {
        \     'permanent': [],
        \     'normal': [[a:hlgrp_alt, l:nonedit_pattern, -20]],
        \     'insert': [[a:hlgrp_alt, l:edit_pattern, -20]],
        \     }
    let l:match_setup = {'*': l:ftconfig_normal}
    for l:ft in a:alt_filetypes
        let l:match_setup[l:ft] = l:ftconfig_alt
    endfor

    let l:mc_bw = g:MC_CreateMatchControl('bad-whitespace')
    let l:mc_bw.match_setup = l:match_setup

    return l:mc_bw
endfun

" --- Excess Lines

fun g:MatchControl_CreateExcessLinesInstance()
    " Return a match-control instance that mimics the default behavior of the
    " vim-excess-lines plugin.

    highlight MC_EXP_InsertTail gui=undercurl guisp=Magenta
                \ term=reverse ctermfg=15 ctermbg=12
    highlight MC_EXP_Warning guifg=Black guibg=Yellow
                \ term=standout cterm=bold ctermfg=0 ctermbg=3
    highlight MC_EXP_Error guifg=White guibg=Firebrick
                \ term=reverse cterm=bold ctermfg=7 ctermbg=1

    let l:exp_permanent_matches = [
        \   ["MC_EXP_Error", '\%81v.\+', -70],
        \   ]
    let l:exp_insert_mode_matches = [
        \   ["MC_EXP_Warning",  '\zs\%70v.\ze.*\%#', -50],
        \   ["MC_EXP_Warning",  '\%#.*\zs\%70v.\ze', -50],
        \   ["MC_EXP_InsertTail",  '\%81v.\+\%#.*$', -50],
        \   ]
    let l:exp_normal_mode_matches = []

    let l:match_setup = {
        \ '*': {
        \       'permanent': l:exp_permanent_matches,
        \       'normal': l:exp_normal_mode_matches,
        \       'insert': l:exp_insert_mode_matches,
        \       },
        \ }

    let l:mc_el = g:MC_CreateMatchControl('excess-lines')
    let l:mc_el.match_setup = l:match_setup
    let l:mc_el.off_conditions = ['!&modifiable', '&wrap']

    return l:mc_el
endfun
