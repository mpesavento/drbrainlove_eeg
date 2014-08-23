%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SUBFUNCTION recursive computation of z-transformed data by means of persistent variables
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function z = recurz(x)

persistent n
persistent s
persistent ss

if nargin==0 || isempty(x)
  % re-initialize
  n  = [];
  s  = [];
  ss = [];
  return
end

if isempty(n)
  n = 1;
else
  n = n + 1;
end

if isempty(s)
  s = x;
else
  s = s + x;
end

if isempty(ss)
  ss = x.^2;
else
  ss = ss + x.^2;
end

if n==1
  % standard deviation cannot be computed yet
  z = zeros(size(x));
elseif all(s(:)==ss(:))
  % standard deviation is zero anyway
  z = zeros(size(x));
else
  % compute standard deviation and z-transform of the input data
  sd = sqrt((ss - (s.^2)./n) ./ (n-1));
  z  = (x-s/n)./ sd;
end