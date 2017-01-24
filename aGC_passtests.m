function [Rin, tau, cap, Vrest] = aGC_passtests(neuron,tree,params,targetfolder,ostruct)
% caution! ostruct.recordnode is vector giving each tree the location where
% to record!

Rin = NaN(1,numel(tree));
tau = NaN(1,numel(tree));
cap = NaN(1,numel(tree));
Vrest = NaN(1,numel(tree));
% neuron = setionconcentrations(neuron,'SH07');

if isfield(ostruct,'recordnode') && isnumeric(ostruct.recordnode) && numel(ostruct.recordnode) == numel(tree)
    recordnode = ostruct.recordnode;
else
    recordnode = ones(numel(tree),1);
end
if isfield(ostruct,'stimnode') && isnumeric(ostruct.stimnode) && numel(ostruct.stimnode) == numel(tree)
    stimnode = ostruct.stimnode;
else
    stimnode = ones(numel(tree),1);
end
if ~isfield(ostruct,'figureheight')
    ostruct.figureheight = [];
    ostruct.figurewidth = [];
end
if ~isfield(ostruct,'passtest')
    ostruct.passtest = 'Mongiat';
end
if isfield(ostruct,'show') && ~any(ostruct.show == 0)
    options = '-s';
else
    options = '';
end
params.prerun = 1500;
del = 100;

params.tstart = 0;

params.cvode=0;
switch ostruct.passtest
    case 'Mongiat'
        Vh = -70-params.LJP;
        dur = 100;
%         params.cvode = 1;
        amp = -10; %mV for cap and Rin Mongiat 2009
        for t = 1:numel(tree)
            neuron.pp{t}.SEClamp = struct('node',stimnode(t),'times',[-100, del, del+dur],'amp', [Vh Vh+amp Vh],'rs',15); 
            neuron.record{t}.SEClamp = struct('record','i','node',recordnode(t));
        end
    case 'Mongiat2'
        dur = 500;
        amp = -0.01  ;      % 10pA for tau...Mongiat 2009
        [hstep, Vrest] = find_curr(params,neuron,tree,-80-params.LJP);
        for t = 1:numel(tree)
            neuron.pp{t}.IClamp = struct('node',stimnode(t),'times',[-400,del,del+dur],'amp', [hstep(t), hstep(t)+amp hstep(t)]); %n,del,dur,amp
            neuron.record{t}.cell = struct('record','v','node',recordnode(t));
        end
    case 'Std'
        dur = 500;
        amp = -0.01  ;      % 10pA for tau...Mongiat 2009
        [hstep, Vrest] = find_curr(params,neuron,tree,-80);
        for t = 1:numel(tree)
            neuron.pp{t}.IClamp = struct('node',stimnode(t),'times',[-400,del,del+dur],'amp', [hstep(t), hstep(t)+amp hstep(t)]); %n,del,dur,amp
            neuron.record{t}.cell = struct('record','v','node',recordnode(t));
        end
    case 'Mehranfard'
        dur = 300;
        amp = -0.05  ;      % -50pA Meranfahrd 2015
        [hstep, Vrest] = find_curr(params,neuron,tree,-70);
        for t = 1:numel(tree)
            neuron.pp{t}.IClamp = struct('node',stimnode(t),'times',[-400,del,del+dur],'amp', [hstep(t), hstep(t)+amp hstep(t)]); %n,del,dur,amp
            neuron.record{t}.cell = struct('record','v','node',recordnode(t));
        end
    case 'SH'
        dur = 500;
        amp = -0.003  ;      % 3pA Schmidt Hieber 2007
        
        for t = 1:numel(tree)
            neuron.pp{t}.IClamp = struct('node',stimnode(t),'del',del,'dur', dur,'amp', amp); %n,del,dur,amp
            neuron.record{t}.cell = struct('record','v','node',recordnode(t));
        end
    case 'Brenner'
        dur = 1000;
        amp = -0.02  ;      % -20pA Brenner 2005 from holding pot of -80mV
        [hstep, Vrest] = find_curr(params,neuron,tree,-80);
        for t = 1:numel(tree)
            neuron.pp{t}.IClamp = struct('node',stimnode(t),'times',[-400,del,del+dur],'amp', [hstep(t), hstep(t)+amp hstep(t)]); %n,del,dur,amp
            neuron.record{t}.cell = struct('record','v','node',recordnode(t));
        end
end
params.tstop = 500+2*dur;
params.dt = 2;
[out, ~] = t2n(tree,params,neuron,'-q-d');
fitstart = del+dur+2;
% fitstart2 = del+10;
if ~isempty(strfind(options,'-s'))
    figure, hold on
end
if amp > 0
    fu = @le;
else
    fu = @ge;
end

switch ostruct.passtest
    case 'Mongiat'
        for t = 1:numel(tree)
            I0 = mean(out.record{t}.SEClamp.i{recordnode(t)}(1:del/params.dt+1)); 
            is = out.record{t}.SEClamp.i{recordnode(t)}((del+dur)/params.dt+1);
            if ~isfield(ostruct,'capacitance') || ostruct.capacitance == 1
                y = out.record{t}.SEClamp.i{recordnode(t)}(sign(amp)*out.record{t}.SEClamp.i{recordnode(t)} > sign(amp)*is)-is;
                x = out.t(sign(amp)*out.record{t}.SEClamp.i{recordnode(t)} > sign(amp)*is);
                cap(t) = trapz(x,y)/amp * 1000;
                fprintf('Capacitance is %g pF\n',cap(t))
            end
%             y = out.record{t}.SEClamp.i{recordnode(t)} - out.record{t}.SEClamp.i{recordnode(t)}(1);
%             y(sign(amp)*y>0) = 0;
%             trapz(out.t,y)/amp*sign(amp)
            Rin(t) = amp/(is-I0); %MOhm mV/nA
            fprintf('Rin: %g MOhm ,     tau:  ms\n',  Rin(t));%,tauexp(t));
            if ~isempty(strfind(options,'-s'))
                plot(out.t,out.record{t}.SEClamp.i{recordnode(t)},'Color',tree{t}.col{1},'LineWidth',1)
                xlim([0 del+dur+100])
            end
        end
                    

    case {'SH','Mongiat2','Brenner','Mehranfard','Std'}
        for t = 1:numel(tree)
            V0 = mean(out.record{t}.cell.v{recordnode(t)}(1:del/params.dt+1));  %mV  only works with prerun
            v0(t) = V0;
            
            Vs = out.record{t}.cell.v{recordnode(t)}((del+dur)/params.dt+1); %mV   sensitive to noise since no mean
            vs(t) = Vs;
            Rin(t) = (Vs-V0)/(amp);  % MOhm
            
            xend = find(fu(out.record{t}.cell.v{recordnode(t)}((del+dur)/params.dt+1:end) , (Vs-V0)*0.1+V0),1,'first');  % take trace from current release until decay has reached 10% of max amplitude
            %     y = log(-out.record{t}.cell.v{elecnode}((del+dur)/params.dt+1:(del+dur)/params.dt+xend)+V0);
            [a,~] = polyfit(out.t((fitstart)/params.dt+1:(fitstart)/params.dt+xend),log(sign(amp)*out.record{t}.cell.v{recordnode(t)}((fitstart)/params.dt+1:(fitstart)/params.dt+xend)-sign(amp)*V0),1);
            
%             [b,~] = polyfit(out.t((fitstart2)/params.dt+1:(fitstart2+dur)/params.dt),log(sign(amp)*out.record{t}.cell.v{recordnode(t)}((fitstart2)/params.dt+1:(fitstart2+dur)/params.dt)-sign(amp)*V0),1);
            if ~isempty(strfind(options,'-s'))
                yf = NaN(1,numel(out.t));
                yf((fitstart)/params.dt+1:end) = sign(amp)*exp(out.t((fitstart)/params.dt+1:end) * a(1) +a(2))+V0;
                hold all
                if numel(tree) == t
                    xlabel('Time [ms]')
                end
                %         if params.realv
                plot(out.t,out.record{t}.cell.v{recordnode(t)},'Color',tree{t}.col{1},'LineWidth',1)
                plot(out.t,yf,'Color','k','LineWidth',2,'LineStyle','--')
                if ceil(numel(tree)/2) == t
                    ylabel('Membrane Potential [mV]')
                end
            end
           
            tau(t) = -1/a(1);
            if imag(tau(t)) ~= 0
               'g' 
            end
            %     Rinth(t) = Rm/(10^3*tsurf(t));     %MOhm
            %     tauth(t) = Rm * cm;  % ms
            fprintf('Rin: %g MOhm ,     tau: %g ms\n',  Rin(t),tau(t));%,tauth(t));
        end
        if ~isempty(strfind(options,'-s'))
            linkaxes
            %     if params.realv
            if amp < 0
                ylim([floor(min(vs)) ceil(max(v0))])
            else
                ylim([floor(min(v0)) ceil(max(vs))])
            end
        end
        %     else
        %         ylim([floor(min(vs)+params.LJP) ceil(max(v0)+params.LJP)])
        %     end
        
end
if ~isempty(strfind(options,'-s'))
    xlim([0 2000])
    FontResizer
    FigureResizer(ostruct.figureheight,ostruct.figurewidth,[],ostruct)
    tprint(fullfile2(targetfolder,strcat(sprintf('Fig.2-PassMeasure_%s_',ostruct.passtest),neuron.experiment)),'-pdf')
    % tprint(fullfile2(targetfolder,strcat('Fig.2-PassMeasure',neuron.experiment)),'-png')
end

if any(strcmp(ostruct.passtest,{'SH','Mongiat2','Std'}))
    if strcmp(ostruct.passtest,'Mongiat2')
        str = '(Holding potential -70 mV)';
%     elseif strcmp(ostruct.passtest,'Brenner')
%         str = '(Holding potential -80 mV)';
    else
        str = '';
    end
%     display(sprintf('VRest recalculated to Mongiat LJP is %g +- %g mV %s',mean(v0)+params.LJP,std(v0),str))
end

