local log_lines = {}

function log(...)
    table.insert(log_lines, string.format(...))
end

function emit_logs()
    local sep = '\n[sticky-fingers]: '
    print_error(sep .. table.concat(log_lines, sep))
end
