function y = ini_decomment(x)
    comment = strfind(x,';');
    if ~isempty(comment)
        y = x(1:comment(1)-1);
    else
        y = x;
    end
    y = y(find(~isspace(y)));
end