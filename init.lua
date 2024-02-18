vim.cmd([[colorscheme habamax]]) 

vim.o.shiftwidth = 4
vim.o.shell = 'powershell'
vim.o.shellcmdflag = "-NoLogo -ExecutionPolicy RemoteSigned -Command [Console]::InputEncoding=[Console]::OutputEncoding=[System.Text.UTF8Encoding]::new();$PSDefaultParameterValues['Out-File:Encoding']='utf8';"
vim.o.shellquote = ''
vim.o.shellxquote = ''
vim.o.shellpipe = '2>&1 | %%{ "$_" } | Tee-Object %s; exit $LastExitCode'
vim.o.shellredir = '2>&1 | %%{ "$_" } | Out-File %s; exit $LastExitCode'

vim.cmd([[hi MatchParen cterm=None ctermfg=199 ctermbg=None]]) 
vim.cmd([[autocmd TermOpen * setlocal nonumber norelativenumber]]) 

--> dotnet build diagnostics
vim.api.nvim_create_namespace("dotnet_diagnostics")
vim.api.nvim_create_autocmd({"QuickFixCmdPost"}, {
    callback = function()
	local buffdiag = {}
	ns = vim.api.nvim_create_namespace("dotnet_diagnostics")
	for i, err in pairs(vim.fn.getqflist()) do
	    errbuf = buffdiag[err.bufnr]
	    if errbuf then
		table.insert(errbuf, {
		    lnum = err.lnum,
		    end_lnum = err.end_lnum,
		    col=err.col,
		    end_col=err.end_col,
		    severity=err.type,
		    message=err.text
		})
	    else
		table.insert(buffdiag, err.bufnr, {{
		    lnum = err.lnum,
		    end_lnum = err.end_lnum,
		    col=err.col,
		    end_col=err.end_col,
		    severity=err.type,
		    message=err.text
		}})
	    end
	end
	for bufnr, diags in pairs(buffdiag) do
	    vim.diagnostic.set(ns, bufnr, diags)
	end
    end,
})

vim.api.nvim_create_autocmd({"QuickFixCmdPre"}, { callback = function() vim.diagnostic.reset(ns) end, })

--> Git diff for nvim signs for current buffer
-- ':sign unplace *' to remove all signs
vim.fn.sign_define('+', { text = '+', texthl = "DiffAdd", linehl = "DiagnosticOk", numhl = "" })
vim.fn.sign_define('_', { text = '_', texthl = "DiffDelete", linehl = "DiagnosticError", numhl = "" })
vim.fn.sign_define('~_', { text = '~_', texthl = "DiffChange", linehl = "DiagnosticWarn", numhl = "" })
vim.fn.sign_define('~', { text = '~', texthl = "DiffChange", linehl = "DiagnosticWarn", numhl = "" })
vim.api.nvim_create_namespace("git_diff")
vim.api.nvim_create_user_command('Gdiff',
    function(opts)
	--> git --no-pager diff --no-ext-diff --no-color -U0
	currbuff = vim.fn.expand('%')
	local diff = vim.fn.system({'git', '--no-pager', 'diff', '--no-ext-diff', '--no-color', '-U0', vim.fn.expand('%')})
	--> parse hunks
	--
	--
	--   local del = vim.fn.matchlist(line, "+\\(\\.*\\)")
	--    if table.getn(del) then
	--	vim.api.nvim_buf_set_extmark(vim.api.nvim_get_current_buf(), ns, linenumber-2, 0, {virt_lines = {{{"test", "DiagnosticError"}}}})

	--
	local hunkreg = "^@@ -\\(\\d\\+\\),\\?\\(\\d*\\) +\\(\\d\\+\\),\\?\\(\\d*\\) @@"
	local lines = {}
	local currline = 1
	local header_parsed = false
	ns = vim.api.nvim_create_namespace("git_diff")
	for line in diff:gmatch('[^\r\n]+') do
	    local match = vim.fn.matchlist(line, hunkreg)
	    local del = vim.fn.matchlist(line, "-\\(.*\\)")
	    if table.getn(del) > 0 and header_parsed then
		vim.api.nvim_buf_set_extmark(vim.api.nvim_get_current_buf(), ns, currline-2, 0, {virt_lines = {{{"-"..del[2], "DiagnosticError"}}}})
	    elseif table.getn(match) > 0 then
		header_parsed = true
		line = tonumber(match[2])
		currline = line
		count = tonumber(match[3])
		if count == nil then count = 1 end
		newline = tonumber(match[4])
		newcount = tonumber(match[5])
		if newcount == nil then newcount = 1 end

		--> added
		if count == 0 and newcount > 0 then
		    for lnum=0,newcount-1 do
			table.insert(lines, {name = '+', lnum = lnum+newline, buffer = vim.api.nvim_get_current_buf()})
		    end
		end
		
		--> removed
		if count > 0 and newcount == 0 then
		    if newline == 0 then
			table.insert({1, '='}, lines)
		    else
			table.insert(lines, {name = '_', lnum = newline, buffer = vim.api.nvim_get_current_buf()})
			for lnum=0,count do
			    linenumber = line+lnum
			    print(linenumber)
			end
		    end
		end

		--> modified
		if count > 0 and newcount > 0 and count == newcount then
		    for lnum=0,newcount-1 do
			table.insert(lines, {name = '~', lnum = lnum+newline, buffer = vim.api.nvim_get_current_buf()})
		    end
		end

		--> modified & added
		if count > 0 and newcount > 0 and count < newcount then
		    for lnum=0,count-1 do
			table.insert(lines, {name = '~', lnum = lnum+newline, buffer = vim.api.nvim_get_current_buf()})
		    end
		    for lnum=count,newcount-1 do
			table.insert(lines, {name = '+', lnum = lnum+newline, buffer = vim.api.nvim_get_current_buf()})
		    end
		end

		--> modified & removed
		if count > 0 and newcount > 0 and count > newcount then
		    for lnum=0,count-1 do
			table.insert(lines, {name = '~', lnum = lnum+newline, buffer = vim.api.nvim_get_current_buf()})
		    end
		    lines[count-1] = {name = '~_', lnum = newline+newcount, buffer = vim.api.nvim_get_current_buf()}
		end
	    end
	end
	--vim.fn.sign_placelist(lines)
    end, {})

