function Zi = plot_topo_fast(chanloc, dat, varargin)

% PLOT_TOPO interpolates and plots the 2-D spatial topography of the
% potential or field distribution over the head
%
% Use as
%   plot_topo(chanloc, val, ...)
%
% Additional options should be specified in key-value pairs and can be
%   'hpos'
%   'vpos'
%   'width'
%   'height'
%   'shading'
%   'gridscale'
%   'mask'
%   'outline'
%   'isolines'
%   'interplim'
%   'interpmethod'
%   'style'
%   'datmask'
%   'axis'   pass in handle to axis to use for plotting

% Copyrights (C) 2009, Giovanni Piantoni
%
% This file is part of FieldTrip, see http://www.ru.nl/neuroimaging/fieldtrip
% for the documentation and details.
%
%    FieldTrip is free software: you can redistribute it and/or modify
%    it under the terms of the GNU General Public License as published by
%    the Free Software Foundation, either version 3 of the License, or
%    (at your option) any later version.
%
%    FieldTrip is distributed in the hope that it will be useful,
%    but WITHOUT ANY WARRANTY; without even the implied warranty of
%    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%    GNU General Public License for more details.
%
%    You should have received a copy of the GNU General Public License
%    along with FieldTrip. If not, see <http://www.gnu.org/licenses/>.
%
% $Id$

% these are for speeding up the plotting on subsequent calls
persistent previous_argin previous_maskimage 

warning('on', 'MATLAB:divideByZero');

% get the optional input arguments
% keyvalcheck(varargin, 'optional', {'hpos', 'vpos', 'width', 'height', 'gridscale', 'shading', 'mask', 'outline', 'interplim', 'interpmethod','isolines','style', 'datmask'});
hpos          = keyval('hpos',         varargin);    if isempty(hpos);         hpos = 0;                 end
vpos          = keyval('vpos',         varargin);    if isempty(vpos);         vpos = 0;                 end
width         = keyval('width',        varargin);    if isempty(width);        width = 1;                end
height        = keyval('height',       varargin);    if isempty(height);       height = 1;               end
gridscale     = keyval('gridscale',    varargin);    if isempty(gridscale);    gridscale = 67;           end; % 67 in original
shading       = keyval('shading',      varargin);    if isempty(shading);      shading = 'flat';         end;
mask          = keyval('mask',         varargin);
outline       = keyval('outline',      varargin);
interplim     = keyval('interplim',    varargin);    if isempty(interplim);    interplim = 'electrodes'; end
interpmethod  = keyval('interpmethod', varargin);    if isempty(interpmethod); interpmethod = 'v4';      end
isolines      = keyval('isolines',     varargin);      
style         = keyval('style',        varargin);    if isempty(style);        style = 'surfiso';       end % can be 'surf', 'iso', 'isofill', 'surfiso'
datmask       = keyval('datmask',      varargin);
electrodes    = keyval('electrodes',   varargin);    if isempty(electrodes),    electrodes='on'; end
h_axis        = keyval('axis',         varargin);

% everything is added to the current figure
holdflag = ishold;
hold on

rmax=0.5;
AXHEADFAC = 1.3;        % head to axes scaling factor



% [Th,Rd]=cart2pol(chanX, chanY);
Th = [chanloc.theta];
Th = pi/180*Th; % convert degrees to radians

Rd = [chanloc.radius];
% chanX1 = [chanloc.X];
% chanY1 = [chanloc.Y];
%%% we do the cartesian shift here, dunno why topoplot doesnt use the given values
[chanX,chanY] = pol2cart(Th,Rd);  % transform electrode locations from polar to cartesian coordinates


headrad=rmax; %"anatomically correct"
plotrad = min(1.0,max(Rd)*1.02);
plotrad = max(plotrad,0.5); % default: plot out to the 0.5 head boundary
intrad = min(1.0,max(Rd)*1.02);             % default: just outside the outermost electrode location
intchans = find(Rd <= intrad); % interpolate channels in the radius intrad circle only

squeezefac = rmax/plotrad;
Rd = Rd*squeezefac;       % squeeze electrode arc_lengths towards the vertex
chanX = chanX*squeezefac;    
chanY = chanY*squeezefac;   


plotcfg.squeezefac = squeezefac;
plotcfg.headrad = headrad;
plotcfg.plotrad = plotrad;
plotcfg.rmax = rmax;
plotcfg.headrad = headrad;
plotcfg.plotrat = plotrad;


% isolines = dat;

hlim = [min(-rmax,min(chanX)), max(rmax,max(chanX))];
vlim = [min(-rmax,min(chanY)), max(rmax,max(chanY))];

xi         = linspace(hlim(1), hlim(2), gridscale);       % x-axis for interpolation (row vector)
yi         = linspace(vlim(1), vlim(2), gridscale);       % y-axis for interpolation (row vector)
% [Xi,Yi,Zi] = griddata(double(chanX'), double(chanY), double(dat), double(xi'), double(yi), interpmethod); % interpolate the topographic data
%this one has nose pointed up
[Xi,Yi,Zi] = griddata(double(chanY), double(chanX), double(dat), double(yi'), double(xi), interpmethod); % interpolate the topographic data
if ~isempty(isolines)
    [Xi,Yi,ZiC] = griddata(double(chanY), double(chanX), double(isolines), double(yi'), double(xi), 'v4'); % interpolate data
end

% curhandles = previous_handles;
% if ~isempty(curhandles)
%     delete(curhandles);
% end

%%%%%%%%%
% try to speed up the preparatsion of the mask on subsequent calls
current_argin = {chanX, chanY, gridscale, mask, plotcfg};
if isequal(current_argin, previous_argin)
  % don't construct the binary image, but reuse it from the previous call
  maskimage = previous_maskimage;

else
%   maskimage = [];
  maskimage = (sqrt(Xi.^2 + Yi.^2) <= rmax); % mask outside the plotting circle
end
if ~isempty(maskimage)
  % apply anatomical mask to the data, i.e. that determines that the interpolated data outside the circle is not displayed
  Zi(~maskimage) = NaN;
end

if isempty(h_axis)
    h_axis = gca; % uses current axes
end
h_plot = [];

set(h_axis,'Xlim',[-rmax rmax]*AXHEADFAC,'Ylim',[-rmax rmax]*AXHEADFAC);

%%%%%%%%%%%%%%%%%%%%%%
% Plot surface
if strcmp(style,'surf') || strcmp(style,'surfiso')
  deltax = xi(2)-xi(1); % length of grid entry
  deltay = yi(2)-yi(1); % length of grid entry
  %do delta/2 offset if shading is 'flat'
  h_plot(end+1) = surface(Xi-deltax/2, Yi-deltay/2, zeros(size(Zi))-0.1, Zi, 'EdgeColor', 'none', 'FaceColor', shading);
end


% Plot filled contours
if strcmp(style,'isofill') && ~isempty(isolines)
  h_plot(end+1) = contourf(Xi,Yi,ZiC,isolines,'k');
end

% Create isolines
if strcmp(style,'iso') || strcmp(style,'surfiso')
  if ~isempty(isolines)
    h_plot(end+1) = contour(Xi,Yi,ZiC,isolines,'k');
  end
end

set(h_axis,'Xlim',[-rmax rmax]*AXHEADFAC,'Ylim',[-rmax rmax]*AXHEADFAC)

axis off


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%do masking and head cartoon

h_head = plot_cartoonhead(plotcfg);
h_plot = [h_plot, h_head]; %adding cell array of handles

plotax = h_axis;
% axis square  % make textax square
axis equal;
set(plotax, 'xlim', [-0.525 0.525]); set(plotax, 'xlim', [-0.525 0.525]);
set(plotax, 'ylim', [-0.525 0.525]); set(plotax, 'ylim', [-0.525 0.525]);

if strcmpi(electrodes,'on') || electrodes==true
    h_plot(end+1) = plot_electrodepos(chanX,chanY);
end


% remember the current input arguments, so that they can be
% reused on a subsequent call in case the same input argument is given
previous_argin     = current_argin;
previous_maskimage = maskimage;
% previous_handles = h_plot;

axis off

if ~holdflag
  hold off
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
