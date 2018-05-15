function pcmout = mixer(pcmin, routemat)

% pcmin:     input linear PCM signal whose columns are individual channels
% routemat:  routing matrix for mixing
%            dim(1) corresponds to input channels
%            dim(2) coresponds to output channels

    pcmout = pcmin * routemat;
    if max(abs(pcmout)) < 1.0
    else
        error('mixer: sample clipping! consider modify mixer matrix? abort!');
    end
end