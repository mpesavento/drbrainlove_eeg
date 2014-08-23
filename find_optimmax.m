function [maxlim, max_history] = find_optimmax(data, maxlim, max_history)
% find the "best" maximum value, for arbitrary definitions of "best"

%create optimal max from median, monotonically increasing
localmax = max(data(:));
if isempty(max_history)
    m=localmax;
else
    m = median([max_history(:,1); localmax]);
end
if m>maxlim
    maxlim = m;

end
max_history=[max_history; localmax, maxlim];
