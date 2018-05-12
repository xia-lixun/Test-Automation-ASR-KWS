function pcm_out = mixer(pcm_in, route_matrix)
% pcm_in:        input linear PCM signal whose columns are individual channels
% route_matrix:  routing matrix for mixing
%                row corresponds to each output channel
%                column coresponds to input pcm channels
    assert(size(pcm_in,2) == size(route_matrix,2));
    
    pcm_out = zeros(size(pcm_in,1),size(route_matrix,1));
    for i = 1:size(route_matrix,1)
        pcm_out(:,i) = sum(pcm_in .* route_matrix(i,:), 2);
    end
    
    if max(abs(pcm_out)) < 1.0
    else
        error('mixer: sample clipping! consider modify mixer matrix? abort!');
    end
end