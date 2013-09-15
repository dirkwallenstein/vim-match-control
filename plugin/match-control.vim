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


" File: match-control.vim
" Author: Dirk Wallenstein
" Description: A frontend to matchadd()
" License: LGPLv3
" Version: 0.0.1

if exists('loaded_match_control')
    finish
endif
let loaded_match_control = 1


"
" --- The Match Control Dictionary
"

" Record all instances in a dictionary mapping id to match object.
let s:all_instances = {}

" Create the match control prototype:
let s:MatchControl = {}

" A list of filetypes for which not to highlight match-control initially.
let s:MatchControl.off_filetypes = []

" A list of filetypes for which to exclusively highlight match-control
" initially.  For all other filetypes match-control highlighting will be
" turned off initially.  An empty list has no effect.  Items in the
" off-filetypes list will be overridden if included here.
let s:MatchControl.on_filetypes = []

" Conditions for which to start in off mode.  This overrides the filetype
" specific configuration.  These are strings that can be evaluated with
" eval().  You can also add function calls like 'MyComplexCondition()'.
let s:MatchControl.off_conditions = ['!&modifiable']

" Buffer types for which to start in off mode.  This overrides the filetype
" specific configuration.
let s:MatchControl.off_buftypes = ['quickfix', 'nofile', 'help']

" A dictionary with filetype keys, or '*' as a fallback entry.  Each entry
" maps to another dictionary with three possible keys: 'permanent', 'insert'
" and 'normal'.  Each maps to a list of lists of arguments to matchadd().
"
"       [["highlight-group", 'pattern', priority], ...]
"
" Each of those match specifications are active in the corresponding mode
" (insert/normal or all the time) in the filetype given as top level key.
" Each of the mode keys in a filetype specific entry falls back to the mode
" key in the fallback entry individually.  Specify empty lists to override.
"
" Actually, the normal mode key comprises all the modes that are not the
" insert mode.
let s:MatchControl.match_setup = {}

" This attribute will become the id specified when obtaining a new instance.
let s:MatchControl.id = ''

fun! s:MatchControl._New(id) dict
    if has_key(s:all_instances, a:id)
        throw "MatchControl: a match object with id ".a:id." already exists."
    endif
    if type(a:id) != type('')
        throw "MatchControl: Did not get a string as id attribute."
    endif
    if empty(a:id)
        throw "MatchControl: Got an empty string id."
    endif
    let l:new_MC = copy(self)
    let l:new_MC.id = a:id

    let s:all_instances[a:id] = l:new_MC

    return l:new_MC
endfun

"
" --- Display Default (on/off)
"

fun! s:MatchControl._GetDisplayOnOffDefaultForFiletype() dict
    " Return 1/0 depending on if the current filetype is configured to be on or
    " off.
    if !empty(self.on_filetypes)
        let l:on_filtypes = filter(copy(self.on_filetypes),
                    \ 'v:val == &ft')
        if empty(l:on_filetypes)
            return 0
        else
            return 1
        endif
    endif
    let l:off_filtypes = filter(copy(self.off_filetypes),
                \ 'v:val == &ft')
    if empty(l:off_filtypes)
        return 1
    else
        return 0
    endif
endfun

function! s:MatchControl._IsOffBuftype() dict
    let l:off_buftypes = filter(copy(self.off_buftypes),
                \ 'v:val == &bt')
    if empty(l:off_buftypes)
        return 0
    else
        return 1
    endif
endfunction

fun! s:MatchControl._IsOffCondition() dict
    " Return 1 if any of the conditions in self.off_conditions
    " evaluates to true.
    for l:condition in self.off_conditions
        if eval(l:condition)
            return 1
        endif
    endfor
    return 0
endfun

fun! s:MatchControl._GetDisplayOnOffDefault() dict
    if self._IsOffCondition() || self._IsOffBuftype()
        return 0
    else
        return self._GetDisplayOnOffDefaultForFiletype()
    endif
endfun

" ---

fun! s:MatchControl._GetMatchSetup() dict
    let l:buffer_record = self._GetBufferRecord()
    if has_key(l:buffer_record, 'override_match_setup')
        return l:buffer_record['override_match_setup']
    endif
    return self.match_setup
endfun

fun! s:MatchControl._GetMatchSpecs(mode) dict
    " Return the list of match-specs for the given a:mode.  Valid modes are
    " 'permanent', 'insert' and 'normal'.
    let l:match_setup = self._GetMatchSetup()
    if !empty(&ft)
        try
            let l:ft_dict = l:match_setup[&ft]
            let l:ft_match_specs = l:ft_dict[a:mode]
            return l:ft_match_specs
        catch /E716/ " Key not present in Dictionary
        endtry
    endif
    try
        let l:default_dict = l:match_setup['*']
        let l:fallback_match_specs = l:default_dict[a:mode]
        return l:fallback_match_specs
    catch /E716/ " Key not present in Dictionary
    endtry
    return []
endfun

"
" --- Per-buffer Instance Records
"

fun! s:MatchControl._PrepareBufferRecord(display_state) dict
    if !exists("b:match_control_buf_records")
        let b:match_control_buf_records = {}
    endif
    if !has_key(b:match_control_buf_records, self.id)
        let b:match_control_buf_records[self.id] = {}
    endif
    let l:buffer_record = b:match_control_buf_records[self.id]
    let l:buffer_record['display_state'] = a:display_state
endfun

fun! s:MatchControl._EnsureBufferRecord() dict
    " Check that all mandatory fields are present for this instance.
    if !exists("b:match_control_buf_records")
        throw "InvalidInit: Missing b:match_control_buf_records"
    endif
    if !has_key(b:match_control_buf_records, self.id)
        throw "InvalidInit: Missing buffer record for " . self.id
    endif
    let l:buffer_record = b:match_control_buf_records[self.id]
    if !has_key(l:buffer_record, 'display_state')
        throw "InvalidInit: Missing 'display_state' in buffer record"
    endif
endfun

fun! s:MatchControl._GetBufferRecord() dict
    call self._EnsureBufferRecord()
    return b:match_control_buf_records[self.id]
endfun

fun! s:MatchControl._IsBufferInitialized() dict
    try
        call self._EnsureBufferRecord()
        return 1
    catch /InvalidInit/
        return 0
    endtry
    throw "Should never be reached"
endfun

fun! s:MatchControl._RecordDisplayAsOn() dict
    call self._EnsureBufferRecord()
    let b:match_control_buf_records[self.id]['display_state'] = 1
endfun

fun! s:MatchControl._RecordDisplayAsOff() dict
    call self._EnsureBufferRecord()
    let b:match_control_buf_records[self.id]['display_state'] = 0
endfun

"
" --- Per-window Instance Records
"

fun! s:MatchControl._PrepareWindowRecord() dict
    if !exists("w:match_control_win_records")
        let w:match_control_win_records = {}
    endif
    if has_key(w:match_control_win_records, self.id)
        return
    endif
    let w:match_control_win_records[self.id] = {}
    let w:match_control_win_records[self.id]['permanent'] = []
    let w:match_control_win_records[self.id]['insert'] = []
    let w:match_control_win_records[self.id]['normal'] = []
endfun

fun! s:MatchControl._EnsureWindowRecord() dict
    " Check that all mandatory fields are present for this instance.
    if !exists("w:match_control_win_records")
        throw "InvalidInit: Missing w:match_control_win_records"
    endif
    if !has_key(w:match_control_win_records, self.id)
        throw "InvalidInit: Missing window record for " . self.id
    endif
    let l:window_record = w:match_control_win_records[self.id]
    if !has_key(l:window_record, 'permanent')
        throw "InvalidInit: Missing 'permanent' in window record"
    endif
    if !has_key(l:window_record, 'insert')
        throw "InvalidInit: Missing 'insert' in window record"
    endif
    if !has_key(l:window_record, 'normal')
        throw "InvalidInit: Missing 'normal' in window record"
    endif
endfun

fun! s:MatchControl._RecordActiveMatchId(mode, match_id) dict
    call self._EnsureWindowRecord()
    call add(w:match_control_win_records[self.id][a:mode], a:match_id)
endfun

fun! s:MatchControl._ClearActiveMatchIds(mode) dict
    call self._EnsureWindowRecord()
    let w:match_control_win_records[self.id][a:mode] = []
endfun

fun! s:MatchControl._GetActiveMatchIds(mode) dict
    call self._EnsureWindowRecord()
    return w:match_control_win_records[self.id][a:mode]
endfun

"
" --- General Match Processors
"

fun! s:MatchControl._InstallMatches_ABS(all_specs, match_mode) dict
    " Install the match specifications given in the list a:all_specs and
    " record them in the mode given in a:match_mode.  Deletes existing
    " matches recorded for a:match_mode first.
    if !self.IsDisplayOn()
        return 0
    endif
    call self._DeleteMatches_ABS(a:match_mode)
    for [l:highlight, l:pattern, l:priority] in a:all_specs
        exe 'let l:next_id = matchadd("' . l:highlight . '", '''
                    \ . l:pattern . ''', ' . l:priority . ')'
        call self._RecordActiveMatchId(a:match_mode, l:next_id)
    endfor
    return 1
endfun

fun! s:MatchControl._DeleteMatches_ABS(match_mode) dict
    " Delete the excess line matches in this window recorded in
    " a:match_mode and clear that list.
    for l:id in self._GetActiveMatchIds(a:match_mode)
        call matchdelete(l:id)
    endfor
    call self._ClearActiveMatchIds(a:match_mode)
endfun

"
" --- Permanent Matches
"

fun! s:MatchControl._GetPermanentMatchSpecs() dict
    return self._GetMatchSpecs('permanent')
endfun

fun! s:MatchControl._DeletePermanentMatches() dict
    " Delete the excess line matches in this window
    call self._DeleteMatches_ABS("permanent")
endfun

fun! s:MatchControl._SetPermanentMatches() dict
    return self._InstallMatches_ABS(self._GetPermanentMatchSpecs(),
                \ "permanent")
endfun

"
" --- Insert Mode Matches
"

fun! s:MatchControl._GetInsertModeMatchSpecs() dict
    return self._GetMatchSpecs('insert')
endfun

fun! s:MatchControl._DeleteInsertModeMatches() dict
    " Delete the insert mode matches in this window
    call self._DeleteMatches_ABS("insert")
endfun

fun! s:MatchControl._SetInsertModeMatches() dict
    return self._InstallMatches_ABS(self._GetInsertModeMatchSpecs(),
                \ "insert")
endfun

"
" --- Normal Mode Matches
"

fun! s:MatchControl._GetNormalModeMatchSpecs() dict
    return self._GetMatchSpecs('normal')
endfun

fun! s:MatchControl._DeleteNormalModeMatches() dict
    " Delete the insert mode matches in this window
    call self._DeleteMatches_ABS("normal")
endfun

fun! s:MatchControl._SetNormalModeMatches() dict
    return self._InstallMatches_ABS(self._GetNormalModeMatchSpecs(),
                \ "normal")
endfun

"
" --- Init and Controls
"

fun! s:MatchControl._SwitchToMode(new_mode) dict
    " Switch the active matches (insert/normal)
    if a:new_mode == 'insert'
        call self._DeleteNormalModeMatches()
        call self._SetInsertModeMatches()
    elseif a:new_mode == 'normal'
        call self._DeleteInsertModeMatches()
        call self._SetNormalModeMatches()
    else
        throw "Invalid mode request: " . a:new_mode
    endif
endfun

fun! s:MatchControl._ReInitBuffer() dict
    " Setup excess lines for this buffer anew
    if self._IsBufferInitialized()
        call self.HideMatches()
        call self._InitializeBuffer_cond(1)
    endif
    call self._SyncMatchControl()
endfun

fun! s:MatchControl._InitializeBuffer_cond(force) dict
    " Determine the initial state of the display (on/off)
    if a:force || !self._IsBufferInitialized()
        call self._PrepareBufferRecord(self._GetDisplayOnOffDefault())
    endif
endfun

fun! s:MatchControl._SyncMatchControl() dict
    " Sync the display to the current state of the buffer (show/hide).
    " Initialize the buffer and window if that hasn't already been done.
    call self._PrepareWindowRecord()
    call self._InitializeBuffer_cond(0)
    if self.IsDisplayOn()
        call self.ShowMatches()
    else
        call self.HideMatches()
    endif
endfun

"
" --- Public Interface
"

fun! s:MatchControl.ShowMatches() dict
    " Highlight the matches
    call self._RecordDisplayAsOn()
    call self._SetPermanentMatches()
    if mode() == "i"
        call self._SwitchToMode("insert")
    else
        call self._SwitchToMode("normal")
    endif
endfun

fun! s:MatchControl.HideMatches() dict
    " Delete all matches
    call self._RecordDisplayAsOff()
    call self._DeletePermanentMatches()
    call self._DeleteNormalModeMatches()
    call self._DeleteInsertModeMatches()
endfun

fun! s:MatchControl.ToggleMatches() dict
    " Toggle between hiding and showing matches.
    if self.IsDisplayOn()
        call self.HideMatches()
    else
        call self.ShowMatches()
    endif
endfun

fun! s:MatchControl.GetActivePattern(index) dict
    " Return the pattern for a currently installed match pattern.  The argument
    " for a:index is the index into the currently installed patterns.  If normal
    " or insert mode patterns are active, they come after the permanent
    " patterns.  Throw an exception if there is no pattern at that index.
    let l:recorded_ids = []
    for l:mode in ["permanent", "normal", "insert"]
        call extend(l:recorded_ids, self._GetActiveMatchIds(l:mode))
    endfor
    try
        let l:match_id = l:recorded_ids[a:index]
    catch /E684/ " list index out of range
        throw "No pattern at index " . a:index
    endtry
    for l:matchrecord in getmatches()
        if l:matchrecord['id'] == l:match_id
            return l:matchrecord['pattern']
        endif
    endfor
    throw "ERROR: recorded id not found per getmatches()"
endfun

fun! s:MatchControl.SearchFirstPattern() dict
    let @/ = self.GetActivePattern(0)
endfun

fun! s:MatchControl.InstallOverridePatterns(match_setup) dict
    " Install a match-setup in the current buffer only.  The a:match_setup
    " format is the same as for g:match_control_match_setup
    call self.HideMatches()
    let l:buffer_record = self._GetBufferRecord()
    let l:buffer_record['override_match_setup'] = a:match_setup
    call self.ShowMatches()
endfun

fun! s:MatchControl.UninstallOverridePatterns() dict
    " Uninstall override patterns installed with g:MC_InstallOverridePatterns
    " and return to the previous configuration.
    call self.HideMatches()
    call remove(self._GetBufferRecord(), 'override_match_setup')
    call self.ShowMatches()
endfun

fun! s:MatchControl.IsDisplayOn() dict
    if self._GetBufferRecord()['display_state']
        return 1
    else
        return 0
    endif
endfun

"
" --- Helper Functions
"

fun! s:CallOnEachInstance(method, args)
    for [l:id, l:instance] in items(s:all_instances)
        call call(a:method, a:args, l:instance)
    endfor
endfun

fun! s:SyncAllMatchControls()
    call s:CallOnEachInstance(s:MatchControl._SyncMatchControl, [])
endfun

fun! s:ReInitBufferForAllMatchControls()
    call s:CallOnEachInstance(s:MatchControl._ReInitBuffer, [])
endfun

fun! s:SwitchModeForAllMatchControls(mode)
    call s:CallOnEachInstance(s:MatchControl._SwitchToMode, [a:mode])
endfun

fun! s:ExecuteMethod(method, args, id)
    " Execute a method on the instance with the given id.
    call call(a:method, a:args, g:MC_GetMatchControl(a:id))
endfun

"
" --- Auto-Commands
"

" The entry point:
autocmd WinEnter,BufWinEnter,ColorScheme * call <SID>SyncAllMatchControls()
autocmd FileType * call <SID>ReInitBufferForAllMatchControls()
" Insert mode matches are added/removed by autocommands:
autocmd InsertEnter * call <SID>SwitchModeForAllMatchControls("insert")
autocmd InsertLeave * call <SID>SwitchModeForAllMatchControls("normal")

" ==========

fun! g:MC_CreateMatchControl(id)
    " Obtain a new match control instance.  The arguments are:
    "
    " id: string that identifies uniquely this instance of match control.  It
    " will become the id attribute on the returned instance.
    return s:MatchControl._New(a:id)
endfun

fun! g:MC_GetMatchControl(id)
    " Return the match control instance with the given id and return it.  Throw
    " an error if there is no instance with such an id.
    for [l:id, l:instance] in items(s:all_instances)
        if l:id == a:id
            return l:instance
        endif
    endfor
    throw "NoSuchId: no instance recorded for the id: " . a:id
endfun

" ---

com -nargs=1 MatchControlToggle call
        \ <SID>ExecuteMethod(s:MatchControl.ToggleMatches, [], <f-args>)
com -nargs=1 MatchControlShow call
        \ <SID>ExecuteMethod(s:MatchControl.ShowMatches, [], <f-args>)
com -nargs=1 MatchControlHide call
        \ <SID>ExecuteMethod(s:MatchControl.HideMatches, [], <f-args>)

com -nargs=1 MatchControlSearchFirstPattern call
        \ <SID>ExecuteMethod(s:MatchControl.SearchFirstPattern, [], <f-args>)
