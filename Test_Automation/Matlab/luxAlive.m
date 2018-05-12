function status = luxAlive()

[status, result] = system('sdb root off');
[status, result] = system('sdb root on');
reference = 'Switched to ''root'' account mode';
if 1 == strncmp(result, reference, length(reference))
    status = 'alive';
else
    status = 'dead';
end
