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


vim.fn.sign_define('E', { text = 'E', texthl = "Error", linehl = "", numhl = "" })
vim.fn.sign_define('W', { text = 'W', texthl = "DiagnosticWarn", linehl = "", numhl = "" })
vim.api.nvim_create_autocmd({"QuickFixCmdPost"}, {
    callback = function()
	local errs = {}
	for i, err in pairs(vim.fn.getqflist()) do
	    if err.type == 'E' then
		table.insert(errs, {group = 'diagnostics', name = 'E', lnum=err.lnum, buffer=vim.api.nvim_buf_get_name(err.bufnr)})
	    else
		table.insert(errs, {group = 'diagnostics', name = 'W', lnum=err.lnum, buffer=vim.api.nvim_buf_get_name(err.bufnr)})
	    end
	end
	vim.fn.sign_placelist(errs)
    end,
})

vim.api.nvim_create_autocmd({"QuickFixCmdPre"}, {
    callback = function()
	vim.fn.sign_unplace('diagnostics')
	--vim.fn.sign_placelist(vim.fn.getfqlist())
    end,
})

vim.api.nvim_create_autocmd("BufWrite", {
    pattern = "*.cs",
    group = vim.api.nvim_create_augroup('dotnet_on_save_err', { clear = true }),
    callback = function()
	local lines = {""}  local winnr = vim.fn.win_getid()  local bufnr = vim.api.nvim_win_get_buf(winnr)   local makeprg = vim.api.nvim_buf_get_option(bufnr, "makeprg")  if not makeprg then return end   local cmd = vim.fn.expandcmd(makeprg)   local function on_event(job_id, data, event)    if event == "stdout" or event == "stderr" then      if data then        vim.list_extend(lines, data)      end    end     if event == "exit" then      vim.fn.setqflist({}, " ", {        title = cmd,        lines = lines,        efm = vim.api.nvim_buf_get_option(bufnr, "errorformat")      })      vim.api.nvim_command("doautocmd QuickFixCmdPost")    end  end   local job_id =    vim.fn.jobstart(    cmd,    {      on_stderr = on_event,      on_stdout = on_event,      on_exit = on_event,      stdout_buffered = true,      stderr_buffered = true,    }  )end

})


vim.fn.sign_define('+', { text = '+', texthl = "", linehl = "", numhl = "" })
vim.fn.sign_define('_', { text = '_', texthl = "", linehl = "", numhl = "" })

--> Git diff for nvim signs for current buffer
-- ':sign unplace *' to remove all signs
vim.api.nvim_create_user_command('Gdiff',
    function(opts)
	--> git --no-pager diff --no-ext-diff --no-color -U0
	currbuff = vim.fn.expand('%')
	local diff = vim.fn.system({'git', '--no-pager', 'diff', '--no-ext-diff', '--no-color', '-U0', vim.fn.expand('%')})
	--> parse hunks
	local hunkreg = "^@@ -\\(\\d\\+\\),\\?\\(\\d*\\) +\\(\\d\\+\\),\\?\\(\\d*\\) @@"
	local lines = {}
	for line in diff:gmatch('[^\r\n]+') do
	    local match = vim.fn.matchlist(line, hunkreg)
	    if table.getn(match) > 0 then
		line = tonumber(match[2])
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
			table.insert({newline, '_'}, lines)
		    end
		end

		--> modified
		if count > 0 and newcount > 0 and count == newcount then
		    for lnum=0,newcount-1 do
			table.insert({lnum+newline, '~'})
		    end
		end

		--> modified & added
		if count > 0 and newcount > 0 and count < newcount then
		    for lnum=0,count-1 do
			table.insert({lnum+newline, '~'})
		    end
		    for lnum=count,newcount-1 do
			table.insert({lnum+newline, '+'})
		    end
		end

		--> modified & removed
		if count > 0 and newcount > 0 and count > newcount then
		    for lnum=0,count-1 do
			table.insert({lnum+newline, '~'})
		    end
		    lines[count-1] = ({newline+newcount-1, '~_'})
		end
	    end
	end
	-->print(table.getn(lines))
	--for k, v in pairs(lines) do
	--    print(v.lnum..','..v.name)
	--end
	--> update current 
	vim.fn.sign_placelist(lines)
    end, {})

