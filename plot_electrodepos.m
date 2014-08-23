function hp2 = plot_electrodepos(x,y)
% plot the electrode positions

EMARKER = '.';          % mark electrode locations with small disks
ECOLOR = [0 0 0];       % default electrode color = black
EMARKERSIZE = [];       % default depends on number of electrodes, set in code
EMARKERLINEWIDTH = 1;   % default edge linewidth for emarkers
ELECTRODE_HEIGHT = 2.1;  % z value for plotting electrode information (above the surf)


if isempty(EMARKERSIZE)
    EMARKERSIZE = 10;
    if length(y)>=160
        EMARKERSIZE = 3;
    elseif length(y)>=128
        EMARKERSIZE = 3;
    elseif length(y)>=100
        EMARKERSIZE = 3;
    elseif length(y)>=80
        EMARKERSIZE = 4;
    elseif length(y)>=64
        EMARKERSIZE = 5;
    elseif length(y)>=48
        EMARKERSIZE = 6;
    elseif length(y)>=32
        EMARKERSIZE = 8;
    end
end

hp2 = plot3(y, x, ones(size(x))*ELECTRODE_HEIGHT,...
    EMARKER,'Color',ECOLOR,'markersize',EMARKERSIZE,'linewidth',EMARKERLINEWIDTH);
