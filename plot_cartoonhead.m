function handles = plot_cartoonhead(plotcfg)
% plot a masking ring and cartoon head on current axis
% based on eeglab/topoplop.m

BLANKINGRINGWIDTH = .035;% width of the blanking ring 
HEADRINGWIDTH    = .007;% width of the cartoon head ring
BACKCOLOR = [.93 .96 1];
HEADCOLOR = [0 0 0];
CIRCGRID   = 201;       % number of angles to use in drawing circles
HLINEWIDTH = 1.7;         % default linewidth for head, nose, ears

rmax = plotcfg.rmax;

hwidth = HEADRINGWIDTH;                   % width of head ring 
hin  = plotcfg.squeezefac * plotcfg.headrad*(1- hwidth/2);  % inner head ring radius
rwidth = BLANKINGRINGWIDTH;         % width of blanking outer ring
rin =  rmax*(1-rwidth/2);              % inner ring radius
if hin>rin
    rin = hin;                              % dont blank inside the head ring
end


%plot edge ring mask
circ = linspace(0,2*pi,CIRCGRID);
rx = sin(circ); 
ry = cos(circ); 
ringx = [[rx(:)' rx(1) ]*(rin+rwidth)  [rx(:)' rx(1)]*rin];
ringy = [[ry(:)' ry(1) ]*(rin+rwidth)  [ry(:)' ry(1)]*rin];
handles(1) = patch(ringx,ringy,0.01*ones(size(ringx)),BACKCOLOR,'edgecolor','none'); hold on

% plot the head outline
headx = [[rx(:)' rx(1) ]*(hin+hwidth)  [rx(:)' rx(1)]*hin];
heady = [[ry(:)' ry(1) ]*(hin+hwidth)  [ry(:)' ry(1)]*hin];
handles(2) = patch(headx,heady,ones(size(headx)),HEADCOLOR,'edgecolor',HEADCOLOR); hold on


%plot ears and nose
base  = rmax-.0046;
basex = 0.18*rmax;                   % nose width
tip   = 1.15*rmax; 
tiphw = .04*rmax;                    % nose tip half width
tipr  = .01*rmax;                    % nose tip rounding
q = .04; % ear lengthening
EarX  = [.497-.005  .510  .518  .5299 .5419  .54    .547   .532   .510   .489-.005]; % rmax = 0.5
EarY  = [q+.0555 q+.0775 q+.0783 q+.0746 q+.0555 -.0055 -.0932 -.1313 -.1384 -.1199];
sf    = plotcfg.headrad/plotcfg.plotrad; % squeeze the model ears and nose  by this factor

handles(3) = plot3([basex;tiphw;0;-tiphw;-basex]*sf,[base;tip-tipr;tip;tip-tipr;base]*sf,...
                 2*ones(size([basex;tiphw;0;-tiphw;-basex])),...
                 'Color',HEADCOLOR,'LineWidth',HLINEWIDTH);                 % plot nose
handles(4) = plot3(EarX*sf,EarY*sf,2*ones(size(EarX)),'color',HEADCOLOR,'LineWidth',HLINEWIDTH);    % plot left ear
handles(5) = plot3(-EarX*sf,EarY*sf,2*ones(size(EarY)),'color',HEADCOLOR,'LineWidth',HLINEWIDTH);   % plot right ear


